package Web;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertTrue;

class ResponsivePolishTest {
    private static String read(String path) throws Exception {
        return Files.readString(Path.of(path), StandardCharsets.UTF_8);
    }

    @Test
    void mobileDrawerUsesTheCompactWidthAndStandardButtonShape() throws Exception {
        String css = read("src/main/webapp/CSS/header.css");

        assertTrue(css.contains("width: min(18rem, 78vw)"));
        assertTrue(css.contains("grid-template-columns: minmax(0, 1fr)"));
        assertTrue(css.contains(".main-nav__item--open .main-nav__dropdown { display: grid; }"));
        assertTrue(css.contains(".site-header--menu-open .nav-toggle"));
        assertTrue(css.contains(".nav-toggle { width: 40px; height: 40px; }"));
    }

    @Test
    void geneSetScoringUsesCompactVerticalRhythm() throws Exception {
        String jsp = read("src/main/webapp/details.jsp");
        String css = read("src/main/webapp/CSS/details.css");

        assertTrue(jsp.contains("control-row gss-controls-row"));
        assertTrue(css.contains("#GeneSetScoring > .header { padding-bottom: 0.25rem; }"));
        assertTrue(css.contains("gap: 0.5rem;"));
        assertTrue(css.contains("padding-bottom: 0.75rem;"));
        assertTrue(css.contains("#GeneSetScoring .tab-bar { margin-bottom: 0; }"));
        assertTrue(css.contains("#gssGeneInput"));
        assertTrue(css.contains("min-height: 44px"));
        assertTrue(css.contains("#gssViolinPlot { min-height: 0; }"));
    }
}
