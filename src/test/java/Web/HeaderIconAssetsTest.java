package Web;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HeaderIconAssetsTest {
    private static final Path WEBAPP = Path.of("src/main/webapp");

    @Test
    void headerUsesSelfHostedPhosphorFillIcons() throws Exception {
        String header = Files.readString(WEBAPP.resolve("includes/header.jsp"), StandardCharsets.UTF_8);
        String css = Files.readString(WEBAPP.resolve("CSS/header.css"), StandardCharsets.UTF_8);
        Path icons = WEBAPP.resolve("images/icons/phosphor-fill");

        List<String> assets = List.of(
                "house-fill.svg", "database-fill.svg", "compass-fill.svg",
                "chart-bar-fill.svg", "download-simple-fill.svg", "question-fill.svg",
                "info-fill.svg", "chat-centered-text-fill.svg");

        for (String asset : assets) {
            assertTrue(Files.isRegularFile(icons.resolve(asset)), "Missing Phosphor asset: " + asset);
            assertTrue(css.contains("phosphor-fill/" + asset), "Header CSS does not use " + asset);
        }

        assertTrue(Files.isRegularFile(icons.resolve("LICENSE.txt")));
        assertTrue(css.contains("background-color: currentColor"));
        assertTrue(css.contains("-webkit-mask-image"));
        assertTrue(header.contains("main-nav__icon--feedback"));
        assertFalse(header.contains("site-icon-sprite"));
        assertFalse(header.contains("<symbol id=\"nav-icon-"));
    }
}
