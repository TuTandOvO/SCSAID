package Servlet;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.*;
import java.nio.file.*;
import java.util.*;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import org.apache.commons.csv.*;
import Utils.DataPathResolver;

@WebServlet("/enrichment")
public class EnrichmentServlet extends HttpServlet {

    private static final Map<String, Map<String, String>> mapping;

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
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String said = request.getParameter("said");
        String action = request.getParameter("action");

        if (said == null || said.isEmpty()) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Missing parameter: said");
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
        File enrichDir = new File(dataRoot, "GSM_enrich" + File.separator + species
                + File.separator + gse + File.separator + gsm);

        response.setContentType("application/json;charset=UTF-8");
        PrintWriter out = response.getWriter();

        // Action: list available gene sets
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
                            // Determine friendly name
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

        // Default action: return data for a specific gene set
        String geneSet = request.getParameter("gene_set");
        String filter = request.getParameter("filter"); // "significant" or "all"

        if (geneSet == null || geneSet.isEmpty()) {
            out.print("[]");
            return;
        }

        // Sanitize gene_set to prevent path traversal
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
                // Truncate lead genes for display
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
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Error reading CSV: " + e.getMessage());
            return;
        }

        new Gson().toJson(results, out);
    }
}
