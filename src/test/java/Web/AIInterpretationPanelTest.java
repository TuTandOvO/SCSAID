package Web;

import com.google.gson.*;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.*;

import static org.junit.jupiter.api.Assertions.*;

class AIInterpretationPanelTest {
    private static final Path ROOT = Path.of(".");

    @Test
    void detailPageUsesConsentFirstBackgroundJobKeyFlow() throws Exception {
        String jsp = Files.readString(ROOT.resolve("src/main/webapp/details.jsp"), StandardCharsets.UTF_8);
        String script = Files.readString(ROOT.resolve("src/main/webapp/JS/ai-interpretation.js"), StandardCharsets.UTF_8);

        assertTrue(jsp.contains("id=\"AIInterpretation\""));
        assertTrue(jsp.contains("aria-label=\"Beta feature\">Beta"));
        assertTrue(jsp.contains("id=\"aiPrivacyConsent\""));
        assertTrue(jsp.contains("id=\"aiPublicationConsent\""));
        assertTrue(jsp.contains("id=\"aiSearchCurrentLiterature\" checked"));
        assertTrue(jsp.contains("id=\"aiContextSummary\""));
        assertTrue(jsp.contains("type=\"password\" autocomplete=\"off\""));
        assertTrue(jsp.contains("data-ai-source=\"cell_communication\""));
        assertTrue(jsp.contains("data-ai-source=\"regulatory_network\""));
        assertTrue(jsp.contains("LLM Interpretation"));
        assertTrue(jsp.contains("name=\"aiProvider\" value=\"claude\""));
        assertTrue(jsp.contains("name=\"aiProvider\" value=\"gemini\""));
        assertTrue(script.contains("X-scSAID-Provider-Key"));
        assertTrue(script.contains("keyInput.value = \"\""));
        assertTrue(script.contains("action=status"));
        assertTrue(script.contains("action=result"));
        assertFalse(script.contains("localStorage"));
        assertFalse(script.contains("sessionStorage"));
        assertFalse(script.contains("document.cookie"));
        assertFalse(script.contains("innerHTML"));
    }

    @Test
    void runtimeIndexesAreSampleResolvedAndSelectOnlyCanonicalPrimaryPapers() throws Exception {
        JsonObject registry = JsonParser.parseString(Files.readString(
                ROOT.resolve("literature/registry.json"), StandardCharsets.UTF_8)).getAsJsonObject();
        JsonObject samples = JsonParser.parseString(Files.readString(
                ROOT.resolve("literature/sample_context.json"), StandardCharsets.UTF_8)).getAsJsonObject();
        JsonObject selections = JsonParser.parseString(Files.readString(
                ROOT.resolve("literature/canonical_sample_papers.json"), StandardCharsets.UTF_8)).getAsJsonObject();

        assertEquals(2, registry.get("schema_version").getAsInt());
        assertEquals(252, registry.getAsJsonArray("datasets").size());
        assertEquals(252, samples.get("count").getAsInt());
        assertEquals(252, selections.get("count").getAsInt());
        JsonObject said003 = samples.getAsJsonObject("samples").getAsJsonObject("SAID003");
        assertEquals("GSM8316003", said003.get("sample_accession").getAsString());
        assertEquals("AA+Ab", said003.getAsJsonObject("metadata").get("title").getAsString());
        long primary = selections.getAsJsonArray("samples").asList().stream()
                .map(JsonElement::getAsJsonObject)
                .filter(item -> "verified_primary".equals(item.get("status").getAsString()))
                .count();
        assertEquals(128, primary);
        assertTrue(selections.getAsJsonArray("samples").asList().stream()
                .map(JsonElement::getAsJsonObject)
                .filter(item -> "verified_primary".equals(item.get("status").getAsString()))
                .allMatch(item -> item.has("paper_id")));
    }
}
