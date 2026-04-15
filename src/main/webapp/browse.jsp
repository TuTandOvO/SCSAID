<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%@ page import="java.io.BufferedReader, java.io.File, java.io.FileReader, java.util.ArrayList, java.util.List, java.util.Map, java.util.HashMap, java.util.Set, java.util.TreeSet, Utils.DataPathResolver" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Browse Datasets - scSAID</title>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;500;600;700&family=Montserrat:wght@200;300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

    <!-- Design System -->
    <link rel="stylesheet" href="CSS/design-system.css">
    <link rel="stylesheet" href="CSS/header.css">
    <link rel="stylesheet" href="CSS/animations.css">
    <link rel="stylesheet" href="CSS/construction-modal-simple.css">

    <style>
        /* ==========================================================================
           Browse Page Specific Styles
           ========================================================================== */

        body {
            background-color: #faf8f5;
        }

        /* Page Layout */
        .browse-page {
            min-height: 100vh;
            padding-top: 72px;
        }

        /* Page Header */
        .page-header {
            background: #1a2332;
            padding: 4rem 0;
            margin-bottom: 3rem;
        }

        .page-header__content {
            max-width: 1400px;
            margin: 0 auto;
            padding: 0 2rem;
        }

        .page-header__eyebrow {
            display: inline-block;
            font-size: 0.75rem;
            font-weight: 700;
            letter-spacing: 0.15em;
            text-transform: uppercase;
            color: #d4a574;
            margin-bottom: 1rem;
        }

        .page-header__title {
            font-family: 'Cormorant Garamond', Georgia, serif;
            font-size: clamp(2rem, 4vw, 3rem);
            font-weight: 500;
            color: #ffffff;
            margin: 0 0 1rem;
        }

        .page-header__description {
            font-size: 1.1rem;
            color: rgba(255, 255, 255, 0.7);
            max-width: 600px;
            margin: 0;
        }

        /* Main Content */
        .browse-content {
            max-width: 1400px;
            margin: 0 auto;
            padding: 0 2rem 4rem;
        }

        /* Table Card */
        .table-card {
            background: #ffffff;
            border-radius: 16px;
            box-shadow: 0 4px 12px rgba(26, 35, 50, 0.08);
            overflow: hidden;
        }

        .table-card__header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1.5rem 2rem;
            border-bottom: 1px solid #e5e0d8;
        }

        .table-card__title {
            font-family: 'Cormorant Garamond', Georgia, serif;
            font-size: 1.5rem;
            font-weight: 500;
            color: #1a2332;
            margin: 0;
        }

        .table-card__actions {
            display: flex;
            gap: 1rem;
            align-items: center;
        }

        /* Enhanced Table */
        .data-table-wrapper {
            overflow-x: auto;
        }

        .browse-table {
            width: 100%;
            border-collapse: collapse;
            font-family: 'Montserrat', sans-serif;
            font-size: 0.9rem;
        }

        .sortable-th {
            cursor: pointer;
            user-select: none;
        }
        .sort-link {
            color: inherit;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 4px;
            white-space: nowrap;
        }
        .sort-link:hover {
            color: #3498db;
        }
        .sort-arrow {
            font-size: 0.7em;
            opacity: 0.7;
        }
        .sortable-th.sorted {
            color: #2c3e50;
        }
        .sortable-th.sorted .sort-arrow {
            opacity: 1;
            color: #3498db;
        }
        .browse-table thead {
            background: #1a2332;
        }

        .browse-table th {
            padding: 1rem 1.25rem;
            text-align: left;
            font-weight: 600;
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            color: #ffffff;
            white-space: nowrap;
        }

        .browse-table th:first-child {
            padding-left: 2rem;
        }

        .browse-table th:last-child {
            padding-right: 2rem;
        }

        .browse-table td {
            padding: 1rem 1.25rem;
            border-bottom: 1px solid #e5e0d8;
            color: #5a6473;
            vertical-align: middle;
        }

        .browse-table td:first-child {
            padding-left: 2rem;
        }

        .browse-table td:last-child {
            padding-right: 2rem;
        }

        .browse-table tbody tr {
            transition: all 0.15s ease;
        }

        .browse-table tbody tr:hover {
            background-color: #faf8f5;
        }

        .browse-table tbody tr:last-child td {
            border-bottom: none;
        }

        /* Cell styling */
        .browse-table .cell-id {
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.85rem;
            color: #1a2332;
            font-weight: 500;
        }

        .browse-table .cell-link {
            color: #e8927c;
            font-weight: 600;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            transition: all 0.15s ease;
        }

        .browse-table .cell-link:hover {
            color: #d4755d;
        }

        .browse-table .cell-link svg {
            width: 16px;
            height: 16px;
            transition: transform 0.15s ease;
        }

        .browse-table .cell-link:hover svg {
            transform: translateX(3px);
        }

        /* Species Badge */
        .species-badge {
            display: inline-flex;
            align-items: center;
            padding: 0.25rem 0.75rem;
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            border-radius: 20px;
        }

        .species-badge--human {
            background: rgba(232, 146, 124, 0.15);
            color: #d4755d;
        }

        .species-badge--mouse {
            background: rgba(212, 165, 116, 0.2);
            color: #b8864a;
        }

        /* Checkbox */
        .browse-table input[type="checkbox"] {
            width: 18px;
            height: 18px;
            accent-color: #e8927c;
            cursor: pointer;
        }

        /* Selected row */
        .browse-table tbody tr.selected-row {
            background-color: rgba(232, 146, 124, 0.08);
        }

        .browse-table tbody tr.selected-row td:first-child {
            box-shadow: inset 3px 0 0 #e8927c;
        }

        /* Pagination */
        .table-card__footer {
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 1.5rem 2rem;
            border-top: 1px solid #e5e0d8;
            background: #faf8f5;
        }

        .pagination {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            margin: 0;
        }

        .pagination__btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-width: 40px;
            height: 40px;
            padding: 0 1rem;
            font-family: 'Montserrat', sans-serif;
            font-size: 0.9rem;
            font-weight: 500;
            color: #5a6473;
            background: #ffffff;
            border: 1px solid #e5e0d8;
            border-radius: 8px;
            cursor: pointer;
            text-decoration: none;
            transition: all 0.15s ease;
        }

        .pagination__btn:hover:not(.pagination__btn--disabled) {
            color: #e8927c;
            border-color: #e8927c;
        }

        .pagination__btn--disabled {
            opacity: 0.4;
            cursor: not-allowed;
        }

        .pagination__input-group {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            margin: 0 0.5rem;
        }

        .pagination__label {
            font-size: 0.9rem;
            color: #5a6473;
        }

        .pagination__input {
            width: 60px;
            height: 40px;
            text-align: center;
            font-family: 'Montserrat', sans-serif;
            font-size: 0.9rem;
            border: 1px solid #e5e0d8;
            border-radius: 8px;
            outline: none;
            transition: all 0.15s ease;
        }

        .pagination__input:focus {
            border-color: #e8927c;
            box-shadow: 0 0 0 3px rgba(232, 146, 124, 0.15);
        }

        /* UMAP Result Container */
        .umap-container {
            margin-top: 2rem;
            padding: 2rem;
            background: #ffffff;
            border-radius: 16px;
            box-shadow: 0 4px 12px rgba(26, 35, 50, 0.08);
            text-align: center;
        }

        .umap-container__title {
            font-family: 'Cormorant Garamond', Georgia, serif;
            font-size: 1.25rem;
            font-weight: 500;
            color: #1a2332;
            margin-bottom: 1rem;
        }

        .umap-container img {
            max-width: 100%;
            border-radius: 8px;
            border: 1px solid #e5e0d8;
        }

        /* Loading Indicator */
        .loading-indicator {
            display: none;
            flex-direction: column;
            align-items: center;
            gap: 1rem;
            padding: 3rem;
        }

        .loading-indicator__spinner {
            width: 48px;
            height: 48px;
            border: 3px solid #e5e0d8;
            border-top-color: #e8927c;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        .loading-indicator__text {
            font-size: 0.95rem;
            color: #5a6473;
        }

        /* Error Message */
        .error-message {
            padding: 1rem 1.5rem;
            background: rgba(220, 53, 69, 0.1);
            color: #dc3545;
            border-radius: 8px;
            margin: 2rem;
            text-align: center;
        }

        /* Filter Bar */
        .filter-bar {
            display: flex;
            flex-wrap: wrap;
            gap: 1rem;
            padding: 1.5rem 2rem;
            background: #f5f3f0;
            border-bottom: 1px solid #e5e0d8;
            align-items: flex-end;
        }

        .filter-group {
            display: flex;
            flex-direction: column;
            gap: 0.4rem;
        }

        .filter-group__label {
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: #5a6473;
        }

        .filter-group__select {
            min-width: 160px;
            padding: 0.65rem 2.5rem 0.65rem 1rem;
            font-family: 'Montserrat', sans-serif;
            font-size: 0.9rem;
            color: #1a2332;
            background: #ffffff url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%235a6473' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E") no-repeat right 1rem center;
            border: 1px solid #e5e0d8;
            border-radius: 8px;
            cursor: pointer;
            appearance: none;
            -webkit-appearance: none;
            transition: all 0.15s ease;
        }

        .filter-group__select:hover {
            border-color: #d4a574;
        }

        .filter-group__select:focus {
            outline: none;
            border-color: #e8927c;
            box-shadow: 0 0 0 3px rgba(232, 146, 124, 0.15);
        }

        .filter-bar__actions {
            display: flex;
            gap: 0.75rem;
            margin-left: auto;
            align-items: flex-end;
        }

        .filter-bar__btn {
            padding: 0.65rem 1.25rem;
            font-family: 'Montserrat', sans-serif;
            font-size: 0.85rem;
            font-weight: 600;
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.15s ease;
        }

        .filter-bar__btn--clear {
            background: transparent;
            color: #5a6473;
            border: 1px solid #e5e0d8;
        }

        .filter-bar__btn--clear:hover {
            color: #1a2332;
            border-color: #5a6473;
        }

        .filter-count {
            font-size: 0.9rem;
            color: #5a6473;
            padding: 0.65rem 0;
        }

        .filter-count strong {
            color: #e8927c;
            font-weight: 600;
        }

        /* Hidden row (filtered out) */
        .browse-table tbody tr.filtered-out {
            display: none;
        }

        /* Responsive */
        @media (max-width: 768px) {
            .page-header {
                padding: 3rem 0;
            }

            .browse-content {
                padding: 0 1rem 3rem;
            }

            .table-card__header {
                flex-direction: column;
                gap: 1rem;
                align-items: flex-start;
            }

            .browse-table th,
            .browse-table td {
                padding: 0.75rem 1rem;
            }

            .browse-table th:first-child,
            .browse-table td:first-child {
                padding-left: 1rem;
            }

            .filter-bar {
                padding: 1rem;
            }

            .filter-group__select {
                min-width: 140px;
            }

            .filter-bar__actions {
                width: 100%;
                margin-left: 0;
                margin-top: 0.5rem;
            }
        }
    </style>
    <script src="JS/micro-interactions.js"></script>
