package AccessCounter;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AccessCounterFilterTest {
    @Test
    void analyticsContentPathAllowsRealSitePagesAndRejectsScannerProbes() {
        assertTrue(AccessCounterFilter.isAnalyticsContentPath("/"));
        assertTrue(AccessCounterFilter.isAnalyticsContentPath("/browse.jsp"));
        assertTrue(AccessCounterFilter.isAnalyticsContentPath("/details.jsp"));
        assertTrue(AccessCounterFilter.isAnalyticsContentPath("/gene-details"));
        assertTrue(AccessCounterFilter.isAnalyticsContentPath("/integrated_umap/"));

        assertFalse(AccessCounterFilter.isAnalyticsContentPath("/wp-admin/install.php"));
        assertFalse(AccessCounterFilter.isAnalyticsContentPath("/.well-known/"));
        assertFalse(AccessCounterFilter.isAnalyticsContentPath("/admin/controller/extension/extension/"));
        assertFalse(AccessCounterFilter.isAnalyticsContentPath("/xmlrpc.php"));
    }
}
