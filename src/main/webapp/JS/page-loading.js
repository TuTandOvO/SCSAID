/* ==========================================================================
   page-loading.js — site-wide loading feedback.

   One self-contained, dependency-free file (injects its own CSS + DOM) that
   gives users a visible "working…" cue in the three situations a reviewer
   flagged:

     1. Clicking through to another page  -> a top progress bar appears as the
        current page navigates away (driven by `beforeunload`, so it never
        false-fires on in-page anchors or return-false forms).
     2. Changing an argument / running a function -> any jQuery AJAX request
        (the site's async transport everywhere) shows the same bar, hooked once
        via the global ajaxStart/ajaxStop events — no per-call-site wiring.
     3. Anything else -> window.PageLoading.start()/done() for manual use
        (e.g. fetch()-based code).

   The AJAX bar waits 200ms before showing, so fast status-polls and quick
   fetches never flicker — only genuinely slow work paints the bar. Pages that
   already have their own in-panel spinners keep them; this is a global
   complement, not a replacement.
   ========================================================================== */
(function () {
    "use strict";
    if (window.__pageLoadingInit) { return; }
    window.__pageLoadingInit = true;

    /* ---- injected styles (brand coral -> bronze indeterminate shimmer) ---- */
    var css =
        ".gload{position:fixed;top:0;left:0;right:0;height:3px;z-index:99999;" +
        "pointer-events:none;opacity:0;transition:opacity .25s ease;}" +
        ".gload.is-active{opacity:1;}" +
        ".gload__fill{position:absolute;top:0;left:0;height:100%;width:100%;" +
        "background:linear-gradient(90deg,rgba(232,146,124,0) 0%,#e8927c 40%,#d4a574 60%,rgba(212,165,116,0) 100%);" +
        "transform:translateX(-100%);}" +
        ".gload.is-active .gload__fill{animation:gloadSlide 1.1s ease-in-out infinite;}" +
        "@keyframes gloadSlide{0%{transform:translateX(-100%);}100%{transform:translateX(100%);}}" +
        "@media (prefers-reduced-motion:reduce){.gload.is-active .gload__fill{" +
        "animation:none;transform:translateX(0);opacity:.85;}}";
    var style = document.createElement("style");
    style.textContent = css;
    (document.head || document.documentElement).appendChild(style);

    /* ---- bar element + show/hide state machine --------------------------- */
    var bar = null, timer = null, visible = false;

    function ensureBar() {
        if (bar) { return; }
        bar = document.createElement("div");
        bar.className = "gload";
        bar.setAttribute("aria-hidden", "true");
        var fill = document.createElement("div");
        fill.className = "gload__fill";
        bar.appendChild(fill);
        (document.body || document.documentElement).appendChild(bar);
    }
    function showNow() {
        if (timer) { clearTimeout(timer); timer = null; }
        ensureBar();
        visible = true;
        bar.classList.add("is-active");
    }
    function showDelayed() {
        if (visible || timer) { return; }
        timer = setTimeout(function () { timer = null; showNow(); }, 200);
    }
    function done() {
        if (timer) { clearTimeout(timer); timer = null; }
        if (bar && visible) {
            visible = false;
            bar.classList.remove("is-active");
        }
    }

    window.PageLoading = { start: showNow, startDelayed: showDelayed, done: done };

    /* ---- 1 & part of 3: page navigation --------------------------------- */
    // beforeunload only fires on a real navigation (link, form GET/POST,
    // location change), so this is false-positive-free.
    window.addEventListener("beforeunload", showNow);
    // Restore from bfcache (back/forward) -> clear any stale bar.
    window.addEventListener("pageshow", function () {
        if (bar) { bar.classList.remove("is-active"); }
        visible = false;
        if (timer) { clearTimeout(timer); timer = null; }
    });

    /* ---- 2: global jQuery AJAX ------------------------------------------ */
    function bindJq() {
        if (!window.jQuery) { return false; }
        window.jQuery(document)
            .on("ajaxStart", showDelayed)
            .on("ajaxStop", done);
        return true;
    }
    if (!bindJq()) {
        // jQuery may be parsed after this script — try again once the DOM/page is ready.
        document.addEventListener("DOMContentLoaded", bindJq);
        window.addEventListener("load", bindJq);
    }
})();
