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
import java.util.Map;
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
            sendError(response, "Missing action parameter");
            return;
        }

        // Ensure server is running
        if (!ensureServerRunning()) {
            sendError(response, "CellPhoneDB server is not available");
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
                    sendError(response, "Unknown action: " + action);
            }
        } catch (Exception e) {
            e.printStackTrace();
            sendError(response, "Server error: " + e.getMessage());
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        String action = request.getParameter("action");

        if (action == null) {
            sendError(response, "Missing action parameter");
            return;
        }

        // Ensure server is running
        if (!ensureServerRunning()) {
            sendError(response, "CellPhoneDB server is not available");
            return;
        }

        try {
            if ("run-analysis".equals(action)) {
                handleRunAnalysis(request, response);
            } else {
                sendError(response, "Unknown action: " + action);
            }
        } catch (Exception e) {
            e.printStackTrace();
            sendError(response, "Server error: " + e.getMessage());
        }
    }

    private void handleCellTypes(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        String said = request.getParameter("said");
        if (said == null || said.isEmpty()) {
            sendError(response, "Missing said parameter");
            return;
        }

        String apiUrl = String.format("http://%s:%d/api/cell-types?said=%s",
                CPDB_HOST, CPDB_PORT, URLEncoder.encode(said, "UTF-8"));

        String result = proxyGetRequest(apiUrl);
        response.getWriter().write(result);
    }

    private void handleStatus(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        String jobId = request.getParameter("job_id");
        if (jobId == null || jobId.isEmpty()) {
            sendError(response, "Missing job_id parameter");
            return;
        }

        String apiUrl = String.format("http://%s:%d/api/status?job_id=%s",
                CPDB_HOST, CPDB_PORT, URLEncoder.encode(jobId, "UTF-8"));

        String result = proxyGetRequest(apiUrl);
        response.getWriter().write(result);
    }

    private void handleResults(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        String jobId = request.getParameter("job_id");
        if (jobId == null || jobId.isEmpty()) {
            sendError(response, "Missing job_id parameter");
            return;
        }

        String apiUrl = String.format("http://%s:%d/api/results?job_id=%s",
                CPDB_HOST, CPDB_PORT, URLEncoder.encode(jobId, "UTF-8"));

        String result = proxyGetRequest(apiUrl);
        response.getWriter().write(result);
    }

    private void handleHealth(HttpServletResponse response) throws IOException {
        String apiUrl = String.format("http://%s:%d/health", CPDB_HOST, CPDB_PORT);

        try {
            String result = proxyGetRequest(apiUrl);
            response.getWriter().write(result);
        } catch (Exception e) {
            Map<String, Object> health = new HashMap<>();
            health.put("status", "unhealthy");
            health.put("error", e.getMessage());
            response.getWriter().write(gson.toJson(health));
        }
    }

    private void handleRunAnalysis(HttpServletRequest request, HttpServletResponse response)
            throws IOException {

        String said = request.getParameter("said");
        String cellTypes = request.getParameter("cell_types");
        String senders = request.getParameter("senders");
        String receivers = request.getParameter("receivers");

        if (said == null || said.isEmpty()) {
            sendError(response, "Missing said parameter");
            return;
        }

        if (cellTypes == null || cellTypes.isEmpty()) {
            sendError(response, "Missing cell_types parameter");
            return;
        }

        String apiUrl = String.format("http://%s:%d/api/run-analysis", CPDB_HOST, CPDB_PORT);

        // Build POST data
        Map<String, String> postData = new HashMap<>();
        postData.put("said", said);
        postData.put("cell_types", cellTypes);
        if (senders != null && !senders.isEmpty()) {
            postData.put("senders", senders);
        }
        if (receivers != null && !receivers.isEmpty()) {
            postData.put("receivers", receivers);
        }

        String result = proxyPostRequest(apiUrl, postData);
        response.getWriter().write(result);
    }

    private String proxyGetRequest(String urlString) throws IOException {
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

        if (inputStream == null) {
            return "{\"error\": \"No response from server\"}";
        }

        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(inputStream, StandardCharsets.UTF_8))) {
            return reader.lines().collect(Collectors.joining("\n"));
        }
    }

    private String proxyPostRequest(String urlString, Map<String, String> data) throws IOException {
        URL url = new URL(urlString);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setConnectTimeout(10000);
        conn.setReadTimeout(300000); // 5 minutes for analysis
        conn.setRequestProperty("Content-Type", "application/json");

        // Write JSON body
        String jsonBody = gson.toJson(data);
        try (OutputStream os = conn.getOutputStream()) {
            os.write(jsonBody.getBytes(StandardCharsets.UTF_8));
        }

        int responseCode = conn.getResponseCode();
        InputStream inputStream;

        if (responseCode >= 200 && responseCode < 300) {
            inputStream = conn.getInputStream();
        } else {
            inputStream = conn.getErrorStream();
        }

        if (inputStream == null) {
            return "{\"error\": \"No response from server\"}";
        }

        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(inputStream, StandardCharsets.UTF_8))) {
            return reader.lines().collect(Collectors.joining("\n"));
        }
    }

    private void sendError(HttpServletResponse response, String message) throws IOException {
        Map<String, String> error = new HashMap<>();
        error.put("error", message);
        response.getWriter().write(gson.toJson(error));
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
        try {
            String apiUrl = String.format("http://%s:%d/health", CPDB_HOST, CPDB_PORT);
            URL url = new URL(apiUrl);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(2000);
            conn.setReadTimeout(2000);

            int responseCode = conn.getResponseCode();
            return responseCode == 200;
        } catch (Exception e) {
            return false;
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
