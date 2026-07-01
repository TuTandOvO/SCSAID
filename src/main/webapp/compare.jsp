<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%
    response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
    response.setHeader("Pragma", "no-cache");
    response.setHeader("Expires", "0");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Compare Conditions - scSAID</title>
    <meta name="description" content="Compare two conditions across the scSAID skin atlas. Pseudobulk DESeq2 differential expression and pre-ranked GSEA, per cell type.">

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">

    <!-- Design System -->
    <link rel="stylesheet" href="CSS/design-system.css?v=<%= System.currentTimeMillis() %>">
    <link rel="stylesheet" href="CSS/header.css?v=20260701h">
    <link rel="stylesheet" href="CSS/details.css?v=<%= System.currentTimeMillis() %>">
    <link rel="stylesheet" href="CSS/compare.css?v=<%= System.currentTimeMillis() %>">
    <link rel="stylesheet" href="lib/css/jquery.dataTables.min.css?v=20260420">

    <!-- Third-party libs (same versions as details.jsp) -->
    <script src="lib/jquery-3.7.1.min.js?v=20260420"></script>
    <script src="lib/jquery.dataTables.min.js?v=20260420"></script>
    <script src="lib/xlsx.full.min.js?v=20260420"></script>
    <script src="lib/plotly-2.20.0.min.js?v=20260420"></script>
    <!-- Publication-quality figure download (high-res PNG / vector PDF) -->
    <script src="lib/jspdf.umd.min.js?v=20260630"></script>
    <script src="lib/svg2pdf.umd.min.js?v=20260630"></script>
    <script src="JS/figure-export.js?v=<%= System.currentTimeMillis() %>"></script>
</head>
<body>

<%@ include file="includes/header.jsp" %>

