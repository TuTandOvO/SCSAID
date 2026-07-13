/* Live traffic charts for the homepage footer. Opens on dblclick only. */
(function () {
    "use strict";

    var POLL_MS = 15000;
    var modal, dialog, closeButton, chartNode, loading, statusNode;
    var titleNode, subtitleNode, metricNode, metricLabelNode;
    var totalTrigger, todayTrigger, totalValue, todayValue;
    var chart = null;
    var currentMode = null;
    var latest = null;
    var lastFocus = null;

    function localZone() {
        try { return Intl.DateTimeFormat().resolvedOptions().timeZone || "local time"; }
        catch (ignored) { return "local time"; }
    }

    function formatNumber(value, digits) {
        return Number(value || 0).toLocaleString(undefined, {
            maximumFractionDigits: digits == null ? 0 : digits
        });
    }

    function formatLocalHour(iso) {
        return new Intl.DateTimeFormat(undefined, {
            weekday: "short", hour: "2-digit", minute: "2-digit"
        }).format(new Date(iso));
    }

    function chartOption(labels, values, mode) {
        var average = mode === "average";
        return {
            animationDuration: 280,
            color: ["#3d86c6"],
            grid: { left: 48, right: 22, top: 30, bottom: 58 },
            tooltip: {
                trigger: "axis",
                confine: true,
                formatter: function (items) {
                    var item = items[0];
                    var label = average ? item.axisValue + " UTC" : formatLocalHour(labels[item.dataIndex]);
                    return label + "<br><strong>" + formatNumber(item.value, average ? 2 : 0) + "</strong> visits";
                }
            },
            xAxis: {
                type: "category",
                boundaryGap: false,
                data: labels.map(function (label) {
                    if (average) return label;
                    return new Intl.DateTimeFormat(undefined, {
                        hour: "2-digit", minute: "2-digit"
                    }).format(new Date(label));
                }),
                axisLine: { lineStyle: { color: "#d7d9dc" } },
                axisTick: { show: false },
                axisLabel: { color: "#777", fontSize: 11, interval: 3, hideOverlap: true }
            },
            yAxis: {
                type: "value",
                minInterval: average ? 0 : 1,
                axisLine: { show: false },
                axisTick: { show: false },
                axisLabel: { color: "#777", fontSize: 11 },
                splitLine: { lineStyle: { color: "#ececef" } }
            },
            series: [{
                type: "line",
                data: values,
                smooth: false,
                symbol: "circle",
                symbolSize: 6,
                showSymbol: true,
                lineStyle: { width: 2 },
                itemStyle: { borderWidth: 1, borderColor: "#ffffff" },
                areaStyle: { color: "rgba(61, 134, 198, 0.13)" }
            }]
        };
    }

    /* Keep the footer traffic panel functional when a CDN-hosted chart library
       is unavailable. The fallback is deliberately dependency-free SVG. */
    function renderFallbackChart(labels, values, mode) {
        var width = 620, height = 250, left = 40, top = 22, right = 18, bottom = 40;
        var innerWidth = width - left - right, innerHeight = height - top - bottom;
        var maximum = Math.max.apply(null, values.concat([1]));
        var points = values.map(function (value, index) {
            return {
                x: left + (values.length < 2 ? innerWidth / 2 : index * innerWidth / (values.length - 1)),
                y: top + innerHeight - (Number(value || 0) / maximum * innerHeight)
            };
        });
        var line = points.map(function (point, index) {
            return (index ? "L" : "M") + point.x.toFixed(1) + " " + point.y.toFixed(1);
        }).join(" ");
        var area = "M" + points[0].x.toFixed(1) + " " + (top + innerHeight) + " L" + line.substring(1) +
            " L" + points[points.length - 1].x.toFixed(1) + " " + (top + innerHeight) + " Z";
        var grid = [0, .5, 1].map(function (ratio) {
            var y = top + innerHeight * (1 - ratio);
            return '<line x1="' + left + '" x2="' + (width - right) + '" y1="' + y + '" y2="' + y +
                '" stroke="#ececef"/><text x="' + (left - 8) + '" y="' + (y + 4) + '" text-anchor="end">' +
                formatNumber(maximum * ratio, mode === "average" ? 2 : 0) + '</text>';
        }).join("");
        var labelsSvg = points.map(function (point, index) {
            if (index % Math.max(1, Math.ceil(points.length / 7)) !== 0 && index !== points.length - 1) return "";
            var label = mode === "average" ? labels[index] + " UTC" : new Intl.DateTimeFormat(undefined, { hour:"2-digit" }).format(new Date(labels[index]));
            return '<text x="' + point.x + '" y="' + (height - 12) + '" text-anchor="middle">' + label + '</text>';
        }).join("");
        chartNode.innerHTML = '<svg viewBox="0 0 ' + width + ' ' + height + '" role="img" aria-label="Traffic chart" ' +
            'style="width:100%;height:100%;font:11px sans-serif;fill:#777"><g>' + grid + '</g><path d="' + area +
            '" fill="rgba(61,134,198,.13)"/><path d="' + line + '" fill="none" stroke="#3d86c6" stroke-width="2.5"/>' +
            points.map(function (point) { return '<circle cx="' + point.x + '" cy="' + point.y + '" r="3" fill="#3d86c6" stroke="#fff"/>'; }).join("") +
            '<g>' + labelsSvg + '</g></svg>';
    }

    function render() {
        if (!latest || !currentMode || modal.hidden) return;
        if (!chart && window.echarts) chart = window.echarts.init(chartNode, null, { renderer: "svg" });

        var historySince = latest.historySince || "today";
        if (currentMode === "last24") {
            titleNode.textContent = "Traffic in the last 24 hours";
            subtitleNode.textContent = "Hourly unique-browser visits on a rolling 24-hour window. Times are shown in " + localZone() + ".";
            metricNode.textContent = formatNumber(latest.last24.total);
            metricLabelNode.textContent = "visits in this window";
            if (chart) chart.setOption(chartOption(latest.last24.labels, latest.last24.values, currentMode), true);
            else renderFallbackChart(latest.last24.labels, latest.last24.values, currentMode);
        } else {
            titleNode.textContent = "Average traffic by hour";
            subtitleNode.textContent = "Mean unique-browser visits per UTC hour across " +
                latest.average.daysIncluded + " recorded UTC day" +
                (latest.average.daysIncluded === 1 ? "" : "s") + ".";
            metricNode.textContent = formatNumber(latest.average.averageDaily, 2);
            metricLabelNode.textContent = "average visits per day";
            if (chart) chart.setOption(chartOption(latest.average.labels, latest.average.values, currentMode), true);
            else renderFallbackChart(latest.average.labels, latest.average.values, currentMode);
        }
        loading.hidden = true;
        statusNode.className = "traffic-modal__status";
        statusNode.textContent = "Hourly history is available from " + historySince +
            ". Earlier aggregate visits cannot be reconstructed by hour. Updated every 15 seconds.";
        if (chart) requestAnimationFrame(function () { chart.resize(); });
    }

    function showError(message) {
        loading.hidden = true;
        statusNode.className = "traffic-modal__status traffic-modal__status--error";
        statusNode.textContent = message;
    }

    function refresh() {
        return fetch("/traffic-stats?_=" + Date.now(), {
            credentials: "same-origin",
            cache: "no-store",
            headers: { "Accept": "application/json" }
        }).then(function (response) {
            if (!response.ok) throw new Error("HTTP " + response.status);
            return response.json();
        }).then(function (payload) {
            latest = payload;
            totalValue.textContent = formatNumber(payload.totalVisits);
            todayValue.textContent = formatNumber(payload.todayVisits);
            render();
        }).catch(function () {
            if (!modal.hidden) showError("Live traffic statistics are temporarily unavailable. Please try again shortly.");
        });
    }

    function open(mode, trigger) {
        currentMode = mode;
        lastFocus = trigger;
        modal.hidden = false;
        document.body.classList.add("traffic-modal-open");
        loading.hidden = false;
        statusNode.textContent = "";
        dialog.focus();
        if (latest) render();
        refresh();
    }

    function close() {
        if (modal.hidden) return;
        modal.hidden = true;
        document.body.classList.remove("traffic-modal-open");
        currentMode = null;
        if (lastFocus) lastFocus.focus({ preventScroll: true });
    }

    function init() {
        modal = document.getElementById("trafficModal");
        dialog = modal.querySelector(".traffic-modal__dialog");
        closeButton = document.getElementById("trafficModalClose");
        chartNode = document.getElementById("trafficChart");
        loading = document.getElementById("trafficLoading");
        statusNode = document.getElementById("trafficStatus");
        titleNode = document.getElementById("trafficModalTitle");
        subtitleNode = document.getElementById("trafficModalSubtitle");
        metricNode = document.getElementById("trafficMetric");
        metricLabelNode = document.getElementById("trafficMetricLabel");
        totalTrigger = document.getElementById("totalVisitsTrigger");
        todayTrigger = document.getElementById("todayVisitsTrigger");
        totalValue = document.getElementById("totalVisitsValue");
        todayValue = document.getElementById("todayVisitsValue");

        totalTrigger.addEventListener("dblclick", function () { open("average", totalTrigger); });
        todayTrigger.addEventListener("dblclick", function () { open("last24", todayTrigger); });
        closeButton.addEventListener("click", close);
        modal.querySelector("[data-traffic-close]").addEventListener("click", close);
        document.addEventListener("keydown", function (event) {
            if (event.key === "Escape" && !modal.hidden) close();
        });
        window.addEventListener("resize", function () { if (chart && !modal.hidden) chart.resize(); });

        refresh();
        window.setInterval(refresh, POLL_MS);
    }

    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
    else init();
})();
