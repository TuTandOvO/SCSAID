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
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicLong;

public class AccessCounterFilter implements Filter {
    private static final String TOTAL_ATTRIBUTE = "totalCount";
    private static final String DAILY_ATTRIBUTE = "dailyCount";
    private static final String DATE_ATTRIBUTE = "currentDate";

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
        context.log("Access counter loaded from " + counterPath
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
        String accept = request.getHeader("Accept");
        return accept != null && accept.toLowerCase(Locale.ROOT).contains("text/html");
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
        String todayValue = today.toString();
        boolean countVisit = counterCookie == null || !todayValue.equals(counterCookie.getValue());

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
                try {
                    CountryResolver.VisitorLocation location = countryResolver == null
                            ? CountryResolver.locate(httpRequest)
                            : countryResolver.resolve(httpRequest);
                    countryTrafficStore.record(today, location.getCountry());
                    developerVisitorStore.record(location, now);
                    developerVisitEventStore.record(location, now, pagePath(httpRequest));
                } catch (IOException error) {
                    context.log("Unable to persist country-level traffic aggregate to "
                            + countryTrafficStore.getPath(), error);
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

        chain.doFilter(request, response);
    }

    private Cookie findCounterCookie(Cookie[] cookies) {
        if (cookies == null) return null;
        for (Cookie cookie : cookies) {
            if ("count_cookie".equals(cookie.getName())) return cookie;
        }
        return null;
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
