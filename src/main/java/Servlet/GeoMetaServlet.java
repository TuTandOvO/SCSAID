package Servlet;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.*;
import java.util.*;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import Utils.DataPathResolver;

@WebServlet("/geo_meta")
public class GeoMetaServlet extends HttpServlet {

    private static final Map<String, Map<String, String>> mapping;

    static {
        try (InputStreamReader reader = new InputStreamReader(
                GeoMetaServlet.class.getClassLoader().getResourceAsStream("mapping.csv.json"),
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

    private Map<String, Object> geoCache = null;
    private long geoCacheLastModified = 0;

    private synchronized Map<String, Object> loadGeoCache(String dataRoot) {
        File cacheFile = new File(dataRoot, "gse_metadata.json");
        if (!cacheFile.exists()) {
            return Collections.emptyMap();
        }
        if (geoCache != null && cacheFile.lastModified() == geoCacheLastModified) {
            return geoCache;
        }
        try (Reader r = new FileReader(cacheFile)) {
            geoCache = new Gson().fromJson(r, new TypeToken<Map<String, Object>>() {}.getType());
            geoCacheLastModified = cacheFile.lastModified();
            return geoCache;
        } catch (Exception e) {
            return Collections.emptyMap();
        }
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String said = request.getParameter("said");
        if (said == null || !said.matches("SAID\\d{3}")) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "A valid dataset accession is required");
            return;
        }

        Map<String, String> meta = mapping.get(said);
        response.setContentType("application/json;charset=UTF-8");
        PrintWriter out = response.getWriter();

        if (meta == null) {
            out.print("{}");
            return;
        }

        String gse = meta.get("GSE");
        String dataRoot = DataPathResolver.resolveDataRoot(getServletContext());
        Map<String, Object> cache = loadGeoCache(dataRoot);

        Object gseData = cache.get(gse);
        if (gseData != null) {
            new Gson().toJson(gseData, out);
        } else {
            // Return minimal info for non-GSE accessions (CRA, HRA)
            Map<String, String> minimal = new HashMap<>();
            minimal.put("gse", gse);
            minimal.put("title", "");
            minimal.put("summary", "");
            minimal.put("overall_design", "");
            new Gson().toJson(minimal, out);
        }
    }
}
