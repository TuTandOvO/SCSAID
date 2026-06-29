<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
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
    <meta name="theme-color" content="#1a2332">
    <title>Gene Search - scSAID</title>
    <meta name="description" content="Search a gene across all differential expression (DEG) results in the scSAID skin atlas. Find in which dataset and cell population your gene of interest is up/down-regulated.">
    <meta name="keywords" content="gene DEG search, scSAID gene, differential expression skin, scRNA-seq gene search, skin marker gene, keratinocyte DEG">
    <meta name="robots" content="index,follow">
    <link rel="canonical" href="https://skin-scsaid.com/gene-search.jsp">

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;500;600;700&family=Montserrat:wght@200;300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

    <!-- Design System — same primitives as Details / Compare -->
    <link rel="stylesheet" href="CSS/design-system.css">
    <link rel="stylesheet" href="CSS/header.css">
    <link rel="stylesheet" href="CSS/details.css">
    <link rel="stylesheet" href="CSS/search.css">
    <link rel="stylesheet" href="CSS/construction-modal-simple.css">
</head>
<body>

<!-- Header -->
<header class="site-header">
    <div class="container">
        <a href="index.jsp" class="site-logo">scSAID</a>
        <nav class="main-nav">
            <a href="index.jsp" class="main-nav__link">Home</a>
            <a href="browse.jsp" class="main-nav__link">Browse</a>
            <a href="gene-search.jsp" class="main-nav__link main-nav__link--active">Search</a>
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
            <a href="https://github.com/TuTandOvO/SCSAID" target="_blank" class="header-icon-link" title="View on GitHub">
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

<main class="search-page">

    <!-- ============================================================
         Hero — cream, serif, with integrated search box
         ============================================================ -->
    <section class="search-hero">
        <span class="search-hero__eyebrow">Gene explorer</span>
        <h1 class="search-hero__title">Search genes across all datasets</h1>
        <p class="search-hero__description">
            Query differentially expressed genes across the entire scSAID single-cell RNA sequencing collection
            — find where, in which population, and at what effect size your gene of interest is regulated.
        </p>

        <form class="search-box" role="search" onsubmit="return false;">
            <input type="text" id="gene-query" class="search-box__input"
                   placeholder="Enter a gene symbol — e.g. KRT14, COL1A1, ACTA2"
                   autocomplete="off" spellcheck="false">
            <button id="search-btn" class="search-box__btn" type="submit">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <circle cx="11" cy="11" r="8"></circle>
                    <path d="M21 21l-4.35-4.35"></path>
                </svg>
                <span>Search</span>
            </button>
        </form>

        <div class="search-examples" aria-label="Example genes">
            <span class="search-examples__label">Try</span>
            <button class="search-examples__btn" data-gene="KRT14">KRT14</button>
            <button class="search-examples__btn" data-gene="COL1A1">COL1A1</button>
            <button class="search-examples__btn" data-gene="ACTA2">ACTA2</button>
            <button class="search-examples__btn" data-gene="PECAM1">PECAM1</button>
            <button class="search-examples__btn" data-gene="CD3E">CD3E</button>
        </div>
    </section>

    <!-- ============================================================
         Results section
         ============================================================ -->
    <section class="results-section" id="results-section">

        <!-- Initial / empty state -->
        <article id="empty-state" class="panel panel--empty">
            <div class="panel-body">
                <div class="state-block">
                    <svg class="state-block__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
                        <circle cx="11" cy="11" r="7" stroke-linecap="round" stroke-linejoin="round"/>
                        <path d="M21 21l-4.35-4.35" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                    <h2 class="state-block__title">Enter a gene name to search</h2>
                    <p class="state-block__text">Matching DEG rows across every scSAID dataset and cell type will appear here. Try one of the example genes above to get started.</p>
                </div>
            </div>
        </article>

        <!-- Loading state -->
        <article id="loading-state" class="panel panel--empty" hidden>
            <div class="panel-body">
                <div class="state-block">
                    <span class="spinner spinner--lg" aria-label="Searching"></span>
                    <p class="state-block__text">Searching across all datasets…</p>
                </div>
            </div>
        </article>

        <!-- No results state -->
        <article id="no-results-state" class="panel panel--empty" hidden>
            <div class="panel-body">
                <div class="state-block">
                    <svg class="state-block__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
                        <circle cx="12" cy="12" r="9" stroke-linecap="round" stroke-linejoin="round"/>
                        <path d="M9 9l6 6M15 9l-6 6" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                    <h2 class="state-block__title">No results found</h2>
                    <p class="state-block__text">Try a different gene symbol or check the spelling. Both human (HUGO) and mouse (MGI) symbols are supported.</p>
                </div>
            </div>
        </article>

        <!-- Results container -->
        <div id="results-container" hidden>

            <article class="panel">
                <header class="panel-header panel-header--split">
                    <div>
                        <span class="panel-eyebrow">Results</span>
                        <h2 class="panel-title">Search results</h2>
                    </div>
                    <span id="results-count" class="panel-count"></span>
                </header>
                <div class="panel-body panel-body--flush">
                    <div class="table-wrapper">
                        <table class="results-table">
                            <thead>
                                <tr>
                                    <th class="cell-checkbox">
                                        <input type="checkbox" id="select-all" class="gene-checkbox" title="Select all genes">
                                    </th>
                                    <th>Gene</th>
                                    <th>Dataset</th>
                                    <th>GSE</th>
                                    <th>Cell type</th>
                                    <th>log₂ FC</th>
                                    <th>Adj. p</th>
                                    <th>Action</th>
                                </tr>
                            </thead>
                            <tbody id="results-body"></tbody>
                        </table>
                    </div>
                </div>
            </article>

            <!-- Sticky selection bar (appears when ≥1 gene selected) -->
            <div id="selection-bar" class="selection-bar" hidden>
                <div class="selection-bar__count"><strong id="sel-count">0</strong>genes selected</div>
                <div id="selected-genes-display" class="selection-bar__genes" aria-live="polite"></div>
                <div class="selection-bar__actions">
                    <button id="clear-selection-btn" class="btn-ghost">Clear</button>
                    <button id="visualize-btn" class="btn-primary" disabled>Visualize on UMAP</button>
                </div>
            </div>

            <!-- UMAP visualization panel -->
            <article id="viz-panel" class="panel viz-panel" hidden>
                <header class="panel-header">
                    <span class="panel-eyebrow">Expression visualization</span>
                    <h2 class="panel-title">Gene expression on integrated UMAP</h2>
                    <p class="panel-description" id="viz-gene-count">Select genes above, then press <em>Visualize on UMAP</em>.</p>
                </header>
                <div class="panel-body panel-body--flush">
                    <div id="viz-iframe-container" class="viz-panel__iframe-container" hidden>
                        <div id="viz-loading" class="viz-panel__loading">
                            <span class="spinner spinner--lg" aria-label="Loading"></span>
                            <p class="state-block__text">Loading visualization…</p>
                        </div>
                        <iframe id="viz-iframe" class="viz-panel__iframe" src="" title="Gene expression UMAP viewer"></iframe>
                    </div>
                </div>
            </article>

        </div>

    </section>
