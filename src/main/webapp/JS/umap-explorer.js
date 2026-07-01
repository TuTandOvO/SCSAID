/* ==========================================================================
   umap-explorer.js — client-side gene-expression overlay on the integrated
   UMAP (CZ CELLxGENE-style FeaturePlot). Mirrors the IIFE + single-state
   pattern of JS/compare.js.

   Data flow:
     /integrated_umap/api/genes?species=     -> autocomplete gene list
     /integrated_umap/api/umap-base?species= -> coords + cell IDs + metadata (once/species)
     /integrated_umap/api/expression?...&gene -> per-gene expression vector (cached)

   Default coloring is categorical (cell type). Selecting a gene recolors the
   single Plotly scattergl trace via restyle (no full re-render); clearing
   restores the categorical coloring. Depends on JS/umap-overlay-core.js.
   ========================================================================== */
(function () {
    "use strict";

    var Core = window.UMAPOverlayCore;
    var API = "/integrated_umap/api";
    var PLOT_ID = "umapPlot";

    var state = {
        species: "human",
        base: { human: null, mouse: null },      // {x,y,cellIds,index(Map),customdata,legend,categories}
        genes: { human: null, mouse: null },     // gene-symbol arrays
        exprCache: {},                            // "species|GENE" -> {gene,values,min,max,stats}
        currentGene: null,
        pendingGene: null,
        suggestIdx: -1,
        plotInited: false
    };

    var $input, $suggest, $clearBtn, $geneStatus, $legend, $loading, $error;

    /* ---- tiny DOM helpers -------------------------------------------------- */
    function el(id) { return document.getElementById(id); }
    function show(node) { if (node) { node.hidden = false; } }
    function hide(node) { if (node) { node.hidden = true; } }
    function esc(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
            return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
        });
    }
    function debounce(fn, ms) {
        var t;
        return function () {
            var ctx = this, args = arguments;
            clearTimeout(t);
            t = setTimeout(function () { fn.apply(ctx, args); }, ms);
        };
    }

    /* ====================================================================== */
    /*  Base atlas load                                                        */
    /* ====================================================================== */
    function loadSpecies(sp) {
        state.species = sp;
        clearGene(true);
        hideSuggest();
        if (state.base[sp]) {
            renderCategorical(state.base[sp]);
            maybeSelectPending();
            return;
        }
        show($loading);
        hide($error);
        $.when(
            $.getJSON(API + "/genes?species=" + sp),
            $.getJSON(API + "/umap-base?species=" + sp)
        ).done(function (genesRes, baseRes) {
            state.genes[sp] = genesRes[0].genes || [];
            var raw = baseRes[0];
            state.base[sp] = buildBase(raw);
            hide($loading);
            renderCategorical(state.base[sp]);
            maybeSelectPending();
        }).fail(function () {
            hide($loading);
            showError("Could not load the " + sp + " atlas. Please retry in a moment.");
        });
    }

    function maybeSelectPending() {
        if (state.pendingGene) {
            var g = state.pendingGene;
            state.pendingGene = null;
            selectGene(g);
        }
    }

    /* Programmatically reflect the species in the toggle (no change event). */
    function setSpeciesRadio(sp) {
        state.species = sp;
        var radios = document.querySelectorAll('input[name="umap-species"]');
        for (var i = 0; i < radios.length; i++) { radios[i].checked = (radios[i].value === sp); }
    }

    /* Deep-link entry (?gene=): pick whichever species' panel has the gene,
       set the toggle, then load that atlas and select the gene. */
    function initDeepLink(gene) {
        show($loading);
        hide($error);
        $.when(
            $.getJSON(API + "/genes?species=human"),
            $.getJSON(API + "/genes?species=mouse")
        ).done(function (h, m) {
            state.genes.human = h[0].genes || [];
            state.genes.mouse = m[0].genes || [];
            var sp = Core.matchGene(gene, state.genes.human) ? "human"
                : Core.matchGene(gene, state.genes.mouse) ? "mouse" : "human";
            setSpeciesRadio(sp);
            $input.value = gene;
            state.pendingGene = gene;
            loadSpecies(sp);
        }).fail(function () { loadSpecies("human"); });
    }

    /* Pre-decode categorical codes into per-point label strings + customdata. */
    function buildBase(raw) {
        var n = raw.n;
        var ct = raw.meta.cell_type, cl = raw.meta.cluster, sm = raw.meta.sample;
        var customdata = new Array(n);
        for (var i = 0; i < n; i++) {
            customdata[i] = [
                raw.cell_ids[i],
                labelOf(ct, i),
                labelOf(cl, i),
                labelOf(sm, i)
            ];
        }
        return {
            x: raw.x,
            y: raw.y,
            cellIds: raw.cell_ids,
            index: Core.buildCellIndex(raw.cell_ids),
            customdata: customdata,
            categories: ct.categories,
            catColors: Core.categoricalColors(ct.codes),
            legend: Core.categoricalLegend(ct.categories)
        };
    }
    function labelOf(block, i) {
        var c = block.codes[i];
        return (c != null && c >= 0 && c < block.categories.length)
            ? block.categories[c] : "—";
    }

    /* ====================================================================== */
    /*  Plot rendering                                                         */
    /* ====================================================================== */
    var BASE_LAYOUT = {
        margin: { l: 8, r: 8, t: 8, b: 8 },
        hovermode: "closest",
        plot_bgcolor: "#ffffff",
        paper_bgcolor: "#ffffff",
        dragmode: "pan",
        showlegend: false,
        xaxis: { visible: false, zeroline: false, showgrid: false, showticklabels: false },
        yaxis: {
            visible: false, zeroline: false, showgrid: false, showticklabels: false,
            scaleanchor: "x", scaleratio: 1
        },
        font: { family: "Montserrat, sans-serif", size: 12, color: "#1a2332" }
    };
    var PLOT_CONFIG_BASE = {
        responsive: true, displaylogo: false,
        modeBarButtonsToRemove: ["lasso2d", "select2d", "autoScale2d"]
    };
    // High-res PNG / vector PDF download buttons (figure-export.js), with a
    // filename that reflects the current species + gene at click time.
    function plotConfig() {
        var name = function () {
            return "featureplot_" + state.species + (state.currentGene ? "_" + state.currentGene : "");
        };
        return window.FigureExport ? window.FigureExport.config(name, PLOT_CONFIG_BASE)
                                   : PLOT_CONFIG_BASE;
    }

    var CAT_HOVER =
        "Cell ID: %{customdata[0]}<br>" +
        "UMAP: (%{x:.2f}, %{y:.2f})<br>" +
        "Cell type: %{customdata[1]}<br>" +
        "Cluster: %{customdata[2]}<br>" +
        "Sample: %{customdata[3]}<extra></extra>";

    function geneHover(gene) {
        return "Cell ID: %{customdata[0]}<br>" +
            "UMAP: (%{x:.2f}, %{y:.2f})<br>" +
            "<b>" + esc(gene) + ": %{marker.color:.3f}</b><br>" +
            "Cell type: %{customdata[1]}<br>" +
            "Cluster: %{customdata[2]}<br>" +
            "Sample: %{customdata[3]}<extra></extra>";
    }

    function renderCategorical(base) {
        var trace = {
            type: "scattergl",
            mode: "markers",
            x: base.x,
            y: base.y,
            customdata: base.customdata,
            hovertemplate: CAT_HOVER,
            marker: { size: 3.5, opacity: 0.7, color: base.catColors, line: { width: 0 } }
        };
        Plotly.react(PLOT_ID, [trace], BASE_LAYOUT, plotConfig());
        state.plotInited = true;
        renderLegendCategorical(base.legend);
    }

    function recolorByGene(gene, values, stats) {
        var base = state.base[state.species];
        var update;
        if (Core.hasMissing(values)) {
            // Slow path: some cells lack a value -> explicit per-point colors (grey for missing)
            update = { "marker.color": [Core.expressionColors(values, stats.min, stats.max)],
                       "hovertemplate": [CAT_HOVER] };
        } else {
            update = {
                "marker.color": [values],
                "marker.colorscale": [Core.plotlyColorscale()],
                "marker.cmin": [stats.min],
                "marker.cmax": [stats.max],
                "marker.showscale": [false],
                "hovertemplate": [geneHover(gene)]
            };
        }
        Plotly.restyle(PLOT_ID, update, [0]);
        renderLegendGene(gene, stats);
    }

    function restoreCategorical() {
        var base = state.base[state.species];
        Plotly.restyle(PLOT_ID, {
            "marker.color": [base.catColors],
            "hovertemplate": [CAT_HOVER]
        }, [0]);
        renderLegendCategorical(base.legend);
    }

    /* ====================================================================== */
    /*  Legend                                                                 */
    /* ====================================================================== */
    function renderLegendCategorical(entries) {
        var html = '<div class="umap-legend__title">Cell type</div><ul class="umap-legend__list">';
        entries.forEach(function (e) {
            html += '<li class="umap-legend__item">' +
                '<span class="umap-legend__swatch" style="background:' + e.color + '"></span>' +
                '<span class="umap-legend__label">' + esc(e.label) + '</span></li>';
        });
        html += "</ul>";
        $legend.innerHTML = html;
    }

    function gradientCss() {
        return "linear-gradient(to right," + Core.COLORSCALE.map(function (s) {
            return s[1] + " " + (s[0] * 100) + "%";
        }).join(",") + ")";
    }

    function renderLegendGene(gene, stats) {
        var note = "";
        if (stats.allZero) { note = '<div class="umap-legend__note">No expression detected in view</div>'; }
        else if (stats.constant) { note = '<div class="umap-legend__note">Uniform expression</div>'; }
        var html =
            '<div class="umap-legend__title">' + esc(gene) + '</div>' +
            '<div class="umap-legend__sub">Expression</div>' +
            '<div class="umap-legend__bar" style="background:' + gradientCss() + '"></div>' +
            '<div class="umap-legend__scale">' +
            '<span>' + stats.min.toFixed(2) + '</span>' +
            '<span>' + stats.max.toFixed(2) + '</span></div>' + note;
        $legend.innerHTML = html;
    }

    /* ====================================================================== */
    /*  Gene selection                                                         */
    /* ====================================================================== */
    function selectGene(raw) {
        var sp = state.species;
        var genes = state.genes[sp] || [];
        var canonical = Core.matchGene(raw, genes);
        if (!canonical) {
            showGeneStatus('Gene "' + esc((raw || "").trim()) +
                '" was not found in the ' + sp + " panel (highly-variable genes only).", "warn");
            return;
        }
        hideGeneStatus();
        hideSuggest();
        $input.value = canonical;
        var key = sp + "|" + canonical;
        if (state.exprCache[key]) {
            applyExpression(state.exprCache[key]);
            return;
        }
        setLoadingGene(true);
        $.ajax({
            url: API + "/expression",
            data: { species: sp, gene: canonical },
            dataType: "json"
        }).done(function (res) {
            var base = state.base[sp];
            // Build the cell-id -> value Map, then join positionally by cell ID.
            var exprMap = new Map();
            for (var i = 0; i < base.cellIds.length; i++) {
                exprMap.set(base.cellIds[i], res.values[i]);
            }
            var values = Core.joinExpression(base.cellIds, exprMap);
            var stats = Core.computeColorStats(values);
            var entry = { gene: res.gene, values: values, stats: stats };
            state.exprCache[key] = entry;
            setLoadingGene(false);
            applyExpression(entry);
        }).fail(function (xhr) {
            setLoadingGene(false);
            if (xhr.status === 404) {
                showGeneStatus('Gene "' + esc(canonical) + '" is not in the ' + sp + " panel.", "warn");
            } else {
                showGeneStatus("Could not load expression for " + esc(canonical) + ". Please retry.", "error");
            }
        });
    }

    function applyExpression(entry) {
        state.currentGene = entry.gene;
        recolorByGene(entry.gene, entry.values, entry.stats);
        $clearBtn.disabled = false;
    }

    function clearGene(silent) {
        state.currentGene = null;
        $clearBtn.disabled = true;
        hideGeneStatus();
        if (!silent) { $input.value = ""; }
        if (state.plotInited && state.base[state.species]) { restoreCategorical(); }
    }

    /* ====================================================================== */
    /*  Autocomplete                                                           */
    /* ====================================================================== */
    function onType() {
        var genes = state.genes[state.species] || [];
        var matches = Core.filterGenes($input.value, genes, 10);
        state.suggestIdx = -1;
        if (!matches.length) { hideSuggest(); return; }
        $suggest.innerHTML = matches.map(function (g, i) {
            return '<li class="gene-suggest__item" role="option" data-gene="' + esc(g) +
                '" data-i="' + i + '">' + esc(g) + "</li>";
        }).join("");
        show($suggest);
    }
    function hideSuggest() { hide($suggest); state.suggestIdx = -1; }
    function suggestItems() { return $suggest.querySelectorAll(".gene-suggest__item"); }
    function highlight(i) {
        var items = suggestItems();
        for (var k = 0; k < items.length; k++) {
            items[k].classList.toggle("is-active", k === i);
        }
        state.suggestIdx = i;
    }
    function onKeyDown(e) {
        var items = suggestItems();
        var open = !$suggest.hidden && items.length;
        if (e.key === "ArrowDown" && open) {
            e.preventDefault(); highlight(Math.min(state.suggestIdx + 1, items.length - 1));
        } else if (e.key === "ArrowUp" && open) {
            e.preventDefault(); highlight(Math.max(state.suggestIdx - 1, 0));
        } else if (e.key === "Enter") {
            e.preventDefault();
            if (open && state.suggestIdx >= 0) {
                selectGene(items[state.suggestIdx].getAttribute("data-gene"));
            } else {
                selectGene($input.value);
            }
        } else if (e.key === "Escape") {
            hideSuggest();
        }
    }

    /* ====================================================================== */
    /*  Status / loading UI                                                    */
    /* ====================================================================== */
    function showGeneStatus(msg, kind) {
        $geneStatus.className = "umap-gene-status umap-gene-status--" + (kind || "warn");
        $geneStatus.innerHTML = msg;
        show($geneStatus);
    }
    function hideGeneStatus() { hide($geneStatus); }
    function setLoadingGene(on) {
        if (on) {
            $input.classList.add("is-loading");
            hideGeneStatus();
            show($loading);
        } else {
            $input.classList.remove("is-loading");
            hide($loading);
            hideGeneStatus();
        }
    }
    function showError(msg) {
        $error.innerHTML = esc(msg);
        show($error);
    }

    /* ====================================================================== */
    /*  Wiring                                                                 */
    /* ====================================================================== */
    function init() {
        $input = el("geneInput");
        $suggest = el("geneSuggest");
        $clearBtn = el("clearGeneBtn");
        $geneStatus = el("geneStatus");
        $legend = el("umapLegend");
        $loading = el("umapLoading");
        $error = el("umapError");

        // Species toggle
        var radios = document.querySelectorAll('input[name="umap-species"]');
        for (var i = 0; i < radios.length; i++) {
            radios[i].addEventListener("change", function () {
                if (this.checked) {
                    $input.value = "";
                    loadSpecies(this.value);
                }
            });
        }

        $input.addEventListener("input", debounce(onType, 200));
        $input.addEventListener("keydown", onKeyDown);
        $input.addEventListener("focus", function () { if ($input.value) { onType(); } });

        $suggest.addEventListener("mousedown", function (e) {
            var li = e.target.closest(".gene-suggest__item");
            if (li) { e.preventDefault(); selectGene(li.getAttribute("data-gene")); }
        });

        $clearBtn.addEventListener("click", function () { clearGene(false); });

        document.addEventListener("click", function (e) {
            if (!e.target.closest(".gene-search")) { hideSuggest(); }
        });

        window.addEventListener("resize", debounce(function () {
            if (state.plotInited) { Plotly.Plots.resize(PLOT_ID); }
        }, 150));

        var initialGene = (document.body.getAttribute("data-initial-gene") || "").trim();
        if (initialGene) { initDeepLink(initialGene); }
        else { loadSpecies("human"); }
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }
})();
