package Utils;

import com.google.gson.*;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;

/** Builds a server-side scientific prompt and performs one transient provider call. */
public class AIInterpretationService {
    public static final String OPENAI_MODEL = "gpt-5-mini";
    public static final String DEEPSEEK_MODEL = "deepseek-v4-flash";

    private static final int CONNECT_TIMEOUT_MS = 15_000;
    // Stay below the common 60-second reverse-proxy default. This makes a slow
    // provider fail cleanly through the application instead of leaving the
    // browser with an opaque gateway timeout.
    private static final int READ_TIMEOUT_MS = 55_000;
    private static final int MAX_PROMPT_CHARS = 60_000;

    private final Gson gson = new Gson();
    private final String openAiUrl;
    private final String deepSeekUrl;
    private final String systemPrompt;
    private final Map<String, JsonObject> datasets = new HashMap<>();
    private final Map<String, JsonObject> papers = new HashMap<>();
    private final Map<String, List<JsonObject>> linksBySaid = new HashMap<>();

    public AIInterpretationService() throws IOException {
        this("https://api.openai.com/v1/responses", "https://api.deepseek.com/chat/completions");
    }

    AIInterpretationService(String openAiUrl, String deepSeekUrl) throws IOException {
        this.openAiUrl = openAiUrl;
        this.deepSeekUrl = deepSeekUrl;
        this.systemPrompt = readResource("ai/interpretation-system.txt");
        loadRegistry();
    }

    public JsonObject interpret(String said, String provider, JsonArray sources, String apiKey)
            throws IOException, ProviderException {
        JsonObject dataset = datasets.get(said);
        if (dataset == null) {
            throw new IllegalArgumentException("Unknown dataset identifier.");
        }

        PaperContext paperContext = selectPaperContext(said);
        String prompt = buildPrompt(dataset, paperContext, sources);
        if (prompt.length() > MAX_PROMPT_CHARS) {
            throw new IllegalArgumentException("The selected results are too large to interpret together.");
        }

        String model;
        String interpretation;
        if ("openai".equals(provider)) {
            model = OPENAI_MODEL;
            interpretation = callOpenAi(apiKey, prompt);
        } else if ("deepseek".equals(provider)) {
            model = DEEPSEEK_MODEL;
            interpretation = callDeepSeek(apiKey, prompt);
        } else {
            throw new IllegalArgumentException("Unsupported provider.");
        }

        JsonObject result = new JsonObject();
        result.addProperty("provider", provider);
        result.addProperty("model", model);
        result.addProperty("interpretation", interpretation);
        result.addProperty("generatedAt", Instant.now().toString());
        result.add("papers", paperContext.references);
        result.addProperty("paperContextMode", paperContext.mode);
        return result;
    }

    private void loadRegistry() throws IOException {
        JsonObject registry = JsonParser.parseString(readResource("literature/registry.json")).getAsJsonObject();
        for (JsonElement item : registry.getAsJsonArray("datasets")) {
            JsonObject dataset = item.getAsJsonObject();
            datasets.put(dataset.get("said").getAsString(), dataset);
        }
        for (JsonElement item : registry.getAsJsonArray("papers")) {
            JsonObject paper = item.getAsJsonObject();
            papers.put(paper.get("paper_id").getAsString(), paper);
        }
        for (JsonElement item : registry.getAsJsonArray("dataset_paper_links")) {
            JsonObject link = item.getAsJsonObject();
            linksBySaid.computeIfAbsent(link.get("said").getAsString(), key -> new ArrayList<>()).add(link);
        }
    }

