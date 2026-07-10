package Servlet;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.*;
import java.util.*;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import org.apache.commons.csv.*;
import Utils.DataPathResolver;

@WebServlet("/enrichment")
public class EnrichmentServlet extends HttpServlet {

    private static final Map<String, Map<String, String>> mapping;

    // ORA gene-set libraries available under {dataRoot}/gmt/, per species.
    // Ordered (insertion order) so the dropdown reads sensibly. Maps the .gmt
    // filename -> friendly label. Only files that actually exist are returned.
    private static final Map<String, String> HUMAN_ORA_LIBS = new LinkedHashMap<>();
    private static final Map<String, String> MOUSE_ORA_LIBS = new LinkedHashMap<>();

    // ORA query-set definition (confirmed): up-regulated significant markers.
    private static final double ORA_PADJ_MAX = 0.05;
    private static final double ORA_LFC_MIN = 1.0;
    private static final int ORA_QUERY_CAP = 500;
    private static final int ORA_MIN_SET = 5;     // skip tiny gene sets
    private static final int ORA_MAX_SET = 2000;  // skip huge/uninformative sets

    static {
        try (InputStreamReader reader = new InputStreamReader(
                EnrichmentServlet.class.getClassLoader().getResourceAsStream("mapping.csv.json"),
                "UTF-8"
        )) {
            mapping = new Gson().fromJson(
                    reader,
                    new TypeToken<Map<String, Map<String, String>>>() {}.getType()
            );
        } catch (Exception e) {
            throw new ExceptionInInitializerError("Failed to load mapping.csv.json: " + e.getMessage());
        }

        HUMAN_ORA_LIBS.put("MSigDB_Hallmark_2020.gmt", "Hallmark Gene Sets (MSigDB)");
        HUMAN_ORA_LIBS.put("GO_Biological_Process_2025.gmt", "GO Biological Process");
        HUMAN_ORA_LIBS.put("GO_Cellular_Component_2025.gmt", "GO Cellular Component");
        HUMAN_ORA_LIBS.put("GO_Molecular_Function_2025.gmt", "GO Molecular Function");
        HUMAN_ORA_LIBS.put("KEGG_2021_Human.gmt", "KEGG Pathways");
        HUMAN_ORA_LIBS.put("Reactome_Pathways_2024.gmt", "Reactome Pathways");

        MOUSE_ORA_LIBS.put("mh.all.v2026.1.Mm.symbols.gmt", "Hallmark Gene Sets (MSigDB)");
        MOUSE_ORA_LIBS.put("m5.go.bp.v2026.1.Mm.symbols.gmt", "GO Biological Process");
        MOUSE_ORA_LIBS.put("m5.go.cc.v2026.1.Mm.symbols.gmt", "GO Cellular Component");
        MOUSE_ORA_LIBS.put("m5.go.mf.v2026.1.Mm.symbols.gmt", "GO Molecular Function");
        MOUSE_ORA_LIBS.put("m8.all.v2026.1.Mm.symbols.gmt", "Cell Type Signatures (M8)");
        MOUSE_ORA_LIBS.put("KEGG_2019_Mouse.gmt", "KEGG Pathways");
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String said = request.getParameter("said");
        String action = request.getParameter("action");
        String method = request.getParameter("method");

        if (said == null || !said.matches("SAID\\d{3}")) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "A valid dataset accession is required");
            return;
        }

        Map<String, String> meta = mapping.get(said);
        if (meta == null) {
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().print("{\"gene_sets\":[]}");
            return;
        }

        String species = meta.get("csv_path").contains("/mouse/") ? "mouse" : "human";
        String gse = meta.get("GSE");
        String gsm = meta.get("GSM");

        String dataRoot = DataPathResolver.resolveDataRoot(getServletContext());

        response.setContentType("application/json;charset=UTF-8");
        PrintWriter out = response.getWriter();

        // ---- ORA: list available .gmt libraries for this species -------------
        if ("ora-list".equals(action)) {
            File gmtDir = new File(dataRoot, "gmt");
            Map<String, String> libs = "mouse".equals(species) ? MOUSE_ORA_LIBS : HUMAN_ORA_LIBS;
            List<Map<String, String>> geneSets = new ArrayList<>();
            for (Map.Entry<String, String> e : libs.entrySet()) {
                if (new File(gmtDir, e.getKey()).exists()) {
                    Map<String, String> gs = new HashMap<>();
                    gs.put("file", e.getKey());
                    gs.put("label", e.getKey());   // value sent back as ?library=
                    gs.put("name", e.getValue());
                    geneSets.add(gs);
                }
            }
            new Gson().toJson(Collections.singletonMap("gene_sets", geneSets), out);
            return;
        }

        // ---- ORA: compute over-representation on the fly ---------------------
        if ("ora".equals(method)) {
            runOra(request, response, out, dataRoot, species, gse, gsm);
            return;
        }

        // ====================== existing GSEA (precomputed) ===================
        File enrichDir = new File(dataRoot, "GSM_enrich" + File.separator + species
                + File.separator + gse + File.separator + gsm);

        if ("list".equals(action)) {
            List<Map<String, String>> geneSets = new ArrayList<>();
            if (enrichDir.isDirectory()) {
                File[] files = enrichDir.listFiles();
                if (files != null) {
                    for (File f : files) {
                        String name = f.getName();
                        if (name.endsWith("_gsea.csv") && !name.contains("_significant")) {
                            Map<String, String> gs = new HashMap<>();
                            String label = name.replace("_gsea.csv", "");
                            gs.put("file", name);
                            gs.put("label", label);
                            if (label.startsWith("c5.go.bp")) gs.put("name", "GO Biological Process");
                            else if (label.startsWith("c5.go.cc")) gs.put("name", "GO Cellular Component");
                            else if (label.startsWith("c5.go.mf")) gs.put("name", "GO Molecular Function");
                            else if (label.startsWith("m5.go.bp")) gs.put("name", "GO Biological Process");
                            else if (label.startsWith("m5.go.cc")) gs.put("name", "GO Cellular Component");
                            else if (label.startsWith("m5.go.mf")) gs.put("name", "GO Molecular Function");
                            else if (label.startsWith("c2.all")) gs.put("name", "Curated Gene Sets (C2)");
                            else if (label.startsWith("h.all") || label.startsWith("mh.all")) gs.put("name", "Hallmark Gene Sets");
                            else if (label.startsWith("m8.all")) gs.put("name", "Cell Type Signatures (M8)");
                            else gs.put("name", label);
                            geneSets.add(gs);
                        }
                    }
                }
            }
            new Gson().toJson(Collections.singletonMap("gene_sets", geneSets), out);
            return;
        }

        // Default action: return data for a specific GSEA gene set
        String geneSet = request.getParameter("gene_set");
        String filter = request.getParameter("filter"); // "significant" or "all"

        if (geneSet == null || geneSet.isEmpty()) {
            out.print("[]");
            return;
        }
        if (geneSet.contains("..") || geneSet.contains("/") || geneSet.contains("\\")) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Invalid gene_set parameter");
            return;
        }

        String suffix = "significant".equals(filter) ? "_gsea_significant.csv" : "_gsea.csv";
        File csvFile = new File(enrichDir, geneSet + suffix);
        if (!csvFile.exists()) {
            out.print("[]");
            return;
        }

        List<Map<String, String>> results = new ArrayList<>();
        try (
            Reader in = new FileReader(csvFile);
            CSVParser parser = CSVFormat.DEFAULT
                    .withFirstRecordAsHeader()
                    .withIgnoreSurroundingSpaces()
                    .withTrim()
                    .parse(in)
        ) {
            for (CSVRecord rec : parser) {
                Map<String, String> row = new HashMap<>();
                row.put("term", rec.get("Term"));
                row.put("es", rec.get("ES"));
                row.put("nes", rec.get("NES"));
                row.put("nom_pval", rec.get("NOM p-val"));
                row.put("fdr_qval", rec.get("FDR q-val"));
                String leadGenes = rec.get("Lead_genes");
                if (leadGenes != null && leadGenes.length() > 200) {
                    String[] genes = leadGenes.split(";");
                    StringBuilder sb = new StringBuilder();
                    for (int i = 0; i < Math.min(genes.length, 20); i++) {
                        if (i > 0) sb.append("; ");
                        sb.append(genes[i]);
                    }
                    if (genes.length > 20) sb.append("... (+" + (genes.length - 20) + " more)");
                    leadGenes = sb.toString();
                }
                row.put("lead_genes", leadGenes != null ? leadGenes.replace(";", "; ") : "");
                results.add(row);
            }
        } catch (Exception e) {
            getServletContext().log("Unable to read GSEA results for " + said, e);
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Enrichment data is temporarily unavailable");
            return;
        }

        new Gson().toJson(results, out);
    }

    // =========================================================================
    //  ORA — hypergeometric over-representation analysis
    // =========================================================================
    private void runOra(HttpServletRequest request, HttpServletResponse response, PrintWriter out,
                        String dataRoot, String species, String gse, String gsm) throws IOException {

        String library = request.getParameter("library");
        if (library == null || library.isEmpty()) { out.print("[]"); return; }
        if (library.contains("..") || library.contains("/") || library.contains("\\")) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Invalid library parameter");
            return;
        }
        Map<String, String> libs = "mouse".equals(species) ? MOUSE_ORA_LIBS : HUMAN_ORA_LIBS;
        if (!libs.containsKey(library)) { out.print("[]"); return; }

        int topN = Math.max(1, Math.min(100, parseIntOr(request.getParameter("top"), 10)));
        boolean sigOnly = "significant".equals(request.getParameter("filter"));

        File degFile = new File(dataRoot, "DEG" + File.separator + species
                + File.separator + gse + File.separator + gsm + File.separator + "DEGs_all.csv");
        File gmtFile = new File(new File(dataRoot, "gmt"), library);
        if (!degFile.exists() || !gmtFile.exists()) { out.print("[]"); return; }

        // 1) Background (all tested genes) + query (sig up markers, top by score).
        Set<String> background = new HashSet<>();
        List<double[]> scored = new ArrayList<>();   // index into queryGenes via parallel list
        List<String> sigGenes = new ArrayList<>();
        List<Double> sigScores = new ArrayList<>();
        try (
            Reader in = new FileReader(degFile);
            CSVParser parser = CSVFormat.DEFAULT.withFirstRecordAsHeader()
                    .withIgnoreSurroundingSpaces().withTrim().parse(in)
        ) {
            for (CSVRecord rec : parser) {
                String gene = rec.get("gene");
                if (gene == null || gene.isEmpty()) continue;
                String g = gene.toUpperCase();
                background.add(g);
                double lfc = parseDoubleOr(rec.get("logfoldchange"), Double.NaN);
                double padj = parseDoubleOr(rec.get("pval_adj"), Double.NaN);
                double score = parseDoubleOr(rec.get("score"), 0.0);
                if (!Double.isNaN(padj) && !Double.isNaN(lfc) && padj < ORA_PADJ_MAX && lfc >= ORA_LFC_MIN) {
                    sigGenes.add(g);
                    sigScores.add(score);
                }
            }
        } catch (Exception e) {
            getServletContext().log("Unable to read DEG input for enrichment", e);
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Enrichment input is temporarily unavailable");
            return;
        }

        // Order the significant genes by score desc, cap to ORA_QUERY_CAP.
        Integer[] order = new Integer[sigGenes.size()];
        for (int i = 0; i < order.length; i++) order[i] = i;
        Arrays.sort(order, (x, y) -> Double.compare(sigScores.get(y), sigScores.get(x)));
        Set<String> query = new LinkedHashSet<>();
        for (int i = 0; i < order.length && query.size() < ORA_QUERY_CAP; i++) {
            query.add(sigGenes.get(order[i]));
        }
        int nQuery = query.size();
        int nBg = background.size();
        if (nQuery == 0 || nBg == 0) { out.print("[]"); return; }

        // 2) Parse the .gmt -> term -> gene set (restricted to background).
        Map<String, Set<String>> terms = parseGmt(gmtFile, background);

        // 3) Hypergeometric test per term (log-space). Shared log-factorial table.
        double[] lf = logFactorials(nBg);
        List<OraRow> rows = new ArrayList<>();
        for (Map.Entry<String, Set<String>> e : terms.entrySet()) {
            Set<String> set = e.getValue();
            int K = set.size();
            if (K < ORA_MIN_SET || K > ORA_MAX_SET) continue;
            int k = 0;
            List<String> overlap = new ArrayList<>();
            for (String g : query) { if (set.contains(g)) { k++; overlap.add(g); } }
            double p = hyperSF(k, nBg, K, nQuery, lf);
            double fold = ((double) k / nQuery) / ((double) K / nBg);
            rows.add(new OraRow(e.getKey(), k, K, p, fold, overlap));
        }
        if (rows.isEmpty()) { out.print("[]"); return; }

        // 4) Benjamini-Hochberg FDR over all tested terms.
        rows.sort((a, b) -> Double.compare(a.pval, b.pval));
        int m = rows.size();
        double prev = 1.0;
        for (int i = m - 1; i >= 0; i--) {
            double q = rows.get(i).pval * m / (i + 1);
            prev = Math.min(prev, q);
            rows.get(i).fdr = Math.min(1.0, prev);
        }

        // 5) Emit top-N terms that actually overlap (and pass FDR if "significant only").
        List<Map<String, Object>> outRows = new ArrayList<>();
        for (OraRow r : rows) {
            if (r.overlap.isEmpty()) continue;
            if (sigOnly && r.fdr >= 0.05) continue;
            Map<String, Object> o = new LinkedHashMap<>();
            o.put("term", r.term);
            o.put("overlap", r.k);
            o.put("set_size", r.K);
            o.put("n_query", nQuery);
            o.put("pval", r.pval);
            o.put("fdr", r.fdr);
            o.put("fold_enrichment", r.fold);
            o.put("overlap_genes", String.join("; ", r.overlap));
            outRows.add(o);
            if (outRows.size() >= topN) break;
        }
        new Gson().toJson(outRows, out);
    }

    private static Map<String, Set<String>> parseGmt(File gmt, Set<String> background) throws IOException {
        Map<String, Set<String>> terms = new LinkedHashMap<>();
        try (BufferedReader br = new BufferedReader(new InputStreamReader(new FileInputStream(gmt), "UTF-8"))) {
            String line;
            while ((line = br.readLine()) != null) {
                if (line.trim().isEmpty()) continue;
                String[] parts = line.split("\t");
                if (parts.length < 3) continue;
                String term = parts[0];
                Set<String> genes = new HashSet<>();
                for (int i = 2; i < parts.length; i++) {
                    String g = parts[i].trim();
                    if (g.isEmpty()) continue;
                    g = g.toUpperCase();
                    if (background.contains(g)) genes.add(g);  // restrict to tested universe
                }
                if (!genes.isEmpty()) terms.put(term, genes);
            }
        }
        return terms;
    }

    /** log(i!) for i in [0, n]. */
    private static double[] logFactorials(int n) {
        double[] lf = new double[n + 1];
        for (int i = 2; i <= n; i++) lf[i] = lf[i - 1] + Math.log(i);
        return lf;
    }

    private static double logChoose(int a, int b, double[] lf) {
        if (b < 0 || b > a) return Double.NEGATIVE_INFINITY;
        return lf[a] - lf[b] - lf[a - b];
    }

    /** Hypergeometric upper tail P(X >= k): overlap k, universe N, set size K, draws n. */
    private static double hyperSF(int k, int N, int K, int n, double[] lf) {
        if (k <= 0) return 1.0;
        int hi = Math.min(n, K);
        double logDenom = logChoose(N, n, lf);
        double sum = 0.0;
        for (int i = k; i <= hi; i++) {
            double logp = logChoose(K, i, lf) + logChoose(N - K, n - i, lf) - logDenom;
            if (logp > Double.NEGATIVE_INFINITY) sum += Math.exp(logp);
        }
        return Math.min(1.0, Math.max(0.0, sum));
    }

    private static int parseIntOr(String s, int def) {
        try { return Integer.parseInt(s.trim()); } catch (Exception e) { return def; }
    }
    private static double parseDoubleOr(String s, double def) {
        if (s == null) return def;
        s = s.trim();
        if (s.isEmpty() || s.equalsIgnoreCase("nan") || s.equalsIgnoreCase("na")) return def;
        try { return Double.parseDouble(s); } catch (Exception e) { return def; }
    }

    private static class OraRow {
        final String term; final int k; final int K; final double pval; final double fold;
        final List<String> overlap; double fdr;
        OraRow(String term, int k, int K, double pval, double fold, List<String> overlap) {
            this.term = term; this.k = k; this.K = K; this.pval = pval; this.fold = fold; this.overlap = overlap;
        }
    }
}
