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

    // Four-corners "expand to full screen" modebar icon.
    var EXPAND_ICON = {
        width: 24, height: 24,
        path: "M4 4h6V2H2v8h2V4zm16 0v6h2V2h-8v2h6zM4 20v-6H2v8h8v-2H4zm16 0h-6v2h8v-8h-2v6z"
    };

    // Inject modal styles once.
    (function injectStyles() {
        if (typeof document === "undefined" || document.getElementById("fig-export-style")) { return; }
        var st = document.createElement("style");
        st.id = "fig-export-style";
        st.textContent =
            ".fig-modal{position:fixed;inset:0;z-index:100000;display:flex;align-items:center;justify-content:center;background:rgba(26,35,50,.55);padding:2.5vh 2.5vw;}" +
            ".fig-modal__panel{background:#fff;border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,.35);width:95vw;height:95vh;display:flex;flex-direction:column;overflow:hidden;}" +
            ".fig-modal__bar{display:flex;align-items:center;justify-content:space-between;padding:10px 16px;border-bottom:1px solid #e5e0d8;flex:none;}" +
            ".fig-modal__title{font-family:Montserrat,sans-serif;font-size:.85rem;font-weight:600;letter-spacing:.04em;color:#1a2332;text-transform:capitalize;}" +
            ".fig-modal__close{appearance:none;-webkit-appearance:none;border:none;background:transparent;font-size:1.7rem;line-height:1;color:#5a6473;cursor:pointer;padding:0 8px;border-radius:6px;}" +
            ".fig-modal__close:hover{background:#f0ede8;color:#1a2332;}" +
            ".fig-modal__body{flex:1;min-height:0;padding:8px;}" +
            ".fig-modal__plot{width:100%;height:100%;}";
        (document.head || document.documentElement).appendChild(st);
    })();

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

    /* ---- full-screen modal ---------------------------------------------- */
    // Re-render the figure large (95% of the viewport, autosized — no fixed
    // height) so dense legends/axes (many cell types) aren't squashed. The big
    // view keeps its own download buttons.
    function expand(gd, name) {
        if (!gd || !window.Plotly) { return; }
        var Plotly = window.Plotly;

        var ov = document.createElement("div"); ov.className = "fig-modal";
        var panel = document.createElement("div"); panel.className = "fig-modal__panel";
        var bar = document.createElement("div"); bar.className = "fig-modal__bar";
        var title = document.createElement("span"); title.className = "fig-modal__title";
        title.textContent = resolveName(name).replace(/[_]+/g, " ");
        var close = document.createElement("button"); close.className = "fig-modal__close";
        close.setAttribute("aria-label", "Close full-screen view"); close.innerHTML = "&times;";
        var body = document.createElement("div"); body.className = "fig-modal__body";
        var plot = document.createElement("div"); plot.className = "fig-modal__plot";
        bar.appendChild(title); bar.appendChild(close);
        body.appendChild(plot); panel.appendChild(bar); panel.appendChild(body);
        ov.appendChild(panel); document.body.appendChild(ov);
        document.body.style.overflow = "hidden";

        var onResize = function () { try { Plotly.Plots.resize(plot); } catch (e) {} };
        function destroy() {
            document.removeEventListener("keydown", onKey);
            window.removeEventListener("resize", onResize);
            try { Plotly.purge(plot); } catch (e) {}
            if (ov.parentNode) { ov.parentNode.removeChild(ov); }
            document.body.style.overflow = "";
        }
        function onKey(e) { if (e.key === "Escape") { destroy(); } }
        close.addEventListener("click", destroy);
        ov.addEventListener("mousedown", function (e) { if (e.target === ov) { destroy(); } });
        document.addEventListener("keydown", onKey);
        window.addEventListener("resize", onResize);

        // Shallow-clone traces (so Plotly's per-plot uid doesn't touch the
        // original) but share the heavy data arrays by reference.
        var data = (gd.data || []).map(function (t) {
            var c = {}; for (var k in t) { if (t.hasOwnProperty(k)) { c[k] = t[k]; } } return c;
        });
        var layout = {}; var src = gd.layout || {};
        for (var k in src) { if (src.hasOwnProperty(k)) { layout[k] = src[k]; } }
        delete layout.width; delete layout.height; layout.autosize = true;

        Plotly.newPlot(plot, data, layout,
            config(name, { responsive: true, displaylogo: false }, { expand: false })
        ).then(onResize);
    }

    /* ---- modebar buttons + config helper -------------------------------- */
    function buttons(name, opts) {
        opts = opts || {};
        var camera = (window.Plotly && window.Plotly.Icons && window.Plotly.Icons.camera);
        var arr = [
            {
                name: "downloadPngHi", title: "Download PNG (high-resolution)",
                icon: camera, click: function (gd) { downloadPng(gd, name); }
            },
            {
                name: "downloadPdf", title: "Download PDF (vector)",
                icon: PDF_ICON, click: function (gd) { downloadPdf(gd, name); }
            }
        ];
        if (opts.expand !== false) {
            arr.unshift({
                name: "expandFig", title: "View full screen",
                icon: EXPAND_ICON, click: function (gd) { expand(gd, name); }
            });
        }
        return arr;
    }

    // Merge our download buttons into a base Plotly config, removing the
    // default low-res snapshot button.
    function config(name, base, opts) {
        base = base || {};
        var out = {};
        for (var k in base) { if (base.hasOwnProperty(k)) { out[k] = base[k]; } }
        var rm = (base.modeBarButtonsToRemove || []).slice();
        if (rm.indexOf("toImage") < 0) { rm.push("toImage"); }
        out.displaylogo = false;
        out.modeBarButtonsToRemove = rm;
        out.modeBarButtonsToAdd = (base.modeBarButtonsToAdd || []).slice().concat(buttons(name, opts));
        // toImageButtonOptions no longer applies (default button removed); drop it.
        delete out.toImageButtonOptions;
        return out;
    }

    window.FigureExport = {
        PNG_SCALE: PNG_SCALE,
        png: downloadPng,
        pdf: downloadPdf,
        expand: expand,
        buttons: buttons,
        config: config
    };
    // Convenience for call sites: figConfig(name, baseConfig) -> Plotly config
    // with the high-res PNG + PDF download buttons.
    window.figConfig = config;
})();
