package Servlet;

import Utils.AIInterpretationJobManager;
import Utils.AIInterpretationService;
import com.google.gson.*;

import javax.servlet.ServletException;
import javax.servlet.http.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.RejectedExecutionException;

/** Consent-gated, session-bound job API for full-paper scientific interpretation. */
public class AIInterpretationServlet extends HttpServlet {
    public static final String CONSENT_VERSION = "2026-07-18";
    private static final int MAX_BODY_CHARS = 524_288;
    private static final int MAX_SOURCES = 6;
    private static final int MAX_ROWS = 100;
    private static final int MAX_OBJECT_KEYS = 30;
    private static final int MAX_STRING_CHARS = 500;
    private static final Set<String> SOURCE_TYPES = Collections.unmodifiableSet(
            new LinkedHashSet<>(Arrays.asList(
                    "cell_proportion", "deg", "gene_set_scoring",
                    "cell_communication", "enrichment", "regulatory_network"
            ))
    );

    private final Gson gson = new Gson();
    private AIInterpretationJobManager jobs;

    @Override
    public void init() throws ServletException {
        try {
            jobs = new AIInterpretationJobManager(new AIInterpretationService());
        } catch (IOException ex) {
            throw new ServletException("LLM interpretation resources could not be loaded.", ex);
        }
    }

