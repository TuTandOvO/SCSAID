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

    <link rel="stylesheet" href="CSS/design-system.css?v=20260703q">
    <link rel="stylesheet" href="CSS/header.css?v=20260704b">
    <link rel="stylesheet" href="CSS/details.css?v=20260703d">
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
        .deg-search-controls {
            max-width: 1120px;
            margin: 0 auto var(--space-xl);
            padding: 0 var(--space-xl);
        }
        .deg-search-controls .filter-grid { align-items: end; }
        .species-tabs {
            display: inline-flex;
            background: var(--bg-surface);
            border: 1px solid var(--border-light);
            border-radius: var(--radius-sm);
            overflow: hidden;
            box-shadow: var(--input-shadow);
        }
        .species-tab {
            border: 0;
            background: transparent;
            padding: 0.65rem 1.1rem;
            color: var(--text-secondary);
            font-family: var(--font-body);
            cursor: pointer;
            border-right: 1px solid var(--border-light);
        }
        .species-tab:last-child { border-right: 0; }
        .species-tab.is-active {
            background: var(--bg-muted);
            color: var(--color-primary);
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
        @media (max-width: 700px) {
            .deg-search-controls { padding: 0 var(--space-md); }
            .deg-search-controls .filter-grid { grid-template-columns: 1fr; }
            .species-tabs { width: 100%; }
            .species-tab { flex: 1; }
        }
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
        <span id="help-deg-search" class="visually-hidden">Search pseudobulk DESeq2 results for each non-Healthy condition versus Healthy within one species. Log2 fold change is condition or perturbation relative to Healthy.</span>

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

    <section class="deg-search-controls" aria-label="DEG search controls">
        <div class="filter-grid">
            <div class="filter-card">
                <span class="filter-name">Species</span>
                <div class="species-tabs" role="tablist" aria-label="Species">
                    <button type="button" class="species-tab is-active" data-species="human" role="tab" aria-selected="true">Human</button>
                    <button type="button" class="species-tab" data-species="mouse" role="tab" aria-selected="false">Mouse</button>
                </div>
            </div>
            <div class="filter-card">
                <label class="filter-name" for="condition-filter">Condition</label>
                <select id="condition-filter" class="form-select"><option value="">All conditions</option></select>
            </div>
            <div class="filter-card">
                <label class="filter-name" for="celltype-filter">Cell type</label>
                <select id="celltype-filter" class="form-select"><option value="">All cell types</option></select>
            </div>
            <div class="filter-card">
                <label class="filter-name" for="direction-filter">Direction</label>
                <select id="direction-filter" class="form-select">
                    <option value="both">Both</option>
                    <option value="up">Up in condition</option>
                    <option value="down">Down in condition</option>
                </select>
            </div>
            <div class="filter-card">
                <label class="filter-name" for="pval-filter">Adj. p ≤</label>
                <input type="number" id="pval-filter" class="form-input" min="0" max="1" step="0.001" value="0.05">
            </div>
            <div class="filter-card">
                <label class="filter-name" for="fc-filter">|log₂ FC| ≥</label>
                <input type="number" id="fc-filter" class="form-input" min="0" step="0.1" value="1.0">
            </div>
            <div class="filter-card">
                <span class="filter-name">Filter</span>
                <label class="checkbox-item">
                    <input type="checkbox" id="hide-pseudogenes" data-preference-key="hidePseudogenes" checked>
                    <span class="checkbox-item__text">Hide pseudogenes</span>
                </label>
            </div>
        </div>
    </section>

    <div class="deg-index-status" id="index-status" hidden></div>

    <section class="results-section" id="results-section">
        <article id="empty-state" class="panel panel--empty">
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
    const $condition = $('#condition-filter');
    const $cellType = $('#celltype-filter');
    const $selectionBar = $('#selection-bar');
    const $selCount = $('#sel-count');
    const $selectedGenesDisplay = $('#selected-genes-display');
    const $vizBtn = $('#visualize-btn');

    let state = { species: 'human', query: '', selectedGenes: new Set(), lastRows: [], statusTimer: null };

    function showOnly($which) {
        [$emptyState, $loadingState, $noResultsState, $resultsContainer].forEach(function($el) {
            $el.prop('hidden', !$el.is($which));
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
    function updateStatus(payload) {
        if (!payload || payload.state === 'ready') {
            const rows = payload && payload.rows ? ' · ' + payload.rows + ' cached rows' : '';
            $status.html('<div class="deg-index-status__card"><strong>' + state.species + ' index ready</strong>' + rows + '</div>').prop('hidden', false);
            return;
        }
        if (payload.state === 'building') {
            const total = payload.totalConditions || '?';
            const done = payload.doneConditions || 0;
            const current = payload.currentCondition ? ' · ' + escapeHtml(payload.currentCondition) : '';
            $status.html('<div class="deg-index-status__card"><strong>Preparing ' + state.species + ' DEG index</strong> · ' + done + '/' + total + current + '</div>').prop('hidden', false);
            clearTimeout(state.statusTimer);
            state.statusTimer = setTimeout(function() { checkIndex(false); }, 5000);
            return;
        }
        if (payload.state === 'missing') {
            $status.html('<div class="deg-index-status__card"><strong>Preparing ' + state.species + ' DEG index</strong> · starting background build</div>').prop('hidden', false);
            warmIndex();
            return;
        }
        if (payload.state === 'error') {
            $status.html('<div class="deg-index-status__card"><strong>DEG index error:</strong> ' + escapeHtml(payload.error || 'unknown') + '</div>').prop('hidden', false);
        }
    }
    function checkIndex(thenSearch) {
        $.getJSON('condition-deg-search/status', { species: state.species })
            .done(function(payload) {
                updateStatus(payload);
                if (payload.state === 'ready' && thenSearch) performSearch(state.query);
                else if ((payload.state === 'missing' || payload.state === 'building') && thenSearch) {
                    showOnly($loadingState);
                    setTimeout(function() { checkIndex(true); }, 4000);
                }
            })
            .fail(function(xhr) {
                $status.html('<div class="deg-index-status__card"><strong>Could not read DEG index status</strong> (' + xhr.status + ')</div>').prop('hidden', false);
            });
    }
    function warmIndex() {
        $.ajax({
            url: 'condition-deg-search/warm',
            method: 'POST',
            contentType: 'application/json',
            data: JSON.stringify({ species: state.species })
        }).done(updateStatus);
    }
    function loadConditions() {
        $.getJSON('conditions', { species: state.species }).done(function(rows) {
            $condition.html('<option value="">All conditions</option>');
            (rows || []).forEach(function(row) {
                if (row.condition && row.condition !== 'Healthy') {
                    $condition.append('<option value="' + escapeHtml(row.condition) + '">' + escapeHtml(row.condition) + ' (n=' + escapeHtml(row.n_samples) + ')</option>');
                }
            });
        });
    }
    function refreshCellTypes(rows) {
        const selected = $cellType.val() || '';
        const seen = {};
        (rows || []).forEach(function(row) { if (row.cell_type) seen[row.cell_type] = true; });
        const names = Object.keys(seen).sort();
        $cellType.html('<option value="">All cell types</option>');
        names.forEach(function(name) { $cellType.append('<option value="' + escapeHtml(name) + '">' + escapeHtml(name) + '</option>'); });
        if (selected && seen[selected]) $cellType.val(selected);
    }
    function params() {
        return {
            q: state.query,
            species: state.species,
            condition: $condition.val() || '',
            cellType: $cellType.val() || '',
            direction: $('#direction-filter').val() || 'both',
            pval: $('#pval-filter').val() || '0.05',
            fc: $('#fc-filter').val() || '1.0',
            hidePseudogenes: $('#hide-pseudogenes').is(':checked')
        };
    }
    function performSearch(query) {
        if (!query || !query.trim()) return;
        state.query = query.trim();
        state.selectedGenes.clear();
        updateSelectionUI();
        showOnly($loadingState);
        $searchBtn.prop('disabled', true);
        $.getJSON('condition-deg-search', params())
            .done(function(payload) {
                $searchBtn.prop('disabled', false);
                updateStatus(payload);
                if (payload.state && payload.state !== 'ready') {
                    setTimeout(function() { checkIndex(true); }, 4000);
                    return;
                }
                const rows = payload.results || [];
                state.lastRows = rows;
                refreshCellTypes(rows);
                if (rows.length) {
                    renderResults(rows, payload.count || rows.length);
                    showOnly($resultsContainer);
                } else {
                    showOnly($noResultsState);
                }
            })
            .fail(function(xhr) {
                $searchBtn.prop('disabled', false);
                $status.html('<div class="deg-index-status__card"><strong>Search failed</strong> (' + xhr.status + ')</div>').prop('hidden', false);
                showOnly($emptyState);
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
        window.location.href = 'featureplot.jsp?species=' + encodeURIComponent(state.species) + '&genes=' + encodeURIComponent(genesList);
    }

    $('.species-tab').on('click', function() {
        state.species = $(this).data('species');
        $('.species-tab').removeClass('is-active').attr('aria-selected', 'false');
        $(this).addClass('is-active').attr('aria-selected', 'true');
        state.selectedGenes.clear();
        updateSelectionUI();
        loadConditions();
        showOnly($emptyState);
        checkIndex(false);
    });
    $searchBtn.on('click', function() { performSearch($input.val()); });
    $input.on('keydown', function(e) { if (e.which === 13) { e.preventDefault(); performSearch($input.val()); } });
    $('.search-examples__btn').on('click', function() { $input.val($(this).data('gene')); performSearch($input.val()); });
    $('#condition-filter, #celltype-filter, #direction-filter, #pval-filter, #fc-filter, #hide-pseudogenes').on('change input', function() {
        if (state.query) performSearch(state.query);
    });
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

    loadConditions();
    checkIndex(false);
});
</script>
<script src="JS/page-loading.js?v=<%= System.currentTimeMillis() %>"></script>
</body>
</html>
