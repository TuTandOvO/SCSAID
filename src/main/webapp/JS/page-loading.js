/* Site-wide loading feedback: one centered circular indicator. */
(function () {
    "use strict";
    if (window.__pageLoadingInit) return;
    window.__pageLoadingInit = true;

    var css =
        ".gload{position:fixed;inset:var(--header-height,72px) 0 0;z-index:1200;" +
        "display:grid;place-items:center;pointer-events:none;visibility:hidden;opacity:0;" +
        "transition:opacity 150ms ease,visibility 150ms ease;}" +
        ".gload.is-active{visibility:visible;opacity:1;}" +
        ".gload__circle{display:block;width:44px;height:44px;border:3px solid rgba(232,146,124,.2);" +
        "border-top-color:var(--color-secondary,#e8927c);border-radius:50%;" +
        "animation:scsaidGlobalLoaderSpin 800ms linear infinite;}" +
        "@keyframes scsaidGlobalLoaderSpin{to{transform:rotate(360deg);}}" +
        "@media (prefers-reduced-motion:reduce){.gload__circle{animation:none;}}";
    var style = document.createElement("style");
    style.textContent = css;
    (document.head || document.documentElement).appendChild(style);

    var loader = null;
    var timer = null;
    var visible = false;

    function ensureLoader() {
        if (loader) return;
        loader = document.createElement("div");
        loader.className = "gload";
        loader.setAttribute("role", "status");
        loader.setAttribute("aria-label", "Loading");
        loader.innerHTML = '<span class="gload__circle" aria-hidden="true"></span>';
        (document.body || document.documentElement).appendChild(loader);
    }

    function hasVisiblePanelLoader() {
        var candidates = document.querySelectorAll(
            ".panel-loader, .site-search__status.is-loading, " +
            ".umap-overlay-state:not([hidden]), .viz-panel__loading:not(.is-hidden), " +
            ".status-banner.is-loading"
        );
        return Array.prototype.some.call(candidates, function (element) {
            var style = window.getComputedStyle(element);
            return style.display !== "none" && style.visibility !== "hidden" && element.getClientRects().length > 0;
        });
    }

    function showNow() {
        if (timer) {
            clearTimeout(timer);
            timer = null;
        }
        ensureLoader();
        visible = true;
        loader.classList.add("is-active");
    }

    function showDelayed() {
        if (visible || timer || hasVisiblePanelLoader()) return;
        timer = setTimeout(function () {
            timer = null;
            if (!hasVisiblePanelLoader()) showNow();
        }, 200);
    }

    function done() {
        if (timer) {
            clearTimeout(timer);
            timer = null;
        }
        if (loader && visible) {
            visible = false;
            loader.classList.remove("is-active");
        }
    }

    window.PageLoading = { start: showNow, startDelayed: showDelayed, done: done };

    window.addEventListener("beforeunload", showNow);
    window.addEventListener("pageshow", done);

    function bindJq() {
        if (!window.jQuery) return false;
        window.jQuery(document).on("ajaxStart", showDelayed).on("ajaxStop", done);
        return true;
    }

    if (!bindJq()) {
        document.addEventListener("DOMContentLoaded", bindJq);
        window.addEventListener("load", bindJq);
    }
})();