<main class="compare-page" id="main-content" tabindex="-1">

    <!-- Editorial hero — cream, serif, homepage tone -->
    <section class="page-hero">
        <div class="page-hero__inner">
            <span class="page-hero__eyebrow">Cross-condition analysis</span>
            <h1 class="page-hero__title">Condition comparison</h1>
            <p class="page-hero__description">
                Differential expression (pseudobulk DESeq2) and pre-ranked GSEA between two conditions,
                per cell type. Samples are the statistical replicates — not individual cells.
            </p>
        </div>
    </section>

    <div class="compare-shell">

        <!-- ============================================================
             Step 1 — Choose conditions
             ============================================================ -->
        <section class="panel setup-card" aria-labelledby="setup-title">
            <header class="panel-header">
                <span class="panel-eyebrow">Step 1</span>
                <h2 class="panel-title" id="setup-title">Choose conditions</h2>
                <p class="panel-description">Pick a species, then the two conditions you want to contrast. Only conditions with at least two samples are listed.</p>
            </header>
            <div class="panel-body">
                <div class="filter-grid">

                    <div class="filter-card">
                        <span class="filter-name">Species</span>
                        <div class="species-toggle" role="radiogroup" aria-label="Species">
                            <label>
                                <input type="radio" name="species" value="human" checked>
                                <span class="species-toggle__option">Human</span>
                            </label>
                            <label>
                                <input type="radio" name="species" value="mouse">
                                <span class="species-toggle__option">Mouse</span>
                            </label>
                        </div>
                    </div>

                    <div class="filter-card">
                        <label class="filter-name" for="conditionA">Condition A · case</label>
                        <select id="conditionA" class="form-select"></select>
                    </div>

                    <div class="filter-card">
                        <label class="filter-name" for="conditionB">Condition B · reference</label>
                        <select id="conditionB" class="form-select" data-default="Healthy"></select>
                    </div>

                    <div class="filter-card filter-card--action">
                        <span class="filter-name">&nbsp;</span>
                        <button id="runBtn" class="btn-primary" disabled>Run comparison</button>
                    </div>

                </div>

                <details class="compare-guidance">
                    <summary>How to choose a valid comparison</summary>
                    <div class="compare-guidance__body">
                        <p>This tool runs <strong>pseudobulk DESeq2</strong> — each sample is one statistical replicate, so more samples per condition means more reliable results.</p>
                        <ul>
                            <li><strong>Cleanest comparison:</strong> a disease against <em>Healthy</em>. A shared baseline isolates disease-driven changes.</li>
                            <li><strong>Disease vs disease</strong> has no shared control, so differences can reflect <strong>skin region, cohort or study (batch)</strong> as much as disease — comparisons across <strong>different body sites</strong> are especially confounded.</li>
                            <li><strong>Small sample sizes</strong> (n = 2–3) are underpowered; treat marginal genes with caution.</li>
                            <li>Cell types with too few cells in either condition are skipped automatically.</li>
                        </ul>
                    </div>
                </details>
                <div id="compareAdvisory" class="compare-advisory" hidden></div>

                <div id="runSummary" class="run-summary" hidden></div>
                <div id="runProgress" class="panel-loader" role="status" aria-label="Loading" hidden></div>
                <div id="runError" class="status-error" hidden></div>
            </div>
        </section>

        <!-- ============================================================
             Step 2 — Results: DEG + GSEA, side by side
             ============================================================ -->
        <section class="results-grid">

            <!-- DEG panel ---------------------------------------------- -->
            <article class="panel" id="degPanel" aria-labelledby="deg-title">
                <header class="panel-header">
                    <span class="panel-eyebrow">Step 2 · Differential expression</span>
                    <h2 class="panel-title" id="deg-title">DEG results</h2>
                    <p class="panel-description">Log<sub>2</sub> fold-change of condition A over B, per cell type. Filter by significance, effect size, and cell type.</p>
                </header>
                <div class="panel-body">

                    <!-- Empty state (before run) -->
                    <div id="degEmpty" class="panel-empty">
                        <svg class="panel-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <path d="M3 3v18h18" stroke-linecap="round" stroke-linejoin="round"/>
                            <path d="M7 14l3-3 3 3 5-5" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                        <h3 class="panel-empty__title">Awaiting a comparison</h3>
                        <p class="panel-empty__text">Pick two conditions above and run the job. Per-cell-type DEG tables will appear here.</p>
                    </div>

                    <!-- Results block (shown once DEG finishes) -->
                    <div id="degResults" hidden>
                        <div class="filter-grid">
                            <div class="filter-card">
                                <div class="filter-label">
                                    <span class="filter-name">Adj. p ≤</span>
                                    <span class="filter-value" id="pvalLabel">0.05</span>
                                </div>
                                <input type="range" id="pvalSlider" min="0" max="0.1" step="0.001" value="0.05">
                            </div>
                            <div class="filter-card">
                                <div class="filter-label">
                                    <span class="filter-name">|log₂ FC| ≥</span>
                                    <span class="filter-value" id="fcLabel">1.0</span>
                                </div>
                                <input type="range" id="fcSlider" min="0" max="5" step="0.1" value="1.0">
                            </div>
                            <div class="filter-card">
                                <label class="filter-name" for="cellTypeSelect">Cell type</label>
                                <select id="cellTypeSelect" class="form-select"><option value="">All cell types</option></select>
                            </div>
                            <div class="filter-card">
                                <span class="filter-name">Filter</span>
                                <label class="checkbox-item">
                                    <input type="checkbox" id="hidePseudogenes" checked>
                                    <span class="checkbox-item__text">Hide pseudogenes</span>
                                </label>
                            </div>
                        </div>

                        <div class="table-wrapper">
                            <table id="degTable" class="display" style="width:100%">
                                <thead>
                                    <tr>
                                        <th>Gene</th>
                                        <th>log₂ FC</th>
                                        <th>p-value</th>
                                        <th>Adj. p</th>
                                        <th>Cell type</th>
                                    </tr>
                                </thead>
                            </table>
                        </div>

                        <div class="panel-actions">
                            <button id="exportDegBtn" class="btn-secondary" disabled>Export Excel</button>
                        </div>
                    </div>

                </div>
            </article>

            <!-- GSEA panel --------------------------------------------- -->
            <article class="panel" id="gseaPanel" data-locked="true" aria-labelledby="gsea-title">
                <header class="panel-header">
                    <span class="panel-eyebrow">Step 2 · Gene-set enrichment</span>
                    <h2 class="panel-title" id="gsea-title">Pre-ranked GSEA</h2>
                    <p class="panel-description">Rank genes by signed −log₁₀(adj p) and run leading-edge analysis against curated libraries.</p>
                </header>
                <div class="panel-body">

                    <!-- Empty state (before DEG completes) -->
                    <div id="gseaEmpty" class="panel-empty">
                        <svg class="panel-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <circle cx="12" cy="12" r="9" stroke-linecap="round" stroke-linejoin="round"/>
                            <path d="M12 7v5l3 2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                        <h3 class="panel-empty__title">GSEA unlocks after DEG</h3>
                        <p class="panel-empty__text">Once the comparison finishes, pick a cell type and gene-set library, and run the enrichment here.</p>
                    </div>

                    <!-- Results block (shown once DEG finishes) -->
                    <div id="gseaResults" hidden>
                        <div class="filter-grid">
                            <div class="filter-card">
                                <label class="filter-name" for="gseaCellTypeSelect">Cell type</label>
                                <select id="gseaCellTypeSelect" class="form-select" disabled></select>
                            </div>
                            <div class="filter-card">
                                <label class="filter-name" for="gseaGmtSelect">Library</label>
                                <select id="gseaGmtSelect" class="form-select" disabled></select>
                            </div>
                            <div class="filter-card">
                                <label class="filter-name" for="gseaTopN">Top N</label>
                                <select id="gseaTopN" class="form-select">
                                    <option>10</option><option selected>20</option><option>30</option>
                                </select>
                            </div>
                            <div class="filter-card">
                                <label class="filter-name" for="gseaDirection">Direction</label>
                                <select id="gseaDirection" class="form-select">
                                    <option value="all">All</option>
                                    <option value="up">Up in A</option>
                                    <option value="down">Down in A</option>
                                </select>
                            </div>
                            <div class="filter-card filter-card--action">
                                <span class="filter-name">&nbsp;</span>
                                <button id="runGseaBtn" class="btn-primary" disabled>Run GSEA</button>
                            </div>
                        </div>

                        <div id="gseaProgress" class="panel-loader" role="status" aria-label="Loading" hidden></div>
                        <div id="gseaError" class="status-error" hidden></div>

                        <div class="gsea-chart-scroll">
                            <div id="gseaChart" class="gsea-chart"></div>
                        </div>

                        <div class="table-wrapper" style="margin-top:0.5rem;">
                            <div style="display:flex; justify-content:flex-end; margin-bottom:0.5rem;">
                                <button id="exportGseaBtn" class="btn-secondary" disabled>Export Excel</button>
                            </div>
                            <table id="gseaTable" class="display" style="width:100%">
                                <thead>
                                    <tr>
                                        <th>Term</th>
                                        <th>NES</th>
                                        <th>p-value</th>
                                        <th>FDR</th>
                                        <th>Leading edge</th>
                                    </tr>
                                </thead>
                            </table>
                        </div>
                    </div>

                </div>
            </article>

        </section>

    </div>
</main>

<script src="JS/compare.js?v=<%= System.currentTimeMillis() %>"></script>
<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
