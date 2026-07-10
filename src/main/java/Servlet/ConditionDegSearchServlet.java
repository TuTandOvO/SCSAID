package Servlet;

import Utils.DataPathResolver;
import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.reflect.TypeToken;

import javax.servlet.ServletContext;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.lang.reflect.Type;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Cached all-vs-Healthy DEG search.
 *
 * The heavy computation is delegated to the existing condition-comparison API
 * on port 8054. This servlet warms a species-specific cache of every
 * non-Healthy condition versus Healthy and then answers gene searches from the
 * cache rather than launching many comparison jobs per user query.
 */
public class ConditionDegSearchServlet extends HttpServlet {
    private static final Gson GSON = new Gson();
    private static final String API_BASE = "http://127.0.0.1:8054";
    private static final int MAX_RESULTS = 500;
    private static final int POLL_INTERVAL_MS = 2000;
    private static final int MAX_POLLS_PER_CONDITION = 3600; // 2 h/contrast ceiling.
    private static final String HEALTHY = "Healthy";
    private static final String HEADER = "species\tcondition\treference\tcell_type\tgene\tlogFC\tpval\tpval_adj\n";
    private static final Object BUILD_LOCK = new Object();

    private static final Map<String, BuildState> STATES = new ConcurrentHashMap<String, BuildState>();
    private static final Type ROW_LIST_TYPE = new TypeToken<List<Map<String, Object>>>() {}.getType();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String path = req.getServletPath();
        resp.setCharacterEncoding("UTF-8");
        resp.setContentType("application/json");
        resp.setHeader("Cache-Control", "no-store");

        String species = normalizeSpecies(req.getParameter("species"));
        if (species == null) {
            resp.sendError(HttpServletResponse.SC_BAD_REQUEST, "species must be human or mouse");
            return;
        }

        if (path.endsWith("/status")) {
            writeStatus(species, getServletContext(), resp);
            return;
        }

        if (!cacheFile(getServletContext(), species).exists()) {
            writeJson(resp, statusPayload(species, getServletContext()));
            return;
        }

        String q = trim(req.getParameter("q"));
        if (q.isEmpty()) {
            resp.sendError(HttpServletResponse.SC_BAD_REQUEST, "Missing query parameter: q");
            return;
        }

