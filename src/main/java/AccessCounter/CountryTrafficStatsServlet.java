package AccessCounter;

import com.google.gson.Gson;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.Map;

/** Authenticated JSON view of the developer-only visit ledger and aggregates. */
public final class CountryTrafficStatsServlet extends HttpServlet {
    private static final Gson GSON = new Gson();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        Object value = getServletContext().getAttribute("countryTrafficStore");
        if (!(value instanceof CountryTrafficStore)) {
            response.sendError(HttpServletResponse.SC_SERVICE_UNAVAILABLE,
                    "Country analytics is not ready");
            return;
        }

        CountryTrafficStore.Snapshot snapshot =
                ((CountryTrafficStore) value).snapshot(LocalDate.now(ZoneOffset.UTC));
        Object developerValue = getServletContext().getAttribute("developerVisitorStore");
        Object eventValue = getServletContext().getAttribute("developerVisitEventStore");
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("runtime", getServletContext().getAttribute("visitorAnalyticsRuntime"));
        payload.put("allTimeTotal", snapshot.allTimeTotal);
        payload.put("allTime", snapshot.allTime);
        payload.put("recent30DaysTotal", snapshot.recent30DaysTotal);
        payload.put("recent30Days", snapshot.recent30Days);
        payload.put("recentStart", snapshot.recentStart.toString());
        payload.put("recentEnd", snapshot.recentEnd.toString());
        if (developerValue instanceof DeveloperVisitorStore) {
            payload.put("recentVisitors", ((DeveloperVisitorStore) developerValue).recent(200));
        }
        if (eventValue instanceof DeveloperVisitEventStore) {
            DeveloperVisitEventStore.Snapshot eventSnapshot =
                    ((DeveloperVisitEventStore) eventValue).snapshot(java.time.Instant.now(), 5000);
            payload.put("visitAnalytics", eventSnapshot);
        }
        payload.put("privacy", "Developer-only view. Counted visit events and address aggregates are retained indefinitely.");

        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
        response.setHeader("Pragma", "no-cache");
        GSON.toJson(payload, response.getWriter());
    }
}
