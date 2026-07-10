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
    <link rel="icon" type="image/x-icon" href="/favicon.ico?v=20260703a">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png?v=20260703a">
    <title>psoSpotter - scSAID</title>
    <meta name="description" content="Run the psoSpotter biomarker-panel selection algorithm on uploaded scRNA-seq h5ad files.">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="CSS/design-system.css?v=20260710b">
    <link rel="stylesheet" href="CSS/buttons.css?v=20260703a">
    <link rel="stylesheet" href="CSS/header.css?v=20260704b">
    <link rel="stylesheet" href="CSS/details.css?v=20260710b">
    <link rel="stylesheet" href="CSS/compare.css?v=20260710b">
    <link rel="stylesheet" href="CSS/psospotter.css?v=20260703a">
</head>
<body>
<%@ include file="includes/header.jsp" %>

<main class="psospotter-page" id="main-content" tabindex="-1">
    <section class="page-hero">
        <div class="page-hero__inner">
            <span class="page-hero__eyebrow">Biomarker panel selection</span>
            <h1 class="page-hero__title">psoSpotter</h1>
            <p class="page-hero__description">
                Upload raw-count h5ad files, provide a candidate gene list, and run the panel-selection pipeline on the backend.
            </p>
            <div class="psospotter-quickstart" aria-label="Example gene shortcuts">
                <button id="quickstartBtn" class="psospotter-quickstart__button" type="button" title="Load an example gene list" aria-label="Load an example gene list">
                    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                        <path d="M9 21h6" />
                        <path d="M10 17h4" />
                        <path d="M6.5 9.25a5.5 5.5 0 1 1 11 0c0 1.83-.8 3.12-2.12 4.28-.58.51-1.01 1.14-1.25 1.82H9.87c-.24-.68-.67-1.31-1.25-1.82C7.3 12.37 6.5 11.08 6.5 9.25Z" />
                    </svg>
                </button>
                <span class="psospotter-quickstart__label">Try</span>
                <div class="psospotter-quickstart__chips" id="quickstartChips">
                    <button type="button" class="psospotter-quickstart__chip" data-gene="KRT14">KRT14</button>
                    <button type="button" class="psospotter-quickstart__chip" data-gene="COL1A1">COL1A1</button>
                    <button type="button" class="psospotter-quickstart__chip" data-gene="ACTA2">ACTA2</button>
                    <button type="button" class="psospotter-quickstart__chip" data-gene="PECAM1">PECAM1</button>
                    <button type="button" class="psospotter-quickstart__chip" data-gene="CD3E">CD3E</button>
                </div>
            </div>
        </div>
    </section>

    <div class="psospotter-shell">
        <section class="panel psospotter-config" aria-labelledby="psospotter-config-title">
            <header class="panel-header">
                <span class="panel-eyebrow">Inputs</span>
                <h2 class="panel-title" id="psospotter-config-title">Run configuration</h2>
            </header>
            <div class="panel-body">
                <form id="psospotterForm" class="psospotter-form" enctype="multipart/form-data" novalidate>
                    <div class="filter-grid psospotter-form__grid">
                        <div class="filter-card">
                            <span class="filter-name">Mode</span>
                            <div class="species-toggle" role="radiogroup" aria-label="Mode">
                                <label>
                                    <input type="radio" name="mode" value="single" data-preference-key="psospotterMode" checked>
                                    <span class="species-toggle__option">Single species</span>
                                </label>
                                <label>
                                    <input type="radio" name="mode" value="cross" data-preference-key="psospotterMode">
                                    <span class="species-toggle__option">Cross species</span>
                                </label>
                            </div>
                        </div>

                        <div class="filter-card" id="singleSpeciesCard">
                            <label class="filter-name" for="singleSpecies">Species</label>
                            <select id="singleSpecies" class="form-select" data-preference-key="psospotterSpecies">
                                <option value="human">Human</option>
                                <option value="mouse">Mouse</option>
                            </select>
                        </div>

                        <div class="filter-card" id="crossDirectionCard" hidden>
                            <label class="filter-name" for="crossDirection">Direction</label>
                            <select id="crossDirection" class="form-select" data-preference-key="psospotterDirection">
                                <option value="human_to_mouse">Human → Mouse</option>
                                <option value="mouse_to_human">Mouse → Human</option>
                            </select>
                        </div>

                        <div class="filter-card">
                            <label class="filter-name" for="panelK">Panel size</label>
                            <select id="panelK" class="form-select" data-preference-key="psospotterPanelK">
                                <option value="5">5</option>
                                <option value="10">10</option>
                                <option value="15">15</option>
                                <option value="20" selected>20</option>
                                <option value="25">25</option>
                                <option value="30">30</option>
                                <option value="40">40</option>
                                <option value="50">50</option>
                            </select>
                        </div>

                        <div class="filter-card filter-card--wide">
                            <label class="filter-name" for="geneList">Candidate genes</label>
                            <textarea id="geneList" class="form-textarea psospotter-textarea" data-preference-key="psospotterGeneList" rows="8" placeholder="TP53, KRT14, CXCL8, ..."></textarea>
                            <div class="psospotter-helpline">Comma, space, tab, or newline separated.</div>
                        </div>

                        <div class="filter-card filter-card--wide" id="singleUploadCard">
                            <label class="filter-name" for="singleH5ad">Upload h5ad</label>
                            <input id="singleH5ad" class="psospotter-file" type="file" accept=".h5ad,.h5ad.gz">
                            <div class="psospotter-helpline">Raw counts must be in layers[&quot;counts&quot;].</div>
                        </div>

                        <div class="filter-card filter-card--wide" id="crossUploadCard" hidden>
                            <label class="filter-name">Uploads</label>
                            <div class="psospotter-upload-grid">
                                <label class="psospotter-upload">
                                    <span class="psospotter-upload__label">Train h5ad</span>
                                    <input id="trainH5ad" class="psospotter-file" type="file" accept=".h5ad,.h5ad.gz">
                                </label>
                                <label class="psospotter-upload">
                                    <span class="psospotter-upload__label">Test h5ad</span>
                                    <input id="testH5ad" class="psospotter-file" type="file" accept=".h5ad,.h5ad.gz">
                                </label>
                            </div>
                            <div class="psospotter-helpline">Cross-species mode uses the bundled Ensembl 116 ortholog table.</div>
                        </div>

                        <div class="filter-card filter-card--action">
                            <span class="filter-name">&nbsp;</span>
                            <button id="runBtn" class="btn-primary" type="submit">Run psoSpotter</button>
                        </div>
                    </div>
                </form>
            </div>
        </section>

        <section class="panel psospotter-status" aria-labelledby="psospotter-status-title">
            <header class="panel-header">
                <span class="panel-eyebrow">Job status</span>
                <h2 class="panel-title" id="psospotter-status-title">Live run</h2>
            </header>
            <div class="panel-body">
                <div id="statusEmpty" class="panel-empty">
                    <svg class="panel-empty__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
                        <path d="M4 12h16" stroke-linecap="round"></path>
                        <path d="M12 4v16" stroke-linecap="round"></path>
                        <circle cx="12" cy="12" r="8" stroke-linecap="round"></circle>
                    </svg>
                    <h3 class="panel-empty__title">Waiting for input</h3>
                    <p class="panel-empty__text">Submit a gene list and an h5ad file to start a backend job.</p>
                </div>

                <div id="statusBody" class="psospotter-status__body" hidden>
                    <div class="psospotter-progress">
                        <div class="psospotter-progress__track" aria-hidden="true">
                            <div id="progressBar" class="psospotter-progress__bar" style="width:0%"></div>
                        </div>
                        <div class="psospotter-progress__meta">
                            <span id="progressLabel" class="psospotter-progress__label">Queued</span>
                            <span id="queueLabel" class="psospotter-progress__queue"></span>
                        </div>
                    </div>

                    <div id="statusMessage" class="info-bar psospotter-info"></div>
                    <div id="errorBox" class="status-error" hidden></div>

                    <div id="resultSummary" class="psospotter-summary" hidden></div>
                    <div id="resultPanels" class="psospotter-panels" hidden></div>
                    <div id="resultTables" class="psospotter-tables" hidden></div>
                    <div id="resultMetrics" class="psospotter-metrics" hidden></div>

                    <div class="panel-actions psospotter-actions">
                        <button id="downloadJsonBtn" class="btn-secondary" type="button" disabled>Download JSON</button>
                        <button id="clearBtn" class="btn-outline" type="button">Reset view</button>
                    </div>
                </div>
            </div>
        </section>
    </div>
</main>

<script src="JS/site-preferences.js?v=20260703d"></script>
<script src="JS/site-header.js?v=20260703a" defer></script>
<script src="JS/psospotter.js?v=20260703a" defer></script>
</body>
</html>
