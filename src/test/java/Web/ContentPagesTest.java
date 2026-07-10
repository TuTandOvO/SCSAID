package Web;

import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
    void aboutPagesContainEditableEditorialTemplates() throws Exception {
        String cite = read("src/main/webapp/cite.jsp");
        String news = read("src/main/webapp/whats-new.jsp");

        assertTrue(cite.contains("Citing scSAID"));
        assertTrue(cite.contains("Additional references"));
        assertTrue(cite.contains("[Authors]"));
        assertTrue(news.contains("What’s New in scSAID"));
        assertTrue(news.contains("LLM Interpretation panel"));
        assertTrue(news.contains("Regulon and regulatory-network interpretation"));
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
