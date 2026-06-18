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
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dataset Details - scSAID</title>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;500;600;700&family=Montserrat:wght@200;300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

    <!-- Stylesheets -->
    <link rel="stylesheet" href="CSS/design-system.css">
    <link rel="stylesheet" href="CSS/header.css">
    <link rel="stylesheet" href="CSS/details.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/jquery.dataTables.min.css">

    <!-- Scripts -->
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js"></script>
    <script src="https://cdn.plot.ly/plotly-2.20.0.min.js"></script>
</head>
<body style="background: #faf8f5;">

<!-- Header -->
<header class="site-header">
    <div class="container">
        <a href="index.jsp" class="site-logo">scSAID</a>
        <nav class="main-nav">
            <a href="index.jsp" class="main-nav__link">Home</a>
            <a href="browse.jsp" class="main-nav__link main-nav__link--active">Browse</a>
            <a href="gene-search.jsp" class="main-nav__link">Search</a>
            <a href="download.jsp" class="main-nav__link">Download</a>
            <div class="main-nav__item">
                <a href="help?topic=faq" class="main-nav__link">Help</a>
                <div class="main-nav__dropdown">
                    <a href="help?topic=faq" class="main-nav__dropdown-link">FAQ</a>
                    <a href="help?topic=methods" class="main-nav__dropdown-link">Methods</a>
                    <a href="help?topic=markers" class="main-nav__dropdown-link">Markers</a>
                    <a href="help?topic=pipeline" class="main-nav__dropdown-link">Pipeline</a>
                    <a href="help?topic=usage" class="main-nav__dropdown-link">Usage</a>
                </div>
            </div>
            <a href="feedback" class="main-nav__link">Feedback</a>
            <a href="contact" class="main-nav__link">Contact</a>
        </nav>
        <div class="header-icons">
            <a href="https://github.com/Dostoyevsky7/SkinDB_web" target="_blank" class="header-icon-link" title="View on GitHub">
                <svg class="github-icon" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                </svg>
            </a>
            <a href="https://zje.zju.edu.cn/zje/main.htm" target="_blank" class="header-icon-link" title="ZJE - Zhejiang University">
                <img src="images/ZJE_Logo.png" alt="ZJE - Zhejiang University" class="university-logo">
            </a>
        </div>
    </div>
