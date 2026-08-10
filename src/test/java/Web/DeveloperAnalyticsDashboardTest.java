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
        String css = Files.readString(Path.of("src/main/webapp/CSS/developer-traffic.css"), StandardCharsets.UTF_8);
        String chinaMap = Files.readString(Path.of("src/main/webapp/map_resources/china-provinces.json"), StandardCharsets.UTF_8);
        String servlet = Files.readString(Path.of("src/main/java/AccessCounter/CountryTrafficStatsServlet.java"), StandardCharsets.UTF_8);
        String eventServlet = Files.readString(Path.of("src/main/java/AccessCounter/DeveloperVisitEventsServlet.java"), StandardCharsets.UTF_8);
        String filter = Files.readString(Path.of("src/main/java/AccessCounter/VisitorAnalyticsFilter.java"), StandardCharsets.UTF_8);

        assertTrue(jsp.contains("lib/leaflet/leaflet.css"));
        assertTrue(jsp.contains("lib/leaflet/leaflet.js"));
        assertTrue(jsp.contains("topojson-client.min.js"));
        assertTrue(jsp.contains("id=\"visitMap\""));
        assertTrue(jsp.contains("id=\"dailyChart\""));
        assertTrue(jsp.contains("id=\"hourlyChart\""));
        assertTrue(jsp.contains("Returning visitor history"));
        assertTrue(jsp.contains("id=\"visitorTimeZone\""));
        assertTrue(jsp.contains("Select a visitor to inspect each numbered return."));
        assertTrue(jsp.contains("Most visited pages"));
        assertTrue(jsp.contains("Visit event ledger"));
        assertTrue(jsp.contains("id=\"eventRows\""));
        assertTrue(jsp.contains("UA fingerprint"));
        assertTrue(jsp.contains("Approximate location"));
        assertTrue(jsp.contains("Registered network"));
        assertTrue(js.contains("L.map(\"visitMap\""));
        assertTrue(js.contains("/map_resources/world-countries.geojson"));
        assertTrue(js.contains("/map_resources/us-states.geojson"));
        assertTrue(js.contains("/map_resources/china-provinces.json"));
        assertTrue(js.contains("/map_resources/uk-local-authorities.topojson"));
        assertTrue(js.contains("mapScope === \"returning\""));
        assertTrue(js.contains("function markerSize"));
        assertTrue(js.contains("function markerColor"));
        assertTrue(js.contains("function instantMillis"));
        assertTrue(js.contains("value.seconds"));
        assertTrue(js.contains("function formatLocalTime"));
        assertTrue(js.contains("formatToParts"));
        assertTrue(js.contains("resolvedOptions().timeZone"));
        assertTrue(js.contains("Visit #"));
        assertTrue(js.contains("data-visitor-toggle"));
        assertTrue(js.contains("marker.bindTooltip(tooltipHtml(group)"));
        assertTrue(js.contains("regionLayers[alias] = item"));
        assertTrue(js.contains("countryLayers[group.country]"));
        assertTrue(js.contains("SG:[1.3521, 103.8198]"));
        assertTrue(js.contains("function fetchJson"));
        assertTrue(js.contains("regional detail unavailable for"));
        assertFalse(js.contains("L.latLng(20, 0)"));
        assertFalse(js.contains("markerLayer.bringToFront"));
        assertFalse(js.contains("marker.bindPopup"));
        assertFalse(js.contains("toISOString()"));
        assertTrue(js.contains("data-map-scope"));
        assertTrue(js.contains("function renderMap"));
        assertTrue(js.contains("function renderEventLedger"));
        assertTrue(js.contains("function eventAccuracy"));
        assertTrue(js.contains("function eventNetwork"));
        assertTrue(js.contains("Latest approximate location"));
        assertTrue(js.contains("/developer-visit-events?offset="));
        assertFalse(jsp.contains("<svg id=\"visitMap\""));
        assertFalse(jsp.contains("Unknown / unavailable"));
        assertFalse(js.contains("mapmyvisitors.com"));
        assertFalse(js.contains("tile.openstreetmap.org"));
        assertTrue(css.contains("leaflet-tooltip.developer-analytics__map-tooltip"));
        assertTrue(css.contains("developer-analytics__history-row"));
        assertTrue(chinaMap.contains("\"name\":\"香港特别行政区\""));
        assertTrue(chinaMap.contains("\"centroid\":[114.134357,22.377366]"));
        assertTrue(servlet.contains("visitAnalytics"));
        assertTrue(servlet.contains("visitorAnalyticsRuntime"));
        assertTrue(eventServlet.contains("retainedFields"));
        assertTrue(eventServlet.contains("userAgentHash"));
        assertTrue(eventServlet.contains("accuracyRadiusKm"));
        assertTrue(eventServlet.contains("networkOrganization"));
        assertTrue(filter.contains("DeveloperVisitEventStore"));
        assertTrue(filter.contains("geoIpAsnDatabase"));
        assertTrue(filter.contains("developer-visit-events.tsv"));
        assertTrue(filter.contains("scsaid_vid"));
    }
}
