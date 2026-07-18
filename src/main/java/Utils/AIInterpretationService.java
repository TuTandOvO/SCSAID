package Utils;

import com.google.gson.*;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

/** Builds a sample-resolved, full-paper scientific prompt and calls one provider. */
public class AIInterpretationService {
    public static final String OPENAI_MODEL = "gpt-5-mini";
    public static final String DEEPSEEK_MODEL = "deepseek-v4-flash";
    public static final String CLAUDE_MODEL = "claude-sonnet-5";
    public static final String GEMINI_MODEL = "gemini-3.5-flash";

    private static final int CONNECT_TIMEOUT_MS = 15_000;
    private static final int READ_TIMEOUT_MS = 240_000;
    private static final int MAX_RESPONSE_CHARS = 4_000_000;
    private static final int MAX_SEARCH_USES = 3;

    private final Gson gson = new Gson();
    private final String openAiUrl;
    private final String deepSeekUrl;
    private final String claudeUrl;
    private final String geminiUrl;
    private final String systemPrompt;
    private final LiteratureContextRepository literature;
    private final BiomedicalLiteratureSearch biomedicalSearch;

    public AIInterpretationService() throws IOException {
        this(
                "https://api.openai.com/v1/responses",
                "https://api.deepseek.com/chat/completions",
                "https://api.anthropic.com/v1/messages",
                "https://generativelanguage.googleapis.com/v1beta/models/"
                        + GEMINI_MODEL + ":generateContent",
                new LiteratureContextRepository(),
                new BiomedicalLiteratureSearch()
        );
    }

    AIInterpretationService(String openAiUrl, String deepSeekUrl, String claudeUrl,
                            String geminiUrl, Path literatureRoot) throws IOException {
        this(openAiUrl, deepSeekUrl, claudeUrl, geminiUrl,
                new LiteratureContextRepository(literatureRoot),
                new BiomedicalLiteratureSearch());
    }

    AIInterpretationService(String openAiUrl, String deepSeekUrl, String claudeUrl,
                            String geminiUrl, LiteratureContextRepository literature,
                            BiomedicalLiteratureSearch biomedicalSearch) throws IOException {
        this.openAiUrl = openAiUrl;
        this.deepSeekUrl = deepSeekUrl;
        this.claudeUrl = claudeUrl;
        this.geminiUrl = geminiUrl;
        this.literature = literature;
        this.biomedicalSearch = biomedicalSearch;
        this.systemPrompt = readResource("ai/interpretation-system.txt");
    }

    public JsonObject contextSummary(String said) throws IOException {
        return literature.publicSummary(said);
    }

    public JsonObject interpret(String said, String provider, JsonArray sources,
                                String apiKey, boolean searchCurrentLiterature)
            throws IOException, ProviderException {
        LiteratureContextRepository.Context context = literature.resolve(said);
        String prompt = buildPrompt(context, sources, searchCurrentLiterature);
        enforceContextLimit(provider, prompt.length());

        ProviderResult providerResult;
        String model;
        switch (provider) {
            case "openai":
                model = OPENAI_MODEL;
                providerResult = callOpenAi(apiKey, prompt, searchCurrentLiterature);
                break;
            case "deepseek":
                model = DEEPSEEK_MODEL;
                providerResult = callDeepSeek(apiKey, prompt, searchCurrentLiterature);
                break;
            case "claude":
                model = CLAUDE_MODEL;
                providerResult = callClaude(apiKey, prompt, searchCurrentLiterature);
                break;
            case "gemini":
                model = GEMINI_MODEL;
                providerResult = callGemini(apiKey, prompt, searchCurrentLiterature);
                break;
            default:
                throw new IllegalArgumentException("Unsupported provider.");
        }

        JsonObject result = new JsonObject();
        result.addProperty("provider", provider);
        result.addProperty("model", model);
        result.addProperty("interpretation", providerResult.text);
        result.addProperty("generatedAt", Instant.now().toString());
        result.addProperty("searchCurrentLiterature", searchCurrentLiterature);
        result.add("webSources", deduplicateSources(providerResult.sources));
        result.add("searchSuggestions", providerResult.searchSuggestions.deepCopy());
        result.add("publication", publicationReference(context.publication));
        result.addProperty("paperContextMode",
                context.publication == null ? "no-verified-primary" : "verified-primary-full-text");
        return result;
    }

