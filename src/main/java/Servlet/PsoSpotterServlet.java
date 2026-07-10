package Servlet;

import Utils.DataPathResolver;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.Part;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;

/**
 * Queue-backed psoSpotter job endpoint.
 *
 * The browser posts uploaded h5ad files plus a candidate gene list. Jobs are
 * serialized through a single worker and retained for 30 minutes after finish.
 */
public class PsoSpotterServlet extends HttpServlet {
    private static final Gson GSON = new GsonBuilder().serializeNulls().create();
    private static final int MAX_QUEUED_JOBS = 5; // 1 running + 4 queued
    private static final int RESULT_TTL_MINUTES = 30;
    private static final int MAX_GENES = 5_000;
    private static final int MAX_GENE_LENGTH = 64;
    private static final int MAX_GENE_TEXT_LENGTH = 100_000;
    private static final byte[] HDF5_MAGIC = new byte[]{(byte) 0x89, 'H', 'D', 'F', '\r', '\n', 0x1a, '\n'};
    private static final Semaphore SLOTS = new Semaphore(MAX_QUEUED_JOBS, true);
    private static final ScheduledExecutorService CLEANER = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "psospotter-cleaner");
        t.setDaemon(true);
        return t;
    });
    private static final java.util.concurrent.ExecutorService WORKER = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "psospotter-worker");
        t.setDaemon(true);
        return t;
    });

    private static final Map<String, JobRecord> JOBS = new ConcurrentHashMap<>();
    private static final Map<String, String> SESSION_JOB = new ConcurrentHashMap<>();
    private static final Deque<String> QUEUE = new ArrayDeque<>();
    private static final Object QUEUE_LOCK = new Object();
    private static volatile boolean workerScheduled = false;

    @Override
    public void init() throws ServletException {
        super.init();
        CLEANER.scheduleAtFixedRate(this::purgeExpiredJobs, 5, 5, TimeUnit.MINUTES);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException {
        String path = request.getServletPath();
        if ("/psospotter".equals(path)) {
            handleSubmit(request, response);
            return;
        }
        response.sendError(HttpServletResponse.SC_NOT_FOUND);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        String path = request.getServletPath();
        if ("/psospotter/status".equals(path)) {
            handleStatus(request, response);
        } else if ("/psospotter/result".equals(path)) {
            handleResult(request, response);
        } else {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
        }
    }

    private void handleSubmit(HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException {
        String sessionId = request.getSession(true).getId();
        JobRecord existing = currentSessionJob(sessionId);
        if (existing != null && !existing.isTerminal()) {
            sendJson(response, HttpServletResponse.SC_CONFLICT, errorMap("A psoSpotter job is already running for this session."));
            return;
        }

        if (!SLOTS.tryAcquire()) {
            sendJson(response, 429, errorMap("The global queue is full. Try again later."));
            return;
        }

        String mode = trim(request.getParameter("mode"));
        if (mode == null || (!"single".equals(mode) && !"cross".equals(mode))) {
            SLOTS.release();
            sendJson(response, HttpServletResponse.SC_BAD_REQUEST, errorMap("Missing or invalid mode."));
            return;
        }

        Path runtimeDir = getRuntimeDir();
        Files.createDirectories(runtimeDir);
        String jobId = UUID.randomUUID().toString();
        Path jobDir = runtimeDir.resolve(jobId);
        Files.createDirectories(jobDir);

        JobRecord job = new JobRecord(jobId, sessionId, mode, jobDir);
        JOBS.put(jobId, job);
        SESSION_JOB.put(sessionId, jobId);

        try {
            Map<String, Object> requestSpec = buildRequestSpec(request, job, jobDir);
            Path requestJson = jobDir.resolve("request.json");
            Files.write(requestJson, GSON.toJson(requestSpec).getBytes(StandardCharsets.UTF_8));
            job.requestJson = requestJson;
            enqueue(job);
        } catch (Exception error) {
            job.status = "failed";
            job.error = error.getMessage();
            job.finishedAt = Instant.now();
            job.expiresAt = job.finishedAt.plus(RESULT_TTL_MINUTES, ChronoUnit.MINUTES);
            cleanupInputs(job);
            SLOTS.release();
            sendJson(response, HttpServletResponse.SC_BAD_REQUEST, errorMap(error.getMessage()));
            return;
        }

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("jobId", jobId);
        payload.put("status", job.status);
        payload.put("queue", queuedCount());
        sendJson(response, HttpServletResponse.SC_OK, payload);
    }

    private Map<String, Object> buildRequestSpec(HttpServletRequest request, JobRecord job, Path jobDir) throws Exception {
        Map<String, Object> spec = new LinkedHashMap<>();
        spec.put("mode", job.mode);
        spec.put("panel_k", parseBoundedInt(request.getParameter("panelK"), 20, 1, 500, "panelK"));
        spec.put("target_total", parseBoundedInt(request.getParameter("targetTotal"), 20000,
                1_000, 5_000_000, "targetTotal"));
        spec.put("genes", splitGenes(trim(request.getParameter("genes"))));
        spec.put("submittedAt", Instant.now().toString());

        if ("single".equals(job.mode)) {
            Part part = request.getPart("h5ad");
            if (part == null || part.getSize() <= 0) {
                throw new IllegalArgumentException("Single-species mode needs one .h5ad upload.");
            }
            String species = normalizeSpecies(request.getParameter("species"));
            spec.put("species", species);
            Path file = jobDir.resolve("input.h5ad");
            savePart(part, file);
            spec.put("single", mapOf(
                    "species", species,
                    "h5ad", file.toString(),
                    "genes", spec.get("genes")
            ));
        } else {
            String trainSpecies = normalizeSpecies(request.getParameter("trainSpecies"));
            String testSpecies = normalizeSpecies(request.getParameter("testSpecies"));
            if (trainSpecies.equals(testSpecies)) {
                throw new IllegalArgumentException("Cross-species mode requires two different species.");
            }
            Part trainPart = request.getPart("trainH5ad");
            Part testPart = request.getPart("testH5ad");
            if (trainPart == null || trainPart.getSize() <= 0 || testPart == null || testPart.getSize() <= 0) {
                throw new IllegalArgumentException("Cross-species mode needs two .h5ad uploads.");
            }
            Path trainFile = jobDir.resolve("train.h5ad");
            Path testFile = jobDir.resolve("test.h5ad");
            savePart(trainPart, trainFile);
            savePart(testPart, testFile);

            Path ortholog = resolveOrthologTable();
            spec.put("species", trainSpecies);
            spec.put("cross", mapOf(
                    "trainSpecies", trainSpecies,
                    "testSpecies", testSpecies,
                    "train_h5ad", trainFile.toString(),
                    "test_h5ad", testFile.toString(),
                    "ortholog_tsv", ortholog.toString(),
                    "genes", spec.get("genes")
            ));
        }

        if (((List<?>) spec.get("genes")).size() == 0) {
            throw new IllegalArgumentException("Please enter at least one gene symbol.");
        }
        return spec;
    }

    private void enqueue(JobRecord job) {
        synchronized (QUEUE_LOCK) {
            QUEUE.addLast(job.jobId);
            if (!workerScheduled) {
                workerScheduled = true;
                WORKER.submit(this::drainQueue);
            }
        }
    }

    private void drainQueue() {
        while (true) {
            String jobId;
            synchronized (QUEUE_LOCK) {
                jobId = QUEUE.pollFirst();
                if (jobId == null) {
                    workerScheduled = false;
                    return;
                }
            }
            JobRecord job = JOBS.get(jobId);
            if (job == null) {
                SLOTS.release();
                continue;
            }
            runJob(job);
        }
    }

    private void runJob(JobRecord job) {
        job.status = "running";
        job.startedAt = Instant.now();
        job.progress = 5;
        job.message = "Launching Python worker";

        Path requestJson = job.requestJson;
        Path resultJson = job.jobDir.resolve("result.json");
        job.resultJson = resultJson;

        List<String> command = new ArrayList<>();
        command.add(DataPathResolver.resolvePythonCommand(getServletContext()));
        command.add(job.runnerScript());
        command.add(requestJson.toString());
        command.add(resultJson.toString());

        ProcessBuilder pb = new ProcessBuilder(command);
        pb.directory(job.jobDir.toFile());
        pb.redirectErrorStream(true);
        pb.environment().put("PYTHONPATH", job.pythonPath());
        pb.environment().put("PYTHONDONTWRITEBYTECODE", "1");

        Process process = null;
        Thread logThread = null;
        try {
            process = pb.start();
            Process finalProcess = process;
            logThread = new Thread(() -> {
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(finalProcess.getInputStream(), StandardCharsets.UTF_8));
                     BufferedWriter logWriter = Files.newBufferedWriter(job.jobDir.resolve("run.log"), StandardCharsets.UTF_8)) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        logWriter.write(line);
                        logWriter.newLine();
                        logWriter.flush();
                        updateProgress(job, line);
                    }
                } catch (IOException ignore) {
                    // The job will fail or finish based on the process exit state.
                }
            }, "psospotter-log-" + job.jobId);
            logThread.setDaemon(true);
            logThread.start();

            boolean finished = process.waitFor(45, TimeUnit.MINUTES);
            if (!finished) {
                process.destroyForcibly();
                job.status = "failed";
                job.error = "The job timed out after 45 minutes.";
            } else if (process.exitValue() != 0) {
                job.status = "failed";
                job.error = "Python exited with code " + process.exitValue();
            } else if (!Files.exists(resultJson)) {
                job.status = "failed";
                job.error = "Python finished without writing a result file.";
            } else {
                job.status = "succeeded";
                job.progress = 100;
                job.message = "Completed";
            }
        } catch (Exception error) {
            job.status = "failed";
            job.error = error.getMessage();
        } finally {
            if (logThread != null) {
                try {
                    logThread.join(5000);
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                }
            }
            job.finishedAt = Instant.now();
            job.expiresAt = job.finishedAt.plus(RESULT_TTL_MINUTES, ChronoUnit.MINUTES);
            cleanupInputs(job);
            SLOTS.release();
            if (process != null && process.isAlive()) {
                process.destroyForcibly();
            }
        }
    }

    private void updateProgress(JobRecord job, String line) {
        if (line == null) return;
        if (line.startsWith("PROGRESS ")) {
            String[] parts = line.split(" ", 3);
            if (parts.length >= 2) {
                try {
                    job.progress = Integer.parseInt(parts[1]);
                } catch (NumberFormatException ignore) {
                    // Keep the previous progress value.
                }
            }
            if (parts.length == 3) {
                job.message = parts[2];
            }
        } else if (job.message == null || job.message.isEmpty()) {
            job.message = line;
        }
    }

    private void handleStatus(HttpServletRequest request, HttpServletResponse response) throws IOException {
        JobRecord job = ownedJob(request, trim(request.getParameter("jobId")));
        if (job == null) {
            sendJson(response, HttpServletResponse.SC_NOT_FOUND, errorMap("Unknown job."));
            return;
        }
        if (job.isExpired()) {
            sendJson(response, 410, errorMap("The result has expired."));
            return;
        }
        Map<String, Object> payload = job.toStatusMap();
        payload.put("queue", queuedCount());
        sendJson(response, HttpServletResponse.SC_OK, payload);
    }

    private void handleResult(HttpServletRequest request, HttpServletResponse response) throws IOException {
        JobRecord job = ownedJob(request, trim(request.getParameter("jobId")));
        if (job == null) {
            sendJson(response, HttpServletResponse.SC_NOT_FOUND, errorMap("Unknown job."));
            return;
        }
        if (job.isExpired()) {
            sendJson(response, 410, errorMap("The result has expired."));
            return;
        }
        if (!"succeeded".equals(job.status)) {
            sendJson(response, HttpServletResponse.SC_CONFLICT, job.toStatusMap());
            return;
        }
        if (job.resultJson == null || !Files.exists(job.resultJson)) {
            sendJson(response, HttpServletResponse.SC_NOT_FOUND, errorMap("Result file not found."));
            return;
        }
        response.setCharacterEncoding("UTF-8");
        response.setContentType("application/json");
        response.setHeader("Cache-Control", "no-store");
        try (InputStream in = Files.newInputStream(job.resultJson);
             OutputStream out = response.getOutputStream()) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        }
    }

    private synchronized int queuedCount() {
        int count = 0;
        for (JobRecord job : JOBS.values()) {
            if (!job.isTerminal()) count++;
        }
        return count;
    }

    private synchronized JobRecord currentSessionJob(String sessionId) {
        String jobId = SESSION_JOB.get(sessionId);
        if (jobId == null) return null;
        JobRecord job = JOBS.get(jobId);
        if (job == null || job.isExpired()) {
            SESSION_JOB.remove(sessionId);
            return null;
        }
        return job;
    }

    private void purgeExpiredJobs() {
        Instant now = Instant.now();
        for (JobRecord job : new ArrayList<>(JOBS.values())) {
            if (job.expiresAt != null && now.isAfter(job.expiresAt)) {
                deleteRecursively(job.jobDir);
                JOBS.remove(job.jobId);
                SESSION_JOB.remove(job.sessionId, job.jobId);
            }
        }
    }

    private void cleanupInputs(JobRecord job) {
        if (job == null || job.jobDir == null) return;
        if (job.requestJson != null) {
            try { Files.deleteIfExists(job.requestJson); } catch (IOException ignore) {}
        }
        for (String name : new String[]{"input.h5ad", "train.h5ad", "test.h5ad"}) {
            try { Files.deleteIfExists(job.jobDir.resolve(name)); } catch (IOException ignore) {}
        }
    }

    private Path getRuntimeDir() {
        String dataRoot = DataPathResolver.resolveDataRoot(getServletContext());
        return Paths.get(dataRoot, "runtime", "psospotter");
    }

    private Path resolveOrthologTable() {
        String path = getServletContext().getRealPath("/WEB-INF/psospotter-data/ensembl116_human_mouse_orthologs.tsv");
        if (path == null) {
            throw new IllegalStateException("Ortholog table is not packaged with the application.");
        }
        Path ortholog = Paths.get(path);
        if (!Files.exists(ortholog)) {
            throw new IllegalStateException("Ortholog table is missing: " + ortholog);
        }
        return ortholog;
    }

    private JobRecord ownedJob(HttpServletRequest request, String jobId) {
        if (jobId == null || request.getSession(false) == null) return null;
        JobRecord job = JOBS.get(jobId);
        return job != null && job.sessionId.equals(request.getSession(false).getId()) ? job : null;
    }

    private String normalizeSpecies(String value) {
        String s = trim(value);
        if (s == null) throw new IllegalArgumentException("Species is required.");
        s = s.toLowerCase();
        if (!"human".equals(s) && !"mouse".equals(s)) {
            throw new IllegalArgumentException("Species must be human or mouse.");
        }
        return s;
    }

    private void savePart(Part part, Path file) throws IOException {
        try (InputStream in = part.getInputStream();
             OutputStream out = Files.newOutputStream(file)) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        }
        if (!hasHdf5Signature(file)) {
            Files.deleteIfExists(file);
            throw new IllegalArgumentException("The upload is not a valid HDF5/h5ad file.");
        }
    }

    private static boolean hasHdf5Signature(Path file) throws IOException {
        if (Files.size(file) < HDF5_MAGIC.length) return false;
        byte[] header = new byte[HDF5_MAGIC.length];
        try (InputStream in = Files.newInputStream(file)) {
            if (in.read(header) != header.length) return false;
        }
        for (int i = 0; i < HDF5_MAGIC.length; i++) {
            if (header[i] != HDF5_MAGIC[i]) return false;
        }
        return true;
    }

    private static Map<String, Object> errorMap(String message) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("error", message);
        return map;
    }

    private static Map<String, Object> mapOf(Object... pairs) {
        Map<String, Object> map = new LinkedHashMap<>();
        for (int i = 0; i + 1 < pairs.length; i += 2) {
            map.put(String.valueOf(pairs[i]), pairs[i + 1]);
        }
        return map;
    }

    private static void sendJson(HttpServletResponse response, int status, Object payload) throws IOException {
        response.setStatus(status);
        response.setCharacterEncoding("UTF-8");
        response.setContentType("application/json");
        response.setHeader("Cache-Control", "no-store");
        response.getWriter().write(GSON.toJson(payload));
    }

    private static String trim(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private static int parseBoundedInt(String value, int fallback, int min, int max, String field) {
        try {
            int parsed = value == null ? fallback : Integer.parseInt(value.trim());
            if (parsed < min || parsed > max) throw new NumberFormatException();
            return parsed;
        } catch (Exception error) {
            throw new IllegalArgumentException(field + " must be between " + min + " and " + max + ".");
        }
    }

    private static List<String> splitGenes(String raw) {
        if (raw == null) return new ArrayList<>();
        if (raw.length() > MAX_GENE_TEXT_LENGTH) {
            throw new IllegalArgumentException("The gene list is too large.");
        }
        Set<String> unique = new LinkedHashSet<>();
        String[] tokens = raw.replace('\r', '\n').split("[\\n,;\\t ]+");
        for (String token : tokens) {
            String gene = token.trim();
            if (gene.isEmpty()) continue;
            if (gene.length() > MAX_GENE_LENGTH || !gene.matches("[A-Za-z0-9._-]+")) {
                throw new IllegalArgumentException("Invalid gene symbol: " + gene.substring(0, Math.min(gene.length(), MAX_GENE_LENGTH)));
            }
            unique.add(gene);
            if (unique.size() > MAX_GENES) {
                throw new IllegalArgumentException("A maximum of " + MAX_GENES + " candidate genes is allowed.");
            }
        }
        return new ArrayList<>(unique);
    }

    @Override
    public void destroy() {
        WORKER.shutdownNow();
        CLEANER.shutdownNow();
        synchronized (QUEUE_LOCK) {
            QUEUE.clear();
            workerScheduled = false;
        }
        for (JobRecord job : new ArrayList<>(JOBS.values())) {
            deleteRecursively(job.jobDir);
        }
        JOBS.clear();
        SESSION_JOB.clear();
        super.destroy();
    }

    private static void deleteRecursively(Path path) {
        if (path == null || !Files.exists(path)) return;
        try {
            Files.walk(path)
                .sorted((a, b) -> b.getNameCount() - a.getNameCount())
                .forEach(p -> {
                    try { Files.deleteIfExists(p); } catch (IOException ignore) {}
                });
        } catch (IOException ignore) {
            // Best-effort cleanup.
        }
    }

    private final class JobRecord {
        final String jobId;
        final String sessionId;
        final String mode;
        final Path jobDir;
        final Instant createdAt = Instant.now();
        volatile String status = "queued";
        volatile int progress = 0;
        volatile String message = "Queued";
        volatile String error;
        volatile Instant startedAt;
        volatile Instant finishedAt;
        volatile Instant expiresAt;
        volatile Path requestJson;
        volatile Path resultJson;

        JobRecord(String jobId, String sessionId, String mode, Path jobDir) {
            this.jobId = jobId;
            this.sessionId = sessionId;
            this.mode = mode;
            this.jobDir = jobDir;
        }

        boolean isTerminal() {
            return "succeeded".equals(status) || "failed".equals(status) || "cancelled".equals(status);
        }

        boolean isExpired() {
            return expiresAt != null && Instant.now().isAfter(expiresAt);
        }

        String runnerScript() {
            String script = getServletContext().getRealPath("/WEB-INF/psospotter-src/runner.py");
            if (script == null) {
                throw new IllegalStateException("Runner script is not packaged with the application.");
            }
            return script;
        }

        String pythonPath() {
            String root = getServletContext().getRealPath("/WEB-INF/psospotter-src");
            if (root == null) {
                throw new IllegalStateException("Vendored psoSpotter source path is missing.");
            }
            return root;
        }

        Map<String, Object> toStatusMap() {
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("jobId", jobId);
            payload.put("status", status);
            payload.put("progress", progress);
            payload.put("message", message);
            payload.put("error", error);
            payload.put("createdAt", createdAt.toString());
            payload.put("startedAt", startedAt == null ? null : startedAt.toString());
            payload.put("finishedAt", finishedAt == null ? null : finishedAt.toString());
            payload.put("expiresAt", expiresAt == null ? null : expiresAt.toString());
            payload.put("resultAvailable", "succeeded".equals(status) && resultJson != null && Files.exists(resultJson));
            return payload;
        }
    }
}
