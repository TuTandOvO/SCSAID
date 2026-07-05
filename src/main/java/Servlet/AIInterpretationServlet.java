package Servlet;

import Utils.AIInterpretationService;
import com.google.gson.*;

import javax.servlet.ServletException;
import javax.servlet.http.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;

/** One-shot relay for user-authorized scientific interpretation requests. */
public class AIInterpretationServlet extends HttpServlet {
    public static final String CONSENT_VERSION = "2026-07-05";
    private static final int MAX_BODY_CHARS = 262_144;
    private static final int MAX_SOURCES = 6;
    private static final int MAX_ROWS = 100;
    private static final int MAX_OBJECT_KEYS = 30;
    private static final int MAX_STRING_CHARS = 500;
    private static final Set<String> SOURCE_TYPES = Collections.unmodifiableSet(new LinkedHashSet<>(Arrays.asList(
            "cell_proportion", "deg", "gene_set_scoring", "cell_communication", "enrichment", "regulatory_network"
    )));

    private final Gson gson = new Gson();
    private AIInterpretationService service;

    @Override
    public void init() throws ServletException {
        try {
            service = new AIInterpretationService();
        } catch (IOException ex) {
            throw new ServletException("LLM interpretation resources could not be loaded.", ex);
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException {
        secureJson(response);
        String apiKey = request.getHeader("X-scSAID-Provider-Key");
        try {
            if (apiKey == null || apiKey.length() < 8 || apiKey.length() > 1024
                    || apiKey.indexOf('\r') >= 0 || apiKey.indexOf('\n') >= 0) {
                sendError(response, 400, "Enter a valid provider API key.");
                return;
            }
            JsonObject body = readBody(request);
            if (!CONSENT_VERSION.equals(string(body, "consentVersion"))) {
                sendError(response, 400, "Privacy consent is required for this request.");
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
            if (!"openai".equals(provider) && !"deepseek".equals(provider)
                    && !"claude".equals(provider) && !"gemini".equals(provider)) {
                sendError(response, 400, "Choose OpenAI, DeepSeek, Claude, or Gemini.");
                return;
            }

            JsonArray sources = normalizeSources(body.get("sources"));
            JsonObject result = service.interpret(said, provider, sources, apiKey);
            JsonArray selected = new JsonArray();
            for (JsonElement item : sources) selected.add(item.getAsJsonObject().get("type"));
            result.add("selectedSources", selected);
            response.setStatus(200);
            gson.toJson(result, response.getWriter());
        } catch (IllegalArgumentException ex) {
            sendError(response, 400, ex.getMessage());
        } catch (AIInterpretationService.ProviderException ex) {
            sendError(response, ex.getStatus(), ex.getMessage());
        } catch (java.net.SocketTimeoutException ex) {
            sendError(response, 504, "The provider took too long to respond. Please try again.");
        } catch (IOException ex) {
            sendError(response, 502, "The provider request could not be completed.");
        } finally {
            // Do not retain the credential in servlet fields, sessions, logs, or response objects.
            apiKey = null;
        }
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        secureJson(response);
        sendError(response, 405, "Use POST for interpretation requests.");
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
            if (!element.isJsonObject()) throw new IllegalArgumentException("Invalid analysis result payload.");
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
            String string = primitive.getAsString();
            if (string.length() > MAX_STRING_CHARS) string = string.substring(0, MAX_STRING_CHARS) + "…";
            return new JsonPrimitive(string);
        }
        if (value.isJsonArray()) {
            JsonArray clean = new JsonArray();
            int limit = Math.min(value.getAsJsonArray().size(), MAX_ROWS);
            for (int i = 0; i < limit; i++) clean.add(normalizeValue(value.getAsJsonArray().get(i), depth + 1));
            return clean;
        }
        JsonObject clean = new JsonObject();
        int keys = 0;
        for (Map.Entry<String, JsonElement> entry : value.getAsJsonObject().entrySet()) {
            if (++keys > MAX_OBJECT_KEYS) break;
            String key = entry.getKey().length() > 80 ? entry.getKey().substring(0, 80) : entry.getKey();
            clean.add(key, normalizeValue(entry.getValue(), depth + 1));
        }
        return clean;
    }

    private boolean validCsrf(HttpServletRequest request, String supplied) {
        HttpSession session = request.getSession(false);
        Object expected = session == null ? null : session.getAttribute("aiInterpretationCsrf");
        if (!(expected instanceof String) || supplied.isEmpty()) return false;
        return MessageDigest.isEqual(((String) expected).getBytes(StandardCharsets.UTF_8),
                supplied.getBytes(StandardCharsets.UTF_8));
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
        error.addProperty("error", message == null || message.trim().isEmpty() ? "Request failed." : message);
        gson.toJson(error, response.getWriter());
    }

    private String string(JsonObject object, String key) {
        return object.has(key) && !object.get(key).isJsonNull() ? object.get(key).getAsString() : "";
    }
}