        SearchParams params = SearchParams.from(req);
        writeJson(resp, searchCache(species, q, params, getServletContext()));
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        // Cache construction is an administrative deployment task. Keeping it
        // off the public request path prevents an anonymous visitor from
        // launching hours of server-side comparisons.
        resp.sendError(HttpServletResponse.SC_METHOD_NOT_ALLOWED,
                "The DEG index is built by the server administrator.");
    }

    private static void writeStatus(String species, ServletContext context, HttpServletResponse resp) throws IOException {
        writeJson(resp, statusPayload(species, context));
    }

    private static Map<String, Object> statusPayload(String species, ServletContext context) {
        Map<String, Object> payload = new LinkedHashMap<String, Object>();
        BuildState state = STATES.get(species);
        File cache = cacheFile(context, species);
        File meta = metaFile(context, species);

        if (state != null && state.building) {
            payload.put("state", "building");
            payload.put("species", species);
            payload.put("currentCondition", state.currentCondition);
            payload.put("doneConditions", state.doneConditions);
            payload.put("totalConditions", state.totalConditions);
            payload.put("message", state.message);
            if (state.error != null) payload.put("error", state.error);
            return payload;
        }

        if (cache.exists()) {
            payload.put("state", "ready");
            payload.put("species", species);
            payload.put("updatedAt", cache.lastModified());
            if (meta.exists()) {
                try (BufferedReader reader = Files.newBufferedReader(meta.toPath(), StandardCharsets.UTF_8)) {
                    JsonObject json = JsonParser.parseReader(reader).getAsJsonObject();
                    payload.put("rows", getLong(json, "rows", -1));
                    payload.put("conditions", getLong(json, "conditions", -1));
                    payload.put("skipped", getLong(json, "skipped", 0));
                } catch (Exception ignored) {
                }
            }
            return payload;
        }

        payload.put("state", (state != null && state.error != null) ? "error" : "missing");
        payload.put("species", species);
        if (state != null && state.error != null) payload.put("error", state.error);
        return payload;
    }

    private static synchronized void startBuild(String species, ServletContext context) {
        BuildState state = STATES.get(species);
        if (state != null && state.building) return;

        final BuildState next = new BuildState();
        next.building = true;
        next.message = "Preparing " + species + " condition-vs-Healthy DEG index";
        STATES.put(species, next);

        Thread worker = new Thread(new Runnable() {
            @Override
            public void run() {
                buildCache(species, context, next);
            }
        }, "condition-deg-cache-" + species);
        worker.setDaemon(true);
        worker.start();
    }

    private static void buildCache(String species, ServletContext context, BuildState state) {
        state.message = "Waiting for the current DEG index build to finish";
        synchronized (BUILD_LOCK) {
            buildCacheLocked(species, context, state);
        }
    }

    private static void buildCacheLocked(String species, ServletContext context, BuildState state) {
        File dir = cacheDir(context);
        if (!dir.exists() && !dir.mkdirs()) {
            state.error = "Cannot create DEG cache directory: " + dir.getAbsolutePath();
            state.building = false;
            return;
        }

        File tmp = new File(dir, species + ".tsv.tmp");
        File out = new File(dir, species + ".tsv");
        File meta = new File(dir, species + ".meta.json");

        long rows = 0L;
        int conditionsDone = 0;
        List<String> skipped = new ArrayList<String>();

        try (BufferedWriter writer = Files.newBufferedWriter(tmp.toPath(), StandardCharsets.UTF_8)) {
            writer.write(HEADER);
            List<Map<String, Object>> conditions = fetchJsonList("/api/conditions?species=" + enc(species));
            List<String> conditionNames = new ArrayList<String>();
            for (Map<String, Object> item : conditions) {
                String condition = asString(item.get("condition"));
                if (!condition.isEmpty() && !HEALTHY.equals(condition)) {
                    conditionNames.add(condition);
                }
            }

            state.totalConditions = conditionNames.size();
            for (String condition : conditionNames) {
                state.currentCondition = condition;
                state.message = "Running " + species + ": " + condition + " vs Healthy";

                try {
                    String jobId = startComparisonJob(species, condition, HEALTHY);
                    JsonObject done = waitForJob(jobId);
                    JsonArray cellTypes = done.has("cellTypes") && done.get("cellTypes").isJsonArray()
                            ? done.getAsJsonArray("cellTypes") : new JsonArray();

                    if (cellTypes.size() == 0) {
                        rows += writeRowsForJob(writer, species, condition, jobId, "");
                    } else {
                        for (JsonElement ctElement : cellTypes) {
                            rows += writeRowsForJob(writer, species, condition, jobId, ctElement.getAsString());
                        }
                    }
                } catch (Exception conditionFailed) {
                    skipped.add(condition + ": " + conditionFailed.getMessage());
                    state.error = "Skipped " + skipped.size() + " contrast(s); continuing";
                }

                conditionsDone++;
                state.doneConditions = conditionsDone;
            }
        } catch (Exception e) {
            state.error = e.getMessage();
            state.message = "DEG index build failed";
            tmp.delete();
            state.building = false;
            return;
        }

        try {
            Files.move(tmp.toPath(), out.toPath(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        } catch (Exception atomicMoveFailed) {
            try {
                try {
                    Files.move(tmp.toPath(), out.toPath(), StandardCopyOption.REPLACE_EXISTING);
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
            } catch (RuntimeException e) {
                state.error = "Cannot publish DEG cache: " + e.getMessage();
                state.building = false;
                return;
            }
        }

        Map<String, Object> metadata = new LinkedHashMap<String, Object>();
        metadata.put("species", species);
        metadata.put("reference", HEALTHY);
        metadata.put("conditions", conditionsDone);
        metadata.put("rows", rows);
        metadata.put("skipped", skipped.size());
        metadata.put("skippedDetails", skipped);
        metadata.put("updatedAt", System.currentTimeMillis());
        try (BufferedWriter writer = Files.newBufferedWriter(meta.toPath(), StandardCharsets.UTF_8)) {
            GSON.toJson(metadata, writer);
        } catch (IOException ignored) {
        }

        state.message = "Ready";
        state.currentCondition = "";
        state.building = false;
    }

    private static long writeRowsForJob(BufferedWriter writer, String species, String condition,
                                        String jobId, String cellType) throws IOException {
        String query = "/api/condition-compare/result?jobId=" + enc(jobId)
                + "&pval=1&fc=0"
                + (cellType == null || cellType.isEmpty() ? "" : "&cellType=" + enc(cellType));
        List<Map<String, Object>> rows = fetchJsonList(query);
        long written = 0L;
        for (Map<String, Object> row : rows) {
            String gene = asString(row.get("gene"));
            if (gene.isEmpty()) continue;
            writer.write(tsv(species));
            writer.write('\t');
            writer.write(tsv(condition));
            writer.write('\t');
            writer.write(HEALTHY);
            writer.write('\t');
            writer.write(tsv(asString(row.get("cell_type"))));
            writer.write('\t');
            writer.write(tsv(gene));
            writer.write('\t');
            writer.write(asString(row.get("logFC")));
            writer.write('\t');
            writer.write(asString(row.get("pval")));
            writer.write('\t');
            writer.write(asString(row.get("pval_adj")));
            writer.write('\n');
            written++;
        }
        return written;
    }

    private static String startComparisonJob(String species, String conditionA, String conditionB) throws IOException {
        JsonObject body = new JsonObject();
        body.addProperty("species", species);
        body.addProperty("conditionA", conditionA);
        body.addProperty("conditionB", conditionB);
        JsonObject response = postJson("/api/condition-compare/run", body.toString());
        String jobId = getString(response, "jobId");
        if (jobId == null || jobId.trim().isEmpty()) {
            throw new IOException("Comparison service did not return a jobId for " + conditionA);
        }
        return jobId;
    }

    private static JsonObject waitForJob(String jobId) throws IOException, InterruptedException {
        for (int i = 0; i < MAX_POLLS_PER_CONDITION; i++) {
            JsonObject status = fetchJsonObject("/api/condition-compare/status?jobId=" + enc(jobId));
            String state = getString(status, "state");
            if ("done".equals(state)) return status;
            if ("error".equals(state)) {
                throw new IOException("Comparison job failed: " + getString(status, "error"));
            }
            Thread.sleep(POLL_INTERVAL_MS);
        }
        throw new IOException("Comparison job timed out: " + jobId);
    }

    private static Map<String, Object> searchCache(String species, String rawQuery, SearchParams params,
                                                   ServletContext context) throws IOException {
        String query = rawQuery.toLowerCase(Locale.ROOT);
        List<Map<String, Object>> results = new ArrayList<Map<String, Object>>();
        int total = 0;

        try (BufferedReader reader = Files.newBufferedReader(cacheFile(context, species).toPath(), StandardCharsets.UTF_8)) {
            String line = reader.readLine(); // header
            while ((line = reader.readLine()) != null) {
                String[] parts = line.split("\t", -1);
                if (parts.length < 8) continue;

                String condition = parts[1];
                String cellType = parts[3];
                String gene = parts[4];
                double logFC = parseDouble(parts[5], Double.NaN);
                double pval = parseDouble(parts[6], Double.NaN);
                double padj = parseDouble(parts[7], Double.NaN);

                if (!gene.toLowerCase(Locale.ROOT).contains(query)) continue;
                if (!params.condition.isEmpty() && !params.condition.equals(condition)) continue;
                if (!params.cellType.isEmpty() && !params.cellType.equals(cellType)) continue;
                if (!Double.isNaN(padj) && padj > params.pval) continue;
                if (!Double.isNaN(logFC) && Math.abs(logFC) < params.fc) continue;
                if ("up".equals(params.direction) && !(logFC > 0)) continue;
                if ("down".equals(params.direction) && !(logFC < 0)) continue;
                if (params.hidePseudogenes && isPseudogene(gene)) continue;

                total++;
                Map<String, Object> row = new LinkedHashMap<String, Object>();
                row.put("gene", gene);
                row.put("species", parts[0]);
                row.put("condition", condition);
                row.put("reference", parts[2]);
                row.put("cell_type", cellType);
                row.put("logFC", logFC);
                row.put("pval", pval);
                row.put("pval_adj", padj);
                results.add(row);
            }
        }

        results.sort(new Comparator<Map<String, Object>>() {
            @Override
            public int compare(Map<String, Object> a, Map<String, Object> b) {
                return Double.compare(asDouble(a.get("pval_adj")), asDouble(b.get("pval_adj")));
            }
        });
        if (results.size() > MAX_RESULTS) {
            results = new ArrayList<Map<String, Object>>(results.subList(0, MAX_RESULTS));
        }

        Map<String, Object> payload = new LinkedHashMap<String, Object>();
        payload.put("state", "ready");
        payload.put("species", species);
        payload.put("query", rawQuery);
        payload.put("count", total);
        payload.put("results", results);
        return payload;
    }

    private static List<Map<String, Object>> fetchJsonList(String path) throws IOException {
        JsonElement element = fetchJson(path);
        return GSON.fromJson(element, ROW_LIST_TYPE);
    }

    private static JsonObject fetchJsonObject(String path) throws IOException {
        return fetchJson(path).getAsJsonObject();
    }

    private static JsonObject postJson(String path, String body) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) new URL(API_BASE + path).openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(60000);
        try (OutputStream out = conn.getOutputStream()) {
            out.write(body.getBytes(StandardCharsets.UTF_8));
        }
        return readJsonResponse(conn).getAsJsonObject();
    }

    private static JsonElement fetchJson(String path) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) new URL(API_BASE + path).openConnection();
        conn.setRequestMethod("GET");
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(60000);
        return readJsonResponse(conn);
    }

    private static JsonElement readJsonResponse(HttpURLConnection conn) throws IOException {
        int code = conn.getResponseCode();
        InputStream in = code >= 400 ? conn.getErrorStream() : conn.getInputStream();
        StringBuilder sb = new StringBuilder();
        if (in != null) {
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) sb.append(line);
            }
        }
        if (code >= 400) {
            throw new IOException("Comparison service HTTP " + code + ": " + sb);
        }
        return JsonParser.parseString(sb.toString());
    }

    private static File cacheDir(ServletContext context) {
        return new File(new File(DataPathResolver.resolveDataRoot(context), "runtime"), "condition_deg_index");
    }

    private static File cacheFile(ServletContext context, String species) {
        return new File(cacheDir(context), species + ".tsv");
    }

    private static File metaFile(ServletContext context, String species) {
        return new File(cacheDir(context), species + ".meta.json");
    }

    private static void writeJson(HttpServletResponse resp, Object payload) throws IOException {
        try (OutputStreamWriter writer = new OutputStreamWriter(resp.getOutputStream(), StandardCharsets.UTF_8)) {
            GSON.toJson(payload, writer);
        }
    }

    private static String normalizeSpecies(String value) {
        String s = trim(value).toLowerCase(Locale.ROOT);
        return ("human".equals(s) || "mouse".equals(s)) ? s : null;
    }

    private static String readBody(HttpServletRequest req) throws IOException {
        StringBuilder body = new StringBuilder();
        try (BufferedReader reader = req.getReader()) {
            String line;
            while ((line = reader.readLine()) != null) body.append(line);
        }
        return body.toString();
    }

    private static String getString(JsonObject object, String key) {
        return object != null && object.has(key) && !object.get(key).isJsonNull()
                ? object.get(key).getAsString() : null;
    }

    private static long getLong(JsonObject object, String key, long fallback) {
        try {
            return object.has(key) ? object.get(key).getAsLong() : fallback;
        } catch (Exception e) {
            return fallback;
        }
    }

    private static String trim(String value) {
        return value == null ? "" : value.trim();
    }

    private static String asString(Object value) {
        return value == null ? "" : String.valueOf(value);
    }

    private static double asDouble(Object value) {
        return parseDouble(asString(value), Double.POSITIVE_INFINITY);
    }

    private static double parseDouble(String value, double fallback) {
        try {
            return Double.parseDouble(value);
        } catch (Exception e) {
            return fallback;
        }
    }

    private static String enc(String value) throws IOException {
        return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8.name());
    }

    private static String tsv(String value) {
        return (value == null ? "" : value).replace('\t', ' ').replace('\n', ' ').replace('\r', ' ');
    }

    private static boolean isPseudogene(String gene) {
        return gene != null && gene.matches("^(Gm\\d+|.+-ps\\d*|.+Rik|.+-PS\\d*)$");
    }

    private static final class BuildState {
        volatile boolean building;
        volatile String currentCondition = "";
        volatile int doneConditions;
        volatile int totalConditions;
        volatile String message = "";
        volatile String error;
    }

    private static final class SearchParams {
        final double pval;
        final double fc;
        final String direction;
        final String condition;
        final String cellType;
        final boolean hidePseudogenes;

        private SearchParams(double pval, double fc, String direction, String condition, String cellType,
                             boolean hidePseudogenes) {
            this.pval = pval;
            this.fc = fc;
            this.direction = direction;
            this.condition = condition;
            this.cellType = cellType;
            this.hidePseudogenes = hidePseudogenes;
        }

        static SearchParams from(HttpServletRequest req) {
            String direction = trim(req.getParameter("direction")).toLowerCase(Locale.ROOT);
            if (!"up".equals(direction) && !"down".equals(direction)) direction = "both";
            String hide = trim(req.getParameter("hidePseudogenes")).toLowerCase(Locale.ROOT);
            return new SearchParams(
                    parseDouble(req.getParameter("pval"), 0.05),
                    parseDouble(req.getParameter("fc"), 1.0),
                    direction,
                    trim(req.getParameter("condition")),
                    trim(req.getParameter("cellType")),
                    hide.isEmpty() || "true".equals(hide) || "1".equals(hide)
            );
        }
    }
}
