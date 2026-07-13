/* Protected developer analytics dashboard. No third-party tracking or map tiles. */
(function () {
    "use strict";
    var POLL_MS = 30000;
    var latest = null;
    var mapScope = "all";
    var NS = "http://www.w3.org/2000/svg";
    /* Approximate country-centroid coordinates, used only for country-level map placement. */
    var countryCoordinates = {
        US:[39,-98], CA:[56,-106], MX:[23,-102], BR:[-10,-55], AR:[-34,-64], CL:[-35,-71], CO:[4,-72], PE:[-10,-76],
        GB:[54,-2], IE:[53,-8], FR:[46,2], DE:[51,10], ES:[40,-4], PT:[39,-8], IT:[42,12], NL:[52,5], BE:[50,4], CH:[47,8], AT:[47,14],
        DK:[56,10], NO:[62,10], SE:[62,15], FI:[64,26], IS:[65,-19], PL:[52,20], CZ:[50,15], HU:[47,19], RO:[46,25], GR:[39,22], TR:[39,35],
        UA:[49,32], RU:[61,105], EE:[59,26], LV:[57,25], LT:[56,24], RS:[44,21], HR:[45,16], BG:[43,25], SK:[49,20], SI:[46,15],
        MA:[32,-6], DZ:[28,2], TN:[34,9], EG:[27,30], ZA:[-30,25], NG:[9,8], KE:[1,38], ET:[9,40], GH:[8,-2], TZ:[-6,35], UG:[1,32],
        SA:[24,45], AE:[24,54], IL:[31,35], IR:[32,53], IQ:[33,44], JO:[31,36], PK:[30,70], IN:[22,79], BD:[24,90], LK:[7,81], NP:[28,84],
        CN:[35,104], JP:[36,138], KR:[36,128], TW:[24,121], HK:[22,114], SG:[1,104], MY:[4,102], TH:[15,101], VN:[16,108], ID:[-2,118], PH:[12,122],
        AU:[-25,134], NZ:[-41,174], FJ:[-17,178]
    };

    function number(value, digits) {
        return Number(value || 0).toLocaleString(undefined, { maximumFractionDigits: digits == null ? 0 : digits });
    }
    function escapeHtml(value) {
        return String(value == null ? "" : value).replace(/[&<>'"]/g, function (character) {
            return { "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[character];
        });
    }
    function formatTime(value) {
        if (!value) return "—";
        var date = new Date(value);
        return isNaN(date.getTime()) ? "—" : date.toISOString().replace("T", " ").replace(".000Z", "Z");
    }
    function isRecent(event) {
        return new Date(event.timestamp).getTime() >= Date.now() - 30 * 24 * 60 * 60 * 1000;
    }
    function renderRows(id, rows) {
        var target = document.getElementById(id);
        target.innerHTML = rows && rows.length ? rows.map(function (row) {
            return "<tr><td>" + escapeHtml(row.label) + "</td><td><code>" + escapeHtml(row.country) +
                "</code></td><td>" + number(row.visits) + "</td></tr>";
        }).join("") : '<tr><td colspan="3">No country aggregates have been collected yet.</td></tr>';
    }
    function renderPages(id, rows) {
        document.getElementById(id).innerHTML = rows && rows.length ? rows.map(function (row) {
            return "<tr><td><code>" + escapeHtml(row.path) + "</code></td><td>" + number(row.visits) + "</td></tr>";
        }).join("") : '<tr><td colspan="2">No counted page visits have been recorded yet.</td></tr>';
    }
    function renderVisitors(rows) {
        var target = document.getElementById("visitorRows");
        target.innerHTML = rows && rows.length ? rows.map(function (row) {
            return "<tr><td><code>" + escapeHtml(row.address) + "</code></td><td>" + escapeHtml(row.country || "ZZ") +
                "</td><td>" + number(row.visits) + "</td><td>" + escapeHtml(formatTime(row.firstSeen)) + "</td><td>" +
                escapeHtml(formatTime(row.lastSeen)) + "</td><td><code>" + escapeHtml(row.lastPath) + "</code></td></tr>";
        }).join("") : '<tr><td colspan="6">No protected visitor addresses have been recorded yet.</td></tr>';
    }
    function svgElement(name, attributes) {
        var element = document.createElementNS(NS, name);
        Object.keys(attributes || {}).forEach(function (key) { element.setAttribute(key, attributes[key]); });
        return element;
    }
    function coordinateFor(event, index) {
        var source = countryCoordinates[event.country];
        if (!source) return null;
        var seed = 0, text = String(event.address) + String(event.timestamp) + index;
        for (var i = 0; i < text.length; i++) seed = ((seed << 5) - seed + text.charCodeAt(i)) | 0;
        var jitterX = ((seed & 15) - 7.5) * 1.5;
        var jitterY = (((seed >>> 4) & 15) - 7.5) * 1.1;
        return { x: (source[1] + 180) / 360 * 1000 + jitterX, y: (90 - source[0]) / 180 * 500 + jitterY };
    }
    function showMapDetail(event, totalShown) {
        var detail = document.getElementById("mapDetail");
        detail.innerHTML = "<p class=\"developer-analytics__eyebrow\">Protected visit record</p><p><strong>" +
            escapeHtml(event.address) + "</strong><br>" + escapeHtml(event.country || "ZZ") + " · " +
            escapeHtml(formatTime(event.timestamp)) + "<br>Visit #" + number(event.visitNumber) + " · <code>" +
            escapeHtml(event.path) + "</code></p><p>Showing " + number(totalShown) + " mapped counted visit" +
            (totalShown === 1 ? "." : "s.") + " Country placement is approximate.</p>";
    }
    function renderMap() {
        var dots = document.getElementById("mapDots");
        while (dots.firstChild) dots.removeChild(dots.firstChild);
        if (!latest || !latest.visitAnalytics) return;
        var events = latest.visitAnalytics.mapEvents || [];
        if (mapScope === "recent") events = events.filter(isRecent);
        var mapped = 0;
        events.forEach(function (event, index) {
            var point = coordinateFor(event, index);
            if (!point) return;
            mapped++;
            var circle = svgElement("circle", { cx: point.x.toFixed(1), cy: point.y.toFixed(1), r: event.visitNumber > 1 ? 4.5 : 3.7,
                tabindex: "0", role: "button", "aria-label": "Protected visit from " + event.country + ", visit " + event.visitNumber });
            if (event.visitNumber > 1) circle.setAttribute("class", "is-returning");
            circle.addEventListener("mouseenter", function () { showMapDetail(event, mapped); });
            circle.addEventListener("focus", function () { showMapDetail(event, mapped); });
            circle.addEventListener("click", function () { showMapDetail(event, mapped); });
            dots.appendChild(circle);
        });
        if (!mapped) document.getElementById("mapDetail").innerHTML = "<p>No country-mapped visits are available for this period yet.</p>";
        else if (latest.visitAnalytics.mapEventsTruncated) document.getElementById("mapDetail").innerHTML += "<p>For performance, the map shows the latest 5,000 retained events.</p>";
    }
    function renderChart(id, rows, labelMode) {
        var svg = document.getElementById(id);
        while (svg.firstChild) svg.removeChild(svg.firstChild);
        var width = 640, height = 230, left = 36, top = 17, right = 14, bottom = 31;
        var innerWidth = width - left - right, innerHeight = height - top - bottom;
        var values = rows.map(function (row) { return Number(row.visits || 0); });
        var maximum = Math.max.apply(null, values.concat([1]));
        [0, .5, 1].forEach(function (ratio) {
            var y = top + innerHeight * (1 - ratio);
            svg.appendChild(svgElement("line", { x1:left, x2:width-right, y1:y, y2:y, class:"grid" }));
            var text = svgElement("text", { x:left - 7, y:y + 3, "text-anchor":"end" });
            text.textContent = number(maximum * ratio); svg.appendChild(text);
        });
        var points = rows.map(function (row, index) {
            var x = left + (rows.length < 2 ? innerWidth / 2 : index * innerWidth / (rows.length - 1));
            var y = top + innerHeight - (Number(row.visits || 0) / maximum * innerHeight);
            return { x:x, y:y, row:row };
        });
        var area = "M" + points[0].x + " " + (top + innerHeight) + " L" + points.map(function (point) { return point.x + " " + point.y; }).join(" L") + " L" + points[points.length - 1].x + " " + (top + innerHeight) + " Z";
        var line = "M" + points.map(function (point) { return point.x + " " + point.y; }).join(" L");
        svg.appendChild(svgElement("path", { d:area, class:"area" }));
        svg.appendChild(svgElement("path", { d:line, class:"line" }));
        points.forEach(function (point, index) {
            if (rows.length <= 24 || index % Math.ceil(rows.length / 8) === 0 || index === rows.length - 1) {
                var label = svgElement("text", { x:point.x, y:height - 9, "text-anchor":"middle" });
                label.textContent = labelMode === "hour" ? point.row.label.substring(11, 16) : point.row.label.substring(5); svg.appendChild(label);
            }
            var circle = svgElement("circle", { cx:point.x, cy:point.y, r:3, class:"point" });
            var title = svgElement("title"); title.textContent = point.row.label + ": " + number(point.row.visits) + " visits";
            circle.appendChild(title); svg.appendChild(circle);
        });
    }
    function render(payload) {
        latest = payload;
        var analytics = payload.visitAnalytics || {};
        document.getElementById("allTimeVisits").textContent = number(analytics.allTimeVisits);
        document.getElementById("uniqueVisitors").textContent = number(analytics.uniqueVisitors);
        document.getElementById("returningVisitors").textContent = number(analytics.returningVisitors);
        document.getElementById("returningDetail").textContent = number(analytics.returnVisits) + " repeat visits";
        document.getElementById("recentVisits").textContent = number(analytics.recent30Visits);
        document.getElementById("recentDetail").textContent = number(analytics.recent30UniqueVisitors) + " unique visitors";
        document.getElementById("recentRange").textContent = payload.recentStart + " to " + payload.recentEnd;
        renderRows("recentRows", payload.recent30Days); renderRows("allTimeRows", payload.allTime);
        renderPages("pageRows", analytics.topPages); renderPages("recentPageRows", analytics.recentTopPages);
        renderVisitors(analytics.returningVisitorRows);
        renderChart("dailyChart", analytics.daily30 || [], "day"); renderChart("hourlyChart", analytics.hourly24 || [], "hour");
        renderMap();
        document.getElementById("analyticsStatus").textContent = payload.privacy + " Updated " + new Date().toLocaleTimeString() + ".";
    }
    function refresh() {
        fetch("/country-traffic-stats?_=" + Date.now(), { credentials: "same-origin", cache: "no-store", headers: { "Accept":"application/json" } })
            .then(function (response) { if (!response.ok) throw new Error("Unable to load analytics."); return response.json(); })
            .then(render).catch(function () { document.getElementById("analyticsStatus").textContent = "Protected analytics are temporarily unavailable."; });
    }
    function init() {
        Array.prototype.forEach.call(document.querySelectorAll("[data-map-scope]"), function (button) {
            button.addEventListener("click", function () {
                mapScope = button.getAttribute("data-map-scope");
                Array.prototype.forEach.call(document.querySelectorAll("[data-map-scope]"), function (other) { other.classList.toggle("is-active", other === button); });
                renderMap();
            });
        });
        refresh(); window.setInterval(refresh, POLL_MS);
    }
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
}());
