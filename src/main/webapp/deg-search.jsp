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
    <title>Search DEG - scSAID</title>
    <meta name="description" content="Search condition and perturbation versus Healthy pseudobulk DEGs across the scSAID skin atlas.">
    <meta name="keywords" content="DEG search, condition versus healthy, perturbation DEG, disease DEG, pseudobulk DESeq2, scSAID">
    <meta name="robots" content="index,follow">
    <link rel="canonical" href="https://skin-scsaid.com/deg-search.jsp">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;0,600;1,300;1,600&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="CSS/design-system.css?v=20260710b">
    <link rel="stylesheet" href="CSS/header.css?v=20260704b">
    <link rel="stylesheet" href="CSS/details.css?v=20260710b">
    <link rel="stylesheet" href="CSS/search.css?v=20260709a">
    <link rel="stylesheet" href="CSS/humanbase-tables.css?v=20260703b">
    <style>
        .search-box-wrap { position: relative; max-width: 640px; margin: 0 auto; }
        .search-suggest {
            position: absolute; top: calc(100% + 4px); left: 0; right: 0; z-index: 60;
            margin: 0; padding: 5px 0; list-style: none; text-align: left;
            background: var(--bg-surface); border: 1px solid rgba(0, 0, 0, 0.15);
            border-radius: var(--radius-sm); box-shadow: var(--dropdown-shadow);
            max-height: 300px; overflow-y: auto;
        }
        .deg-index-status {
            max-width: 1120px;
            margin: 0 auto var(--space-lg);
            padding: 0 var(--space-xl);
            color: var(--text-secondary);
            font-size: 0.92rem;
        }
        .deg-index-status__card {
            border: 1px solid var(--border-light);
            border-radius: var(--radius-sm);
            background: var(--bg-surface);
            padding: 0.75rem 1rem;
        }
        .deg-index-status strong { color: var(--text-primary); }
    </style>
</head>
<body>

<%@ include file="includes/header.jsp" %>

<main class="search-page" id="main-content" tabindex="-1">
    <section class="search-hero">
        <span class="search-hero__eyebrow">Condition DEG explorer</span>
        <h1 class="search-hero__title title-with-help">
            <button type="button" class="analysis-help" aria-label="About condition DEG search" aria-describedby="help-deg-search" aria-expanded="false" data-help-target="help-deg-search">Search disease and perturbation DEGs</button>
        </h1>
        <span id="help-deg-search" class="visually-hidden">Search cached pseudobulk DESeq2 results for each non-Healthy condition versus Healthy. Log2 fold change is condition or perturbation relative to Healthy.</span>

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
            <button class="search-examples__btn" data-gene="CXCL8">CXCL8</button>
            <button class="search-examples__btn" data-gene="IL1B">IL1B</button>
        </div>
    </section>

    <div class="deg-index-status" id="index-status" hidden></div>

    <section class="results-section" id="results-section">
        <article id="empty-state" class="panel panel--empty" hidden>
            <div class="panel-body">
                <div class="state-block">
                    <svg class="state-block__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
                        <path d="M3 3v18h18" stroke-linecap="round" stroke-linejoin="round"/>
                        <path d="M7 14l3-3 3 3 5-5" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                    <h2 class="state-block__title">Enter a gene name to search</h2>
                    <p class="state-block__text">The search uses cached pseudobulk DESeq2 contrasts: each non-Healthy condition versus Healthy, per cell type and species.</p>
                </div>
            </div>
        </article>

        <article id="loading-state" class="panel panel--empty" hidden>
            <div class="panel-body panel-loader" role="status" aria-label="Loading"></div>
        </article>

        <article id="no-results-state" class="panel panel--empty" hidden>
            <div class="panel-body">
                <div class="state-block">
                    <svg class="state-block__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
                        <circle cx="12" cy="12" r="9" stroke-linecap="round" stroke-linejoin="round"/>
                        <path d="M9 9l6 6M15 9l-6 6" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                    <h2 class="state-block__title">No DEG results found</h2>
                    <p class="state-block__text">Try a different gene symbol, relax the adjusted p-value or fold-change threshold, or switch species.</p>
                </div>
            </div>
        </article>

        <div id="results-container" hidden>
            <article class="panel">
                <header class="panel-header panel-header--split">
                    <div>
                        <span class="panel-eyebrow">Condition vs Healthy</span>
                        <h2 class="panel-title">DEG search results</h2>
                    </div>
                    <span id="results-count" class="panel-count"></span>
                </header>
                <div class="panel-body panel-body--flush">
                    <div class="table-wrapper hb-table-shell">
                        <table class="results-table hb-table">
                            <thead>
                                <tr>
                                    <th class="cell-checkbox"><input type="checkbox" id="select-all" class="gene-checkbox" aria-label="Select all genes"></th>
                                    <th>Gene</th>
                                    <th>Species</th>
                                    <th>Condition</th>
                                    <th>Reference</th>
                                    <th>Cell type</th>
                                    <th>log₂ FC</th>
                                    <th>p-value</th>
                                    <th>Adj. p</th>
                                    <th>Action</th>
                                </tr>
                            </thead>
                            <tbody id="results-body"></tbody>
                        </table>
                    </div>
                </div>
            </article>

            <div id="selection-bar" class="selection-bar" hidden>
                <div class="selection-bar__count"><strong id="sel-count">0</strong>genes selected</div>
                <div id="selected-genes-display" class="selection-bar__genes" aria-live="polite"></div>
                <div class="selection-bar__actions">
                    <button id="clear-selection-btn" class="btn-ghost">Clear</button>
                    <button id="visualize-btn" class="btn-primary" disabled>Visualize on UMAP</button>
                </div>
            </div>
        </div>
    </section>
