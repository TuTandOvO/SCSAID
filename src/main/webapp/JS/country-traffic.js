/* Protected developer analytics dashboard. Self-hosted Leaflet, no remote map tiles. */
(function () {
    "use strict";
    var POLL_MS = 30000;
    var latest = null;
    var mapScope = "all";
    var map = null;
    var countryLayer = null;
    var markerLayer = null;
    var countryCounts = {};
    var NS = "http://www.w3.org/2000/svg";
    var countryCodeByIso3 = {
        AFG:"AF", ALA:"AX", ALB:"AL", DZA:"DZ", ASM:"AS", AND:"AD", AGO:"AO", AIA:"AI", ATA:"AQ", ATG:"AG", ARG:"AR", ARM:"AM", ABW:"AW", AUS:"AU", AUT:"AT", AZE:"AZ",
        BHS:"BS", BHR:"BH", BGD:"BD", BRB:"BB", BLR:"BY", BEL:"BE", BLZ:"BZ", BEN:"BJ", BMU:"BM", BTN:"BT", BOL:"BO", BES:"BQ", BIH:"BA", BWA:"BW", BVT:"BV", BRA:"BR", IOT:"IO", BRN:"BN", BGR:"BG", BFA:"BF", BDI:"BI",
        CPV:"CV", KHM:"KH", CMR:"CM", CAN:"CA", CYM:"KY", CAF:"CF", TCD:"TD", CHL:"CL", CHN:"CN", CXR:"CX", CCK:"CC", COL:"CO", COM:"KM", COG:"CG", COD:"CD", COK:"CK", CRI:"CR", CIV:"CI", HRV:"HR", CUB:"CU", CUW:"CW", CYP:"CY", CZE:"CZ",
        DNK:"DK", DJI:"DJ", DMA:"DM", DOM:"DO", ECU:"EC", EGY:"EG", SLV:"SV", GNQ:"GQ", ERI:"ER", EST:"EE", SWZ:"SZ", ETH:"ET", FLK:"FK", FRO:"FO", FJI:"FJ", FIN:"FI", FRA:"FR", GUF:"GF", PYF:"PF", ATF:"TF",
        GAB:"GA", GMB:"GM", GEO:"GE", DEU:"DE", GHA:"GH", GIB:"GI", GRC:"GR", GRL:"GL", GRD:"GD", GLP:"GP", GUM:"GU", GTM:"GT", GGY:"GG", GIN:"GN", GNB:"GW", GUY:"GY",
        HTI:"HT", HMD:"HM", VAT:"VA", HND:"HN", HKG:"HK", HUN:"HU", ISL:"IS", IND:"IN", IDN:"ID", IRN:"IR", IRQ:"IQ", IRL:"IE", IMN:"IM", ISR:"IL", ITA:"IT",
        JAM:"JM", JPN:"JP", JEY:"JE", JOR:"JO", KAZ:"KZ", KEN:"KE", KIR:"KI", PRK:"KP", KOR:"KR", KWT:"KW", KGZ:"KG", LAO:"LA", LVA:"LV", LBN:"LB", LSO:"LS", LBR:"LR", LBY:"LY", LIE:"LI", LTU:"LT", LUX:"LU",
        MAC:"MO", MDG:"MG", MWI:"MW", MYS:"MY", MDV:"MV", MLI:"ML", MLT:"MT", MHL:"MH", MTQ:"MQ", MRT:"MR", MUS:"MU", MYT:"YT", MEX:"MX", FSM:"FM", MDA:"MD", MCO:"MC", MNG:"MN", MNE:"ME", MSR:"MS", MAR:"MA", MOZ:"MZ", MMR:"MM",
        NAM:"NA", NRU:"NR", NPL:"NP", NLD:"NL", NCL:"NC", NZL:"NZ", NIC:"NI", NER:"NE", NGA:"NG", NIU:"NU", NFK:"NF", MKD:"MK", MNP:"MP", NOR:"NO", OMN:"OM",
        PAK:"PK", PLW:"PW", PSE:"PS", PAN:"PA", PNG:"PG", PRY:"PY", PER:"PE", PHL:"PH", PCN:"PN", POL:"PL", PRT:"PT", PRI:"PR", QAT:"QA", REU:"RE", ROU:"RO", RUS:"RU", RWA:"RW",
        BLM:"BL", SHN:"SH", KNA:"KN", LCA:"LC", MAF:"MF", SPM:"PM", VCT:"VC", WSM:"WS", SMR:"SM", STP:"ST", SAU:"SA", SEN:"SN", SRB:"RS", SYC:"SC", SLE:"SL", SGP:"SG", SXM:"SX", SVK:"SK", SVN:"SI", SLB:"SB", SOM:"SO", ZAF:"ZA", SGS:"GS", SSD:"SS", ESP:"ES", LKA:"LK", SDN:"SD", SUR:"SR", SJM:"SJ", SWE:"SE", CHE:"CH", SYR:"SY", TWN:"TW",
        TJK:"TJ", TZA:"TZ", THA:"TH", TLS:"TL", TGO:"TG", TKL:"TK", TON:"TO", TTO:"TT", TUN:"TN", TUR:"TR", TKM:"TM", TCA:"TC", TUV:"TV",
        UGA:"UG", UKR:"UA", ARE:"AE", GBR:"GB", USA:"US", UMI:"UM", URY:"UY", UZB:"UZ", VUT:"VU", VEN:"VE", VNM:"VN", VGB:"VG", VIR:"VI", WLF:"WF", ESH:"EH", YEM:"YE", ZMB:"ZM", ZWE:"ZW"
    };
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
        if (!value) return "-";
        var date = new Date(value);
        return isNaN(date.getTime()) ? "-" : date.toISOString().replace("T", " ").replace(".000Z", "Z");
    }
    function display(value) {
        return value == null || String(value).trim() === "" ? "-" : String(value);
    }
    function shortVisitorId(row) {
        if (!row || !row.visitorId) return "legacy";
        return row.visitorId.length > 12 ? row.visitorId.substring(0, 12) : row.visitorId;
    }
    function isRecent(event) {
        return new Date(event.timestamp).getTime() >= Date.now() - 30 * 24 * 60 * 60 * 1000;
    }
    function mapEvents() {
        if (!latest || !latest.visitAnalytics) return [];
        var events = latest.visitAnalytics.mapEvents || [];
        if (mapScope === "recent") events = events.filter(isRecent);
        if (mapScope === "returning") events = events.filter(function (event) { return Number(event.visitNumber || 0) > 1; });
        return events.filter(function (event) { return event.country && event.country !== "ZZ"; });
    }
    function renderRows(id, rows) {
        var filtered = (rows || []).filter(function (row) { return row.country && row.country !== "ZZ"; });
        document.getElementById(id).innerHTML = filtered.length ? filtered.map(function (row) {
            return "<tr><td>" + escapeHtml(row.label) + "</td><td><code>" + escapeHtml(row.country) +
                "</code></td><td>" + number(row.visits) + "</td></tr>";
        }).join("") : '<tr><td colspan="3">No country-mapped visits have been collected yet.</td></tr>';
    }
    function renderPages(id, rows) {
        document.getElementById(id).innerHTML = rows && rows.length ? rows.map(function (row) {
            return "<tr><td><code>" + escapeHtml(row.path) + "</code></td><td>" + number(row.visits) + "</td></tr>";
        }).join("") : '<tr><td colspan="2">No counted content-page visits have been recorded yet.</td></tr>';
    }
    function renderVisitors(rows) {
        var target = document.getElementById("visitorRows");
        target.innerHTML = rows && rows.length ? rows.map(function (row) {
            return "<tr><td><code>" + escapeHtml(shortVisitorId(row)) + "</code></td><td><code>" + escapeHtml(row.address) +
                "</code></td><td>" + escapeHtml(display(row.country)) + "</td><td>" + escapeHtml(display(row.browser)) +
                "</td><td>" + escapeHtml(display(row.operatingSystem)) + "</td><td>" + escapeHtml(display(row.language)) +
                "</td><td>" + number(row.visits) + "</td><td>" + escapeHtml(formatTime(row.firstSeen)) + "</td><td>" +
                escapeHtml(formatTime(row.lastSeen)) + "</td><td><code>" + escapeHtml(row.lastPath) + "</code></td></tr>";
        }).join("") : '<tr><td colspan="10">No protected visitor IDs have been recorded yet.</td></tr>';
    }
    function svgElement(name, attributes) {
        var element = document.createElementNS(NS, name);
        Object.keys(attributes || {}).forEach(function (key) { element.setAttribute(key, attributes[key]); });
        return element;
    }
    function countryCode(feature) {
        return countryCodeByIso3[feature.id] || feature.id;
    }
    function coordinatesFor(event, index) {
        var source = countryCoordinates[event.country];
        if (!source) return null;
        var seed = 0, text = String(event.visitorId || event.address) + String(event.timestamp) + index;
        for (var i = 0; i < text.length; i++) seed = ((seed << 5) - seed + text.charCodeAt(i)) | 0;
        var latJitter = (((seed >>> 4) & 15) - 7.5) * .18;
        var lngJitter = ((seed & 15) - 7.5) * .28;
        return [source[0] + latJitter, source[1] + lngJitter];
    }
    function markerHtml(event, sameCountryCount) {
        var count = sameCountryCount > 1 ? String(Math.min(sameCountryCount, 99)) : "";
        return '<span class="developer-analytics__marker ' + (event.visitNumber > 1 ? "is-returning " : "") +
            (sameCountryCount > 1 ? "is-cluster" : "") + '">' + escapeHtml(count) + '</span>';
    }
    function popupHtml(event) {
        return "<p class=\"developer-analytics__eyebrow\">Protected visit record</p><p><strong>Visitor " +
            escapeHtml(shortVisitorId(event)) + "</strong><br>" + escapeHtml(event.country) + " · " +
            escapeHtml(formatTime(event.timestamp)) + "<br>Visit #" + number(event.visitNumber) + " · <code>" +
            escapeHtml(event.path) + "</code></p><p>" + escapeHtml(display(event.browser)) + " · " +
            escapeHtml(display(event.operatingSystem)) + " · " + escapeHtml(display(event.language)) + "</p>";
    }
    function showMapDetail(event, totalShown) {
        document.getElementById("mapDetail").innerHTML = popupHtml(event) + "<p>Showing " + number(totalShown) +
            " mapped counted visit" + (totalShown === 1 ? "." : "s.") + " Placement is country-level approximate.</p>";
    }
    function updateCountryStyles() {
        if (!countryLayer) return;
        countryLayer.eachLayer(function (layer) {
            var code = countryCode(layer.feature);
            layer.setStyle({
                className: "developer-analytics__country" + (countryCounts[code] ? " has-visits" : ""),
                fillColor: countryCounts[code] ? "#ddecf8" : "#e8eff3",
                color: countryCounts[code] ? "#9fc7e2" : "#d2dee5",
                weight: countryCounts[code] ? 1.2 : .8,
                fillOpacity: 1
            });
        });
    }
    function renderMap() {
        if (!map || !markerLayer) return;
        var events = mapEvents();
        markerLayer.clearLayers();
        countryCounts = {};
        events.forEach(function (event) { countryCounts[event.country] = (countryCounts[event.country] || 0) + 1; });
        updateCountryStyles();
        events.forEach(function (event, index) {
            var coordinates = coordinatesFor(event, index);
            if (!coordinates) return;
            var marker = L.marker(coordinates, {
                icon: L.divIcon({
                    className: "",
                    html: markerHtml(event, countryCounts[event.country] || 1),
                    iconSize: [26, 26],
                    iconAnchor: [13, 13]
                }),
                keyboard: true,
                title: "Visitor " + shortVisitorId(event)
            });
            marker.bindPopup(popupHtml(event));
            marker.on("mouseover focus click", function () { showMapDetail(event, events.length); });
            marker.addTo(markerLayer);
        });
        if (!events.length) {
            document.getElementById("mapDetail").innerHTML = "<p>No country-mapped visits are available for this period yet.</p>";
        } else if (latest.visitAnalytics && latest.visitAnalytics.mapEventsTruncated) {
            document.getElementById("mapDetail").innerHTML += "<p>For performance, the map shows the latest 5,000 retained events.</p>";
        }
    }
    function initMap() {
        map = L.map("visitMap", {
            attributionControl: false,
            worldCopyJump: true,
            minZoom: 1,
            maxZoom: 5
        }).setView([23, 8], 2);
        markerLayer = L.layerGroup().addTo(map);
        fetch("/map_resources/world-countries.geojson", { cache: "force-cache" })
            .then(function (response) { if (!response.ok) throw new Error("map"); return response.json(); })
            .then(function (geojson) {
                countryLayer = L.geoJSON(geojson, {
                    style: function () { return { className:"developer-analytics__country", color:"#d2dee5", weight:.8, fillColor:"#e8eff3", fillOpacity:1 }; },
                    onEachFeature: function (feature, layer) {
                        layer.bindTooltip(feature.properties && feature.properties.name ? feature.properties.name : countryCode(feature));
                    }
                }).addTo(map);
                countryLayer.bringToBack();
                renderMap();
            })
            .catch(function () {
                document.getElementById("mapDetail").innerHTML = "<p>The local map file could not be loaded.</p>";
            });
    }
    function renderChart(id, rows, labelMode) {
        var svg = document.getElementById(id);
        while (svg.firstChild) svg.removeChild(svg.firstChild);
        rows = rows && rows.length ? rows : [{ label:"", visits:0 }];
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
        initMap();
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
