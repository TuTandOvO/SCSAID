package AccessCounter;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;

/** Protects country aggregates from the public internet with deploy-time credentials. */
public final class DeveloperAnalyticsFilter implements Filter {
    private static final String USER_ENV = "SCSAID_ANALYTICS_USER";
    private static final String PASSWORD_ENV = "SCSAID_ANALYTICS_PASSWORD";

    private String expectedUser;
    private String expectedPassword;

    @Override
    public void init(FilterConfig filterConfig) {
        expectedUser = System.getenv(USER_ENV);
        expectedPassword = System.getenv(PASSWORD_ENV);
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletResponse httpResponse = (HttpServletResponse) response;
        if (!configured()) {
            httpResponse.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        if (!validCredentials(httpRequest.getHeader("Authorization"))) {
            httpResponse.setHeader("WWW-Authenticate", "Basic realm=\"scSAID private analytics\"");
            httpResponse.setHeader("Cache-Control", "no-store");
            httpResponse.sendError(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }
        httpResponse.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
        httpResponse.setHeader("Pragma", "no-cache");
        chain.doFilter(request, response);
    }

    private boolean configured() {
        return expectedUser != null && !expectedUser.isBlank()
                && expectedPassword != null && !expectedPassword.isBlank();
    }

    private boolean validCredentials(String authorization) {
        if (authorization == null || !authorization.startsWith("Basic ")) return false;
        try {
            String decoded = new String(Base64.getDecoder().decode(authorization.substring(6)),
                    StandardCharsets.UTF_8);
            int separator = decoded.indexOf(':');
            if (separator < 0) return false;
            byte[] suppliedUser = decoded.substring(0, separator).getBytes(StandardCharsets.UTF_8);
            byte[] suppliedPassword = decoded.substring(separator + 1).getBytes(StandardCharsets.UTF_8);
            return MessageDigest.isEqual(expectedUser.getBytes(StandardCharsets.UTF_8), suppliedUser)
                    && MessageDigest.isEqual(expectedPassword.getBytes(StandardCharsets.UTF_8), suppliedPassword);
        } catch (IllegalArgumentException ignored) {
            return false;
        }
    }
}
