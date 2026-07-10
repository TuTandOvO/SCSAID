package Servlet;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.*;
import java.util.*;
import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.reflect.TypeToken;
import org.apache.commons.csv.*;
import Utils.DataPathResolver;

/**
 * Serves precomputed SCORPION gene-regulatory-network summaries for a dataset.
 *
 * The heavy reconstruction (SCORPION / PANDA message passing on the single-cell
 * matrix) happens offline in scripts/scorpion/run_scorpion.R, which writes three
 * small files next to each dataset:
 *      <dataRoot>/SkinDB_New/10X/<species>/<GSE>/<GSM>/SCORPION/
 *          tf_activity.csv   (tf,out_degree,total_score,mean_weight,rank)
 *          tf_targets.csv    (tf,target,weight)
 *          meta.json
 * This servlet only ever *reads* those files, exactly as EnrichmentServlet reads
 * the precomputed GSEA CSVs. If they are absent it reports {available:false} so
 * the page can show a graceful "being prepared" state.
 *
 * Actions (GET):
 *   ?action=activity&said=SAID001[&top=25]   -> {available, meta, regulators:[...]}
 *   ?action=targets &said=SAID001&tf=FOXP1[&top=20] -> {tf, targets:[{target,weight}]}
 *   ?action=network &said=SAID001[&topTf=10&topTarget=8] -> {nodes:[...], links:[...]}
 */
@WebServlet("/scorpion")
public class ScorpionServlet extends HttpServlet {

    private static final Map<String, Map<String, String>> mapping;

    static {
        try (InputStreamReader reader = new InputStreamReader(
                ScorpionServlet.class.getClassLoader().getResourceAsStream("mapping.csv.json"),
                "UTF-8")) {
            mapping = new Gson().fromJson(reader,
                    new TypeToken<Map<String, Map<String, String>>>() {}.getType());
        } catch (Exception e) {
            throw new ExceptionInInitializerError("Failed to load mapping.csv.json: " + e.getMessage());
        }
    }

    private final Gson gson = new Gson();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("application/json;charset=UTF-8");
        PrintWriter out = response.getWriter();

