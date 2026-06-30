/* ==========================================================================
   figure-export.js — publication-quality figure downloads for Plotly charts.

   Replaces Plotly's default low-res camera snapshot with two modebar buttons:
     • PNG (high-resolution)  — rendered at 4× device scale (~300+ DPI).
     • PDF                    — vector via svg2pdf (crisp text/axes), with an
                                automatic high-res raster fallback.

   Depends on lib/jspdf.umd.min.js + lib/svg2pdf.umd.min.js (vendored) and Plotly.
   Load this file AFTER those three and BEFORE the page's chart code.

   Usage at each Plotly call site:
       Plotly.newPlot(id, data, layout, FigureExport.config('my_figure_name', baseConfig));
   `name` may be a string or a function (evaluated at click time for dynamic names).
   ========================================================================== */
(function () {
    "use strict";

    var PNG_SCALE = 4;  // 4× the on-screen size -> ~300+ DPI for a typical figure.

    // Document-with-"PDF" modebar icon (24×24 grid, Plotly icon format).
    var PDF_ICON = {
        width: 24, height: 24,
        path: "M6 2h7l5 5v13a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1zm6.5 1.6V7H17l-4.5-4.4z" +
              "M7.4 13.2h1.3q.8 0 1.2.35.45.35.45 1 0 .65-.45 1-.4.35-1.2.35h-.4v1.5H7.4v-4.6z" +
              "m.9 2.2h.35q.35 0 .5-.13.18-.13.18-.4 0-.27-.16-.4-.15-.13-.5-.13H8.3v1.06z",
        transform: "matrix(1 0 0 1 0 0)"
    };

    function dims(gd) {
        var fl = (gd && gd._fullLayout) || {};
        return {
            w: Math.round(fl.width || (gd && gd.clientWidth) || 800),
            h: Math.round(fl.height || (gd && gd.clientHeight) || 600)
        };
    }
    function resolveName(name) {
        var n = (typeof name === "function") ? name() : name;
        return (n || "figure").toString().replace(/[^\w.\-]+/g, "_");
    }
    function jsPDFCtor() {
        return (window.jspdf && window.jspdf.jsPDF) || null;
    }

    /* ---- PNG: high-resolution raster ------------------------------------- */
    function downloadPng(gd, name) {
        var d = dims(gd);
        window.Plotly.downloadImage(gd, {
            format: "png", scale: PNG_SCALE, width: d.w, height: d.h,
            filename: resolveName(name)
        });
    }

    /* ---- PDF: vector (svg2pdf) with raster fallback ---------------------- */
    function downloadPdf(gd, name) {
        var d = dims(gd), filename = resolveName(name);
        var JsPDF = jsPDFCtor();
        if (!JsPDF || typeof JsPDF.API.svg !== "function") {
            return rasterPdf(gd, filename, d);   // libs missing -> raster
        }
        window.Plotly.toImage(gd, { format: "svg", width: d.w, height: d.h })
            .then(function (uri) {
                var svgText = decodeURIComponent(uri.replace(/^data:image\/svg\+xml,/, ""));
                var el = new DOMParser().parseFromString(svgText, "image/svg+xml").documentElement;
                var doc = new JsPDF({
                    orientation: d.w >= d.h ? "landscape" : "portrait",
                    unit: "pt", format: [d.w, d.h], compress: true
                });
                return doc.svg(el, { x: 0, y: 0, width: d.w, height: d.h })
                    .then(function () { doc.save(filename + ".pdf"); });
            })
            .catch(function (err) {
                if (window.console) { console.warn("Vector PDF failed; using raster.", err); }
                rasterPdf(gd, filename, d);
            });
    }

    function rasterPdf(gd, filename, d) {
        var JsPDF = jsPDFCtor();
        if (!JsPDF) { return; }
        window.Plotly.toImage(gd, { format: "png", width: d.w, height: d.h, scale: PNG_SCALE })
            .then(function (uri) {
                var doc = new JsPDF({
                    orientation: d.w >= d.h ? "landscape" : "portrait",
                    unit: "pt", format: [d.w, d.h], compress: true
                });
                doc.addImage(uri, "PNG", 0, 0, d.w, d.h, undefined, "FAST");
                doc.save(filename + ".pdf");
            });
    }

    /* ---- modebar buttons + config helper -------------------------------- */
    function buttons(name) {
        var camera = (window.Plotly && window.Plotly.Icons && window.Plotly.Icons.camera);
        return [
            {
                name: "downloadPngHi", title: "Download PNG (high-resolution)",
                icon: camera, click: function (gd) { downloadPng(gd, name); }
            },
            {
                name: "downloadPdf", title: "Download PDF (vector)",
                icon: PDF_ICON, click: function (gd) { downloadPdf(gd, name); }
            }
        ];
    }

    // Merge our download buttons into a base Plotly config, removing the
    // default low-res snapshot button.
    function config(name, base) {
        base = base || {};
        var out = {};
        for (var k in base) { if (base.hasOwnProperty(k)) { out[k] = base[k]; } }
        var rm = (base.modeBarButtonsToRemove || []).slice();
        if (rm.indexOf("toImage") < 0) { rm.push("toImage"); }
        out.displaylogo = false;
        out.modeBarButtonsToRemove = rm;
        out.modeBarButtonsToAdd = (base.modeBarButtonsToAdd || []).slice().concat(buttons(name));
        // toImageButtonOptions no longer applies (default button removed); drop it.
        delete out.toImageButtonOptions;
        return out;
    }

    window.FigureExport = {
        PNG_SCALE: PNG_SCALE,
        png: downloadPng,
        pdf: downloadPdf,
        buttons: buttons,
        config: config
    };
    // Convenience for call sites: figConfig(name, baseConfig) -> Plotly config
    // with the high-res PNG + PDF download buttons.
    window.figConfig = config;
})();