</main>

<script src="lib/jquery-3.7.1.min.js"></script>
<script src="JS/umap-overlay-core.js?v=<%= System.currentTimeMillis() %>"></script>
<script>
$(function() {
    const $input = $('#gene-query');
    const $searchBtn = $('#search-btn');
    const $loadingState = $('#loading-state');
    const $resultsContainer = $('#results-container');
    const $emptyState = $('#empty-state');
    const $noResultsState = $('#no-results-state');
    const $resultsBody = $('#results-body');
    const $resultsCount = $('#results-count');
    const $selectAll = $('#select-all');
    const $status = $('#index-status');
    const $selectionBar = $('#selection-bar');
    const $selCount = $('#sel-count');
    const $selectedGenesDisplay = $('#selected-genes-display');
    const $vizBtn = $('#visualize-btn');

    const SPECIES = ['human', 'mouse'];
    let state = { query: '', selectedGenes: new Set(), lastRows: [], statusTimer: null };

    function showOnly($which) {
        [$emptyState, $loadingState, $noResultsState, $resultsContainer].forEach(function($el) {
            $el.prop('hidden', !$el.is($which));
        });
    }
    function hideAllResults() {
        [$emptyState, $loadingState, $noResultsState, $resultsContainer].forEach(function($el) {
            $el.prop('hidden', true);
        });
    }
    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text == null ? '' : String(text);
        return div.innerHTML;
    }
    function escapeRegex(text) { return String(text).replace(/[.*+?^$\x7B\x7D()|[\]\\]/g, '\\$&'); }
    function highlightMatch(text, query) {
        return escapeHtml(text).replace(new RegExp('(' + escapeRegex(query) + ')', 'gi'), '<mark>$1</mark>');
    }
    function formatNumber(v) {
        const n = Number(v);
        if (!Number.isFinite(n)) return '';
        return Math.abs(n) < 0.001 ? n.toExponential(2) : n.toFixed(4).replace(/0+$/, '').replace(/\.$/, '');
    }
    function isPseudogene(name) {
        return /^(Gm\d+|.+-ps\d*|.+Rik|.+-PS\d*)$/.test(String(name || ''));
    }
    function statusHtml(payloads) {
        const ready = payloads.filter(function(p) { return p && p.state === 'ready'; });
        const building = payloads.filter(function(p) { return p && p.state === 'building'; });
        const missing = payloads.filter(function(p) { return p && p.state === 'missing'; });
        const errors = payloads.filter(function(p) { return p && p.state === 'error'; });

        if (building.length) {
            const p = building[0];
            const total = p.totalConditions || '?';
            const done = p.doneConditions || 0;
            const current = p.currentCondition ? ' · ' + escapeHtml(p.currentCondition) : '';
            clearTimeout(state.statusTimer);
            state.statusTimer = setTimeout(checkIndex, 5000);
            return '<strong>Preparing ' + escapeHtml(p.species) + ' DEG index</strong> · ' + done + '/' + total + current;
        }
        if (ready.length && !missing.length && !errors.length) {
            return '<strong>DEG indexes ready</strong> · human and mouse caches are available';
        }
        if (ready.length) {
            return '<strong>Partial DEG index ready</strong> · available: ' + ready.map(function(p) { return p.species; }).join(', ')
                + (missing.length ? ' · missing: ' + missing.map(function(p) { return p.species; }).join(', ') : '');
        }
        if (errors.length) {
            return '<strong>DEG index error:</strong> ' + escapeHtml(errors[0].error || 'unknown');
        }
        return '<strong>DEG index not prepared yet.</strong> The all-vs-Healthy cache is a server-side dataset and is not built from the browser.';
    }
    function setStatus(payloads) {
        $status.html('<div class="deg-index-status__card">' + statusHtml(payloads) + '</div>').prop('hidden', false);
    }
    function checkIndex() {
        $.when.apply($, SPECIES.map(function(species) {
            return $.getJSON('condition-deg-search/status', { species: species })
                .then(function(payload) { return payload; }, function(xhr) { return { state: 'error', species: species, error: 'HTTP ' + xhr.status }; });
        })).done(function() {
            setStatus(Array.prototype.slice.call(arguments));
        });
    }
    function params(species) {
        return {
            q: state.query,
            species: species,
            direction: 'both',
            pval: '0.05',
            fc: '1.0',
            hidePseudogenes: true
        };
    }
    function performSearch(query) {
        if (!query || !query.trim()) {
            hideAllResults();
            $status.prop('hidden', true).empty();
            return;
        }
        state.query = query.trim();
        state.selectedGenes.clear();
        updateSelectionUI();
        showOnly($loadingState);
        $searchBtn.prop('disabled', true);
        $.when.apply($, SPECIES.map(function(species) {
            return $.getJSON('condition-deg-search', params(species))
                .then(function(payload) { return payload; }, function(xhr) { return { state: 'error', species: species, error: 'HTTP ' + xhr.status, results: [], count: 0 }; });
        })).done(function() {
            $searchBtn.prop('disabled', false);
            const payloads = Array.prototype.slice.call(arguments);
            const rows = [];
            let count = 0;
            payloads.forEach(function(payload) {
                if (payload.state === 'ready') {
                    rows.push.apply(rows, payload.results || []);
                    count += payload.count || (payload.results || []).length;
                }
            });
            rows.sort(function(a, b) { return Number(a.pval_adj || Infinity) - Number(b.pval_adj || Infinity); });
            state.lastRows = rows.slice(0, 500);
            setStatus(payloads);
            if (state.lastRows.length) {
                renderResults(state.lastRows, count);
                showOnly($resultsContainer);
            } else {
                showOnly($noResultsState);
            }
        });
    }
    function renderResults(rows, count) {
        $resultsCount.html('<strong>' + count + '</strong>' + (count === 1 ? ' result' : ' results') + (count >= 500 ? ' · showing top 500' : ''));
        const processed = {};
        let html = '';
        rows.forEach(function(row) {
            const logfc = Number(row.logFC);
            const fcClass = logfc >= 0 ? 'expression-badge--up' : 'expression-badge--down';
            const fcSign = logfc > 0 ? '+' : '';
            let checkbox = '';
            if (!processed[row.gene]) {
                checkbox = '<input type="checkbox" class="gene-checkbox gene-select" data-gene="' + escapeHtml(row.gene) + '" aria-label="Select gene ' + escapeHtml(row.gene) + '">';
                processed[row.gene] = true;
            }
            const compareUrl = 'compare.jsp?species=' + encodeURIComponent(row.species) + '&conditionA=' + encodeURIComponent(row.condition) + '&conditionB=Healthy';
            html += '<tr data-gene="' + escapeHtml(row.gene) + '">';
            html += '<td class="cell-checkbox" data-label="Select">' + checkbox + '</td>';
            html += '<td class="cell-gene" data-label="Gene"><a href="gene-details?gene=' + encodeURIComponent(row.gene) + '&species=' + encodeURIComponent(row.species) + '" class="gene-link">' + highlightMatch(row.gene, state.query) + '<span class="gene-link-icon">→</span></a></td>';
            html += '<td data-label="Species">' + escapeHtml(row.species) + '</td>';
            html += '<td data-label="Condition">' + escapeHtml(row.condition) + '</td>';
            html += '<td data-label="Reference">' + escapeHtml(row.reference) + '</td>';
            html += '<td data-label="Cell type"><span class="group-badge">' + escapeHtml(row.cell_type) + '</span></td>';
            html += '<td data-label="log₂ FC"><span class="expression-badge ' + fcClass + '">' + fcSign + formatNumber(row.logFC) + '</span></td>';
            html += '<td class="cell-pval" data-label="p-value">' + formatNumber(row.pval) + '</td>';
            html += '<td class="cell-pval" data-label="Adj. p">' + formatNumber(row.pval_adj) + '</td>';
            html += '<td data-label="Action"><a href="' + compareUrl + '" class="cell-link">Compare</a><a href="gene-details?gene=' + encodeURIComponent(row.gene) + '&species=' + encodeURIComponent(row.species) + '" class="cell-link">Gene Info</a></td>';
            html += '</tr>';
        });
        $resultsBody.html(html);
        $('.gene-select').on('change', function() {
            const gene = $(this).data('gene');
            if ($(this).prop('checked')) state.selectedGenes.add(gene);
            else state.selectedGenes.delete(gene);
            updateSelectionUI();
            updateRowHighlighting();
        });
        $selectAll.prop('checked', false);
    }
    function updateRowHighlighting() {
        $('#results-body tr').each(function() {
            $(this).toggleClass('is-selected', state.selectedGenes.has($(this).data('gene')));
        });
    }
    function updateSelectionUI() {
        const count = state.selectedGenes.size;
        $selCount.text(count);
        if (!count) {
            $selectedGenesDisplay.text('');
            $vizBtn.prop('disabled', true);
            $selectionBar.prop('hidden', true);
        } else {
            $selectedGenesDisplay.text(Array.from(state.selectedGenes).join(', '));
            $vizBtn.prop('disabled', false);
            $selectionBar.prop('hidden', false);
        }
    }
    function visualizeGenes() {
        if (!state.selectedGenes.size) return;
        const genesList = Array.from(state.selectedGenes).join(',');
        window.location.href = 'featureplot.jsp?genes=' + encodeURIComponent(genesList);
    }

    $searchBtn.on('click', function() { performSearch($input.val()); });
    $input.on('keydown', function(e) { if (e.which === 13) { e.preventDefault(); performSearch($input.val()); } });
    $('.search-examples__btn').on('click', function() { $input.val($(this).data('gene')); performSearch($input.val()); });
    $selectAll.on('change', function() {
        const checked = $(this).prop('checked');
        $('.gene-select').each(function() {
            $(this).prop('checked', checked);
            const gene = $(this).data('gene');
            if (checked) state.selectedGenes.add(gene); else state.selectedGenes.delete(gene);
        });
        updateSelectionUI();
        updateRowHighlighting();
    });
    $('#clear-selection-btn').on('click', function() {
        state.selectedGenes.clear();
        $('.gene-select').prop('checked', false);
        $selectAll.prop('checked', false);
        updateSelectionUI();
        updateRowHighlighting();
    });
    $vizBtn.on('click', visualizeGenes);

});
</script>
<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
