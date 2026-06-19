package Servlet;

import javax.servlet.ServletException;
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
 * Proxy servlet for cross-dataset DEG comparison.
 * Forwards to the Python Flask API on port 8054 (same service as CellPhoneDB).
 *
 *   POST /deg-compare            body {"saidA":"X","saidB":"Y"}  -> {"jobId":"..."}
 *   GET  /deg-compare/status?jobId=
 *   GET  /deg-compare/result?jobId=&pval=&fc=&cellType=
 *
 * Also exposes GET /datasets?species=&exclude= (maps to /api/datasets).
 */
@WebServlet(urlPatterns = {"/deg-compare", "/deg-compare/status", "/deg-compare/result", "/datasets",
                            "/deg-per-celltype", "/deg-per-celltype/status", "/deg-per-celltype/result"})
public class DEGCompareServlet extends HttpServlet {

    private static final String API_BASE = "http://127.0.0.1:8054";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String path = req.getServletPath();
        resp.setContentType("application/json");
        resp.setCharacterEncoding("UTF-8");

        String upstream;
        if ("/datasets".equals(path)) {
            upstream = "/api/datasets?" + buildQuery(req, "species", "exclude");
        } else if (path.startsWith("/deg-per-celltype")) {
            if (path.endsWith("/status")) {
                upstream = "/api/deg-per-celltype/status?" + buildQuery(req, "jobId");
            } else if (path.endsWith("/result")) {
                upstream = "/api/deg-per-celltype/result?" + buildQuery(req, "jobId", "pval", "fc", "cellType");
            } else {
                resp.sendError(HttpServletResponse.SC_NOT_FOUND);
                return;
            }
        } else if (path.endsWith("/status")) {
            upstream = "/api/deg-compare/status?" + buildQuery(req, "jobId");
        } else if (path.endsWith("/result")) {
            upstream = "/api/deg-compare/result?" + buildQuery(req, "jobId", "pval", "fc", "cellType");
        } else {
            resp.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }
        proxyGet(upstream, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json");
        resp.setCharacterEncoding("UTF-8");

        StringBuilder body = new StringBuilder();
        try (BufferedReader r = req.getReader()) {
            String line;
            while ((line = r.readLine()) != null) body.append(line);
        }
        String path = req.getServletPath();
        String upstream = "/deg-per-celltype".equals(path)
                ? "/api/deg-per-celltype/run"
                : "/api/deg-compare/run";
        proxyPostJson(upstream, body.toString(), resp);
    }

    // ----- helpers -----

    private static String buildQuery(HttpServletRequest req, String... keys) {
        StringBuilder sb = new StringBuilder();
        boolean first = true;
        for (String k : keys) {
            String v = req.getParameter(k);
            if (v == null) continue;
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
        conn.setReadTimeout(30000);
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
        conn.setReadTimeout(30000);
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