    private String buildPrompt(JsonObject dataset, PaperContext paperContext, JsonArray sources) {
        JsonObject compactDataset = new JsonObject();
        for (String key : Arrays.asList("said", "study_accession", "sample_accession", "species", "cells",
                "condition", "age", "sex", "tissue", "fine_cell_types", "gross_cell_types",
                "study_title", "study_summary", "overall_design")) {
            if (dataset.has(key)) compactDataset.add(key, dataset.get(key));
        }

        StringBuilder prompt = new StringBuilder(16_384);
        prompt.append("Interpret the selected scSAID results for this dataset.\n\n")
                .append("<dataset_context>\n").append(gson.toJson(compactDataset)).append("\n</dataset_context>\n\n")
                .append("<publication_context mode=\"").append(paperContext.mode).append("\">\n")
                .append(gson.toJson(paperContext.promptPapers)).append("\n</publication_context>\n\n")
                .append("<scsaid_analysis_results>\n").append(gson.toJson(sources))
                .append("\n</scsaid_analysis_results>\n");
        return prompt.toString();
    }

    private PaperContext selectPaperContext(String said) {
        List<JsonObject> links = new ArrayList<>(linksBySaid.getOrDefault(said, Collections.emptyList()));
        links.sort(Comparator.comparingInt(link -> relationRank(string(link, "relation"))));
        JsonArray promptPapers = new JsonArray();
        JsonArray references = new JsonArray();
        Set<String> seen = new HashSet<>();
        boolean hasAbstract = false;
        for (JsonObject link : links) {
            if (promptPapers.size() >= 2) break;
            String relation = string(link, "relation");
            if ("correction".equals(relation)) continue;
            String paperId = string(link, "paper_id");
            if (!seen.add(paperId)) continue;
            JsonObject paper = papers.get(paperId);
            if (paper == null) continue;

            JsonObject context = new JsonObject();
            for (String key : Arrays.asList("title", "pmid", "doi", "journal", "year", "abstract")) {
                if (paper.has(key)) context.add(key, paper.get(key));
            }
            context.addProperty("relation", relation);
            hasAbstract = hasAbstract || !string(paper, "abstract").trim().isEmpty();
            promptPapers.add(context);

            JsonObject reference = new JsonObject();
            reference.addProperty("title", string(paper, "title"));
            reference.addProperty("pmid", string(paper, "pmid"));
            reference.addProperty("doi", string(paper, "doi"));
            reference.addProperty("relation", relation);
            references.add(reference);
        }
        return new PaperContext(promptPapers, references, hasAbstract ? "abstract-plus-geo" : "geo-fallback");
    }

    private int relationRank(String relation) {
        if ("primary_dataset_publication".equals(relation)) return 0;
        if ("repository_linked_publication".equals(relation)) return 1;
        if ("preprint".equals(relation)) return 2;
        return 3;
    }

    private String callOpenAi(String apiKey, String prompt) throws IOException, ProviderException {
        JsonObject body = new JsonObject();
        body.addProperty("model", OPENAI_MODEL);
        body.addProperty("instructions", systemPrompt);
        body.addProperty("input", prompt);
        body.addProperty("store", false);
        body.addProperty("max_output_tokens", 3000);
        JsonObject response = postJson(openAiUrl, apiKey, body, "OpenAI");
        StringBuilder output = new StringBuilder();
        JsonArray items = response.has("output") && response.get("output").isJsonArray()
                ? response.getAsJsonArray("output") : new JsonArray();
        for (JsonElement itemElement : items) {
            JsonObject item = itemElement.getAsJsonObject();
            if (!item.has("content") || !item.get("content").isJsonArray()) continue;
            for (JsonElement contentElement : item.getAsJsonArray("content")) {
                JsonObject content = contentElement.getAsJsonObject();
                if ("output_text".equals(string(content, "type")) && content.has("text")) {
                    if (output.length() > 0) output.append('\n');
                    output.append(content.get("text").getAsString());
                }
            }
        }
        if (output.length() == 0) throw new ProviderException(502, "OpenAI returned no interpretation.");
        return output.toString();
    }

