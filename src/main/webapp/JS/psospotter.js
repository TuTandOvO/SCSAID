(function () {
    "use strict";

    var form = document.getElementById("psospotterForm");
    if (!form) return;

    var state = {
        jobId: null,
        pollTimer: null,
        lastResult: null,
        lastResultText: null
    };

    var els = {
        modeInputs: Array.prototype.slice.call(form.querySelectorAll('input[name="mode"]')),
        singleSpeciesCard: document.getElementById("singleSpeciesCard"),
        singleUploadCard: document.getElementById("singleUploadCard"),
        crossDirectionCard: document.getElementById("crossDirectionCard"),
        crossUploadCard: document.getElementById("crossUploadCard"),
        singleSpecies: document.getElementById("singleSpecies"),
        crossDirection: document.getElementById("crossDirection"),
        panelK: document.getElementById("panelK"),
        geneList: document.getElementById("geneList"),
        quickstartBtn: document.getElementById("quickstartBtn"),
        quickstartChips: document.getElementById("quickstartChips"),
        singleH5ad: document.getElementById("singleH5ad"),
        trainH5ad: document.getElementById("trainH5ad"),
        testH5ad: document.getElementById("testH5ad"),
        runBtn: document.getElementById("runBtn"),
        statusEmpty: document.getElementById("statusEmpty"),
        statusBody: document.getElementById("statusBody"),
        progressBar: document.getElementById("progressBar"),
        progressLabel: document.getElementById("progressLabel"),
        queueLabel: document.getElementById("queueLabel"),
        statusMessage: document.getElementById("statusMessage"),
        errorBox: document.getElementById("errorBox"),
        resultSummary: document.getElementById("resultSummary"),
        resultPanels: document.getElementById("resultPanels"),
        resultTables: document.getElementById("resultTables"),
        resultMetrics: document.getElementById("resultMetrics"),
        downloadJsonBtn: document.getElementById("downloadJsonBtn"),
        clearBtn: document.getElementById("clearBtn")
    };

    function preferences() {
        return window.ScsaidPreferences || null;
    }

    function currentMode() {
        for (var i = 0; i < els.modeInputs.length; i++) {
            if (els.modeInputs[i].checked) return els.modeInputs[i].value;
        }
        return "single";
    }

    function currentDirection() {
        return els.crossDirection.value === "mouse_to_human" ? "mouse_to_human" : "human_to_mouse";
    }

    function activeSpecies() {
        return els.singleSpecies.value === "mouse" ? "mouse" : "human";
    }

    function setVisible(el, visible) {
        if (!el) return;
        el.hidden = !visible;
    }

    function setDisabled(disabled) {
        els.runBtn.disabled = disabled;
        els.singleSpecies.disabled = disabled;
        els.crossDirection.disabled = disabled;
        els.panelK.disabled = disabled;
        els.geneList.disabled = disabled;
        els.singleH5ad.disabled = disabled;
        els.trainH5ad.disabled = disabled;
        els.testH5ad.disabled = disabled;
        for (var i = 0; i < els.modeInputs.length; i++) els.modeInputs[i].disabled = disabled;
    }

    function clearNode(node) {
        while (node.firstChild) node.removeChild(node.firstChild);
    }

    function card(label, value) {
        var item = document.createElement("div");
        item.className = "psospotter-summary__item";
        var lab = document.createElement("span");
        lab.className = "psospotter-summary__label";
        lab.textContent = label;
        var val = document.createElement("span");
        val.className = "psospotter-summary__value";
        val.textContent = value;
        item.appendChild(lab);
        item.appendChild(val);
        return item;
    }

    function metric(label, value) {
        var item = document.createElement("div");
        item.className = "psospotter-metric";
        var lab = document.createElement("span");
        lab.className = "psospotter-metric__label";
        lab.textContent = label;
        var val = document.createElement("span");
        val.className = "psospotter-metric__value";
        val.textContent = value;
        item.appendChild(lab);
        item.appendChild(val);
        return item;
    }

    function section(title) {
        var box = document.createElement("section");
        box.className = "psospotter-section";
        var heading = document.createElement("h3");
        heading.className = "psospotter-section__title";
        heading.textContent = title;
        box.appendChild(heading);
        return box;
    }

    function asNumber(value, digits) {
        if (value === null || value === undefined || value === "") return "n/a";
        var n = Number(value);
        if (!isFinite(n)) return String(value);
        if (digits === 0) return String(Math.round(n));
        if (Math.abs(n) >= 1000 || Math.abs(n) < 1e-4) return n.toExponential(2);
        return n.toFixed(digits || 3);
    }

    function showMessage(text, error) {
        els.statusMessage.textContent = text || "";
        els.statusMessage.hidden = !text;
        els.errorBox.textContent = error || "";
        els.errorBox.hidden = !error;
    }

    function setProgress(percent, label, queueText) {
        var value = Math.max(0, Math.min(100, Number(percent) || 0));
        els.progressBar.style.width = value + "%";
        els.progressLabel.textContent = label || (value >= 100 ? "Complete" : "Running");
        els.queueLabel.textContent = queueText || "";
    }

    function updateModeUi() {
        var mode = currentMode();
        var single = mode === "single";
        setVisible(els.singleSpeciesCard, single);
        setVisible(els.singleUploadCard, single);
        setVisible(els.crossDirectionCard, !single);
        setVisible(els.crossUploadCard, !single);
        if (preferences()) {
            preferences().set("psospotterMode", mode);
        }
    }

    function saveGeneText() {
        var prefs = preferences();
        if (prefs) prefs.set("psospotterGeneList", els.geneList.value);
    }

    function normalizeGenes(text) {
        return (text || "")
            .split(/[\s,;]+/)
            .map(function (gene) { return gene.trim(); })
            .filter(function (gene, index, arr) {
                return gene && arr.indexOf(gene) === index;
            });
    }

    function setGeneList(text) {
        els.geneList.value = text;
        saveGeneText();
    }

    function appendGene(gene) {
        var genes = normalizeGenes(els.geneList.value);
        if (genes.indexOf(gene) < 0) genes.push(gene);
        setGeneList(genes.join(", "));
        els.geneList.focus();
        els.geneList.setSelectionRange(els.geneList.value.length, els.geneList.value.length);
    }

    function loadExampleGenes() {
        setGeneList("KRT14, COL1A1, ACTA2, PECAM1, CD3E");
        els.geneList.focus();
    }

    function selectedFiles() {
        var mode = currentMode();
        if (mode === "single") {
            return { single: els.singleH5ad.files[0] || null };
        }
        return {
            train: els.trainH5ad.files[0] || null,
            test: els.testH5ad.files[0] || null
        };
    }

    function validate() {
        var genes = (els.geneList.value || "").trim();
        if (!genes) return "Enter a gene list first.";
        if (currentMode() === "single") {
            if (!selectedFiles().single) return "Upload one h5ad file.";
        } else {
            if (!selectedFiles().train || !selectedFiles().test) return "Upload both train and test h5ad files.";
        }
        return null;
    }

    function buildFormData() {
        var fd = new FormData();
        fd.append("mode", currentMode());
        fd.append("panelK", els.panelK.value);
        fd.append("targetTotal", "20000");
        fd.append("genes", els.geneList.value);
        if (currentMode() === "single") {
            fd.append("species", activeSpecies());
            fd.append("h5ad", selectedFiles().single);
        } else {
            var direction = currentDirection();
            var trainSpecies = direction === "human_to_mouse" ? "human" : "mouse";
            var testSpecies = direction === "human_to_mouse" ? "mouse" : "human";
            fd.append("species", trainSpecies);
            fd.append("trainSpecies", trainSpecies);
            fd.append("testSpecies", testSpecies);
            fd.append("trainH5ad", selectedFiles().train);
            fd.append("testH5ad", selectedFiles().test);
        }
        return fd;
    }

    function resetResults() {
        clearNode(els.resultSummary);
        clearNode(els.resultPanels);
        clearNode(els.resultTables);
        clearNode(els.resultMetrics);
        els.resultSummary.hidden = true;
        els.resultPanels.hidden = true;
        els.resultTables.hidden = true;
        els.resultMetrics.hidden = true;
        els.downloadJsonBtn.disabled = true;
        state.lastResult = null;
        state.lastResultText = null;
    }

    function renderSummary(payload) {
        var input = payload.input || {};
        var result = payload.result || {};
        var mode = payload.mode || currentMode();
        var summary = els.resultSummary;
        clearNode(summary);

        summary.appendChild(card("Mode", mode === "single" ? "Single species" : "Cross species"));
        if (mode === "single") {
            summary.appendChild(card("Species", input.species || activeSpecies()));
            summary.appendChild(card("Matched genes", String((input.matched_genes || []).length)));
            summary.appendChild(card("Cells retained", String(input.rows || "")));
        } else {
            summary.appendChild(card("Train species", input.train_species || "human"));
            summary.appendChild(card("Test species", input.test_species || "mouse"));
            summary.appendChild(card("Matched genes", String((input.matched_train_genes || []).length)));
            summary.appendChild(card("Cells retained", String((input.train_rows || 0) + " / " + (input.test_rows || 0))));
        }
        summary.appendChild(card("Panel size", String(((result.panel || []) && result.panel.length) || 0)));
        summary.appendChild(card("Requested genes", String((input.requested_genes || []).length)));

        summary.hidden = false;
    }

    function renderSingle(payload) {
        var result = payload.result || {};
        var panel = Array.isArray(result.panel) ? result.panel : [];
        var coeffs = Array.isArray(result.coefficients) ? result.coefficients : [];
        var stability = Array.isArray(result.stability) ? result.stability : [];
        var metrics = result.metrics || {};
        var pruning = result.pruning || {};

        var panelSection = section("Panel genes");
        var chips = document.createElement("div");
        chips.className = "psospotter-chip-list";
        panel.forEach(function (gene) {
            var chip = document.createElement("span");
            chip.className = "psospotter-chip";
            chip.textContent = String(gene);
            chips.appendChild(chip);
        });
        if (!panel.length) {
            var empty = document.createElement("p");
            empty.className = "psospotter-empty-note";
            empty.textContent = "No panel genes returned.";
            chips.appendChild(empty);
        }
        panelSection.appendChild(chips);

        var coeffSection = section("Coefficients");
        var coeffTable = document.createElement("table");
        coeffTable.className = "psospotter-table";
        coeffTable.appendChild(thead(["Feature", "Beta"]));
        var coeffBody = document.createElement("tbody");
        coeffs.forEach(function (row) {
            var tr = document.createElement("tr");
            tr.appendChild(td(row.feature));
            tr.appendChild(td(asNumber(row.beta, 4)));
            coeffBody.appendChild(tr);
        });
        coeffTable.appendChild(coeffBody);
        coeffSection.appendChild(coeffTable);

        var stabSection = section("Stability");
        var stabTable = document.createElement("table");
        stabTable.className = "psospotter-table";
        stabTable.appendChild(thead(["Gene", "Freq", "Consistency", "Mean |beta|"]));
        var stabBody = document.createElement("tbody");
        stability.slice(0, 25).forEach(function (row) {
            var tr = document.createElement("tr");
            tr.appendChild(td(row.gene));
            tr.appendChild(td(asNumber(row.selection_freq, 3)));
            tr.appendChild(td(asNumber(row.sign_consistency, 3)));
            tr.appendChild(td(asNumber(row.mean_abs_beta, 4)));
            stabBody.appendChild(tr);
        });
        stabTable.appendChild(stabBody);
        stabSection.appendChild(stabTable);

        var metricsSection = section("Metrics");
        var metricGrid = document.createElement("div");
        metricGrid.className = "psospotter-metric-grid";
        metricGrid.appendChild(metric("Train AUC", asNumber(metrics.train_auc, 3)));
        metricGrid.appendChild(metric("Test AUC", asNumber(metrics.test_auc, 3)));
        metricGrid.appendChild(metric("Train acc.", asNumber(metrics.train_acc, 3)));
        metricGrid.appendChild(metric("Test acc.", asNumber(metrics.test_acc, 3)));
        metricGrid.appendChild(metric("Calibration C", asNumber(payload.result.calibration_C, 5)));
        metricGrid.appendChild(metric("Pruned genes", String((pruning.kept_names || []).length || panel.length)));
        metricsSection.appendChild(metricGrid);

        clearNode(els.resultPanels);
        els.resultPanels.appendChild(panelSection);
        els.resultPanels.hidden = false;

        clearNode(els.resultTables);
        els.resultTables.appendChild(coeffSection);
        els.resultTables.appendChild(stabSection);
        els.resultTables.hidden = false;

        clearNode(els.resultMetrics);
        els.resultMetrics.appendChild(metricsSection);
        els.resultMetrics.hidden = false;
    }

    function renderCross(payload) {
        var result = payload.result || {};
        var panel = Array.isArray(result.panel) ? result.panel : [];
        var internal = result.internal || {};
        var external = result.external || {};
        var stability = Array.isArray(result.stability) ? result.stability : [];

        var panelSection = section("Mapped panel");
        var table = document.createElement("table");
        table.className = "psospotter-table";
        table.appendChild(thead(["Train gene", "Test gene"]));
        var body = document.createElement("tbody");
        panel.forEach(function (row) {
            var tr = document.createElement("tr");
            tr.appendChild(td(row.train_gene));
            tr.appendChild(td(row.test_gene));
            body.appendChild(tr);
        });
        table.appendChild(body);
        panelSection.appendChild(table);

        var stabSection = section("Stability");
        var stabTable = document.createElement("table");
        stabTable.className = "psospotter-table";
        stabTable.appendChild(thead(["Gene", "Freq", "Consistency", "Mean |beta|"]));
        var stabBody = document.createElement("tbody");
        stability.slice(0, 25).forEach(function (row) {
            var tr = document.createElement("tr");
            tr.appendChild(td(row.gene));
            tr.appendChild(td(asNumber(row.selection_freq, 3)));
            tr.appendChild(td(asNumber(row.sign_consistency, 3)));
            tr.appendChild(td(asNumber(row.mean_abs_beta, 4)));
            stabBody.appendChild(tr);
        });
        stabTable.appendChild(stabBody);
        stabSection.appendChild(stabTable);

        var metricsSection = section("Metrics");
        var metricGrid = document.createElement("div");
        metricGrid.className = "psospotter-metric-grid";
        metricGrid.appendChild(metric("Internal AUC", asNumber(internal.test_auc, 3)));
        metricGrid.appendChild(metric("Internal acc.", asNumber(internal.test_acc, 3)));
        metricGrid.appendChild(metric("External AUC", asNumber(external.auc, 3)));
        metricGrid.appendChild(metric("External acc.", asNumber(external.acc, 3)));
        metricGrid.appendChild(metric("Panel genes", String(panel.length)));
        metricsSection.appendChild(metricGrid);

        clearNode(els.resultPanels);
        els.resultPanels.appendChild(panelSection);
        els.resultPanels.hidden = false;

        clearNode(els.resultTables);
        els.resultTables.appendChild(stabSection);
        els.resultTables.hidden = false;

        clearNode(els.resultMetrics);
        els.resultMetrics.appendChild(metricsSection);
        els.resultMetrics.hidden = false;
    }

    function td(value) {
        var cell = document.createElement("td");
        cell.textContent = value === null || value === undefined ? "" : String(value);
        return cell;
    }

    function thead(headers) {
        var head = document.createElement("thead");
        var tr = document.createElement("tr");
        headers.forEach(function (label) {
            var th = document.createElement("th");
            th.textContent = label;
            tr.appendChild(th);
        });
        head.appendChild(tr);
        return head;
    }

    function downloadResult() {
        if (!state.lastResultText) return;
        var blob = new Blob([state.lastResultText], { type: "application/json;charset=utf-8" });
        var url = URL.createObjectURL(blob);
        var a = document.createElement("a");
        a.href = url;
        a.download = "psospotter-result.json";
        document.body.appendChild(a);
        a.click();
        a.remove();
        window.setTimeout(function () { URL.revokeObjectURL(url); }, 2000);
    }

    function stopPolling() {
        if (state.pollTimer) {
            window.clearTimeout(state.pollTimer);
            state.pollTimer = null;
        }
    }

    function pollStatus() {
        if (!state.jobId) return;
        fetch("psospotter/status?jobId=" + encodeURIComponent(state.jobId), {
            headers: { Accept: "application/json" }
        })
            .then(function (response) {
                if (response.status === 410) {
                    throw new Error("The result expired before it could be loaded.");
                }
                if (!response.ok) throw new Error("Status request failed.");
                return response.json();
            })
            .then(function (status) {
                if (status.progress !== undefined) {
                    setProgress(status.progress, status.message || status.status || "Running", status.queue ? "Queue: " + status.queue : "");
                }
                if (status.status === "succeeded") {
                    stopPolling();
                    loadResult();
                } else if (status.status === "failed") {
                    stopPolling();
                    setDisabled(false);
                    showMessage("Job finished.", status.error || "The run failed.");
                    setProgress(100, "Failed", "");
                } else {
                    state.pollTimer = window.setTimeout(pollStatus, 2000);
                }
            })
            .catch(function (error) {
                stopPolling();
                setDisabled(false);
                showMessage("", error.message || "Unable to read job status.");
            });
    }

    function loadResult() {
        if (!state.jobId) return;
        fetch("psospotter/result?jobId=" + encodeURIComponent(state.jobId), {
            headers: { Accept: "application/json" }
        })
            .then(function (response) {
                if (response.status === 410) throw new Error("The result expired after 30 minutes.");
                if (!response.ok) throw new Error("Result request failed.");
                return response.text();
            })
            .then(function (text) {
                state.lastResultText = text;
                state.lastResult = JSON.parse(text);
                setDisabled(false);
                showMessage("Job completed successfully.", "");
                setProgress(100, "Complete", "");
                renderSummary(state.lastResult);
                if (state.lastResult.mode === "cross") renderCross(state.lastResult);
                else renderSingle(state.lastResult);
                els.downloadJsonBtn.disabled = false;
            })
            .catch(function (error) {
                setDisabled(false);
                showMessage("", error.message || "Unable to load results.");
            });
    }

    function submitJob(event) {
        event.preventDefault();
        var validation = validate();
        if (validation) {
            showMessage("", validation);
            return;
        }

        resetResults();
        setDisabled(true);
        showMessage("Submitting job…", "");
        setProgress(5, "Submitting", "");

        fetch("psospotter", {
            method: "POST",
            body: buildFormData()
        })
            .then(function (response) {
                if (!response.ok) {
                    return response.json().catch(function () { return {}; }).then(function (payload) {
                        throw new Error(payload.error || ("Submission failed (" + response.status + ")"));
                    });
                }
                return response.json();
            })
            .then(function (payload) {
                state.jobId = payload.jobId;
                setVisible(els.statusEmpty, false);
                setVisible(els.statusBody, true);
                setProgress(0, "Queued", payload.queue ? "Queue: " + payload.queue : "");
                showMessage("Job queued.", "");
                pollStatus();
            })
            .catch(function (error) {
                setDisabled(false);
                showMessage("", error.message || "Failed to submit the job.");
                setProgress(0, "Queued", "");
                setVisible(els.statusEmpty, true);
                setVisible(els.statusBody, false);
            });
    }

    function bindEvents() {
        form.addEventListener("submit", submitJob);
        els.clearBtn.addEventListener("click", function () {
            stopPolling();
            state.jobId = null;
            setDisabled(false);
            resetResults();
            setVisible(els.statusEmpty, true);
            setVisible(els.statusBody, false);
            setProgress(0, "Queued", "");
            showMessage("", "");
        });
        els.downloadJsonBtn.addEventListener("click", downloadResult);
        els.modeInputs.forEach(function (input) {
            input.addEventListener("change", function () {
                updateModeUi();
            });
        });
        els.geneList.addEventListener("input", saveGeneText);
        els.singleSpecies.addEventListener("change", function () {
            var prefs = preferences();
            if (prefs) prefs.set("psospotterSpecies", els.singleSpecies.value);
        });
        els.crossDirection.addEventListener("change", function () {
            var prefs = preferences();
            if (prefs) prefs.set("psospotterDirection", els.crossDirection.value);
        });
        els.panelK.addEventListener("change", function () {
            var prefs = preferences();
            if (prefs) prefs.set("psospotterPanelK", els.panelK.value);
        });
        if (els.quickstartBtn) {
            els.quickstartBtn.addEventListener("click", loadExampleGenes);
        }
        if (els.quickstartChips) {
            var chips = els.quickstartChips.querySelectorAll("[data-gene]");
            for (var i = 0; i < chips.length; i++) {
                chips[i].addEventListener("click", function () {
                    appendGene(this.getAttribute("data-gene"));
                });
            }
        }
    }

    function restoreState() {
        var prefs = preferences();
        if (!prefs) return;
        var mode = prefs.get("psospotterMode", "single");
        var direction = prefs.get("psospotterDirection", "human_to_mouse");
        var species = prefs.get("psospotterSpecies", "human");
        var panelK = prefs.get("psospotterPanelK", "20");
        var geneList = prefs.get("psospotterGeneList", "");

        els.modeInputs.forEach(function (input) {
            input.checked = input.value === mode;
        });
        els.crossDirection.value = direction === "mouse_to_human" ? "mouse_to_human" : "human_to_mouse";
        els.singleSpecies.value = species === "mouse" ? "mouse" : "human";
        els.panelK.value = String(panelK);
        els.geneList.value = geneList || "";
        updateModeUi();
    }

    restoreState();
    bindEvents();
    updateModeUi();
    setVisible(els.statusEmpty, true);
    setVisible(els.statusBody, false);
    setProgress(0, "Queued", "");
})();
