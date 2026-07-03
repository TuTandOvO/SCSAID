package Web;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HeaderNavigationTest {
    private static final Path HEADER = Path.of("src/main/webapp/includes/header.jsp");

    private static int occurrences(String text, String token) {
        int count = 0;
        int offset = 0;
        while ((offset = text.indexOf(token, offset)) >= 0) {
            count++;
            offset += token.length();
        }
        return count;
    }

    @Test
    void expressionAndFeedbackLiveInsideTheirRequestedMenus() throws Exception {
        String header = Files.readString(HEADER, StandardCharsets.UTF_8);

        assertTrue(header.contains("boolean scsaidNavigate = scsaidSearch || scsaidCompare || scsaidExpression"));
        assertTrue(header.contains("boolean scsaidAbout = scsaidCite || scsaidWhatsNew || scsaidPrivacy || scsaidFeedback"));
        assertTrue(header.contains("id=\"navigate-menu\""));
        assertTrue(header.contains("main-nav__dropdown-icon--expression"));
        assertTrue(header.contains("id=\"about-menu\""));
        assertTrue(header.contains("main-nav__dropdown-icon--feedback"));
        assertFalse(header.contains("<a href=\"featureplot.jsp\" class=\"main-nav__link"));
        assertFalse(header.contains("<a href=\"feedback\" class=\"main-nav__link"));
    }

    @Test
    void everyDropdownDestinationHasAnIcon() throws Exception {
        String header = Files.readString(HEADER, StandardCharsets.UTF_8);

        assertEquals(13, occurrences(header, "class=\"main-nav__dropdown-link"));
        assertEquals(13, occurrences(header, "main-nav__dropdown-icon main-nav__dropdown-icon--"));
    }

    @Test
    void homeTabIsHiddenOnlyOnTheHomePage() throws Exception {
        String header = Files.readString(HEADER, StandardCharsets.UTF_8);

        assertTrue(header.contains("<% if (!scsaidHome) { %>"));
        assertTrue(header.contains("<a href=\"index.jsp\" class=\"main-nav__link\"><span class=\"main-nav__icon main-nav__icon--home\""));
        assertTrue(header.contains("<a href=\"index.jsp\" class=\"site-logo\" aria-label=\"scSAID home\">scSAID</a>"));
    }
}
