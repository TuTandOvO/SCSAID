package AccessCounter;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.Cookie;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Initializes the shared traffic stores and records one eligible page view per
 * browser and UTC day.
 *
 * <p>The deliberately specific class name avoids colliding with the legacy
 * AccessCounterFilter that was installed by early scSAID deployments.</p>
 */
public final class VisitorAnalyticsFilter implements Filter {
    private static final String TOTAL_ATTRIBUTE = "totalCount";
    private static final String DAILY_ATTRIBUTE = "dailyCount";
    private static final String DATE_ATTRIBUTE = "currentDate";
    private static final String VISITOR_COOKIE = "scsaid_vid";
    private static final SecureRandom VISITOR_ID_RANDOM = new SecureRandom();

    private final Object counterLock = new Object();
    private FilterConfig filterConfig;
    private CounterStore counterStore;
    private TrafficHistoryStore trafficHistoryStore;
    private CountryTrafficStore countryTrafficStore;
    private DeveloperVisitorStore developerVisitorStore;
    private DeveloperVisitEventStore developerVisitEventStore;
    private CountryResolver countryResolver;

    @Override
    public void init(FilterConfig filterConfig) throws ServletException {
        this.filterConfig = filterConfig;
        ServletContext context = filterConfig.getServletContext();
        Path counterPath = resolveCounterPath(filterConfig, context);
        counterStore = new CounterStore(counterPath);
        Path historyPath = resolveHistoryPath(filterConfig, counterPath);
        trafficHistoryStore = new TrafficHistoryStore(historyPath);
        Path countryHistoryPath = resolveCountryHistoryPath(filterConfig, counterPath);
        countryTrafficStore = new CountryTrafficStore(countryHistoryPath,
                resolveCountryRetentionDays(filterConfig));
        developerVisitorStore = new DeveloperVisitorStore(resolveDeveloperVisitorPath(filterConfig, counterPath), 0);
        developerVisitEventStore = new DeveloperVisitEventStore(resolveDeveloperVisitEventPath(filterConfig, counterPath));
        Path geoIpDatabase = resolveGeoIpDatabasePath(filterConfig, context);

        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        CounterStore.Snapshot snapshot;
        try {
            snapshot = counterStore.load(today);
        } catch (IOException error) {
            context.log("Unable to load access counter from " + counterPath, error);
            snapshot = new CounterStore.Snapshot(0, 0, today);
        }

        context.setAttribute("counterFile", counterPath.toString());
        context.setAttribute("trafficHistoryFile", historyPath.toString());
        context.setAttribute("trafficHistoryStore", trafficHistoryStore);
        context.setAttribute("countryTrafficFile", countryHistoryPath.toString());
        context.setAttribute("countryTrafficStore", countryTrafficStore);
        context.setAttribute("developerVisitorStore", developerVisitorStore);
        context.setAttribute("developerVisitEventStore", developerVisitEventStore);
        context.setAttribute(TOTAL_ATTRIBUTE, new AtomicLong(snapshot.total));
        context.setAttribute(DAILY_ATTRIBUTE, new AtomicLong(snapshot.daily));
        context.setAttribute(DATE_ATTRIBUTE, snapshot.date);
        context.setAttribute("visitorAnalyticsRuntime", "visitor-analytics-v2");
        context.log("Visitor analytics runtime initialized from " + counterPath
                + ": total=" + snapshot.total + ", daily=" + snapshot.daily);
        try {
            trafficHistoryStore.load();
        } catch (IOException error) {
            context.log("Unable to load traffic history from " + historyPath, error);
        }
        try {
            countryTrafficStore.load();
        } catch (IOException error) {
            context.log("Unable to load country-level traffic aggregates from " + countryHistoryPath, error);
        }
        try {
            developerVisitorStore.load();
        } catch (IOException error) {
            context.log("Unable to load developer-only visitor address history", error);
        }
        try {
            countryResolver = CountryResolver.open(geoIpDatabase);
            if (countryResolver == null) {
                context.log("Country-level traffic analytics is running without a local GeoLite database.");
            }
        } catch (IOException error) {
            context.log("Unable to open local GeoLite database for country-level traffic analytics", error);
        }
    }

