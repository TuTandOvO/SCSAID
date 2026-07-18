package Utils;

import com.google.gson.*;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;

import java.io.*;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.*;

class AIInterpretationServiceTest {
    @TempDir
    Path literatureRoot;
    private HttpServer server;
    private String baseUrl;
    private final AtomicReference<String> authorization = new AtomicReference<>();
    private final AtomicReference<String> providerKey = new AtomicReference<>();
    private final AtomicReference<String> anthropicVersion = new AtomicReference<>();
    private final AtomicReference<String> requestBody = new AtomicReference<>();

    @BeforeEach
    void startServer() throws IOException {
        Files.createDirectories(literatureRoot.resolve("text"));
        Files.writeString(
                literatureRoot.resolve("text/PMID_39483478.txt"),
                "Paper ID: PMID_39483478\nPMID: 39483478\nDOI: 10.3389/fimmu.2024.1444777\n"
                        + "Complete canonical article text. ".repeat(100),
                StandardCharsets.UTF_8
        );
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        baseUrl = "http://127.0.0.1:" + server.getAddress().getPort();
        server.start();
    }

    @AfterEach
    void stopServer() {
        server.stop(0);
    }

    @Test
    void openAiUsesOneAuthorizationHeaderAndStatelessResponseRequest() throws Exception {
        server.createContext("/openai", exchange -> respond(exchange, 200,
                "{\"output\":[{\"content\":[{\"type\":\"output_text\",\"text\":\"## Executive interpretation\\nResult\"}]}]}"));
        AIInterpretationService service = service();
        String secret = "sk-test-secret-never-log";

        JsonObject result = service.interpret("SAID001", "openai", sourcePayload(), secret, false);

        assertEquals("Bearer " + secret, authorization.get());
        assertFalse(requestBody.get().contains(secret));
        JsonObject upstream = JsonParser.parseString(requestBody.get()).getAsJsonObject();
        assertEquals(AIInterpretationService.OPENAI_MODEL, upstream.get("model").getAsString());
        assertFalse(upstream.get("store").getAsBoolean());
        assertTrue(upstream.get("input").getAsString().contains("SAID001"));
        String prompt = upstream.get("input").getAsString();
        assertTrue(prompt.contains("<sample_context>"));
        assertTrue(prompt.contains("\"sample_accession\":\"GSM8316001\""));
        assertTrue(prompt.contains("Complete canonical article text"));
        assertFalse(prompt.contains("\"study_summary\""));
        assertTrue(prompt.contains("<publication_context>"));
        assertEquals("## Executive interpretation\nResult", result.get("interpretation").getAsString());
        assertFalse(result.toString().contains(secret));
    }

    @Test
    void deepSeekUsesCurrentModelAndNonThinkingSingleTurnRequest() throws Exception {
        server.createContext("/deepseek", exchange -> respond(exchange, 200,
                "{\"choices\":[{\"message\":{\"content\":\"## Executive interpretation\\nDeepSeek result\"}}]}"));
        AIInterpretationService service = service();

        JsonObject result = service.interpret(
                "SAID001", "deepseek", sourcePayload(), "sk-deepseek-test", false);

        JsonObject upstream = JsonParser.parseString(requestBody.get()).getAsJsonObject();
        assertEquals(AIInterpretationService.DEEPSEEK_MODEL, upstream.get("model").getAsString());
        assertEquals("disabled", upstream.getAsJsonObject("thinking").get("type").getAsString());
        assertEquals(2, upstream.getAsJsonArray("messages").size());
        assertEquals("DeepSeek result", result.get("interpretation").getAsString().split("\\n")[1]);
    }

    @Test
    void claudeUsesApiKeyHeaderAndMessagesApiShape() throws Exception {
        server.createContext("/claude", exchange -> respond(exchange, 200,
                "{\"content\":[{\"type\":\"text\",\"text\":\"## Deep interpretation\\nClaude result\"}]}"));
        AIInterpretationService service = service();
        String secret = "sk-ant-test-secret";

        JsonObject result = service.interpret("SAID001", "claude", sourcePayload(), secret, true);

        assertEquals(secret, providerKey.get());
        assertEquals("2023-06-01", anthropicVersion.get());
        assertNull(authorization.get());
        assertFalse(requestBody.get().contains(secret));
        JsonObject upstream = JsonParser.parseString(requestBody.get()).getAsJsonObject();
        assertEquals(AIInterpretationService.CLAUDE_MODEL, upstream.get("model").getAsString());
        assertEquals("web_search_20250305", upstream.getAsJsonArray("tools").get(0)
                .getAsJsonObject().get("type").getAsString());
        assertTrue(upstream.get("system").getAsString().contains("computational skin biologist"));
        assertEquals("user", upstream.getAsJsonArray("messages").get(0).getAsJsonObject()
                .get("role").getAsString());
        assertEquals("claude", result.get("provider").getAsString());
        assertTrue(result.get("interpretation").getAsString().contains("Claude result"));
    }

