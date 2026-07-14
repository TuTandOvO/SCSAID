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
    var regionCounts = {};
    var countryLayers = {};
    var regionLayers = {};
    var regionFeatureLayers = [];
    var mapAssetWarning = "";
    var expandedVisitors = {};
    var NS = "http://www.w3.org/2000/svg";
    var localTimeZone = detectTimeZone();
    var localTimeFormatter = createTimeFormatter(localTimeZone);

    var countryCodeByIso3 = {
        AFG:"AF", ALB:"AL", DZA:"DZ", ARG:"AR", ARM:"AM", AUS:"AU", AUT:"AT", AZE:"AZ", BGD:"BD", BEL:"BE", BOL:"BO", BRA:"BR", BGR:"BG", CAN:"CA", CHL:"CL", CHN:"CN", COL:"CO", COG:"CG", COD:"CD", CRI:"CR", HRV:"HR", CUB:"CU", CYP:"CY", CZE:"CZ", DNK:"DK", DOM:"DO", ECU:"EC", EGY:"EG", EST:"EE", FIN:"FI", FRA:"FR", DEU:"DE", GHA:"GH", GRC:"GR", GRL:"GL", HKG:"HK", HUN:"HU", ISL:"IS", IND:"IN", IDN:"ID", IRN:"IR", IRQ:"IQ", IRL:"IE", ISR:"IL", ITA:"IT", JPN:"JP", KAZ:"KZ", KEN:"KE", KOR:"KR", LVA:"LV", LTU:"LT", LUX:"LU", MAC:"MO", MYS:"MY", MEX:"MX", MNG:"MN", MAR:"MA", NLD:"NL", NZL:"NZ", NGA:"NG", NOR:"NO", PAK:"PK", PER:"PE", PHL:"PH", POL:"PL", PRT:"PT", ROU:"RO", RUS:"RU", SAU:"SA", SRB:"RS", SGP:"SG", SVK:"SK", SVN:"SI", ZAF:"ZA", ESP:"ES", LKA:"LK", SWE:"SE", CHE:"CH", TWN:"TW", THA:"TH", TUR:"TR", UKR:"UA", ARE:"AE", GBR:"GB", USA:"US", VNM:"VN"
    };
    var countryNames = { CN:"China", GB:"United Kingdom", HK:"Hong Kong", MO:"Macao", US:"United States" };
    var chinaSubdivisionNames = {
        AH:"安徽省", BJ:"北京市", CQ:"重庆市", FJ:"福建省", GD:"广东省", GS:"甘肃省", GX:"广西壮族自治区", GZ:"贵州省", HA:"河南省", HB:"湖北省", HE:"河北省", HI:"海南省", HK:"香港特别行政区", HL:"黑龙江省", HN:"湖南省", JL:"吉林省", JS:"江苏省", JX:"江西省", LN:"辽宁省", MO:"澳门特别行政区", NM:"内蒙古自治区", NX:"宁夏回族自治区", QH:"青海省", SC:"四川省", SD:"山东省", SH:"上海市", SN:"陕西省", SX:"山西省", TJ:"天津市", XJ:"新疆维吾尔自治区", XZ:"西藏自治区", YN:"云南省", ZJ:"浙江省"
    };
    var chinaEnglishNames = {
        anhui:"安徽省", beijing:"北京市", chongqing:"重庆市", fujian:"福建省", guangdong:"广东省", gansu:"甘肃省", guangxi:"广西壮族自治区", guizhou:"贵州省", henan:"河南省", hubei:"湖北省", hebei:"河北省", hainan:"海南省", hongkong:"香港特别行政区", "hong kong":"香港特别行政区", heilongjiang:"黑龙江省", hunan:"湖南省", jilin:"吉林省", jiangsu:"江苏省", jiangxi:"江西省", liaoning:"辽宁省", macao:"澳门特别行政区", macau:"澳门特别行政区", "inner mongolia":"内蒙古自治区", ningxia:"宁夏回族自治区", qinghai:"青海省", sichuan:"四川省", shandong:"山东省", shanghai:"上海市", shaanxi:"陕西省", shanxi:"山西省", tianjin:"天津市", xinjiang:"新疆维吾尔自治区", tibet:"西藏自治区", yunnan:"云南省", zhejiang:"浙江省"
    };

    function number(value, digits) {
        return Number(value || 0).toLocaleString(undefined, { maximumFractionDigits: digits == null ? 0 : digits });
    }

    function escapeHtml(value) {
        return String(value == null ? "" : value).replace(/[&<>'"]/g, function (character) {
            return { "&":"&amp;", "<":"&lt;", ">":"&gt;", "'":"&#39;", '"':"&quot;" }[character];
        });
    }

    function display(value) {
        return value == null || String(value).trim() === "" ? "—" : String(value);
    }

    function detectTimeZone() {
        try { return Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC"; }
        catch (ignored) { return "UTC"; }
    }

    function createTimeFormatter(timeZone) {
        try {
            return new Intl.DateTimeFormat("en-GB", {
                timeZone: timeZone,
                year: "numeric", month: "2-digit", day: "2-digit",
                hour: "2-digit", minute: "2-digit", second: "2-digit",
                hourCycle: "h23"
            });
        } catch (ignored) {
            return null;
        }
    }

    function instantMillis(value) {
        if (!value) return NaN;
        if (typeof value === "number") return value;
        if (typeof value === "string") return new Date(value).getTime();
        if (typeof value.seconds === "number") {
            return value.seconds * 1000 + Math.floor(Number(value.nanos || 0) / 1000000);
        }
        return NaN;
    }

    function formatLocalTime(value) {
        var date = new Date(instantMillis(value));
        if (isNaN(date.getTime())) return "—";
        if (!localTimeFormatter || !localTimeFormatter.formatToParts) {
            var pad = function (part) { return String(part).padStart(2, "0"); };
            return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate()) + " " +
                pad(date.getHours()) + ":" + pad(date.getMinutes()) + ":" + pad(date.getSeconds());
        }
        var parts = {};
        localTimeFormatter.formatToParts(date).forEach(function (part) {
            if (part.type !== "literal") parts[part.type] = part.value;
        });
        return parts.year + "-" + parts.month + "-" + parts.day + " " +
            parts.hour + ":" + parts.minute + ":" + parts.second;
    }

    function normalizeName(value) {
        return String(value || "").toLowerCase().replace(/&/g, "and").replace(/[^a-z0-9\u4e00-\u9fff]+/g, " ").trim();
    }

    function countryName(code) {
        if (countryNames[code]) return countryNames[code];
        try {
            if (typeof Intl.DisplayNames === "function") {
                return new Intl.DisplayNames(["en"], { type:"region" }).of(code) || code;
            }
        } catch (ignored) {}
        return code;
    }

    function isRecent(event) {
        return instantMillis(event.timestamp) >= Date.now() - 30 * 24 * 60 * 60 * 1000;
    }

    function shortVisitorId(row) {
        if (!row || !row.visitorId) return "legacy";
        return row.visitorId.length > 12 ? row.visitorId.substring(0, 12) : row.visitorId;
    }

    function chinaRegionName(event) {
        var code = String(event.regionCode || "").toUpperCase();
        if (chinaSubdivisionNames[code]) return chinaSubdivisionNames[code];
        return chinaEnglishNames[normalizeName(event.regionName)] || event.regionName || "";
    }

    function regionLabel(event) {
        if (event.country === "CN") return chinaRegionName(event) || "China";
        if ((event.country === "US" || event.country === "GB") && event.regionName) return event.regionName;
        return countryName(event.country);
    }

    function regionKey(event) {
        if (event.country === "CN") {
            var chinaName = chinaRegionName(event);
            return chinaName ? "CN:" + normalizeName(chinaName) : "country:CN";
        }
        if ((event.country === "US" || event.country === "GB") && event.regionName) {
            return event.country + ":" + normalizeName(event.regionName);
        }
        return "country:" + event.country;
    }

    function eventVisitorKey(event) {
        return event.visitorKey || event.visitorId || (event.address + ":" + (event.userAgentHash || "legacy"));
    }

    function mapEvents() {
        if (!latest || !latest.visitAnalytics) return [];
        var events = latest.visitAnalytics.mapEvents || [];
        if (mapScope === "recent") events = events.filter(isRecent);
        if (mapScope === "returning") events = events.filter(function (event) { return Number(event.visitNumber || 0) > 1; });
        return events.filter(function (event) { return event.country && event.country !== "ZZ"; });
    }

    function increment(object, key) {
        if (!key || key === "—") return;
        object[key] = (object[key] || 0) + 1;
    }

    function topValue(object) {
        var keys = Object.keys(object);
        if (!keys.length) return "—";
        keys.sort(function (a, b) { return object[b] - object[a] || a.localeCompare(b); });
        return keys[0];
    }

    function aggregateEvents(events) {
        var groups = {};
        events.forEach(function (event) {
            var key = regionKey(event);
            if (!groups[key]) {
                groups[key] = {
                    key:key, country:event.country, label:regionLabel(event), visits:0, returning:0,
                    visitors:{}, browsers:{}, systems:{}, latest:null
                };
            }
            groups[key].visits++;
            groups[key].visitors[eventVisitorKey(event)] = true;
            increment(groups[key].browsers, display(event.browser));
            increment(groups[key].systems, display(event.operatingSystem));
            if (Number(event.visitNumber || 0) > 1) groups[key].returning++;
            if (!groups[key].latest || instantMillis(event.timestamp) > instantMillis(groups[key].latest.timestamp)) {
                groups[key].latest = event;
            }
        });
        return Object.keys(groups).map(function (key) {
            groups[key].uniqueVisitors = Object.keys(groups[key].visitors).length;
            groups[key].topBrowser = topValue(groups[key].browsers);
            groups[key].topSystem = topValue(groups[key].systems);
            return groups[key];
        });
    }

    function renderRows(id, rows) {
        var filtered = (rows || []).filter(function (row) { return row.country && row.country !== "ZZ"; });
        document.getElementById(id).innerHTML = filtered.length ? filtered.map(function (row) {
            return "<tr><td>" + escapeHtml(row.label) + "</td><td><code>" + escapeHtml(row.country) +
                "</code></td><td>" + number(row.visits) + "</td></tr>";
        }).join("") : '<tr><td colspan="3">No mapped visits have been collected yet.</td></tr>';
    }

    function renderPages(id, rows) {
        document.getElementById(id).innerHTML = rows && rows.length ? rows.map(function (row) {
            return "<tr><td><code>" + escapeHtml(row.path) + "</code></td><td>" + number(row.visits) + "</td></tr>";
        }).join("") : '<tr><td colspan="2">No counted content-page visits have been recorded yet.</td></tr>';
    }

    function visitorLocation(row) {
        var region = String(row.regionName || "").trim();
        var country = countryName(row.country || "");
        return region && normalizeName(region) !== normalizeName(country) ? region + ", " + country : country;
    }

    function historyLocation(record) {
        var region = String(record.regionName || "").trim();
        var country = countryName(record.country || "");
        var location = region && normalizeName(region) !== normalizeName(country) ? region + ", " + country : country;
        return location + (record.address ? " · " + record.address : "");
    }

    function visitorKey(row, index) {
        return row.visitorId || row.address || ("visitor-" + index);
    }

    function historyHtml(row) {
        var history = row.history || [];
        var items = history.map(function (record) {
            return '<li><span class="developer-analytics__history-number">Visit #' + number(record.visitNumber) +
                '</span><time class="developer-analytics__time">' + escapeHtml(formatLocalTime(record.timestamp)) +
                '</time><code class="developer-analytics__history-path" title="' + escapeHtml(record.path) + '">' +
                escapeHtml(record.path) + '</code><span class="developer-analytics__history-location">' +
                escapeHtml(historyLocation(record)) + '</span></li>';
        }).join("");
        var note = row.historyTruncated ? '<p class="developer-analytics__history-note">Showing the latest 100 of ' +
            number(row.visits) + ' visits.</p>' : "";
        return '<div class="developer-analytics__history"><ol>' + items + '</ol>' + note + '</div>';
    }

    function renderVisitors(rows) {
        var target = document.getElementById("visitorRows");
        if (!rows || !rows.length) {
            target.innerHTML = '<tr><td colspan="8">No returning visitors have been recorded yet.</td></tr>';
            return;
        }
        target.innerHTML = rows.map(function (row, index) {
            var key = visitorKey(row, index);
            var open = !!expandedVisitors[key];
            var historyId = "visitor-history-" + index;
            var client = display(row.browser) + " · " + display(row.operatingSystem);
            return '<tr class="developer-analytics__visitor-summary' + (open ? " is-open" : "") + '" data-visitor-key="' +
                escapeHtml(key) + '"><td><code class="developer-analytics__visitor-id">' + escapeHtml(shortVisitorId(row)) +
                '</code><span class="developer-analytics__visitor-ip">' + escapeHtml(display(row.address)) +
                '</span></td><td>' + escapeHtml(visitorLocation(row)) + '</td><td>' + escapeHtml(client) +
                '<span class="developer-analytics__visitor-meta">' + escapeHtml(display(row.language)) +
                '</span></td><td><strong class="developer-analytics__visit-count">' + number(row.visits) +
                '</strong></td><td><time class="developer-analytics__time">' + escapeHtml(formatLocalTime(row.firstSeen)) +
                '</time></td><td><time class="developer-analytics__time">' + escapeHtml(formatLocalTime(row.lastSeen)) +
                '</time></td><td><code class="developer-analytics__last-path" title="' + escapeHtml(row.lastPath) + '">' +
                escapeHtml(row.lastPath) + '</code></td><td><button type="button" class="developer-analytics__visitor-toggle" aria-expanded="' +
                (open ? "true" : "false") + '" aria-controls="' + historyId + '" data-visitor-toggle="' +
                escapeHtml(key) + '"><span class="sr-only">Toggle numbered visit history</span></button></td></tr>' +
                '<tr id="' + historyId + '" class="developer-analytics__history-row"' + (open ? "" : " hidden") +
                '><td colspan="8" class="developer-analytics__history-cell">' + historyHtml(row) + '</td></tr>';
        }).join("");
    }

    function toggleVisitor(button) {
        var key = button.getAttribute("data-visitor-toggle");
        var historyId = button.getAttribute("aria-controls");
        var history = document.getElementById(historyId);
        var summary = button.closest("tr");
        var open = button.getAttribute("aria-expanded") !== "true";
        button.setAttribute("aria-expanded", open ? "true" : "false");
        history.hidden = !open;
        summary.classList.toggle("is-open", open);
        if (open) expandedVisitors[key] = true; else delete expandedVisitors[key];
    }

    function svgElement(name, attributes) {
        var element = document.createElementNS(NS, name);
        Object.keys(attributes || {}).forEach(function (key) { element.setAttribute(key, attributes[key]); });
        return element;
    }

    function countryCode(feature) {
        return countryCodeByIso3[feature.id] || feature.id;
    }

    function validLayerCenter(layer) {
        if (!layer || !layer.getBounds) return null;
        var bounds = layer.getBounds();
        return bounds && bounds.isValid && bounds.isValid() ? bounds.getCenter() : null;
    }

    function layerCenter(group) {
        return validLayerCenter(regionLayers[group.key]) || validLayerCenter(countryLayers[group.country]);
    }

    function markerSize(group) {
        return Math.max(18, Math.min(46, 16 + Math.sqrt(group.visits) * 7));
    }

    function markerColor(group) {
        var share = group.visits ? group.returning / group.visits : 0;
        var start = [84, 175, 224], end = [51, 122, 183];
        var rgb = start.map(function (value, index) { return Math.round(value + (end[index] - value) * share); });
        return "rgb(" + rgb.join(",") + ")";
    }

    function markerHtml(group) {
        var size = markerSize(group);
        var label = group.visits > 999 ? "999+" : String(group.visits);
        return '<span class="developer-analytics__marker" style="width:' + size + 'px;height:' + size +
            'px;background:' + markerColor(group) + '">' + escapeHtml(label) + '</span>';
    }

    function tooltipHtml(group) {
        var share = group.visits ? Math.round(group.returning / group.visits * 100) : 0;
        return '<div class="developer-analytics__tooltip-title">' + escapeHtml(group.label) +
            '<span class="developer-analytics__tooltip-code">' + escapeHtml(group.country) + '</span></div>' +
            '<dl class="developer-analytics__tooltip-grid"><dt>Visits</dt><dd>' + number(group.visits) +
            '</dd><dt>Unique visitors</dt><dd>' + number(group.uniqueVisitors) +
            '</dd><dt>Returning visits</dt><dd>' + number(group.returning) +
            '</dd><dt>Returning share</dt><dd>' + number(share) +
            '%</dd><dt>Common client</dt><dd>' + escapeHtml(group.topBrowser + " · " + group.topSystem) +
            '</dd></dl><p class="developer-analytics__tooltip-latest">Latest: ' +
            escapeHtml(formatLocalTime(group.latest && group.latest.timestamp)) + '<code>' +
            escapeHtml(group.latest && group.latest.path) + '</code></p>';
    }

    function updateLayerStyles() {
        if (countryLayer) countryLayer.eachLayer(function (layer) {
            var code = countryCode(layer.feature);
            layer.setStyle({
                className:"developer-analytics__country" + (countryCounts[code] ? " has-visits" : ""),
                fillColor:countryCounts[code] ? "#dcebf5" : "#e9eef1",
                color:countryCounts[code] ? "#91bedb" : "#cfd9df",
                weight:countryCounts[code] ? 1.2 : .8,
                fillOpacity:1
            });
        });
        regionFeatureLayers.forEach(function (layer) {
            var key = layer._scsaidRegionKey;
            var aliases = layer._scsaidRegionAliases || [];
            var hasVisits = !!regionCounts[key] || aliases.some(function (alias) { return !!regionCounts[alias]; });
            layer.setStyle({
                className:"developer-analytics__region" + (hasVisits ? " has-visits" : ""),
                fillColor:hasVisits ? "#a4cfeb" : "#dcebf5",
                color:hasVisits ? "#5e9fc9" : "rgba(82,137,173,.44)",
                weight:hasVisits ? 1.2 : .7,
                fillOpacity:hasVisits ? .62 : .35
            });
        });
    }

    function renderMap() {
        if (!map || !markerLayer) return;
        var groups = aggregateEvents(mapEvents());
        var plottedGroups = 0;
        var plottedVisits = 0;
        var unmappedVisits = 0;
        markerLayer.clearLayers();
        countryCounts = {};
        regionCounts = {};
        groups.forEach(function (group) {
            countryCounts[group.country] = (countryCounts[group.country] || 0) + group.visits;
            regionCounts[group.key] = group.visits;
        });
        updateLayerStyles();
        groups.forEach(function (group) {
            var center = layerCenter(group);
            if (!center) {
                unmappedVisits += group.visits;
                return;
            }
            var size = markerSize(group);
            var marker = L.marker(center, {
                icon:L.divIcon({ className:"", html:markerHtml(group), iconSize:[size, size], iconAnchor:[size / 2, size / 2] }),
                keyboard:true,
                title:group.label
            });
            marker.bindTooltip(tooltipHtml(group), {
                className:"developer-analytics__map-tooltip",
                direction:"top",
                offset:[0, -(size / 2)],
                opacity:1
            });
            marker.on("focus", function () { marker.openTooltip(); });
            marker.on("blur", function () { marker.closeTooltip(); });
            marker.on("click", function () { marker.openTooltip(); });
            marker.addTo(markerLayer);
            plottedGroups++;
            plottedVisits += group.visits;
        });
        var status = plottedGroups ? number(plottedVisits) + " visits across " + number(plottedGroups) +
            " mapped area" + (plottedGroups === 1 ? "" : "s") : "No mapped visits for this period";
        if (unmappedVisits) status += " · " + number(unmappedVisits) + " unresolved";
        if (latest && latest.visitAnalytics && latest.visitAnalytics.mapEventsTruncated) status += " · latest 5,000 events";
        if (mapAssetWarning) status += " · " + mapAssetWarning;
        document.getElementById("mapStatus").textContent = status;
    }

    function registerTerritoryAliases(country, name, item) {
        if (country !== "CN") return;
        var normalized = normalizeName(name);
        var aliases = [];
        if (normalized.indexOf("香港") !== -1 || normalized === "hong kong") aliases.push("country:HK");
        if (normalized.indexOf("澳门") !== -1 || normalized === "macao" || normalized === "macau") aliases.push("country:MO");
        if (normalized.indexOf("台湾") !== -1 || normalized === "taiwan") aliases.push("country:TW");
        aliases.forEach(function (alias) { regionLayers[alias] = item; });
        item._scsaidRegionAliases = aliases;
    }

    function addRegionLayer(geojson, country, nameSelector) {
        return L.geoJSON(geojson, {
            style:function () { return { className:"developer-analytics__region", color:"rgba(82,137,173,.44)", weight:.7, fillColor:"#dcebf5", fillOpacity:.35 }; },
            onEachFeature:function (feature, item) {
                var name = nameSelector(feature);
                var key = country + ":" + normalizeName(name);
                item._scsaidRegionKey = key;
                regionLayers[key] = item;
                registerTerritoryAliases(country, name, item);
                regionFeatureLayers.push(item);
                item.bindTooltip(name, { sticky:true });
            }
        });
    }

    function initMap() {
        map = L.map("visitMap", { attributionControl:false, worldCopyJump:true, minZoom:1, maxZoom:7 }).setView([23, 8], 2);
        markerLayer = L.layerGroup().addTo(map);
        function fetchJson(url) {
            return fetch(url, { cache:"force-cache" }).then(function (response) {
                if (!response.ok) throw new Error("Unable to load " + url);
                return response.json();
            });
        }
        Promise.all([
            fetchJson("/map_resources/world-countries.geojson"),
            fetchJson("/map_resources/us-states.geojson").catch(function () { return null; }),
            fetchJson("/map_resources/china-provinces.json").catch(function () { return null; }),
            fetchJson("/map_resources/uk-local-authorities.topojson").catch(function () { return null; })
        ]).then(function (assets) {
            var missing = [];
            countryLayer = L.geoJSON(assets[0], {
                style:function () { return { className:"developer-analytics__country", color:"#cfd9df", weight:.8, fillColor:"#e9eef1", fillOpacity:1 }; },
                onEachFeature:function (feature, layer) {
                    var code = countryCode(feature);
                    countryLayers[code] = layer;
                    layer.bindTooltip(feature.properties && feature.properties.name ? feature.properties.name : code, { sticky:true });
                }
            }).addTo(map);
            countryLayer.bringToBack();
            if (assets[1]) addRegionLayer(assets[1], "US", function (feature) { return feature.properties.name; }).addTo(map);
            else missing.push("United States");
            if (assets[2]) addRegionLayer(assets[2], "CN", function (feature) { return feature.properties.name; }).addTo(map);
            else missing.push("China");
            if (window.topojson && assets[3] && assets[3].objects && assets[3].objects.lad) {
                addRegionLayer(window.topojson.feature(assets[3], assets[3].objects.lad), "GB", function (feature) {
                    return feature.properties.LAD13NM;
                }).addTo(map);
            } else missing.push("United Kingdom");
            mapAssetWarning = missing.length ? "regional detail unavailable for " + missing.join(", ") : "";
            renderMap();
        }).catch(function () {
            document.getElementById("mapStatus").textContent = "The local regional map files could not be loaded.";
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
                label.textContent = labelMode === "hour" ? point.row.label.substring(11, 16) : point.row.label.substring(5);
                svg.appendChild(label);
            }
            var circle = svgElement("circle", { cx:point.x, cy:point.y, r:3, class:"point" });
            var title = svgElement("title");
            title.textContent = point.row.label + ": " + number(point.row.visits) + " visits";
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
        renderRows("recentRows", payload.recent30Days);
        renderRows("allTimeRows", payload.allTime);
        renderPages("pageRows", analytics.topPages);
        renderPages("recentPageRows", analytics.recentTopPages);
        renderVisitors(analytics.returningVisitorRows);
        renderChart("dailyChart", analytics.daily30 || [], "day");
        renderChart("hourlyChart", analytics.hourly24 || [], "hour");
        renderMap();
        document.getElementById("analyticsStatus").textContent = payload.privacy + " Updated " +
            formatLocalTime(Date.now()) + " (" + localTimeZone + ").";
    }

    function refresh() {
        fetch("/country-traffic-stats?_=" + Date.now(), {
            credentials:"same-origin", cache:"no-store", headers:{ "Accept":"application/json" }
        }).then(function (response) {
            if (!response.ok) throw new Error("Unable to load analytics.");
            return response.json();
        }).then(render).catch(function () {
            document.getElementById("analyticsStatus").textContent = "Protected analytics are temporarily unavailable.";
        });
    }

    function init() {
        document.getElementById("visitorTimeZone").textContent = "Local time · " + localTimeZone;
        initMap();
        Array.prototype.forEach.call(document.querySelectorAll("[data-map-scope]"), function (button) {
            button.addEventListener("click", function () {
                mapScope = button.getAttribute("data-map-scope");
                Array.prototype.forEach.call(document.querySelectorAll("[data-map-scope]"), function (other) {
                    other.classList.toggle("is-active", other === button);
                });
                renderMap();
            });
        });
        document.getElementById("visitorRows").addEventListener("click", function (event) {
            var button = event.target.closest("[data-visitor-toggle]");
            if (button) toggleVisitor(button);
        });
        refresh();
        window.setInterval(refresh, POLL_MS);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
}());
