<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
<%
    // Feature Plot — gene expression overlaid on the integrated human/mouse skin
    // UMAP. Client-side Plotly FeaturePlot (see JS/umap-explorer.js); the
    // ~50k-cell base + per-gene expression come from the zarr-backed JSON API
    // under /integrated_umap/api/. A ?gene= query deep-links a gene (species is
    // auto-detected from whichever panel contains it).
    String geneParam = request.getParameter("gene");
    if (geneParam == null) geneParam = "";
    geneParam = geneParam.trim();
    // Escape for safe embedding in an HTML attribute.
    String geneHtml = geneParam.replace("&","&amp;").replace("<","&lt;")
                               .replace(">","&gt;").replace("\"","&quot;").replace("'","&#39;");

    response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <!-- Favicons / PWA icons -->
    <link rel="icon" type="image/x-icon" href="/favicon.ico?v=20260703a">
    <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16.png?v=20260703a">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png?v=20260703a">
    <link rel="icon" type="image/png" sizes="192x192" href="/images/favicon-192.png?v=20260703a">
    <link rel="icon" type="image/png" sizes="512x512" href="/images/favicon-512.png?v=20260703a">
    <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png?v=20260703a">
    <link rel="manifest" href="/site.webmanifest?v=20260703a">
    <meta name="theme-color" content="#333333">
    <title>Expression - scSAID</title>
    <meta name="description" content="Interactive gene expression feature plots on the integrated human and mouse skin atlas. Enter any gene symbol to visualise its expression on the UMAP. Choose human or mouse; case-insensitive (COL1A1, Col1a1 both work).">
    <meta name="keywords" content="gene expression atlas, feature plot, UMAP gene, scRNA-seq gene expression, skin gene atlas, scSAID feature plot, keratinocyte marker, dermal gene">
    <meta name="robots" content="index,follow">
    <link rel="canonical" href="https://skin-scsaid.com/featureplot.jsp">
    <meta property="og:type" content="website">
    <meta property="og:title" content="Expression — Gene Expression Atlas | scSAID">
    <meta property="og:description" content="Interactive gene featureplot on the integrated human and mouse skin scRNA-seq atlas.">
    <meta property="og:url" content="https://skin-scsaid.com/featureplot.jsp">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;1,300&display=swap" rel="stylesheet">

    <!-- Design System + reused page styles -->
    <link rel="stylesheet" href="CSS/design-system.css?v=20260710c">
    <link rel="stylesheet" href="CSS/header.css?v=20260710c">
    <link rel="stylesheet" href="CSS/details.css?v=20260710b">
    <link rel="stylesheet" href="CSS/compare.css?v=20260710b">
    <link rel="stylesheet" href="CSS/umap-explorer.css?v=20260710b">

    <!-- Third-party libs -->
    <script src="lib/jquery-3.7.1.min.js?v=20260420"></script>
    <script src="lib/plotly-2.20.0.min.js?v=20260420"></script>
    <!-- Publication-quality figure download (high-res PNG / vector PDF) -->
    <script src="lib/jspdf.umd.min.js?v=20260630"></script>
    <script src="lib/svg2pdf.umd.min.js?v=20260630"></script>
    <script src="JS/figure-export.js?v=<%= System.currentTimeMillis() %>"></script>
</head>
<body data-initial-gene="<%= geneHtml %>">

<%@ include file="includes/header.jsp" %>

<main class="umap-page" id="main-content" tabindex="-1">

    <!-- Editorial hero -->
    <section class="page-hero">
        <div class="page-hero__inner">
            <span class="page-hero__eyebrow">Integrated atlas · gene expression</span>
            <h1 class="page-hero__title title-with-help">
                <button type="button" class="analysis-help" aria-label="About integrated expression" aria-describedby="help-expression" aria-expanded="false" data-help-target="help-expression">Expression</button>
            </h1>
            <span id="help-expression" class="visually-hidden">Overlay a gene's expression intensity on the integrated human or mouse skin UMAP. Gene-symbol matching is case-insensitive.</span>
        </div>
    </section>

    <div class="umap-shell">

        <!-- Controls -->
        <section class="panel umap-controls" aria-labelledby="umap-controls-title">
            <div class="panel-body">
                <div class="umap-control-row">
                    <div class="umap-control">
                        <span class="filter-name" id="umap-controls-title">Species</span>
                        <div class="species-toggle" role="radiogroup" aria-label="Species">
                            <label>
                                <input type="radio" name="umap-species" value="human" data-preference-key="species" checked>
                                <span class="species-toggle__option">Human</span>
                            </label>
                            <label>
                                <input type="radio" name="umap-species" value="mouse" data-preference-key="species">
                                <span class="species-toggle__option">Mouse</span>
                            </label>
                        </div>
                    </div>

                    <div class="umap-control umap-control--search">
                        <label class="filter-name" for="geneInput">Gene</label>
                        <div class="gene-search">
                            <input type="text" id="geneInput" class="gene-search__input"
                                   placeholder="Search gene…" autocomplete="off"
                                   spellcheck="false" role="combobox" aria-autocomplete="list"
                                   aria-expanded="false" aria-controls="geneSuggest">
                            <ul id="geneSuggest" class="gene-search__suggest" role="listbox" hidden></ul>
                        </div>
                    </div>

                    <div class="umap-control umap-control--action">
                        <span class="filter-name">&nbsp;</span>
                        <button id="clearGeneBtn" class="btn-secondary" disabled>Clear gene</button>
                    </div>
                </div>

                <div id="geneStatus" class="umap-gene-status umap-gene-status--warn" hidden></div>
            </div>
        </section>

        <!-- Plot -->
        <section class="panel" aria-label="UMAP feature plot">
            <div class="panel-body umap-plot-body">
                <div class="umap-stage">
                    <div id="umapPlot" class="umap-plot"></div>
                    <div id="umapLegend" class="umap-legend"></div>
                    <div id="umapLoading" class="umap-overlay-state panel-loader" role="status" aria-label="Loading"></div>
                    <div id="umapError" class="umap-overlay-state umap-overlay-state--error" hidden></div>
                </div>
            </div>
        </section>

    </div>
</main>

<script src="JS/umap-overlay-core.js?v=<%= System.currentTimeMillis() %>"></script>
<script src="JS/umap-explorer.js?v=<%= System.currentTimeMillis() %>"></script>
<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
