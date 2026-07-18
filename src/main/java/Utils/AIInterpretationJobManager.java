package Utils;

import com.google.gson.*;

import java.io.IOException;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;

/** Session-bound, in-memory interpretation jobs with short-lived results. */
public final class AIInterpretationJobManager implements AutoCloseable {
    private static final long RESULT_TTL_MS = TimeUnit.MINUTES.toMillis(30);
    private static final long RUNNING_TTL_MS = TimeUnit.MINUTES.toMillis(20);
    private static final long RATE_WINDOW_MS = TimeUnit.MINUTES.toMillis(10);
    private static final int MAX_SESSION_SUBMISSIONS = 4;
    private static final int MAX_JOBS = 128;

    private final AIInterpretationService service;
    private final ConcurrentMap<String, Job> jobs = new ConcurrentHashMap<>();
    private final ThreadPoolExecutor executor;
    private final ScheduledExecutorService sweeper;

    public AIInterpretationJobManager(AIInterpretationService service) {
        this.service = service;
        this.executor = new ThreadPoolExecutor(
                2, 4, 60, TimeUnit.SECONDS,
                new ArrayBlockingQueue<>(24),
                daemonFactory("scsaid-llm-worker"),
                new ThreadPoolExecutor.AbortPolicy()
        );
        this.sweeper = Executors.newSingleThreadScheduledExecutor(
                daemonFactory("scsaid-llm-cleanup")
        );
        this.sweeper.scheduleAtFixedRate(this::sweep, 1, 1, TimeUnit.MINUTES);
    }

    public synchronized String submit(String sessionId, String said, String provider,
                                      JsonArray sources, char[] apiKey,
                                      boolean searchCurrentLiterature) {
        long now = System.currentTimeMillis();
        long recentForSession = jobs.values().stream()
                .filter(job -> constantEquals(job.sessionId, sessionId))
                .filter(job -> now - job.createdAt <= RATE_WINDOW_MS)
                .count();
        if (recentForSession >= MAX_SESSION_SUBMISSIONS) {
            Arrays.fill(apiKey, '\0');
            throw new RejectedExecutionException(
                    "This session has reached the interpretation request limit. Try again shortly."
            );
        }
        if (jobs.size() >= MAX_JOBS) sweep();
        if (jobs.size() >= MAX_JOBS) {
            Arrays.fill(apiKey, '\0');
            throw new RejectedExecutionException("The interpretation queue is full. Try again shortly.");
        }
        String id = UUID.randomUUID().toString();
        Job job = new Job(id, sessionId, said, provider, selectedSources(sources), now);
        jobs.put(id, job);
        try {
            executor.execute(() -> run(job, sources, apiKey, searchCurrentLiterature));
        } catch (RejectedExecutionException ex) {
            jobs.remove(id);
            Arrays.fill(apiKey, '\0');
            throw ex;
        }
        return id;
    }

    public JsonObject status(String id, String sessionId) {
        Job job = owned(id, sessionId);
        JsonObject status = new JsonObject();
        status.addProperty("jobId", job.id);
        status.addProperty("status", job.status.name().toLowerCase(Locale.ROOT));
        status.addProperty("progress", job.progress);
        status.addProperty("provider", job.provider);
        status.addProperty("said", job.said);
        status.addProperty("createdAt", Instant.ofEpochMilli(job.createdAt).toString());
        if (job.completedAt > 0) {
            status.addProperty("completedAt", Instant.ofEpochMilli(job.completedAt).toString());
        }
        if (job.status == Status.FAILED) {
            status.addProperty("error", job.error);
            status.addProperty("errorStatus", job.errorStatus);
        }
        return status;
    }

    public JsonObject result(String id, String sessionId) {
        Job job = owned(id, sessionId);
        if (job.status == Status.QUEUED || job.status == Status.RUNNING) {
            throw new IllegalStateException("Interpretation is still running.");
        }
        if (job.status == Status.FAILED) {
            throw new JobFailedException(job.errorStatus, job.error);
        }
        return job.result.deepCopy();
    }

    public JsonObject contextSummary(String said) throws IOException {
        return service.contextSummary(said);
    }

