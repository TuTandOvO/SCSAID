package AccessCounter;

import com.google.gson.Gson;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Paginated developer-only view of the complete retained visit-event ledger. */
public final class DeveloperVisitEventsServlet extends HttpServlet {
    private static final Gson GSON = new Gson();
    private static final int DEFAULT_LIMIT = 100;

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        Object value = getServletContext().getAttribute("developerVisitEventStore");
        if (!(value instanceof DeveloperVisitEventStore)) {
            response.sendError(HttpServletResponse.SC_SERVICE_UNAVAILABLE,
                    "Visit event ledger is not ready");
            return;
        }

        int offset = parseInteger(request.getParameter("offset"), 0, 0, Integer.MAX_VALUE);
        int limit = parseInteger(request.getParameter("limit"), DEFAULT_LIMIT, 1, 200);
        String query = request.getParameter("q");
        DeveloperVisitEventStore.EventPage page =
                ((DeveloperVisitEventStore) value).eventPage(offset, limit, query);

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("runtime", getServletContext().getAttribute("visitorAnalyticsRuntime"));
        payload.put("generatedAt", Instant.now().toString());
        payload.put("timezone", "UTC");
        payload.put("retainedFields", List.of(
                "timestamp", "visitNumber", "visitorId", "address", "country",
                "regionCode", "regionName", "cityName", "accuracyRadiusKm",
                "accuracyLabel", "asnNumber", "networkOrganization", "browser",
                "operatingSystem", "language", "userAgentHash", "path"));
        payload.put("page", page);

        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
        response.setHeader("Pragma", "no-cache");
        GSON.toJson(payload, response.getWriter());
    }

    private static int parseInteger(String value, int fallback, int minimum, int maximum) {
        try {
            int parsed = Integer.parseInt(value == null ? "" : value.trim());
            return Math.max(minimum, Math.min(maximum, parsed));
        } catch (NumberFormatException ignored) {
            return fallback;
        }
    }
}
