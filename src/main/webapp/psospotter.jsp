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
    <meta name="robots" content="index,follow">
    <link rel="canonical" href="https://skin-scsaid.com/psospotter.jsp">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;0,600;1,300;1,600&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="CSS/design-system.css?v=20260710c">
    <link rel="stylesheet" href="CSS/buttons.css?v=20260703a">
    <link rel="stylesheet" href="CSS/header.css?v=20260712a">
    <link rel="stylesheet" href="CSS/details.css?v=20260710b">
    <link rel="stylesheet" href="CSS/search.css?v=20260711b">
    <link rel="stylesheet" href="CSS/psospotter.css?v=20260717b">
    <link rel="stylesheet" href="CSS/humanbase-tables.css?v=20260703b">
</head>
<body>
<%@ include file="includes/header.jsp" %>

<main class="search-page psospotter-page" id="main-content" tabindex="-1">
    <section class="search-hero psospotter-hero">
        <span class="search-hero__eyebrow">Biomarker panel selection</span>
        <h1 class="search-hero__title psospotter-hero__title">psoSpotter <span class="feature-status">beta</span></h1>
        <p class="search-hero__description">
            Select a compact candidate-gene panel from raw-count single-cell data in single- or cross-species mode.
        </p>
        <div class="search-examples psospotter-quickstart" aria-label="Example candidate genes">
            <button id="quickstartBtn" class="psospotter-quickstart__button" type="button" title="Load all example genes" aria-label="Load all example genes">
                <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                    <path d="M9 21h6"></path>
                    <path d="M10 17h4"></path>
                    <path d="M6.5 9.25a5.5 5.5 0 1 1 11 0c0 1.83-.8 3.12-2.12 4.28-.58.51-1.01 1.14-1.25 1.82H9.87c-.24-.68-.67-1.31-1.25-1.82C7.3 12.37 6.5 11.08 6.5 9.25Z"></path>
                </svg>
            </button>
            <span class="search-examples__label">Try</span>
            <div class="psospotter-quickstart__chips" id="quickstartChips">
                <button type="button" class="search-examples__btn" data-gene="KRT14">KRT14</button>
                <button type="button" class="search-examples__btn" data-gene="COL1A1">COL1A1</button>
                <button type="button" class="search-examples__btn" data-gene="ACTA2">ACTA2</button>
                <button type="button" class="search-examples__btn" data-gene="PECAM1">PECAM1</button>
                <button type="button" class="search-examples__btn" data-gene="CD3E">CD3E</button>
            </div>
        </div>
    </section>

    <div class="results-section psospotter-shell">
        <section class="panel psospotter-config" aria-labelledby="psospotter-config-title">
            <header class="panel-header panel-header--split">
                <div>
                    <span class="panel-eyebrow">Analysis setup</span>
                    <h2 class="panel-title" id="psospotter-config-title">Configure psoSpotter</h2>
                    <p class="panel-description">Provide candidate genes and analysis-ready h5ad input. Previous gene input is restored locally in this browser.</p>
                </div>
            </header>
            <div class="panel-body">
                <form id="psospotterForm" class="psospotter-form" enctype="multipart/form-data" novalidate>
                    <div class="psospotter-form__basics">
                        <div class="control-group psospotter-control psospotter-control--mode">
                            <span class="control-label">Mode</span>
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

                        <div class="control-group psospotter-control" id="singleSpeciesCard">
                            <label class="control-label" for="singleSpecies">Species</label>
                            <select id="singleSpecies" class="form-select" data-preference-key="psospotterSpecies">
                                <option value="human">Human</option>
                                <option value="mouse">Mouse</option>
                            </select>
                        </div>

                        <div class="control-group psospotter-control" id="crossDirectionCard" hidden>
                            <label class="control-label" for="crossDirection">Direction</label>
                            <select id="crossDirection" class="form-select" data-preference-key="psospotterDirection">
                                <option value="human_to_mouse">Human → Mouse</option>
                                <option value="mouse_to_human">Mouse → Human</option>
                            </select>
                        </div>

                        <div class="control-group psospotter-control">
                            <label class="control-label" for="panelK">Panel size</label>
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
                    </div>

                    <div class="psospotter-form__inputs">
                        <div class="psospotter-field psospotter-field--genes">
                            <div class="psospotter-field__header">
                                <label class="control-label" for="geneList">Candidate genes</label>
                                <span id="geneCount" class="psospotter-field__meta" aria-live="polite">0 unique genes</span>
                            </div>
                            <textarea id="geneList" class="form-textarea psospotter-textarea" data-preference-key="psospotterGeneList" rows="9" placeholder="KRT14, COL1A1, ACTA2, PECAM1, CD3E" aria-describedby="geneListHelp"></textarea>
                            <p class="psospotter-helpline" id="geneListHelp">Separate symbols with commas, spaces, tabs, semicolons, or new lines.</p>
                        </div>

                        <div class="psospotter-field psospotter-field--files">
                            <div id="singleUploadCard">
                                <label class="control-label" for="singleH5ad">Analysis-ready h5ad</label>
                                <input id="singleH5ad" class="psospotter-file" type="file" accept=".h5ad,application/x-hdf5" aria-describedby="singleH5adHelp">
                                <p class="psospotter-helpline" id="singleH5adHelp">Upload one h5ad file with raw counts in <code>layers[&quot;counts&quot;]</code>.</p>
                            </div>

                            <div id="crossUploadCard" hidden>
                                <span class="control-label">Analysis-ready h5ad files</span>
                                <div class="psospotter-upload-grid">
                                    <div class="psospotter-upload">
                                        <label class="psospotter-upload__label" for="trainH5ad">Training dataset</label>
                                        <input id="trainH5ad" class="psospotter-file" type="file" accept=".h5ad,application/x-hdf5" aria-describedby="crossH5adHelp">
                                    </div>
                                    <div class="psospotter-upload">
                                        <label class="psospotter-upload__label" for="testH5ad">Test dataset</label>
                                        <input id="testH5ad" class="psospotter-file" type="file" accept=".h5ad,application/x-hdf5" aria-describedby="crossH5adHelp">
                                    </div>
                                </div>
                                <p class="psospotter-helpline" id="crossH5adHelp">Cross-species mode maps genes with the bundled Ensembl 116 orthologue table.</p>
                            </div>
                        </div>
                    </div>

                    <div class="psospotter-form__footer">
                        <div>
                            <p class="psospotter-retention">Completed results remain available for 30 minutes.</p>
                            <div id="formError" class="status-error psospotter-form__error" role="alert" hidden></div>
                        </div>
                        <button id="runBtn" class="btn-primary psospotter-run-button" type="submit">Run psoSpotter</button>
                    </div>
                </form>
            </div>
        </section>

        <section id="psospotterStatus" class="panel psospotter-status" aria-labelledby="psospotter-status-title" data-run-state="running" hidden>
            <header class="panel-header panel-header--split">
                <div>
                    <span class="panel-eyebrow">Analysis output</span>
                    <h2 class="panel-title" id="psospotter-status-title">psoSpotter results</h2>
                </div>
                <span id="runStateBadge" class="psospotter-run-state">Queued</span>
            </header>
            <div class="panel-body">
                <div id="statusBody" class="psospotter-status__body" hidden>
                    <div id="jobState" class="psospotter-job-state" role="status" aria-live="polite" aria-atomic="true">
                        <div id="jobLoader" class="panel-loader psospotter-job-state__loader" aria-hidden="true"></div>
                        <div class="psospotter-job-state__copy">
                            <span id="progressLabel" class="psospotter-progress__label">Queued</span>
                            <span id="progressPercent" class="psospotter-progress__percent">0%</span>
                            <span id="queueLabel" class="psospotter-progress__queue"></span>
                        </div>
                    </div>

                    <div id="statusMessage" class="info-bar psospotter-info" aria-live="polite" hidden></div>
                    <div id="errorBox" class="status-error" role="alert" hidden></div>

                    <div id="resultSummary" class="psospotter-summary" hidden></div>
                    <div id="resultPanels" class="psospotter-panels" hidden></div>
                    <div id="resultTables" class="psospotter-tables" hidden></div>
                    <div id="resultMetrics" class="psospotter-metrics" hidden></div>

                    <div class="panel-actions psospotter-actions">
                        <button id="downloadJsonBtn" class="btn-secondary" type="button" disabled>Download JSON</button>
                        <button id="clearBtn" class="btn-outline" type="button">Clear results</button>
                    </div>
                </div>
            </div>
        </section>
    </div>
</main>

<script src="JS/site-preferences.js?v=20260703d"></script>
<script src="JS/site-header.js?v=20260703a" defer></script>
<script src="JS/psospotter.js?v=20260717a" defer></script>
</body>
</html>
