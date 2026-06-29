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
    <title>Gene Expression Explorer - scSAID</title>
    <meta name="description" content="Search a gene and see its expression intensity overlaid on the integrated human or mouse skin UMAP — a CZ CELLxGENE-style FeaturePlot.">

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;500;600;700&family=Montserrat:wght@200;300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

    <!-- Design System + reused page styles -->
    <link rel="stylesheet" href="CSS/design-system.css?v=<%= System.currentTimeMillis() %>">
    <link rel="stylesheet" href="CSS/header.css">
    <link rel="stylesheet" href="CSS/details.css?v=<%= System.currentTimeMillis() %>">
    <link rel="stylesheet" href="CSS/compare.css?v=<%= System.currentTimeMillis() %>">
    <link rel="stylesheet" href="CSS/umap-explorer.css?v=<%= System.currentTimeMillis() %>">

    <!-- Third-party libs -->
    <script src="lib/jquery-3.7.1.min.js?v=20260420"></script>
    <script src="lib/plotly-2.20.0.min.js?v=20260420"></script>
</head>
<body>

<!-- Header -->
<header class="site-header">
    <div class="container">
        <a href="index.jsp" class="site-logo">scSAID</a>
        <nav class="main-nav">
            <a href="index.jsp" class="main-nav__link">Home</a>
            <a href="browse.jsp" class="main-nav__link">Browse</a>
            <a href="gene-search.jsp" class="main-nav__link">Search</a>
            <a href="compare.jsp" class="main-nav__link">Compare</a>
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

<main class="umap-page">

    <!-- Editorial hero -->
    <section class="page-hero">
        <div class="page-hero__inner">
            <span class="page-hero__eyebrow">Single-cell expression</span>
            <h1 class="page-hero__title">Gene expression explorer</h1>
            <p class="page-hero__description">
                Search a gene and see its expression intensity painted onto the integrated skin UMAP,
                FeaturePlot-style. Human and mouse atlases, ~50k representative cells each.
            </p>
        </div>
    </section>

    <div class="umap-shell">

        <!-- Controls -->
        <section class="panel" aria-labelledby="umap-controls-title">
            <div class="panel-body">
                <div class="umap-control-row">
                    <div class="umap-control">
                        <span class="filter-name" id="umap-controls-title">Species</span>
                        <div class="species-toggle" role="radiogroup" aria-label="Species">
                            <label>
                                <input type="radio" name="umap-species" value="human" checked>
                                <span class="species-toggle__option">Human</span>
                            </label>
                            <label>
                                <input type="radio" name="umap-species" value="mouse">
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
                    <div id="umapLoading" class="umap-overlay-state">
                        <span class="spinner"></span>
                        <span>Loading atlas…</span>
                    </div>
                    <div id="umapError" class="umap-overlay-state umap-overlay-state--error" hidden></div>
                </div>
            </div>
        </section>

    </div>
</main>

<script src="JS/umap-overlay-core.js?v=<%= System.currentTimeMillis() %>"></script>
<script src="JS/umap-explorer.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
