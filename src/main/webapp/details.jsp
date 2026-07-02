<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%@ page import="
    java.io.*,
    java.util.*,
    java.nio.file.Paths,
    Utils.DataPathResolver" %>
<%!
    private static final String DOWNLOAD_DATA_RELATIVE_PATH = "download_data";
    private static final String HUMAN_CSV_RELATIVE_PATH = "human/human_obs_by_batch.csv";
    private static final String MOUSE_CSV_RELATIVE_PATH = "mouse/mouse_obs_by_batch.csv";


    // Helper method to build the path to the cpdb_out directory for a given sample
    private String getCpdbPath(String dataRoot, String gse, String gsm) {
        // This logic assumes a path structure like /SkinDB_New/10X/human/GSE.../GSM.../
        // You MUST adjust this to match your actual directory structure.
        if (dataRoot == null || dataRoot.isEmpty() || gse == null || gsm == null || gse.isEmpty() || gsm.isEmpty()) {
            return null;
        }
        return Paths.get(dataRoot, DOWNLOAD_DATA_RELATIVE_PATH, "10X", "human", gse, gsm, "cpdb_out").toString();
    }

    // Escape a string so it can be embedded inside a JSON string literal (used
    // to build inline JSON-LD without pulling in Gson here).
    protected static String jsonEscape(String s) {
        if (s == null) return "";
        StringBuilder out = new StringBuilder(s.length() + 8);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '\\': out.append("\\\\"); break;
                case '"':  out.append("\\\""); break;
                case '\n': out.append(" "); break;
                case '\r': out.append(" "); break;
                case '\t': out.append(" "); break;
                case '<':  out.append("\\u003C"); break; // avoid </script> injection
                case '>':  out.append("\\u003E"); break;
                default:
                    if (c < 0x20) out.append(' '); else out.append(c);
            }
        }
        return out.toString();
    }
%>
<%
    // =========================================================================
    // SECTION A: NEW BACKEND LOGIC FOR HANDLING AJAX REQUESTS FOR CELLPHONEDB
    // =========================================================================
    String dataRoot = DataPathResolver.resolveDataRoot(application);
    String pythonCommand = DataPathResolver.resolvePythonCommand(application);
    File humanCsvFile = DataPathResolver.resolveReadableFile(application, HUMAN_CSV_RELATIVE_PATH);
    File mouseCsvFile = DataPathResolver.resolveReadableFile(application, MOUSE_CSV_RELATIVE_PATH);
    String humanCsvPath = humanCsvFile.getAbsolutePath();
    String mouseCsvPath = mouseCsvFile.getAbsolutePath();

    String action = request.getParameter("action");
    if (action != null) {
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        PrintWriter jsonOut = response.getWriter();
        String saidParamForAction = request.getParameter("said");
        String gseForAction = request.getParameter("gse");
        String gsmForAction = request.getParameter("gsm");

        // Handle cell proportion action (does not need cpdbPath)
        if ("cell_proportion".equals(action)) {
            String mapType = request.getParameter("map_type");
            String speciesForProp = request.getParameter("species");
            if (mapType == null) mapType = "Gross_Map";
            if (speciesForProp == null) speciesForProp = "human";
            String h5adDir = speciesForProp.equalsIgnoreCase("mouse") ? "mouse" : "human";
            String h5adFile = Paths.get(dataRoot, DOWNLOAD_DATA_RELATIVE_PATH, h5adDir, gseForAction, gsmForAction, gseForAction + "_" + gsmForAction + ".h5ad").toString();
            String propScript = Paths.get(dataRoot, "services", "cell_proportion.py").toString();
            try {
                ProcessBuilder pb = new ProcessBuilder(pythonCommand, propScript, h5adFile, mapType);
                pb.redirectErrorStream(true);
                Process p = pb.start();
                BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream(), "UTF-8"));
                StringBuilder sb = new StringBuilder();
                String ln;
                while ((ln = br.readLine()) != null) sb.append(ln);
                br.close();
                p.waitFor();
                jsonOut.print(sb.toString());
            } catch (Exception e) {
                jsonOut.print("{\"error\": \"" + e.getMessage().replace("\"", "'") + "\"}");
            }
            jsonOut.flush();
            return;
        }

        String cpdbPath = getCpdbPath(dataRoot, gseForAction, gsmForAction);

        if (cpdbPath == null || !new File(cpdbPath).exists()) {
            jsonOut.print("{\"error\": \"CPDB data path not found for the given sample. Path was: " + (cpdbPath == null ? "null" : cpdbPath.replace("\\", "\\\\")) + "\"}");
            jsonOut.flush();
            return;
        }

        try {
            if ("get_cell_types".equals(action)) {
                // 调用 Python 脚本 --list 模式
                String pythonScriptPath = Paths.get(cpdbPath, "plot_cpdb_receiver_top15.py").toString();
                ProcessBuilder pb = new ProcessBuilder(pythonCommand, pythonScriptPath, "--list");
                pb.directory(new File(cpdbPath));
                pb.redirectErrorStream(true);
                try {
                    Process p = pb.start();
                    BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream(), "UTF-8"));
                    StringBuilder sb = new StringBuilder();
                    String line;
                    while ((line = br.readLine()) != null) {
                        sb.append(line);
                    }
                    br.close();
                    int exitCode = p.waitFor();
                    if (exitCode == 0) {
                        jsonOut.print(sb.toString());
                        // 直接输出 Python 的 JSON
                    } else {
                        jsonOut.print("{\"error\": \"Python script exited with code " + exitCode + ". Output: " + sb.toString().replace("\"", "'") + "\"}");
                    }
                } catch (Exception e) {
                    jsonOut.print("{\"error\": \"Exception: " + e.getMessage().replace("\"", "'") + "\"}");
                }
                return;
            }
            else if ("generate_plot".equals(action)) {
                String plotType = request.getParameter("plot_type");
                String scriptName = "";
                List<String> command = new ArrayList<String>();
                command.add(pythonCommand);
                String outputFileName = "";
                // 定义输出文件名变量

                if ("summary".equals(plotType)) {
                    scriptName = "plot_cpdb_sum_sig.py";
                    outputFileName = "sum_sig_heatmap.png"; // 使用您本地运行的硬编码文件名
                } else if ("receiver".equals(plotType)) {
                    scriptName = "plot_cpdb_receiver_top15.py";
                    String cellType = request.getParameter("cell_type");
                    if (cellType == null || cellType.isEmpty()) {
                        jsonOut.print("{\"error\": \"Cell type is required for this plot.\"}");
                        return;
                    }
                    command.add(new File(cpdbPath, scriptName).getAbsolutePath());
                    command.add(cellType);
                    outputFileName = "top15_receiver_" + cellType.replace(" ", "_").replace("/", "_") + ".png";
                } else {
                    jsonOut.print("{\"error\": \"Invalid plot type specified.\"}");
                    return;
                }

                if (command.size() == 1) { // For scripts that need no extra args, like summary plot
                    command.add(new File(cpdbPath, scriptName).getAbsolutePath());
                }

                // Execute the script
                ProcessBuilder pb = new ProcessBuilder(command);
                pb.directory(new File(cpdbPath)); // Execute script in its directory
                // 修改：不捕获脚本输出，只等待进程结束，以防止JSON响应被污染
                Process process = pb.start();
                InputStream is = null, es = null;
                try {
                    is = process.getInputStream();
                    es = process.getErrorStream();
                    while (is.read() != -1) ;
                    while (es.read() != -1) ;
                } finally {
                    if (is != null) try { is.close(); } catch (IOException ignore) {}
                    if (es != null) try { es.close(); } catch (IOException ignore) {}
                }

                int exitCode = process.waitFor();
                if (exitCode == 0) {
                    // Check if the output file was generated
                    File outputFile = new File(cpdbPath, outputFileName);
                    if (outputFile.exists()) {
                        String imageUrl = request.getContextPath() + "/SkinDB_New/10X/human/" + gseForAction + "/" + gsmForAction + "/cpdb_out/" + outputFileName;
                        jsonOut.print("{\"imageUrl\": \"" + imageUrl + "\"}");
                    } else {
                        // 修改: 移除 scriptOutput 变量，因为我们已不再捕获它
                        jsonOut.print("{\"error\": \"Plot generated successfully but output file not found: " + outputFileName + ".\"}");
                    }
                } else {
                    // 修改: 移除 scriptOutput 变量，因为我们已不再捕获它
                    jsonOut.print("{\"error\": \"Failed to generate plot. Exit code: " + exitCode + ".\"}");
                }
            }
        } catch (Exception e) {
            jsonOut.print("{\"error\": \"An exception occurred: " + e.getMessage().replace("\"", "'") + "\"}");
        } finally {
            jsonOut.flush();
        }
        return; // End execution here, do not render the HTML page
    }

    // =========================================================================
    // SECTION B: EXISTING JSP LOGIC FOR PAGE DISPLAY
    // =========================================================================
    // 1) 获取 URL 中的 said 参数
    String saidParam = request.getParameter("said");
    if (saidParam == null || saidParam.trim().isEmpty()) {
        out.println("<h2 style='color:red;'>Error: no SAID specified.</h2>");
        return;
    }

    // 2) 声明变量
    String saidVal = "";
    String gseVal = "";
    String gsmVal = "";
    String speciesVal = "";
    String n_cellsVal = "";
    String conditionVal = "";
    String ageVal = "";
    String sexVal = "";
    String tissueVal = "";
    String h5adPath = "";

    BufferedReader csvReader = null;
    String csvError = null;

    // Check if CSV files exist
    if (!humanCsvFile.exists() || !mouseCsvFile.exists()) {
        csvError = "CSV data files not found. Human path: " + humanCsvPath + ", Mouse path: " + mouseCsvPath;
        out.println("<h2 style='color:red;'>Error loading CSV: " + csvError + "</h2>");
        return;
    } else {
        try {
        // 3) Search in human CSV first
        boolean found = false;
        csvReader = new BufferedReader(new FileReader(humanCsvPath));
        String headerLine = csvReader.readLine(); // Skip header
        String line;
        while ((line = csvReader.readLine()) != null) {
            String[] parts = line.split(",", -1);
            if (parts.length >= 11 && saidParam.equals(parts[10])) {
                saidVal = parts[10];
                gseVal = parts[9];
                gsmVal = parts[5];
                speciesVal = "Human";
                n_cellsVal = parts[1];
                conditionVal = parts[2];
                ageVal = parts[3];
                sexVal = parts[4];
                tissueVal = parts[6];
                h5adPath = dataRoot + "/" + DOWNLOAD_DATA_RELATIVE_PATH + "/human/" + gseVal + "/" + gsmVal + "/" + gseVal + "_" + gsmVal + ".h5ad";
                found = true;
                break;
            }
        }
        csvReader.close();

        // 4) If not found in human CSV, search in mouse CSV
        if (!found) {
            csvReader = new BufferedReader(new FileReader(mouseCsvPath));
            csvReader.readLine(); // Skip header
            while ((line = csvReader.readLine()) != null) {
                String[] parts = line.split(",", -1);
                if (parts.length >= 11 && saidParam.equals(parts[10])) {
                    saidVal = parts[10];
                    gseVal = parts[9];
                    gsmVal = parts[5];
                    speciesVal = "Mouse";
                    n_cellsVal = parts[1];
                    conditionVal = parts[2];
                    ageVal = parts[3];
                    sexVal = parts[4];
                    tissueVal = parts[6];
                    h5adPath = dataRoot + "/" + DOWNLOAD_DATA_RELATIVE_PATH + "/mouse/" + gseVal + "/" + gsmVal + "/" + gseVal + "_" + gsmVal + ".h5ad";
                    found = true;
                    break;
                }
            }
            csvReader.close();
        }

        if (!found) {
            out.println("<h2 style='color:red;'>Error: SAID '" + saidParam + "' not found in database.</h2>");
            return;
        }
    } catch (Exception e) {
        out.println("<h2 style='color:red;'>Error loading CSV: " + e.getMessage() + "</h2>");
        return;
    } finally {
        if (csvReader != null) try { csvReader.close(); } catch (Exception ignore) {}
    }
    }

    // =========================================================================
    // Server-side render of GEO study metadata (static per SAID) so the
    // Experimental Design panel does not depend on an AJAX call into geo_meta.
    // =========================================================================
    String geoTitle = "";
    String geoSummary = "";
    String geoDesign = "";
    java.util.List<String> geoPubmedIds = new java.util.ArrayList<String>();
    try {
        File gseMetaFile = new File(dataRoot, "gse_metadata.json");
        if (gseMetaFile.exists() && gseVal != null && !gseVal.isEmpty()) {
            com.google.gson.JsonObject all = com.google.gson.JsonParser
                    .parseReader(new java.io.FileReader(gseMetaFile))
                    .getAsJsonObject();
            if (all.has(gseVal)) {
                com.google.gson.JsonObject g = all.getAsJsonObject(gseVal);
                if (g.has("title") && !g.get("title").isJsonNull()) geoTitle = g.get("title").getAsString();
                if (g.has("summary") && !g.get("summary").isJsonNull()) geoSummary = g.get("summary").getAsString();
                if (g.has("overall_design") && !g.get("overall_design").isJsonNull()) geoDesign = g.get("overall_design").getAsString();
                if (g.has("pubmed_ids") && g.get("pubmed_ids").isJsonArray()) {
                    for (com.google.gson.JsonElement e : g.getAsJsonArray("pubmed_ids")) {
                        if (!e.isJsonNull()) geoPubmedIds.add(e.getAsString());
                    }
                }
            }
        }
    } catch (Exception e) {
        // Leave fields blank on any parse/IO issue — the panel will show an empty-state.
    }

    // Suppress browser/proxy caching of the JSP response so CDN -> local lib
    // migration is picked up immediately without Cmd+Shift+R.
    response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
    response.setHeader("Pragma", "no-cache");
    response.setHeader("Expires", "0");
%>

