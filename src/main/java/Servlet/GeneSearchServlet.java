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

@WebServlet("/gene-search")
public class GeneSearchServlet extends HttpServlet {

    private static final Map<String, Map<String, String>> mapping;

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

        query = query.trim().toLowerCase();
        final int maxResults = 500; // Limit results to prevent overwhelming response

        List<Map<String, String>> results = new ArrayList<>();

        // Search across every dataset in the mapping
        for (Map.Entry<String, Map<String, String>> entry : mapping.entrySet()) {
            if (results.size() >= maxResults) break;

            String said = entry.getKey();
            Map<String, String> meta = entry.getValue();

            // Resolve the DEG file the same way DEGServlet does. The csv_path in
            // mapping.csv.json points at a SkinDB_New/... layout that does not exist
            // on the server, so build the real path instead:
            //   {dataRoot}/DEG/{species}/{GSE}/{GSM}/DEGs_all.csv
            String csvPath = meta.get("csv_path");
            String species = (csvPath != null && csvPath.contains("/mouse/")) ? "mouse" : "human";
            String gse = meta.get("GSE");
            String gsm = meta.get("GSM");
            if (gse == null || gsm == null) continue;

            String relPath = "DEG/" + species + "/" + gse + "/" + gsm + "/DEGs_all.csv";
            File csvFile = DataPathResolver.resolveReadableFile(getServletContext(), relPath);
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
                String groupCol = lowerToOrig.get("group");

                // Skip files missing the columns we need
                if (namesCol == null || fcCol == null || pvalCol == null) {
                    continue;
                }

                for (CSVRecord rec : parser) {
                    if (results.size() >= maxResults) break;

                    try {
                        String geneName = rec.get(namesCol);

                        // Case-insensitive partial match
                        if (geneName.toLowerCase().contains(query)) {
                            double logfc = Double.parseDouble(rec.get(fcCol));
                            double pval = Double.parseDouble(rec.get(pvalCol));
                            // DEGs_all.csv is dataset-level (no per-cell-type group)
                            String group = (groupCol != null) ? rec.get(groupCol) : "All";

                            Map<String, String> row = new HashMap<>();
                            row.put("gene", geneName);
                            row.put("said", said);
                            row.put("gse", meta.get("GSE"));
                            row.put("gsm", meta.get("GSM"));
                            row.put("logfc", String.format("%.4f", logfc));
                            row.put("pval", String.format("%.2e", pval));
                            row.put("group", group);
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
}
