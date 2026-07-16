package Web;

import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ContentPagesTest {
    private static String read(String path) throws Exception {
        return Files.readString(Path.of(path), StandardCharsets.UTF_8);
    }

    @Test
    void geneSetPlotDoesNotReserveSpaceBeforeAResult() throws Exception {
        String jsp = read("src/main/webapp/details.jsp");
        String css = read("src/main/webapp/CSS/details.css");

        assertTrue(jsp.contains("id=\"gssViolinPlot\" style=\"display:none;\""));
        assertTrue(jsp.contains("$('#gssViolinPlot').empty().hide()"));
        assertTrue(jsp.contains("$('#gssViolinPlot').show()"));
        assertTrue(css.contains("#gssViolinPlot { min-height: 0; }"));
    }

    @Test
    void standalonePrivacyPageWasRemoved() {
        assertTrue(Files.notExists(Path.of("src/main/webapp/privacy.jsp")));
        assertTrue(Files.notExists(Path.of("src/main/webapp/CSS/privacy.css")));
    }

    @Test
    void degSearchDoesNotExposeCacheStatusLine() throws Exception {
        String jsp = read("src/main/webapp/deg-search.jsp");
        assertFalse(jsp.contains("id=\"index-status\""));
        assertFalse(jsp.contains("deg-index-status"));
        assertFalse(jsp.contains("function checkIndex()"));
        assertFalse(jsp.contains("DEG indexes ready"));
    }

    @Test
    void aboutPagesContainEditorialCitationAndDatedReleaseTimeline() throws Exception {
        String cite = read("src/main/webapp/cite.jsp");
        String news = read("src/main/webapp/whats-new.jsp");
        String newsScript = read("src/main/webapp/JS/whats-new.js");

        assertTrue(cite.contains("Citing scSAID"));
        assertTrue(cite.contains("Additional references"));
        assertTrue(cite.contains("[Authors]"));
        assertTrue(news.contains("<h1>What’s New</h1>"));
        assertTrue(news.contains("class=\"changelog-timeline\""));
        assertTrue(news.contains("href=\"#release-2026-07-16\""));
        assertTrue(news.contains("id=\"release-2026-06-24\""));
        assertTrue(news.contains("Post-QC cell totals across every dataset"));
        assertTrue(news.contains("LLM Interpretation on dataset detail pages"));
        assertFalse(news.toLowerCase().contains("visitor"));
        assertTrue(newsScript.contains("IntersectionObserver"));
        assertTrue(newsScript.contains("aria-current"));
    }

    @Test
    void usageGuideCoversEveryCurrentWorkflow() throws Exception {
        String usage = read("src/main/webapp/help/usage.md");
        String[] required = {
                "## Site navigation and global search",
                "## Browse datasets and integrate samples",
                "## Dataset Details page",
                "### Cell Proportion",
                "### Cell Clustering",
                "### Differentially Expressed Genes",
                "### Gene Set Scoring",
                "### Cell-Cell Communication",
                "### Enrichment Analysis",
                "### Gene Regulatory Network (SCORPION) — Beta",
                "## Search markers across datasets",
                "## Search condition DEGs across datasets",
                "## Integrated Expression feature plot",
                "## Compare conditions in real time",
                "## psoSpotter beta workflow",
                "## Download Center",
                "## Help, About, storage notice, and feedback"
        };
        for (String heading : required) assertTrue(usage.contains(heading), heading);
    }

    @Test
    void homepageUnderlinesEveryScsaidAcronymInitial() throws Exception {
        String home = read("src/main/webapp/index.jsp");
        assertEquals(6, home.split("class=\\\"hero__acronym-letter\\\"", -1).length - 1);
        assertTrue(home.contains("text-decoration-line: underline"));
        assertTrue(home.contains("text-decoration-color: currentColor"));
    }

    @Test
    void suppliedLogoWasRenderedAtAllPublishedFaviconSizes() throws Exception {
        assertPngSize("src/main/webapp/images/favicon-16.png", 16);
        assertPngSize("src/main/webapp/images/favicon-32.png", 32);
        assertPngSize("src/main/webapp/images/favicon-192.png", 192);
        assertPngSize("src/main/webapp/images/favicon-512.png", 512);
        assertPngSize("src/main/webapp/images/apple-touch-icon.png", 180);
        assertTrue(Files.size(Path.of("src/main/webapp/favicon.ico")) > 1000);
    }

    private static void assertPngSize(String path, int expected) throws Exception {
        BufferedImage image = ImageIO.read(Path.of(path).toFile());
        assertTrue(image != null, path);
        assertEquals(expected, image.getWidth(), path);
        assertEquals(expected, image.getHeight(), path);
    }
}