<!DOCTYPE html>
<%
    // ---- SEO: per-SAID meta + JSON-LD ------------------------------------
    // Build a compact "search snippet" from the (cleaned) curator metadata
    // plus the GEO study description; capped so Google treats it as a normal
    // meta description. Single-line, HTML-escaped.
    String pageTitle = saidVal + " — " + speciesVal + " " + conditionVal
            + " " + tissueVal + " | scSAID";
    StringBuilder sbMeta = new StringBuilder();
    sbMeta.append(speciesVal).append(" ")
          .append(conditionVal).append(" scRNA-seq dataset (")
          .append(n_cellsVal).append(" cells, ")
          .append(tissueVal).append(") from ")
          .append(gseVal).append("/").append(gsmVal)
          .append(". ");
    if (geoTitle != null && !geoTitle.isEmpty()) {
        sbMeta.append(geoTitle).append(". ");
    }
    if (geoSummary != null && !geoSummary.isEmpty()) {
        sbMeta.append(geoSummary);
    }
    String metaDesc = sbMeta.toString().replace('\n',' ').replace('\r',' ');
    if (metaDesc.length() > 300) metaDesc = metaDesc.substring(0, 297) + "...";
    String metaDescHtml = metaDesc.replace("&","&amp;").replace("<","&lt;")
                                  .replace(">","&gt;").replace("\"","&quot;");

    String canonUrl = "https://skin-scsaid.com/details.jsp?said=" + saidVal;

    // Build JSON-LD Dataset schema for this specific SAID.
    StringBuilder sbJ = new StringBuilder();
    sbJ.append("{");
    sbJ.append("\"@context\":\"https://schema.org/\",");
    sbJ.append("\"@type\":\"Dataset\",");
    sbJ.append("\"name\":\"").append(jsonEscape(pageTitle)).append("\",");
    sbJ.append("\"alternateName\":\"").append(jsonEscape(saidVal)).append("\",");
    sbJ.append("\"identifier\":\"").append(jsonEscape(saidVal)).append("\",");
    sbJ.append("\"url\":\"").append(canonUrl).append("\",");
    sbJ.append("\"description\":\"").append(jsonEscape(metaDesc)).append("\",");
    sbJ.append("\"keywords\":[\"scRNA-seq\",\"single-cell RNA-seq\",\"")
       .append(jsonEscape(speciesVal.toLowerCase())).append(" skin\",\"")
       .append(jsonEscape(conditionVal)).append("\",\"")
       .append(jsonEscape(tissueVal)).append("\",\"scSAID\"],");
    sbJ.append("\"isAccessibleForFree\":true,");
    sbJ.append("\"license\":\"https://creativecommons.org/licenses/by/4.0/\",");
    sbJ.append("\"measurementTechnique\":\"single-cell RNA sequencing\",");
    sbJ.append("\"variableMeasured\":[\"gene expression\",\"cell type annotation\"],");
    sbJ.append("\"creator\":{\"@type\":\"Organization\",\"name\":\"ZJU-UoE Joint Institute\",\"url\":\"https://zje.zju.edu.cn/\"},");
    sbJ.append("\"includedInDataCatalog\":{\"@type\":\"DataCatalog\",\"name\":\"scSAID\",\"url\":\"https://skin-scsaid.com/\"},");
    if (gseVal != null && gseVal.startsWith("GSE")) {
        sbJ.append("\"isBasedOn\":\"https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=")
           .append(gseVal).append("\",");
    }
    if (!geoPubmedIds.isEmpty()) {
        sbJ.append("\"citation\":[");
        for (int i = 0; i < geoPubmedIds.size(); i++) {
            if (i > 0) sbJ.append(",");
            sbJ.append("\"https://pubmed.ncbi.nlm.nih.gov/")
               .append(geoPubmedIds.get(i)).append("/\"");
        }
        sbJ.append("],");
    }
    sbJ.append("\"spatialCoverage\":{\"@type\":\"Place\",\"name\":\"")
       .append(jsonEscape(speciesVal)).append(" ").append(jsonEscape(tissueVal)).append("\"}");
    sbJ.append("}");
    String jsonLd = sbJ.toString();
%>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <!-- Favicons / PWA icons -->
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
    <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16.png">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png">
    <link rel="icon" type="image/png" sizes="192x192" href="/images/favicon-192.png">
    <link rel="icon" type="image/png" sizes="512x512" href="/images/favicon-512.png">
    <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png">
    <link rel="manifest" href="/site.webmanifest">
    <meta name="theme-color" content="#333333">
    <title><%= pageTitle.replace("<","&lt;").replace(">","&gt;") %></title>

    <!-- SEO: per-SAID meta tags + JSON-LD Dataset schema -->
    <meta name="description" content="<%= metaDescHtml %>">
    <meta name="keywords" content="scSAID, <%= saidVal %>, <%= gseVal %>, <%= gsmVal %>, <%= speciesVal %> scRNA-seq, <%= conditionVal %>, <%= tissueVal %>, skin atlas, single-cell">
    <meta name="robots" content="index,follow,max-image-preview:large">
    <link rel="canonical" href="<%= canonUrl %>">

    <meta property="og:type" content="website">
    <meta property="og:site_name" content="scSAID">
    <meta property="og:title" content="<%= (saidVal + " — " + speciesVal + " " + conditionVal + " (" + tissueVal + ")").replace("\"","&quot;") %>">
    <meta property="og:description" content="<%= metaDescHtml %>">
    <meta property="og:url" content="<%= canonUrl %>">

    <script type="application/ld+json"><%= jsonLd %></script>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">

    <!-- Stylesheets -->
    <link rel="stylesheet" href="CSS/design-system.css?v=20260702c">
    <link rel="stylesheet" href="CSS/header.css?v=20260701h">
    <link rel="stylesheet" href="CSS/details.css?v=20260701h">
    <link rel="stylesheet" href="lib/css/jquery.dataTables.min.css?v=20260416">

    <!-- Scripts (served from local lib/; ?v= busts any cached CDN-pointing copy) -->
    <script src="lib/jquery-3.7.1.min.js?v=20260416"></script>
    <script src="lib/jquery.dataTables.min.js?v=20260416"></script>
    <script src="lib/xlsx.full.min.js?v=20260416"></script>
    <script src="lib/plotly-2.20.0.min.js?v=20260416"></script>
    <!-- Publication-quality figure download (high-res PNG / vector PDF) -->
    <script src="lib/jspdf.umd.min.js?v=20260630"></script>
    <script src="lib/svg2pdf.umd.min.js?v=20260630"></script>
    <script src="JS/figure-export.js?v=<%= System.currentTimeMillis() %>"></script>
</head>
<body style="background: var(--bg-body);">

