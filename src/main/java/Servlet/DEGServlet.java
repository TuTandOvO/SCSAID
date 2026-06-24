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

@WebServlet("/deg")
public class DEGServlet extends HttpServlet {

    private static final Map<String, Map<String, String>> mapping;

    static {
        try (InputStreamReader reader = new InputStreamReader(
                DEGServlet.class.getClassLoader().getResourceAsStream("mapping.csv.json"),
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
        if (said == null || said.isEmpty()) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Missing parameter: said");
            return;
        }

        Map<String, String> meta = mapping.get(said);
        if (meta == null) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND, "SAID not found in mapping: " + said);
            return;
        }

        double pvalThreshold = parseDouble(request.getParameter("pval"), 0.05);
        double fcThreshold   = parseDouble(request.getParameter("fc"), 1.0);

        // Determine species from the csv_path in mapping
        String csvPath = meta.get("csv_path");
        String species;
        if (csvPath != null && csvPath.contains("/mouse/")) {
            species = "mouse";
        } else {
            species = "human";
        }

        String gse = meta.get("GSE");
        String gsm = meta.get("GSM");

        // Build the correct path: {dataRoot}/DEG/{species}/{GSE}/{GSM}/DEGs_all.csv
        String dataRoot = DataPathResolver.resolveDataRoot(getServletContext());
        File csvFile = new File(dataRoot, "DEG" + File.separator + species + File.separator
                + gse + File.separator + gsm + File.separator + "DEGs_all.csv");

        if (!csvFile.exists()) {
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().print("[]");
            return;
        }

        List<Map<String, String>> outList = new ArrayList<>();

        try (
                Reader in = new FileReader(csvFile);
                CSVParser parser = CSVFormat.DEFAULT
                        .withFirstRecordAsHeader()
                        .withIgnoreSurroundingSpaces()
                        .withTrim()
                        .parse(in)
        ) {
            // Build case-insensitive column name lookup
            Map<String, String> lowerToOrig = new HashMap<>();
            for (String orig : parser.getHeaderMap().keySet()) {
                lowerToOrig.put(orig.trim().toLowerCase(), orig);
            }

            // Column names in actual DEG files: gene, logfoldchange, pval_adj, score
            String geneCol  = lowerToOrig.getOrDefault("gene", lowerToOrig.get("names"));
            String fcCol    = lowerToOrig.getOrDefault("logfoldchange", lowerToOrig.get("logfoldchanges"));
            String pvalCol  = lowerToOrig.getOrDefault("pval_adj", lowerToOrig.get("pvals_adj"));
            String scoreCol = lowerToOrig.get("score");
            if (scoreCol == null) scoreCol = lowerToOrig.get("scores");

            if (geneCol == null || fcCol == null || pvalCol == null || scoreCol == null) {
                response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                        "CSV missing required columns. Found: " + parser.getHeaderMap().keySet());
                return;
            }

            // Optional group column
            String groupCol = lowerToOrig.get("group");
            String filterGroup = request.getParameter("group");

            for (CSVRecord rec : parser) {
                try {
                    String gene  = rec.get(geneCol);
                    double logfc = Double.parseDouble(rec.get(fcCol));
                    double pval  = Double.parseDouble(rec.get(pvalCol));
                    String score = rec.get(scoreCol);
                    String group = (groupCol != null) ? rec.get(groupCol) : "All";

                    if (pval <= pvalThreshold && logfc >= fcThreshold) {
                        if (filterGroup == null || filterGroup.isEmpty() || group.equals(filterGroup)) {
                            Map<String, String> row = new HashMap<>();
                            row.put("gene",           gene);
                            row.put("logfoldchanges", String.valueOf(logfc));
                            row.put("pvals_adj",      String.valueOf(pval));
                            row.put("scores",         score);
                            row.put("group",          group);
                            outList.add(row);
                        }
                    }
                } catch (NumberFormatException ignore) {
                }
            }

        } catch (IOException e) {
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Error reading CSV: " + e.getMessage());
            return;
        }

        response.setContentType("application/json;charset=UTF-8");
        new Gson().toJson(outList, response.getWriter());
    }

    private double parseDouble(String s, double def) {
        try {
            return Double.parseDouble(s);
        } catch (Exception e) {
            return def;
        }
    }
}
