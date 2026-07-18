package Utils;

import com.google.gson.*;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;

import java.io.*;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.NoSuchElementException;
import java.util.concurrent.RejectedExecutionException;

import static org.junit.jupiter.api.Assertions.*;

class AIInterpretationJobManagerTest {
    @TempDir
    Path literatureRoot;
    private HttpServer server;
    private AIInterpretationJobManager jobs;

    @BeforeEach
    void setUp() throws Exception {
        Files.createDirectories(literatureRoot.resolve("text"));
        Files.writeString(
                literatureRoot.resolve("text/PMID_39483478.txt"),
                "Complete verified paper. ".repeat(100),
                StandardCharsets.UTF_8
        );
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/openai", exchange -> {
            exchange.getRequestBody().readAllBytes();
            byte[] response = ("{\"output\":[{\"content\":[{\"type\":\"output_text\","
                    + "\"text\":\"## Deep interpretation\\nComplete\"}]}]}")
                    .getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, response.length);
            try (OutputStream output = exchange.getResponseBody()) {
                output.write(response);
            }
        });
        server.start();
        String base = "http://127.0.0.1:" + server.getAddress().getPort();
        AIInterpretationService service = new AIInterpretationService(
                base + "/openai", base + "/deepseek", base + "/claude",
                base + "/gemini", literatureRoot
        );
        jobs = new AIInterpretationJobManager(service);
    }

    @AfterEach
    void tearDown() {
        if (jobs != null) jobs.close();
        if (server != null) server.stop(0);
    }

    @Test
    void jobIsSessionBoundAndReturnsNoCredential() throws Exception {
        char[] key = "sk-job-test-secret".toCharArray();
        String id = jobs.submit("session-a", "SAID001", "openai", sources(), key, false);
        assertThrows(NoSuchElementException.class, () -> jobs.status(id, "session-b"));

        JsonObject status = null;
        for (int attempt = 0; attempt < 50; attempt++) {
            status = jobs.status(id, "session-a");
            if ("completed".equals(status.get("status").getAsString())) break;
            Thread.sleep(20);
        }
        assertNotNull(status);
        assertEquals("completed", status.get("status").getAsString());
        JsonObject result = jobs.result(id, "session-a");
        assertTrue(result.get("interpretation").getAsString().contains("Complete"));
        assertFalse(result.toString().contains("sk-job-test-secret"));
    }

    @Test
    void limitsRapidSubmissionsPerSessionAndClearsRejectedCredential() {
        for (int index = 0; index < 4; index++) {
            jobs.submit(
                    "rate-limited-session", "SAID001", "openai", sources(),
                    ("sk-rate-test-" + index).toCharArray(), false
            );
        }
        char[] rejectedKey = "sk-rate-test-rejected".toCharArray();
        assertThrows(
                RejectedExecutionException.class,
                () -> jobs.submit(
                        "rate-limited-session", "SAID001", "openai", sources(),
                        rejectedKey, false
                )
        );
        for (char character : rejectedKey) {
            assertEquals('\0', character);
        }
    }

    private JsonArray sources() {
        JsonObject source = new JsonObject();
        source.addProperty("type", "deg");
        source.add("parameters", new JsonObject());
        source.add("data", new JsonArray());
        JsonArray sources = new JsonArray();
        sources.add(source);
        return sources;
    }
}
