package Web;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class FeaturePlotContextTest {
    private static final Path ROOT = Path.of("src/main");

    @Test
    void featurePlotCoordinatesDatasetConditionAndGene() throws Exception {
        String jsp = Files.readString(ROOT.resolve("webapp/featureplot.jsp"), StandardCharsets.UTF_8);
        String js = Files.readString(ROOT.resolve("webapp/JS/umap-explorer.js"), StandardCharsets.UTF_8);
        String css = Files.readString(ROOT.resolve("webapp/CSS/umap-explorer.css"), StandardCharsets.UTF_8);
        String webXml = Files.readString(ROOT.resolve("webapp/WEB-INF/web.xml"), StandardCharsets.UTF_8);

        assertTrue(jsp.contains("id=\"conditionSelect\""));
        assertTrue(jsp.contains("id=\"datasetSelect\""));
        assertTrue(jsp.contains("id=\"contextDataset\""));
        assertTrue(jsp.contains("id=\"contextCondition\""));
        assertTrue(jsp.contains("id=\"contextGene\""));
        assertTrue(js.contains("/atlas-context?species="));
        assertTrue(js.contains("function matchingIndices(base)"));
        assertTrue(js.contains("function backgroundTrace(base)"));
        assertTrue(js.contains("Condition: %{customdata[6]}"));
        assertTrue(css.contains(".umap-context"));
        assertTrue(css.contains(".umap-controls {\n    position: relative;\n    z-index: 20;\n    border: 0;\n    box-shadow: none;"));
        assertTrue(css.contains("@media (max-width: 420px)"));
        assertTrue(webXml.contains("<url-pattern>/atlas-context</url-pattern>"));
    }

    @Test
    void everyAtlasDatasetHasUniqueDatasetSampleAndConditionMetadata() throws Exception {
        String json = Files.readString(ROOT.resolve("resources/atlas-context.json"), StandardCharsets.UTF_8);
        List<Map<String, String>> rows = new Gson().fromJson(
                json, new TypeToken<List<Map<String, String>>>() { }.getType());
        Set<String> saids = new HashSet<>();
        Set<String> gsms = new HashSet<>();
        int human = 0;
        int mouse = 0;
        for (Map<String, String> row : rows) {
            assertTrue(saids.add(row.get("said")));
            assertTrue(gsms.add(row.get("gsm")));
            assertTrue(!row.get("condition").isBlank());
            if ("human".equals(row.get("species"))) human++;
            if ("mouse".equals(row.get("species"))) mouse++;
        }
        assertEquals(252, rows.size());
        assertEquals(133, human);
        assertEquals(119, mouse);
    }
}
