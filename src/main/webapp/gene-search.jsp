<%@ page language="java"
         contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" %>
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
    <title>Gene Search - scSAID</title>
    <meta name="description" content="Search a gene across all differential expression (DEG) results in the scSAID skin atlas. Find in which dataset and cell population your gene of interest is up/down-regulated.">
    <meta name="keywords" content="gene DEG search, scSAID gene, differential expression skin, scRNA-seq gene search, skin marker gene, keratinocyte DEG">
    <meta name="robots" content="index,follow">
    <link rel="canonical" href="https://skin-scsaid.com/gene-search.jsp">

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;0,600;1,300;1,600&display=swap" rel="stylesheet">

    <!-- Design System — same primitives as Details / Compare -->
    <link rel="stylesheet" href="CSS/design-system.css?v=20260703q">
    <link rel="stylesheet" href="CSS/header.css?v=20260703h">
    <link rel="stylesheet" href="CSS/details.css?v=20260703d">
    <link rel="stylesheet" href="CSS/search.css?v=20260702p">
    <link rel="stylesheet" href="CSS/humanbase-tables.css?v=20260703b">
    <style>
        /* Gene-name autocomplete dropdown (inline so edge-caching never staleness it) */
        /* The form itself uses overflow:hidden for its pill shape, so the dropdown
           lives in a non-clipping wrapper that matches the form's width. */
        .search-box-wrap { position: relative; max-width: 640px; margin: 0 auto; }
        .search-suggest {
            position: absolute; top: calc(100% + 4px); left: 0; right: 0; z-index: 60;
            margin: 0; padding: 5px 0; list-style: none; text-align: left;
            background: var(--bg-surface); border: 1px solid rgba(0, 0, 0, 0.15);
            border-radius: var(--radius-sm); box-shadow: var(--dropdown-shadow);
            max-height: 300px; overflow-y: auto;
        }
        .search-suggest__item {
            padding: 0.55rem 0.8rem; font-family: var(--font-mono); font-size: 0.9rem;
            color: var(--text-primary); border-radius: var(--radius-sm); cursor: pointer;
        }
        .search-suggest__item mark { background: transparent; color: var(--color-secondary-dark); font-weight: 300; }
        .search-suggest__item:hover,
        .search-suggest__item.is-active {
            background: color-mix(in srgb, var(--color-secondary) 14%, transparent);
        }
    </style>
</head>
<body>

<%@ include file="includes/header.jsp" %>

<main class="search-page" id="main-content" tabindex="-1">

    <!-- ============================================================
         Hero — cream, serif, with integrated search box
         ============================================================ -->
    <section class="search-hero">
        <span class="search-hero__eyebrow">Gene explorer</span>
        <h1 class="search-hero__title title-with-help">
            <button type="button" class="analysis-help" aria-label="About cross-dataset gene search" aria-describedby="help-gene-search" aria-expanded="false" data-help-target="help-gene-search">Search genes across all datasets</button>
        </h1>
        <span id="help-gene-search" class="visually-hidden">Query differential-expression results across all scSAID datasets and cell types to locate the populations and effect sizes associated with a gene.</span>

        <div class="search-box-wrap">
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
        <ul id="gene-suggest" class="search-suggest" role="listbox" hidden></ul>
        </div>

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
            <div class="panel-body panel-loader" role="status" aria-label="Loading"></div>
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
                    <div class="table-wrapper hb-table-shell">
                        <table class="results-table hb-table">
                            <thead>
                                <tr>
                                    <th class="cell-checkbox">
                                        <input type="checkbox" id="select-all" class="gene-checkbox" aria-label="Select all genes">
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
                    <h2 class="panel-title title-with-help">
                        <button type="button" class="analysis-help" aria-label="About integrated UMAP visualization" aria-describedby="help-search-umap" aria-expanded="false" data-help-target="help-search-umap">Gene expression on integrated UMAP</button>
                    </h2>
                    <span id="help-search-umap" class="visually-hidden">Selected genes are displayed on the integrated UMAP for cross-dataset expression comparison.</span>
                    <p class="panel-description" id="viz-gene-count">Select genes above, then press <em>Visualize on UMAP</em>.</p>
                </header>
                <div class="panel-body panel-body--flush">
                    <div id="viz-iframe-container" class="viz-panel__iframe-container" hidden>
                        <div id="viz-loading" class="viz-panel__loading panel-loader" role="status" aria-label="Loading"></div>
                        <iframe id="viz-iframe" class="viz-panel__iframe" src="" title="Gene expression UMAP viewer"></iframe>
                    </div>
                </div>
            </article>

        </div>

    </section>
</main>

