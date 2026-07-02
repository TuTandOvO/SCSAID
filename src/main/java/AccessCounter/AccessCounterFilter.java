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
import java.time.LocalDate;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicLong;

public class AccessCounterFilter implements Filter {
    private static final String TOTAL_ATTRIBUTE = "totalCount";
    private static final String DAILY_ATTRIBUTE = "dailyCount";
    private static final String DATE_ATTRIBUTE = "currentDate";

    private final Object counterLock = new Object();
    private FilterConfig filterConfig;
    private CounterStore counterStore;

    @Override
    public void init(FilterConfig filterConfig) throws ServletException {
        this.filterConfig = filterConfig;
        ServletContext context = filterConfig.getServletContext();
        Path counterPath = resolveCounterPath(filterConfig, context);
        counterStore = new CounterStore(counterPath);

        LocalDate today = LocalDate.now();
        CounterStore.Snapshot snapshot;
        try {
            snapshot = counterStore.load(today);
        } catch (IOException error) {
            context.log("Unable to load access counter from " + counterPath, error);
            snapshot = new CounterStore.Snapshot(0, 0, today);
        }

        context.setAttribute("counterFile", counterPath.toString());
        context.setAttribute(TOTAL_ATTRIBUTE, new AtomicLong(snapshot.total));
        context.setAttribute(DAILY_ATTRIBUTE, new AtomicLong(snapshot.daily));
        context.setAttribute(DATE_ATTRIBUTE, snapshot.date);
        context.log("Access counter loaded from " + counterPath
                + ": total=" + snapshot.total + ", daily=" + snapshot.daily);
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
        String accept = request.getHeader("Accept");
        return accept != null && accept.toLowerCase(Locale.ROOT).contains("text/html");
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;
        ServletContext context = filterConfig.getServletContext();

        if (isStaticAsset(httpRequest.getRequestURI()) || !isCountablePageView(httpRequest)) {
            chain.doFilter(request, response);
            return;
        }

        AtomicLong total = (AtomicLong) context.getAttribute(TOTAL_ATTRIBUTE);
        AtomicLong daily = (AtomicLong) context.getAttribute(DAILY_ATTRIBUTE);
        LocalDate today = LocalDate.now();
        Cookie counterCookie = findCounterCookie(httpRequest.getCookies());
        String todayValue = today.toString();
        boolean countVisit = counterCookie == null || !todayValue.equals(counterCookie.getValue());

        synchronized (counterLock) {
            LocalDate storedDate = (LocalDate) context.getAttribute(DATE_ATTRIBUTE);
            boolean changed = false;
            if (!today.equals(storedDate)) {
                daily.set(0);
                context.setAttribute(DATE_ATTRIBUTE, today);
                changed = true;
            }

            if (countVisit) {
                total.incrementAndGet();
                daily.incrementAndGet();
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
    }
}