    private Path resolveCounterPath(FilterConfig config, ServletContext context) {
        String configured = config.getInitParameter("counterFile");
        if (configured != null && !configured.trim().isEmpty()) {
            return Path.of(configured.trim());
        }

        String dataRoot = context.getInitParameter("skindbDataRoot");
        if (dataRoot != null && !dataRoot.trim().isEmpty()) {
            return Path.of(dataRoot.trim(), "runtime", "access-counter.properties");
        }

        return Path.of(System.getProperty("java.io.tmpdir") + File.separator
                + "scsaid" + File.separator + "access-counter.properties");
    }

    private Path resolveHistoryPath(FilterConfig config, Path counterPath) {
        String configured = config.getInitParameter("trafficHistoryFile");
        if (configured != null && !configured.trim().isEmpty()) {
            return Path.of(configured.trim());
        }
        return counterPath.resolveSibling("traffic-history.properties");
    }

    private Path resolveCountryHistoryPath(FilterConfig config, Path counterPath) {
        String configured = config.getInitParameter("countryTrafficFile");
        if (configured != null && !configured.trim().isEmpty()) {
            return Path.of(configured.trim());
        }
        return counterPath.resolveSibling("country-traffic.properties");
    }

    private int resolveCountryRetentionDays(FilterConfig config) {
        String configured = config.getInitParameter("countryTrafficRetentionDays");
        try {
            return configured == null ? 365 : Integer.parseInt(configured.trim());
        } catch (NumberFormatException ignored) {
            return 365;
        }
    }

    private Path resolveDeveloperVisitorPath(FilterConfig config, Path counterPath) {
        String configured = config.getInitParameter("developerVisitorFile");
        if (configured != null && !configured.trim().isEmpty()) return Path.of(configured.trim());
        return counterPath.resolveSibling("developer-visitor-addresses.properties");
    }

    private Path resolveDeveloperVisitEventPath(FilterConfig config, Path counterPath) {
        String configured = config.getInitParameter("developerVisitEventsFile");
        if (configured != null && !configured.trim().isEmpty()) return Path.of(configured.trim());
        return counterPath.resolveSibling("developer-visit-events.tsv");
    }

    private Path resolveGeoIpDatabasePath(FilterConfig config, ServletContext context) {
        String configured = config.getInitParameter("geoIpDatabase");
        if (configured != null && !configured.trim().isEmpty()) {
            return Path.of(configured.trim());
        }
        String deployed = context.getRealPath("/WEB-INF/GeoLite2-City.mmdb");
        return deployed == null ? null : Path.of(deployed);
    }

    private boolean isStaticAsset(String uri) {
        if (uri == null) return false;
        String lower = uri.toLowerCase();
        return lower.endsWith(".css")
                || lower.endsWith(".js")
                || lower.endsWith(".png")
                || lower.endsWith(".jpg")
                || lower.endsWith(".jpeg")
                || lower.endsWith(".gif")
                || lower.endsWith(".svg")
                || lower.endsWith(".ico")
                || lower.endsWith(".woff")
                || lower.endsWith(".woff2")
                || lower.endsWith(".ttf")
                || lower.endsWith(".map")
                || lower.contains("favicon");
    }

    private boolean isCountablePageView(HttpServletRequest request) {
        if (!"GET".equalsIgnoreCase(request.getMethod())) return false;
        String uri = request.getRequestURI();
        if (uri != null && (uri.endsWith("/developer-traffic.jsp")
                || uri.endsWith("/country-traffic-stats"))) return false;
        if (!isAnalyticsContentPath(pagePath(request))) return false;
        String accept = request.getHeader("Accept");
        return accept != null && accept.toLowerCase(Locale.ROOT).contains("text/html");
    }