    private String buildPrompt(LiteratureContextRepository.Context context,
                               JsonArray sources, boolean searchEnabled) {
        JsonObject publication = new JsonObject();
        if (context.publication == null) {
            publication.addProperty("status", "no_verified_primary_publication");
        } else {
            publication.addProperty("status", "verified_primary_full_text");
            publication.add("citation", context.publication.deepCopy());
            publication.addProperty("full_text", context.fullText);
        }

        JsonObject searchPolicy = new JsonObject();
        searchPolicy.addProperty("enabled", searchEnabled);
        searchPolicy.addProperty(
                "instruction",
                searchEnabled
                        ? "Search current literature when it materially improves interpretation. "
                        + "Keep web findings separate and cite returned URLs, PMID, or DOI."
                        : "Do not search online. Use only the supplied sample, publication, and analysis evidence."
        );

        StringBuilder prompt = new StringBuilder(64_000 + context.fullText.length());
        prompt.append("Interpret the selected scSAID results for this exact sample.\n\n")
                .append("<sample_context>\n")
                .append(gson.toJson(context.sampleContext))
                .append("\n</sample_context>\n\n")
                .append("<scsaid_annotations>\n")
                .append(gson.toJson(context.annotations))
                .append("\n</scsaid_annotations>\n\n")
                .append("<publication_context>\n")
                .append(gson.toJson(publication))
                .append("\n</publication_context>\n\n")
                .append("<online_literature_policy>\n")
                .append(gson.toJson(searchPolicy))
                .append("\n</online_literature_policy>\n\n")
                .append("<scsaid_analysis_results>\n")
                .append(gson.toJson(sources))
                .append("\n</scsaid_analysis_results>\n");
        return prompt.toString();
    }

    private void enforceContextLimit(String provider, int characters) {
        int limit;
        switch (provider) {
            case "deepseek":
                limit = 480_000;
                break;
            case "openai":
            case "claude":
                limit = 700_000;
                break;
            case "gemini":
                limit = 1_500_000;
                break;
            default:
                throw new IllegalArgumentException("Unsupported provider.");
        }
        if (characters > limit) {
            throw new IllegalArgumentException(
                    "The complete paper and selected results exceed " + provider
                            + " context capacity. Select fewer analysis results or choose another provider."
            );
        }
    }

    private ProviderResult callOpenAi(String apiKey, String prompt, boolean search)
            throws IOException, ProviderException {
        JsonObject body = new JsonObject();
        body.addProperty("model", OPENAI_MODEL);
        body.addProperty("instructions", systemPrompt);
        body.addProperty("input", prompt);
        body.addProperty("store", false);
        body.addProperty("max_output_tokens", 5000);
        if (search) {
            JsonArray tools = new JsonArray();
            JsonObject webSearch = new JsonObject();
            webSearch.addProperty("type", "web_search");
            tools.add(webSearch);
            body.add("tools", tools);
        }
        JsonObject response = postJson(openAiUrl, body, "OpenAI",
                Collections.singletonMap("Authorization", "Bearer " + apiKey));
        StringBuilder output = new StringBuilder();
        JsonArray sources = new JsonArray();
        JsonArray items = array(response, "output");
        for (JsonElement itemElement : items) {
            if (!itemElement.isJsonObject()) continue;
            JsonObject item = itemElement.getAsJsonObject();
            for (JsonElement contentElement : array(item, "content")) {
                if (!contentElement.isJsonObject()) continue;
                JsonObject content = contentElement.getAsJsonObject();
                if ("output_text".equals(string(content, "type")) && content.has("text")) {
                    appendLine(output, content.get("text").getAsString());
                }
                for (JsonElement annotationElement : array(content, "annotations")) {
                    if (!annotationElement.isJsonObject()) continue;
                    JsonObject annotation = annotationElement.getAsJsonObject();
                    JsonObject citation = annotation.has("url_citation")
                            && annotation.get("url_citation").isJsonObject()
                            ? annotation.getAsJsonObject("url_citation") : annotation;
                    addSource(sources, string(citation, "title"), "OpenAI web search",
                            "", "", string(citation, "url"), "openai");
                }
            }
        }
        if (output.length() == 0) throw new ProviderException(502, "OpenAI returned no interpretation.");
        return new ProviderResult(output.toString(), sources);
    }

