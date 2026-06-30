/* Condition-vs-condition comparison page.
 * Wires the Compare page against /conditions, /condition-compare, /condition-gsea.
 */
(function () {
    "use strict";

    // -------- Module state ----------------------------------------------------
    var state = {
        species: "human",
        degJobId: null,
        cellTypes: [],
        gseaJobId: null,
        conditions: {},   // condition name -> n_samples (for the advisory)
    };

    // Conservative name-based pseudogene heuristic (same regex as details.jsp).
    var PSEUDOGENE_RE = /^(Gm\d+|.+-ps\d*|.+Rik|.+-PS\d*)$/;
    function isPseudogene(name) {
        if (!name) return false;
        return PSEUDOGENE_RE.test(String(name));
    }

    function populateSelect(options, $sel, placeholder, defaultValue) {
        $sel.empty();
        if (placeholder !== undefined) {
            $sel.append('<option value="">' + placeholder + '</option>');
        }
        (options || []).forEach(function (opt) {
            var val, label;
            if (typeof opt === "string") { val = label = opt; }
            else { val = opt.value; label = opt.label; }
            $sel.append('<option value="' + $('<div>').text(val).html() + '">' +
                        $('<div>').text(label).html() + '</option>');
        });
        if (defaultValue !== undefined &&
            $sel.find('option[value="' + defaultValue + '"]').length) {
            $sel.val(defaultValue);
        }
    }

    // -------- Conditions loader -----------------------------------------------
    function loadConditions() {
        $.getJSON("conditions", { species: state.species })
            .done(function (rows) {
                state.conditions = {};
                var opts = (rows || []).map(function (r) {
                    state.conditions[r.condition] = r.n_samples;
                    return { value: r.condition, label: r.condition + "  (n=" + r.n_samples + ")" };
                });
                populateSelect(opts, $("#conditionA"), "— select condition A —");
                populateSelect(opts, $("#conditionB"), "— select condition B —", "Healthy");
                updateRunBtn();
            })
            .fail(function (xhr) {
                $("#runError").text("Failed to load conditions (" + xhr.status + ")").prop("hidden", false);
            });
    }

    function loadGmtCatalog() {
        $.getJSON("gmt-catalog", { species: state.species })
            .done(function (data) {
                var libs = (data && data.libraries) || [];
                var opts = libs.map(function (l) {
                    return { value: l.file, label: l.label + "  (" + l.n_sets + " sets)" };
                });
                populateSelect(opts, $("#gseaGmtSelect"));
                $("#gseaGmtSelect").prop("disabled", libs.length === 0);
            });
    }

    // -------- Run button enable/disable --------------------------------------
    function updateRunBtn() {
        var a = $("#conditionA").val();
        var b = $("#conditionB").val();
        $("#runBtn").prop("disabled", !a || !b || a === b);
        updateAdvisory();
    }

    // Non-blocking advisory: flag comparisons that are easy to over-interpret —
    // disease-vs-disease (no shared baseline; region/cohort/batch confounding)
    // and very small sample sizes (underpowered pseudobulk). The user can still run.
    function updateAdvisory() {
        var $box = $("#compareAdvisory");
        if (!$box.length) { return; }
        var a = $("#conditionA").val();
        var b = $("#conditionB").val();
        if (!a || !b || a === b) { $box.prop("hidden", true).empty(); return; }

        var BASELINE = "Healthy";
        var SMALL = 3;
        var esc = function (s) { return $('<div>').text(s).html(); };
        var notes = [];

        if (a !== BASELINE && b !== BASELINE) {
            notes.push("<strong>Disease vs disease.</strong> Neither side is the healthy baseline, so the " +
                "differentially expressed genes can reflect <em>skin region, cohort and study (batch)</em> " +
                "differences as much as disease biology — especially when the two conditions were profiled at " +
                "different body sites. For a cleaner result, compare each condition against <em>Healthy</em>, " +
                "or read these genes as descriptive rather than disease-specific.");
        }

        var low = [];
        var nA = state.conditions[a], nB = state.conditions[b];
        if (nA != null && nA < SMALL) { low.push(esc(a) + " (n=" + nA + ")"); }
        if (nB != null && nB < SMALL) { low.push(esc(b) + " (n=" + nB + ")"); }
        if (low.length) {
            notes.push("<strong>Small sample size:</strong> " + low.join(" and ") + ". Pseudobulk DESeq2 " +
                "uses samples as replicates, so with this few replicates the fold-changes and adjusted " +
                "p-values are underpowered and unstable.");
        }

        if (!notes.length) { $box.prop("hidden", true).empty(); return; }
        var html = '<div class="compare-advisory__title">Interpret with care — you can still run it</div>' +
                   '<ul class="compare-advisory__list">';
        notes.forEach(function (n) { html += "<li>" + n + "</li>"; });
        $box.html(html + "</ul>").prop("hidden", false);
    }

    // -------- Summary chips ---------------------------------------------------
    function renderSummary(s, condA, condB) {
        var items = [
            { label: "Species", value: state.species },
            { label: "A — case", value: condA + " · n=" + (s.nSamplesA || "?") },
            { label: "B — ref", value: condB + " · n=" + (s.nSamplesB || "?") },
            { label: "Cell types", value: (s.cellTypes || []).length + " analyzed" },
        ];
        var html = items.map(function (it) {
            return '<span class="run-summary__item">' +
                   '<span class="run-summary__label">' + it.label + '</span>' +
                   '<span class="run-summary__value">' + $('<div>').text(it.value).html() + '</span>' +
                   '</span>';
        }).join("");

        if (s.skipped && s.skipped.length) {
            html += '<div class="run-summary__skipped">Skipped ' + s.skipped.length +
                    ' cell type(s): ' + $('<div>').text(
                        s.skipped.slice(0, 4).join("; ") + (s.skipped.length > 4 ? " …" : "")
                    ).html() + '</div>';
        }
        $("#runSummary").html(html).prop("hidden", false);
    }

    // -------- DEG / GSEA panel visibility ------------------------------------
    function showDegResults() {
        $("#degEmpty").prop("hidden", true);
        $("#degResults").prop("hidden", false);
    }
    function hideDegResults() {
        $("#degEmpty").prop("hidden", false);
        $("#degResults").prop("hidden", true);
    }
    function unlockGsea() {
        $("#gseaPanel").attr("data-locked", "false");
        $("#gseaEmpty").prop("hidden", true);
        $("#gseaResults").prop("hidden", false);
    }
    function lockGsea() {
        $("#gseaPanel").attr("data-locked", "true");
        $("#gseaEmpty").prop("hidden", false);
        $("#gseaResults").prop("hidden", true);
    }

    // -------- DEG job ---------------------------------------------------------
    function runCompare() {
        var a = $("#conditionA").val();
        var b = $("#conditionB").val();
        if (!a || !b || a === b) return;

        $("#runError").prop("hidden", true);
        $("#runSummary").prop("hidden", true).empty();
        $("#runProgress").prop("hidden", false);
        $("#runProgressText").text("Queued…");
        $("#runBtn").prop("disabled", true);
        clearResults();

        $.ajax({
            url: "condition-compare",
            method: "POST",
            contentType: "application/json",
            data: JSON.stringify({ species: state.species, conditionA: a, conditionB: b }),
        })
        .done(function (resp) {
            state.degJobId = resp.jobId;
            pollDegStatus(a, b);
        })
        .fail(function (xhr) {
            $("#runProgress").prop("hidden", true);
            $("#runError").text("Failed to start job (" + xhr.status + ")").prop("hidden", false);
            updateRunBtn();
        });
    }

    function pollDegStatus(condA, condB) {
        if (!state.degJobId) return;
        $.getJSON("condition-compare/status", { jobId: state.degJobId })
            .done(function (s) {
                var phase = s.phase ? " · " + s.phase : "";
                var ctInfo = (s.cellTypesTotal && s.cellTypesTotal > 0)
                    ? " · " + (s.cellTypesDone || 0) + "/" + s.cellTypesTotal + " cell types"
                    : "";
                var pct = s.progress ? " · " + s.progress + "%" : "";
                $("#runProgressText").text("Running" + phase + ctInfo + pct);

                if (s.state === "done") {
                    $("#runProgress").prop("hidden", true);
                    state.cellTypes = s.cellTypes || [];
                    renderSummary(s, condA, condB);
                    populateSelect(state.cellTypes, $("#cellTypeSelect"), "All cell types");
                    populateSelect(state.cellTypes, $("#gseaCellTypeSelect"));
                    $("#gseaCellTypeSelect").prop("disabled", state.cellTypes.length === 0);
                    $("#runGseaBtn").prop("disabled", state.cellTypes.length === 0);
                    $("#exportDegBtn").prop("disabled", false);
                    showDegResults();
                    unlockGsea();
                    loadDeg();
                    updateRunBtn();
                } else if (s.state === "error") {
                    $("#runProgress").prop("hidden", true);
                    $("#runError").text("Job failed: " + (s.error || "unknown")).prop("hidden", false);
                    updateRunBtn();
                } else {
                    setTimeout(function () { pollDegStatus(condA, condB); }, 2500);
                }
            })
            .fail(function (xhr) {
                $("#runProgress").prop("hidden", true);
                $("#runError").text("Status poll failed (" + xhr.status + ")").prop("hidden", false);
                updateRunBtn();
            });
    }

    // -------- DEG table -------------------------------------------------------
    var degTable = null;
    function ensureDegTable() {
        if (degTable) return;
        degTable = $("#degTable").DataTable({
            paging: true, searching: true, info: true, order: [[3, "asc"]],
            columnDefs: [
                { targets: [1, 2, 3], className: "dt-right" },
                {
                    targets: 1,
                    render: function (v) { return (typeof v === "number") ? v.toFixed(3) : v; }
                },
                {
                    targets: [2, 3],
                    render: function (v) {
                        if (v === null || v === undefined) return "";
                        return (Math.abs(v) < 1e-3) ? v.toExponential(2) : v.toFixed(4);
                    }
                },
            ],
        });
    }

    function loadDeg() {
        if (!state.degJobId) return;
        var pval = parseFloat($("#pvalSlider").val());
        var fc   = parseFloat($("#fcSlider").val());
        var ct   = $("#cellTypeSelect").val();
        var hidePs = $("#hidePseudogenes").is(":checked");
        $("#pvalLabel").text(pval.toFixed(3).replace(/0+$/, "").replace(/\.$/, ""));
        $("#fcLabel").text(fc.toFixed(1));

        $.getJSON("condition-compare/result", {
            jobId: state.degJobId, pval: pval, fc: fc, cellType: ct,
        })
        .done(function (rows) {
            ensureDegTable();
            degTable.clear();
            (rows || []).forEach(function (r) {
                if (hidePs && isPseudogene(r.gene)) return;
                degTable.row.add([r.gene, r.logFC, r.pval, r.pval_adj, r.cell_type]);
            });
            degTable.draw();
        })
        .fail(function (xhr) {
            $("#runError").text("Failed to load DEG rows (" + xhr.status + ")").prop("hidden", false);
        });
    }

    function clearResults() {
        state.cellTypes = [];
        state.gseaJobId = null;
        hideDegResults();
        lockGsea();
        if (degTable) { degTable.clear().draw(); }
        $("#gseaChart").empty();
        if (gseaTable) { gseaTable.clear().draw(); }
        $("#gseaError").prop("hidden", true);
        $("#runSummary").prop("hidden", true).empty();
        $("#exportDegBtn").prop("disabled", true);
        $("#exportGseaBtn").prop("disabled", true);
        $("#gseaCellTypeSelect").prop("disabled", true).empty();
        $("#runGseaBtn").prop("disabled", true);
    }

    // -------- GSEA ------------------------------------------------------------
    var gseaTable = null;
    function ensureGseaTable() {
        if (gseaTable) return;
        gseaTable = $("#gseaTable").DataTable({
            paging: true, searching: true, info: true, order: [[1, "desc"]],
            columnDefs: [
                { targets: [1, 2, 3], className: "dt-right" },
                {
                    targets: 1,
                    render: function (v) { return (typeof v === "number") ? v.toFixed(3) : v; }
                },
                {
                    targets: [2, 3],
                    render: function (v) {
                        if (v === null || v === undefined) return "";
                        return (Math.abs(v) < 1e-3) ? v.toExponential(2) : v.toFixed(4);
                    }
                },
                { targets: 4, render: function (v) { return v ? v.substring(0, 160) + (v.length > 160 ? "…" : "") : ""; } },
            ],
        });
    }

    function runGsea() {
        if (!state.degJobId) return;
        var ct  = $("#gseaCellTypeSelect").val();
        var gmt = $("#gseaGmtSelect").val();
        if (!ct || !gmt) return;

        $("#gseaError").prop("hidden", true);
        $("#gseaProgress").prop("hidden", false);
        $("#gseaProgressText").text("Running pre-ranked GSEA…");
        $("#runGseaBtn").prop("disabled", true);
        $("#gseaChart").empty();
        if (gseaTable) gseaTable.clear().draw();

        $.ajax({
            url: "condition-gsea", method: "POST",
            contentType: "application/json",
            data: JSON.stringify({ jobId: state.degJobId, cellType: ct, gmtFile: gmt }),
        })
        .done(function (resp) {
            state.gseaJobId = resp.jobId;
            pollGseaStatus();
        })
        .fail(function (xhr) {
            $("#gseaProgress").prop("hidden", true);
            $("#gseaError").text("Failed to start GSEA (" + xhr.status + ")").prop("hidden", false);
            $("#runGseaBtn").prop("disabled", false);
        });
    }

    // Hard cap how long the frontend will wait for the upstream GSEA service
    // before declaring the job stalled. Without this we have observed jobs
    // appearing to hang at 30 % when the prerank step degenerates on tied ranks.
    var GSEA_POLL_INTERVAL_MS  = 2000;
    var GSEA_POLL_MAX_TICKS    = 180;          // 180 * 2s = 6 min ceiling
    var gseaPollTicks = 0;

    function pollGseaStatus() {
        if (!state.gseaJobId) return;
        $.getJSON("condition-gsea/status", { jobId: state.gseaJobId })
            .done(function (s) {
                if (s.state === "done") {
                    $("#gseaProgress").prop("hidden", true);
                    $("#runGseaBtn").prop("disabled", false);
                    gseaPollTicks = 0;
                    loadGsea();
                } else if (s.state === "error") {
                    $("#gseaProgress").prop("hidden", true);
                    $("#gseaError").text("GSEA failed: " + (s.error || "unknown")).prop("hidden", false);
                    $("#runGseaBtn").prop("disabled", false);
                    gseaPollTicks = 0;
                } else {
                    gseaPollTicks++;
                    if (gseaPollTicks > GSEA_POLL_MAX_TICKS) {
                        $("#gseaProgress").prop("hidden", true);
                        $("#gseaError")
                            .text("GSEA appears to be stalled (no progress for "
                                  + Math.round(GSEA_POLL_MAX_TICKS * GSEA_POLL_INTERVAL_MS / 60000)
                                  + " min). Try a smaller library, a more populated cell type, "
                                  + "or contact the maintainer.")
                            .prop("hidden", false);
                        $("#runGseaBtn").prop("disabled", false);
                        gseaPollTicks = 0;
                        return;
                    }
                    $("#gseaProgressText").text("Running GSEA… " + (s.progress || 0) + "%"
                                               + (s.phase ? " · " + s.phase : ""));
                    setTimeout(pollGseaStatus, GSEA_POLL_INTERVAL_MS);
                }
            })
            .fail(function (xhr) {
                $("#gseaProgress").prop("hidden", true);
                $("#gseaError").text("GSEA status failed (" + xhr.status + ")").prop("hidden", false);
                $("#runGseaBtn").prop("disabled", false);
                gseaPollTicks = 0;
            });
    }

    function loadGsea() {
        if (!state.gseaJobId) return;
        var topN = parseInt($("#gseaTopN").val() || "20", 10);
        var dir  = $("#gseaDirection").val() || "all";
        $.getJSON("condition-gsea/result", { jobId: state.gseaJobId, topN: topN, direction: dir })
            .done(function (rows) {
                renderGseaChart(rows || []);
                renderGseaTable(rows || []);
            })
            .fail(function (xhr) {
                $("#gseaError").text("GSEA result load failed (" + xhr.status + ")").prop("hidden", false);
            });
    }

    // Truncate very long term labels for axis ticks; full term goes into hover.
    function _shortTerm(t, max) {
        if (!t) return "";
        return t.length > max ? t.substr(0, max - 1) + "…" : t;
    }

    function renderGseaChart(rows) {
        if (!rows.length) {
            Plotly.purge("gseaChart");
            $("#gseaChart").html(
              '<div class="panel-empty" style="min-height:320px;">' +
              '<p class="panel-empty__text">No enriched terms for the chosen top-N / direction.</p>' +
              '</div>');
            $("#exportGseaBtn").prop("disabled", true);
            return;
        }
        // Sort so the largest |NES| is at the top of the bar chart.
        var sorted = rows.slice().sort(function (a, b) {
            return Math.abs(a.nes || 0) - Math.abs(b.nes || 0);
        });
        var fullY = sorted.map(function (r) { return r.term; });
        var y = fullY.map(function (t) { return _shortTerm(t, 48); });
        var x = sorted.map(function (r) { return r.nes; });
        // Homepage colour language: coral for Up in A, navy for Down in A.
        var colors = sorted.map(function (r) { return (r.nes || 0) >= 0 ? "#e8927c" : "#1a2332"; });
        var hover  = sorted.map(function (r) {
            return "<b>" + r.term + "</b><br>NES: " + (r.nes || 0).toFixed(3) +
                   "<br>p: " + ((r.pval === null || r.pval === undefined) ? "NA" : r.pval.toExponential(2)) +
                   "<br>FDR: " + ((r.fdr === null || r.fdr === undefined) ? "NA" : r.fdr.toExponential(2));
        });
        var trace = {
            type: "bar", orientation: "h",
            x: x, y: y, marker: { color: colors },
            hoverinfo: "text", hovertext: hover,
        };

        // Width: pin the inner Plotly canvas to the wrapper width but never let
        // it shrink below a usable minimum so the wrapper can scroll horizontally
        // when the panel is narrow. Long term labels trigger a wider canvas.
        var wrapper = document.querySelector(".gsea-chart-scroll");
        var availW  = wrapper ? wrapper.clientWidth : 800;
        var maxLabel = Math.max.apply(null, y.map(function (t) { return (t || "").length; }));
        var leftMargin = Math.min(360, 12 + maxLabel * 6.4);
        var minCanvasW = Math.max(720, leftMargin + 360);
        var canvasW = Math.max(availW - 4, minCanvasW);

        var layout = {
            width: canvasW,
            margin: { l: leftMargin, r: 30, t: 20, b: 50 },
            xaxis: { title: "NES", zeroline: true, zerolinecolor: "#d1c9bd" },
            yaxis: { automargin: true, tickfont: { size: 11, family: "Montserrat, sans-serif" } },
            height: Math.max(340, 22 * y.length + 80),
            plot_bgcolor: "#fff", paper_bgcolor: "#fff",
            font: { family: "Montserrat, sans-serif", color: "#1a2332" },
        };
        // Enable the modebar so users can pan/zoom/save when terms are long.
        var baseConfig = {
            displayModeBar: true,
            responsive: false,        // wrapper handles horizontal scroll
            displaylogo: false,
            modeBarButtonsToRemove: ["lasso2d", "select2d", "autoScale2d"],
        };
        // High-res PNG / vector PDF download buttons (figure-export.js).
        var fname = "compare_GSEA_" + (state.species || "");
        var config = window.FigureExport ? window.FigureExport.config(fname, baseConfig) : baseConfig;
        Plotly.newPlot("gseaChart", [trace], layout, config);
    }

    function renderGseaTable(rows) {
        ensureGseaTable();
        gseaTable.clear();
        rows.forEach(function (r) {
            gseaTable.row.add([r.term, r.nes, r.pval, r.fdr, r.leading || ""]);
        });
        gseaTable.draw();
        $("#exportGseaBtn").prop("disabled", !rows.length);
    }

    // -------- Export ----------------------------------------------------------
    function exportDegToExcel() {
        if (!degTable) return;
        var data = [["Gene", "log2FC", "p-value", "Adj. p", "Cell type"]];
        degTable.rows({ search: "applied" }).every(function () { data.push(this.data()); });
        var ws = XLSX.utils.aoa_to_sheet(data);
        var wb = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(wb, ws, "DEG");
        var name = "condition_DEG_" + state.species + "_" +
                   ($("#conditionA option:selected").text() || "A").replace(/\W+/g, "_") + "_vs_" +
                   ($("#conditionB option:selected").text() || "B").replace(/\W+/g, "_") + ".xlsx";
        XLSX.writeFile(wb, name);
    }

    // Export the (filtered) GSEA results table to Excel. Mirrors exportDegToExcel
    // -- also respects the user's current DataTable filter so a Filter:-search
    // narrows the export.
    function exportGseaToExcel() {
        if (!gseaTable) return;
        var data = [["Term", "NES", "p-value", "FDR", "Leading edge"]];
        gseaTable.rows({ search: "applied" }).every(function () {
            var d = this.data();
            // DataTable cells may carry numeric NaN/null; coerce to plain text.
            data.push([
                d[0] || "",
                (d[1] === null || d[1] === undefined || isNaN(d[1])) ? "" : d[1],
                (d[2] === null || d[2] === undefined || isNaN(d[2])) ? "" : d[2],
                (d[3] === null || d[3] === undefined || isNaN(d[3])) ? "" : d[3],
                d[4] || ""
            ]);
        });
        var ws = XLSX.utils.aoa_to_sheet(data);
        var wb = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(wb, ws, "GSEA");
        var safeCt  = ($("#gseaCellTypeSelect option:selected").text() || "celltype")
                        .replace(/\W+/g, "_");
        var safeLib = ($("#gseaGmtSelect option:selected").text() || "library")
                        .replace(/\W+/g, "_");
        var name = "condition_GSEA_" + state.species + "_" + safeCt + "_" + safeLib + ".xlsx";
        XLSX.writeFile(wb, name);
    }

    // -------- Wiring ----------------------------------------------------------
    $(function () {
        loadConditions();
        loadGmtCatalog();

        $('input[name="species"]').on("change", function () {
            state.species = $(this).val();
            clearResults();
            loadConditions();
            loadGmtCatalog();
        });

        $("#conditionA, #conditionB").on("change", updateRunBtn);
        $("#runBtn").on("click", runCompare);

        $("#pvalSlider, #fcSlider, #cellTypeSelect, #hidePseudogenes")
            .on("input change", function () {
                if (state.degJobId) loadDeg();
            });

        $("#runGseaBtn").on("click", runGsea);
        $("#gseaTopN, #gseaDirection").on("change", function () {
            if (state.gseaJobId) loadGsea();
        });
        // Changing cell type or library means a different job.
        $("#gseaCellTypeSelect, #gseaGmtSelect").on("change", function () {
            state.gseaJobId = null;
            Plotly.purge("gseaChart");
            $("#gseaChart").empty();
            if (gseaTable) gseaTable.clear().draw();
            $("#exportGseaBtn").prop("disabled", true);
        });

        $("#exportDegBtn").on("click", exportDegToExcel);
        $("#exportGseaBtn").on("click", exportGseaToExcel);

        // Re-fit the GSEA chart on viewport resize so the wrapper-driven width
        // stays in sync with the new layout.
        var _resizeT = null;
        $(window).on("resize", function () {
            if (_resizeT) clearTimeout(_resizeT);
            _resizeT = setTimeout(function () {
                if ($("#gseaChart").children().length &&
                    document.getElementById("gseaChart") &&
                    document.getElementById("gseaChart").layout) {
                    var wrapper = document.querySelector(".gsea-chart-scroll");
                    var availW  = wrapper ? wrapper.clientWidth : 800;
                    Plotly.relayout("gseaChart", { width: Math.max(availW - 4, 720) });
                }
            }, 150);
        });
    });
})();
