package AccessCounter;

import com.google.gson.Gson;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

/** Read-only, uncached JSON endpoint for the live footer traffic charts. */
public class TrafficStatsServlet extends HttpServlet {
    private static final Gson GSON = new Gson();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        Object storeObject = getServletContext().getAttribute("trafficHistoryStore");
        if (!(storeObject instanceof TrafficHistoryStore)) {
            response.sendError(HttpServletResponse.SC_SERVICE_UNAVAILABLE,
                    "Traffic history is not ready");
            return;
        }

        TrafficHistoryStore.Snapshot snapshot =
                ((TrafficHistoryStore) storeObject).snapshot(Instant.now());
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("generatedAt", Instant.now().toString());
        payload.put("timezone", "UTC");
        payload.put("historySince", snapshot.historyStart == null
                ? null : snapshot.historyStart.toString());
        payload.put("totalVisits", atomicValue("totalCount"));
        payload.put("todayVisits", atomicValue("dailyCount"));

        Map<String, Object> last24 = new LinkedHashMap<>();
        last24.put("labels", snapshot.last24Labels);
        last24.put("values", snapshot.last24Values);
        last24.put("total", snapshot.last24Total);
        payload.put("last24", last24);

        Map<String, Object> average = new LinkedHashMap<>();
        average.put("labels", snapshot.averageLabels);
        average.put("values", snapshot.averageValues);
        average.put("daysIncluded", snapshot.daysIncluded);
        average.put("averageDaily", snapshot.averageDaily);
        payload.put("average", average);

        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
        response.setHeader("Pragma", "no-cache");
        GSON.toJson(payload, response.getWriter());
    }

    private long atomicValue(String attribute) {
        Object value = getServletContext().getAttribute(attribute);
        return value instanceof AtomicLong ? ((AtomicLong) value).get() : 0L;
    }
}
