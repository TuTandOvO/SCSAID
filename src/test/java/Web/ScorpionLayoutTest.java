package Web;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertTrue;

class ScorpionLayoutTest {
    private static final Path WEBAPP = Path.of("src/main/webapp");

    @Test
    void scorpionUsesCompactSplitViewsAndCircularNetwork() throws Exception {
        String jsp = Files.readString(WEBAPP.resolve("details.jsp"), StandardCharsets.UTF_8);
        String css = Files.readString(WEBAPP.resolve("CSS/details.css"), StandardCharsets.UTF_8);

        assertTrue(jsp.contains("class=\"scorpion-overview-grid\""));
        assertTrue(jsp.contains("id=\"scorpionRegChart\" class=\"scorpion-chart\""));
        assertTrue(jsp.contains("id=\"scorpionTargetChart\" class=\"scorpion-chart\""));
        assertTrue(jsp.contains("function placeRing(arr, radius)"));
        assertTrue(jsp.contains("placeRing(tfs, 0.47)"));
        assertTrue(jsp.contains("placeRing(tgs, 1)"));

        assertTrue(css.contains(".scorpion-overview-grid"));
        assertTrue(css.contains("grid-template-columns: repeat(2, minmax(0, 1fr))"));
        assertTrue(css.contains("@media (max-width: 1050px)"));
    }
}
