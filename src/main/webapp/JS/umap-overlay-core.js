/* ==========================================================================
   umap-overlay-core.js — pure, DOM-free helpers for the gene-expression
   UMAP overlay (umap-explorer.jsp / umap-explorer.js).

   Everything here is side-effect free and synchronous so it can be unit
   tested in a plain browser page (tests/umap-overlay.test.html) with no npm /
   build step. The interactive page (umap-explorer.js) consumes these.

   Exposed as window.UMAPOverlayCore (and module.exports when available).
   ========================================================================== */
(function (root, factory) {
    "use strict";
    var api = factory();
    if (typeof module !== "undefined" && module.exports) {
        module.exports = api;
    }
    if (root) {
        root.UMAPOverlayCore = api;
    }
})(typeof self !== "undefined" ? self : this, function () {
    "use strict";

    /* --- Continuous expression colorscale (brand coral ramp, mirrors
       gene_viz_resources/gene_expression_viz.py). Stops are [pos, hex]. ----- */
    var COLORSCALE = [
        [0.0, "#f5f3f0"],
        [0.1, "#ffeaa7"],
        [0.3, "#fab1a0"],
        [0.5, "#e8927c"],
        [0.7, "#e17055"],
        [1.0, "#d63031"]
    ];

    var MISSING_COLOR = "#cccccc";  // cells with no expression value -> grey

    /* Qualitative palette for default (cell-type) coloring. */
    var CATEGORY_PALETTE = [
        "#1a2332", "#e8927c", "#d4a574", "#3cb44b", "#4363d8",
        "#f58231", "#911eb4", "#42d4f4", "#f032e6", "#469990",
        "#9A6324", "#800000", "#808000", "#000075", "#e6194b",
        "#46c2b6", "#bcbd22", "#17becf", "#8c564b", "#7f7f7f"
    ];

    /* ---- color math -------------------------------------------------------- */
    function hexToRgb(hex) {
        var h = hex.replace("#", "");
        return {
            r: parseInt(h.substring(0, 2), 16),
            g: parseInt(h.substring(2, 4), 16),
            b: parseInt(h.substring(4, 6), 16)
        };
    }
    function comp(n) {
        var s = Math.max(0, Math.min(255, Math.round(n))).toString(16);
        return s.length === 1 ? "0" + s : s;
    }
    function rgbToHex(c) { return "#" + comp(c.r) + comp(c.g) + comp(c.b); }

    /* Interpolate the COLORSCALE at position t in [0,1] -> hex. */
    function sampleColorscale(t) {
        if (t == null || isNaN(t)) { return MISSING_COLOR; }
        if (t <= 0) { return COLORSCALE[0][1]; }
        if (t >= 1) { return COLORSCALE[COLORSCALE.length - 1][1]; }
        for (var i = 0; i < COLORSCALE.length - 1; i++) {
            var lo = COLORSCALE[i], hi = COLORSCALE[i + 1];
            if (t >= lo[0] && t <= hi[0]) {
                var span = hi[0] - lo[0];
                var f = span === 0 ? 0 : (t - lo[0]) / span;
                var a = hexToRgb(lo[1]), b = hexToRgb(hi[1]);
                return rgbToHex({
                    r: a.r + (b.r - a.r) * f,
                    g: a.g + (b.g - a.g) * f,
                    b: a.b + (b.b - a.b) * f
                });
            }
        }
        return COLORSCALE[COLORSCALE.length - 1][1];
    }

    /* COLORSCALE in the [[pos,'rgb(...)'],...] form Plotly wants. */
    function plotlyColorscale() {
        return COLORSCALE.map(function (s) { return [s[0], s[1]]; });
    }

    /* ---- cell-id join ------------------------------------------------------ */
    /* Map cellId -> first row position. Duplicate IDs keep the first. */
    function buildCellIndex(cellIds) {
        var m = new Map();
        for (var i = 0; i < cellIds.length; i++) {
            if (!m.has(cellIds[i])) { m.set(cellIds[i], i); }
        }
        return m;
    }

    /* Align an expression Map(cellId -> value) onto an ordered cellIds list.
       A cell absent from the map yields null (rendered grey). */
    function joinExpression(cellIds, exprMap) {
        var out = new Array(cellIds.length);
        for (var i = 0; i < cellIds.length; i++) {
            var v = exprMap.has(cellIds[i]) ? exprMap.get(cellIds[i]) : null;
            out[i] = (v == null || isNaN(v)) ? null : v;
        }
        return out;
    }

    /* ---- stats / normalization -------------------------------------------- */
    /* min/max over finite values. allZero and constant flags drive safe
       rendering for degenerate genes. */
    function computeColorStats(values) {
        var min = Infinity, max = -Infinity, seen = 0;
        for (var i = 0; i < values.length; i++) {
            var v = values[i];
            if (v == null || isNaN(v)) { continue; }
            seen++;
            if (v < min) { min = v; }
            if (v > max) { max = v; }
        }
        if (seen === 0) { return { min: 0, max: 0, allZero: true, constant: true }; }
        return {
            min: min,
            max: max,
            allZero: (min === 0 && max === 0),
            constant: (min === max)
        };
    }

    /* Normalize a value to [0,1] given min/max. Returns null for missing.
       Degenerate (max<=min) maps everything to 0 (scale floor) — safe, no NaN. */
    function normalizeValue(v, min, max) {
        if (v == null || isNaN(v)) { return null; }
        if (max <= min) { return 0; }
        var t = (v - min) / (max - min);
        if (t < 0) { return 0; }
        if (t > 1) { return 1; }
        return t;
    }

    function valueToColor(v, min, max) {
        var t = normalizeValue(v, min, max);
        return t == null ? MISSING_COLOR : sampleColorscale(t);
    }

    /* Per-point colors for the whole expression vector (used only when the
       fast Plotly-colorscale path can't be used, e.g. some values missing). */
    function expressionColors(values, min, max) {
        var out = new Array(values.length);
        for (var i = 0; i < values.length; i++) {
            out[i] = valueToColor(values[i], min, max);
        }
        return out;
    }

    function hasMissing(values) {
        for (var i = 0; i < values.length; i++) {
            if (values[i] == null || isNaN(values[i])) { return true; }
        }
        return false;
    }

    /* ---- categorical (cell-type) coloring --------------------------------- */
    function categoryColor(i) {
        if (i < 0) { return MISSING_COLOR; }
        return CATEGORY_PALETTE[i % CATEGORY_PALETTE.length];
    }
    /* hex per point from integer category codes (-1 -> grey). */
    function categoricalColors(codes) {
        var out = new Array(codes.length);
        for (var i = 0; i < codes.length; i++) { out[i] = categoryColor(codes[i]); }
        return out;
    }
    /* [{label,color}] legend entries for a category list. */
    function categoricalLegend(categories) {
        return categories.map(function (label, i) {
            return { label: label, color: categoryColor(i) };
        });
    }

    /* ---- gene search / autocomplete --------------------------------------- */
    /* Case-insensitive suggestions: prefix matches first, then substring. */
    function filterGenes(query, geneList, limit) {
        limit = limit || 10;
        var q = (query || "").trim().toLowerCase();
        if (!q) { return []; }
        var prefix = [], contains = [];
        for (var i = 0; i < geneList.length; i++) {
            var g = geneList[i], lg = g.toLowerCase();
            if (lg === q) { prefix.unshift(g); continue; }
            if (lg.indexOf(q) === 0) { prefix.push(g); }
            else if (lg.indexOf(q) > 0) { contains.push(g); }
            if (prefix.length >= limit) { break; }
        }
        return prefix.concat(contains).slice(0, limit);
    }

    /* Exact case-insensitive match -> canonical symbol, or null. */
    function matchGene(query, geneList) {
        var q = (query || "").trim().toLowerCase();
        if (!q) { return null; }
        for (var i = 0; i < geneList.length; i++) {
            if (geneList[i].toLowerCase() === q) { return geneList[i]; }
        }
        return null;
    }

    return {
        COLORSCALE: COLORSCALE,
        MISSING_COLOR: MISSING_COLOR,
        CATEGORY_PALETTE: CATEGORY_PALETTE,
        hexToRgb: hexToRgb,
        rgbToHex: rgbToHex,
        sampleColorscale: sampleColorscale,
        plotlyColorscale: plotlyColorscale,
        buildCellIndex: buildCellIndex,
        joinExpression: joinExpression,
        computeColorStats: computeColorStats,
        normalizeValue: normalizeValue,
        valueToColor: valueToColor,
        expressionColors: expressionColors,
        hasMissing: hasMissing,
        categoryColor: categoryColor,
        categoricalColors: categoricalColors,
        categoricalLegend: categoricalLegend,
        filterGenes: filterGenes,
        matchGene: matchGene
    };
});