    private void run(Job job, JsonArray sources, char[] apiKey, boolean search) {
        String transientKey = null;
        try {
            job.status = Status.RUNNING;
            job.progress = search
                    ? "Reading the verified full paper and searching current literature"
                    : "Reading the verified full paper";
            transientKey = new String(apiKey);
            JsonObject result = service.interpret(
                    job.said, job.provider, sources, transientKey, search
            );
            result.add("selectedSources", job.selectedSources.deepCopy());
            job.result = result;
            job.progress = "Interpretation ready";
            job.status = Status.COMPLETED;
        } catch (AIInterpretationService.ProviderException ex) {
            fail(job, ex.getStatus(), ex.getMessage());
        } catch (IllegalArgumentException ex) {
            fail(job, 400, safeMessage(ex.getMessage()));
        } catch (java.net.SocketTimeoutException ex) {
            fail(job, 504, "The provider took too long to respond. Please try again.");
        } catch (IOException ex) {
            fail(job, 502, "The provider or private literature corpus could not be read.");
        } catch (RuntimeException ex) {
            fail(job, 500, "The interpretation job could not be completed.");
        } finally {
            Arrays.fill(apiKey, '\0');
            transientKey = null;
            job.completedAt = System.currentTimeMillis();
        }
    }

    private void fail(Job job, int status, String message) {
        job.errorStatus = status;
        job.error = safeMessage(message);
        job.progress = "Interpretation failed";
        job.status = Status.FAILED;
    }

    private Job owned(String id, String sessionId) {
        if (id == null || !id.matches("[0-9a-fA-F-]{36}") || sessionId == null) {
            throw new NoSuchElementException("Interpretation job not found.");
        }
        Job job = jobs.get(id);
        if (job == null || !constantEquals(job.sessionId, sessionId)) {
            throw new NoSuchElementException("Interpretation job not found.");
        }
        return job;
    }

    private void sweep() {
        long now = System.currentTimeMillis();
        jobs.entrySet().removeIf(entry -> {
            Job job = entry.getValue();
            long age = now - (job.completedAt > 0 ? job.completedAt : job.createdAt);
            return job.completedAt > 0 ? age > RESULT_TTL_MS : age > RUNNING_TTL_MS;
        });
    }

    private JsonArray selectedSources(JsonArray sources) {
        JsonArray selected = new JsonArray();
        for (JsonElement element : sources) {
            selected.add(element.getAsJsonObject().get("type").getAsString());
        }
        return selected;
    }

    private static boolean constantEquals(String left, String right) {
        if (left.length() != right.length()) return false;
        int difference = 0;
        for (int i = 0; i < left.length(); i++) {
            difference |= left.charAt(i) ^ right.charAt(i);
        }
        return difference == 0;
    }

    private static String safeMessage(String message) {
        if (message == null || message.trim().isEmpty()) return "Interpretation failed.";
        return message.length() > 300 ? message.substring(0, 300) : message;
    }

    private ThreadFactory daemonFactory(String name) {
        return runnable -> {
            Thread thread = new Thread(runnable, name);
            thread.setDaemon(true);
            return thread;
        };
    }

    @Override
    public void close() {
        executor.shutdownNow();
        sweeper.shutdownNow();
        jobs.clear();
    }

    private enum Status { QUEUED, RUNNING, COMPLETED, FAILED }

    private static final class Job {
        final String id;
        final String sessionId;
        final String said;
        final String provider;
        final JsonArray selectedSources;
        final long createdAt;
        volatile long completedAt;
        volatile Status status = Status.QUEUED;
        volatile String progress = "Queued";
        volatile JsonObject result;
        volatile String error = "";
        volatile int errorStatus = 500;

        Job(String id, String sessionId, String said, String provider,
            JsonArray selectedSources, long createdAt) {
            this.id = id;
            this.sessionId = sessionId;
            this.said = said;
            this.provider = provider;
            this.selectedSources = selectedSources;
            this.createdAt = createdAt;
        }
    }

    public static final class JobFailedException extends RuntimeException {
        private final int status;

        JobFailedException(int status, String message) {
            super(message);
            this.status = status;
        }

        public int getStatus() {
            return status;
        }
    }
}
