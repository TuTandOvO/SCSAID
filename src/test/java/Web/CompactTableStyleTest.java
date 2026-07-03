package Web;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertTrue;

class CompactTableStyleTest {
    private static String read(String path) throws Exception {
        return Files.readString(Path.of(path), StandardCharsets.UTF_8);
    }

    @Test
    void sharedTableLayerIsAppliedToAllRequestedSurfaces() throws Exception {
        String geneSearch = read("src/main/webapp/gene-search.jsp");
        String browse = read("src/main/webapp/browse.jsp");
        String details = read("src/main/webapp/details.jsp");

        assertTrue(geneSearch.contains("CSS/humanbase-tables.css"));
        assertTrue(geneSearch.contains("results-table hb-table"));
        assertTrue(browse.contains("CSS/humanbase-tables.css"));
        assertTrue(browse.contains("browse-table hb-table"));
        assertTrue(details.contains("CSS/humanbase-tables.css"));
        assertTrue(details.contains("elegant-table hb-table"));
    }

    @Test
    void sharedTableLayerRetainsTheReferenceMeasurements() throws Exception {
        String css = read("src/main/webapp/CSS/humanbase-tables.css");

        assertTrue(css.contains("--compact-table-head: #e9ecef"));
        assertTrue(css.contains("--compact-table-rule: #dee2e6"));
        assertTrue(css.contains("--compact-table-cell-pad: 8px"));
        assertTrue(css.contains("--compact-table-font-size: 13px"));
        assertTrue(css.contains("font-weight: 600"));
        assertTrue(css.contains("border-bottom: 1px solid var(--compact-table-rule)"));
    }
}