</head>
<body class="content-fade-in">

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

<main class="browse-page">
    <!-- Page Header -->
    <div class="page-header">
        <div class="page-header__content">
            <span class="page-header__eyebrow">Data Explorer</span>
            <h1 class="page-header__title">Browse Datasets</h1>
            <p class="page-header__description">
                Explore our comprehensive collection of single-cell RNA sequencing datasets from skin and appendage tissues.
            </p>
        </div>
    </div>

    <!-- Main Content -->
    <div class="browse-content">
        <%
            // Resolve CSV paths from configured data roots. Defaults: /opt/SkinDB, /root/SkinDB
            File humanFile = DataPathResolver.resolveReadableFile(application, "human/human_obs_by_batch.csv");
            File mouseFile = DataPathResolver.resolveReadableFile(application, "mouse/mouse_obs_by_batch.csv");
            String humanCsvPath = humanFile.getAbsolutePath();
            String mouseCsvPath = mouseFile.getAbsolutePath();

            // Get filter parameters from URL
            String filterSpecies = request.getParameter("species");
            String filterCondition = request.getParameter("condition");
            String filterTissue = request.getParameter("tissue");
            if (filterSpecies == null) filterSpecies = "";
            if (filterCondition == null) filterCondition = "";
            if (filterTissue == null) filterTissue = "";

            // Sort parameters
            String sortCol = request.getParameter("sort");
            String sortOrder = request.getParameter("order");
            if (sortCol == null || sortCol.isEmpty()) sortCol = "said";
            if (sortOrder == null || sortOrder.isEmpty()) sortOrder = "asc";
            final String finalSortCol = sortCol;
            final String finalSortOrder = sortOrder;

            // Load all data from CSV files
            List<Map<String, String>> allData = new ArrayList<Map<String, String>>();
            Set<String> allTissues = new TreeSet<String>(); // For populating dropdown
            Set<String> allConditions = new TreeSet<String>(); // For populating dropdown
            BufferedReader reader = null;
            String dataLoadError = null;

            if (!humanFile.exists() || !humanFile.canRead()) {
                dataLoadError = "Human dataset file not accessible: " + humanCsvPath
                        + " (tried: " + String.join(", ", DataPathResolver.getCandidateFilePaths(application, "human/human_obs_by_batch.csv")) + ")";
            } else if (!mouseFile.exists() || !mouseFile.canRead()) {
                dataLoadError = "Mouse dataset file not accessible: " + mouseCsvPath
                        + " (tried: " + String.join(", ", DataPathResolver.getCandidateFilePaths(application, "mouse/mouse_obs_by_batch.csv")) + ")";
            } else {
                try {
                // Load human data
                reader = new BufferedReader(new FileReader(humanCsvPath));
                String headerLine = reader.readLine(); // Skip header
                String line;
                while ((line = reader.readLine()) != null) {
                    String[] parts = line.split(",", -1);
                    if (parts.length >= 11) {
                        Map<String, String> row = new HashMap<String, String>();
                        row.put("said", parts[10]);      // said column
                        row.put("gse", parts[9]);        // GSE column
                        row.put("gsm", parts[5]);        // GSM column
                        row.put("species", "Human");
                        row.put("n_cells", parts[1]);    // n_cells column
                        row.put("condition", parts[2]);  // condition column
                        row.put("age", parts[3]);        // Age column
                        row.put("sex", parts[4]);        // sex column
                        row.put("tissue", parts[6]);     // Skin_location column

                        // Collect all tissues and conditions for dropdown
                        if (parts[6] != null && !parts[6].trim().isEmpty()) {
                            allTissues.add(parts[6].trim());
                        }
                        if (parts[2] != null && !parts[2].trim().isEmpty()) {
                            allConditions.add(parts[2].trim());
                        }

                        // Apply filters
                        boolean include = true;
                        if (!filterSpecies.isEmpty() && !filterSpecies.equalsIgnoreCase("Human")) {
                            include = false;
                        }
                        if (include && !filterCondition.isEmpty() && !parts[2].equalsIgnoreCase(filterCondition)) {
                            include = false;
                        }
                        if (include && !filterTissue.isEmpty() && !parts[6].equalsIgnoreCase(filterTissue)) {
                            include = false;
                        }

                        if (include) {
                            allData.add(row);
                        }
                    }
                }
                reader.close();

                // Load mouse data
                reader = new BufferedReader(new FileReader(mouseCsvPath));
                reader.readLine(); // Skip header
                while ((line = reader.readLine()) != null) {
                    String[] parts = line.split(",", -1);
                    if (parts.length >= 11) {
                        Map<String, String> row = new HashMap<String, String>();
                        row.put("said", parts[10]);      // said column
                        row.put("gse", parts[9]);        // GSE column
                        row.put("gsm", parts[5]);        // GSM column
                        row.put("species", "Mouse");
                        row.put("n_cells", parts[1]);    // n_cells column
                        row.put("condition", parts[2]);  // condition column
                        row.put("age", parts[3]);        // Age column
                        row.put("sex", parts[4]);        // sex column
                        row.put("tissue", parts[6]);     // Skin_location column

                        // Collect all tissues and conditions for dropdown
                        if (parts[6] != null && !parts[6].trim().isEmpty()) {
                            allTissues.add(parts[6].trim());
                        }
                        if (parts[2] != null && !parts[2].trim().isEmpty()) {
                            allConditions.add(parts[2].trim());
                        }

                        // Apply filters
                        boolean include = true;
                        if (!filterSpecies.isEmpty() && !filterSpecies.equalsIgnoreCase("Mouse")) {
                            include = false;
                        }
                        if (include && !filterCondition.isEmpty() && !parts[2].equalsIgnoreCase(filterCondition)) {
                            include = false;
                        }
                        if (include && !filterTissue.isEmpty() && !parts[6].equalsIgnoreCase(filterTissue)) {
                            include = false;
                        }

                        if (include) {
                            allData.add(row);
                        }
                    }
                }
                reader.close();
                reader = null;

                // Sort allData
                allData.sort(new java.util.Comparator<Map<String, String>>() {
                    public int compare(Map<String, String> a, Map<String, String> b) {
                        String va = a.get(finalSortCol) != null ? a.get(finalSortCol) : "";
                        String vb = b.get(finalSortCol) != null ? b.get(finalSortCol) : "";
                        int cmp;
                        // Numeric sort for n_cells and said
                        if ("n_cells".equals(finalSortCol) || "said".equals(finalSortCol)) {
                            try {
                                String na = va.replaceAll("[^0-9]", "");
                                String nb = vb.replaceAll("[^0-9]", "");
                                int ia = na.isEmpty() ? 0 : Integer.parseInt(na);
                                int ib = nb.isEmpty() ? 0 : Integer.parseInt(nb);
                                cmp = Integer.compare(ia, ib);
                            } catch (Exception e) {
                                cmp = va.compareToIgnoreCase(vb);
                            }
                        } else {
                            cmp = va.compareToIgnoreCase(vb);
                        }
                        return "desc".equals(finalSortOrder) ? -cmp : cmp;
                    }
                });

                int rowsPerPage = 10;
                int totalRows = allData.size();
                int totalPages = (int) Math.ceil((double) totalRows / rowsPerPage);
                if (totalPages == 0) totalPages = 1;

                String pageParam = request.getParameter("page");
                int pageNum = 1;
                try { pageNum = Integer.parseInt(pageParam); } catch(Exception ignore){}
                if (pageNum < 1) pageNum = 1;
                if (totalPages > 0 && pageNum > totalPages) pageNum = totalPages;

                int startRow = (pageNum - 1) * rowsPerPage;
                int endRow = Math.min(startRow + rowsPerPage, totalRows);

                // Build filter query string for pagination links
                String filterQueryString = "";
                if (!filterSpecies.isEmpty()) filterQueryString += "&species=" + java.net.URLEncoder.encode(filterSpecies, "UTF-8");
                if (!filterCondition.isEmpty()) filterQueryString += "&condition=" + java.net.URLEncoder.encode(filterCondition, "UTF-8");
                if (!filterTissue.isEmpty()) filterQueryString += "&tissue=" + java.net.URLEncoder.encode(filterTissue, "UTF-8");
                filterQueryString += "&sort=" + java.net.URLEncoder.encode(sortCol, "UTF-8") + "&order=" + java.net.URLEncoder.encode(sortOrder, "UTF-8");
        %>

        <div class="table-card" data-panel-enter>
            <div class="table-card__header">
                <h2 class="table-card__title">Dataset Preview</h2>
                <div class="table-card__actions">
                    <button id="integrate-button" class="btn btn--primary" data-btn-morph>
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-right: 8px;">
                            <circle cx="12" cy="12" r="10"></circle>
                            <path d="M12 6v12M6 12h12"></path>
                        </svg>
                        Generate Integrated UMAP
                    </button>
                </div>
            </div>

            <!-- Filter Bar -->
            <div class="filter-bar">
                <form id="filter-form" method="get" style="display: contents;">
                    <div class="filter-group">
                        <label class="filter-group__label">Species</label>
                        <select name="species" id="filter-species" class="filter-group__select" onchange="this.form.submit()">
                            <option value="">All Species</option>
                            <option value="Human" <%= "Human".equalsIgnoreCase(filterSpecies) ? "selected" : "" %>>Human</option>
                            <option value="Mouse" <%= "Mouse".equalsIgnoreCase(filterSpecies) ? "selected" : "" %>>Mouse</option>
                        </select>
                    </div>

                    <div class="filter-group">
                        <label class="filter-group__label">Condition</label>
                        <select name="condition" id="filter-condition" class="filter-group__select" onchange="this.form.submit()">
                            <option value="">All Conditions</option>
                            <% for (String cond : allConditions) { %>
                            <option value="<%= cond %>" <%= cond.equalsIgnoreCase(filterCondition) ? "selected" : "" %>><%= cond %></option>
                            <% } %>
                        </select>
                    </div>

                    <div class="filter-group">
                        <label class="filter-group__label">Tissue</label>
                        <select name="tissue" id="filter-tissue" class="filter-group__select" onchange="this.form.submit()">
                            <option value="">All Tissues</option>
                            <% for (String tis : allTissues) { %>
                            <option value="<%= tis %>" <%= tis.equalsIgnoreCase(filterTissue) ? "selected" : "" %>><%= tis %></option>
                            <% } %>
                        </select>
                    </div>

                    <div class="filter-bar__actions">
                        <span id="filter-count" class="filter-count">
                            <% if (!filterSpecies.isEmpty() || !filterCondition.isEmpty() || !filterTissue.isEmpty()) { %>
                            Showing <strong><%= totalRows %></strong> filtered results
                            <% } %>
                        </span>
                        <a href="browse.jsp" class="filter-bar__btn filter-bar__btn--clear">Clear Filters</a>
                    </div>
                </form>
            </div>

            <div class="data-table-wrapper">
                <table class="browse-table">
                    <thead>
                    <tr>
                        <th><input type="checkbox" id="select-all" title="Select all"></th>
                        <%
                            String[][] sortCols = {
                                {"said", "SAID"}, {"gse", "GSE"}, {"gsm", "GSM"},
                                {"species", "Species"}, {"n_cells", "Cells"},
                                {"condition", "Condition"}, {"tissue", "Tissue"}
                            };
                            for (String[] sc : sortCols) {
                                String colKey = sc[0], colLabel = sc[1];
                                String nextOrder = (colKey.equals(sortCol) && "asc".equals(sortOrder)) ? "desc" : "asc";
                                String arrow = "";
                                if (colKey.equals(sortCol)) {
                                    arrow = "asc".equals(sortOrder) ? " &#9650;" : " &#9660;";
                                }
                                String sortUrl = "?sort=" + colKey + "&order=" + nextOrder;
                                if (!filterSpecies.isEmpty()) sortUrl += "&species=" + java.net.URLEncoder.encode(filterSpecies, "UTF-8");
                                if (!filterCondition.isEmpty()) sortUrl += "&condition=" + java.net.URLEncoder.encode(filterCondition, "UTF-8");
                                if (!filterTissue.isEmpty()) sortUrl += "&tissue=" + java.net.URLEncoder.encode(filterTissue, "UTF-8");
                        %>
                        <th class="sortable-th<%= colKey.equals(sortCol) ? " sorted" : "" %>">
                            <a href="<%= sortUrl %>" class="sort-link"><%= colLabel %><span class="sort-arrow"><%= arrow %></span></a>
                        </th>
                        <% } %>
                        <th>Details</th>
                    </tr>
                    </thead>
                    <tbody data-stagger-group data-stagger-type="fade-up">
                    <%
                        for (int r = startRow; r < endRow; r++) {
                            Map<String, String> rowData = allData.get(r);
                            String said_display = rowData.get("said");
                            String gse = rowData.get("gse");
                            String gsm_value = rowData.get("gsm");
                            String species = rowData.get("species");
                            String n_cells = rowData.get("n_cells");
                            String condition = rowData.get("condition");
                            String tissue = rowData.get("tissue");
                            String speciesLower = species.toLowerCase();
                            String conditionLower = condition.toLowerCase();
                            String tissueLower = tissue.toLowerCase().trim();
                    %>
                    <tr data-species="<%= speciesLower %>" data-disease="<%= conditionLower %>" data-tissue="<%= tissueLower %>" data-stagger-item>
                        <td><input type="checkbox" name="dataset_checkbox" value="<%= said_display %>"></td>
                        <td class="cell-id"><%= said_display %></td>
                        <td><%= gse %></td>
                        <td><%= gsm_value %></td>
                        <td>
                            <span class="species-badge <%= speciesLower.contains("human") ? "species-badge--human" : "species-badge--mouse" %>">
                                <%= species %>
                            </span>
                        </td>
                        <td><%= n_cells %></td>
                        <td><%= condition %></td>
                        <td><%= tissue %></td>
                        <td>
                            <a href="details.jsp?said=<%= java.net.URLEncoder.encode(said_display, "UTF-8") %>" class="cell-link">
                                View
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                    <path d="M5 12h14M12 5l7 7-7 7"></path>
                                </svg>
                            </a>
                        </td>
                    </tr>
                    <% } %>
                    </tbody>
                </table>
            </div>

            <div class="table-card__footer">
                <div class="pagination">
                    <% if (pageNum > 1) { %>
                    <a href="?page=<%= pageNum - 1 %><%= filterQueryString %>" class="pagination__btn">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M15 18l-6-6 6-6"></path>
                        </svg>
                        Previous
                    </a>
                    <% } else { %>
                    <span class="pagination__btn pagination__btn--disabled">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M15 18l-6-6 6-6"></path>
                        </svg>
                        Previous
                    </span>
                    <% } %>

                    <div class="pagination__input-group">
                        <span class="pagination__label">Page</span>
                        <form method="get" style="display: inline-flex; align-items: center; gap: 0.5rem;">
                            <input type="hidden" name="species" value="<%= filterSpecies %>">
                            <input type="hidden" name="condition" value="<%= filterCondition %>">
                            <input type="hidden" name="tissue" value="<%= filterTissue %>">
                            <input type="number" name="page" min="1" max="<%= totalPages %>" value="<%= pageNum %>" class="pagination__input">
                            <span class="pagination__label">of <%= totalPages %></span>
                            <button type="submit" class="pagination__btn">Go</button>
                        </form>
                    </div>

                    <% if (pageNum < totalPages) { %>
                    <a href="?page=<%= pageNum + 1 %><%= filterQueryString %>" class="pagination__btn">
                        Next
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M9 18l6-6-6-6"></path>
                        </svg>
                    </a>
                    <% } else { %>
                    <span class="pagination__btn pagination__btn--disabled">
                        Next
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M9 18l6-6-6-6"></path>
                        </svg>
                    </span>
                    <% } %>
                </div>
            </div>
        </div>

        <!-- UMAP Result Container -->
        <div id="umap-result-container" class="umap-container" style="display: none;">
            <div id="loading-indicator" class="loading-indicator">
                <div class="loading-indicator__spinner"></div>
                <p class="loading-indicator__text">Generating UMAP... This may take a few moments.</p>
            </div>
            <img id="umap-image" src="" alt="Integrated UMAP plot" style="display: none;">
        </div>

        <%
            } catch (Exception e) {
                dataLoadError = "Error loading data: " + e.getMessage();
            } finally {
                if (reader != null) try { reader.close(); } catch(Exception ignore){}
            }
            } // end else (files exist)

            // Show error message if data couldn't be loaded
            if (dataLoadError != null) {
        %>
        <div class="error-message" style="background: #fff3cd; border: 1px solid #ffc107; color: #856404; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <strong>Data Loading Notice:</strong> <%= dataLoadError %>
            <br><br>
            <em>The data files may not be available on this deployment. This feature requires the CSV data files to be present on the server.</em>
        </div>
        <%
            }
        %>
    </div>
