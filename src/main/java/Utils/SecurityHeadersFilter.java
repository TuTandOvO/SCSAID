package Utils;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/** Adds a defensive baseline to every response, including application errors. */
public class SecurityHeadersFilter implements Filter {
    @Override
    public void init(FilterConfig filterConfig) {
        // No configuration required.
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletResponse res = (HttpServletResponse) response;
        res.setHeader("X-Content-Type-Options", "nosniff");
        res.setHeader("X-Frame-Options", "SAMEORIGIN");
        res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
        res.setHeader("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=()");
        res.setHeader("Cross-Origin-Opener-Policy", "same-origin");
        res.setHeader("Cross-Origin-Resource-Policy", "same-site");
        res.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
        chain.doFilter(request, response);
    }

    @Override
    public void destroy() {
        // No resources to release.
    }
}
