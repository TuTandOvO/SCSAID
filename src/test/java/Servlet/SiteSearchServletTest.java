package Servlet;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

class SiteSearchServletTest {
    @Test
    void routesGsmCommunicationQueryToDatasetCommunicationSection() {
        List<SiteSearchServlet.SearchResult> results = SiteSearchServlet.search("GSM8316003 CCC", "");

        assertFalse(results.isEmpty());
        assertEquals("Dataset", results.get(0).category);
        assertEquals("/details.jsp?said=SAID003#CellPhoneDBAnalysis", results.get(0).url);
    }

    @Test
    void routesSaidDegQueryToDatasetDegSectionWithinContextPath() {
        List<SiteSearchServlet.SearchResult> results = SiteSearchServlet.search("SAID003 DEG", "/scsaid");

        assertFalse(results.isEmpty());
        assertEquals("/scsaid/details.jsp?said=SAID003#DEGResults", results.get(0).url);
    }

    @Test
    void findsGenericExpressionFunction() {
        List<SiteSearchServlet.SearchResult> results = SiteSearchServlet.search("Expression", "");

        assertFalse(results.isEmpty());
        assertEquals("Gene expression", results.get(0).title);
        assertEquals("/featureplot.jsp", results.get(0).url);
    }
}
