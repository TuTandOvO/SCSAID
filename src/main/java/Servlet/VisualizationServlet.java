package Servlet;

import com.google.gson.Gson;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Servlet for managing the Interactive Visualization Suite
 * Handles starting/stopping the Python Dash visualization server
 */
@WebServlet("/visualization")
public class VisualizationServlet extends HttpServlet {

    // Store running visualization processes
    private static final Map<String, Process> runningProcesses = new ConcurrentHashMap<>();
    private static final int VIZ_PORT_BASE = 8050;

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String datasetId = request.getParameter("dataset");
        String vizType = request.getParameter("type"); // Added to distinguish between integrated and individual
        String direct = request.getParameter("direct"); // Parameter to indicate direct visualization access

        if (datasetId == null || datasetId.isEmpty()) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Dataset ID is required");
            return;
        }

        // Default to individual visualization if not specified
        if (vizType == null || vizType.isEmpty()) {
            vizType = "individual";
        }

        try {
            String datasetPath = null;

            if ("individual".equals(vizType)) {
                // Get individual dataset path
                datasetPath = getIndividualDatasetPath(datasetId);
            } else {
                // For integrated visualization, get path from mapping.json
                datasetPath = getDatasetPath(datasetId);
            }

            if (datasetPath == null || !Files.exists(Paths.get(datasetPath))) {
                response.sendError(HttpServletResponse.SC_NOT_FOUND, "Dataset file not found: " + datasetPath);
                return;
            }

            // Create a unique key for this dataset and visualization type
            String processKey = vizType + "_" + datasetId;

            // Check if visualization server is already running for this dataset
            if (!runningProcesses.containsKey(processKey)) {
                startVisualizationServer(processKey, datasetPath, vizType, datasetId);
            }

            // Set attributes for JSP
            request.setAttribute("datasetId", datasetId);
            request.setAttribute("vizType", vizType);
            request.setAttribute("vizPort", VIZ_PORT_BASE);
            String scheme = request.getScheme();
            String host = request.getServerName();
            String vizUrl = scheme + "://" + host + ":" + VIZ_PORT_BASE + "/viz/?dataset=" + datasetId + "&type=" + vizType;

            request.setAttribute("vizUrl", vizUrl);

            // If direct parameter is set, redirect to the actual visualization
            if ("true".equals(direct) || "1".equals(direct)) {
                response.sendRedirect(vizUrl);
            } else {
                // Forward to JSP for regular requests
                request.getRequestDispatcher("visualization.jsp").forward(request, response);
            }

        } catch (Exception e) {
            e.printStackTrace();
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                             "Error starting visualization: " + e.getMessage());
        }
    }

    /**
     * API endpoint to check visualization server status
     */
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String action = request.getParameter("action");

        if ("status".equals(action)) {
            String datasetId = request.getParameter("dataset");
            String vizType = request.getParameter("type");
            if (vizType == null || vizType.isEmpty()) {
                vizType = "individual";
            }

            String processKey = vizType + "_" + datasetId;
            boolean isRunning = runningProcesses.containsKey(processKey);

            Map<String, Object> result = new HashMap<>();
            result.put("running", isRunning);
            result.put("port", VIZ_PORT_BASE);

            Gson gson = new Gson();
            response.setContentType("application/json");
            response.getWriter().write(gson.toJson(result));

        } else if ("stop".equals(action)) {
            String datasetId = request.getParameter("dataset");
            String vizType = request.getParameter("type");
            if (vizType == null || vizType.isEmpty()) {
                vizType = "individual";
            }

            String processKey = vizType + "_" + datasetId;
            stopVisualizationServer(processKey);

            Map<String, Object> result = new HashMap<>();
            result.put("stopped", true);

            Gson gson = new Gson();
            response.setContentType("application/json");
            response.getWriter().write(gson.toJson(result));
        }
    }

    private void startVisualizationServer(String processKey, String datasetPath, String vizType, String datasetId) throws IOException {
        String pythonScript = getServletContext().getRealPath("/WEB-INF/visualization_suite.py");

        // If individual visualization is requested, use a different script
        if ("individual".equals(vizType)) {
            pythonScript = getServletContext().getRealPath("/WEB-INF/individual_viz_suite.py");
            // If individual script doesn't exist, fall back to main script
            if (!Files.exists(Paths.get(pythonScript))) {
                pythonScript = getServletContext().getRealPath("/WEB-INF/visualization_suite.py");
            }
        }

        // Check if Python script exists
        if (!Files.exists(Paths.get(pythonScript))) {
            throw new IOException("Visualization script not found: " + pythonScript);
        }

        // Build command - specify type as individual to ensure UMAP computation if needed
        ProcessBuilder pb = new ProcessBuilder(
            "python3",
            pythonScript,
            "--dataset", datasetPath,
            "--dataset-id", datasetId,
            "--type", vizType,
            "--port", String.valueOf(VIZ_PORT_BASE)
        );

        pb.redirectErrorStream(true);

        // Start process
        Process process = pb.start();

        // Store process
        runningProcesses.put(processKey, process);

        // Monitor output in separate thread
        new Thread(() -> {
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    System.out.println("[Viz " + processKey + "] " + line);
                }
            } catch (IOException e) {
                System.err.println("Error reading visualization output: " + e.getMessage());
            }
        }).start();

        System.out.println("Started visualization server for dataset: " + processKey + " (type: " + vizType + ")");

        // Wait a moment for server to start
        try {
            Thread.sleep(3000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    /**
     * Stop visualization server for a dataset
     */
    private void stopVisualizationServer(String processKey) {
        Process process = runningProcesses.remove(processKey);
        if (process != null && process.isAlive()) {
            process.destroy();
            try {
                process.waitFor();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            System.out.println("Stopped visualization server for dataset: " + processKey);
        }
    }

    /**
     * Get dataset file path from mapping.json or find individual dataset file
     */
    private String getDatasetPath(String datasetId) {
        try {
            // First try the original mapping approach
            String mappingPath = getServletContext().getRealPath("/WEB-INF/classes/mapping.json");
            if (!Files.exists(Paths.get(mappingPath))) {
                mappingPath = getServletContext().getRealPath("/WEB-INF/classes/") + "../resources/mapping.json";
            }

            if (Files.exists(Paths.get(mappingPath))) {
                String content = new String(Files.readAllBytes(Paths.get(mappingPath)));
                Gson gson = new Gson();
                @SuppressWarnings("unchecked")
                Map<String, Map<String, String>> mapping = gson.fromJson(content, Map.class);

                if (mapping.containsKey(datasetId)) {
                    String filePath = mapping.get(datasetId).get("file_path");
                    if (filePath != null && Files.exists(Paths.get(filePath))) {
                        return filePath;
                    }
                }
            }

            // If mapping approach failed or file doesn't exist, try to find individual H5AD file
            return getIndividualDatasetPath(datasetId);
        } catch (Exception e) {
            System.err.println("Error loading dataset mapping: " + e.getMessage());
        }

        return null;
    }

    /**
     * Get individual dataset file path by finding the H5AD file based on SAID
     */
    private String getIndividualDatasetPath(String datasetId) {
        try {
            // Get data root path using the DataPathResolver
            String dataRoot = Utils.DataPathResolver.resolveDataRoot(getServletContext());
            String downloadDataPath = "download_data";

            // Look up GSE and GSM from CSV files based on SAID
            java.io.File humanFile = Utils.DataPathResolver.resolveReadableFile(getServletContext(), "human/human_obs_by_batch.csv");
            java.io.File mouseFile = Utils.DataPathResolver.resolveReadableFile(getServletContext(), "mouse/mouse_obs_by_batch.csv");

            String gse = null;
            String gsm = null;
            String species = null;

            // Search in human CSV first
            if (humanFile.exists()) {
                java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.FileReader(humanFile));
                String headerLine = reader.readLine(); // Skip header
                String line;
                while ((line = reader.readLine()) != null) {
                    String[] parts = line.split(",", -1);
                    if (parts.length >= 11 && datasetId.equals(parts[10])) { // SAID is in column 10
                        gse = parts[9];  // GSE column
                        gsm = parts[5];  // GSM column
                        species = "human";
                        break;
                    }
                }
                reader.close();
            }

            // If not found in human, search in mouse
            if (gse == null && gsm == null && mouseFile.exists()) {
                java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.FileReader(mouseFile));
                reader.readLine(); // Skip header
                String line;
                while ((line = reader.readLine()) != null) {
                    String[] parts = line.split(",", -1);
                    if (parts.length >= 11 && datasetId.equals(parts[10])) { // SAID is in column 10
                        gse = parts[9];  // GSE column
                        gsm = parts[5];  // GSM column
                        species = "mouse";
                        break;
                    }
                }
                reader.close();
            }

            if (gse != null && gsm != null && species != null) {
                // Build expected H5AD file path: /opt/SkinDB/download_data/10X/[species]/[GSE]/[GSM]/[GSE]_[GSM].h5ad
                String h5adFilename = gse + "_" + gsm + ".h5ad";
                String h5adPath = Paths.get(dataRoot, downloadDataPath, "10X", species, gse, gsm, h5adFilename).toString();

                // Check if the file exists
                if (Files.exists(Paths.get(h5adPath))) {
                    System.out.println("Found individual dataset file for SAID " + datasetId + ": " + h5adPath);
                    return h5adPath;
                } else {
                    // Try alternative naming convention
                    String altH5adPath = Paths.get(dataRoot, downloadDataPath, "10X", species, gse, gsm, gsm + ".h5ad").toString();
                    if (Files.exists(Paths.get(altH5adPath))) {
                        System.out.println("Found alternative individual dataset file for SAID " + datasetId + ": " + altH5adPath);
                        return altH5adPath;
                    } else {
                        System.err.println("H5AD file not found at: " + h5adPath + " or " + altH5adPath);
                    }
                }
            } else {
                System.err.println("Could not find GSE/GSM for SAID: " + datasetId);
            }
        } catch (Exception e) {
            System.err.println("Error finding individual dataset path for SAID " + datasetId + ": " + e.getMessage());
        }

        return null;
    }

    /**
     * Clean up resources on servlet destruction
     */
    @Override
    public void destroy() {
        System.out.println("Stopping all visualization servers...");
        for (Map.Entry<String, Process> entry : runningProcesses.entrySet()) {
            Process process = entry.getValue();
            if (process.isAlive()) {
                process.destroy();
            }
        }
        runningProcesses.clear();
        super.destroy();
    }
}
