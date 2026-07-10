package Servlet;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * Proxy servlet for the cross-condition comparison feature.
 * Forwards to the Python Flask API on port 8054.
 *
 *   GET  /conditions?species=
 *
 *   POST /condition-compare              body {"species":..,"conditionA":..,"conditionB":..} -> {"jobId":..}
 *   GET  /condition-compare/status?jobId=
 *   GET  /condition-compare/result?jobId=&pval=&fc=&cellType=
 *
 *   POST /condition-gsea                 body {"jobId":..,"cellType":..,"gmtFile":..} -> {"jobId":..}
 *   GET  /condition-gsea/status?jobId=
 *   GET  /condition-gsea/result?jobId=&topN=&direction=
 *
 *   GET  /gmt-catalog?species=           (proxy of /api/gmt-catalog so the page can populate library list)
 */
@WebServlet(urlPatterns = {
        "/conditions",
        "/condition-compare", "/condition-compare/status", "/condition-compare/result",
        "/condition-gsea",   "/condition-gsea/status",    "/condition-gsea/result",
        "/gmt-catalog"
})
public class ConditionCompareServlet extends HttpServlet {

    private static final String API_BASE = "http://127.0.0.1:8054";
    private static final int MAX_JSON_BODY = 65_536;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String path = req.getServletPath();
        resp.setContentType("application/json");
        resp.setCharacterEncoding("UTF-8");

        String upstream;
        if ("/conditions".equals(path)) {
            upstream = "/api/conditions?" + buildQuery(req, "species");
        } else if ("/gmt-catalog".equals(path)) {
            upstream = "/api/gmt-catalog?" + buildQuery(req, "species");
        } else if (path.startsWith("/condition-compare")) {
            if (path.endsWith("/status")) {
                upstream = "/api/condition-compare/status?" + buildQuery(req, "jobId");
            } else if (path.endsWith("/result")) {
                upstream = "/api/condition-compare/result?" + buildQuery(req, "jobId", "pval", "fc", "cellType");
            } else {
                resp.sendError(HttpServletResponse.SC_NOT_FOUND);
                return;
            }
        } else if (path.startsWith("/condition-gsea")) {
            if (path.endsWith("/status")) {
                upstream = "/api/condition-gsea/status?" + buildQuery(req, "jobId");
            } else if (path.endsWith("/result")) {
                upstream = "/api/condition-gsea/result?" + buildQuery(req, "jobId", "topN", "direction");
            } else {
                resp.sendError(HttpServletResponse.SC_NOT_FOUND);
                return;
            }
        } else {
            resp.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }
        proxyGet(upstream, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String path = req.getServletPath();
        resp.setContentType("application/json");
        resp.setCharacterEncoding("UTF-8");

        StringBuilder body = new StringBuilder();
        try (BufferedReader r = req.getReader()) {
            String line;
            while ((line = r.readLine()) != null) {
                if (body.length() + line.length() > MAX_JSON_BODY) {
                    resp.sendError(HttpServletResponse.SC_REQUEST_ENTITY_TOO_LARGE, "Request body is too large");
                    return;
                }
                body.append(line);
            }
        }

        String upstream;
        if ("/condition-compare".equals(path)) {
            upstream = "/api/condition-compare/run";
        } else if ("/condition-gsea".equals(path)) {
            upstream = "/api/condition-gsea/run";
        } else {
            resp.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }
        proxyPostJson(upstream, body.toString(), resp);
    }

    // ----- helpers (parallel to DEGCompareServlet) -----

    private static String buildQuery(HttpServletRequest req, String... keys) {
        StringBuilder sb = new StringBuilder();
        boolean first = true;
        for (String k : keys) {
            String v = req.getParameter(k);
            if (v == null) continue;
            if (v.length() > 256) continue;
            if (!first) sb.append("&");
            first = false;
            sb.append(URLEncoder.encode(k, StandardCharsets.UTF_8))
              .append("=")
              .append(URLEncoder.encode(v, StandardCharsets.UTF_8));
        }
        return sb.toString();
    }

    private static void proxyGet(String upstreamPath, HttpServletResponse resp) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) new URL(API_BASE + upstreamPath).openConnection();
        conn.setRequestMethod("GET");
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(60000);
        int code = conn.getResponseCode();
        resp.setStatus(code == HttpURLConnection.HTTP_OK ? 200 : code);
        try (InputStream in = (code >= 400 ? conn.getErrorStream() : conn.getInputStream());
             OutputStream out = resp.getOutputStream()) {
            if (in == null) return;
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        }
    }

    private static void proxyPostJson(String upstreamPath, String jsonBody, HttpServletResponse resp) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) new URL(API_BASE + upstreamPath).openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(60000);
        try (OutputStream os = conn.getOutputStream()) {
            os.write(jsonBody.getBytes(StandardCharsets.UTF_8));
        }
        int code = conn.getResponseCode();
        resp.setStatus(code == HttpURLConnection.HTTP_OK ? 200 : code);
        try (InputStream in = (code >= 400 ? conn.getErrorStream() : conn.getInputStream());
             OutputStream out = resp.getOutputStream()) {
            if (in == null) return;
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        }
    }
}
