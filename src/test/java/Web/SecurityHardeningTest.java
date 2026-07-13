package Web;

import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SecurityHardeningTest {
    private static String read(String relative) throws Exception {
        return Files.readString(Path.of(relative));
    }

    @Test
    void publicMappingsExcludeLegacyLaunchersAndProtectVisitorAddressData() throws Exception {
        String webXml = read("src/main/webapp/WEB-INF/web.xml");
        assertFalse(webXml.contains("/details_init"));
        assertFalse(webXml.contains("/deg_cell_type_change"));
        assertFalse(webXml.contains("/track"));
        assertFalse(webXml.contains("/api/geo"));
        assertFalse(webXml.contains("/condition-deg-search/warm"));
        assertTrue(webXml.contains("DeveloperAnalyticsFilter"));
        assertTrue(webXml.contains("<url-pattern>/developer-traffic.jsp</url-pattern>"));
        assertTrue(webXml.contains("/country-traffic-stats"));
        String filter = read("src/main/java/AccessCounter/DeveloperAnalyticsFilter.java");
        assertTrue(filter.contains("SC_UNAUTHORIZED"));
        assertTrue(filter.contains("MessageDigest.isEqual"));
    }

    @Test
    void heavyAnalysisRoutesAreRateLimited() throws Exception {
        String webXml = read("src/main/webapp/WEB-INF/web.xml");
        for (String route : new String[]{"/cpdb-api", "/condition-compare", "/condition-gsea",
                "/deg-compare", "/deg-per-celltype", "/scorpion", "/psospotter"}) {
            assertTrue(webXml.contains("<url-pattern>" + route + "</url-pattern>"), route);
        }
    }

    @Test
    void cellPhoneDbIsExplicitlyMappedWhenAnnotationScanningIsDisabled() throws Exception {
        String webXml = read("src/main/webapp/WEB-INF/web.xml");
        String servlet = read("src/main/java/Servlet/CellPhoneDBServlet.java");
        assertTrue(webXml.contains("metadata-complete=\"true\""));
        assertTrue(webXml.contains("<servlet-class>Servlet.CellPhoneDBServlet</servlet-class>"));
        assertTrue(webXml.contains("<servlet-name>CellPhoneDBServlet</servlet-name>"));
        assertTrue(webXml.contains("<url-pattern>/cpdb-api</url-pattern>"));
        assertTrue(servlet.contains("/api?action=cell-types"));
        assertTrue(servlet.contains("application/x-www-form-urlencoded"));
        assertTrue(servlet.contains("jobId.matches(\"[0-9a-fA-F]{8}\")"));
        assertTrue(servlet.contains("writeUpstream(response"));
    }

    @Test
    void uploadedJobResultsAreSessionBoundAndFileTyped() throws Exception {
        String servlet = read("src/main/java/Servlet/PsoSpotterServlet.java");
        assertTrue(servlet.contains("ownedJob(request"));
        assertTrue(servlet.contains("job.sessionId.equals"));
        assertTrue(servlet.contains("hasHdf5Signature"));
        assertTrue(servlet.contains("MAX_GENES"));
    }

    @Test
    void applicationAddsSecurityHeadersAndTrustsOnlySanitizedProxyIp() throws Exception {
        String headers = read("src/main/java/Utils/SecurityHeadersFilter.java");
        String limiter = read("src/main/java/Utils/RateLimitFilter.java");
        assertTrue(headers.contains("X-Content-Type-Options"));
        assertTrue(headers.contains("Strict-Transport-Security"));
        assertTrue(limiter.contains("X-Real-IP"));
        assertFalse(limiter.contains("getHeader(\"CF-Connecting-IP\")"));
        assertFalse(limiter.contains("getHeader(\"X-Forwarded-For\")"));
    }

    @Test
    void vulnerableAndUnusedDependenciesAreGone() throws Exception {
        String pom = read("pom.xml");
        assertFalse(pom.contains("<version>5.2.3</version>"));
        assertFalse(pom.contains("<version>20210307</version>"));
        assertTrue(pom.contains("<artifactId>geoip2</artifactId>"));
        assertTrue(pom.contains("<version>4.0.0</version>"));
        assertFalse(pom.contains("<artifactId>jsch</artifactId>"));
        assertFalse(pom.contains("<artifactId>poi-ooxml</artifactId>"));
        assertFalse(pom.contains("<artifactId>opencsv</artifactId>"));
    }

    @Test
    void pythonAnalysisServicesAreLoopbackOnlyAndMemoryBounded() throws Exception {
        String cpdb = read("src/main/webapp/cpdb_resources/cpdb_analysis.py");
        assertTrue(cpdb.contains("MAX_CACHED_DATASETS = 1"));
        assertTrue(cpdb.contains("BoundedSemaphore(2)"));
        assertTrue(cpdb.contains("JOB_RESULT_TTL = timedelta(minutes=30)"));
        assertTrue(cpdb.contains("default='127.0.0.1'"));
        assertFalse(cpdb.contains("default='0.0.0.0'"));
    }
}