    private ProviderResult callClaude(String apiKey, String prompt, boolean search)
            throws IOException, ProviderException {
        JsonObject body = new JsonObject();
        body.addProperty("model", CLAUDE_MODEL);
        body.addProperty("max_tokens", 5000);
        body.addProperty("system", systemPrompt);
        JsonArray messages = new JsonArray();
        messages.add(message("user", prompt));
        body.add("messages", messages);
        if (search) {
            JsonArray tools = new JsonArray();
            JsonObject webSearch = new JsonObject();
            webSearch.addProperty("type", "web_search_20250305");
            webSearch.addProperty("name", "web_search");
            webSearch.addProperty("max_uses", 5);
            tools.add(webSearch);
            body.add("tools", tools);
        }

        Map<String, String> headers = new LinkedHashMap<>();
        headers.put("x-api-key", apiKey);
        headers.put("anthropic-version", "2023-06-01");
        JsonObject response = postJson(claudeUrl, body, "Claude", headers);
        StringBuilder output = new StringBuilder();
        JsonArray sources = new JsonArray();
        for (JsonElement blockElement : array(response, "content")) {
            if (!blockElement.isJsonObject()) continue;
            JsonObject block = blockElement.getAsJsonObject();
            if ("text".equals(string(block, "type")) && block.has("text")) {
                appendLine(output, block.get("text").getAsString());
            }
            for (JsonElement citationElement : array(block, "citations")) {
                if (!citationElement.isJsonObject()) continue;
                JsonObject citation = citationElement.getAsJsonObject();
                addSource(sources, string(citation, "title"), "Claude web search",
                        "", "", first(string(citation, "url"), string(citation, "source")), "claude");
            }
            if ("web_search_tool_result".equals(string(block, "type"))) {
                for (JsonElement resultElement : array(block, "content")) {
                    if (!resultElement.isJsonObject()) continue;
                    JsonObject item = resultElement.getAsJsonObject();
                    addSource(sources, string(item, "title"), "Claude web search",
                            "", "", string(item, "url"), "claude");
                }
            }
        }
        if (output.length() == 0) throw new ProviderException(502, "Claude returned no interpretation.");
        return new ProviderResult(output.toString(), sources);
    }

    private ProviderResult callGemini(String apiKey, String prompt, boolean search)
            throws IOException, ProviderException {
        JsonObject body = new JsonObject();
        JsonObject systemInstruction = new JsonObject();
        JsonArray systemParts = new JsonArray();
        JsonObject systemPart = new JsonObject();
        systemPart.addProperty("text", systemPrompt);
        systemParts.add(systemPart);
        systemInstruction.add("parts", systemParts);
        body.add("system_instruction", systemInstruction);

        JsonArray contents = new JsonArray();
        JsonObject userContent = new JsonObject();
        userContent.addProperty("role", "user");
        JsonArray userParts = new JsonArray();
        JsonObject userPart = new JsonObject();
        userPart.addProperty("text", prompt);
        userParts.add(userPart);
        userContent.add("parts", userParts);
        contents.add(userContent);
        body.add("contents", contents);
        JsonObject generationConfig = new JsonObject();
        generationConfig.addProperty("maxOutputTokens", 5000);
        body.add("generationConfig", generationConfig);
        if (search) {
            JsonArray tools = new JsonArray();
            JsonObject tool = new JsonObject();
            tool.add("google_search", new JsonObject());
            tools.add(tool);
            body.add("tools", tools);
        }

        JsonObject response = postJson(geminiUrl, body, "Gemini",
                Collections.singletonMap("x-goog-api-key", apiKey));
        StringBuilder output = new StringBuilder();
        JsonArray sources = new JsonArray();
        JsonArray queries = new JsonArray();
        try {
            JsonObject candidate = response.getAsJsonArray("candidates").get(0).getAsJsonObject();
            for (JsonElement partElement : candidate.getAsJsonObject("content").getAsJsonArray("parts")) {
                JsonObject part = partElement.getAsJsonObject();
                if (part.has("text")) appendLine(output, part.get("text").getAsString());
            }
            if (candidate.has("groundingMetadata")) {
                JsonObject grounding = candidate.getAsJsonObject("groundingMetadata");
                for (JsonElement chunkElement : array(grounding, "groundingChunks")) {
                    if (!chunkElement.isJsonObject()) continue;
                    JsonObject chunk = chunkElement.getAsJsonObject();
                    JsonObject web = chunk.has("web") && chunk.get("web").isJsonObject()
                            ? chunk.getAsJsonObject("web") : chunk;
                    addSource(sources, string(web, "title"), "Google Search",
                            "", "", string(web, "uri"), "gemini");
                }
                for (JsonElement query : array(grounding, "webSearchQueries")) {
                    if (query.isJsonPrimitive()) queries.add(query.getAsString());
                }
            }
        } catch (RuntimeException ignored) {
            // Normalized below; provider payload details never reach the browser.
        }
        if (output.length() == 0) throw new ProviderException(502, "Gemini returned no interpretation.");
        return new ProviderResult(output.toString(), sources, queries);
    }

