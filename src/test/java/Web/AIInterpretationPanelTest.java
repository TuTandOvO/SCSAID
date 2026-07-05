package Web;

import com.google.gson.*;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.*;

import static org.junit.jupiter.api.Assertions.*;

class AIInterpretationPanelTest {
    private static final Path ROOT = Path.of(".");

    @Test
    void detailPageUsesConsentFirstOneShotKeyFlow() throws Exception {
        String jsp = Files.readString(ROOT.resolve("src/main/webapp/details.jsp"), StandardCharsets.UTF_8);
        String script = Files.readString(ROOT.resolve("src/main/webapp/JS/ai-interpretation.js"), StandardCharsets.UTF_8);

        assertTrue(jsp.contains("id=\"AIInterpretation\""));
        assertTrue(jsp.contains("aria-label=\"Beta feature\">Beta"));
        assertTrue(jsp.contains("id=\"aiPrivacyConsent\""));
        assertTrue(jsp.contains("type=\"password\" autocomplete=\"new-password\""));
        assertTrue(jsp.contains("data-ai-source=\"cell_communication\""));
        assertTrue(jsp.contains("data-ai-source=\"regulatory_network\""));
        assertTrue(jsp.contains("LLM Interpretation"));
        assertTrue(jsp.contains("name=\"aiProvider\" value=\"claude\""));
        assertTrue(jsp.contains("name=\"aiProvider\" value=\"gemini\""));
        assertTrue(script.contains("X-scSAID-Provider-Key"));
        assertTrue(script.contains("keyInput.value = \"\""));
        assertFalse(script.contains("localStorage"));
        assertFalse(script.contains("sessionStorage"));
        assertFalse(script.contains("document.cookie"));
        assertFalse(script.contains("innerHTML"));
    }

    @Test
    void registryContainsDatasetMetadataAndPaperAbstracts() throws Exception {
        JsonObject registry = JsonParser.parseString(Files.readString(
                ROOT.resolve("literature/registry.json"), StandardCharsets.UTF_8)).getAsJsonObject();

        assertEquals(2, registry.get("schema_version").getAsInt());
        assertEquals(252, registry.getAsJsonArray("datasets").size());
        assertTrue(registry.getAsJsonArray("datasets").get(0).getAsJsonObject().has("condition"));
        long abstracts = registry.getAsJsonArray("papers").asList().stream()
                .map(JsonElement::getAsJsonObject)
                .filter(paper -> paper.has("abstract") && !paper.get("abstract").getAsString().isEmpty())
                .count();
        assertTrue(abstracts >= 45, "Expected broad PubMed abstract coverage");
    }
}