</main>

<script src="lib/jquery-3.7.1.min.js"></script>
<script>
$(document).ready(function() {
    const $input = $('#gene-query');
    const $searchBtn = $('#search-btn');
    const $loadingState = $('#loading-state');
    const $resultsContainer = $('#results-container');
    const $emptyState = $('#empty-state');
    const $noResultsState = $('#no-results-state');
    const $resultsBody = $('#results-body');
    const $resultsCount = $('#results-count');
    const $selectAll = $('#select-all');

    // Visualization elements
    const $vizPanel = $('#viz-panel');
    const $vizBtn = $('#visualize-btn');
    const $clearSelectionBtn = $('#clear-selection-btn');
    const $selectedGenesDisplay = $('#selected-genes-display');
    const $vizGeneCount = $('#viz-gene-count');
    const $vizIframeContainer = $('#viz-iframe-container');
    const $vizIframe = $('#viz-iframe');
    const $vizLoading = $('#viz-loading');

    // Sticky selection bar
    const $selectionBar = $('#selection-bar');
    const $selCount = $('#sel-count');

    let currentQuery = '';
    let selectedGenes = new Set();

    function showOnly($which) {
        [$emptyState, $loadingState, $noResultsState, $resultsContainer].forEach(function($el) {
            if ($el.is($which)) {
                $el.prop('hidden', false).css('display', '');
            } else {
                $el.prop('hidden', true);
            }
        });
    }

    function performSearch(query) {
        if (!query || query.trim() === '') return;

        query = query.trim();
        currentQuery = query.toLowerCase();

        // Reset selection
        selectedGenes.clear();
        updateSelectionUI();
        $vizPanel.prop('hidden', true);
        $vizIframeContainer.prop('hidden', true);
        $vizIframe.attr('src', '');

        showOnly($loadingState);
        $searchBtn.prop('disabled', true);

        $.ajax({
            url: 'gene-search',
            type: 'GET',
            data: { q: query },
            success: function(response) {
                $searchBtn.prop('disabled', false);
                if (response.results && response.results.length > 0) {
                    renderResults(response.results, response.count);
                    showOnly($resultsContainer);
                } else {
                    showOnly($noResultsState);
                }
            },
            error: function(xhr, status, error) {
                $searchBtn.prop('disabled', false);
                alert('Search error: ' + error);
                showOnly($emptyState);
            }
        });
    }

    function renderResults(results, count) {
        $resultsCount.html('<strong>' + count + '</strong>' + (count === 1 ? ' result' : ' results')
            + (count >= 500 ? ' · showing top 500' : ''));

        let html = '';
        let processedGenes = new Set();

        results.forEach(function(row) {
            const logfc = parseFloat(row.logfc);
            const isUp = logfc > 0;
            const fcClass = isUp ? 'expression-badge--up' : 'expression-badge--down';
            const fcSign = isUp ? '+' : '';

            const geneName = highlightMatch(row.gene, currentQuery);

            let checkboxHtml = '';
            if (!processedGenes.has(row.gene)) {
                checkboxHtml = '<input type="checkbox" class="gene-checkbox gene-select" data-gene="' + escapeHtml(row.gene) + '">';
                processedGenes.add(row.gene);
            }

            html += '<tr data-gene="' + escapeHtml(row.gene) + '">';
            html += '<td class="cell-checkbox">' + checkboxHtml + '</td>';
            html += '<td class="cell-gene"><a href="gene-details?gene=' + encodeURIComponent(row.gene) + '&species=human" class="gene-link">' + geneName + '<span class="gene-link-icon">→</span></a></td>';
            html += '<td><a href="details.jsp?said=' + encodeURIComponent(row.said) + '" class="cell-link">' + row.said + '</a></td>';
            html += '<td>' + escapeHtml(row.gse) + '</td>';
            html += '<td><span class="group-badge">' + escapeHtml(row.group) + '</span></td>';
            html += '<td><span class="expression-badge ' + fcClass + '">' + fcSign + row.logfc + '</span></td>';
            html += '<td class="cell-pval">' + escapeHtml(row.pval) + '</td>';
            html += '<td><a href="details.jsp?said=' + encodeURIComponent(row.said) + '#DEG" class="cell-link">Dataset</a><a href="gene-details?gene=' + encodeURIComponent(row.gene) + '&species=human" class="cell-link">Gene Info</a></td>';
            html += '</tr>';
        });

        $resultsBody.html(html);

        $('.gene-select').on('change', function() {
            const gene = $(this).data('gene');
            if ($(this).prop('checked')) {
                selectedGenes.add(gene);
            } else {
                selectedGenes.delete(gene);
            }
            updateSelectionUI();
            updateRowHighlighting();
        });

        $selectAll.prop('checked', false);
    }

    function updateRowHighlighting() {
        $('#results-body tr').each(function() {
            const gene = $(this).data('gene');
            $(this).toggleClass('is-selected', selectedGenes.has(gene));
        });
    }

    function updateSelectionUI() {
        const count = selectedGenes.size;
        $selCount.text(count);

        if (count === 0) {
            $selectedGenesDisplay.text('');
            $vizBtn.prop('disabled', true);
            $vizGeneCount.text('Select genes above, then press Visualize on UMAP.');
            $selectionBar.prop('hidden', true);
            $vizPanel.prop('hidden', true);
        } else {
            const genesList = Array.from(selectedGenes).join(', ');
            $selectedGenesDisplay.text(genesList);
            $vizBtn.prop('disabled', false);
            $vizGeneCount.text(count + ' gene' + (count > 1 ? 's' : '') + ' selected · ' + genesList);
            $selectionBar.prop('hidden', false);
            $vizPanel.prop('hidden', false);
        }
    }

    function visualizeGenes() {
        if (selectedGenes.size === 0) return;

        const genesList = Array.from(selectedGenes).join(',');
        const vizUrl = 'http://localhost:8053/gene-viz/?genes=' + encodeURIComponent(genesList);

        $vizIframeContainer.prop('hidden', false);
        $vizLoading.removeClass('is-hidden');
        $vizBtn.prop('disabled', true);

        $vizIframe.attr('src', vizUrl);

        $vizIframe.off('load').on('load', function() {
            setTimeout(function() {
                $vizLoading.addClass('is-hidden');
                $vizBtn.prop('disabled', false);
            }, 500);
        });

        setTimeout(function() {
            $vizPanel[0].scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }, 100);
    }

    function clearSelection() {
        selectedGenes.clear();
        $('.gene-select').prop('checked', false);
        $selectAll.prop('checked', false);
        updateSelectionUI();
        updateRowHighlighting();
        $vizIframeContainer.prop('hidden', true);
        $vizIframe.attr('src', '');
    }

    function highlightMatch(text, query) {
        const regex = new RegExp('(' + escapeRegex(query) + ')', 'gi');
        return escapeHtml(text).replace(regex, '<mark>$1</mark>');
    }

    function escapeHtml(text) {
        if (text === null || text === undefined) return '';
        const div = document.createElement('div');
        div.textContent = String(text);
        return div.innerHTML;
    }

    function escapeRegex(string) {
        return string.replace(/[.*+?^$\x7B\x7D()|[\]\\]/g, '\\$&');
    }

    // Wire up events
    $searchBtn.on('click', function() { performSearch($input.val()); });
    $input.on('keypress', function(e) { if (e.which === 13) { e.preventDefault(); performSearch($input.val()); } });

    $('.search-examples__btn').on('click', function() {
        const gene = $(this).data('gene');
        $input.val(gene);
        performSearch(gene);
    });

    $selectAll.on('change', function() {
        const isChecked = $(this).prop('checked');
        $('.gene-select').each(function() {
            $(this).prop('checked', isChecked);
            const gene = $(this).data('gene');
            if (isChecked) selectedGenes.add(gene);
            else selectedGenes.delete(gene);
        });
        updateSelectionUI();
        updateRowHighlighting();
    });

    $vizBtn.on('click', visualizeGenes);
    $clearSelectionBtn.on('click', clearSelection);
});
</script>

<!-- Under Construction Modal Script -->
<script src="JS/construction-modal-simple.js"></script>


<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
