/**
 * Data Composition Charts - Interactive ECharts visualizations
 * Renders 7 chart types for human/mouse cell count data.
 */
(function () {
    'use strict';

    var COLORS = [
        '#e8927c', '#d4a574', '#7c9eb8', '#a3c4bc', '#c4725e',
        '#8b95a5', '#d4b896', '#9bb5cf', '#e8c9a8', '#5a6473',
        '#b8a99a', '#7eb5a6', '#d4755d', '#c9a0c9', '#8cc4c4',
        '#9b8ec4', '#e8b4a0'
    ];

    var TOOLTIP_STYLE = {
        backgroundColor: '#1a2332',
        borderColor: '#2d3a4f',
        borderWidth: 1,
        textStyle: { color: '#ffffff', fontSize: 13 },
        extraCssText: 'border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.3);'
    };

    var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var ANIMATION = reduceMotion
        ? { animation: false }
        : { animationDuration: 800, animationEasing: 'cubicOut' };

    var charts = [];
    var resizeObservers = [];
    var currentSpecies = 'human';

    function formatNumber(n) {
        return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }

    function getTotal(data) {
        var sum = 0;
        for (var i = 0; i < data.length; i++) sum += data[i].value;
        return sum;
    }

    function destroyCharts() {
        for (var r = 0; r < resizeObservers.length; r++) {
            resizeObservers[r].disconnect();
        }
        resizeObservers = [];
        for (var i = 0; i < charts.length; i++) {
            charts[i].dispose();
        }
        charts = [];
    }

    function initChart(containerId) {
        var el = document.getElementById(containerId);
        if (!el) return null;
        var chart = echarts.init(el);
        charts.push(chart);

        if (window.ResizeObserver) {
            var ro = new ResizeObserver(function () {
                if (!chart.isDisposed()) chart.resize();
            });
            ro.observe(el);
            resizeObservers.push(ro);
        }

        return chart;
    }

    /* ---- Doughnut chart (Gross_Map, Sex, Skin_location) ---- */
    function createDoughnut(containerId, data, showCenterLabel) {
        var chart = initChart(containerId);
        if (!chart) return;

        var total = getTotal(data);
        var seriesData = [];
        for (var i = 0; i < data.length; i++) {
            seriesData.push({ name: data[i].label, value: data[i].value });
        }

        var option = {
            tooltip: Object.assign({}, TOOLTIP_STYLE, {
                trigger: 'item',
                formatter: function (p) {
                    return '<strong>' + p.name + '</strong><br/>' +
                        formatNumber(p.value) + ' cells (' + p.percent + '%)';
                }
            }),
            legend: {
                type: 'scroll',
                orient: 'horizontal',
                bottom: 0,
                left: 'center',
                textStyle: { fontSize: 11, color: '#5a6473' },
                pageTextStyle: { color: '#5a6473' },
                pageIconColor: '#8b95a5',
                pageIconInactiveColor: '#d1c9bd'
            },
            color: COLORS,
            series: [{
                type: 'pie',
                radius: showCenterLabel ? ['42%', '72%'] : ['38%', '68%'],
                center: ['50%', '45%'],
                avoidLabelOverlap: true,
                itemStyle: { borderRadius: 4, borderColor: '#fff', borderWidth: 2 },
                label: { show: false },
                emphasis: {
                    label: { show: true, fontSize: 13, fontWeight: 'bold' },
                    itemStyle: { shadowBlur: 10, shadowOffsetX: 0, shadowColor: 'rgba(0,0,0,0.2)' }
                },
                data: seriesData
            }]
        };

        if (showCenterLabel) {
            option.graphic = [{
                type: 'group',
                left: 'center',
                top: '38%',
                children: [
                    {
                        type: 'text',
                        style: {
                            text: formatNumber(total),
                            textAlign: 'center',
                            fill: '#1a2332',
                            fontSize: 22,
                            fontWeight: 'bold',
                            fontFamily: 'Cormorant Garamond, Georgia, serif'
                        }
                    },
                    {
                        type: 'text',
                        top: 28,
                        style: {
                            text: 'total cells',
                            textAlign: 'center',
                            fill: '#8b95a5',
                            fontSize: 12,
                            fontFamily: 'Montserrat, sans-serif'
                        }
                    }
                ]
            }];
        }

        Object.assign(option, ANIMATION);
        chart.setOption(option);
    }

    /* ---- Horizontal bar chart ---- */
    function createHorizontalBar(containerId, data, barColor) {
        var chart = initChart(containerId);
        if (!chart) return;

        var labels = [];
        var values = [];
        // Reverse so largest is at top
        for (var i = data.length - 1; i >= 0; i--) {
            labels.push(data[i].label);
            values.push(data[i].value);
        }

        // Calculate max label length for grid left margin
        var maxLen = 0;
        for (var j = 0; j < labels.length; j++) {
            if (labels[j].length > maxLen) maxLen = labels[j].length;
        }
        var leftMargin = Math.min(Math.max(maxLen * 6.5, 100), 280);

        var option = {
            tooltip: Object.assign({}, TOOLTIP_STYLE, {
                trigger: 'axis',
                axisPointer: { type: 'shadow' },
                formatter: function (params) {
                    var p = params[0];
                    return '<strong>' + p.name + '</strong><br/>' + formatNumber(p.value) + ' cells';
                }
            }),
            grid: { left: leftMargin, right: 40, top: 10, bottom: 10, containLabel: false },
            xAxis: {
                type: 'value',
                axisLabel: {
                    formatter: function (v) {
                        if (v >= 1000) return (v / 1000) + 'k';
                        return v;
                    },
                    color: '#8b95a5',
                    fontSize: 11
                },
                splitLine: { lineStyle: { color: '#f0ede8' } },
                axisLine: { show: false },
                axisTick: { show: false }
            },
            yAxis: {
                type: 'category',
                data: labels,
                axisLabel: {
                    color: '#5a6473',
                    fontSize: 11,
                    width: leftMargin - 10,
                    overflow: 'truncate',
                    ellipsis: '...'
                },
                axisLine: { show: false },
                axisTick: { show: false }
            },
            series: [{
                type: 'bar',
                data: values,
                barMaxWidth: 20,
                itemStyle: {
                    borderRadius: [0, 3, 3, 0],
                    color: barColor || '#e8927c'
                },
                emphasis: {
                    itemStyle: { shadowBlur: 6, shadowColor: 'rgba(0,0,0,0.15)' }
                }
            }]
        };

        Object.assign(option, ANIMATION);
        chart.setOption(option);
    }

    /* ---- Horizontal bar with dataZoom slider ---- */
    function createScrollableBar(containerId, data, visibleCount, barColor) {
        var chart = initChart(containerId);
        if (!chart) return;

        var labels = [];
        var values = [];
        for (var i = data.length - 1; i >= 0; i--) {
            labels.push(data[i].label);
            values.push(data[i].value);
        }

        var maxLen = 0;
        for (var j = 0; j < labels.length; j++) {
            if (labels[j].length > maxLen) maxLen = labels[j].length;
        }
        var leftMargin = Math.min(Math.max(maxLen * 5.5, 100), 320);

        var startPercent = Math.max(0, 100 - (visibleCount / data.length * 100));

        var option = {
            tooltip: Object.assign({}, TOOLTIP_STYLE, {
                trigger: 'axis',
                axisPointer: { type: 'shadow' },
                formatter: function (params) {
                    var p = params[0];
                    return '<strong>' + p.name + '</strong><br/>' + formatNumber(p.value) + ' cells';
                }
            }),
            grid: { left: leftMargin, right: 50, top: 10, bottom: 50, containLabel: false },
            dataZoom: [{
                type: 'slider',
                yAxisIndex: 0,
                right: 8,
                start: startPercent,
                end: 100,
                width: 18,
                handleSize: '100%',
                handleStyle: { color: '#e8927c', borderColor: '#d4755d' },
                fillerColor: 'rgba(232,146,124,0.15)',
                borderColor: '#e5e0d8',
                textStyle: { color: '#8b95a5' }
            }],
            xAxis: {
                type: 'value',
                axisLabel: {
                    formatter: function (v) {
                        if (v >= 1000) return (v / 1000) + 'k';
                        return v;
                    },
                    color: '#8b95a5',
                    fontSize: 11
                },
                splitLine: { lineStyle: { color: '#f0ede8' } },
                axisLine: { show: false },
                axisTick: { show: false }
            },
            yAxis: {
                type: 'category',
                data: labels,
                axisLabel: {
                    color: '#5a6473',
                    fontSize: 11,
                    width: leftMargin - 10,
                    overflow: 'truncate',
                    ellipsis: '...'
                },
                axisLine: { show: false },
                axisTick: { show: false }
            },
            series: [{
                type: 'bar',
                data: values,
                barMaxWidth: 18,
                itemStyle: {
                    borderRadius: [0, 3, 3, 0],
                    color: barColor || '#7c9eb8'
                },
                emphasis: {
                    itemStyle: { shadowBlur: 6, shadowColor: 'rgba(0,0,0,0.15)' }
                }
            }]
        };

        Object.assign(option, ANIMATION);
        chart.setOption(option);
    }

    /* ---- Render all charts for a species ---- */
    function renderCharts(species) {
        var d = CELL_COUNT_DATA[species];
        if (!d) return;

        destroyCharts();
        currentSpecies = species;

        // Row 1
        createDoughnut('chart-gross-map', d.Gross_Map, true);
        createHorizontalBar('chart-condition', d.Condition, '#e8927c');

        // Row 2
        createDoughnut('chart-sex', d.Sex, false);
        createHorizontalBar('chart-age', d.Age, '#7c9eb8');

        // Skin location — doughnut since it has ≤12 entries
        createDoughnut('chart-skin-location', d.Skin_location, false);

        // Row 3 — Fine Map: scrollable bar with 20 visible
        createScrollableBar('chart-fine-map', d.Fine_Map, 20, '#d4a574');

        // Row 4 — Batch: top 25 with scrollable bar
        var batchTop25 = d.Batch.slice(0, 25);
        createScrollableBar('chart-batch', batchTop25, 15, '#c4725e');
    }

    /* ---- Public API ---- */
    window.CompositionCharts = {
        init: function () {
            renderCharts('human');

            var btns = document.querySelectorAll('.composition__toggle-btn');
            for (var i = 0; i < btns.length; i++) {
                btns[i].addEventListener('click', function () {
                    var species = this.getAttribute('data-species');
                    if (species === currentSpecies) return;

                    // Update active button
                    for (var j = 0; j < btns.length; j++) {
                        btns[j].classList.remove('composition__toggle-btn--active');
                        btns[j].setAttribute('aria-pressed', 'false');
                    }
                    this.classList.add('composition__toggle-btn--active');
                    this.setAttribute('aria-pressed', 'true');

                    renderCharts(species);
                });
            }

            var resizeFrame = 0;
            window.addEventListener('resize', function () {
                window.cancelAnimationFrame(resizeFrame);
                resizeFrame = window.requestAnimationFrame(function () {
                    for (var k = 0; k < charts.length; k++) {
                        if (!charts[k].isDisposed()) charts[k].resize();
                    }
                });
            }, { passive: true });
        }
    };
})();