<script src="lib/jquery-3.7.1.min.js"></script>
<script src="JS/umap-overlay-core.js?v=<%= System.currentTimeMillis() %>"></script>
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
                checkboxHtml = '<input type="checkbox" class="gene-checkbox gene-select" data-gene="' + escapeHtml(row.gene) + '" aria-label="Select gene ' + escapeHtml(row.gene) + '">';
                processedGenes.add(row.gene);
            }

            html += '<tr data-gene="' + escapeHtml(row.gene) + '">';
            html += '<td class="cell-checkbox" data-label="Select">' + checkboxHtml + '</td>';
            html += '<td class="cell-gene" data-label="Gene"><a href="gene-details?gene=' + encodeURIComponent(row.gene) + '&species=human" class="gene-link">' + geneName + '<span class="gene-link-icon">→</span></a></td>';
            html += '<td data-label="Dataset"><a href="details.jsp?said=' + encodeURIComponent(row.said) + '" class="cell-link">' + row.said + '</a></td>';
            html += '<td data-label="GSE">' + escapeHtml(row.gse) + '</td>';
            html += '<td data-label="Cell type"><span class="group-badge">' + escapeHtml(row.group) + '</span></td>';
            html += '<td data-label="log₂ FC"><span class="expression-badge ' + fcClass + '">' + fcSign + row.logfc + '</span></td>';
            html += '<td class="cell-pval" data-label="Adj. p">' + escapeHtml(row.pval) + '</td>';
            html += '<td data-label="Action"><a href="details.jsp?said=' + encodeURIComponent(row.said) + '#DEG" class="cell-link">Dataset</a><a href="gene-details?gene=' + encodeURIComponent(row.gene) + '&species=human" class="cell-link">Gene Info</a></td>';
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

    // ---- Gene-name autocomplete (real-time, partial + fuzzy) -------------
    var geneUniverse = [];
    var $suggest = $('#gene-suggest');
    var suggestIdx = -1, suggestTimer = null;

    // Load the gene vocabulary (human + mouse panels) for suggestions.
    $.when(
        $.getJSON('/integrated_umap/api/genes?species=human'),
        $.getJSON('/integrated_umap/api/genes?species=mouse')
    ).done(function (h, m) {
        var seen = {}, all = ((h[0] && h[0].genes) || []).concat((m[0] && m[0].genes) || []);
        for (var i = 0; i < all.length; i++) {
            var k = all[i].toLowerCase();
            if (!seen[k]) { seen[k] = 1; geneUniverse.push(all[i]); }
        }
    });

    function renderSuggest() {
        var q = $input.val();
        var matches = (q && q.trim() && window.UMAPOverlayCore)
            ? UMAPOverlayCore.filterGenes(q, geneUniverse, 8) : [];
        suggestIdx = -1;
        if (!matches.length) { hideSuggest(); return; }
        var ql = q.trim().toLowerCase(), html = '';
        for (var i = 0; i < matches.length; i++) {
            html += '<li class="search-suggest__item" role="option" data-gene="'
                + escapeHtml(matches[i]) + '">' + highlightMatch(matches[i], ql) + '</li>';
        }
        $suggest.html(html).prop('hidden', false);
    }
    function hideSuggest() { $suggest.prop('hidden', true); suggestIdx = -1; }
    function suggestItems() { return $suggest.find('.search-suggest__item'); }
    function highlightSuggest(i) {
        var items = suggestItems();
        items.removeClass('is-active');
        if (i >= 0 && i < items.length) { items.eq(i).addClass('is-active'); suggestIdx = i; }
    }
    function selectSuggest(gene) { $input.val(gene); hideSuggest(); performSearch(gene); }

    $input.on('input', function () { clearTimeout(suggestTimer); suggestTimer = setTimeout(renderSuggest, 140); });
    $input.on('focus', function () { if ($input.val().trim()) { renderSuggest(); } });
    $input.on('keydown', function (e) {
        var items = suggestItems();
        var open = !$suggest.prop('hidden') && items.length;
        if (e.which === 40 && open) { e.preventDefault(); highlightSuggest(Math.min(suggestIdx + 1, items.length - 1)); }
        else if (e.which === 38 && open) { e.preventDefault(); highlightSuggest(Math.max(suggestIdx - 1, 0)); }
        else if (e.which === 13) {
            e.preventDefault();
            if (open && suggestIdx >= 0) { selectSuggest(items.eq(suggestIdx).data('gene')); }
            else { hideSuggest(); performSearch($input.val()); }
        } else if (e.which === 27) { hideSuggest(); }
    });
    $suggest.on('mousedown', '.search-suggest__item', function (e) { e.preventDefault(); selectSuggest($(this).data('gene')); });
    $(document).on('click', function (e) { if (!$(e.target).closest('.search-box-wrap').length) { hideSuggest(); } });

    // Wire up events
    $searchBtn.on('click', function() { performSearch($input.val()); });

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



<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
