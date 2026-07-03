<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%@ page import="java.io.BufferedReader, java.io.File, java.io.FileReader, java.util.ArrayList, java.util.List, java.util.Map, java.util.HashMap, java.util.Set, java.util.TreeSet, Utils.DataPathResolver" %>
<!DOCTYPE html>
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
    <title>Browse Datasets - scSAID</title>
    <meta name="description" content="Browse 252 curated single-cell RNA-seq datasets of human and mouse skin on scSAID. Filter by species, condition, tissue location, and number of cells. Generate integrated UMAP atlases across multiple studies.">
    <meta name="keywords" content="browse scRNA-seq datasets, skin atlas browser, single-cell skin, scSAID browse, GSM, GSE, skin single-cell, skin tissue single-cell">
    <meta name="robots" content="index,follow">
    <link rel="canonical" href="https://skin-scsaid.com/browse.jsp">
    <meta property="og:type" content="website">
    <meta property="og:title" content="Browse datasets — scSAID">
    <meta property="og:description" content="Browse 252 curated scRNA-seq datasets of human and mouse skin.">
    <meta property="og:url" content="https://skin-scsaid.com/browse.jsp">

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">

    <!-- Design System -->
    <link rel="stylesheet" href="CSS/design-system.css?v=20260702p">
    <link rel="stylesheet" href="CSS/buttons.css?v=20260702p">
    <link rel="stylesheet" href="CSS/header.css?v=20260702p">
    <link rel="stylesheet" href="CSS/animations.css?v=20260701h">
    <link rel="stylesheet" href="CSS/browse.css?v=20260702p">

    <script src="JS/micro-interactions.js"></script>
</head>
<body class="content-fade-in">

<%@ include file="includes/header.jsp" %>

<main class="browse-page" id="main-content" tabindex="-1">
    <!-- Page Hero -->
    <section class="page-hero">
        <div class="page-hero__inner">
            <span class="page-hero__eyebrow">Data Explorer</span>
            <h1 class="page-hero__title">Browse Datasets</h1>
            <p class="page-hero__description">
                Explore our comprehensive collection of single-cell RNA sequencing datasets from skin and appendage tissues.
            </p>
        </div>
    </section>

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
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
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
                        <th><input type="checkbox" id="select-all" aria-label="Select all datasets"></th>
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
                        <td data-label="Select"><input type="checkbox" name="dataset_checkbox" value="<%= said_display %>" aria-label="Select dataset <%= said_display %>"></td>
                        <td class="cell-id" data-label="SAID"><%= said_display %></td>
                        <td data-label="GSE"><%= gse %></td>
                        <td data-label="GSM"><%= gsm_value %></td>
                        <td data-label="Species">
                            <span class="species-badge <%= speciesLower.contains("human") ? "species-badge--human" : "species-badge--mouse" %>">
                                <%= species %>
                            </span>
                        </td>
                        <td data-label="Cells"><%= n_cells %></td>
                        <td data-label="Condition"><%= condition %></td>
                        <td data-label="Tissue"><%= tissue %></td>
                        <td data-label="Details">
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
            <div id="loading-indicator" class="loading-indicator panel-loader" role="status" aria-label="Loading"></div>
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
        <div class="error-message" style="background: var(--color-warning-bg); border: 1px solid var(--color-warning-border); color: var(--color-warning-text); padding: 20px; border-radius: var(--radius-md); margin: 20px 0;">
            <strong>Data Loading Notice:</strong> <%= dataLoadError %>
            <br><br>
            <em>The data files may not be available on this deployment. This feature requires the CSV data files to be present on the server.</em>
        </div>
        <%
            }
        %>
    </div>
</main>

<script src="lib/jquery-3.7.1.min.js"></script>
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
        '<span id="selection-badge" style="display:none; margin-left:12px; background:var(--color-primary); color:var(--text-inverse); padding:4px 12px; border-radius:var(--radius-lg); font-size:0.85rem; font-weight:300;"></span>' +
        '<button id="clear-selection-btn" class="btn-danger" style="margin-left:8px; display:none;" title="Clear all selections">Clear All</button>'
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



<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
