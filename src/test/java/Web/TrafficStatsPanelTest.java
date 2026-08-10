package Web;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class TrafficStatsPanelTest {
    @Test
    void footerChartsOpenOnlyFromDoubleClickAndRefreshLive() throws Exception {
        String jsp = Files.readString(Path.of("src/main/webapp/index.jsp"), StandardCharsets.UTF_8);
        String js = Files.readString(Path.of("src/main/webapp/JS/traffic-stats.js"), StandardCharsets.UTF_8);
        String filter = Files.readString(
                Path.of("src/main/java/AccessCounter/VisitorAnalyticsFilter.java"), StandardCharsets.UTF_8);
        String webXml = Files.readString(
                Path.of("src/main/webapp/WEB-INF/web.xml"), StandardCharsets.UTF_8);

        assertTrue(jsp.contains("id=\"totalVisitsTrigger\""));
        assertTrue(jsp.contains("id=\"todayVisitsTrigger\""));
        assertTrue(jsp.contains("id=\"trafficModal\""));
        assertTrue(jsp.contains("id=\"trafficChart\""));
        assertTrue(jsp.contains("traffic-modal__loading panel-loader"));
        assertTrue(js.contains("totalTrigger.addEventListener(\"dblclick\""));
        assertTrue(js.contains("todayTrigger.addEventListener(\"dblclick\""));
        assertFalse(js.contains("totalTrigger.addEventListener(\"click\""));
        assertFalse(js.contains("todayTrigger.addEventListener(\"click\""));
        assertTrue(js.contains("var POLL_MS = 15000"));
        assertTrue(js.contains("function renderFallbackChart"));
        assertTrue(js.contains("fetch(\"/traffic-stats?_=\""));
        assertTrue(filter.contains("LocalDate.now(ZoneOffset.UTC)"));
        assertTrue(filter.contains("now.atZone(ZoneOffset.UTC).toLocalDate()"));
        assertTrue(webXml.contains("<url-pattern>/traffic-stats</url-pattern>"));
        assertTrue(webXml.contains("<filter-class>AccessCounter.VisitorAnalyticsFilter</filter-class>"));
        assertFalse(webXml.contains("<filter-class>AccessCounter.AccessCounterFilter</filter-class>"));
        assertTrue(webXml.contains("/opt/SkinDB/runtime/traffic-history.properties"));
    }
}