    @Override
    public void destroy() {
        if (jobs != null) jobs.close();
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException {
        secureJson(response);
        String headerKey = request.getHeader("X-scSAID-Provider-Key");
        char[] apiKey = headerKey == null ? new char[0] : headerKey.toCharArray();
        headerKey = null;
        try {
            if (!validApiKey(apiKey)) {
                sendError(response, 400, "Enter a valid provider API key.");
                return;
            }
            JsonObject body = readBody(request);
            if (!CONSENT_VERSION.equals(string(body, "consentVersion"))
                    || !booleanValue(body, "privacyConsent")) {
                sendError(response, 400, "Current privacy consent is required.");
                return;
            }
            if (!booleanValue(body, "publicationRightsConfirmed")) {
                sendError(response, 400,
                        "Confirm that you may transmit the linked publication to the provider.");
                return;
            }
            if (!validCsrf(request, string(body, "csrfToken"))) {
                sendError(response, 403, "This page session is no longer valid. Refresh and try again.");
                return;
            }

            String said = string(body, "said");
            if (!said.matches("SAID\\d{3}")) {
                sendError(response, 400, "Invalid dataset identifier.");
                return;
            }
            String provider = string(body, "provider").toLowerCase(Locale.ROOT);
            if (!Arrays.asList("openai", "deepseek", "claude", "gemini").contains(provider)) {
                sendError(response, 400, "Choose OpenAI, DeepSeek, Claude, or Gemini.");
                return;
            }
            JsonArray sources = normalizeSources(body.get("sources"));
            HttpSession session = request.getSession(false);
            if (session == null) {
                sendError(response, 403, "This page session is no longer valid. Refresh and try again.");
                return;
            }
            String jobId = jobs.submit(
                    session.getId(), said, provider, sources, apiKey,
                    !body.has("searchCurrentLiterature")
                            || booleanValue(body, "searchCurrentLiterature")
            );
            apiKey = new char[0]; // ownership transferred to the worker
            JsonObject accepted = new JsonObject();
            accepted.addProperty("jobId", jobId);
            accepted.addProperty("status", "queued");
            response.setStatus(202);
            gson.toJson(accepted, response.getWriter());
        } catch (IllegalArgumentException ex) {
            sendError(response, 400, ex.getMessage());
        } catch (RejectedExecutionException ex) {
            sendError(response, 503, "The interpretation queue is busy. Please try again shortly.");
        } finally {
            Arrays.fill(apiKey, '\0');
        }
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        secureJson(response);
        String action = request.getParameter("action");
        try {
            if ("context".equals(action)) {
                String said = Optional.ofNullable(request.getParameter("said")).orElse("");
                if (!said.matches("SAID\\d{3}")) {
                    sendError(response, 400, "Invalid dataset identifier.");
                    return;
                }
                gson.toJson(jobs.contextSummary(said), response.getWriter());
                return;
            }
            if (!"status".equals(action) && !"result".equals(action)) {
                sendError(response, 400, "Choose a supported interpretation action.");
                return;
            }
            if (!validCsrf(request, Optional.ofNullable(request.getParameter("csrfToken")).orElse(""))) {
                sendError(response, 403, "This page session is no longer valid. Refresh and try again.");
                return;
            }
            HttpSession session = request.getSession(false);
            if (session == null) {
                sendError(response, 404, "Interpretation job not found.");
                return;
            }
            String jobId = request.getParameter("jobId");
            JsonObject result = "status".equals(action)
                    ? jobs.status(jobId, session.getId())
                    : jobs.result(jobId, session.getId());
            gson.toJson(result, response.getWriter());
        } catch (NoSuchElementException ex) {
            sendError(response, 404, "Interpretation job not found.");
        } catch (IllegalStateException ex) {
            sendError(response, 409, ex.getMessage());
        } catch (AIInterpretationJobManager.JobFailedException ex) {
            sendError(response, ex.getStatus(), ex.getMessage());
        } catch (IllegalArgumentException ex) {
            sendError(response, 400, ex.getMessage());
        } catch (IOException ex) {
            sendError(response, 503, "The private literature context is temporarily unavailable.");
        }
    }

    private boolean validApiKey(char[] key) {
        if (key.length < 8 || key.length > 1024) return false;
        for (char character : key) {
            if (character == '\r' || character == '\n' || character == '\0') return false;
        }
        return true;
    }

    private JsonObject readBody(HttpServletRequest request) throws IOException {
        if (request.getContentLengthLong() > MAX_BODY_CHARS) {
            throw new IllegalArgumentException("The selected result payload is too large.");
        }
        StringBuilder body = new StringBuilder();
        char[] buffer = new char[4096];
        int count;
        try (Reader reader = request.getReader()) {
            while ((count = reader.read(buffer)) != -1) {
                if (body.length() + count > MAX_BODY_CHARS) {
                    throw new IllegalArgumentException("The selected result payload is too large.");
                }
                body.append(buffer, 0, count);
            }
        }
        try {
            return JsonParser.parseString(body.toString()).getAsJsonObject();
        } catch (RuntimeException ex) {
            throw new IllegalArgumentException("Malformed interpretation request.");
        }
    }

    private JsonArray normalizeSources(JsonElement rawSources) {
        if (rawSources == null || !rawSources.isJsonArray()) {
            throw new IllegalArgumentException("Select at least one analysis result.");
        }
        JsonArray input = rawSources.getAsJsonArray();
        if (input.size() < 1 || input.size() > MAX_SOURCES) {
            throw new IllegalArgumentException("Select between one and six analysis results.");
        }
        JsonArray normalized = new JsonArray();
        Set<String> seen = new HashSet<>();
        for (JsonElement element : input) {
            if (!element.isJsonObject()) {
                throw new IllegalArgumentException("Invalid analysis result payload.");
            }
            JsonObject source = element.getAsJsonObject();
            String type = string(source, "type");
            if (!SOURCE_TYPES.contains(type) || !seen.add(type)) {
                throw new IllegalArgumentException("Invalid or duplicate analysis result type.");
            }
            JsonObject clean = new JsonObject();
            clean.addProperty("type", type);
            clean.add("parameters", normalizeValue(source.get("parameters"), 0));
            clean.add("data", normalizeValue(source.get("data"), 0));
            normalized.add(clean);
        }
        return normalized;
    }

    private JsonElement normalizeValue(JsonElement value, int depth) {
        if (value == null || value.isJsonNull()) return JsonNull.INSTANCE;
        if (depth > 5) throw new IllegalArgumentException("Analysis result nesting is too deep.");
        if (value.isJsonPrimitive()) {
            JsonPrimitive primitive = value.getAsJsonPrimitive();
            if (primitive.isBoolean()) return new JsonPrimitive(primitive.getAsBoolean());
            if (primitive.isNumber()) {
                double number = primitive.getAsDouble();
                return Double.isFinite(number) ? new JsonPrimitive(number) : JsonNull.INSTANCE;
            }
            String valueString = primitive.getAsString();
            if (valueString.length() > MAX_STRING_CHARS) {
                valueString = valueString.substring(0, MAX_STRING_CHARS) + "…";
            }
            return new JsonPrimitive(valueString);
        }
        if (value.isJsonArray()) {
            JsonArray clean = new JsonArray();
            int limit = Math.min(value.getAsJsonArray().size(), MAX_ROWS);
            for (int index = 0; index < limit; index++) {
                clean.add(normalizeValue(value.getAsJsonArray().get(index), depth + 1));
            }
            return clean;
        }
        JsonObject clean = new JsonObject();
        int keys = 0;
        for (Map.Entry<String, JsonElement> entry : value.getAsJsonObject().entrySet()) {
            if (++keys > MAX_OBJECT_KEYS) break;
            String key = entry.getKey().length() > 80
                    ? entry.getKey().substring(0, 80) : entry.getKey();
            clean.add(key, normalizeValue(entry.getValue(), depth + 1));
        }
        return clean;
    }

    private boolean validCsrf(HttpServletRequest request, String supplied) {
        HttpSession session = request.getSession(false);
        Object expected = session == null ? null : session.getAttribute("aiInterpretationCsrf");
        if (!(expected instanceof String) || supplied.isEmpty()) return false;
        return MessageDigest.isEqual(
                ((String) expected).getBytes(StandardCharsets.UTF_8),
                supplied.getBytes(StandardCharsets.UTF_8)
        );
    }

    private boolean booleanValue(JsonObject object, String key) {
        return object.has(key) && object.get(key).isJsonPrimitive()
                && object.get(key).getAsJsonPrimitive().isBoolean()
                && object.get(key).getAsBoolean();
    }

    private void secureJson(HttpServletResponse response) {
        response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store, max-age=0");
        response.setHeader("Pragma", "no-cache");
        response.setHeader("X-Content-Type-Options", "nosniff");
    }

    private void sendError(HttpServletResponse response, int status, String message) throws IOException {
        response.setStatus(status);
        JsonObject error = new JsonObject();
        error.addProperty(
                "error",
                message == null || message.trim().isEmpty() ? "Request failed." : message
        );
        gson.toJson(error, response.getWriter());
    }

    private String string(JsonObject object, String key) {
        return object.has(key) && !object.get(key).isJsonNull()
                ? object.get(key).getAsString() : "";
    }
}