    private String callDeepSeek(String apiKey, String prompt) throws IOException, ProviderException {
        JsonObject body = new JsonObject();
        body.addProperty("model", DEEPSEEK_MODEL);
        JsonArray messages = new JsonArray();
        messages.add(message("system", systemPrompt));
        messages.add(message("user", prompt));
        body.add("messages", messages);
        JsonObject thinking = new JsonObject();
        thinking.addProperty("type", "disabled");
        body.add("thinking", thinking);
        body.addProperty("max_tokens", 3000);
        body.addProperty("stream", false);
        JsonObject response = postJson(deepSeekUrl, apiKey, body, "DeepSeek");
        try {
            String output = response.getAsJsonArray("choices").get(0).getAsJsonObject()
                    .getAsJsonObject("message").get("content").getAsString();
            if (output.trim().isEmpty()) throw new IllegalStateException();
            return output;
        } catch (RuntimeException ex) {
            throw new ProviderException(502, "DeepSeek returned no interpretation.");
        }
    }

    private JsonObject postJson(String endpoint, String apiKey, JsonObject body, String providerName)
            throws IOException, ProviderException {
        HttpURLConnection connection = (HttpURLConnection) new URL(endpoint).openConnection();
        connection.setRequestMethod("POST");
        connection.setDoOutput(true);
        connection.setConnectTimeout(CONNECT_TIMEOUT_MS);
        connection.setReadTimeout(READ_TIMEOUT_MS);
        connection.setRequestProperty("Content-Type", "application/json");
        connection.setRequestProperty("Authorization", "Bearer " + apiKey);
        byte[] bytes = gson.toJson(body).getBytes(StandardCharsets.UTF_8);
        try (OutputStream output = connection.getOutputStream()) {
            output.write(bytes);
        } finally {
            Arrays.fill(bytes, (byte) 0);
        }

        int status = connection.getResponseCode();
        InputStream stream = status >= 200 && status < 300 ? connection.getInputStream() : connection.getErrorStream();
        String responseBody = stream == null ? "" : readLimited(stream, 1_000_000);
        connection.disconnect();
        if (status < 200 || status >= 300) {
            if (status == 401 || status == 403) throw new ProviderException(401, providerName + " rejected the API key.");
            if (status == 402) throw new ProviderException(402, providerName + " reports insufficient account credit.");
            if (status == 429) throw new ProviderException(429, providerName + " rate-limited the request. Please try again later.");
            throw new ProviderException(502, providerName + " could not complete the request.");
        }
        try {
            return JsonParser.parseString(responseBody).getAsJsonObject();
        } catch (RuntimeException ex) {
            throw new ProviderException(502, providerName + " returned an unreadable response.");
        }
    }

    private JsonObject message(String role, String content) {
        JsonObject message = new JsonObject();
        message.addProperty("role", role);
        message.addProperty("content", content);
        return message;
    }

    private String readResource(String path) throws IOException {
        InputStream stream = AIInterpretationService.class.getClassLoader().getResourceAsStream(path);
        if (stream == null) throw new FileNotFoundException("Missing application resource: " + path);
        return readLimited(stream, 8_000_000);
    }

    private String readLimited(InputStream stream, int limit) throws IOException {
        try (Reader reader = new InputStreamReader(stream, StandardCharsets.UTF_8)) {
            char[] buffer = new char[4096];
            StringBuilder value = new StringBuilder();
            int count;
            while ((count = reader.read(buffer)) != -1) {
                if (value.length() + count > limit) throw new IOException("Response exceeded the allowed size.");
                value.append(buffer, 0, count);
            }
            return value.toString();
        }
    }

    private static String string(JsonObject object, String key) {
        return object.has(key) && !object.get(key).isJsonNull() ? object.get(key).getAsString() : "";
    }

    private static final class PaperContext {
        final JsonArray promptPapers;
        final JsonArray references;
        final String mode;

        PaperContext(JsonArray promptPapers, JsonArray references, String mode) {
            this.promptPapers = promptPapers;
            this.references = references;
            this.mode = mode;
        }
    }

    public static final class ProviderException extends Exception {
        private final int status;

        ProviderException(int status, String message) {
            super(message);
            this.status = status;
        }

        public int getStatus() {
            return status;
        }
    }
}