</header>
<div class="details-box">
    <!-- Sidebar Navigation -->
    <aside class="sidebar">
        <h1 class="sidebar__title">Dataset Navigation</h1>
        <nav class="sidebar__nav">
            <a href="#ExperimentInformation" class="nav-item active">
                <svg class="nav-item__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="10"></circle>
                    <path d="M12 16v-4M12 8h.01"></path>
                </svg>
                General Information
            </a>
            <a href="#CellClustering" class="nav-item">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:16px;height:16px;">
                    <circle cx="7" cy="8" r="2.5" fill="currentColor" opacity="0.3"></circle><circle cx="16" cy="6" r="2" fill="currentColor" opacity="0.3"></circle><circle cx="12" cy="14" r="3" fill="currentColor" opacity="0.3"></circle><circle cx="5" cy="17" r="1.5" fill="currentColor" opacity="0.3"></circle><circle cx="19" cy="15" r="2" fill="currentColor" opacity="0.3"></circle>
                </svg>
                Cell Clustering
            </a>
            <a href="#DEGResults" class="nav-item">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:16px;height:16px;">
                    <rect x="3" y="3" width="18" height="18" rx="2"></rect><line x1="3" y1="9" x2="21" y2="9"></line><line x1="3" y1="15" x2="21" y2="15"></line><line x1="9" y1="3" x2="9" y2="21"></line>
                </svg>
                DEG Results
            </a>
            <a href="#GeneSetScoring" class="nav-item">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:16px;height:16px;">
                    <rect x="3" y="12" width="4" height="9" rx="1"></rect><rect x="10" y="7" width="4" height="14" rx="1"></rect><rect x="17" y="3" width="4" height="18" rx="1"></rect>
                </svg>
                Gene Set Scoring
            </a>
            <a href="#CellPhoneDBAnalysis" class="nav-item">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:16px;height:16px;">
                    <circle cx="5" cy="6" r="2"></circle><circle cx="19" cy="6" r="2"></circle><circle cx="12" cy="18" r="2"></circle><line x1="5" y1="8" x2="12" y2="16"></line><line x1="19" y1="8" x2="12" y2="16"></line><line x1="7" y1="6" x2="17" y2="6"></line>
                </svg>
                CellPhoneDB Analysis
            </a>
            <a href="#EnrichmentAnalysis" class="nav-item">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:16px;height:16px;">
                    <path d="M21 12a9 9 0 1 1-9-9"></path><path d="M21 3v9h-9"></path>
                </svg>
                Enrichment Analysis
            </a>
        </nav>
    </aside>
    <div class="basic"  id="ExperimentInformation">
        <div class="general_info" style="height: 600px;">
            <div class="header">General Information</div>
            <div class="general_info_part">
                <div style="width: 40%">
                    <div class="title_1">Overview<div class="separator"></div></div>

                    <div class="detail_container_1"><div class="subtitle">Data ID: </div><div class="text_2"><%= saidVal %></div></div>
                    <div class="detail_container_1"><div class="subtitle">GSE: </div><div class="text_2"><%= gseVal %></div></div>
                    <div class="detail_container_1"><div class="subtitle">GSM: </div><div class="text_2"><%= gsmVal %></div></div>
                    <div class="detail_container_1"><div class="subtitle">Species: </div><div class="text_2"><%= speciesVal %></div></div>
                    <div class="detail_container_1"><div class="subtitle">Condition: </div><div class="text_2"><%= conditionVal %></div></div>
                    <div class="detail_container_1"><div class="subtitle">Tissue: </div><div class="text_2"><%= tissueVal %></div></div>
                    <div class="detail_container_1"><div class="subtitle">Cells: </div><div class="text_2"><%= n_cellsVal %></div></div>
                    <div class="detail_container_1"><div class="subtitle">Age: </div><div class="text_2"><%= ageVal %></div></div>
                    <div class="detail_container_1"><div class="subtitle">Sex: </div><div class="text_2"><%= sexVal %></div></div>
                </div>
                <div style="width: 60%">
                    <div class="title_1">Experimental Design<div class="separator"></div></div>
                    <div id="geo-meta-container" style="max-height: 500px; overflow-y: auto; padding-right: 10px;">
                        <div id="geo-meta-loading" style="color:#999; font-size:0.9rem;">Loading study information...</div>
                        <div id="geo-meta-content" style="display:none;">
                            <div class="detail_container_2" style="margin-bottom:10px;">
                                <div class="subtitle" style="font-weight:600; color:#2c3e50;">Study Title</div>
                                <div id="geo-title" class="text_2" style="font-size:0.9rem; line-height:1.5; margin-top:4px;"></div>
                            </div>
                            <div class="detail_container_2" style="margin-bottom:10px;">
                                <div class="subtitle" style="font-weight:600; color:#2c3e50;">Summary</div>
                                <div id="geo-summary" class="text_2" style="font-size:0.85rem; line-height:1.6; margin-top:4px; text-align:justify;"></div>
                            </div>
                            <div class="detail_container_2" style="margin-bottom:10px;">
                                <div class="subtitle" style="font-weight:600; color:#2c3e50;">Overall Design</div>
                                <div id="geo-design" class="text_2" style="font-size:0.85rem; line-height:1.6; margin-top:4px; text-align:justify;"></div>
                            </div>
                            <div id="geo-pubmed-row" class="detail_container_2" style="display:none;">
                                <div class="subtitle" style="font-weight:600; color:#2c3e50;">PubMed</div>
                                <div id="geo-pubmed" class="text_2" style="font-size:0.85rem; margin-top:4px;"></div>
                            </div>
                        </div>
                        <div id="geo-meta-empty" style="display:none; color:#999; font-size:0.9rem;">
                            No GEO metadata available for this dataset.
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <div class="CellClustering" id="CellClustering">
            <div class="cluster">
                <div class="header">
                    <div class="header-content">
                        <div><div class="header-title">Cell Clustering</div></div>
                        <div class="umap-controls" style="display:flex; align-items:center; gap:12px;">
                            <label style="font-size:0.85rem; color:#666;">Color by:</label>
                            <select id="umapColorBy" class="elegant-select" style="min-width:160px;">
                                <option value="">Loading...</option>
                            </select>
                            <button id="downloadUmapPdf" class="export-btn" title="Download PDF">
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
                <div id="umap-container" style="width:100%; min-height:600px; display:flex; justify-content:center; align-items:center; background:#fff;">
                    <div id="umap-loading" style="text-align:center; color:#999;">
                        <div class="spinner" style="margin:0 auto 10px;"></div>
                        Loading UMAP...
                    </div>
                    <img id="umap-image" src="" alt="UMAP plot" style="display:none; max-width:100%; height:auto;">
                </div>
            </div>

            <div class="cluster" id="DEGResults">
                <div class="header">
                    <div class="header-content">
                        <div>
                            <div class="header-title">Differentially Expressed Genes</div>
                        </div>
                        <button id="exportExcelBtn" class="export-btn">
                            <svg class="export-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                                <polyline points="7 10 12 15 17 10"></polyline>
                                <line x1="12" y1="15" x2="12" y2="3"></line>
                            </svg>
                            Export Excel
                        </button>
                    </div>
                </div>
                <div class="panel-body">
                    <div class="deg-controls">
                        <div class="filter-grid">
                            <div class="filter-card">
                                <div class="filter-label">
                                    <span class="filter-name">p-value threshold</span>
                                    <span class="filter-value" id="pvalLabel">0.05</span>
                                </div>
                                <input type="range" id="pvalSlider" class="elegant-slider" min="0" max="0.1" step="0.001" value="0.05">
                                <div class="filter-hint">Maximum adjusted p-value</div>
                            </div>
                            <div class="filter-card">
                                <div class="filter-label">
                                    <span class="filter-name">Log fold change</span>
                                    <span class="filter-value" id="fcLabel">1.0</span>
                                </div>
                                <input type="range" id="fcSlider" class="elegant-slider" min="0" max="10" step="0.1" value="1.0">
                                <div class="filter-hint">Minimum log₂ fold change</div>
                            </div>
                            <div class="filter-card">
                                <div class="filter-label">
                                    <span class="filter-name">Cell type group</span>
                                </div>
                                <select id="groupSelect" class="elegant-select">
                                    <option value="">All groups</option>
                                </select>
                                <div class="filter-hint">Filter by cell type</div>
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
                                    <th>Group</th>
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
                            <div class="header-title">Gene Set Scoring (AUCell)</div>
                            <div class="header-subtitle">Score cells by a custom gene set using the AUCell algorithm</div>
                        </div>
                    </div>
                </div>
                <div class="panel-body" style="padding:1.5rem;">
                    <div style="display:flex; gap:1.5rem; flex-wrap:wrap; align-items:flex-end; margin-bottom:1rem;">
                        <div style="flex:1; min-width:300px;">
                            <label style="font-family:'Source Sans 3',sans-serif; font-size:0.85rem; color:#6b7c93; margin-bottom:0.4rem; display:block;">Gene Set (comma-separated)</label>
                            <textarea id="gssGeneInput" rows="2" placeholder="e.g. COL1A1, COL1A2, COL3A1, FN1, VIM, ACTA2" style="width:100%; padding:0.6rem 0.8rem; border:1.5px solid #e0dcd7; border-radius:8px; font-family:'Source Sans 3',sans-serif; font-size:0.9rem; resize:vertical; transition: border-color 0.2s;"></textarea>
                        </div>
                        <div style="min-width:140px;">
                            <label style="font-family:'Source Sans 3',sans-serif; font-size:0.85rem; color:#6b7c93; margin-bottom:0.4rem; display:block;">Group By</label>
                            <select id="gssGroupBy" style="width:100%; padding:0.6rem 0.8rem; border:1.5px solid #e0dcd7; border-radius:8px; font-family:'Source Sans 3',sans-serif; font-size:0.9rem; background:#fff; cursor:pointer;">
                                <option value="Fine_Map">Fine_Map</option>
                                <option value="Gross_Map">Gross_Map</option>
                            </select>
                        </div>
                        <div>
                            <button id="gssRunBtn" style="padding:0.7rem 1.5rem; background:linear-gradient(135deg, #5b86e5 0%, #36d1dc 100%); color:#fff; border:none; border-radius:8px; font-family:'Montserrat',sans-serif; font-weight:600; font-size:0.9rem; cursor:pointer; transition:all 0.2s; white-space:nowrap;" onmouseover="this.style.transform='translateY(-1px)'; this.style.boxShadow='0 4px 12px rgba(91,134,229,0.35)';" onmouseout="this.style.transform=''; this.style.boxShadow='';">
                                Run AUCell
                            </button>
                        </div>
                    </div>
                    <div id="gssGeneInfo" style="font-family:'Source Sans 3',sans-serif; font-size:0.82rem; color:#8b95a5; margin-bottom:1rem; display:none;"></div>
                    <div id="gssProgress" style="display:none; text-align:center; padding:2rem; color:#6b7c93; font-family:'Source Sans 3',sans-serif;">
                        <div style="margin-bottom:0.5rem;">Running AUCell scoring...</div>
                        <div style="width:200px; height:4px; background:#eee; border-radius:2px; margin:0 auto;"><div id="gssProgressBar" style="width:30%; height:100%; background:linear-gradient(90deg, #5b86e5, #36d1dc); border-radius:2px; transition:width 0.3s;"></div></div>
                    </div>
                    <div id="gssError" style="display:none; padding:1rem; background:#fff5f5; border:1px solid #fed7d7; border-radius:8px; color:#c53030; font-family:'Source Sans 3',sans-serif; font-size:0.9rem; margin-bottom:1rem;"></div>
                    <div id="gssViolinPlot" style="min-height:200px;"></div>
                </div>
            </div>

            <div class="cluster" id="CellPhoneDBAnalysis">
                <div class="header">
                    <div class="header-content">
                        <div>
                            <div class="header-title">CellPhoneDB Cell-Cell Communication Analysis</div>
                        </div>
                        <span class="cpdb-badge">Dynamic Analysis</span>
                    </div>
                </div>
                <div class="panel-body">
                    <!-- Cell Type Selection -->
                    <div class="cpdb-config-section">
                        <div style="display:flex; align-items:center; gap:16px; margin-bottom:12px; flex-wrap:wrap;">
                            <h3 class="cpdb-section-title" style="margin:0;">Cell-Cell Communication</h3>
                            <div class="cpdb-mode-toggle" style="margin:0;">
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

                        <!-- All Combinations mode: single checkbox list -->
                        <div id="cpdbAllControls">
                            <p class="cpdb-section-desc">Select 2 or more cell types to analyze ligand-receptor interactions</p>
                            <div id="cpdbCellTypeList" style="max-height:300px; overflow-y:auto; border:1px solid #e0e0e0; border-radius:8px; padding:8px 12px; background:#fafafa;">
                                <div style="color:#999;">Loading cell types...</div>
                            </div>
                            <div style="margin-top:6px; font-size:0.8rem; color:#888;">
                                <span id="cpdbSelectedCount">0</span> cell types selected
                                <a href="javascript:void(0)" id="cpdbSelectAll" style="margin-left:12px; color:#3498db;">Select All</a>
                                <a href="javascript:void(0)" id="cpdbClearAll" style="margin-left:8px; color:#e74c3c;">Clear</a>
                            </div>
                        </div>

                        <!-- Sender/Receiver mode: two checkbox lists side by side -->
                        <div id="cpdbDirectedControls" style="display:none;">
                            <p class="cpdb-section-desc">Assign cell types as senders (left) and receivers (right)</p>
                            <div style="display:flex; gap:16px; align-items:stretch;">
                                <div style="flex:1; min-width:0;">
                                    <label style="font-weight:600; color:#2c3e50; font-size:0.9rem; display:block; margin-bottom:6px;">Sender Cell Types</label>
                                    <div id="cpdbSenderList" style="max-height:280px; overflow-y:auto; border:1px solid #e0e0e0; border-radius:8px; padding:8px 12px; background:#fafafa;">
                                    </div>
                                    <div style="margin-top:4px; font-size:0.75rem; color:#888;"><span id="cpdbSenderCount">0</span> selected</div>
                                </div>
                                <div style="display:flex; align-items:center; font-size:2rem; color:#999; padding:0 8px;">→</div>
                                <div style="flex:1; min-width:0;">
                                    <label style="font-weight:600; color:#2c3e50; font-size:0.9rem; display:block; margin-bottom:6px;">Receiver Cell Types</label>
                                    <div id="cpdbReceiverList" style="max-height:280px; overflow-y:auto; border:1px solid #e0e0e0; border-radius:8px; padding:8px 12px; background:#fafafa;">
                                    </div>
                                    <div style="margin-top:4px; font-size:0.75rem; color:#888;"><span id="cpdbReceiverCount">0</span> selected</div>
                                </div>
                            </div>
                        </div>

                        <button id="runCpdbAnalysisBtn" class="generate-btn" style="margin-top:16px;">
                            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <polygon points="5 3 19 12 5 21 5 3"></polygon>
                            </svg>
                            Run Analysis
                        </button>
                    </div>

                    <!-- Progress Section -->
                    <div id="cpdbProgressSection" class="cpdb-progress" style="display:none;">
                        <div class="cpdb-progress-bar">
                            <div class="cpdb-progress-fill"></div>
                        </div>
                        <p class="cpdb-progress-text">Running CellPhoneDB analysis...</p>
                        <p class="cpdb-progress-hint">This may take several minutes for large datasets</p>
                    </div>

                    <!-- Results Section -->
                    <div id="cpdbResultsSection" style="display:none;">
                        <div class="cpdb-results-tabs">
                            <button class="cpdb-tab active" data-tab="heatmap">Interaction Heatmap</button>
                            <button class="cpdb-tab" data-tab="dotplot">Dot Plot</button>
                            <button class="cpdb-tab" data-tab="table">Results Table</button>
                        </div>

                        <div id="cpdbHeatmapTab" class="cpdb-tab-content active">
                            <div id="cpdbHeatmapPlot" class="cpdb-plot-container"></div>
                        </div>

                        <div id="cpdbDotplotTab" class="cpdb-tab-content">
                            <div id="cpdbDotplot" class="cpdb-plot-container"></div>
                        </div>

                        <div id="cpdbTableTab" class="cpdb-tab-content">
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
                        <div><div class="header-title">Enrichment Analysis (GSEA)</div></div>
                    </div>
                </div>
                <div class="panel-body">
                    <div style="display:flex; align-items:center; gap:16px; flex-wrap:wrap; margin-bottom:16px; padding:12px 16px; background:#f8f9fa; border-radius:8px; border:1px solid #e9ecef;">
                        <div style="display:flex; align-items:center; gap:6px;">
                            <label style="font-size:0.85rem; color:#555; font-weight:500;">Gene Set:</label>
                            <select id="enrichGeneSet" class="elegant-select" style="min-width:220px;">
                                <option value="">Loading...</option>
                            </select>
                        </div>
                        <div style="display:flex; align-items:center; gap:6px;">
                            <label style="font-size:0.85rem; color:#555; font-weight:500;">Top:</label>
                            <select id="enrichTopN" class="elegant-select" style="min-width:80px;">
                                <option value="10" selected>10</option>
                                <option value="20">20</option>
                                <option value="30">30</option>
                            </select>
                        </div>
                        <div style="display:flex; align-items:center; gap:6px;">
                            <label style="font-size:0.85rem; color:#555; font-weight:500;">Filter:</label>
                            <select id="enrichFilter" class="elegant-select" style="min-width:130px;">
                                <option value="all" selected>All results</option>
                                <option value="significant">Significant only</option>
                            </select>
                        </div>
                    </div>
                    <div id="enrich-loading" style="text-align:center; padding:40px; color:#999; display:none;">
                        <div class="spinner" style="margin:0 auto 10px;"></div>
                        Loading enrichment data...
                    </div>
                    <div id="enrich-empty" style="text-align:center; padding:40px; color:#999; display:none;">
                        No enrichment data available for this dataset.
                    </div>
                    <div id="enrichChart" style="width:100%; min-height:500px;"></div>
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

                function initGroupOptions() {
                    console.log("🔍 Initializing DEG group dropdown");

                    $.getJSON(contextPath + '/deg', { said: said, pval: 1.0, fc: 0.0 })
                        .done(function(data){
                            console.log("✅ DEG group data fetched");
                            const groups = Array.from(new Set(data.map(r => typeof r.group === "string" ? r.group.trim() : null).filter(g => g)));
                            const select = $('#groupSelect');
                            select.empty().append('<option value="">All</option>');
                            groups.forEach(g => select.append('<option value="' + g + '">' + g + '</option>'));
                            console.log("✅ DEG group dropdown populated");
                        })
                        .fail(function(xhr){ console.error("❌ DEG group data failed:", xhr.status, xhr.statusText); });
                }

                function loadDEG(){
                    const pval = $('#pvalSlider').val();
                    const fc = $('#fcSlider').val();
                    const group = $('#groupSelect').val();
                    $('#pvalLabel').text(pval);
                    $('#fcLabel').text(fc);
                    const params = { said: said, pval: pval, fc: fc };
                    if (group) params.group = group;
                    console.log("📡 Requesting DEG data:", params);
                    $.getJSON(contextPath + '/deg', params)
                        .done(function(data){
                            console.log("✅ DEG data received");
                            table.clear();

                            data.forEach(r => table.row.add([r.gene, r.logfoldchanges, r.pvals_adj, r.scores, r.group]));
                            table.draw();
                        })
                        .fail(function(xhr){ console.error("❌ DEG data loading failed:", xhr.status, xhr.statusText); });
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
                        $('#umap-loading').html('<p style="color:#c00;">Failed to load UMAP image.</p>');
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

                initGroupOptions();
                loadDEG();
                $('#pvalSlider, #fcSlider, #groupSelect').on('input change', loadDEG);
                $('#exportExcelBtn').on('click', exportTableToExcel);

                // =========================================================================
                // =========================================================================
                // EXPERIMENTAL DESIGN (GEO Metadata)
                // =========================================================================
                $.getJSON(contextPath + '/geo_meta', { said: said })
                    .done(function(data) {
                        $('#geo-meta-loading').hide();
                        if (data && (data.title || data.summary || data.overall_design)) {
                            $('#geo-title').text(data.title || 'N/A');
                            $('#geo-summary').text(data.summary || 'N/A');
                            $('#geo-design').text(data.overall_design || 'N/A');
                            if (data.pubmed_ids && data.pubmed_ids.length > 0) {
                                var links = data.pubmed_ids.map(function(pmid) {
                                    return '<a href="https://pubmed.ncbi.nlm.nih.gov/' + pmid + '/" target="_blank" style="color:#2471a3;">PMID: ' + pmid + '</a>';
                                });
                                $('#geo-pubmed').html(links.join(', '));
                                $('#geo-pubmed-row').show();
                            }
                            $('#geo-meta-content').show();
                        } else {
                            $('#geo-meta-empty').show();
                        }
                    })
                    .fail(function() {
                        $('#geo-meta-loading').hide();
                        $('#geo-meta-empty').show();
                    });

                // Enrichment Analysis - Horizontal Bar Chart
                // =========================================================================
                var enrichAllData = [];

                function loadEnrichGeneSets() {
                    $.getJSON(contextPath + '/enrichment', { said: said, action: 'list' })
                        .done(function(data) {
                            var select = $('#enrichGeneSet');
                            select.empty();
                            if (data.gene_sets && data.gene_sets.length > 0) {
                                data.gene_sets.forEach(function(gs) {
                                    select.append('<option value="' + gs.label + '">' + gs.name + '</option>');
                                });
                                loadEnrichData();
                            } else {
                                select.append('<option value="">No enrichment data</option>');
                                $('#enrich-empty').show();
                            }
                        })
                        .fail(function() {
                            $('#enrichGeneSet').html('<option value="">Error loading</option>');
                        });
                }

                function loadEnrichData() {
                    var geneSet = $('#enrichGeneSet').val();
                    var filter = $('#enrichFilter').val();
                    if (!geneSet) return;

                    $('#enrich-loading').show();
                    $('#enrich-empty').hide();
                    $('#enrichChart').empty();

                    $.getJSON(contextPath + '/enrichment', { said: said, gene_set: geneSet, filter: filter })
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
                        font: { family: 'Montserrat, sans-serif' },
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

                    Plotly.newPlot('enrichChart', [trace], layout, {
                        responsive: true,
                        displayModeBar: true,
                        modeBarButtonsToRemove: ['lasso2d', 'select2d'],
                        toImageButtonOptions: { format: 'svg', filename: 'GSEA_' + said }
                    });
                }

                loadEnrichGeneSets();
                $('#enrichGeneSet, #enrichFilter').on('change', loadEnrichData);
                $('#enrichTopN').on('change', renderEnrichChart);

                // =========================================================================
                // SECTION D: CELLPHONEDB DYNAMIC ANALYSIS
                // =========================================================================

                var cpdbAllCellTypes = [];

                function buildCheckboxList(containerId, cellTypes, cellCounts, prefix) {
                    var html = '';
                    cellTypes.forEach(function(ct, i) {
                        var count = cellCounts[ct] || 0;
                        var id = prefix + '_' + i;
                        html += '<label style="display:flex; align-items:center; padding:4px 0; cursor:pointer; gap:8px; font-size:0.85rem;" title="' + ct + ' (' + count + ' cells)">' +
                            '<input type="checkbox" value="' + ct.replace(/"/g, '&quot;') + '" id="' + id + '" style="margin:0; width:16px; height:16px; cursor:pointer;">' +
                            '<span style="flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">' + ct + '</span>' +
                            '<span style="color:#aaa; font-size:0.75rem; flex-shrink:0;">' + count + '</span>' +
                            '</label>';
                    });
                    $('#' + containerId).html(html);
                }

                function updateCounts() {
                    $('#cpdbSelectedCount').text($('#cpdbCellTypeList input:checked').length);
                    $('#cpdbSenderCount').text($('#cpdbSenderList input:checked').length);
                    $('#cpdbReceiverCount').text($('#cpdbReceiverList input:checked').length);
                }

                function initCpdbCellTypes() {
                    $.getJSON(contextPath + '/cpdb-api?action=cell-types', { said: said })
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
                        })
                        .fail(function() {
                            $('#cpdbCellTypeList').html('<div style="color:#c00;">Failed to load cell types</div>');
                        });
                }

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
                    $('.cpdb-progress-fill').css('width', '10%');

                    console.log("📡 Starting CPDB analysis:", params);

                    $.ajax({
                        url: contextPath + '/cpdb-api?action=run-analysis',
                        type: 'POST',
                        data: {
                            said: said,
                            cell_types: JSON.stringify(selectedTypes),
                            senders: mode === 'directed' ? JSON.stringify(senderTypes) : null,
                            receivers: mode === 'directed' ? JSON.stringify(receiverTypes) : null
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
                            } else {
                                // Update progress bar if available
                                if (data.progress) {
                                    $('.cpdb-progress-fill').css('width', data.progress + '%');
                                }
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
                            [0, '#faf8f5'],
                            [0.5, '#e8927c'],
                            [1, '#8B0000']
                        ],
                        hoverongaps: false,
                        hovertemplate: 'Sender: %{x}<br>Receiver: %{y}<br>Significant interactions: %{z}<extra></extra>'
                    };

                    var el = document.getElementById('cpdbHeatmapPlot');
                    var w = Math.max(el.offsetWidth - 40, 500);
                    var h = Math.max(heatmapData.y.length * 40 + 250, 500);

                    var layout = {
                        title: 'Significant Interactions Between Cell Types',
                        font: { family: 'Montserrat, sans-serif' },
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

                    Plotly.newPlot('cpdbHeatmapPlot', [trace], layout, { responsive: true });
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
                        font: { family: 'Montserrat, sans-serif' },
                        width: w,
                        height: h,
                        xaxis: {
                            title: 'Cell Type Pairs',
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

                    Plotly.newPlot('cpdbDotplot', [trace], layout, { responsive: true });
                }

                // Populate results table
                function populateCpdbTable(interactions) {
                    var tbody = $('#cpdbResultsTable tbody');
                    tbody.empty();

                    if (!interactions || interactions.length === 0) {
                        tbody.append('<tr><td colspan="5" style="text-align:center; color:#999;">No significant interactions found</td></tr>');
                        return;
                    }

                    interactions.forEach(function(row) {
                        var pClass = row.pvalue < 0.01 ? 'color:#c0392b; font-weight:600;' : (row.pvalue < 0.05 ? 'color:#e67e22;' : '');
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
                }

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

                // ─── Gene Set Scoring (AUCell) ─────────────────────────
                $('#gssRunBtn').click(function() {
                    var genes = $('#gssGeneInput').val().trim();
                    if (!genes) {
                        $('#gssError').text('Please enter a gene set.').show();
                        return;
                    }

                    var groupBy = $('#gssGroupBy').val();
                    var btn = $(this);
                    btn.prop('disabled', true).css('opacity', '0.6');
                    $('#gssProgress').show();
                    $('#gssError').hide();
                    $('#gssGeneInfo').hide();
                    $('#gssViolinPlot').empty();

                    $.ajax({
                        url: contextPath + '/cpdb-api?action=geneset-score',
                        type: 'POST',
                        data: { said: said, genes: genes, group_by: groupBy },
                        dataType: 'json',
                        timeout: 120000,
                        success: function(data) {
                            btn.prop('disabled', false).css('opacity', '1');
                            $('#gssProgress').hide();

                            if (data.error) {
                                $('#gssError').text(data.error).show();
                                return;
                            }

                            // Show gene match info
                            var info = 'Genes found: ' + data.genes_found.length;
                            if (data.genes_not_found && data.genes_not_found.length > 0) {
                                info += ' | Not found: ' + data.genes_not_found.join(', ');
                            }
                            info += ' | Grouped by: ' + data.group_by;
                            $('#gssGeneInfo').html(info).show();

                            renderGssViolin(data);
                        },
                        error: function(xhr) {
                            btn.prop('disabled', false).css('opacity', '1');
                            $('#gssProgress').hide();
                            $('#gssError').text('Request failed: ' + xhr.statusText).show();
                        }
                    });
                });

                function renderGssViolin(data) {
                    var cellTypes = data.cell_types;
                    var violinData = data.violin_data;

                    if (!cellTypes || cellTypes.length === 0) {
                        $('#gssViolinPlot').html('<div style="text-align:center; padding:2rem; color:#999;">No data to display</div>');
                        return;
                    }

                    var traces = [];
                    var colors = [
                        '#e8927c','#5b86e5','#36d1dc','#f5a623','#7b68ee',
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
                        title: { text: 'AUCell Gene Set Score by Cell Type', font: { family: 'Montserrat, sans-serif', size: 15 } },
                        yaxis: { title: 'AUCell Score', zeroline: false },
                        xaxis: { tickangle: -45, tickfont: { size: 8 }, automargin: true },
                        margin: { l: 60, r: 30, t: 50, b: 200 },
                        height: h,
                        showlegend: false,
                        violingap: 0.25,
                        violinmode: 'group'
                    };

                    Plotly.newPlot('gssViolinPlot', traces, layout, { responsive: true });
                }

                // Initialize
                initCpdbCellTypes();
            });
        </script>
    </div>
</div>

</body>
</html>
