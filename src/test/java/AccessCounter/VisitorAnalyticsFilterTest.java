package AccessCounter;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class VisitorAnalyticsFilterTest {
    @Test
    void analyticsContentPathAllowsRealSitePagesAndRejectsScannerProbes() {
        assertTrue(VisitorAnalyticsFilter.isAnalyticsContentPath("/"));
        assertTrue(VisitorAnalyticsFilter.isAnalyticsContentPath("/browse.jsp"));
        assertTrue(VisitorAnalyticsFilter.isAnalyticsContentPath("/details.jsp"));
        assertTrue(VisitorAnalyticsFilter.isAnalyticsContentPath("/gene-details"));
        assertTrue(VisitorAnalyticsFilter.isAnalyticsContentPath("/integrated_umap/"));

        assertFalse(VisitorAnalyticsFilter.isAnalyticsContentPath("/wp-admin/install.php"));
        assertFalse(VisitorAnalyticsFilter.isAnalyticsContentPath("/.well-known/"));
        assertFalse(VisitorAnalyticsFilter.isAnalyticsContentPath("/admin/controller/extension/extension/"));
        assertFalse(VisitorAnalyticsFilter.isAnalyticsContentPath("/xmlrpc.php"));
    }
}
