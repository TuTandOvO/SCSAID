package Web;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertTrue;

class DeveloperAnalyticsDashboardTest {
    @Test
    void protectedDashboardProvidesAllTimeRecurrenceMapAndTimingPanels() throws Exception {
        String jsp = Files.readString(Path.of("src/main/webapp/developer-traffic.jsp"), StandardCharsets.UTF_8);
        String js = Files.readString(Path.of("src/main/webapp/JS/country-traffic.js"), StandardCharsets.UTF_8);
        String servlet = Files.readString(Path.of("src/main/java/AccessCounter/CountryTrafficStatsServlet.java"), StandardCharsets.UTF_8);
        String filter = Files.readString(Path.of("src/main/java/AccessCounter/AccessCounterFilter.java"), StandardCharsets.UTF_8);

        assertTrue(jsp.contains("id=\"visitMap\""));
        assertTrue(jsp.contains("id=\"dailyChart\""));
        assertTrue(jsp.contains("id=\"hourlyChart\""));
        assertTrue(jsp.contains("Returning visitor history"));
        assertTrue(jsp.contains("Most visited pages"));
        assertTrue(js.contains("var countryCoordinates"));
        assertTrue(js.contains("data-map-scope"));
        assertTrue(js.contains("function renderMap"));
        assertTrue(servlet.contains("visitAnalytics"));
        assertTrue(filter.contains("DeveloperVisitEventStore"));
        assertTrue(filter.contains("developer-visit-events.tsv"));
    }
}
