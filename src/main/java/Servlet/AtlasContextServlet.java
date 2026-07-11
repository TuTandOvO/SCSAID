package Servlet;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.lang.reflect.Type;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Supplies the authoritative GSM -> scSAID dataset -> condition mapping used
 * by the integrated expression explorer.  Expression values remain in the
 * atlas service; this endpoint contains metadata only.
 */
public class AtlasContextServlet extends HttpServlet {
    private static final Gson GSON = new Gson();
    private static final List<Map<String, String>> RECORDS = loadRecords();

    private static List<Map<String, String>> loadRecords() {
        Type type = new TypeToken<List<Map<String, String>>>() { }.getType();
        try (InputStream in = AtlasContextServlet.class.getClassLoader()
                .getResourceAsStream("atlas-context.json")) {
            if (in == null) {
                throw new IllegalStateException("atlas-context.json is missing");
            }
            List<Map<String, String>> records = GSON.fromJson(
                    new InputStreamReader(in, StandardCharsets.UTF_8), type);
            return Collections.unmodifiableList(records);
        } catch (IOException | RuntimeException e) {
            throw new ExceptionInInitializerError(
                    "Unable to load atlas-context.json: " + e.getMessage());
        }
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String species = (request.getParameter("species") == null)
                ? "" : request.getParameter("species").trim().toLowerCase(Locale.ROOT);
        if (!species.isEmpty() && !"human".equals(species) && !"mouse".equals(species)) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Invalid species");
            return;
        }

        List<Map<String, String>> selected = RECORDS;
        if (!species.isEmpty()) {
            selected = new ArrayList<>();
            for (Map<String, String> record : RECORDS) {
                if (species.equals(record.get("species"))) {
                    selected.add(record);
                }
            }
        }

        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "public, max-age=86400");
        GSON.toJson(Collections.singletonMap("datasets", selected), response.getWriter());
    }
}
