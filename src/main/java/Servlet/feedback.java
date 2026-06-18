package Servlet;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.annotation.*;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

import Utils.RateLimitFilter;

/**
 * Feedback page. The page embeds a Google Form; to curb over-submission the
 * iframe is gated behind a Cloudflare Turnstile challenge whose token is
 * verified here ({@code doPost}) before the form is revealed.
 *
 * <p>Configuration (no secrets in the WAR):
 * <ul>
 *   <li>{@code TURNSTILE_SECRET} env var — private key used for server-side verify.</li>
 *   <li>site key — {@code turnstileSiteKey} context-param (or {@code TURNSTILE_SITE_KEY} env),
 *       exposed to the page. When blank, the gate is disabled and the form shows as before.</li>
 * </ul>
 */
@WebServlet(name = "feedback", value = "/feedback")
public class feedback extends HttpServlet {

    private static final String SITEVERIFY_URL =
            "https://challenges.cloudflare.com/turnstile/v0/siteverify";

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        request.setAttribute("turnstileSiteKey", siteKey());
        request.getRequestDispatcher("feedback.jsp").forward(request, response);
    }

    /** Verify a Turnstile token. Returns JSON {"ok":true|false}. */
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.setContentType("application/json;charset=UTF-8");

        String clientIp = RateLimitFilter.clientIp(request);

        // Throttle verification attempts per IP regardless of token validity.
        if (!RateLimitFilter.allow(clientIp, "feedback", 10)) {
            response.setStatus(429);
            response.setHeader("Retry-After", "60");
            response.getWriter().write("{\"ok\":false,\"error\":\"rate_limited\"}");
            return;
        }

        String secret = secret();
        // If the gate is not configured, treat as open so the page never breaks.
        if (secret == null || secret.isEmpty()) {
            response.getWriter().write("{\"ok\":true,\"gate\":\"disabled\"}");
            return;
        }

        String token = request.getParameter("cf-turnstile-response");
        if (token == null || token.trim().isEmpty()) {
            response.getWriter().write("{\"ok\":false,\"error\":\"missing_token\"}");
            return;
        }

        boolean ok = verifyTurnstile(secret, token.trim(), clientIp);
        response.getWriter().write(ok ? "{\"ok\":true}" : "{\"ok\":false}");
    }

    private boolean verifyTurnstile(String secret, String token, String clientIp) {
        try {
            StringBuilder body = new StringBuilder();
            body.append("secret=").append(enc(secret));
            body.append("&response=").append(enc(token));
            if (clientIp != null && !clientIp.isEmpty()) {
                body.append("&remoteip=").append(enc(clientIp));
            }

            URL url = new URL(SITEVERIFY_URL);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
            conn.setConnectTimeout(5000);
            conn.setReadTimeout(5000);

            byte[] payload = body.toString().getBytes(StandardCharsets.UTF_8);
            try (OutputStream os = conn.getOutputStream()) {
                os.write(payload);
            }

            int code = conn.getResponseCode();
            if (code != 200) {
                getServletContext().log("Turnstile verify HTTP " + code);
                return false;
            }

            StringBuilder resp = new StringBuilder();
            try (BufferedReader in = new BufferedReader(
                    new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = in.readLine()) != null) {
                    resp.append(line);
                }
            }

            JsonObject json = JsonParser.parseString(resp.toString()).getAsJsonObject();
            return json.has("success") && json.get("success").getAsBoolean();
        } catch (Exception e) {
            getServletContext().log("Turnstile verify error: " + e.getMessage());
            return false;
        }
    }

    private static String enc(String v) {
        try {
            return URLEncoder.encode(v, StandardCharsets.UTF_8.toString());
        } catch (Exception e) {
            return "";
        }
    }

    private String secret() {
        String s = System.getenv("TURNSTILE_SECRET");
        return s == null ? null : s.trim();
    }

    private String siteKey() {
        String s = getServletContext().getInitParameter("turnstileSiteKey");
        if (s == null || s.trim().isEmpty()) {
            s = System.getenv("TURNSTILE_SITE_KEY");
        }
        return s == null ? "" : s.trim();
    }
}
