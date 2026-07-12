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

    function render() {
        if (!latest || !currentMode || modal.hidden) return;
        if (!chart && window.echarts) chart = window.echarts.init(chartNode, null, { renderer: "svg" });
        if (!chart) {
            showError("The traffic chart could not be initialized.");
            return;
        }

        var historySince = latest.historySince || "today";
        if (currentMode === "last24") {
            titleNode.textContent = "Traffic in the last 24 hours";
            subtitleNode.textContent = "Hourly unique-browser visits on a rolling 24-hour window. Times are shown in " + localZone() + ".";
            metricNode.textContent = formatNumber(latest.last24.total);
            metricLabelNode.textContent = "visits in this window";
            chart.setOption(chartOption(latest.last24.labels, latest.last24.values, currentMode), true);
        } else {
            titleNode.textContent = "Average traffic by hour";
            subtitleNode.textContent = "Mean unique-browser visits per UTC hour across " +
                latest.average.daysIncluded + " recorded UTC day" +
                (latest.average.daysIncluded === 1 ? "" : "s") + ".";
            metricNode.textContent = formatNumber(latest.average.averageDaily, 2);
            metricLabelNode.textContent = "average visits per day";
            chart.setOption(chartOption(latest.average.labels, latest.average.values, currentMode), true);
        }
        loading.hidden = true;
        statusNode.className = "traffic-modal__status";
        statusNode.textContent = "Hourly history is available from " + historySince +
            ". Earlier aggregate visits cannot be reconstructed by hour. Updated every 15 seconds.";
        requestAnimationFrame(function () { chart.resize(); });
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
