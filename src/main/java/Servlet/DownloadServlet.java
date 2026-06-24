package Servlet;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.*;
import java.util.*;

@WebServlet("/download-file")
public class DownloadServlet extends HttpServlet {

    // Whitelist of allowed files for download
    private static final Map<String, FileInfo> ALLOWED_FILES = new HashMap<>();

    static {
        ALLOWED_FILES.put("browse", new FileInfo(
            "WEB-INF/BrowseShow.xlsx",
            "scSAID_Browse_Data.xlsx",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "Dataset overview and browse data"
        ));
        ALLOWED_FILES.put("all", new FileInfo(
            "WEB-INF/AllData.xlsx",
            "scSAID_All_Data.xlsx",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "Complete dataset with all metadata"
        ));
        ALLOWED_FILES.put("csv", new FileInfo(
            "WEB-INF/scSAID_sample_metadata.csv",
            "scSAID_sample_metadata.csv",
            "text/csv; charset=UTF-8",
            "Sample metadata (252 rows, CSV, easy for R/Python)"
        ));
        ALLOWED_FILES.put("integrate", new FileInfo(
            "WEB-INF/IntegrateTable.xlsx",
            "scSAID_Integration_Table.xlsx",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "Integration analysis data"
        ));
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String fileKey = request.getParameter("file");

        if (fileKey == null || fileKey.isEmpty()) {
            // Return list of available files as JSON
            response.setContentType("application/json;charset=UTF-8");
            PrintWriter out = response.getWriter();
            out.print("{\"files\":[");
            boolean first = true;
            for (Map.Entry<String, FileInfo> entry : ALLOWED_FILES.entrySet()) {
                if (!first) out.print(",");
                first = false;
                FileInfo info = entry.getValue();
                String realPath = getServletContext().getRealPath("/" + info.path);
                File file = new File(realPath);
                long size = file.exists() ? file.length() : 0;

                out.print("{");
                out.print("\"key\":\"" + entry.getKey() + "\",");
                out.print("\"filename\":\"" + info.downloadName + "\",");
                out.print("\"description\":\"" + info.description + "\",");
                out.print("\"size\":" + size + ",");
                out.print("\"available\":" + file.exists());
                out.print("}");
            }
            out.print("]}");
            return;
        }

        FileInfo fileInfo = ALLOWED_FILES.get(fileKey);
        if (fileInfo == null) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Invalid file key: " + fileKey);
            return;
        }

        String realPath = getServletContext().getRealPath("/" + fileInfo.path);
        File file = new File(realPath);

        if (!file.exists()) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND, "File not found");
            return;
        }

        // Set response headers for file download
        response.setContentType(fileInfo.mimeType);
        response.setHeader("Content-Disposition", "attachment; filename=\"" + fileInfo.downloadName + "\"");
        response.setContentLengthLong(file.length());

        // Stream the file
        try (FileInputStream fis = new FileInputStream(file);
             OutputStream os = response.getOutputStream()) {

            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = fis.read(buffer)) != -1) {
                os.write(buffer, 0, bytesRead);
            }
            os.flush();
        }
    }

    private static class FileInfo {
        final String path;
        final String downloadName;
        final String mimeType;
        final String description;

        FileInfo(String path, String downloadName, String mimeType, String description) {
            this.path = path;
            this.downloadName = downloadName;
            this.mimeType = mimeType;
            this.description = description;
        }
    }
}