    private ProviderResult callDeepSeek(String apiKey, String prompt, boolean search)
            throws IOException, ProviderException {
        JsonArray messages = new JsonArray();
        messages.add(message("system", systemPrompt));
        messages.add(message("user", prompt));
        JsonArray accumulatedSources = new JsonArray();

        for (int use = 0; use <= MAX_SEARCH_USES; use++) {
            JsonObject body = new JsonObject();
            body.addProperty("model", DEEPSEEK_MODEL);
            body.add("messages", messages.deepCopy());
            JsonObject thinking = new JsonObject();
            thinking.addProperty("type", "disabled");
            body.add("thinking", thinking);
            body.addProperty("max_tokens", 5000);
            body.addProperty("stream", false);
            if (search) body.add("tools", deepSeekSearchTools());

            JsonObject response = postJson(deepSeekUrl, body, "DeepSeek",
                    Collections.singletonMap("Authorization", "Bearer " + apiKey));
            JsonObject assistant;
            try {
                assistant = response.getAsJsonArray("choices").get(0).getAsJsonObject()
                        .getAsJsonObject("message");
            } catch (RuntimeException ex) {
                throw new ProviderException(502, "DeepSeek returned no interpretation.");
            }
            JsonArray toolCalls = array(assistant, "tool_calls");
            if (!search || toolCalls.size() == 0) {
                String output = string(assistant, "content");
                if (output.trim().isEmpty()) {
                    throw new ProviderException(502, "DeepSeek returned no interpretation.");
                }
                return new ProviderResult(output, accumulatedSources);
            }
            if (use == MAX_SEARCH_USES) {
                throw new ProviderException(502, "DeepSeek exceeded the literature-search limit.");
            }
            messages.add(assistant.deepCopy());
            for (JsonElement callElement : toolCalls) {
                JsonObject call = callElement.getAsJsonObject();
                JsonObject function = call.getAsJsonObject("function");
                if (!"search_biomedical_literature".equals(string(function, "name"))) continue;
                String query;
                try {
                    query = JsonParser.parseString(string(function, "arguments"))
                            .getAsJsonObject().get("query").getAsString();
                } catch (RuntimeException ex) {
                    throw new ProviderException(502, "DeepSeek requested an invalid literature search.");
                }
                BiomedicalLiteratureSearch.SearchResult searched = biomedicalSearch.search(query);
                accumulatedSources.addAll(searched.sources);
                JsonObject toolMessage = message("tool", searched.toolJson);
                toolMessage.addProperty("tool_call_id", string(call, "id"));
                messages.add(toolMessage);
            }
        }
        throw new ProviderException(502, "DeepSeek could not complete the interpretation.");
    }

    private JsonArray deepSeekSearchTools() {
        JsonObject parameters = new JsonObject();
        parameters.addProperty("type", "object");
        JsonObject properties = new JsonObject();
        JsonObject query = new JsonObject();
        query.addProperty("type", "string");
        query.addProperty("description", "A concise biomedical literature query.");
        properties.add("query", query);
        parameters.add("properties", properties);
        JsonArray required = new JsonArray();
        required.add("query");
        parameters.add("required", required);

        JsonObject function = new JsonObject();
        function.addProperty("name", "search_biomedical_literature");
        function.addProperty("description",
                "Search current PubMed-indexed biomedical literature through Europe PMC.");
        function.add("parameters", parameters);
        JsonObject tool = new JsonObject();
        tool.addProperty("type", "function");
        tool.add("function", function);
        JsonArray tools = new JsonArray();
        tools.add(tool);
        return tools;
    }

