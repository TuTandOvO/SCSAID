package Web;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PreferenceSystemTest {
    private static final Path WEBAPP = Path.of("src/main/webapp");

    private static String read(String relativePath) throws Exception {
        return Files.readString(WEBAPP.resolve(relativePath), StandardCharsets.UTF_8);
    }

    @Test
    void storesOnlyAllowlistedInterfacePreferences() throws Exception {
        String script = read("JS/site-preferences.js");

        assertTrue(script.contains("var allowedKeys = { species: true, hidePseudogenes: true }"));
        assertTrue(script.contains("scsaid.preferences.v1"));
        assertTrue(script.contains("window.ScsaidPreferences"));
        assertFalse(script.contains("geneSearch:"));
        assertFalse(script.contains("analysisResults:"));
        assertFalse(script.contains("document.cookie"));
    }

    @Test
    void sharedControlsUseThePreferenceLayer() throws Exception {
        String compare = read("compare.jsp");
        String featurePlot = read("featureplot.jsp");
        String details = read("details.jsp");

        assertTrue(compare.contains("name=\"species\" value=\"human\" data-preference-key=\"species\""));
        assertTrue(featurePlot.contains("name=\"umap-species\" value=\"human\" data-preference-key=\"species\""));
        assertTrue(compare.contains("data-preference-key=\"hidePseudogenes\""));
        assertTrue(details.contains("data-preference-key=\"hidePseudogenes\""));
    }

    @Test
    void publishesAnInformationalStorageNoticeWithoutStandalonePrivacyPage() throws Exception {
        String header = read("includes/header.jsp");

        assertTrue(header.contains("id=\"storage-notice\""));
        assertTrue(header.contains("We do not use advertising or third-party tracking cookies."));
        assertTrue(header.contains("id=\"mapmyvisitors\""));
        assertTrue(header.contains("//mapmyvisitors.com/map.js?d=FceBPIpTNKr7fyBoiQjL-qoD1MRcySwmXIUGnxPMY2c&cl=ffffff&w=a"));
        assertFalse(header.contains("href=\"privacy.jsp\""));
        assertTrue(Files.notExists(WEBAPP.resolve("privacy.jsp")));
        assertTrue(Files.notExists(WEBAPP.resolve("CSS/privacy.css")));
    }

    @Test
    void existingFirstPartyCookiesRemainConfigured() throws Exception {
        String counter = Files.readString(
                Path.of("src/main/java/AccessCounter/AccessCounterFilter.java"), StandardCharsets.UTF_8);
        String webXml = read("WEB-INF/web.xml");

        assertTrue(counter.contains("new Cookie(\"count_cookie\""));
        assertTrue(counter.contains("updatedCookie.setHttpOnly(true)"));
        assertTrue(counter.contains("updatedCookie.setSecure(true)"));
        assertTrue(webXml.contains("<http-only>true</http-only>"));
        assertTrue(webXml.contains("<secure>true</secure>"));
    }
}