    static boolean isAnalyticsContentPath(String path) {
        if (path == null || path.isBlank()) return true;
        String normalized = path.trim().toLowerCase(Locale.ROOT);
        int query = normalized.indexOf('?');
        if (query >= 0) normalized = normalized.substring(0, query);
        if (!normalized.startsWith("/")) normalized = "/" + normalized;
        if ("/".equals(normalized)) return true;
        if (normalized.startsWith("/integrated_umap/")) return true;
        switch (normalized) {
            case "/index.jsp":
            case "/home":
            case "/browse":
            case "/browse.jsp":
            case "/details":
            case "/details.jsp":
            case "/gene-search":
            case "/gene-search.jsp":
            case "/deg-search.jsp":
            case "/compare":
            case "/compare.jsp":
            case "/featureplot.jsp":
            case "/download.jsp":
            case "/help":
            case "/help.jsp":
            case "/method.jsp":
            case "/feedback":
            case "/feedback.jsp":
            case "/contact":
            case "/contact.jsp":
            case "/cite.jsp":
            case "/whats-new.jsp":
            case "/about.jsp":
            case "/psospotter.jsp":
            case "/gene-details":
            case "/gene-details.jsp":
            case "/visualization.jsp":
            case "/umap-explorer.jsp":
            case "/enrichment-analysis.jsp":
            case "/gene-set-scoring.jsp":
            case "/sitemap.jsp":
                return true;
            default:
                return false;
        }
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;
        ServletContext context = filterConfig.getServletContext();
        AtomicLong total = (AtomicLong) context.getAttribute(TOTAL_ATTRIBUTE);
        AtomicLong daily = (AtomicLong) context.getAttribute(DAILY_ATTRIBUTE);
        Instant now = Instant.now();
        LocalDate today = now.atZone(ZoneOffset.UTC).toLocalDate();

        // Apply the UTC boundary even when the request is the live JSON poll,
        // so an already-open homepage resets "Today" at midnight without
        // waiting for another HTML navigation.
        synchronized (counterLock) {
            LocalDate storedDate = (LocalDate) context.getAttribute(DATE_ATTRIBUTE);
            if (!today.equals(storedDate)) {
                daily.set(0);
                context.setAttribute(DATE_ATTRIBUTE, today);
                persistCounts(context, total, daily, today);
            }
        }

        if (isStaticAsset(httpRequest.getRequestURI()) || !isCountablePageView(httpRequest)) {
            chain.doFilter(request, response);
            return;
        }

        Cookie counterCookie = findCounterCookie(httpRequest.getCookies());
        Cookie visitorCookie = findVisitorCookie(httpRequest.getCookies());
        String visitorId = visitorCookie == null ? newVisitorId() : visitorCookie.getValue();
        String todayValue = today.toString();
        boolean countVisit = counterCookie == null || !todayValue.equals(counterCookie.getValue());
        boolean setVisitorCookie = visitorCookie == null;

        synchronized (counterLock) {
            boolean changed = false;
            if (countVisit) {
                total.incrementAndGet();
                daily.incrementAndGet();
                try {
                    trafficHistoryStore.record(now);
                } catch (IOException error) {
                    context.log("Unable to persist hourly traffic history to "
                            + trafficHistoryStore.getPath(), error);
                }
                CountryResolver.VisitorLocation location = countryResolver == null
                        ? CountryResolver.locate(httpRequest)
                        : countryResolver.resolve(httpRequest);
                try {
                    countryTrafficStore.record(today, location.getCountry());
                } catch (IOException error) {
                    context.log("Unable to persist country-level traffic aggregate to "
                            + countryTrafficStore.getPath(), error);
                }
                try {
                    developerVisitorStore.record(location, now);
                } catch (IOException error) {
                    context.log("Unable to persist developer visitor aggregate to "
                            + developerVisitorStore.getPath(), error);
                }
                try {
                    developerVisitEventStore.record(location, userContext(visitorId, httpRequest),
                            now, pagePath(httpRequest));
                } catch (IOException error) {
                    context.log("Unable to append developer visit event to "
                            + developerVisitEventStore.getPath(), error);
                }
                changed = true;
            }

            if (changed) {
                persistCounts(context, total, daily, today);
            }
        }

        if (countVisit) {
            Cookie updatedCookie = new Cookie("count_cookie", todayValue);
            String contextPath = httpRequest.getContextPath();
            updatedCookie.setPath(contextPath == null || contextPath.isEmpty() ? "/" : contextPath);
            updatedCookie.setMaxAge(60 * 60 * 24 * 365);
            updatedCookie.setHttpOnly(true);
            updatedCookie.setSecure(true);
            httpResponse.addCookie(updatedCookie);
        }
        if (setVisitorCookie) {
            Cookie updatedVisitorCookie = new Cookie(VISITOR_COOKIE, visitorId);
            String contextPath = httpRequest.getContextPath();
            updatedVisitorCookie.setPath(contextPath == null || contextPath.isEmpty() ? "/" : contextPath);
            updatedVisitorCookie.setMaxAge(60 * 60 * 24 * 365 * 2);
            updatedVisitorCookie.setHttpOnly(true);
            updatedVisitorCookie.setSecure(true);
            httpResponse.addCookie(updatedVisitorCookie);
        }

        chain.doFilter(request, response);
    }

