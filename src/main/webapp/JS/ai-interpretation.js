(function () {
    "use strict";

    var sourceState = Object.create(null);
    var labels = {
        cell_proportion: "Cell proportion",
        deg: "Differentially expressed genes",
        gene_set_scoring: "Gene set scoring",
        cell_communication: "Cell-cell communication",
        enrichment: "Enrichment analysis",
        regulatory_network: "Regulatory network"
    };

    function clone(value) {
        try { return JSON.parse(JSON.stringify(value)); }
        catch (error) { return null; }
    }

    function publish(type, parameters, data) {
        if (!labels[type]) return;
        sourceState[type] = {
            type: type,
            parameters: clone(parameters || {}),
            data: clone(data == null ? {} : data)
        };
        var input = document.querySelector('[data-ai-source="' + type + '"]');
        if (!input) return;
        input.disabled = false;
        var item = input.closest(".ai-source");
        if (item) {
            item.classList.add("ai-source--ready");
            var status = item.querySelector(".ai-source__status");
            if (status) status.textContent = "Ready";
        }
    }

    function appendText(parent, tag, text, className) {
        var element = document.createElement(tag);
        if (className) element.className = className;
        element.textContent = text;
        parent.appendChild(element);
        return element;
    }

    // Purposefully small Markdown renderer. Every provider character is assigned
    // through textContent, so model output can never create executable markup.
    function renderSafeMarkdown(container, markdown) {
        container.replaceChildren();
        var lines = String(markdown || "").replace(/\r/g, "").split("\n");
        var paragraph = [];
        var list = null;
        var code = null;

        function flushParagraph() {
            if (!paragraph.length) return;
            appendText(container, "p", paragraph.join(" "));
            paragraph = [];
        }
        function closeList() { list = null; }
        function flushCode() {
            if (code === null) return;
            var pre = document.createElement("pre");
            appendText(pre, "code", code.join("\n"));
            container.appendChild(pre);
            code = null;
        }

        lines.forEach(function (line) {
            if (line.indexOf("```") === 0) {
                flushParagraph(); closeList();
                if (code === null) code = []; else flushCode();
                return;
            }
            if (code !== null) { code.push(line); return; }
            if (!line.trim()) { flushParagraph(); closeList(); return; }
            if (line.indexOf("### ") === 0) {
                flushParagraph(); closeList(); appendText(container, "h3", line.slice(4)); return;
            }
            if (line.indexOf("## ") === 0) {
                flushParagraph(); closeList(); appendText(container, "h2", line.slice(3)); return;
            }
            if (/^[-*] /.test(line)) {
                flushParagraph();
                if (!list) { list = document.createElement("ul"); container.appendChild(list); }
                appendText(list, "li", line.slice(2));
                return;
            }
            closeList();
            paragraph.push(line.trim());
        });
        flushParagraph();
        flushCode();
    }

    function setBusy(card, busy) {
        var run = card.querySelector("#aiInterpretRun");
        var loader = card.querySelector("#aiInterpretLoading");
        run.disabled = busy;
        loader.hidden = !busy;
        card.setAttribute("aria-busy", busy ? "true" : "false");
    }

    function showError(card, message) {
        var error = card.querySelector("#aiInterpretError");
        error.textContent = message;
        error.hidden = false;
    }

    function renderResult(card, result) {
        var panel = card.querySelector("#aiInterpretResult");
        var content = panel.querySelector(".ai-result__content");
        panel.querySelector(".ai-result__provider").textContent =
            (result.provider === "openai" ? "OpenAI" : "DeepSeek") + " · " + result.model;
        panel.querySelector(".ai-result__time").textContent = new Date(result.generatedAt).toLocaleString();
        renderSafeMarkdown(content, result.interpretation);

        var references = panel.querySelector(".ai-result__references");
        references.replaceChildren();
        (result.papers || []).forEach(function (paper) {
            var link = document.createElement("a");
            link.target = "_blank";
            link.rel = "noopener noreferrer";
            link.href = paper.pmid ? "https://pubmed.ncbi.nlm.nih.gov/" + encodeURIComponent(paper.pmid) + "/"
                : "https://doi.org/" + encodeURIComponent(paper.doi || "");
            link.textContent = paper.pmid ? "PMID " + paper.pmid : "DOI " + paper.doi;
            references.appendChild(link);
        });
        if (!references.childNodes.length) appendText(references, "span", "GEO study context used; no linked abstract was available.");
        panel.hidden = false;
        panel.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }

    function init() {
        var card = document.getElementById("AIInterpretation");
        if (!card) return;
        var activate = card.querySelector("#aiInterpretActivate");
        var gate = card.querySelector("#aiPrivacyGate");
        var consent = card.querySelector("#aiPrivacyConsent");
        var workspace = card.querySelector("#aiInterpretWorkspace");
        var run = card.querySelector("#aiInterpretRun");
        var keyInput = card.querySelector("#aiProviderKey");

        activate.addEventListener("click", function () {
            activate.closest(".ai-intro").hidden = true;
            gate.hidden = false;
            consent.focus();
        });
        consent.addEventListener("change", function () {
            workspace.hidden = !consent.checked;
            if (consent.checked) keyInput.focus();
        });
        card.querySelector("#aiInterpretReset").addEventListener("click", function () {
            card.querySelector("#aiInterpretResult").hidden = true;
            card.querySelector("#aiInterpretError").hidden = true;
            keyInput.focus();
        });

        run.addEventListener("click", function () {
            var selected = [];
            card.querySelectorAll("[data-ai-source]:checked").forEach(function (input) {
                if (sourceState[input.value]) selected.push(sourceState[input.value]);
            });
            var key = keyInput.value.trim();
            var providerInput = card.querySelector('input[name="aiProvider"]:checked');
            card.querySelector("#aiInterpretError").hidden = true;
            card.querySelector("#aiInterpretResult").hidden = true;

            if (!selected.length) { showError(card, "Select at least one ready analysis result."); return; }
            if (!providerInput) { showError(card, "Choose an LLM provider."); return; }
            if (key.length < 8) { showError(card, "Enter the API key for the selected provider."); return; }

            var payload = {
                said: card.dataset.said,
                provider: providerInput.value,
                consentVersion: card.dataset.consentVersion,
                csrfToken: card.dataset.csrf,
                sources: selected
            };
            setBusy(card, true);
            var request = fetch(card.dataset.endpoint, {
                method: "POST",
                credentials: "same-origin",
                cache: "no-store",
                headers: {
                    "Content-Type": "application/json",
                    "X-scSAID-Provider-Key": key
                },
                body: JSON.stringify(payload)
            });
            keyInput.value = "";
            key = null;

            request.then(function (response) {
                return response.json().catch(function () { return {}; }).then(function (data) {
                    if (!response.ok) throw new Error(data.error || "The interpretation request failed.");
                    return data;
                });
            }).then(function (result) {
                renderResult(card, result);
            }).catch(function (error) {
                showError(card, error.message || "The interpretation request failed.");
            }).finally(function () {
                setBusy(card, false);
            });
        });
    }

    window.ScsaidAIInterpretation = { publish: publish, renderSafeMarkdown: renderSafeMarkdown };
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
    else init();
}());
