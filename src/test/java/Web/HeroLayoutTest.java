package Web;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertTrue;

class HeroLayoutTest {
    private static final Path WEBAPP = Path.of("src/main/webapp");

    @Test
    void helpEnabledHeroTitlesRemainBelowTheirEyebrows() throws Exception {
        String css = Files.readString(WEBAPP.resolve("CSS/design-system.css"), StandardCharsets.UTF_8);
        String featurePlot = Files.readString(WEBAPP.resolve("featureplot.jsp"), StandardCharsets.UTF_8);

        assertTrue(featurePlot.contains("<span class=\"page-hero__eyebrow\">"));
        assertTrue(featurePlot.contains("<h1 class=\"page-hero__title title-with-help\">"));
        assertTrue(css.contains(".page-hero__title.title-with-help"));
        assertTrue(css.contains(".page-hero__title.title-with-help {\n    display: block;"));
    }
}
