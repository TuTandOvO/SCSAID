package Servlet;

import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.*;
import java.util.*;
import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.reflect.TypeToken;
import org.apache.commons.csv.*;
import Utils.DataPathResolver;

@WebServlet("/gene-search")
public class GeneSearchServlet extends HttpServlet {

    private static final Map<String, Map<String, String>> mapping;
    private static volatile Map<String, String> markerReferenceCellTypes;

    static {
        try (InputStreamReader reader = new InputStreamReader(
                GeneSearchServlet.class.getClassLoader().getResourceAsStream("mapping.csv.json"),
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

        String query = request.getParameter("q");
        if (query == null || query.trim().isEmpty()) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Missing query parameter: q");
            return;
        }

        query = query.trim();
        final int maxResults = 500; // Limit results to prevent overwhelming response

        List<Map<String, String>> results = new ArrayList<>();

        // Search across every dataset in the mapping
        for (Map.Entry<String, Map<String, String>> entry : mapping.entrySet()) {
            if (results.size() >= maxResults) break;

            String said = entry.getKey();
            Map<String, String> meta = entry.getValue();

            String csvPath = meta.get("csv_path");
            String species = (csvPath != null && csvPath.contains("/mouse/")) ? "mouse" : "human";
            String gse = meta.get("GSE");
            String gsm = meta.get("GSM");
            if (gse == null || gsm == null) continue;

            File csvFile = null;
            if (csvPath != null && !csvPath.trim().isEmpty()) {
                File annotated = DataPathResolver.resolveReadableFile(getServletContext(), csvPath);
                if (annotated != null && annotated.exists() && annotated.canRead()) {
                    csvFile = annotated;
                }
            }
            if (csvFile == null) {
                String relPath = "DEG/" + species + "/" + gse + "/" + gsm + "/DEGs_all.csv";
                csvFile = DataPathResolver.resolveReadableFile(getServletContext(), relPath);
            }
            if (csvFile == null || !csvFile.exists()) continue;

            try (
                Reader in = new FileReader(csvFile);
                CSVParser parser = CSVFormat.DEFAULT
                        .withFirstRecordAsHeader()
                        .withIgnoreSurroundingSpaces()
                        .withTrim()
                        .parse(in)
            ) {
                // Build column name mapping (case-insensitive)
                Map<String, String> lowerToOrig = new HashMap<>();
                for (String orig : parser.getHeaderMap().keySet()) {
                    lowerToOrig.put(orig.trim().toLowerCase(), orig);
                }

                // Real DEG files use: gene, logfoldchange, pval_adj (+ score).
                // Fall back to the older names/logfoldchanges/pvals_adj naming.
                String namesCol = lowerToOrig.containsKey("gene")
                        ? lowerToOrig.get("gene") : lowerToOrig.get("names");
                String fcCol = lowerToOrig.containsKey("logfoldchange")
                        ? lowerToOrig.get("logfoldchange") : lowerToOrig.get("logfoldchanges");
                String pvalCol = lowerToOrig.containsKey("pval_adj")
                        ? lowerToOrig.get("pval_adj") : lowerToOrig.get("pvals_adj");
                String cellTypeCol = firstPresent(lowerToOrig,
                        "cell_type", "cell type", "celltype", "celltypes",
                        "fine_map", "fine map", "gross_map", "gross map",
                        "annotation", "cell_annotation", "cell annotation",
                        "cluster", "clusters", "leiden", "louvain", "group");

                // Skip files missing the columns we need
                if (namesCol == null || fcCol == null || pvalCol == null) {
                    continue;
                }

                for (CSVRecord rec : parser) {
                    if (results.size() >= maxResults) break;

                    try {
                        String geneName = rec.get(namesCol);

                        // Exact-case partial match. Human symbols are typically uppercase
                        // (e.g. KRT14), while mouse symbols are typically title case
                        // (e.g. Krt14), so case-insensitive matching is misleading here.
                        if (geneName.contains(query)) {
                            double logfc = Double.parseDouble(rec.get(fcCol));
                            double pval = Double.parseDouble(rec.get(pvalCol));
                            String markerCellType = (cellTypeCol != null) ? rec.get(cellTypeCol) : "";
                            if (isGenericCellType(markerCellType)) {
                                markerCellType = markerReferenceCellTypes(getServletContext()).get(geneName);
                            }
                            if (isGenericCellType(markerCellType)) {
                                markerCellType = "Unannotated";
                            }

                            Map<String, String> row = new HashMap<>();
                            row.put("gene", geneName);
                            row.put("said", said);
                            row.put("gse", meta.get("GSE"));
                            row.put("gsm", meta.get("GSM"));
                            row.put("species", species);
                            row.put("logfc", String.format("%.4f", logfc));
                            row.put("pval", String.format("%.2e", pval));
                            row.put("group", markerCellType);
                            row.put("cell_type", markerCellType);
                            results.add(row);
                        }
                    } catch (Exception ignore) {
                        // Skip malformed rows
                    }
                }
            } catch (IOException e) {
                // Skip files that can't be read
            }
        }

        // Sort results by adjusted p-value (ascending)
        results.sort((a, b) -> {
            try {
                double pvalA = Double.parseDouble(a.get("pval"));
                double pvalB = Double.parseDouble(b.get("pval"));
                return Double.compare(pvalA, pvalB);
            } catch (Exception e) {
                return 0;
            }
        });

        response.setContentType("application/json;charset=UTF-8");
        Map<String, Object> responseData = new HashMap<>();
        responseData.put("query", query);
        responseData.put("count", results.size());
        responseData.put("results", results);
        new Gson().toJson(responseData, response.getWriter());
    }

    private static String firstPresent(Map<String, String> lowerToOrig, String... keys) {
        for (String key : keys) {
            String value = lowerToOrig.get(key);
            if (value != null) {
                return value;
            }
        }
        return null;
    }

    private static boolean isGenericCellType(String value) {
        if (value == null) return true;
        String normalized = value.trim();
        return normalized.isEmpty()
                || "all".equalsIgnoreCase(normalized)
                || "unannotated".equalsIgnoreCase(normalized)
                || "unknown".equalsIgnoreCase(normalized);
    }

    private static Map<String, String> markerReferenceCellTypes(ServletContext context) {
        Map<String, String> cached = markerReferenceCellTypes;
        if (cached != null) return cached;

        synchronized (GeneSearchServlet.class) {
            if (markerReferenceCellTypes != null) return markerReferenceCellTypes;

            Map<String, List<String>> collected = new LinkedHashMap<String, List<String>>();
            try (InputStream in = context.getResourceAsStream("/enrichment_resources/gmt/web/marker_genes_fine_map.json")) {
                if (in != null) {
                    JsonObject root = JsonParser.parseReader(new InputStreamReader(in, "UTF-8")).getAsJsonObject();
                    for (Map.Entry<String, JsonElement> entry : root.entrySet()) {
                        String cellType = entry.getKey();
                        JsonObject payload = entry.getValue().getAsJsonObject();
                        if (!payload.has("genes") || !payload.get("genes").isJsonArray()) continue;
                        JsonArray genes = payload.getAsJsonArray("genes");
                        for (JsonElement geneElement : genes) {
                            String gene = geneElement.getAsString();
                            addMarkerReference(collected, gene, cellType);
                            addMarkerReference(collected, gene.toUpperCase(Locale.ROOT), cellType);
                        }
                    }
                }
            } catch (Exception ignored) {
            }

            Map<String, String> flattened = new HashMap<String, String>();
            for (Map.Entry<String, List<String>> entry : collected.entrySet()) {
                flattened.put(entry.getKey(), summarizeCellTypes(entry.getValue()));
            }
            markerReferenceCellTypes = flattened;
            return markerReferenceCellTypes;
        }
    }

    private static void addMarkerReference(Map<String, List<String>> collected, String gene, String cellType) {
        if (gene == null || gene.trim().isEmpty()) return;
        List<String> list = collected.get(gene);
        if (list == null) {
            list = new ArrayList<String>();
            collected.put(gene, list);
        }
        if (!list.contains(cellType)) {
            list.add(cellType);
        }
    }

    private static String summarizeCellTypes(List<String> cellTypes) {
        if (cellTypes == null || cellTypes.isEmpty()) return "";
        int shown = Math.min(3, cellTypes.size());
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < shown; i++) {
            if (i > 0) sb.append("; ");
            sb.append(cellTypes.get(i));
        }
        if (cellTypes.size() > shown) {
            sb.append("; +").append(cellTypes.size() - shown).append(" more");
        }
        return sb.toString();
    }
}