</main>

<script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
<script>
$(document).ready(function() {
    // ===== Persistent Selection across pages =====
    var STORAGE_KEY = 'skindb_selected_saids';

    function getStoredSaids() {
        try {
            var stored = sessionStorage.getItem(STORAGE_KEY);
            return stored ? JSON.parse(stored) : [];
        } catch(e) { return []; }
    }

    function saveStoredSaids(saids) {
        sessionStorage.setItem(STORAGE_KEY, JSON.stringify(saids));
        updateSelectionBadge();
    }

    function addSaid(said) {
        var saids = getStoredSaids();
        if (saids.indexOf(said) === -1) {
            saids.push(said);
            saveStoredSaids(saids);
        }
    }

    function removeSaid(said) {
        var saids = getStoredSaids();
        var idx = saids.indexOf(said);
        if (idx !== -1) {
            saids.splice(idx, 1);
            saveStoredSaids(saids);
        }
    }

    function updateSelectionBadge() {
        var saids = getStoredSaids();
        var $badge = $('#selection-badge');
        if (saids.length > 0) {
            $badge.text(saids.length + ' selected').show();
        } else {
            $badge.hide();
        }
    }

    // Add badge next to the Generate button
    $('#integrate-button').after(
        '<span id="selection-badge" style="display:none; margin-left:12px; background:#3498db; color:#fff; padding:4px 12px; border-radius:12px; font-size:0.85rem; font-weight:500;"></span>' +
        '<button id="clear-selection-btn" class="btn" style="margin-left:8px; padding:6px 14px; font-size:0.8rem; background:#e74c3c; color:#fff; border:none; border-radius:6px; cursor:pointer; display:none;" title="Clear all selections">Clear All</button>'
    );

    // Restore selections on page load
    var storedSaids = getStoredSaids();
    $('input[name="dataset_checkbox"]').each(function() {
        if (storedSaids.indexOf($(this).val()) !== -1) {
            $(this).prop('checked', true);
            $(this).closest('tr').addClass('selected-row');
        }
    });
    updateSelectionBadge();
    if (storedSaids.length > 0) $('#clear-selection-btn').show();

    // Row selection highlighting + persist
    document.querySelector('#select-all').closest('table').addEventListener('change', function (e) {
        const cb = e.target;
        if (cb.type !== 'checkbox' || cb.name !== 'dataset_checkbox') return;
        const tr = cb.closest('tr');
        tr.classList.toggle('selected-row', cb.checked);
        if (cb.checked) {
            addSaid(cb.value);
        } else {
            removeSaid(cb.value);
        }
        var count = getStoredSaids().length;
        if (count > 0) $('#clear-selection-btn').show(); else $('#clear-selection-btn').hide();
    });

    // Select all checkbox (only select visible rows)
    $('#select-all').on('click', function() {
        const flag = this.checked;
        $('input[name="dataset_checkbox"]').each(function () {
            const $row = $(this).closest('tr');
            if (!$row.hasClass('filtered-out')) {
                this.checked = flag;
                $row.toggleClass('selected-row', flag);
                if (flag) {
                    addSaid($(this).val());
                } else {
                    removeSaid($(this).val());
                }
            }
        });
        var count = getStoredSaids().length;
        if (count > 0) $('#clear-selection-btn').show(); else $('#clear-selection-btn').hide();
    });

    // Clear all selections
    $('#clear-selection-btn').on('click', function() {
        sessionStorage.removeItem(STORAGE_KEY);
        $('input[name="dataset_checkbox"]').prop('checked', false);
        $('#select-all').prop('checked', false);
        $('tr.selected-row').removeClass('selected-row');
        updateSelectionBadge();
        $(this).hide();
    });

    // Integration button - opens interactive Dash UMAP in new tab
    $('#integrate-button').on('click', function() {
        var allSaids = getStoredSaids();

        if (allSaids.length < 1) {
            alert('Please select at least one dataset to visualize.');
            return;
        }

        // Open Dash app in new tab with all persisted SAIDs
        var url = '/integrated_umap/?saids=' + allSaids.join(',');
        window.open(url, '_blank');
    });
});
</script>

<!-- Under Construction Modal Script -->
<script src="JS/construction-modal-simple.js"></script>

</body>
</html>
