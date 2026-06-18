package Utils;

import javax.servlet.*;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Lightweight per-client-IP rate limiter for abuse-prone endpoints
 * (process spawners and search). Sliding fixed-window counters kept in memory.
 *
 * <p>The real client IP is resolved from the Cloudflare/sslh/nginx chain:
 * {@code CF-Connecting-IP} -> first hop of {@code X-Forwarded-For} -> remote addr.
 *
 * <p>The static {@link #allow(String, String, int)} method is reused by
 * {@code Servlet.feedback} so the Turnstile verify endpoint shares the same logic.
 */
public class RateLimitFilter implements Filter {

    // window length for all buckets
    private static final long WINDOW_MS = 60_000L;

    // per-bucket request budget within one window
    private static final int LIMIT_PROCESS = 15;   // spawn Python / heavy compute
    private static final int LIMIT_SEARCH  = 60;    // CSV scans / lookups
    private static final int LIMIT_DEFAULT = 90;

    // ip|bucket -> window state
    private static final Map<String, Window> WINDOWS = new ConcurrentHashMap<>();
    private static final AtomicLong lastSweep = new AtomicLong(0L);

    private static final class Window {
        volatile long windowStart;
        final AtomicInteger count = new AtomicInteger(0);
        Window(long start) { this.windowStart = start; }
    }

    @Override
    public void init(FilterConfig filterConfig) {
        // no configuration required
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse res = (HttpServletResponse) response;

        String bucket = bucketFor(req.getRequestURI(), req.getContextPath());
        int limit = limitFor(bucket);

        if (!allow(clientIp(req), bucket, limit)) {
            res.setStatus(429); // 429 Too Many Requests
            res.setHeader("Retry-After", "60");
            res.setContentType("application/json;charset=UTF-8");
            res.getWriter().write("{\"error\":\"Too many requests. Please slow down and try again shortly.\"}");
            return;
        }

        chain.doFilter(request, response);
    }

    /**
     * Returns {@code true} if a request for {@code bucket} from {@code ip} is within
     * {@code limitPerMinute}; {@code false} when the budget for the current window is spent.
     */
    public static boolean allow(String ip, String bucket, int limitPerMinute) {
        long now = System.currentTimeMillis();
        maybeSweep(now);

        String key = ip + "|" + bucket;
        Window w = WINDOWS.computeIfAbsent(key, k -> new Window(now));
        synchronized (w) {
            if (now - w.windowStart >= WINDOW_MS) {
                w.windowStart = now;
                w.count.set(0);
            }
            return w.count.incrementAndGet() <= limitPerMinute;
        }
    }

    /** Resolve the originating client IP behind Cloudflare -> sslh -> nginx. */
    public static String clientIp(HttpServletRequest req) {
        String cf = req.getHeader("CF-Connecting-IP");
        if (cf != null && !cf.trim().isEmpty()) {
            return cf.trim();
        }
        String xff = req.getHeader("X-Forwarded-For");
        if (xff != null && !xff.trim().isEmpty()) {
            int comma = xff.indexOf(',');
            return (comma > 0 ? xff.substring(0, comma) : xff).trim();
        }
        return req.getRemoteAddr();
    }

    private static String bucketFor(String uri, String ctx) {
        String path = uri;
        if (ctx != null && !ctx.isEmpty() && path.startsWith(ctx)) {
            path = path.substring(ctx.length());
        }
        if (path.startsWith("/visualization") || path.startsWith("/enrichment")
                || path.startsWith("/integrate")) {
            return "process";
        }
        if (path.startsWith("/gene-search") || path.startsWith("/gene-details")
                || path.startsWith("/deg")) {
            return "search";
        }
        return "default";
    }

    private static int limitFor(String bucket) {
        switch (bucket) {
            case "process": return LIMIT_PROCESS;
            case "search":  return LIMIT_SEARCH;
            default:        return LIMIT_DEFAULT;
        }
    }

    /** Drop stale windows occasionally so the map cannot grow without bound. */
    private static void maybeSweep(long now) {
        long prev = lastSweep.get();
        if (now - prev < WINDOW_MS) {
            return;
        }
        if (!lastSweep.compareAndSet(prev, now)) {
            return;
        }
        WINDOWS.entrySet().removeIf(e -> now - e.getValue().windowStart >= 2 * WINDOW_MS);
    }

    @Override
    public void destroy() {
        WINDOWS.clear();
    }
}