    @Test
    void geminiUsesApiKeyHeaderAndGenerateContentShape() throws Exception {
        server.createContext("/gemini", exchange -> respond(exchange, 200,
                "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"## Deep interpretation\\nGemini result\"}]}}]}"));
        AIInterpretationService service = service();
        String secret = "AIza-test-secret";

        JsonObject result = service.interpret("SAID001", "gemini", sourcePayload(), secret, true);

        assertEquals(secret, providerKey.get());
        assertNull(authorization.get());
        assertFalse(requestBody.get().contains(secret));
        JsonObject upstream = JsonParser.parseString(requestBody.get()).getAsJsonObject();
        assertTrue(upstream.getAsJsonObject("system_instruction").getAsJsonArray("parts")
                .get(0).getAsJsonObject().get("text").getAsString().contains("computational skin biologist"));
        assertEquals("user", upstream.getAsJsonArray("contents").get(0).getAsJsonObject()
                .get("role").getAsString());
        assertEquals(5000, upstream.getAsJsonObject("generationConfig").get("maxOutputTokens").getAsInt());
        assertTrue(upstream.getAsJsonArray("tools").get(0).getAsJsonObject().has("google_search"));
        assertEquals(AIInterpretationService.GEMINI_MODEL, result.get("model").getAsString());
        assertTrue(result.get("interpretation").getAsString().contains("Gemini result"));
    }

    @Test
    void providerErrorsAreNormalizedWithoutEchoingBodyOrSecret() throws Exception {
        server.createContext("/openai", exchange -> respond(exchange, 401,
                "{\"error\":\"upstream details must not escape\"}"));
        AIInterpretationService service = service();
        String secret = "sk-private-test-value";

        AIInterpretationService.ProviderException error = assertThrows(
                AIInterpretationService.ProviderException.class,
                () -> service.interpret("SAID001", "openai", sourcePayload(), secret, false));

        assertEquals(401, error.getStatus());
        assertFalse(error.getMessage().contains(secret));
        assertFalse(error.getMessage().contains("upstream details"));
    }

    @Test
    void rejectsCompleteArticleThatExceedsProviderContextWithoutTruncatingIt() throws Exception {
        Files.writeString(
                literatureRoot.resolve("text/PMID_39483478.txt"),
                "Complete canonical article text. ".repeat(24_000),
                StandardCharsets.UTF_8
        );
        AIInterpretationService service = service();

        IllegalArgumentException error = assertThrows(
                IllegalArgumentException.class,
                () -> service.interpret(
                        "SAID001", "openai", sourcePayload(), "sk-context-test", false
                )
        );

        assertTrue(error.getMessage().contains("complete paper"));
        assertNull(requestBody.get());
    }

    @Test
    void deepSeekUsesBoundedBiomedicalSearchToolLoop() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        server.createContext("/deepseek-search", exchange -> {
            if (calls.getAndIncrement() == 0) {
                respond(exchange, 200, "{\"choices\":[{\"message\":{\"content\":\"\","
                        + "\"tool_calls\":[{\"id\":\"call-1\",\"type\":\"function\","
                        + "\"function\":{\"name\":\"search_biomedical_literature\","
                        + "\"arguments\":\"{\\\"query\\\":\\\"skin fibrosis single cell\\\"}\"}}]}}]}");
            } else {
                respond(exchange, 200, "{\"choices\":[{\"message\":{\"content\":"
                        + "\"## Deep interpretation\\nSearch-backed result\"}}]}");
            }
        });
        BiomedicalLiteratureSearch search = new BiomedicalLiteratureSearch() {
            @Override
            public SearchResult search(String query) {
                JsonArray sources = new JsonArray();
                JsonObject source = new JsonObject();
                source.addProperty("title", "Verified search result");
                source.addProperty("source", "Europe PMC / PubMed");
                source.addProperty("pmid", "123456");
                source.addProperty("doi", "");
                source.addProperty("url", "https://pubmed.ncbi.nlm.nih.gov/123456/");
                source.addProperty("provider", "deepseek");
                sources.add(source);
                return new SearchResult("{\"results\":[{\"pmid\":\"123456\"}]}", sources);
            }
        };
        AIInterpretationService service = new AIInterpretationService(
                baseUrl + "/openai", baseUrl + "/deepseek-search",
                baseUrl + "/claude", baseUrl + "/gemini",
                new LiteratureContextRepository(literatureRoot), search
        );

        JsonObject result = service.interpret(
                "SAID001", "deepseek", sourcePayload(), "sk-deepseek-test", true);

        assertEquals(2, calls.get());
        assertTrue(result.get("interpretation").getAsString().contains("Search-backed"));
        assertEquals("123456", result.getAsJsonArray("webSources").get(0)
                .getAsJsonObject().get("pmid").getAsString());
    }

    private JsonArray sourcePayload() {
        JsonObject source = new JsonObject();
        source.addProperty("type", "deg");
        source.add("parameters", JsonParser.parseString("{\"pval_max\":0.05}"));
        source.add("data", JsonParser.parseString("[{\"gene\":\"Krt14\",\"logFC\":2.1}]"));
        JsonArray sources = new JsonArray();
        sources.add(source);
        return sources;
    }

    private AIInterpretationService service() throws IOException {
        return new AIInterpretationService(baseUrl + "/openai", baseUrl + "/deepseek",
                baseUrl + "/claude", baseUrl + "/gemini", literatureRoot);
    }

    private void respond(HttpExchange exchange, int status, String response) throws IOException {
        authorization.set(exchange.getRequestHeaders().getFirst("Authorization"));
        providerKey.set(exchange.getRequestHeaders().getFirst("x-api-key") != null
                ? exchange.getRequestHeaders().getFirst("x-api-key")
                : exchange.getRequestHeaders().getFirst("x-goog-api-key"));
        anthropicVersion.set(exchange.getRequestHeaders().getFirst("anthropic-version"));
        requestBody.set(read(exchange.getRequestBody()));
        byte[] bytes = response.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length);
        try (OutputStream output = exchange.getResponseBody()) {
            output.write(bytes);
        }
    }

    private String read(InputStream stream) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[1024];
        int count;
        while ((count = stream.read(buffer)) != -1) output.write(buffer, 0, count);
        return output.toString(StandardCharsets.UTF_8.name());
    }
}