        String said = request.getParameter("said");
        String action = request.getParameter("action");
        if (said == null || !said.matches("SAID\\d{3}")) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "A valid dataset accession is required");
            return;
        }
        Map<String, String> meta = mapping.get(said);
        if (meta == null || meta.get("csv_path") == null) {
            out.print("{\"available\":false}");
            return;
        }

        File dir = resolveScorpionDir(meta);
        File activityFile = new File(dir, "tf_activity.csv");
        File targetsFile  = new File(dir, "tf_targets.csv");
        File metaFile     = new File(dir, "meta.json");

        if (action == null) action = "activity";

        try {
            switch (action) {
                case "activity":
                    handleActivity(out, activityFile, metaFile,
                            boundedInt(request.getParameter("top"), 25, 1, 100));
                    break;
                case "targets":
                    handleTargets(out, targetsFile,
                            validGene(request.getParameter("tf")),
                            boundedInt(request.getParameter("top"), 20, 1, 100));
                    break;
                case "network":
                    handleNetwork(out, activityFile, targetsFile,
                            boundedInt(request.getParameter("topTf"), 10, 1, 50),
                            boundedInt(request.getParameter("topTarget"), 8, 1, 50));
                    break;
                default:
                    response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Unknown action: " + action);
            }
        } catch (Exception e) {
            getServletContext().log("Unable to read SCORPION data for " + said, e);
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                    "Regulatory-network data is temporarily unavailable");
        }
    }

    // Precomputed networks live under a fixed root keyed by species/GSE/GSM,
    // exactly like EnrichmentServlet roots GSEA under GSM_enrich/<sp>/<GSE>/<GSM>.
    // (The mapping's csv_path is only used to read the species tag.)
    //   -> <dataRoot>/SCORPION/<species>/<GSE>/<GSM>
    private File resolveScorpionDir(Map<String, String> meta) {
        String csvPath = meta.get("csv_path");
        String species = (csvPath != null && csvPath.contains("/mouse/")) ? "mouse" : "human";
        String gse = meta.get("GSE");
        String gsm = meta.get("GSM");
        String rel = "SCORPION/" + species + "/" + gse + "/" + gsm;
        return DataPathResolver.resolveReadableFile(getServletContext(), rel);
    }

    private void handleActivity(PrintWriter out, File activityFile, File metaFile, int top)
            throws IOException {
        JsonObject root = new JsonObject();
        if (!activityFile.exists()) {
            root.addProperty("available", false);
            out.print(root.toString());
            return;
        }
        root.addProperty("available", true);
        if (metaFile.exists()) {
            try (Reader r = new FileReader(metaFile)) {
                root.add("meta", gson.fromJson(r, JsonObject.class));
            } catch (Exception ignore) { /* meta is optional */ }
        }
        List<Map<String, Object>> regulators = new ArrayList<>();
        try (Reader in = new FileReader(activityFile);
             CSVParser p = CSVFormat.DEFAULT.withFirstRecordAsHeader()
                     .withIgnoreSurroundingSpaces().withTrim().parse(in)) {
            for (CSVRecord rec : p) {
                if (regulators.size() >= top) break;
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("tf", rec.get("tf"));
                row.put("rank", parseIntOr(get(rec, "rank"), regulators.size() + 1));
                row.put("out_degree", parseIntOr(get(rec, "out_degree"), 0));
                row.put("total_score", parseDoubleOr(get(rec, "total_score"), 0));
                row.put("mean_weight", parseDoubleOr(get(rec, "mean_weight"), 0));
                regulators.add(row);
            }
        }
        root.add("regulators", gson.toJsonTree(regulators));
        out.print(root.toString());
    }

    private void handleTargets(PrintWriter out, File targetsFile, String tf, int top)
            throws IOException {
        JsonObject root = new JsonObject();
        root.addProperty("tf", tf == null ? "" : tf);
        List<Map<String, Object>> targets = new ArrayList<>();
        if (tf != null && !tf.isEmpty() && targetsFile.exists()) {
            try (Reader in = new FileReader(targetsFile);
                 CSVParser p = CSVFormat.DEFAULT.withFirstRecordAsHeader()
                         .withIgnoreSurroundingSpaces().withTrim().parse(in)) {
                for (CSVRecord rec : p) {
                    if (!tf.equals(rec.get("tf"))) continue;
                    if (targets.size() >= top) break;
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("target", rec.get("target"));
                    row.put("weight", parseDoubleOr(get(rec, "weight"), 0));
                    targets.add(row);
                }
            }
        }
        root.add("targets", gson.toJsonTree(targets));
        out.print(root.toString());
    }

    // A small sub-network: the top TFs and their top targets, as nodes + links.
    private void handleNetwork(PrintWriter out, File activityFile, File targetsFile,
                               int topTf, int topTarget) throws IOException {
        JsonObject root = new JsonObject();
        if (!activityFile.exists() || !targetsFile.exists()) {
            root.addProperty("available", false);
            out.print(root.toString());
            return;
        }
        // Pick the top-ranked TFs.
        LinkedHashSet<String> tfs = new LinkedHashSet<>();
        try (Reader in = new FileReader(activityFile);
             CSVParser p = CSVFormat.DEFAULT.withFirstRecordAsHeader()
                     .withIgnoreSurroundingSpaces().withTrim().parse(in)) {
            for (CSVRecord rec : p) {
                if (tfs.size() >= topTf) break;
                tfs.add(rec.get("tf"));
            }
        }
        // Collect their top targets.
        Map<String, Integer> perTf = new HashMap<>();
        List<Map<String, Object>> links = new ArrayList<>();
        LinkedHashSet<String> targetNodes = new LinkedHashSet<>();
        try (Reader in = new FileReader(targetsFile);
             CSVParser p = CSVFormat.DEFAULT.withFirstRecordAsHeader()
                     .withIgnoreSurroundingSpaces().withTrim().parse(in)) {
            for (CSVRecord rec : p) {
                String tf = rec.get("tf");
                if (!tfs.contains(tf)) continue;
                int n = perTf.getOrDefault(tf, 0);
                if (n >= topTarget) continue;
                perTf.put(tf, n + 1);
                String target = rec.get("target");
                targetNodes.add(target);
                Map<String, Object> link = new LinkedHashMap<>();
                link.put("source", tf);
                link.put("target", target);
                link.put("weight", parseDoubleOr(get(rec, "weight"), 0));
                links.add(link);
            }
        }
        List<Map<String, Object>> nodes = new ArrayList<>();
        for (String tf : tfs)  nodes.add(node(tf, "tf"));
        for (String t : targetNodes) if (!tfs.contains(t)) nodes.add(node(t, "target"));
        root.addProperty("available", true);
        root.add("nodes", gson.toJsonTree(nodes));
        root.add("links", gson.toJsonTree(links));
        out.print(root.toString());
    }

    private static Map<String, Object> node(String id, String type) {
        Map<String, Object> n = new LinkedHashMap<>();
        n.put("id", id);
        n.put("type", type);
        return n;
    }

    private static String get(CSVRecord rec, String col) {
        try { return rec.isSet(col) ? rec.get(col) : null; } catch (Exception e) { return null; }
    }
    private static int parseIntOr(String s, int def) {
        try { return s == null ? def : (int) Math.round(Double.parseDouble(s.trim())); }
        catch (Exception e) { return def; }
    }
    private static int boundedInt(String s, int def, int min, int max) {
        int value = parseIntOr(s, def);
        return Math.max(min, Math.min(max, value));
    }
    private static String validGene(String value) {
        if (value == null) return null;
        String gene = value.trim();
        return gene.matches("[A-Za-z0-9._-]{1,64}") ? gene : null;
    }
    private static double parseDoubleOr(String s, double def) {
        try { return s == null ? def : Double.parseDouble(s.trim()); } catch (Exception e) { return def; }
    }
}
