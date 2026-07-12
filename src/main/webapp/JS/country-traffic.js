(function () {
    "use strict";
    var POLL_MS = 30000;

    function number(value) { return new Intl.NumberFormat().format(value || 0); }
    function escapeHtml(value) {
        return String(value == null ? "" : value).replace(/[&<>'"]/g, function (character) {
            return { "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[character];
        });
    }
    function renderRows(id, rows) {
        var target = document.getElementById(id);
        if (!rows || !rows.length) {
            target.innerHTML = '<tr><td colspan="3">No country aggregates have been collected yet.</td></tr>';
            return;
        }
        target.innerHTML = rows.map(function (row) {
            return "<tr><td>" + escapeHtml(row.label) + "</td><td><code>" +
                escapeHtml(row.country) + "</code></td><td>" + number(row.visits) + "</td></tr>";
        }).join("");
    }
    function render(payload) {
        document.getElementById("allTimeTotal").textContent = number(payload.allTimeTotal);
        document.getElementById("recentTotal").textContent = number(payload.recent30DaysTotal);
        document.getElementById("recentRange").textContent = payload.recentStart + " to " + payload.recentEnd;
        renderRows("recentRows", payload.recent30Days);
        renderRows("allTimeRows", payload.allTime);
        document.getElementById("analyticsStatus").textContent = payload.privacy + " Updated " +
            new Date().toLocaleTimeString() + ".";
    }
    function refresh() {
        fetch("/country-traffic-stats?_=" + Date.now(), { credentials: "same-origin", cache: "no-store" })
            .then(function (response) {
                if (!response.ok) throw new Error("Unable to load country analytics.");
                return response.json();
            })
            .then(render)
            .catch(function () {
                document.getElementById("analyticsStatus").textContent = "Country analytics are temporarily unavailable.";
            });
    }
    refresh();
    window.setInterval(refresh, POLL_MS);
}());