    private JsonObject postJson(String endpoint, JsonObject body, String providerName,
                                Map<String, String> headers)
            throws IOException, ProviderException {
        HttpURLConnection connection = (HttpURLConnection) new URL(endpoint).openConnection();
        connection.setRequestMethod("POST");
        connection.setDoOutput(true);
        connection.setConnectTimeout(CONNECT_TIMEOUT_MS);
        connection.setReadTimeout(READ_TIMEOUT_MS);
        connection.setRequestProperty("Content-Type", "application/json");
        for (Map.Entry<String, String> header : headers.entrySet()) {
            connection.setRequestProperty(header.getKey(), header.getValue());
        }
        byte[] bytes = gson.toJson(body).getBytes(StandardCharsets.UTF_8);
        try (OutputStream output = connection.getOutputStream()) {
            output.write(bytes);
        } finally {
            Arrays.fill(bytes, (byte) 0);
        }

        int status = connection.getResponseCode();
        InputStream stream = status >= 200 && status < 300
                ? connection.getInputStream() : connection.getErrorStream();
        String responseBody = stream == null ? "" : readLimited(stream, MAX_RESPONSE_CHARS);
        connection.disconnect();
        if (status < 200 || status >= 300) {
            if (status == 401 || status == 403) {
                throw new ProviderException(401, providerName + " rejected the API key.");
            }
            if (status == 402) {
                throw new ProviderException(402, providerName + " reports insufficient account credit.");
            }
            if (status == 413) {
                throw new ProviderException(413,
                        providerName + " rejected the complete paper because the request is too large.");
            }
            if (status == 429) {
                throw new ProviderException(429,
                        providerName + " rate-limited the request. Please try again later.");
            }
            throw new ProviderException(502, providerName + " could not complete the request.");
        }
        try {
            return JsonParser.parseString(responseBody).getAsJsonObject();
        } catch (RuntimeException ex) {
            throw new ProviderException(502, providerName + " returned an unreadable response.");
        }
    }

    private JsonObject publicationReference(JsonObject publication) {
        JsonObject reference = new JsonObject();
        if (publication == null) {
            reference.addProperty("status", "no_verified_primary");
            return reference;
        }
        reference.addProperty("status", "verified_primary");
        for (String key : Arrays.asList("title", "pmid", "doi", "journal", "year")) {
            if (publication.has(key)) reference.add(key, publication.get(key).deepCopy());
        }
        return reference;
    }

    private JsonArray deduplicateSources(JsonArray sources) {
        JsonArray result = new JsonArray();
        Set<String> seen = new LinkedHashSet<>();
        for (JsonElement element : sources) {
            if (!element.isJsonObject()) continue;
            JsonObject source = element.getAsJsonObject();
            String key = first(string(source, "url"), string(source, "doi"),
                    string(source, "pmid"), string(source, "title"));
            if (!key.isEmpty() && seen.add(key)) result.add(source);
        }
        return result;
    }

    private void addSource(JsonArray target, String title, String source, String pmid,
                           String doi, String url, String provider) {
        if (url == null || !url.matches("https://.+")) return;
        JsonObject item = new JsonObject();
        item.addProperty("title", title == null || title.trim().isEmpty() ? url : title);
        item.addProperty("source", source);
        item.addProperty("pmid", pmid);
        item.addProperty("doi", doi);
        item.addProperty("url", url);
        item.addProperty("provider", provider);
        item.addProperty("retrievedAt", LocalDate.now().toString());
        target.add(item);
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
        return readLimited(stream, 1_000_000);
    }

    private String readLimited(InputStream stream, int limit) throws IOException {
        try (Reader reader = new InputStreamReader(stream, StandardCharsets.UTF_8)) {
            char[] buffer = new char[8192];
            StringBuilder value = new StringBuilder();
            int count;
            while ((count = reader.read(buffer)) != -1) {
                if (value.length() + count > limit) {
                    throw new IOException("Provider response exceeded the allowed size.");
                }
                value.append(buffer, 0, count);
            }
            return value.toString();
        }
    }

    private static JsonArray array(JsonObject object, String key) {
        return object != null && object.has(key) && object.get(key).isJsonArray()
                ? object.getAsJsonArray(key) : new JsonArray();
    }

    private static String string(JsonObject object, String key) {
        return object != null && object.has(key) && !object.get(key).isJsonNull()
                ? object.get(key).getAsString() : "";
    }

    private static String first(String... values) {
        for (String value : values) {
            if (value != null && !value.trim().isEmpty()) return value;
        }
        return "";
    }

    private static void appendLine(StringBuilder target, String value) {
        if (value == null || value.trim().isEmpty()) return;
        if (target.length() > 0) target.append('\n');
        target.append(value);
    }

    private static final class ProviderResult {
        final String text;
        final JsonArray sources;
        final JsonArray searchSuggestions;

        ProviderResult(String text, JsonArray sources) {
            this(text, sources, new JsonArray());
        }

        ProviderResult(String text, JsonArray sources, JsonArray searchSuggestions) {
            this.text = text;
            this.sources = sources;
            this.searchSuggestions = searchSuggestions;
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
