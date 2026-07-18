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
    var providerDisclosures = {
        openai: "OpenAI API data is not used for training by default; standard abuse-monitoring retention may apply unless eligible account controls are enabled.",
        claude: "Anthropic API retention follows your organization’s agreement; default retention and optional zero-data-retention arrangements may differ.",
        gemini: "Gemini handling differs between paid and unpaid services. Google Search grounding has additional processing and display requirements.",
        deepseek: "DeepSeek may process data in the People’s Republic of China and may use submitted content for model improvement under its current policy unless applicable controls are exercised."
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

    // Provider output is assigned only through text nodes. This deliberately
    // supports only the small Markdown subset needed by the response template.
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

    function safeHttpsUrl(value) {
        try {
            var parsed = new URL(String(value || ""), window.location.href);
            return parsed.protocol === "https:" ? parsed.href : "";
        } catch (error) {
            return "";
        }
    }

    function setBusy(card, busy, progress) {
        var run = card.querySelector("#aiInterpretRun");
        var loading = card.querySelector("#aiInterpretLoading");
        run.disabled = busy;
        loading.hidden = !busy;
        card.setAttribute("aria-busy", busy ? "true" : "false");
        if (progress) card.querySelector("#aiInterpretProgress").textContent = progress;
    }

    function showError(card, message) {
        var error = card.querySelector("#aiInterpretError");
        error.textContent = message;
        error.hidden = false;
    }

    function fetchJson(url, options) {
        return fetch(url, options || {}).then(function (response) {
            return response.json().catch(function () { return {}; }).then(function (data) {
                if (!response.ok) {
                    var problem = new Error(data.error || "The interpretation request failed.");
                    problem.status = response.status;
                    throw problem;
                }
                return data;
            });
        });
    }

    function renderContextSummary(card, context) {
        var container = card.querySelector("#aiContextSummary");
        container.replaceChildren();
        appendText(container, "strong", context.sampleAccession || card.dataset.said);
        appendText(container, "span", context.repository || "Exact sample record");
        var sampleUrl = safeHttpsUrl(context.sampleSourceUrl);
        if (sampleUrl) {
            var sampleLink = appendText(container, "a", "Repository record");
            sampleLink.href = sampleUrl;
            sampleLink.target = "_blank";
            sampleLink.rel = "noopener noreferrer";
        }
        if (context.hasVerifiedPrimaryPaper && context.publication) {
            appendText(container, "span", context.publication.title || "Verified primary publication");
            var paperUrl = context.publication.pmid
                ? "https://pubmed.ncbi.nlm.nih.gov/" + encodeURIComponent(context.publication.pmid) + "/"
                : "https://doi.org/" + encodeURIComponent(context.publication.doi || "");
            var paperLink = appendText(container, "a",
                context.publication.pmid ? "PMID " + context.publication.pmid : "DOI " + context.publication.doi);
            paperLink.href = paperUrl;
            paperLink.target = "_blank";
            paperLink.rel = "noopener noreferrer";
        } else {
            appendText(container, "span",
                "No verified primary publication — interpretation will not substitute an ambiguous paper.");
        }
    }

    function renderResult(card, result) {
        var panel = card.querySelector("#aiInterpretResult");
        var providerNames = {
            openai: "OpenAI",
            deepseek: "DeepSeek",
            claude: "Claude",
            gemini: "Gemini"
        };
        panel.querySelector(".ai-result__provider").textContent =
            (providerNames[result.provider] || result.provider) + " · " + result.model;
        panel.querySelector(".ai-result__time").textContent =
            new Date(result.generatedAt).toLocaleString();
        renderSafeMarkdown(panel.querySelector(".ai-result__content"), result.interpretation);

        var references = panel.querySelector(".ai-result__references");
        references.replaceChildren();
        var publication = result.publication || {};
        if (publication.status === "verified_primary") {
            var paperLink = document.createElement("a");
            paperLink.target = "_blank";
            paperLink.rel = "noopener noreferrer";
            paperLink.href = publication.pmid
                ? "https://pubmed.ncbi.nlm.nih.gov/" + encodeURIComponent(publication.pmid) + "/"
                : "https://doi.org/" + encodeURIComponent(publication.doi || "");
            paperLink.textContent = publication.pmid
                ? "Verified primary paper · PMID " + publication.pmid
                : "Verified primary paper · DOI " + publication.doi;
            references.appendChild(paperLink);
        } else {
            appendText(references, "span", "No verified primary publication was supplied.");
        }

        var sourceSection = panel.querySelector(".ai-result__web-sources");
        var sourceList = panel.querySelector(".ai-result__source-list");
        sourceList.replaceChildren();
        (result.webSources || []).forEach(function (source) {
            var url = safeHttpsUrl(source.url);
            if (!url) return;
            var row = document.createElement("div");
            var link = appendText(row, "a", source.title || url);
            link.href = url;
            link.target = "_blank";
            link.rel = "noopener noreferrer";
            var identity = source.pmid ? "PMID " + source.pmid
                : (source.doi ? "DOI " + source.doi : source.source || "");
            if (identity) appendText(row, "small", " · " + identity);
            sourceList.appendChild(row);
        });
        (result.searchSuggestions || []).forEach(function (query) {
            var row = document.createElement("div");
            appendText(row, "small", "Google Search suggestion · " + query);
            sourceList.appendChild(row);
        });
        sourceSection.hidden = !sourceList.childNodes.length;
        panel.hidden = false;
        panel.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }

    function delay(milliseconds) {
        return new Promise(function (resolve) { window.setTimeout(resolve, milliseconds); });
    }

    function pollJob(card, jobId) {
        var started = Date.now();
        function next() {
            var query = "?action=status&jobId=" + encodeURIComponent(jobId)
                + "&csrfToken=" + encodeURIComponent(card.dataset.csrf);
            return fetchJson(card.dataset.endpoint + query, {
                credentials: "same-origin",
                cache: "no-store"
            }).then(function (status) {
                setBusy(card, true, status.progress || "Generating interpretation…");
                if (status.status === "completed") {
                    return fetchJson(card.dataset.endpoint + "?action=result&jobId="
                        + encodeURIComponent(jobId) + "&csrfToken="
                        + encodeURIComponent(card.dataset.csrf), {
                        credentials: "same-origin",
                        cache: "no-store"
                    });
                }
                if (status.status === "failed") {
                    throw new Error(status.error || "The interpretation job failed.");
                }
                if (Date.now() - started > 20 * 60 * 1000) {
                    throw new Error("The interpretation is still running. Please try again shortly.");
                }
                return delay(1500).then(next);
            });
        }
        return next();
    }

    function init() {
        var card = document.getElementById("AIInterpretation");
        if (!card) return;
        var activate = card.querySelector("#aiInterpretActivate");
        var gate = card.querySelector("#aiPrivacyGate");
        var privacyConsent = card.querySelector("#aiPrivacyConsent");
        var publicationConsent = card.querySelector("#aiPublicationConsent");
        var workspace = card.querySelector("#aiInterpretWorkspace");
        var run = card.querySelector("#aiInterpretRun");
        var keyInput = card.querySelector("#aiProviderKey");
        var disclosure = card.querySelector("#aiProviderDisclosure");

        function updateConsentGate() {
            workspace.hidden = !(privacyConsent.checked && publicationConsent.checked);
            if (!workspace.hidden) keyInput.focus();
        }

        function updateProviderDisclosure() {
            var selected = card.querySelector('input[name="aiProvider"]:checked');
            disclosure.textContent = selected ? providerDisclosures[selected.value] || "" : "";
        }

        fetchJson(card.dataset.endpoint + "?action=context&said="
            + encodeURIComponent(card.dataset.said), {
            credentials: "same-origin",
            cache: "no-store"
        }).then(function (context) {
            renderContextSummary(card, context);
        }).catch(function (error) {
            card.querySelector("#aiContextSummary").textContent =
                error.message || "Sample context is temporarily unavailable.";
        });

        activate.addEventListener("click", function () {
            activate.closest(".ai-intro").hidden = true;
            gate.hidden = false;
            privacyConsent.focus();
        });
        privacyConsent.addEventListener("change", updateConsentGate);
        publicationConsent.addEventListener("change", updateConsentGate);
        card.querySelectorAll('input[name="aiProvider"]').forEach(function (input) {
            input.addEventListener("change", updateProviderDisclosure);
        });
        updateProviderDisclosure();

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

            if (!selected.length) {
                showError(card, "Select at least one ready analysis result."); return;
            }
            if (!providerInput) {
                showError(card, "Choose an LLM provider."); return;
            }
            if (key.length < 8) {
                showError(card, "Enter the API key for the selected provider."); return;
            }
            if (!privacyConsent.checked || !publicationConsent.checked) {
                showError(card, "Both consent confirmations are required."); return;
            }

            var payload = {
                said: card.dataset.said,
                provider: providerInput.value,
                consentVersion: card.dataset.consentVersion,
                privacyConsent: true,
                publicationRightsConfirmed: true,
                searchCurrentLiterature: card.querySelector("#aiSearchCurrentLiterature").checked,
                csrfToken: card.dataset.csrf,
                sources: selected
            };
            setBusy(card, true, "Queuing the full-paper interpretation…");
            var request = fetchJson(card.dataset.endpoint, {
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

            request.then(function (accepted) {
                return pollJob(card, accepted.jobId);
            }).then(function (result) {
                renderResult(card, result);
            }).catch(function (error) {
                showError(card, error.message || "The interpretation request failed.");
            }).finally(function () {
                setBusy(card, false);
            });
        });
    }

    window.ScsaidAIInterpretation = {
        publish: publish,
        renderSafeMarkdown: renderSafeMarkdown
    };
    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }
}());