<%@ include file="includes/header.jsp" %>
<div class="details-box" id="main-content" tabindex="-1">

    <!-- Dataset Hero — editorial header that carries the homepage language
         (dark navy, gold eyebrow, serif title, JetBrains-Mono meta chips). -->
    <section class="dataset-hero" id="ExperimentInformation">
        <div class="dataset-hero__inner">
            <div class="dataset-hero__eyebrow">
                <span>Dataset</span>
                <code><%= saidVal %></code>
            </div>
            <h1 class="dataset-hero__title"><%
                    StringBuilder heroTitle = new StringBuilder();
                    heroTitle.append(speciesVal);
                    if (conditionVal != null && !conditionVal.isEmpty()) heroTitle.append(" · ").append(conditionVal);
                    if (tissueVal   != null && !tissueVal.isEmpty()  && !"NA".equalsIgnoreCase(tissueVal)) heroTitle.append(" — ").append(tissueVal);
                %><%= heroTitle.toString().replace("<","&lt;").replace(">","&gt;") %></h1>
            <p class="dataset-hero__subtitle">
                <% if (!geoTitle.isEmpty()) { %>
                    <%= geoTitle.replace("<","&lt;").replace(">","&gt;") %>
                <% } else { %>
                    Single-cell RNA-seq dataset catalogued in scSAID under accession <%= gseVal %> / <%= gsmVal %>.
                <% } %>
            </p>
            <div class="dataset-hero__meta">
                <div class="dataset-hero__meta-item">
                    <span class="dataset-hero__meta-label">Cells</span>
                    <span class="dataset-hero__meta-value dataset-hero__meta-value--large"><%= (n_cellsVal == null || n_cellsVal.isEmpty()) ? "—" : n_cellsVal %></span>
                </div>
                <div class="dataset-hero__meta-item">
                    <span class="dataset-hero__meta-label">GSE</span>
                    <span class="dataset-hero__meta-value"><%= gseVal %></span>
                </div>
                <div class="dataset-hero__meta-item">
                    <span class="dataset-hero__meta-label">GSM</span>
                    <span class="dataset-hero__meta-value"><%= gsmVal %></span>
                </div>
                <div class="dataset-hero__meta-item">
                    <span class="dataset-hero__meta-label">Species</span>
                    <span class="dataset-hero__meta-value"><%= speciesVal %></span>
                </div>
                <div class="dataset-hero__meta-item">
                    <span class="dataset-hero__meta-label">Tissue</span>
                    <span class="dataset-hero__meta-value"><%= (tissueVal == null || tissueVal.isEmpty()) ? "—" : tissueVal %></span>
                </div>
                <div class="dataset-hero__meta-item">
                    <span class="dataset-hero__meta-label">Condition</span>
                    <span class="dataset-hero__meta-value"><%= (conditionVal == null || conditionVal.isEmpty()) ? "—" : conditionVal %></span>
                </div>
                <div class="dataset-hero__meta-item">
                    <span class="dataset-hero__meta-label">Age</span>
                    <span class="dataset-hero__meta-value"><%= (ageVal == null || ageVal.isEmpty()) ? "—" : ageVal %></span>
                </div>
                <div class="dataset-hero__meta-item">
                    <span class="dataset-hero__meta-label">Sex</span>
                    <span class="dataset-hero__meta-value"><%= (sexVal == null || sexVal.isEmpty()) ? "—" : sexVal %></span>
                </div>
            </div>
        </div>
    </section>

    <!-- Sidebar Navigation -->
    <aside class="sidebar">
        <p class="sidebar__title">Analyses</p>
        <nav class="sidebar__nav">
            <a href="#ExperimentInformation" class="nav-item active">
                <svg class="nav-item__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="10"></circle>
                    <path d="M12 16v-4M12 8h.01"></path>
                </svg>
                Overview
            </a>
            <a href="#CellProportion" class="nav-item">
                <svg class="nav-item__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="10"></circle><path d="M12 2a10 10 0 0 1 0 20"></path><line x1="12" y1="2" x2="12" y2="22"></line>
                </svg>
                Cell Proportion
            </a>
            <a href="#CellClustering" class="nav-item">
                <svg class="nav-item__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="7" cy="8" r="2.5" fill="currentColor" opacity="0.3"></circle><circle cx="16" cy="6" r="2" fill="currentColor" opacity="0.3"></circle><circle cx="12" cy="14" r="3" fill="currentColor" opacity="0.3"></circle><circle cx="5" cy="17" r="1.5" fill="currentColor" opacity="0.3"></circle><circle cx="19" cy="15" r="2" fill="currentColor" opacity="0.3"></circle>
                </svg>
                Cell Clustering
            </a>
            <a href="#DEGResults" class="nav-item">
                <svg class="nav-item__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="3" y="3" width="18" height="18" rx="2"></rect><line x1="3" y1="9" x2="21" y2="9"></line><line x1="3" y1="15" x2="21" y2="15"></line><line x1="9" y1="3" x2="9" y2="21"></line>
                </svg>
                DEG Results
            </a>
            <a href="#GeneSetScoring" class="nav-item">
                <svg class="nav-item__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="3" y="12" width="4" height="9" rx="1"></rect><rect x="10" y="7" width="4" height="14" rx="1"></rect><rect x="17" y="3" width="4" height="18" rx="1"></rect>
                </svg>
                Gene Set Scoring
            </a>
            <a href="#CellPhoneDBAnalysis" class="nav-item">
                <svg class="nav-item__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="5" cy="6" r="2"></circle><circle cx="19" cy="6" r="2"></circle><circle cx="12" cy="18" r="2"></circle><line x1="5" y1="8" x2="12" y2="16"></line><line x1="19" y1="8" x2="12" y2="16"></line><line x1="7" y1="6" x2="17" y2="6"></line>
                </svg>
                Cell-Cell Communication
            </a>
            <a href="#EnrichmentAnalysis" class="nav-item">
                <svg class="nav-item__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M21 12a9 9 0 1 1-9-9"></path><path d="M21 3v9h-9"></path>
                </svg>
                Enrichment Analysis
            </a>
            <a href="#RegulatoryNetwork" class="nav-item">
                <svg class="nav-item__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="5" r="2"></circle><circle cx="5" cy="16" r="2"></circle><circle cx="12" cy="16" r="2"></circle><circle cx="19" cy="16" r="2"></circle><line x1="12" y1="7" x2="12" y2="14"></line><line x1="12" y1="7" x2="5" y2="14"></line><line x1="12" y1="7" x2="19" y2="14"></line>
                </svg>
                Regulatory Network
            </a>
        </nav>
    </aside>

    <div class="basic">
        <!-- Study brief: GEO study context, when available. -->
        <% if (!geoTitle.isEmpty() || !geoSummary.isEmpty() || !geoDesign.isEmpty() || !geoPubmedIds.isEmpty()) { %>
        <section class="study-brief" aria-label="Experimental design">
            <% if (!geoTitle.isEmpty()) { %>
            <div class="study-brief__item">
                <span class="study-brief__label">Study</span>
                <div class="study-brief__value study-brief__value--title"><%= geoTitle.replace("<","&lt;").replace(">","&gt;") %></div>
            </div>
            <% } %>
            <% if (!geoSummary.isEmpty()) { %>
            <div class="study-brief__item">
                <span class="study-brief__label">Summary</span>
                <div class="study-brief__value"><%= geoSummary.replace("<","&lt;").replace(">","&gt;") %></div>
            </div>
            <% } %>
            <% if (!geoDesign.isEmpty()) { %>
            <div class="study-brief__item">
                <span class="study-brief__label">Overall Design</span>
                <div class="study-brief__value"><%= geoDesign.replace("<","&lt;").replace(">","&gt;") %></div>
            </div>
            <% } %>
            <% if (!geoPubmedIds.isEmpty()) { %>
            <div class="study-brief__item">
                <span class="study-brief__label">PubMed</span>
                <div class="study-brief__value">
                    <% for (int i = 0; i < geoPubmedIds.size(); i++) {
                        String pmid = geoPubmedIds.get(i);
                    %><%= i > 0 ? " · " : "" %><a href="https://pubmed.ncbi.nlm.nih.gov/<%= pmid %>/" target="_blank" rel="noopener">PMID: <%= pmid %></a><% } %>
                </div>
            </div>
            <% } %>
        </section>
        <% } %>
        <div class="cluster" id="CellProportion">
            <div class="header">
                <div class="header-content">
                    <div>
                        <div class="header-title title-with-help">
                            <button type="button" class="analysis-help" aria-label="About cell proportion" aria-describedby="help-cell-proportion" aria-expanded="false" data-help-target="help-cell-proportion">Cell Proportion</button>
                        </div>
                        <span id="help-cell-proportion" class="visually-hidden">Cell counts and relative abundance across the selected annotation level, shown as bar and composition charts.</span>
                    </div>
                    <div class="umap-controls control-row" style="align-items:center; gap:12px;">
                        <label class="panel-label" style="margin:0;">Annotation</label>
                        <select id="proportionMapType" class="form-select elegant-select proportion-map-select">
                            <option value="Gross_Map" selected>Gross Map</option>
                            <option value="Fine_Map">Fine Map</option>
                        </select>
                    </div>
                </div>
            </div>
            <div class="panel-body" style="padding:1.5rem;">
                <div id="proportion-loading" class="panel-loader" role="status" aria-label="Loading"></div>
                <div id="proportion-error" class="status-error" style="display:none;"></div>
                <div id="proportion-charts" style="display:none;">
                    <div class="proportion-charts-layout">
                        <div class="proportion-chart proportion-chart--bar">
                            <div id="proportionBarChart"></div>
                        </div>
                        <div class="proportion-chart proportion-chart--donut">
                            <div id="proportionDonutChart"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="CellClustering" id="CellClustering">
            <div class="cluster">
                <div class="header">
                    <div class="header-content">
                        <div>
                            <div class="header-title title-with-help">
                                <button type="button" class="analysis-help" aria-label="About cell clustering" aria-describedby="help-cell-clustering" aria-expanded="false" data-help-target="help-cell-clustering">Cell Clustering</button>
                            </div>
                            <span id="help-cell-clustering" class="visually-hidden">UMAP embedding of this sample. Color by available cell annotations or metadata fields.</span>
                        </div>
                        <div class="umap-controls control-row" style="align-items:center; gap:12px;">
                            <label class="panel-label" style="margin:0;">Color by</label>
                            <select id="umapColorBy" class="form-select elegant-select" style="min-width:160px;">
                                <option value="">—</option>
                            </select>
                            <button id="downloadUmapPdf" class="export-btn btn-ghost" title="Download PDF">
                                <svg class="export-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                                    <polyline points="7 10 12 15 17 10"></polyline>
                                    <line x1="12" y1="15" x2="12" y2="3"></line>
                                </svg>
                                PDF
                            </button>
                        </div>
                    </div>
                </div>
                <div id="umap-container">
                    <div id="umap-loading" class="panel-loader" role="status" aria-label="Loading"></div>
                    <img id="umap-image" src="" alt="UMAP plot" style="display:none; max-width:100%; height:auto;">
                </div>
            </div>

            <div class="cluster" id="DEGResults">
                <div class="header">
                    <div class="header-content">
                        <div>
                            <div class="header-title title-with-help">
                                <button type="button" class="analysis-help" aria-label="About differentially expressed genes" aria-describedby="help-deg" aria-expanded="false" data-help-target="help-deg">Differentially Expressed Genes</button>
                            </div>
                            <span id="help-deg" class="visually-hidden">Cluster-marker results for this sample, or an on-demand comparison against another sample. Use the controls to filter by adjusted p-value, effect size, cell type, and pseudogene status.</span>
                        </div>
                        <button id="exportExcelBtn" class="export-btn btn-ghost">
                            <svg class="export-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                                <polyline points="7 10 12 15 17 10"></polyline>
                                <line x1="12" y1="15" x2="12" y2="3"></line>
                            </svg>
                            Export Excel
                        </button>
                    </div>
                </div>
                <div class="panel-body section-stack">
                    <div class="comparison-bar control-row">
                        <div class="control-group control-group--wide">
                            <label class="panel-label" for="degCompareSelect">Compare with</label>
                            <select id="degCompareSelect" class="form-select elegant-select">
                                <option value="">— No comparison (cluster vs rest of this sample)</option>
                            </select>
                        </div>
                        <div class="control-group" style="flex:0 0 auto;">
                            <label class="panel-label">&nbsp;</label>
                            <button id="degRunCompareBtn" class="btn-primary" disabled>Run comparison</button>
                        </div>
                    </div>
                    <div id="degCompareStatus" class="info-bar" style="display:none;"></div>
                    <div id="degProgress" class="panel-loader" role="status" aria-label="Loading" style="display:none;"></div>
                    <div id="degError" class="status-error" style="display:none;"></div>
                    <div class="deg-controls">
                        <div class="filter-grid">
                            <div class="filter-card">
                                <div class="filter-label">
                                    <span class="filter-name label-with-help">
                                        <button type="button" class="analysis-help" aria-label="About the p-value threshold" aria-describedby="help-deg-pvalue" aria-expanded="false" data-help-target="help-deg-pvalue">p-value threshold</button>
                                    </span>
                                    <span class="filter-value" id="pvalLabel">0.05</span>
                                </div>
                                <input type="range" id="pvalSlider" class="elegant-slider" min="0" max="0.1" step="0.001" value="0.05">
                                <span id="help-deg-pvalue" class="visually-hidden">Maximum adjusted p-value retained in the DEG table.</span>
                            </div>
                            <div class="filter-card">
                                <div class="filter-label">
                                    <span class="filter-name label-with-help">
                                        <button type="button" class="analysis-help" aria-label="About the log fold-change threshold" aria-describedby="help-deg-logfc" aria-expanded="false" data-help-target="help-deg-logfc">Log fold change</button>
                                    </span>
                                    <span class="filter-value" id="fcLabel">1.0</span>
                                </div>
                                <input type="range" id="fcSlider" class="elegant-slider" min="0" max="10" step="0.1" value="1.0">
                                <span id="help-deg-logfc" class="visually-hidden">Minimum log2 fold change retained in the DEG table.</span>
                            </div>
                            <div class="filter-card">
                                <div class="filter-label">
                                    <span class="filter-name">Cell type</span>
                                </div>
                                <select id="cellTypeSelect" class="elegant-select">
                                    <option value="">All cell types</option>
                                </select>
                            </div>
                            <div class="filter-card">
                                <div class="filter-label">
                                    <span class="filter-name label-with-help">
                                        <button type="button" class="analysis-help" aria-label="About the pseudogene filter" aria-describedby="help-deg-pseudogenes" aria-expanded="false" data-help-target="help-deg-pseudogenes">Pseudogenes</button>
                                    </span>
                                </div>
                                <label class="checkbox-item" style="padding-top:0.25rem;">
                                    <input type="checkbox" id="hidePseudogenes" checked>
                                    <span class="checkbox-item__text">Hide pseudogenes</span>
                                </label>
                                <span id="help-deg-pseudogenes" class="visually-hidden">Filters common mouse pseudogene naming patterns, including Gm-numbered genes, -ps, Rik, and Pn suffixes.</span>
                            </div>
                        </div>
                    </div>
                    <div class="table-wrapper">
                        <table id="degTable" class="elegant-table" style="width:100%">
                            <thead>
                                <tr>
                                    <th>Gene</th>
                                    <th>logFC</th>
                                    <th>p-value</th>
                                    <th>Score</th>
                                    <th>Cell type</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>

            <div class="cluster" id="GeneSetScoring">
                <div class="header">
                    <div class="header-content">
                        <div>
                            <div class="header-title title-with-help">
                                <button type="button" class="analysis-help" aria-label="About gene set scoring" aria-describedby="help-gene-set-scoring" aria-expanded="false" data-help-target="help-gene-set-scoring">Gene Set Scoring</button>
                            </div>
                            <span id="help-gene-set-scoring" class="visually-hidden">Score a custom, MSigDB, or uploaded GMT gene set across cells and summarize scores by the selected annotation using AUCell, Scanpy score_genes, UCell, ssGSEA, or GSVA.</span>
                        </div>
                    </div>
                </div>
                <div class="panel-body" style="padding:1.5rem;">
                    <!-- Gene Set Input Mode Tabs -->
                    <div class="tab-bar" style="margin-bottom:1rem;">
                        <button class="gss-input-tab tab-btn active" data-mode="custom">Custom Genes</button>
                        <button class="gss-input-tab tab-btn" data-mode="msigdb">MSigDB Library</button>
                        <button class="gss-input-tab tab-btn" data-mode="upload">Upload GMT</button>
                    </div>

                    <!-- Mode 1: Custom gene list (original) -->
                    <div id="gssCustomPanel" class="gss-input-panel">
                        <div class="control-group" style="min-width:0; margin-bottom:1rem;">
                            <label class="panel-label">Gene Set (comma-separated)</label>
                            <textarea id="gssGeneInput" class="form-textarea" rows="2" placeholder="e.g. COL1A1, COL1A2, COL3A1, FN1, VIM, ACTA2"></textarea>
                        </div>
                    </div>

                    <!-- Mode 2: MSigDB predefined gene sets -->
                    <div id="gssMsigdbPanel" class="gss-input-panel" style="display:none;">
                        <div class="control-row" style="margin-bottom:0.8rem;">
                            <div class="control-group control-group--library">
                                <label class="panel-label">Library</label>
                                <select id="gssLibrary" class="form-select">
                                    <option value="">—</option>
                                </select>
                            </div>
                            <div class="control-group" style="flex:1; min-width:250px;">
                                <label class="panel-label">Search Gene Sets</label>
                                <input type="text" id="gssSetSearch" class="form-input" placeholder="Type to search (e.g. apoptosis, WNT, MAPK)...">
                            </div>
                        </div>
                        <div id="gssSetList" class="list-panel" style="max-height:200px; padding:4px 0;">
                            <div class="help-text" style="padding:12px;">Select a library to browse gene sets</div>
                        </div>
                        <div id="gssSelectedSetInfo" class="info-bar" style="display:none; margin-top:0.5rem;">
                        </div>
                    </div>

                    <!-- Mode 3: Upload GMT file -->
                    <div id="gssUploadPanel" class="gss-input-panel" style="display:none;">
                        <div id="gssDropZone" class="drop-zone" style="margin-bottom:0.8rem;">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" style="width:36px; height:36px; margin-bottom:0.5rem; color:var(--ink-mute);"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="17 8 12 3 7 8"></polyline><line x1="12" y1="3" x2="12" y2="15"></line></svg>
                            <div style="font-family:'Nunito', sans-serif; font-size:0.9rem; color:var(--ink-soft);">
                                Drag & drop a <strong>.gmt</strong> file here, or
                                <label class="action-link" style="cursor:pointer; text-decoration:underline;">browse<input type="file" id="gssFileInput" accept=".gmt,.txt" style="display:none;"></label>
                                <button type="button" class="analysis-help analysis-help--inline" aria-label="About GMT file format" aria-describedby="help-gmt-format" aria-expanded="false" data-help-target="help-gmt-format">GMT format</button>
                            </div>
                            <span id="help-gmt-format" class="visually-hidden">GMT rows contain a set name, description, and gene symbols separated by tabs.</span>
                        </div>
                        <div id="gssUploadResult" style="display:none;">
                            <div id="gssSpeciesWarning" style="display:none; padding:0.6rem 0.8rem; background:#fff8e1; border:1px solid #ffe082; border-radius:var(--radius-sm); font-family:'Nunito', sans-serif; font-size:0.82rem; color:#8d6e00; margin-bottom:0.5rem;">
                                <strong>&#9888; Species mismatch:</strong> <span id="gssSpeciesWarningText"></span>
                            </div>
                            <div id="gssUploadSetList" class="list-panel" style="max-height:180px; padding:4px 0;"></div>
                            <div id="gssUploadSelectedInfo" class="info-bar" style="display:none; margin-top:0.5rem;"></div>
                        </div>
                    </div>

                    <!-- Controls row: Group By, Method, Run button -->
                    <div class="control-row" style="margin:1rem 0;">
                        <div class="control-group">
                            <label class="panel-label">Group By</label>
                            <select id="gssGroupBy" class="form-select">
                                <option value="Fine_Map">Fine_Map</option>
                                <option value="Gross_Map">Gross_Map</option>
                            </select>
                        </div>
                        <div class="control-group">
                            <label class="panel-label">Method</label>
                            <select id="gssMethod" class="form-select">
                                <option value="aucell" selected>AUCell</option>
                                <option value="scanpy">Scanpy score_genes</option>
                                <option value="ucell">UCell</option>
                                <option value="ssgsea">ssGSEA</option>
                                <option value="gsva">GSVA</option>
                            </select>
                        </div>
                        <button id="gssRunBtn" class="btn-primary">
                            Run Scoring
                        </button>
                    </div>
                    <div id="gssGeneInfo" class="help-text" style="margin-bottom:1rem; display:none;"></div>
                    <div id="gssProgress" class="panel-loader" role="status" aria-label="Loading" style="display:none;"></div>
                    <div id="gssError" class="status-error" style="display:none; margin-bottom:1rem;"></div>
                    <div id="gssViolinPlot" style="min-height:200px;"></div>
                </div>
            </div>

            <div class="cluster" id="CellPhoneDBAnalysis">
                <div class="header">
                    <div class="header-content">
                        <div>
                            <div class="header-title title-with-help">
                                <button type="button" class="analysis-help" aria-label="About CellPhoneDB communication analysis" aria-describedby="help-cellphonedb" aria-expanded="false" data-help-target="help-cellphonedb">CellPhoneDB Cell-Cell Communication Analysis</button>
                            </div>
                            <span id="help-cellphonedb" class="visually-hidden">CellPhoneDB ligand-receptor inference across selected cell types. Analyze all selected combinations or define directed sender and receiver groups at fine or broad annotation resolution.</span>
                        </div>
                    </div>
                </div>
                <div class="panel-body">
                    <!-- Cell Type Selection -->
                    <div class="cpdb-config-section">
                        <div class="control-row" style="gap:16px; margin-bottom:12px;">
                            <h3 class="cpdb-section-title">Cell-Cell Communication</h3>
                            <div class="cpdb-mode-toggle">
                                <label class="cpdb-radio">
                                    <input type="radio" name="cpdbMode" value="all" checked>
                                    <span>All Combinations</span>
                                </label>
                                <label class="cpdb-radio">
                                    <input type="radio" name="cpdbMode" value="directed">
                                    <span>Sender → Receiver</span>
                                </label>
                            </div>
                        </div>

                        <!-- Annotation-granularity toggle (Fine_Map / Gross_Map) -->
                        <div class="control-row" style="gap:16px; margin-bottom:12px; align-items:center;">
                            <label class="panel-label" style="margin:0;">Annotation level</label>
                            <div class="cpdb-mode-toggle">
                                <label class="cpdb-radio">
                                    <input type="radio" name="cpdbLevel" value="fine" checked>
                                    <span>Fine_Map (fine-grained)</span>
                                </label>
                                <label class="cpdb-radio">
                                    <input type="radio" name="cpdbLevel" value="gross">
                                    <span>Gross_Map (broad)</span>
                                </label>
                            </div>
                        </div>

                        <!-- All Combinations mode: single checkbox list -->
                        <div id="cpdbAllControls">
                            <p class="cpdb-section-desc">Select 2 or more cell types to analyze ligand-receptor interactions</p>
                            <div id="cpdbCellTypeList" class="list-panel" style="max-height:300px;">
                                <div class="panel-loader" role="status" aria-label="Loading"></div>
                            </div>
                            <div class="help-text" style="margin-top:6px;">
                                <span id="cpdbSelectedCount">0</span> cell types selected
                                <a href="javascript:void(0)" id="cpdbSelectAll" class="action-link" style="margin-left:12px;">Select All</a>
                                <a href="javascript:void(0)" id="cpdbClearAll" class="action-link action-link--danger" style="margin-left:8px;">Clear</a>
                            </div>
                        </div>

                        <!-- Sender/Receiver mode: two checkbox lists side by side -->
                        <div id="cpdbDirectedControls" style="display:none;">
                            <p class="cpdb-section-desc">Assign cell types as senders (left) and receivers (right)</p>
                            <div class="control-row" style="align-items:stretch; gap:16px;">
                                <div class="control-group" style="flex:1; min-width:0;">
                                    <label class="panel-label">Sender Cell Types</label>
                                    <div id="cpdbSenderList" class="list-panel" style="max-height:280px;">
                                    </div>
                                    <div class="help-text"><span id="cpdbSenderCount">0</span> selected</div>
                                </div>
                                <div class="arrow-separator">→</div>
                                <div class="control-group" style="flex:1; min-width:0;">
                                    <label class="panel-label">Receiver Cell Types</label>
                                    <div id="cpdbReceiverList" class="list-panel" style="max-height:280px;">
                                    </div>
                                    <div class="help-text"><span id="cpdbReceiverCount">0</span> selected</div>
                                </div>
                            </div>
                        </div>

                        <button id="runCpdbAnalysisBtn" class="btn-primary" style="margin-top:1rem;">
                            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <polygon points="5 3 19 12 5 21 5 3"></polygon>
                            </svg>
                            Run Analysis
                        </button>
                    </div>

                    <!-- Progress Section -->
                    <div id="cpdbProgressSection" class="cpdb-progress panel-loader" role="status" aria-label="Loading" style="display:none;"></div>

                    <!-- Results Section -->
                    <div id="cpdbResultsSection" style="display:none;">
                        <div class="cpdb-results-tabs">
                            <button class="cpdb-tab tab-btn active" data-tab="heatmap">Interaction Heatmap</button>
                            <button class="cpdb-tab tab-btn" data-tab="dotplot">Dot Plot</button>
                            <button class="cpdb-tab tab-btn" data-tab="table">Results Table</button>
                        </div>

                        <div id="cpdbHeatmapTab" class="cpdb-tab-content active">
                            <div id="cpdbHeatmapPlot" class="cpdb-plot-container"></div>
                        </div>

                        <div id="cpdbDotplotTab" class="cpdb-tab-content">
                            <div id="cpdbDotplot" class="cpdb-plot-container"></div>
                        </div>

                        <div id="cpdbTableTab" class="cpdb-tab-content">
                            <div class="cpdb-table-toolbar" style="display:flex; justify-content:flex-end; align-items:center; margin-bottom:0.75rem;">
                                <button id="cpdbExportExcelBtn" class="export-btn btn-ghost" disabled>
                                    <svg class="export-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                                        <polyline points="7 10 12 15 17 10"></polyline>
                                        <line x1="12" y1="15" x2="12" y2="3"></line>
                                    </svg>
                                    Export Excel
                                </button>
                            </div>
                            <div class="table-wrapper">
                                <table id="cpdbResultsTable" class="elegant-table">
                                    <thead>
                                        <tr>
                                            <th>Interaction Pair</th>
                                            <th>Sender</th>
                                            <th>Receiver</th>
                                            <th>Mean Expression</th>
                                            <th>P-value</th>
                                        </tr>
                                    </thead>
                                    <tbody></tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

            <div class="cluster" id="EnrichmentAnalysis">
                <div class="header">
                    <div class="header-content">
                        <div>
                            <div class="header-title title-with-help">
                                <button type="button" class="analysis-help" aria-label="About enrichment analysis" aria-describedby="help-enrichment" aria-expanded="false" data-help-target="help-enrichment">Enrichment Analysis</button>
                            </div>
                            <div id="help-enrichment" class="visually-hidden">
                                <span id="enrichSource">Source: cluster markers of this sample.</span>
                                GSEA ranks the complete gene list and tests whether a pathway is shifted toward either end. ORA tests whether significantly up-regulated markers with adjusted p below 0.05 and log2 fold change at least 1 over-represent a pathway using a hypergeometric test.
                            </div>
                        </div>
                    </div>
                </div>
                <div class="panel-body">
                    <div class="control-row toolbar-row" style="margin-bottom:0.5rem;">
                        <div class="control-group" style="min-width:170px;">
                            <label class="panel-label">Method</label>
                            <select id="enrichMethod" class="form-select elegant-select">
                                <option value="gsea" selected>GSEA (ranked)</option>
                                <option value="ora">ORA (over-representation)</option>
                            </select>
                        </div>
                        <div class="control-group" style="min-width:220px;">
                            <label class="panel-label">Gene Set</label>
                            <select id="enrichGeneSet" class="form-select elegant-select">
                                <option value="">—</option>
                            </select>
                        </div>
                        <div class="control-group" style="min-width:180px; display:none;" id="enrichCellTypeWrap">
                            <label class="panel-label">Cell type</label>
                            <select id="enrichCellTypeSelect" class="form-select elegant-select">
                                <option value="">All</option>
                            </select>
                        </div>
                        <div class="control-group" style="min-width:80px;">
                            <label class="panel-label">Top</label>
                            <select id="enrichTopN" class="form-select elegant-select">
                                <option value="10" selected>10</option>
                                <option value="20">20</option>
                                <option value="30">30</option>
                            </select>
                        </div>
                        <div class="control-group">
                            <label class="panel-label">Filter</label>
                            <select id="enrichFilter" class="form-select elegant-select">
                                <option value="all" selected>All results</option>
                                <option value="significant">Significant only</option>
                            </select>
                        </div>
                    </div>
                    <div id="enrich-loading" class="panel-loader" role="status" aria-label="Loading" style="display:none;"></div>
                    <div id="enrich-empty" class="progress-box" style="display:none;">
                        No enrichment data available for this dataset.
                    </div>
                    <div id="enrichChart"></div>
                </div>
            </div>

            <div class="cluster" id="RegulatoryNetwork">
                <div class="header">
                    <div class="header-content">
                        <div>
                            <div class="header-title title-with-help">
                                <button type="button" class="analysis-help" aria-label="About the SCORPION regulatory network" aria-describedby="help-scorpion" aria-expanded="false" data-help-target="help-scorpion">Gene Regulatory Network (SCORPION)</button>
                                <span class="feature-status" aria-label="Beta feature">Beta</span>
                            </div>
                            <div id="help-scorpion" class="visually-hidden">
                                Beta feature. Transcription-factor regulatory network reconstructed with SCORPION using PANDA message passing on the single-cell co-expression network, a CollecTRI regulatory prior, and STRING v12 protein interactions. Regulators are ranked by total network strength; targetome and network views show leading predicted targets. Method: Osorio D. et al., SCORPION, Kuijjer Lab.
                            </div>
                        </div>
                    </div>
                </div>
                <div class="panel-body">
                    <div id="scorpion-loading" class="panel-loader" role="status" aria-label="Loading" style="display:none;"></div>
                    <div id="scorpion-empty" class="progress-box" style="display:none;">
                        The regulatory network for this dataset is being prepared and is not yet available.
                    </div>

                    <div id="scorpionContent" style="display:none;">
                        <div class="control-row toolbar-row" style="margin-bottom:0.5rem;">
                            <div class="control-group" style="min-width:120px;">
                                <label class="panel-label">Top regulators</label>
                                <select id="scorpionTopN" class="form-select elegant-select">
                                    <option value="15">15</option>
                                    <option value="20" selected>20</option>
                                    <option value="30">30</option>
                                </select>
                            </div>
                        </div>
                        <div id="scorpionRegChart"></div>

                        <div class="control-row toolbar-row" style="margin:1.5rem 0 0.5rem;">
                            <div class="control-group" style="min-width:220px;">
                                <label class="panel-label">Targetome of TF</label>
                                <select id="scorpionTfSelect" class="form-select elegant-select"></select>
                            </div>
                        </div>
                        <div id="scorpionTargetChart"></div>

                        <div style="margin-top:1.5rem;">
                            <label class="panel-label">Regulator &rarr; target network (top regulators)</label>
                            <div id="scorpionNetwork"></div>
                        </div>

                    </div>
                </div>
            </div>
        </div>

        <script>
            // Dynamic context path for AJAX requests
            const contextPath = '<%= request.getContextPath() %>';

            $(document).ready(function() {
                document.querySelectorAll('a[href^="#"]').forEach(a => {
                    a.addEventListener('click', function (e) {
                        e.preventDefault();
                        const target = document.querySelector(this.getAttribute('href'));
                        const top = target.getBoundingClientRect().top + window.pageYOffset - 60 - 15;
                        window.scrollTo({ top: top, behavior: 'smooth' });
                    });
                });
                const offset = 120;
                const links  = document.querySelectorAll('.nav-item[href^="#"]');
                const sections = Array.from(links, a => document.querySelector(a.getAttribute('href')))
                    .filter(el => el);

                function highlight() {
                    let curr = '';
                    sections.forEach(sec => {
                        const rect = sec.getBoundingClientRect();
                        if (rect.top <= offset && rect.bottom > offset) curr = sec.id;
                    });
                    links.forEach(link => link.classList.toggle('active', link.getAttribute('href') === '#' + curr));
                }

                window.addEventListener('scroll', highlight);
                highlight();

            })
            $(function(){

                // =========================================================================
                // Original DEG Script
                // =========================================================================
                console.log("🌟 Original script start");
                const table = $('#degTable').DataTable({ paging:true, searching:false, info:true });

                const said = '<%= saidParam %>';
                const gse = '<%= gseVal %>';
                const gsm = '<%= gsmVal %>';

                // Module-scope state for cross-dataset comparison
                var currentComparisonJobId = null;
                var comparisonCellTypes = [];
                var comparisonSaidB = null;
                var comparisonLabelB = null;
                var species = '<%= speciesVal == null ? "" : speciesVal.toLowerCase() %>';
                var legacyJobId = null;
                var legacyCellTypes = [];
                var legacyReady = false;

                function loadCompareOptions() {
                    $.getJSON(contextPath + '/datasets', { species: species, exclude: said })
                        .done(function(data){
                            const select = $('#degCompareSelect');
                            select.find('option:not(:first)').remove();
                            (data || []).forEach(function(d){
                                const label = d.gsm + ' · ' + (d.tissue || '—') + ' · ' + (d.condition || '—');
                                select.append('<option value="' + d.said + '" data-label="' + label + '">' + label + '</option>');
                            });
                        })
                        .fail(function(xhr){ console.error("Dataset list failed:", xhr.status); });
                }

                function populateCellTypeSelect(types, selectEl) {
                    selectEl.find('option:not(:first)').remove();
                    (types || []).forEach(function(t){
                        selectEl.append('<option value="' + t + '">' + t + '</option>');
                    });
                }

                function initGroupOptions() {
                    // Kick off the per-cell-type DEG job for this sample so the
                    // cell-type dropdown and pval/fc filters have something real
                    // to filter. Cached by sha1(said), so subsequent visits are
                    // instant.
                    legacyReady = false;
                    $('#degProgress').show();
                    $.ajax({
                        url: contextPath + '/deg-per-celltype',
                        method: 'POST',
                        contentType: 'application/json',
                        data: JSON.stringify({ said: said })
                    })
                    .done(function(resp){ pollLegacyStatus(resp.jobId); })
                    .fail(function(xhr){
                        $('#degProgress').hide();
                        $('#degError').show().text('Failed to start DEG job (' + xhr.status + ')');
                    });
                }

                function pollLegacyStatus(jobId) {
                    $.getJSON(contextPath + '/deg-per-celltype/status', { jobId: jobId })
                        .done(function(s){
                            if (s.state === 'done') {
                                legacyJobId = jobId;
                                legacyCellTypes = s.cellTypes || [];
                                legacyReady = true;
                                $('#degProgress').hide();
                                if (!currentComparisonJobId) {
                                    populateCellTypeSelect(legacyCellTypes, $('#cellTypeSelect'));
                                    loadDEG();
                                }
                            } else if (s.state === 'error') {
                                $('#degProgress').hide();
                                $('#degError').show().text('DEG job failed: ' + (s.error || 'unknown'));
                            } else {
                                setTimeout(function(){ pollLegacyStatus(jobId); }, 2000);
                            }
                        })
                        .fail(function(xhr){
                            $('#degProgress').hide();
                            $('#degError').show().text('DEG status poll failed (' + xhr.status + ')');
                        });
                }

                function updateEnrichSource() {
                    var src = $('#enrichSource');
                    if (currentComparisonJobId) {
                        src.html('Source: <strong>' + gsm + ' vs ' + comparisonLabelB + '</strong> (A-vs-B DEG, uncorrected)');
                        $('#enrichCellTypeWrap').show();
                        populateCellTypeSelect(comparisonCellTypes, $('#enrichCellTypeSelect'));
                    } else {
                        src.html('Source: <strong>cluster markers of ' + gsm + '</strong>');
                        $('#enrichCellTypeWrap').hide();
                    }
                    // ORA is only available for the sample-marker source (it reads the per-sample
                    // DEG file); for the comparison-job source, fall back to GSEA.
                    var $m = $('#enrichMethod');
                    $m.find('option[value="ora"]').prop('disabled', !!currentComparisonJobId);
                    if (currentComparisonJobId && $m.val() === 'ora') { $m.val('gsea'); }
                }

                // Conservative name-based pseudogene heuristic (high-precision suffixes only):
                //   Mouse: Gm\d+, -ps\d*, Rik suffix
                //   Both:  -PS\d* suffix
                // Intentionally avoids the broad human [A-Z0-9]+P\d+ pattern because it
                // false-positives on real genes (CASP1, CDK5RAP1, etc.). Users can uncheck
                // the filter to see everything.
                const PSEUDOGENE_RE = /^(Gm\d+|.+-ps\d*|.+Rik|.+-PS\d*)$/;
                function isPseudogene(name) {
                    if (!name) return false;
                    return PSEUDOGENE_RE.test(String(name));
                }

                function loadDEG(){
                    const pval = $('#pvalSlider').val();
                    const fc = $('#fcSlider').val();
                    const cellType = $('#cellTypeSelect').val();
                    const hidePseudo = $('#hidePseudogenes').is(':checked');
                    $('#pvalLabel').text(pval);
                    $('#fcLabel').text(fc);

                    if (currentComparisonJobId) {
                        const params = { jobId: currentComparisonJobId, pval: pval, fc: fc };
                        if (cellType) params.cellType = cellType;
                        $.getJSON(contextPath + '/deg-compare/result', params)
                            .done(function(data){
                                table.clear();
                                (data || []).forEach(function(r){
                                    if (hidePseudo && isPseudogene(r.gene)) return;
                                    table.row.add([r.gene, r.logFC, r.pval_adj, r.score, r.cell_type]);
                                });
                                table.draw();
                            })
                            .fail(function(xhr){ console.error("Comparison result load failed:", xhr.status); });
                        return;
                    }

                    if (!legacyReady || !legacyJobId) {
                        // Job is still running — table will populate on completion.
                        return;
                    }
                    const params = { jobId: legacyJobId, pval: pval, fc: fc };
                    if (cellType) params.cellType = cellType;
                    $.getJSON(contextPath + '/deg-per-celltype/result', params)
                        .done(function(data){
                            table.clear();
                            (data || []).forEach(function(r){
                                if (hidePseudo && isPseudogene(r.gene)) return;
                                table.row.add([r.gene, r.logFC, r.pval_adj, r.score, r.cell_type]);
                            });
                            table.draw();
                        })
                        .fail(function(xhr){ console.error("DEG data loading failed:", xhr.status); });
                }

                function pollCompareStatus(jobId) {
                    $.getJSON(contextPath + '/deg-compare/status', { jobId: jobId })
                        .done(function(s){
                            if (s.state === 'done') {
                                $('#degProgress').hide();
                                comparisonCellTypes = s.cellTypes || [];
                                currentComparisonJobId = jobId;
                                populateCellTypeSelect(comparisonCellTypes, $('#cellTypeSelect'));
                                $('#degCompareStatus').show().html('Comparing <strong>' + gsm + '</strong> vs <strong>' + comparisonLabelB + '</strong>' + (s.skipped && s.skipped.length ? ' · skipped: ' + s.skipped.join(', ') : ''));
                                updateEnrichSource();
                                loadDEG();
                                if (typeof loadEnrichData === 'function') loadEnrichData();
                            } else if (s.state === 'error') {
                                $('#degProgress').hide();
                                $('#degError').show().text('Comparison failed: ' + (s.error || 'unknown error'));
                                $('#degRunCompareBtn').prop('disabled', false);
                            } else {
                                setTimeout(function(){ pollCompareStatus(jobId); }, 2000);
                            }
                        })
                        .fail(function(xhr){
                            $('#degProgress').hide();
                            $('#degError').show().text('Status poll failed (' + xhr.status + ')');
                            $('#degRunCompareBtn').prop('disabled', false);
                        });
                }

                function runComparison() {
                    const saidB = $('#degCompareSelect').val();
                    if (!saidB) return;
                    comparisonSaidB = saidB;
                    comparisonLabelB = $('#degCompareSelect option:selected').data('label') || saidB;
                    $('#degError').hide();
                    $('#degCompareStatus').hide();
                    $('#degProgress').show();
                    $('#degRunCompareBtn').prop('disabled', true);
                    $.ajax({
                        url: contextPath + '/deg-compare',
                        method: 'POST',
                        contentType: 'application/json',
                        data: JSON.stringify({ saidA: said, saidB: saidB })
                    })
                    .done(function(resp){ pollCompareStatus(resp.jobId); })
                    .fail(function(xhr){
                        $('#degProgress').hide();
                        $('#degError').show().text('Failed to start comparison (' + xhr.status + ')');
                        $('#degRunCompareBtn').prop('disabled', false);
                    });
                }

                function clearComparison() {
                    currentComparisonJobId = null;
                    comparisonCellTypes = [];
                    comparisonSaidB = null;
                    comparisonLabelB = null;
                    $('#degCompareStatus').hide();
                    $('#degError').hide();
                    $('#degRunCompareBtn').prop('disabled', true);
                    if (legacyReady) {
                        populateCellTypeSelect(legacyCellTypes, $('#cellTypeSelect'));
                    } else {
                        initGroupOptions();
                    }
                    updateEnrichSource();
                    loadDEG();
                    if (typeof loadEnrichData === 'function') loadEnrichData();
                }

                function exportTableToExcel() {
                    const exportData = [["Gene", "logFC", "p-value", "Score", "Group"]];
                    table.rows({ search: 'applied' }).every(function () { exportData.push(this.data()); });
                    const ws = XLSX.utils.aoa_to_sheet(exportData);
                    const wb = XLSX.utils.book_new();
                    XLSX.utils.book_append_sheet(wb, ws, "Filtered_DEG");
                    XLSX.writeFile(wb, "filtered_DEG_results.xlsx");
                }

                // =========================================================================
                // UMAP PNG Visualization
                // =========================================================================
                function loadUmapOptions() {
                    $.getJSON('/umap_obs_options', { gse: gse, gsm: gsm })
                        .done(function(data) {
                            var select = $('#umapColorBy');
                            select.empty();
                            var allowed = ["Fine_Map", "Gross_Map"];
                            var cols = (data.obs_columns || []).filter(function(c) { return allowed.indexOf(c) !== -1; });
                            if (cols.length > 0) {
                                cols.forEach(function(col) {
                                    var selected = (col === data.default_color_by) ? ' selected' : '';
                                    select.append('<option value="' + col + '"' + selected + '>' + col + '</option>');
                                });
                            } else {
                                select.append('<option value="">No metadata available</option>');
                            }
                            loadUmapImage();
                        })
                        .fail(function() {
                            $('#umapColorBy').html('<option value="">Error loading options</option>');
                            loadUmapImage();
                        });
                }

                function loadUmapImage() {
                    var colorBy = $('#umapColorBy').val() || '';
                    $('#umap-loading').show();
                    $('#umap-image').hide();
                    var imgUrl = '/umap_png?gse=' + encodeURIComponent(gse) + '&gsm=' + encodeURIComponent(gsm);
                    if (colorBy) imgUrl += '&color_by=' + encodeURIComponent(colorBy);
                    imgUrl += '&_t=' + Date.now();

                    var img = new Image();
                    img.onload = function() {
                        $('#umap-image').attr('src', imgUrl).show();
                        $('#umap-loading').hide();
                    };
                    img.onerror = function() {
                        $('#umap-loading').removeClass('panel-loader').html('<p style="color:#c00;">Failed to load UMAP image.</p>');
                    };
                    img.src = imgUrl;
                }

                loadUmapOptions();
                $('#umapColorBy').on('change', loadUmapImage);
                $('#downloadUmapPdf').on('click', function() {
                    var colorBy = $('#umapColorBy').val() || '';
                    var pdfUrl = '/umap_pdf?gse=' + encodeURIComponent(gse) + '&gsm=' + encodeURIComponent(gsm);
                    if (colorBy) pdfUrl += '&color_by=' + encodeURIComponent(colorBy);
                    window.open(pdfUrl, '_blank');
                });

                loadCompareOptions();
                initGroupOptions();
                loadDEG();
                $('#pvalSlider, #fcSlider, #cellTypeSelect, #hidePseudogenes').on('input change', loadDEG);
                $('#exportExcelBtn').on('click', exportTableToExcel);
                $('#degCompareSelect').on('change', function(){
                    const v = $(this).val();
                    $('#degRunCompareBtn').prop('disabled', !v);
                    if (!v && currentComparisonJobId) clearComparison();
                });
                $('#degRunCompareBtn').on('click', runComparison);

                // Experimental Design / GEO metadata is now rendered server-side in
                // the JSP body above (no AJAX needed — the data is static per SAID).

                // Enrichment Analysis - Horizontal Bar Chart
                // =========================================================================
                var enrichAllData = [];

                function loadEnrichGeneSets() {
                    var method = $('#enrichMethod').val();
                    var action = (method === 'ora') ? 'ora-list' : 'list';
                    $('#enrichChart').empty();
                    $.getJSON(contextPath + '/enrichment', { said: said, action: action })
                        .done(function(data) {
                            var select = $('#enrichGeneSet');
                            select.empty();
                            if (data.gene_sets && data.gene_sets.length > 0) {
                                data.gene_sets.forEach(function(gs) {
                                    select.append('<option value="' + gs.label + '">' + gs.name + '</option>');
                                });
                                loadEnrichData();
                            } else {
                                select.append('<option value="">No data</option>');
                                $('#enrich-empty').show().text(method === 'ora'
                                    ? 'No ORA gene-set libraries available for this species.'
                                    : 'No enrichment data available for this dataset.');
                            }
                        })
                        .fail(function() {
                            $('#enrichGeneSet').html('<option value="">Error loading</option>');
                        });
                }

                function loadEnrichData() {
                    var method = $('#enrichMethod').val();
                    var geneSet = $('#enrichGeneSet').val();
                    var filter = $('#enrichFilter').val();
                    if (!geneSet) return;

                    $('#enrich-loading').show();
                    $('#enrich-empty').hide();
                    $('#enrichChart').empty();

                    if (method === 'ora') {
                        var topN = parseInt($('#enrichTopN').val()) || 10;
                        $.getJSON(contextPath + '/enrichment',
                            { said: said, method: 'ora', library: geneSet, top: topN, filter: filter })
                            .done(function(data) {
                                $('#enrich-loading').hide();
                                if (!data || data.length === 0) {
                                    $('#enrich-empty').show().text(filter === 'significant'
                                        ? 'No terms at FDR < 0.05. Try showing all results.'
                                        : 'No over-represented terms for this library.');
                                    return;
                                }
                                $('#enrich-empty').hide();
                                enrichAllData = data;
                                renderOraChart();
                            })
                            .fail(function() {
                                $('#enrich-loading').hide();
                                $('#enrich-empty').show().text('Error loading ORA results.');
                            });
                        return;
                    }

                    var enrichParams = { gene_set: geneSet, filter: filter };
                    if (currentComparisonJobId) {
                        enrichParams.jobId = currentComparisonJobId;
                        var ect = $('#enrichCellTypeSelect').val();
                        if (ect) enrichParams.cellType = ect;
                    } else {
                        enrichParams.said = said;
                    }
                    $.getJSON(contextPath + '/enrichment', enrichParams)
                        .done(function(data) {
                            $('#enrich-loading').hide();
                            if (!data || data.length === 0) {
                                $('#enrich-empty').show().text(
                                    filter === 'significant' ? 'No significant results. Try showing all results.' : 'No enrichment data available.'
                                );
                                return;
                            }
                            $('#enrich-empty').hide();
                            enrichAllData = data;
                            renderEnrichChart();
                        })
                        .fail(function() {
                            $('#enrich-loading').hide();
                            $('#enrich-empty').show().text('Error loading enrichment data.');
                        });
                }

                function renderEnrichChart() {
                    var topN = parseInt($('#enrichTopN').val()) || 10;
                    var half = Math.floor(topN / 2);

                    // Split into positive and negative NES
                    var pos = enrichAllData.filter(function(r) { return parseFloat(r.nes) > 0; });
                    var neg = enrichAllData.filter(function(r) { return parseFloat(r.nes) < 0; });

                    // Sort by |NES| descending
                    pos.sort(function(a, b) { return Math.abs(parseFloat(b.nes)) - Math.abs(parseFloat(a.nes)); });
                    neg.sort(function(a, b) { return Math.abs(parseFloat(b.nes)) - Math.abs(parseFloat(a.nes)); });

                    // Take equal amounts; if one side has fewer, give remainder to the other
                    var nPos = Math.min(half, pos.length);
                    var nNeg = Math.min(half, neg.length);
                    if (nPos < half) nNeg = Math.min(topN - nPos, neg.length);
                    if (nNeg < half) nPos = Math.min(topN - nNeg, pos.length);

                    var selected = neg.slice(0, nNeg).concat(pos.slice(0, nPos));

                    // Sort for display: negative (most negative first) then positive (least positive first)
                    selected.sort(function(a, b) { return parseFloat(a.nes) - parseFloat(b.nes); });

                    if (selected.length === 0) {
                        $('#enrich-empty').show().text('No pathways to display.');
                        return;
                    }

                    // Clean term names: remove common prefixes like GOBP_, HALLMARK_, etc.
                    var terms = selected.map(function(r) {
                        var t = r.term;
                        t = t.replace(/^(GOBP_|GOCC_|GOMF_|HALLMARK_|KEGG_|REACTOME_|WP_)/, '');
                        t = t.replace(/_/g, ' ');
                        if (t.length > 60) t = t.substring(0, 57) + '...';
                        return t;
                    });
                    var nesValues = selected.map(function(r) { return parseFloat(r.nes); });
                    var colors = nesValues.map(function(v) { return v > 0 ? '#c0392b' : '#2471a3'; });
                    var hoverText = selected.map(function(r) {
                        return '<b>' + r.term.replace(/_/g, ' ') + '</b><br>' +
                               'NES: ' + parseFloat(r.nes).toFixed(3) + '<br>' +
                               'FDR q-val: ' + parseFloat(r.fdr_qval).toExponential(2) + '<br>' +
                               'NOM p-val: ' + parseFloat(r.nom_pval).toExponential(2);
                    });

                    var chartHeight = Math.max(400, selected.length * 28 + 100);

                    var trace = {
                        type: 'bar',
                        orientation: 'h',
                        x: nesValues,
                        y: terms,
                        marker: { color: colors },
                        text: nesValues.map(function(v) { return v.toFixed(2); }),
                        textposition: 'outside',
                        textfont: { size: 11 },
                        hovertext: hoverText,
                        hoverinfo: 'text'
                    };

                    var layout = {
                        margin: { l: 320, r: 60, t: 30, b: 50 },
                        xaxis: {
                            title: 'Normalized Enrichment Score (NES)',
                            zeroline: true,
                            zerolinecolor: '#999',
                            zerolinewidth: 1.5
                        },
                        yaxis: {
                            automargin: true,
                            tickfont: { size: 11 }
                        },
                        height: chartHeight,
                        plot_bgcolor: '#fff',
                        paper_bgcolor: '#fff',
                        font: { family: 'Nunito, sans-serif' },
                        shapes: [{
                            type: 'line', x0: 0, x1: 0,
                            y0: -0.5, y1: selected.length - 0.5,
                            line: { color: '#999', width: 1.5, dash: 'dot' }
                        }],
                        annotations: [
                            { x: Math.min.apply(null, nesValues) * 0.5, y: selected.length + 0.3,
                              text: '<b style="color:#2471a3">Downregulated</b>', showarrow: false,
                              font: { size: 12, color: '#2471a3' }, xanchor: 'center' },
                            { x: Math.max.apply(null, nesValues) * 0.5, y: selected.length + 0.3,
                              text: '<b style="color:#c0392b">Upregulated</b>', showarrow: false,
                              font: { size: 12, color: '#c0392b' }, xanchor: 'center' }
                        ]
                    };

                    Plotly.newPlot('enrichChart', [trace], layout, figConfig('GSEA_' + said, {
                        responsive: true,
                        displayModeBar: true,
                        modeBarButtonsToRemove: ['lasso2d', 'select2d']
                    }));
                }

                function renderOraChart() {
                    var rows = (enrichAllData || []).slice();
                    if (rows.length === 0) { $('#enrich-empty').show().text('No terms to display.'); return; }
                    // Server returns top-N by p-value ascending; reverse so the most significant
                    // term sits at the top of the horizontal bar chart.
                    rows.reverse();

                    var terms = rows.map(function(r) {
                        var t = String(r.term).replace(/^(GOBP_|GOCC_|GOMF_|HALLMARK_|KEGG_|REACTOME_|WP_)/, '');
                        t = t.replace(/_/g, ' ');
                        if (t.length > 60) t = t.substring(0, 57) + '...';
                        return t;
                    });
                    var vals = rows.map(function(r) {
                        var f = parseFloat(r.fdr);
                        if (!(f > 0)) f = 1e-300;
                        return -Math.log10(f);
                    });
                    var hoverText = rows.map(function(r) {
                        return '<b>' + String(r.term).replace(/_/g, ' ') + '</b><br>' +
                               'Overlap: ' + r.overlap + ' / ' + r.set_size + ' genes<br>' +
                               'Fold enrichment: ' + parseFloat(r.fold_enrichment).toFixed(2) + '×<br>' +
                               'p-value: ' + parseFloat(r.pval).toExponential(2) + '<br>' +
                               'FDR: ' + parseFloat(r.fdr).toExponential(2) + '<br>' +
                               '<span style="font-size:10px">' + String(r.overlap_genes) + '</span>';
                    });
                    var barText = rows.map(function(r) { return r.overlap + '/' + r.set_size; });
                    var chartHeight = Math.max(400, rows.length * 30 + 110);

                    var trace = {
                        type: 'bar', orientation: 'h',
                        x: vals, y: terms,
                        marker: { color: '#c0392b' },
                        text: barText, textposition: 'outside', textfont: { size: 11 },
                        hovertext: hoverText, hoverinfo: 'text'
                    };
                    var layout = {
                        margin: { l: 320, r: 70, t: 30, b: 50 },
                        xaxis: { title: '−log₁₀(FDR)', zeroline: true, zerolinecolor: '#999' },
                        yaxis: { automargin: true, tickfont: { size: 11 } },
                        height: chartHeight,
                        plot_bgcolor: '#fff', paper_bgcolor: '#fff',
                        font: { family: 'Nunito, sans-serif' }
                    };
                    Plotly.newPlot('enrichChart', [trace], layout, figConfig('ORA_' + said, {
                        responsive: true, displayModeBar: true,
                        modeBarButtonsToRemove: ['lasso2d', 'select2d']
                    }));
                }

                loadEnrichGeneSets();
                $('#enrichMethod').on('change', loadEnrichGeneSets);
                $('#enrichGeneSet, #enrichFilter, #enrichCellTypeSelect').on('change', loadEnrichData);
                $('#enrichTopN').on('change', function() {
                    if ($('#enrichMethod').val() === 'ora') { loadEnrichData(); }
                    else { renderEnrichChart(); }
                });

                // =========================================================================
                // SECTION C2: SCORPION GENE REGULATORY NETWORK (precomputed)
                // =========================================================================
                var scorpionRegulators = [];
                var ACCENT = '#337ab7';

                function scorpionLayout(extra) {
                    return Object.assign({
                        font: { family: 'Nunito, sans-serif', size: 12, color: '#333' },
                        paper_bgcolor: 'rgba(0,0,0,0)',
                        plot_bgcolor: 'rgba(0,0,0,0)',
                        margin: { l: 110, r: 24, t: 24, b: 44 }
                    }, extra || {});
                }

                function loadScorpion() {
                    $('#scorpion-loading').show();
                    $('#scorpion-empty').hide();
                    $('#scorpionContent').hide();
                    var topN = parseInt($('#scorpionTopN').val()) || 20;
                    $.getJSON(contextPath + '/scorpion', { said: said, action: 'activity', top: topN })
                        .done(function(data) {
                            $('#scorpion-loading').hide();
                            if (!data || !data.available || !data.regulators || data.regulators.length === 0) {
                                $('#scorpion-empty').show();
                                return;
                            }
                            scorpionRegulators = data.regulators;
                            $('#scorpionContent').show();
                            renderScorpionRegChart();
                            populateScorpionTfSelect();
                            loadScorpionNetwork();
                            var firstTf = scorpionRegulators[0] && scorpionRegulators[0].tf;
                            if (firstTf) { $('#scorpionTfSelect').val(firstTf); loadScorpionTargets(firstTf); }
                        })
                        .fail(function() {
                            $('#scorpion-loading').hide();
                            $('#scorpion-empty').show().text('Error loading regulatory network.');
                        });
                }

                function renderScorpionRegChart() {
                    var rows = scorpionRegulators.slice().sort(function(a, b) {
                        return parseFloat(a.total_score) - parseFloat(b.total_score); // ascending -> top of bar chart is largest
                    });
                    var trace = {
                        type: 'bar', orientation: 'h',
                        x: rows.map(function(r) { return parseFloat(r.total_score); }),
                        y: rows.map(function(r) { return r.tf; }),
                        marker: { color: ACCENT },
                        hovertemplate: '<b>%{y}</b><br>Regulatory score: %{x:.2f}<br>Targets: %{customdata}<extra></extra>',
                        customdata: rows.map(function(r) { return r.out_degree; })
                    };
                    var layout = scorpionLayout({
                        height: Math.max(320, rows.length * 22 + 80),
                        xaxis: { title: 'Total regulatory score', zeroline: false },
                        yaxis: { automargin: true }
                    });
                    Plotly.newPlot('scorpionRegChart', [trace], layout,
                        figConfig('SCORPION_master_regulators_' + said, { responsive: true, displayModeBar: true }));
                }

                function populateScorpionTfSelect() {
                    var sel = $('#scorpionTfSelect').empty();
                    scorpionRegulators.forEach(function(r) {
                        sel.append('<option value="' + r.tf + '">' + r.tf + '</option>');
                    });
                }

                function loadScorpionTargets(tf) {
                    if (!tf) return;
                    $.getJSON(contextPath + '/scorpion', { said: said, action: 'targets', tf: tf, top: 20 })
                        .done(function(data) {
                            var targets = (data && data.targets) || [];
                            if (targets.length === 0) {
                                Plotly.purge('scorpionTargetChart');
                                $('#scorpionTargetChart').html('<div class="help-text" style="padding:0.5rem 0;">No target genes recorded for ' + tf + '.</div>');
                                return;
                            }
                            var rows = targets.slice().sort(function(a, b) { return parseFloat(a.weight) - parseFloat(b.weight); });
                            var trace = {
                                type: 'bar', orientation: 'h',
                                x: rows.map(function(r) { return parseFloat(r.weight); }),
                                y: rows.map(function(r) { return r.target; }),
                                marker: { color: '#5a91c0' },
                                hovertemplate: '<b>%{y}</b><br>Edge weight: %{x:.2f}<extra></extra>'
                            };
                            var layout = scorpionLayout({
                                height: Math.max(280, rows.length * 22 + 70),
                                xaxis: { title: 'Regulatory edge weight (' + tf + ' → target)', zeroline: false },
                                yaxis: { automargin: true }
                            });
                            Plotly.newPlot('scorpionTargetChart', [trace], layout,
                                figConfig('SCORPION_targetome_' + tf + '_' + said, { responsive: true, displayModeBar: true }));
                        })
                        .fail(function() {
                            $('#scorpionTargetChart').html('<div class="help-text" style="padding:0.5rem 0;">Error loading targets.</div>');
                        });
                }

                function loadScorpionNetwork() {
                    $.getJSON(contextPath + '/scorpion', { said: said, action: 'network', topTf: 10, topTarget: 6 })
                        .done(function(data) {
                            if (!data || !data.available || !data.nodes) { Plotly.purge('scorpionNetwork'); return; }
                            renderScorpionNetwork(data.nodes, data.links);
                        });
                }

                // Deterministic bipartite layout: regulators on the left, targets on the right.
                function renderScorpionNetwork(nodes, links) {
                    var tfs = nodes.filter(function(n) { return n.type === 'tf'; });
                    var tgs = nodes.filter(function(n) { return n.type === 'target'; });
                    var pos = {};
                    function place(arr, x) {
                        arr.forEach(function(n, i) {
                            var y = arr.length === 1 ? 0.5 : 1 - (i / (arr.length - 1));
                            pos[n.id] = { x: x, y: y };
                        });
                    }
                    place(tfs, 0); place(tgs, 1);

                    var edgeX = [], edgeY = [];
                    links.forEach(function(l) {
                        var s = pos[l.source], t = pos[l.target];
                        if (!s || !t) return;
                        edgeX.push(s.x, t.x, null);
                        edgeY.push(s.y, t.y, null);
                    });
                    var edgeTrace = {
                        type: 'scatter', mode: 'lines', x: edgeX, y: edgeY,
                        line: { color: 'rgba(51,122,183,0.22)', width: 1 }, hoverinfo: 'none'
                    };
                    function nodeTrace(arr, color, size, anchor, dx) {
                        return {
                            type: 'scatter', mode: 'markers+text',
                            x: arr.map(function(n) { return pos[n.id].x; }),
                            y: arr.map(function(n) { return pos[n.id].y; }),
                            text: arr.map(function(n) { return n.id; }),
                            textposition: anchor, textfont: { size: 11, color: '#333' },
                            marker: { color: color, size: size, line: { color: '#fff', width: 1 } },
                            hovertemplate: '%{text}<extra></extra>'
                        };
                    }
                    var tfTrace = nodeTrace(tfs, ACCENT, 14, 'middle left');
                    var tgTrace = nodeTrace(tgs, '#9aa7b3', 9, 'middle right');
                    var layout = scorpionLayout({
                        height: Math.max(360, Math.max(tfs.length, tgs.length) * 34 + 80),
                        showlegend: false,
                        margin: { l: 90, r: 90, t: 20, b: 20 },
                        xaxis: { visible: false, range: [-0.35, 1.35] },
                        yaxis: { visible: false, range: [-0.1, 1.1] }
                    });
                    Plotly.newPlot('scorpionNetwork', [edgeTrace, tfTrace, tgTrace], layout,
                        figConfig('SCORPION_network_' + said, { responsive: true, displayModeBar: true }));
                }

                loadScorpion();
                $('#scorpionTopN').on('change', loadScorpion);
                $('#scorpionTfSelect').on('change', function() { loadScorpionTargets($(this).val()); });

                // =========================================================================
                // SECTION D: CELLPHONEDB DYNAMIC ANALYSIS
                // =========================================================================

                var cpdbAllCellTypes = [];

                function buildCheckboxList(containerId, cellTypes, cellCounts, prefix) {
                    var html = '';
                    cellTypes.forEach(function(ct, i) {
                        var count = cellCounts[ct] || 0;
                        var id = prefix + '_' + i;
                        html += '<label class="checkbox-item" title="' + ct + ' (' + count + ' cells)">' +
                            '<input type="checkbox" value="' + ct.replace(/"/g, '&quot;') + '" id="' + id + '">' +
                            '<span class="checkbox-item__text">' + ct + '</span>' +
                            '<span class="checkbox-item__count">' + count + '</span>' +
                            '</label>';
                    });
                    $('#' + containerId).html(html);
                }

                function updateCounts() {
                    $('#cpdbSelectedCount').text($('#cpdbCellTypeList input:checked').length);
                    $('#cpdbSenderCount').text($('#cpdbSenderList input:checked').length);
                    $('#cpdbReceiverCount').text($('#cpdbReceiverList input:checked').length);
                }

                function currentCpdbLevel() {
                    // Returns "fine" or "gross" based on the radio button state.
                    return $('input[name="cpdbLevel"]:checked').val() || 'fine';
                }

                function initCpdbCellTypes() {
                    var level = currentCpdbLevel();
                    $('#cpdbCellTypeList').html('<div class="panel-loader" role="status" aria-label="Loading"></div>');
                    $('#cpdbSenderList, #cpdbReceiverList').html('');
                    $.getJSON(contextPath + '/cpdb-api?action=cell-types', { said: said, level: level })
                        .done(function(data) {
                            if (data.error) {
                                $('#cpdbCellTypeList').html('<div style="color:#c00;">' + data.error + '</div>');
                                return;
                            }
                            cpdbAllCellTypes = data.cell_types;
                            var counts = data.cell_counts || {};
                            buildCheckboxList('cpdbCellTypeList', data.cell_types, counts, 'ct_all');
                            buildCheckboxList('cpdbSenderList', data.cell_types, counts, 'ct_sender');
                            buildCheckboxList('cpdbReceiverList', data.cell_types, counts, 'ct_recv');
                            $('#cpdbCellTypeList, #cpdbSenderList, #cpdbReceiverList').on('change', 'input', updateCounts);
                            updateCounts();
                        })
                        .fail(function() {
                            $('#cpdbCellTypeList').html('<div style="color:#c00;">Failed to load cell types</div>');
                        });
                }

                // When the granularity toggle flips, reload the cell-type lists at the new level.
                $('input[name="cpdbLevel"]').on('change', function() { initCpdbCellTypes(); });

                $('#cpdbSelectAll').click(function() {
                    $('#cpdbCellTypeList input[type="checkbox"]').prop('checked', true);
                    updateCounts();
                });
                $('#cpdbClearAll').click(function() {
                    $('#cpdbCellTypeList input[type="checkbox"]').prop('checked', false);
                    updateCounts();
                });

                $('input[name="cpdbMode"]').change(function() {
                    var isDirected = $(this).val() === 'directed';
                    $('#cpdbAllControls').toggle(!isDirected);
                    $('#cpdbDirectedControls').toggle(isDirected);
                });

                // Run analysis
                $('#runCpdbAnalysisBtn').click(function() {
                    const mode = $('input[name="cpdbMode"]:checked').val();
                    var selectedTypes = [];
                    var senderTypes = [];
                    var receiverTypes = [];

                    if (mode === 'all') {
                        $('#cpdbCellTypeList input:checked').each(function() { selectedTypes.push($(this).val()); });
                        if (selectedTypes.length < 2) {
                            alert('Please select at least 2 cell types');
                            return;
                        }
                    } else {
                        $('#cpdbSenderList input:checked').each(function() { senderTypes.push($(this).val()); });
                        $('#cpdbReceiverList input:checked').each(function() { receiverTypes.push($(this).val()); });
                        if (senderTypes.length < 1 || receiverTypes.length < 1) {
                            alert('Please select at least 1 sender and 1 receiver cell type');
                            return;
                        }
                        // Merge unique cell types for CellPhoneDB
                        var allSet = {};
                        senderTypes.forEach(function(t) { allSet[t] = true; });
                        receiverTypes.forEach(function(t) { allSet[t] = true; });
                        selectedTypes = Object.keys(allSet);
                    }

                    const params = {
                        action: 'run-analysis',
                        said: said,
                        cell_types: JSON.stringify(selectedTypes)
                    };

                    if (mode === 'directed') {
                        params.senders = JSON.stringify(senderTypes);
                        params.receivers = JSON.stringify(receiverTypes);
                    }

                    // Show progress
                    $('#cpdbProgressSection').show();
                    $('#cpdbResultsSection').hide();

                    console.log("📡 Starting CPDB analysis:", params);

                    $.ajax({
                        url: contextPath + '/cpdb-api?action=run-analysis',
                        type: 'POST',
                        data: {
                            said: said,
                            cell_types: JSON.stringify(selectedTypes),
                            senders: mode === 'directed' ? JSON.stringify(senderTypes) : null,
                            receivers: mode === 'directed' ? JSON.stringify(receiverTypes) : null,
                            level: currentCpdbLevel()
                        },
                        success: function(response) {
                            console.log("✅ CPDB analysis started:", response);
                            if (response.job_id) {
                                pollCpdbStatus(response.job_id);
                            } else if (response.error) {
                                showCpdbError(response.error);
                            }
                        },
                        error: function(xhr) {
                            console.error("❌ CPDB analysis request failed:", xhr.status, xhr.statusText);
                            showCpdbError('Request failed: ' + xhr.statusText);
                        }
                    });
                });

                // Poll job status
                function pollCpdbStatus(jobId) {
                    const poll = setInterval(function() {
                        $.getJSON(contextPath + '/cpdb-api?action=status', {
                            job_id: jobId
                        }).done(function(data) {
                            console.log("📊 CPDB job status:", data);
                            if (data.status === 'completed') {
                                clearInterval(poll);
                                loadCpdbResults(jobId);
                            } else if (data.status === 'failed') {
                                clearInterval(poll);
                                showCpdbError(data.error || 'Analysis failed');
                            }
                        }).fail(function() {
                            clearInterval(poll);
                            showCpdbError('Failed to check job status');
                        });
                    }, 3000);
                }

                // Load and display results
                function loadCpdbResults(jobId) {
                    $.getJSON(contextPath + '/cpdb-api?action=results', {
                        job_id: jobId
                    }).done(function(data) {
                        console.log("CPDB results loaded:", data);
                        $('#cpdbProgressSection').hide();
                        $('#cpdbResultsSection').show();

                        // Ensure heatmap tab is active
                        $('.cpdb-tab').removeClass('active').first().addClass('active');
                        $('.cpdb-tab-content').removeClass('active');
                        $('#cpdbHeatmapTab').addClass('active');

                        // Delay render slightly to let the DOM update display
                        setTimeout(function() {
                            try { renderCpdbHeatmap(data.heatmap_data); } catch(e) { console.error('Heatmap render error:', e); }
                            try { renderCpdbDotplot(data.dotplot_data); } catch(e) { console.error('Dotplot render error:', e); }
                            try { populateCpdbTable(data.interactions); } catch(e) { console.error('Table render error:', e); }
                        }, 100);
                    }).fail(function(xhr) {
                        console.error("Failed to load CPDB results:", xhr.status);
                        showCpdbError('Failed to load results');
                    });
                }

                // Render heatmap using Plotly
                function renderCpdbHeatmap(heatmapData) {
                    if (!heatmapData || !heatmapData.z || heatmapData.z.length === 0) {
                        $('#cpdbHeatmapPlot').html('<div class="cpdb-error"><p class="cpdb-error-text">No interaction data to display</p></div>');
                        return;
                    }

                    var trace = {
                        z: heatmapData.z,
                        x: heatmapData.x,
                        y: heatmapData.y,
                        type: 'heatmap',
                        colorscale: [
                            [0, '#ffffff'],
                            [0.5, '#337ab7'],
                            [1, '#8B0000']
                        ],
                        hoverongaps: false,
                        hovertemplate: 'Receiver: %{x}<br>Sender: %{y}<br>Significant interactions: %{z}<extra></extra>'
                    };

                    var el = document.getElementById('cpdbHeatmapPlot');
                    var w = Math.max(el.offsetWidth - 40, 500);
                    var h = Math.max(heatmapData.y.length * 40 + 250, 500);

                    var layout = {
                        title: 'Significant Interactions Between Cell Types',
                        font: { family: 'Nunito, sans-serif' },
                        width: w,
                        height: h,
                        xaxis: {
                            title: 'Receiver',
                            tickangle: -45,
                            tickfont: { size: 11 }
                        },
                        yaxis: {
                            title: 'Sender',
                            tickfont: { size: 11 },
                            automargin: true
                        },
                        margin: { l: 150, r: 50, t: 60, b: 150 }
                    };

                    Plotly.newPlot('cpdbHeatmapPlot', [trace], layout, figConfig('cpdb_heatmap_' + said, { responsive: true }));
                }

                // Render dot plot using Plotly
                function renderCpdbDotplot(dotplotData) {
                    if (!dotplotData || !dotplotData.interactions || dotplotData.interactions.length === 0) {
                        $('#cpdbDotplot').html('<div class="cpdb-error"><p class="cpdb-error-text">No significant interactions to display</p></div>');
                        return;
                    }

                    // Flatten 2D arrays into scatter points
                    var xArr = [], yArr = [], sizeArr = [], colorArr = [], textArr = [];
                    var interactions = dotplotData.interactions;
                    var cellPairs = dotplotData.cell_pairs;
                    var means = dotplotData.means;
                    var pvalues = dotplotData.pvalues;
                    var sizes = dotplotData.sizes;

                    for (var i = 0; i < interactions.length; i++) {
                        for (var j = 0; j < cellPairs.length; j++) {
                            var m = means[i][j];
                            var p = pvalues[i][j];
                            var s = sizes[i][j];
                            if (s > 0) {
                                xArr.push(cellPairs[j]);
                                yArr.push(interactions[i]);
                                sizeArr.push(Math.min(25, Math.max(4, s * 2.5)));
                                colorArr.push(m);
                                textArr.push('Mean: ' + m.toFixed(3) + '<br>p-value: ' + p.toFixed(4));
                            }
                        }
                    }

                    if (xArr.length === 0) {
                        $('#cpdbDotplot').html('<div class="cpdb-error"><p class="cpdb-error-text">No significant interactions to display</p></div>');
                        return;
                    }

                    var trace = {
                        x: xArr,
                        y: yArr,
                        mode: 'markers',
                        marker: {
                            size: sizeArr,
                            color: colorArr,
                            colorscale: [[0, '#2166ac'], [0.5, '#f7f7f7'], [1, '#b2182b']],
                            showscale: true,
                            colorbar: { title: 'Mean', thickness: 15, len: 0.6 }
                        },
                        type: 'scatter',
                        text: textArr,
                        hovertemplate: '%{y}<br>%{x}<br>%{text}<extra></extra>'
                    };

                    var el = document.getElementById('cpdbDotplot');
                    var w = Math.max(el.offsetWidth - 40, 600);
                    var h = Math.max(interactions.length * 22 + 250, 500);

                    var layout = {
                        title: 'Top Ligand-Receptor Interactions (Dot Plot)',
                        font: { family: 'Nunito, sans-serif' },
                        width: w,
                        height: h,
                        xaxis: {
                            title: dotplotData.directed ? 'Cell Type Pairs (Sender | Receiver)' : 'Cell Type Pairs',
                            tickangle: -45,
                            tickfont: { size: 9 },
                            automargin: true
                        },
                        yaxis: {
                            title: '',
                            tickfont: { size: 9 },
                            automargin: true
                        },
                        margin: { l: 200, r: 80, t: 60, b: 150 }
                    };

                    Plotly.newPlot('cpdbDotplot', [trace], layout, figConfig('cpdb_dotplot_' + said, { responsive: true }));
                }

                // Populate results table
                var cpdbTable = null;

                function populateCpdbTable(interactions) {
                    if (cpdbTable) {
                        cpdbTable.destroy();
                        cpdbTable = null;
                    }
                    var tbody = $('#cpdbResultsTable tbody');
                    tbody.empty();

                    var exportBtn = document.getElementById('cpdbExportExcelBtn');

                    if (!interactions || interactions.length === 0) {
                        tbody.append('<tr><td colspan="5" style="text-align:center; color:#999;">No significant interactions found</td></tr>');
                        if (exportBtn) exportBtn.disabled = true;
                        return;
                    }

                    interactions.forEach(function(row) {
                        var pClass = row.pvalue < 0.01 ? 'color:#c0392b; font-weight:300;' : (row.pvalue < 0.05 ? 'color:#e67e22;' : '');
                        tbody.append(
                            '<tr>' +
                            '<td>' + (row.interaction || '') + '</td>' +
                            '<td>' + (row.sender || '') + '</td>' +
                            '<td>' + (row.receiver || '') + '</td>' +
                            '<td>' + (row.mean != null ? row.mean.toFixed(4) : '0') + '</td>' +
                            '<td style="' + pClass + '">' + (row.pvalue != null ? row.pvalue.toFixed(4) : '1') + '</td>' +
                            '</tr>'
                        );
                    });

                    cpdbTable = $('#cpdbResultsTable').DataTable({
                        paging: true,
                        pageLength: 10,
                        searching: true,
                        info: true,
                        order: [[4, 'asc']],
                        language: { search: 'Filter:' }
                    });

                    if (exportBtn) exportBtn.disabled = false;
                }

                // Export the (filtered) CPDB results table to an Excel file.
                // Uses the SheetJS XLSX library already loaded for DEG export.
                function exportCpdbResultsToExcel() {
                    if (!cpdbTable) return;
                    try {
                        var exportData = [["Interaction Pair", "Sender", "Receiver", "Mean Expression", "P-value"]];
                        cpdbTable.rows({ search: 'applied' }).every(function () {
                            // DataTable rows are HTML strings; pull plain text from the row's DOM cells
                            var node = this.node();
                            if (!node) return;
                            var cells = $(node).find('td');
                            exportData.push([
                                cells.eq(0).text(),
                                cells.eq(1).text(),
                                cells.eq(2).text(),
                                cells.eq(3).text(),
                                cells.eq(4).text()
                            ]);
                        });

                        var ws = XLSX.utils.aoa_to_sheet(exportData);
                        var wb = XLSX.utils.book_new();
                        XLSX.utils.book_append_sheet(wb, ws, "CPDB_Significant");

                        var safeSaid = (typeof said !== 'undefined' && said) ? String(said).replace(/[^A-Za-z0-9_-]+/g, '_') : 'sample';
                        var filename = 'CPDB_' + safeSaid + '_significant_interactions.xlsx';
                        XLSX.writeFile(wb, filename);
                    } catch (err) {
                        console.error('CPDB Excel export failed:', err);
                        alert('Export failed: ' + (err && err.message ? err.message : 'unknown error'));
                    }
                }
                $(document).on('click', '#cpdbExportExcelBtn', function() {
                    if (this.disabled) return;
                    exportCpdbResultsToExcel();
                });

                // Show error
                function showCpdbError(message) {
                    $('#cpdbProgressSection').hide();
                    $('#cpdbResultsSection').show();
                    $('#cpdbHeatmapPlot').html(
                        '<div class="cpdb-error">' +
                        '<svg class="cpdb-error-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">' +
                        '<circle cx="12" cy="12" r="10"></circle>' +
                        '<line x1="12" y1="8" x2="12" y2="12"></line>' +
                        '<line x1="12" y1="16" x2="12.01" y2="16"></line>' +
                        '</svg>' +
                        '<p class="cpdb-error-text">' + message + '</p>' +
                        '</div>'
                    );
                }

                // Tab switching
                $('.cpdb-tab').click(function() {
                    const tab = $(this).data('tab');
                    $('.cpdb-tab').removeClass('active');
                    $(this).addClass('active');
                    $('.cpdb-tab-content').removeClass('active');
                    $('#cpdb' + tab.charAt(0).toUpperCase() + tab.slice(1) + 'Tab').addClass('active');

                    // Resize Plotly charts when tab becomes visible
                    if (tab === 'heatmap') {
                        Plotly.Plots.resize('cpdbHeatmapPlot');
                    } else if (tab === 'dotplot') {
                        Plotly.Plots.resize('cpdbDotplot');
                    }
                });

                // ─── Gene Set Scoring ─────────────────────────
                var gssMethodNames = {
                    'aucell': 'AUCell',
                    'scanpy': 'Scanpy score_genes',
                    'ucell': 'UCell',
                    'ssgsea': 'ssGSEA',
                    'gsva': 'GSVA'
                };

                var gssCurrentMode = 'custom';
                var gssSelectedMsigdbGenes = null;
                var gssSelectedMsigdbName = '';
                var gssUploadedSets = {};       // {name: [genes]}
                var gssSelectedUploadName = '';
                var gssSelectedUploadGenes = null;
                var datasetSpecies = '<%= speciesVal %>'.toLowerCase();

                // Input mode tab switching
                $('.gss-input-tab').click(function() {
                    var mode = $(this).data('mode');
                    gssCurrentMode = mode;
                    $('.gss-input-tab').removeClass('active').css({'color':'#999','border-bottom-color':'transparent'});
                    $(this).addClass('active').css({'color':'#5b86e5','border-bottom-color':'#5b86e5'});
                    $('.gss-input-panel').hide();
                    if (mode === 'custom') $('#gssCustomPanel').show();
                    else if (mode === 'msigdb') { $('#gssMsigdbPanel').show(); loadGmtCatalog(); }
                    else if (mode === 'upload') $('#gssUploadPanel').show();
                });
                // Style active tab on init
                $('.gss-input-tab.active').css({'color':'#5b86e5','border-bottom-color':'#5b86e5'});

                // ─── MSigDB Library Browser ─────────────────
                function loadGmtCatalog() {
                    var sel = $('#gssLibrary');
                    if (sel.data('loaded')) return;
                    sel.html('<option value="">—</option>');
                    $.getJSON('/cpdb-api/gmt-catalog', { species: datasetSpecies })
                        .done(function(data) {
                            sel.empty();
                            sel.append('<option value="">-- Select a library --</option>');
                            var cats = {};
                            data.libraries.forEach(function(lib) {
                                if (!cats[lib.category]) cats[lib.category] = [];
                                cats[lib.category].push(lib);
                            });
                            Object.keys(cats).forEach(function(cat) {
                                var group = $('<optgroup label="' + cat + '">');
                                cats[cat].forEach(function(lib) {
                                    group.append('<option value="' + lib.file + '">' + lib.label + ' (' + lib.n_sets + ' sets)</option>');
                                });
                                sel.append(group);
                            });
                            sel.data('loaded', true);
                        })
                        .fail(function() { sel.html('<option value="">Error loading libraries</option>'); });
                }

                var gssSearchTimer = null;
                $('#gssSetSearch').on('input', function() {
                    clearTimeout(gssSearchTimer);
                    gssSearchTimer = setTimeout(loadGmtSets, 300);
                });
                $('#gssLibrary').on('change', function() {
                    $('#gssSetSearch').val('');
                    gssSelectedMsigdbGenes = null;
                    gssSelectedMsigdbName = '';
                    $('#gssSelectedSetInfo').hide();
                    loadGmtSets();
                });

                function loadGmtSets() {
                    var file = $('#gssLibrary').val();
                    if (!file) {
                        $('#gssSetList').html('<div style="padding:12px; color:#999; font-size:0.85rem;">Select a library to browse gene sets</div>');
                        return;
                    }
                    var search = $('#gssSetSearch').val().trim();
                    $('#gssSetList').html('<div style="padding:12px; color:#999; font-size:0.85rem;">Searching...</div>');
                    $.getJSON('/cpdb-api/gmt-sets', { file: file, search: search, limit: 100 })
                        .done(function(data) {
                            if (!data.sets || data.sets.length === 0) {
                                $('#gssSetList').html('<div style="padding:12px; color:#999; font-size:0.85rem;">No matching gene sets found</div>');
                                return;
                            }
                            var html = '';
                            data.sets.forEach(function(s) {
                                var isSelectedBool = (s.name === gssSelectedMsigdbName);
                                html += "<div class=\"gss-set-item set-list-item" + (isSelectedBool ? " selected" : "") + "\" data-name=\"" + s.name.replace(/"/g, "&quot;") + "\" data-file=\"" + file + "\">" +
                                    '<span>' + s.name.replace(/_/g, ' ') + '</span>' +
                                    '<span class="set-list-item__meta">' + s.n_genes + ' genes</span></div>';
                            });
                            if (data.sets.length >= 100) {
                                html += '<div style="padding:8px 12px; color:#888; font-size:0.78rem; text-align:center; font-style:italic;">Showing first 100 results. Use search to narrow down.</div>';
                            }
                            $('#gssSetList').html(html);
                        })
                        .fail(function() {
                            $('#gssSetList').html('<div style="padding:12px; color:#c00; font-size:0.85rem;">Error loading gene sets</div>');
                        });
                }

                // Click on a gene set in the list
                $(document).on('click', '.gss-set-item', function() {
                    var name = $(this).data('name');
                    var file = $(this).data('file');
                    $('.gss-set-item').removeClass('selected');
                    $(this).addClass('selected');
                    gssSelectedMsigdbName = name;
                    $('#gssSelectedSetInfo').html('<div class="panel-loader" role="status" aria-label="Loading"></div>').show();
                    $.getJSON('/cpdb-api/gmt-genes', { file: file, set_name: name })
                        .done(function(data) {
                            gssSelectedMsigdbGenes = data.genes;
                            $('#gssSelectedSetInfo').html('<strong>' + name.replace(/_/g, ' ') + '</strong> &mdash; ' + data.n_genes + ' genes: <span style="color:#666;">' + data.genes.slice(0, 15).join(', ') + (data.genes.length > 15 ? ', ...' : '') + '</span>').show();
                        })
                        .fail(function() {
                            $('#gssSelectedSetInfo').html('<span style="color:#c00;">Failed to load genes</span>').show();
                        });
                });

                // ─── GMT File Upload ─────────────────────────
                function handleGmtFile(file) {
                    if (!file) return;
                    var reader = new FileReader();
                    reader.onload = function(e) {
                        var content = e.target.result;
                        var lines = content.trim().split('\n');
                        gssUploadedSets = {};
                        var setsInfo = [];
                        lines.forEach(function(line) {
                            var parts = line.split('\t');
                            if (parts.length >= 3) {
                                var name = parts[0];
                                var genes = parts.slice(2).filter(function(g) { return g.trim(); });
                                if (genes.length > 0) {
                                    gssUploadedSets[name] = genes;
                                    setsInfo.push({ name: name, n_genes: genes.length });
                                }
                            }
                        });

                        if (setsInfo.length === 0) {
                            $('#gssError').text('No valid gene sets found in file. Expected GMT format: name<tab>description<tab>gene1<tab>gene2<tab>...').show();
                            return;
                        }

                        // Detect species from gene names
                        var sampleGenes = [];
                        var keys = Object.keys(gssUploadedSets).slice(0, 10);
                        keys.forEach(function(k) { sampleGenes = sampleGenes.concat(gssUploadedSets[k].slice(0, 5)); });
                        var upperCount = sampleGenes.filter(function(g) { return g === g.toUpperCase(); }).length;
                        var detectedSpecies = (upperCount / sampleGenes.length > 0.7) ? 'human' : 'mouse';

                        // Species warning
                        if (detectedSpecies !== datasetSpecies) {
                            var warnText = 'The uploaded gene set appears to be for <strong>' + detectedSpecies +
                                '</strong>, but this dataset is <strong>' + datasetSpecies +
                                '</strong>. Gene symbols may not match, leading to low or no gene overlap.';
                            $('#gssSpeciesWarningText').html(warnText);
                            $('#gssSpeciesWarning').show();
                        } else {
                            $('#gssSpeciesWarning').hide();
                        }

                        // Render set list
                        var html = '';
                        setsInfo.forEach(function(s) {
                            html += "<div class=\"gss-upload-item set-list-item\" data-name=\"" + s.name.replace(/"/g, "&quot;") + "\">" +
                                '<span>' + s.name.replace(/_/g, ' ') + '</span>' +
                                '<span class="set-list-item__meta">' + s.n_genes + ' genes</span></div>';
                        });
                        $('#gssUploadSetList').html(html);
                        $('#gssUploadResult').show();
                        gssSelectedUploadName = '';
                        gssSelectedUploadGenes = null;
                        $('#gssUploadSelectedInfo').hide();

                        // If only 1 set, auto-select it
                        if (setsInfo.length === 1) {
                            $('.gss-upload-item').first().click();
                        }
                    };
                    reader.readAsText(file);
                }

                // Click uploaded set
                $(document).on('click', '.gss-upload-item', function() {
                    var name = $(this).data('name');
                    $('.gss-upload-item').removeClass('selected');
                    $(this).addClass('selected');
                    gssSelectedUploadName = name;
                    gssSelectedUploadGenes = gssUploadedSets[name];
                    var genes = gssSelectedUploadGenes;
                    $('#gssUploadSelectedInfo').html('<strong>' + name.replace(/_/g, ' ') + '</strong> &mdash; ' + genes.length + ' genes: <span style="color:#666;">' + genes.slice(0, 15).join(', ') + (genes.length > 15 ? ', ...' : '') + '</span>').show();
                });

                // File input
                $('#gssFileInput').on('change', function() { handleGmtFile(this.files[0]); });

                // Drag & drop
                var dropZone = document.getElementById('gssDropZone');
                if (dropZone) {
                    dropZone.addEventListener('dragover', function(e) { e.preventDefault(); this.classList.add('drag-active'); });
                    dropZone.addEventListener('dragleave', function(e) { this.classList.remove('drag-active'); });
                    dropZone.addEventListener('drop', function(e) {
                        e.preventDefault();
                        this.classList.remove('drag-active');
                        if (e.dataTransfer.files.length > 0) handleGmtFile(e.dataTransfer.files[0]);
                    });
                }

                // ─── Run Scoring (all modes) ─────────────────
                function getSelectedGenes() {
                    if (gssCurrentMode === 'custom') {
                        var text = $('#gssGeneInput').val().trim();
                        return text ? text : null;
                    } else if (gssCurrentMode === 'msigdb') {
                        if (!gssSelectedMsigdbGenes || gssSelectedMsigdbGenes.length === 0) return null;
                        return gssSelectedMsigdbGenes.join(', ');
                    } else if (gssCurrentMode === 'upload') {
                        if (!gssSelectedUploadGenes || gssSelectedUploadGenes.length === 0) return null;
                        return gssSelectedUploadGenes.join(', ');
                    }
                    return null;
                }

                function getSelectedSetName() {
                    if (gssCurrentMode === 'msigdb') return gssSelectedMsigdbName;
                    if (gssCurrentMode === 'upload') return gssSelectedUploadName;
                    return 'Custom';
                }

                $('#gssRunBtn').click(function() {
                    var genes = getSelectedGenes();
                    if (!genes) {
                        var msgs = {
                            'custom': 'Please enter a gene set.',
                            'msigdb': 'Please select a gene set from the library.',
                            'upload': 'Please upload a GMT file and select a gene set.'
                        };
                        $('#gssError').text(msgs[gssCurrentMode] || 'No genes selected.').show();
                        return;
                    }

                    var groupBy = $('#gssGroupBy').val();
                    var method = $('#gssMethod').val();
                    var methodLabel = gssMethodNames[method] || method;
                    var setName = getSelectedSetName();
                    var btn = $(this);
                    btn.prop('disabled', true).css('opacity', '0.6');
                    $('#gssProgress').show();
                    $('#gssError').hide();
                    $('#gssGeneInfo').hide();
                    $('#gssViolinPlot').empty();

                    $.ajax({
                        url: contextPath + '/cpdb-api?action=geneset-score',
                        type: 'POST',
                        data: { said: said, genes: genes, group_by: groupBy, method: method },
                        dataType: 'json',
                        timeout: 300000,
                        success: function(data) {
                            btn.prop('disabled', false).css('opacity', '1');
                            $('#gssProgress').hide();

                            if (data.error) {
                                $('#gssError').text(data.error).show();
                                return;
                            }

                            // Show gene match info
                            var info = 'Method: ' + methodLabel;
                            if (setName !== 'Custom') info += ' | Set: ' + setName.replace(/_/g, ' ');
                            info += ' | Genes found: ' + data.genes_found.length;
                            if (data.genes_not_found && data.genes_not_found.length > 0) {
                                info += ' | Not found: ' + data.genes_not_found.join(', ');
                            }
                            info += ' | Grouped by: ' + data.group_by;
                            $('#gssGeneInfo').html(info).show();

                            var title = setName !== 'Custom' ? setName.replace(/_/g, ' ') : methodLabel;
                            renderGssViolin(data, title);
                        },
                        error: function(xhr) {
                            btn.prop('disabled', false).css('opacity', '1');
                            $('#gssProgress').hide();
                            $('#gssError').text('Request failed: ' + xhr.statusText).show();
                        }
                    });
                });

                function renderGssViolin(data, methodLabel) {
                    methodLabel = methodLabel || 'AUCell';
                    var cellTypes = data.cell_types;
                    var violinData = data.violin_data;

                    if (!cellTypes || cellTypes.length === 0) {
                        $('#gssViolinPlot').html('<div style="text-align:center; padding:2rem; color:#999;">No data to display</div>');
                        return;
                    }

                    var traces = [];
                    var colors = [
                        '#337ab7','#5b86e5','#36d1dc','#f5a623','#7b68ee',
                        '#2ecc71','#e74c3c','#9b59b6','#1abc9c','#f39c12',
                        '#3498db','#e67e22','#2c3e50','#16a085','#d35400',
                        '#8e44ad','#27ae60','#c0392b','#2980b9','#f1c40f'
                    ];

                    for (var i = 0; i < cellTypes.length; i++) {
                        var ct = cellTypes[i];
                        var vd = violinData[ct];
                        traces.push({
                            type: 'violin',
                            y: vd.values,
                            name: ct + ' (n=' + vd.n_cells + ')',
                            box: { visible: true, width: 0.1 },
                            meanline: { visible: true },
                            line: { color: colors[i % colors.length], width: 1.5 },
                            fillcolor: colors[i % colors.length],
                            opacity: 0.65,
                            spanmode: 'soft',
                            bandwidth: 0.05,
                            points: vd.n_cells <= 30 ? 'all' : false,
                            jitter: 0.3,
                            pointpos: -1.5,
                            marker: { size: 3, opacity: 0.5 },
                            scalemode: 'width',
                            width: 0.8
                        });
                    }

                    var h = Math.max(500, 50 + cellTypes.length * 8);
                    var layout = {
                        title: { text: methodLabel + ' Gene Set Score by Cell Type', font: { family: 'Nunito, sans-serif', size: 15 } },
                        yaxis: { title: methodLabel + ' Score', zeroline: false },
                        xaxis: { tickangle: -45, tickfont: { size: 8 }, automargin: true },
                        margin: { l: 60, r: 30, t: 50, b: 200 },
                        height: h,
                        showlegend: false,
                        violingap: 0.25,
                        violinmode: 'group'
                    };

                    Plotly.newPlot('gssViolinPlot', traces, layout, figConfig('geneset_violin_' + said, { responsive: true }));
                }

                // =========================================================================
                // Cell Proportion Charts
                // =========================================================================
                var proportionColors = [
                    '#337ab7','#5b86e5','#36d1dc','#f5a623','#7b68ee',
                    '#2ecc71','#e74c3c','#9b59b6','#1abc9c','#f39c12',
                    '#3498db','#e67e22','#2c3e50','#16a085','#d35400',
                    '#8e44ad','#27ae60','#c0392b','#2980b9','#f1c40f',
                    '#00bcd4','#ff5722','#795548','#607d8b','#4caf50',
                    '#ff9800','#673ab7','#009688','#cddc39','#ff4081',
                    '#00acc1','#8bc34a','#ffc107','#03a9f4','#e91e63',
                    '#9c27b0','#ffeb3b','#4dd0e1','#a1887f','#90a4ae'
                ];

                function loadCellProportion() {
                    var mapType = $('#proportionMapType').val();
                    var species = '<%= speciesVal %>';
                    $('#proportion-loading').show();
                    $('#proportion-charts').hide();
                    $('#proportion-error').hide();

                    $.getJSON('details.jsp', {
                        action: 'cell_proportion',
                        said: said,
                        gse: gse,
                        gsm: gsm,
                        map_type: mapType,
                        species: species
                    }).done(function(data) {
                        $('#proportion-loading').hide();
                        if (data.error) {
                            $('#proportion-error').text(data.error).show();
                            return;
                        }
                        $('#proportion-charts').show();
                        renderProportionCharts(data.cell_types, mapType);
                    }).fail(function(xhr) {
                        $('#proportion-loading').hide();
                        $('#proportion-error').text('Failed to load cell proportion data: ' + xhr.statusText).show();
                    });
                }

                function renderProportionCharts(cellTypes, mapType) {
                    var labels = Object.keys(cellTypes);
                    var values = Object.values(cellTypes);
                    var total = values.reduce(function(a, b) { return a + b; }, 0);
                    var colors = labels.map(function(_, i) { return proportionColors[i % proportionColors.length]; });

                    // Bar Chart (absolute counts)
                    var barTrace = {
                        type: 'bar',
                        x: labels,
                        y: values,
                        marker: { color: colors, line: { color: '#fff', width: 1 } },
                        hovertemplate: '<b>%{x}</b><br>Cells: %{y:,}<br>Proportion: %{customdata:.1%}<extra></extra>',
                        customdata: values.map(function(v) { return v / total; })
                    };

                    var barHeight = Math.max(400, labels.length > 15 ? 500 : 400);
                    var barLayout = {
                        title: { text: 'Absolute Cell Count (' + mapType.replace('_', ' ') + ')', font: { family: 'Nunito, sans-serif', size: 14 } },
                        xaxis: { tickangle: -45, tickfont: { size: labels.length > 20 ? 7 : 9 }, automargin: true },
                        yaxis: { title: 'Number of Cells', tickformat: ',d' },
                        margin: { l: 70, r: 20, t: 50, b: 180 },
                        height: barHeight,
                        plot_bgcolor: '#fff',
                        paper_bgcolor: '#fff',
                        font: { family: 'Nunito, sans-serif' }
                    };

                    Plotly.newPlot('proportionBarChart', [barTrace], barLayout, figConfig('cell_proportion_bar_' + said, {
                        responsive: true,
                        displayModeBar: true,
                        modeBarButtonsToRemove: ['lasso2d', 'select2d']
                    }));

                    // Donut Chart (relative proportion)
                    var donutTrace = {
                        type: 'pie',
                        labels: labels,
                        values: values,
                        hole: 0.45,
                        marker: { colors: colors, line: { color: '#fff', width: 1.5 } },
                        textinfo: labels.length > 15 ? 'percent' : 'label+percent',
                        textposition: labels.length > 15 ? 'inside' : 'auto',
                        textfont: { size: labels.length > 20 ? 8 : 10 },
                        hovertemplate: '<b>%{label}</b><br>Cells: %{value:,}<br>Proportion: %{percent}<extra></extra>',
                        sort: false
                    };

                    var donutLayout = {
                        title: { text: 'Relative Proportion', font: { family: 'Nunito, sans-serif', size: 14 } },
                        height: barHeight,
                        margin: { l: 20, r: 20, t: 50, b: 20 },
                        showlegend: false,
                        paper_bgcolor: '#fff',
                        font: { family: 'Nunito, sans-serif' },
                        annotations: [{
                            text: '<b>' + total.toLocaleString() + '</b><br>cells',
                            showarrow: false,
                            font: { size: 13, family: 'Nunito, sans-serif', color: '#555' },
                            x: 0.5, y: 0.5
                        }]
                    };

                    Plotly.newPlot('proportionDonutChart', [donutTrace], donutLayout, figConfig('cell_proportion_donut_' + said, {
                        responsive: true,
                        displayModeBar: true,
                        modeBarButtonsToRemove: ['lasso2d', 'select2d']
                    }));
                }

                loadCellProportion();
                $('#proportionMapType').on('change', loadCellProportion);

                // Initialize
                initCpdbCellTypes();
            });
        </script>
    </div>
</div>

<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
