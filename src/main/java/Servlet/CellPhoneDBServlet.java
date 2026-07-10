package Servlet;

import com.google.gson.Gson;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Servlet for CellPhoneDB Dynamic Analysis
 * Proxies requests to Python Flask API running on port 8054
 */
@WebServlet("/cpdb-api")
public class CellPhoneDBServlet extends HttpServlet {

    private static final int CPDB_PORT = 8054;
    private static final String CPDB_HOST = "127.0.0.1";
    private static Process cpdbProcess;
    private static boolean serverStarted = false;
    private static volatile boolean consolidatedApi = true;
    private static final Object processLock = new Object();

    private final Gson gson = new Gson();

    @Override
    public void init() throws ServletException {
        super.init();
        // Attempt to start the Python server on servlet init
        startCpdbServerIfNeeded();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        String action = request.getParameter("action");

        if (action == null) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, "Missing action parameter");
            return;
        }

        // Ensure server is running
        if (!ensureServerRunning()) {
            sendError(response, HttpServletResponse.SC_SERVICE_UNAVAILABLE, "CellPhoneDB server is not available");
            return;
        }

        try {
            switch (action) {
                case "cell-types":
                    handleCellTypes(request, response);
                    break;
                case "status":
                    handleStatus(request, response);
                    break;
                case "results":
                    handleResults(request, response);
                    break;
                case "health":
                    handleHealth(response);
                    break;
                default:
                    sendError(response, HttpServletResponse.SC_BAD_REQUEST, "Unknown action");
            }
        } catch (Exception e) {
            getServletContext().log("CellPhoneDB request failed", e);
            sendError(response, HttpServletResponse.SC_BAD_GATEWAY, "CellPhoneDB request failed");
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        String action = request.getParameter("action");

        if (action == null) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, "Missing action parameter");
            return;
        }

        // Ensure server is running
        if (!ensureServerRunning()) {
            sendError(response, HttpServletResponse.SC_SERVICE_UNAVAILABLE, "CellPhoneDB server is not available");
            return;
        }

        try {
            if ("run-analysis".equals(action)) {
                handleRunAnalysis(request, response);
            } else {
                sendError(response, HttpServletResponse.SC_BAD_REQUEST, "Unknown action");
            }
        } catch (Exception e) {
            getServletContext().log("CellPhoneDB analysis request failed", e);
            sendError(response, HttpServletResponse.SC_BAD_GATEWAY, "CellPhoneDB analysis request failed");
        }
    }

    private void handleCellTypes(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        String said = request.getParameter("said");
        String level = request.getParameter("level");
        if (said == null || !said.matches("SAID\\d{3}")) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, "A valid dataset accession is required");
            return;
        }
        if (level == null) level = "";
        if (!level.isEmpty() && !level.equals("fine") && !level.equals("gross")) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, "Invalid annotation level");
            return;
        }

        String apiUrl = consolidatedApi
                ? String.format("http://%s:%d/api?action=cell-types&said=%s&level=%s",
                    CPDB_HOST, CPDB_PORT, enc(said), enc(level))
                : String.format("http://%s:%d/api/cell-types?said=%s&level=%s",
                    CPDB_HOST, CPDB_PORT, enc(said), enc(level));

        writeUpstream(response, proxyGetRequest(apiUrl));
    }

    private void handleStatus(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        String jobId = request.getParameter("job_id");
        if (!validJobId(jobId) || !ownsJob(request, jobId)) {
            sendError(response, HttpServletResponse.SC_NOT_FOUND, "Unknown job");
            return;
        }

        String apiUrl = consolidatedApi
                ? String.format("http://%s:%d/api?action=status&job_id=%s",
                    CPDB_HOST, CPDB_PORT, enc(jobId))
                : String.format("http://%s:%d/api/status?job_id=%s",
                    CPDB_HOST, CPDB_PORT, enc(jobId));

        writeUpstream(response, proxyGetRequest(apiUrl));
    }

    private void handleResults(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        String jobId = request.getParameter("job_id");
        if (!validJobId(jobId) || !ownsJob(request, jobId)) {
            sendError(response, HttpServletResponse.SC_NOT_FOUND, "Unknown job");
            return;
        }

        String apiUrl = consolidatedApi
                ? String.format("http://%s:%d/api?action=results&job_id=%s",
                    CPDB_HOST, CPDB_PORT, enc(jobId))
                : String.format("http://%s:%d/api/results?job_id=%s",
                    CPDB_HOST, CPDB_PORT, enc(jobId));

        writeUpstream(response, proxyGetRequest(apiUrl));
    }

    private void handleHealth(HttpServletResponse response) throws IOException {
        Map<String, Object> health = new HashMap<>();
        boolean healthy = isServerHealthy();
        health.put("status", healthy ? "healthy" : "unhealthy");
        response.setStatus(healthy
                ? HttpServletResponse.SC_OK
                : HttpServletResponse.SC_SERVICE_UNAVAILABLE);
        response.getWriter().write(gson.toJson(health));
    }

    private void handleRunAnalysis(HttpServletRequest request, HttpServletResponse response)
            throws IOException {

        String said = request.getParameter("said");
        String cellTypes = request.getParameter("cell_types");
        String senders = request.getParameter("senders");
        String receivers = request.getParameter("receivers");
        String level = request.getParameter("level");

        if (said == null || !said.matches("SAID\\d{3}")) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, "A valid dataset accession is required");
            return;
        }

        if (cellTypes == null || cellTypes.isEmpty() || cellTypes.length() > 20_000
                || (senders != null && senders.length() > 20_000)
                || (receivers != null && receivers.length() > 20_000)) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, "Invalid cell-type selection");
            return;
        }
        if (level == null) level = "";
        if (!level.isEmpty() && !level.equals("fine") && !level.equals("gross")) {
            sendError(response, HttpServletResponse.SC_BAD_REQUEST, "Invalid annotation level");
            return;
        }

        String apiUrl = consolidatedApi
                ? String.format("http://%s:%d/api?action=run-analysis", CPDB_HOST, CPDB_PORT)
                : String.format("http://%s:%d/api/run-analysis", CPDB_HOST, CPDB_PORT);

        // Build POST data
        Map<String, String> postData = new HashMap<>();
        postData.put("said", said);
        postData.put("cell_types", cellTypes);
        postData.put("level", level);
        if (senders != null && !senders.isEmpty()) {
            postData.put("senders", senders);
        }
        if (receivers != null && !receivers.isEmpty()) {
            postData.put("receivers", receivers);
        }

        UpstreamResponse upstream = proxyPostRequest(apiUrl, postData, consolidatedApi);
        String result = upstream.body;
        try {
            com.google.gson.JsonObject payload = gson.fromJson(result, com.google.gson.JsonObject.class);
            if (upstream.isSuccess() && payload != null && payload.has("job_id")
                    && validJobId(payload.get("job_id").getAsString())) {
                rememberJob(request, payload.get("job_id").getAsString());
            } else {
                response.setStatus(upstream.isSuccess()
                        ? HttpServletResponse.SC_BAD_GATEWAY : upstream.status);
            }
        } catch (Exception invalidResponse) {
            throw new IOException("CellPhoneDB returned an invalid job response");
        }
        response.getWriter().write(result);
    }

    private UpstreamResponse proxyGetRequest(String urlString) throws IOException {
        URL url = new URL(urlString);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("GET");
        conn.setConnectTimeout(10000);
        conn.setReadTimeout(60000);

        int responseCode = conn.getResponseCode();
        InputStream inputStream;

        if (responseCode >= 200 && responseCode < 300) {
            inputStream = conn.getInputStream();
        } else {
            inputStream = conn.getErrorStream();
        }

        if (inputStream == null) return new UpstreamResponse(responseCode,
                "{\"error\":\"No response from analysis service\"}");

        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(inputStream, StandardCharsets.UTF_8))) {
            return new UpstreamResponse(responseCode,
                    reader.lines().collect(Collectors.joining("\n")));
        } finally {
            conn.disconnect();
        }
    }

    private UpstreamResponse proxyPostRequest(String urlString, Map<String, String> data,
            boolean formEncoded) throws IOException {
        URL url = new URL(urlString);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setConnectTimeout(10000);
        conn.setReadTimeout(300000); // 5 minutes for analysis
        conn.setRequestProperty("Content-Type", formEncoded
                ? "application/x-www-form-urlencoded; charset=UTF-8"
                : "application/json; charset=UTF-8");

        String requestBody = formEncoded ? formEncode(data) : gson.toJson(data);
        try (OutputStream os = conn.getOutputStream()) {
            os.write(requestBody.getBytes(StandardCharsets.UTF_8));
        }

        int responseCode = conn.getResponseCode();
        InputStream inputStream;

        if (responseCode >= 200 && responseCode < 300) {
            inputStream = conn.getInputStream();
        } else {
            inputStream = conn.getErrorStream();
        }

        if (inputStream == null) return new UpstreamResponse(responseCode,
                "{\"error\":\"No response from analysis service\"}");

        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(inputStream, StandardCharsets.UTF_8))) {
            return new UpstreamResponse(responseCode,
                    reader.lines().collect(Collectors.joining("\n")));
        } finally {
            conn.disconnect();
        }
    }

    private static String formEncode(Map<String, String> data) {
        return data.entrySet().stream()
                .map(entry -> enc(entry.getKey()) + "=" + enc(entry.getValue()))
                .collect(Collectors.joining("&"));
    }

    private static String enc(String value) {
        try {
            return URLEncoder.encode(value == null ? "" : value, "UTF-8");
        } catch (java.io.UnsupportedEncodingException impossible) {
            throw new IllegalStateException(impossible);
        }
    }

    private static void writeUpstream(HttpServletResponse response, UpstreamResponse upstream)
            throws IOException {
        response.setStatus(upstream.status);
        response.getWriter().write(upstream.body);
    }

    private static final class UpstreamResponse {
        final int status;
        final String body;

        UpstreamResponse(int status, String body) {
            this.status = status;
            this.body = body;
        }

        boolean isSuccess() {
            return status >= 200 && status < 300;
        }
    }

    private void sendError(HttpServletResponse response, int status, String message) throws IOException {
        response.setStatus(status);
        response.setHeader("Cache-Control", "no-store");
        Map<String, String> error = new HashMap<>();
        error.put("error", message);
        response.getWriter().write(gson.toJson(error));
    }

    @SuppressWarnings("unchecked")
    private static void rememberJob(HttpServletRequest request, String jobId) {
        if (!validJobId(jobId)) return;
        synchronized (request.getSession(true)) {
            Set<String> jobs = (Set<String>) request.getSession().getAttribute("cpdbJobIds");
            if (jobs == null) {
                jobs = new HashSet<>();
                request.getSession().setAttribute("cpdbJobIds", jobs);
            }
            jobs.add(jobId);
        }
    }

    @SuppressWarnings("unchecked")
    private static boolean ownsJob(HttpServletRequest request, String jobId) {
        if (request.getSession(false) == null) return false;
        Object jobs = request.getSession(false).getAttribute("cpdbJobIds");
        return jobs instanceof Set && ((Set<String>) jobs).contains(jobId);
    }

    private static boolean validJobId(String jobId) {
        return jobId != null && (jobId.matches("[0-9a-fA-F]{8}")
                || jobId.matches("[0-9a-fA-F-]{36}"));
    }

    private boolean ensureServerRunning() {
        synchronized (processLock) {
            if (serverStarted && isServerHealthy()) {
                return true;
            }
            return startCpdbServerIfNeeded();
        }
    }

    private boolean startCpdbServerIfNeeded() {
        synchronized (processLock) {
            // Check if already running
            if (isServerHealthy()) {
                serverStarted = true;
                return true;
            }

            // Get path to Python script
            String webappPath = getServletContext().getRealPath("/");
            String scriptPath = webappPath + "cpdb_resources/cpdb_analysis.py";

            File scriptFile = new File(scriptPath);
            if (!scriptFile.exists()) {
                System.err.println("CellPhoneDB script not found: " + scriptPath);
                return false;
            }

            try {
                // Try to use conda environment
                ProcessBuilder pb = new ProcessBuilder(
                        "python3", scriptPath,
                        "--port", String.valueOf(CPDB_PORT),
                        "--host", CPDB_HOST
                );

                pb.directory(new File(webappPath + "cpdb_resources"));
                pb.redirectErrorStream(true);

                cpdbProcess = pb.start();

                // Start output monitoring thread
                new Thread(() -> {
                    try (BufferedReader reader = new BufferedReader(
                            new InputStreamReader(cpdbProcess.getInputStream()))) {
                        String line;
                        while ((line = reader.readLine()) != null) {
                            System.out.println("[CPDB] " + line);
                        }
                    } catch (IOException e) {
                        System.err.println("Error reading CPDB output: " + e.getMessage());
                    }
                }).start();

                // Wait for server to start
                Thread.sleep(5000);

                // Check if healthy
                if (isServerHealthy()) {
                    serverStarted = true;
                    System.out.println("CellPhoneDB server started on port " + CPDB_PORT);
                    return true;
                } else {
                    System.err.println("CellPhoneDB server failed to start");
                    return false;
                }

            } catch (Exception e) {
                System.err.println("Error starting CellPhoneDB server: " + e.getMessage());
                e.printStackTrace();
                return false;
            }
        }
    }

    private boolean isServerHealthy() {
        String consolidatedHealth = String.format(
                "http://%s:%d/api/conditions?species=human", CPDB_HOST, CPDB_PORT);
        if (probe(consolidatedHealth)) {
            consolidatedApi = true;
            return true;
        }
        String restHealth = String.format("http://%s:%d/health", CPDB_HOST, CPDB_PORT);
        if (probe(restHealth)) {
            consolidatedApi = false;
            return true;
        }
        return false;
    }

    private static boolean probe(String apiUrl) {
        HttpURLConnection conn = null;
        try {
            conn = (HttpURLConnection) new URL(apiUrl).openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(2000);
            conn.setReadTimeout(2000);
            return conn.getResponseCode() == HttpURLConnection.HTTP_OK;
        } catch (Exception e) {
            return false;
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    @Override
    public void destroy() {
        synchronized (processLock) {
            if (cpdbProcess != null && cpdbProcess.isAlive()) {
                System.out.println("Stopping CellPhoneDB server...");
                cpdbProcess.destroy();
                try {
                    cpdbProcess.waitFor();
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
            serverStarted = false;
        }
        super.destroy();
    }
}
