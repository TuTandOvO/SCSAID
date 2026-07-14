package Web;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DeveloperAnalyticsDashboardTest {
    @Test
    void protectedDashboardProvidesAllTimeRecurrenceMapAndTimingPanels() throws Exception {
        String jsp = Files.readString(Path.of("src/main/webapp/developer-traffic.jsp"), StandardCharsets.UTF_8);
        String js = Files.readString(Path.of("src/main/webapp/JS/country-traffic.js"), StandardCharsets.UTF_8);
        String servlet = Files.readString(Path.of("src/main/java/AccessCounter/CountryTrafficStatsServlet.java"), StandardCharsets.UTF_8);
        String filter = Files.readString(Path.of("src/main/java/AccessCounter/AccessCounterFilter.java"), StandardCharsets.UTF_8);

        assertTrue(jsp.contains("lib/leaflet/leaflet.css"));
        assertTrue(jsp.contains("lib/leaflet/leaflet.js"));
        assertTrue(jsp.contains("topojson-client.min.js"));
        assertTrue(jsp.contains("id=\"visitMap\""));
        assertTrue(jsp.contains("id=\"dailyChart\""));
        assertTrue(jsp.contains("id=\"hourlyChart\""));
        assertTrue(jsp.contains("Returning visitor history"));
        assertTrue(jsp.contains("Most visited pages"));
        assertTrue(js.contains("L.map(\"visitMap\""));
        assertTrue(js.contains("/map_resources/world-countries.geojson"));
        assertTrue(js.contains("/map_resources/us-states.geojson"));
        assertTrue(js.contains("/map_resources/china-provinces.json"));
        assertTrue(js.contains("/map_resources/uk-local-authorities.topojson"));
        assertTrue(js.contains("mapScope === \"returning\""));
        assertTrue(js.contains("function markerSize"));
        assertTrue(js.contains("function markerColor"));
        assertTrue(js.contains("data-map-scope"));
        assertTrue(js.contains("function renderMap"));
        assertFalse(jsp.contains("<svg id=\"visitMap\""));
        assertFalse(jsp.contains("Unknown / unavailable"));
        assertFalse(js.contains("mapmyvisitors.com"));
        assertFalse(js.contains("tile.openstreetmap.org"));
        assertTrue(servlet.contains("visitAnalytics"));
        assertTrue(filter.contains("DeveloperVisitEventStore"));
        assertTrue(filter.contains("developer-visit-events.tsv"));
        assertTrue(filter.contains("scsaid_vid"));
    }
}
