package Utils;

import com.google.gson.*;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.*;

import java.io.*;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.*;

class AIInterpretationServiceTest {
    private HttpServer server;
    private String baseUrl;
    private final AtomicReference<String> authorization = new AtomicReference<>();
    private final AtomicReference<String> requestBody = new AtomicReference<>();

    @BeforeEach
    void startServer() throws IOException {
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
        AIInterpretationService service = new AIInterpretationService(baseUrl + "/openai", baseUrl + "/deepseek");
        String secret = "sk-test-secret-never-log";

        JsonObject result = service.interpret("SAID001", "openai", sourcePayload(), secret);

        assertEquals("Bearer " + secret, authorization.get());
        assertFalse(requestBody.get().contains(secret));
        JsonObject upstream = JsonParser.parseString(requestBody.get()).getAsJsonObject();
        assertEquals(AIInterpretationService.OPENAI_MODEL, upstream.get("model").getAsString());
        assertFalse(upstream.get("store").getAsBoolean());
        assertTrue(upstream.get("input").getAsString().contains("SAID001"));
        assertTrue(upstream.get("input").getAsString().contains("publication_context"));
        assertEquals("## Executive interpretation\nResult", result.get("interpretation").getAsString());
        assertFalse(result.toString().contains(secret));
    }

    @Test
    void deepSeekUsesCurrentModelAndNonThinkingSingleTurnRequest() throws Exception {
        server.createContext("/deepseek", exchange -> respond(exchange, 200,
                "{\"choices\":[{\"message\":{\"content\":\"## Executive interpretation\\nDeepSeek result\"}}]}"));
        AIInterpretationService service = new AIInterpretationService(baseUrl + "/openai", baseUrl + "/deepseek");

        JsonObject result = service.interpret("SAID001", "deepseek", sourcePayload(), "sk-deepseek-test");

        JsonObject upstream = JsonParser.parseString(requestBody.get()).getAsJsonObject();
        assertEquals(AIInterpretationService.DEEPSEEK_MODEL, upstream.get("model").getAsString());
        assertEquals("disabled", upstream.getAsJsonObject("thinking").get("type").getAsString());
        assertEquals(2, upstream.getAsJsonArray("messages").size());
        assertEquals("DeepSeek result", result.get("interpretation").getAsString().split("\\n")[1]);
    }

    @Test
    void providerErrorsAreNormalizedWithoutEchoingBodyOrSecret() throws Exception {
        server.createContext("/openai", exchange -> respond(exchange, 401,
                "{\"error\":\"upstream details must not escape\"}"));
        AIInterpretationService service = new AIInterpretationService(baseUrl + "/openai", baseUrl + "/deepseek");
        String secret = "sk-private-test-value";

        AIInterpretationService.ProviderException error = assertThrows(
                AIInterpretationService.ProviderException.class,
                () -> service.interpret("SAID001", "openai", sourcePayload(), secret));

        assertEquals(401, error.getStatus());
        assertFalse(error.getMessage().contains(secret));
        assertFalse(error.getMessage().contains("upstream details"));
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

    private void respond(HttpExchange exchange, int status, String response) throws IOException {
        authorization.set(exchange.getRequestHeaders().getFirst("Authorization"));
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