    private Cookie findCounterCookie(Cookie[] cookies) {
        if (cookies == null) return null;
        for (Cookie cookie : cookies) {
            if ("count_cookie".equals(cookie.getName())) return cookie;
        }
        return null;
    }

    private Cookie findVisitorCookie(Cookie[] cookies) {
        if (cookies == null) return null;
        for (Cookie cookie : cookies) {
            if (VISITOR_COOKIE.equals(cookie.getName())
                    && cookie.getValue() != null
                    && cookie.getValue().matches("[A-Za-z0-9_-]{22,64}")) return cookie;
        }
        return null;
    }

    private String newVisitorId() {
        byte[] bytes = new byte[18];
        VISITOR_ID_RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private DeveloperVisitEventStore.UserContext userContext(String visitorId, HttpServletRequest request) {
        String userAgent = header(request, "User-Agent");
        String language = primaryLanguage(header(request, "Accept-Language"));
        return new DeveloperVisitEventStore.UserContext(visitorId, sha256Prefix(userAgent),
                browserFamily(userAgent), operatingSystemFamily(userAgent), language);
    }

    private static String header(HttpServletRequest request, String name) {
        String value = request.getHeader(name);
        if (value == null) return "";
        return value.length() > 512 ? value.substring(0, 512) : value;
    }

    private static String primaryLanguage(String acceptLanguage) {
        if (acceptLanguage == null || acceptLanguage.isBlank()) return "";
        String primary = acceptLanguage.split(",", 2)[0].trim();
        return primary.length() > 32 ? primary.substring(0, 32) : primary;
    }

    private static String sha256Prefix(String value) {
        if (value == null || value.isBlank()) return "";
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder builder = new StringBuilder();
            for (int index = 0; index < 12; index++) {
                builder.append(String.format("%02x", hash[index]));
            }
            return builder.toString();
        } catch (Exception ignored) {
            return "";
        }
    }

    private static String browserFamily(String userAgent) {
        String value = userAgent == null ? "" : userAgent.toLowerCase(Locale.ROOT);
        if (value.contains("edg/")) return "Edge";
        if (value.contains("opr/") || value.contains("opera")) return "Opera";
        if (value.contains("chrome/") || value.contains("crios/")) return "Chrome";
        if (value.contains("firefox/") || value.contains("fxios/")) return "Firefox";
        if (value.contains("safari/")) return "Safari";
        if (value.contains("bot") || value.contains("crawler") || value.contains("spider")) return "Bot";
        return value.isBlank() ? "" : "Other";
    }

    private static String operatingSystemFamily(String userAgent) {
        String value = userAgent == null ? "" : userAgent.toLowerCase(Locale.ROOT);
        if (value.contains("windows")) return "Windows";
        if (value.contains("mac os") || value.contains("macintosh")) return "macOS";
        if (value.contains("iphone") || value.contains("ipad") || value.contains("ios")) return "iOS";
        if (value.contains("android")) return "Android";
        if (value.contains("linux")) return "Linux";
        return value.isBlank() ? "" : "Other";
    }

    /** The protected analytics ledger stores only the path, never query values. */
    private String pagePath(HttpServletRequest request) {
        String path = request.getRequestURI();
        String contextPath = request.getContextPath();
        if (contextPath != null && !contextPath.isEmpty() && path != null && path.startsWith(contextPath)) {
            path = path.substring(contextPath.length());
        }
        return path == null || path.isBlank() ? "/" : path;
    }

    private void persistCounts(ServletContext context, AtomicLong total, AtomicLong daily, LocalDate date) {
        try {
            counterStore.save(total.get(), daily.get(), date);
        } catch (IOException error) {
            context.log("Unable to persist access counter to " + counterStore.getPath(), error);
        }
    }

    @Override
    public void destroy() {
        if (filterConfig == null || counterStore == null) return;
        ServletContext context = filterConfig.getServletContext();
        AtomicLong total = (AtomicLong) context.getAttribute(TOTAL_ATTRIBUTE);
        AtomicLong daily = (AtomicLong) context.getAttribute(DAILY_ATTRIBUTE);
        LocalDate date = (LocalDate) context.getAttribute(DATE_ATTRIBUTE);
        if (total == null || daily == null || date == null) return;

        synchronized (counterLock) {
            persistCounts(context, total, daily, date);
        }
        if (countryResolver != null) {
            try {
                countryResolver.close();
            } catch (IOException error) {
                context.log("Unable to close local GeoLite database", error);
            }
        }
    }
}
