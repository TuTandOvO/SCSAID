<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="index,follow">
    <title>What’s New - scSAID</title>
    <meta name="description" content="A dated timeline of new analyses, datasets, interface improvements, and fixes released in scSAID.">
    <link rel="icon" type="image/x-icon" href="/favicon.ico?v=20260703a">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32.png?v=20260703a">
    <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png?v=20260703a">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:ital,wght@0,300;0,600;1,300&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="CSS/design-system.css?v=20260710c">
    <link rel="stylesheet" href="CSS/header.css?v=20260712a">
    <link rel="stylesheet" href="CSS/about-pages.css?v=20260716a">
</head>
<body>
    <%@ include file="includes/header.jsp" %>
    <main class="about-page changelog-page" id="main-content" tabindex="-1" aria-label="What’s New">
        <header class="about-page__header changelog-hero">
            <p class="changelog-hero__eyebrow">scSAID release notes</p>
            <h1>What’s New</h1>
            <p class="about-page__intro">Follow the development of scSAID through dated releases, scientific-analysis additions, interface refinements, and fixes.</p>
            <p class="changelog-hero__updated">Last updated <time datetime="2026-07-16">16 July 2026</time></p>
        </header>

        <div class="changelog-layout">
            <aside class="changelog-timeline" aria-label="Release timeline">
                <p class="changelog-timeline__label">Timeline</p>
                <nav class="changelog-timeline__nav" aria-label="Jump to a release date">
                    <ol>
                        <li><a href="#release-2026-07-16" class="is-active" aria-current="true"><span>16 Jul</span><small>Data accuracy</small></a></li>
                        <li><a href="#release-2026-07-11"><span>11 Jul</span><small>Expression</small></a></li>
                        <li><a href="#release-2026-07-10"><span>10 Jul</span><small>Reliability</small></a></li>
                        <li><a href="#release-2026-07-09"><span>09 Jul</span><small>Gene search</small></a></li>
                        <li><a href="#release-2026-07-05"><span>05 Jul</span><small>LLM providers</small></a></li>
                        <li><a href="#release-2026-07-04"><span>04 Jul</span><small>Interpretation</small></a></li>
                        <li><a href="#release-2026-07-03"><span>03 Jul</span><small>Navigation</small></a></li>
                        <li><a href="#release-2026-07-02"><span>02 Jul</span><small>Context help</small></a></li>
                        <li><a href="#release-2026-07-01"><span>01 Jul</span><small>New design</small></a></li>
                        <li><a href="#release-2026-06-30"><span>30 Jun</span><small>Analysis tools</small></a></li>
                        <li><a href="#release-2026-06-29"><span>29 Jun</span><small>Expression UMAP</small></a></li>
                        <li><a href="#release-2026-06-24"><span>24 Jun</span><small>Design system</small></a></li>
                    </ol>
                </nav>
            </aside>

            <div class="changelog-feed">
                <section class="release" id="release-2026-07-16" aria-labelledby="release-title-2026-07-16" data-release>
                    <header class="release__header">
                        <div>
                            <p class="release__month">July 2026</p>
                            <h2 class="release__date" id="release-title-2026-07-16"><time datetime="2026-07-16">16 July</time></h2>
                        </div>
                        <span class="release__latest">Latest</span>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--fixed">Data fix</p>
                        <h3>Post-QC cell totals across every dataset</h3>
                        <p>The cell count shown in dataset summaries now comes from the post-quality-control cells represented in each dataset’s Cell Proportion analysis. This removes discrepancies between pre-QC metadata and analysis-ready data.</p>
                        <ul>
                            <li>Verified all 252 human and mouse datasets against their analysis-ready AnnData objects.</li>
                            <li>Corrected 246 dataset totals while preserving all other metadata.</li>
                            <li>Added an automatic deployment check so summary counts remain synchronized with future data updates.</li>
                        </ul>
                    </article>
                </section>

                <section class="release" id="release-2026-07-11" aria-labelledby="release-title-2026-07-11" data-release>
                    <header class="release__header">
                        <h2 class="release__date" id="release-title-2026-07-11"><time datetime="2026-07-11">11 July</time></h2>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--new">New</p>
                        <h3>Condition-aware Expression explorer</h3>
                        <p>The Expression page can now focus an integrated UMAP by species and biological condition while visualizing a selected gene. Dataset and condition context remain visible with the expression overlay, making cross-condition inspection clearer without separating the views.</p>
                    </article>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--improved">Improved</p>
                        <h3>Cleaner analysis controls and result regions</h3>
                        <ul>
                            <li>Centered the Expression controls and removed the unnecessary outer filter-panel border.</li>
                            <li>Simplified the filter set by removing the dataset selector, leaving species, condition, and gene as the primary dimensions.</li>
                            <li>Removed redundant outer borders around Search Marker and Search DEG results.</li>
                        </ul>
                    </article>
                </section>

                <section class="release" id="release-2026-07-10" aria-labelledby="release-title-2026-07-10" data-release>
                    <header class="release__header">
                        <h2 class="release__date" id="release-title-2026-07-10"><time datetime="2026-07-10">10 July</time></h2>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--fixed">Reliability</p>
                        <h3>Faster, resumable condition-DEG preparation</h3>
                        <p>The condition-versus-Healthy DEG index is prepared as a server-side dataset rather than in a user’s browser. Preparation can resume after interruption, completed contrasts are retained, and the public page no longer exposes internal cache status.</p>
                    </article>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--fixed">Fixed</p>
                        <h3>CellPhoneDB production analysis</h3>
                        <p>Corrected servlet registration, production health detection, and the CellPhoneDB API contract so communication analyses use the deployed service consistently.</p>
                    </article>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--improved">Improved</p>
                        <h3>Consistent controls and safer analysis requests</h3>
                        <ul>
                            <li>Standardized two-option toggles across species, annotation-level, and sender–receiver controls with equal responsive halves and smooth state transitions.</li>
                            <li>Added expandable multi-cell-type marker labels and sortable fold-change and adjusted-p columns.</li>
                            <li>Bound resource-intensive analysis requests and hardened public endpoints against malformed or excessive input.</li>
                            <li>Refined download cards, page heroes, labels, icons, and table details for clearer visual consistency.</li>
                        </ul>
                    </article>
                </section>

                <section class="release" id="release-2026-07-09" aria-labelledby="release-title-2026-07-09" data-release>
                    <header class="release__header">
                        <h2 class="release__date" id="release-title-2026-07-09"><time datetime="2026-07-09">9 July</time></h2>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--new">New</p>
                        <h3>Search Marker and Search DEG are now distinct workflows</h3>
                        <p>Cell-type marker lookup is now named <strong>Search Marker</strong>. A separate <strong>Search DEG</strong> page searches cached pseudobulk DESeq2 results for non-Healthy conditions versus Healthy, per cell type and species.</p>
                    </article>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--fixed">Fixed</p>
                        <h3>More precise marker lookup</h3>
                        <ul>
                            <li>Gene symbols are case-sensitive and respect human uppercase and mouse title-case conventions.</li>
                            <li>Results identify the cell type or cell types for which each gene is a marker.</li>
                            <li>Empty result and downstream analysis panels remain hidden until the user submits a search or comparison.</li>
                        </ul>
                    </article>
                </section>

                <section class="release" id="release-2026-07-05" aria-labelledby="release-title-2026-07-05" data-release>
                    <header class="release__header">
                        <h2 class="release__date" id="release-title-2026-07-05"><time datetime="2026-07-05">5 July</time></h2>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--new">New</p>
                        <h3>Claude and Gemini support in LLM Interpretation <span class="main-nav__badge">beta</span></h3>
                        <p>Claude and Gemini joined OpenAI and DeepSeek as supported interpretation providers. The same explicit-consent and single-request API-key handling rules apply to every provider.</p>
                    </article>
                </section>

                <section class="release" id="release-2026-07-04" aria-labelledby="release-title-2026-07-04" data-release>
                    <header class="release__header">
                        <h2 class="release__date" id="release-title-2026-07-04"><time datetime="2026-07-04">4 July</time></h2>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--new">New</p>
                        <h3>LLM Interpretation on dataset detail pages <span class="main-nav__badge">beta</span></h3>
                        <p>Users can select one or more scSAID analysis outputs and request a structured scientific interpretation in the context of dataset metadata and linked publications.</p>
                        <ul>
                            <li>Provider API keys are accepted only after explicit privacy agreement, used for one request, and not stored in sessions, cookies, browser storage, databases, caches, or application logs.</li>
                            <li>The interpretation prompt separates site-derived observations, publication-reported findings, and biological hypotheses.</li>
                            <li>Scientific safeguards require cautious causal language, supplied PMID/DOI identifiers only, explicit limitations, and validation proposals.</li>
                        </ul>
                    </article>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--data">Data</p>
                        <h3>Dataset publication registry</h3>
                        <p>Added a structured paper directory and dataset-to-publication index to connect scSAID analyses with their original study context.</p>
                    </article>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--improved">Documentation</p>
                        <h3>Expanded project context</h3>
                        <p>Added the scSAID graphical abstract to the homepage, completed the About-page templates, expanded the usage guide, narrowed the mobile navigation drawer, and made SCORPION preparation status visible for networks not yet precomputed.</p>
                    </article>
                </section>

                <section class="release" id="release-2026-07-03" aria-labelledby="release-title-2026-07-03" data-release>
                    <header class="release__header">
                        <h2 class="release__date" id="release-title-2026-07-03"><time datetime="2026-07-03">3 July</time></h2>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--new">New</p>
                        <h3>psoSpotter gene-list analysis <span class="main-nav__badge">beta</span></h3>
                        <p>Added a real-time psoSpotter workflow for submitted gene lists, with temporary result retention and locally remembered previous input.</p>
                    </article>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--improved">Interface</p>
                        <h3>A shared visual language across the site</h3>
                        <ul>
                            <li>Reorganized the header into Navigate, Help, and About menus with self-hosted Phosphor Fill icons and a site-function search.</li>
                            <li>Aligned scientific result tables around a compact layout, alternating rows, restrained borders, and responsive overflow.</li>
                            <li>Made the SCORPION regulator, targetome, and circular network views more compact.</li>
                            <li>Added first-party preference persistence for shared widgets.</li>
                        </ul>
                    </article>
                </section>

                <section class="release" id="release-2026-07-02" aria-labelledby="release-title-2026-07-02" data-release>
                    <header class="release__header">
                        <h2 class="release__date" id="release-title-2026-07-02"><time datetime="2026-07-02">2 July</time></h2>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--improved">Interface</p>
                        <h3>Contextual help for expert workflows</h3>
                        <p>Long explanatory notes were moved behind clickable analysis titles with a restrained arrow treatment. Users can open concise method cards when needed without interrupting the default expert-facing interface.</p>
                    </article>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--fixed">Fixed</p>
                        <h3>Text encoding and deployment consistency</h3>
                        <p>Enforced UTF-8 across JSP responses to remove corrupted punctuation and symbols, and serialized production deployments to prevent overlapping releases. Regulatory Network was also marked clearly as a beta analysis.</p>
                    </article>
                </section>

                <section class="release" id="release-2026-07-01" aria-labelledby="release-title-2026-07-01" data-release>
                    <header class="release__header">
                        <h2 class="release__date" id="release-title-2026-07-01"><time datetime="2026-07-01">1 July</time></h2>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--new">New analysis</p>
                        <h3>SCORPION regulatory networks <span class="main-nav__badge">beta</span></h3>
                        <p>Introduced dataset-level gene-regulatory-network reconstruction using curated transcription-factor priors and optional protein–protein interaction context, with regulator and target exploration on detail pages.</p>
                    </article>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--improved">Redesign</p>
                        <h3>HumanBase-inspired scSAID interface</h3>
                        <ul>
                            <li>Introduced the Nunito-based light editorial design, scSAID blue accents, compact widgets, and consistent page structure.</li>
                            <li>Added a shared function-search bar to the header and repaired responsive layouts across mobile, tablet, laptop, wide, and short viewports.</li>
                            <li>Unified all loading states into one panel-centered circular indicator.</li>
                            <li>Restored Help content with a locally hosted Markdown renderer and expanded Methods, Pipeline, Markers, Usage, and FAQ documentation.</li>
                        </ul>
                    </article>
                </section>

                <section class="release" id="release-2026-06-30" aria-labelledby="release-title-2026-06-30" data-release>
                    <header class="release__header">
                        <div>
                            <p class="release__month">June 2026</p>
                            <h2 class="release__date" id="release-title-2026-06-30"><time datetime="2026-06-30">30 June</time></h2>
                        </div>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--new">Analysis</p>
                        <h3>Expanded enrichment and comparison workflows</h3>
                        <ul>
                            <li>Added over-representation analysis alongside pre-ranked GSEA in dataset detail pages.</li>
                            <li>Added live comparison-suitability guidance before real-time condition analysis.</li>
                            <li>Renamed Feature Plot to Expression for a clearer site-wide destination.</li>
                        </ul>
                    </article>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--improved">Export</p>
                        <h3>Publication-ready figures and improved gene entry</h3>
                        <p>Added high-resolution PNG and vector PDF downloads, full-screen result figures, real-time partial and typo-tolerant gene autocomplete, and fixes for autocomplete menus clipped by their parent cards.</p>
                    </article>
                </section>

                <section class="release" id="release-2026-06-29" aria-labelledby="release-title-2026-06-29" data-release>
                    <header class="release__header">
                        <h2 class="release__date" id="release-title-2026-06-29"><time datetime="2026-06-29">29 June</time></h2>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--new">New</p>
                        <h3>Integrated gene-expression UMAP</h3>
                        <p>Added a client-side gene-expression overlay for integrated scSAID atlases, replacing the external embedded application with a native page consistent with the rest of the site.</p>
                    </article>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--fixed">Fixed</p>
                        <h3>Clearer live-analysis states</h3>
                        <p>Removed result placeholders that appeared permanently queued, corrected empty bordered status strips, and refined spacing around the condition-comparison workflow.</p>
                    </article>
                </section>

                <section class="release" id="release-2026-06-24" aria-labelledby="release-title-2026-06-24" data-release>
                    <header class="release__header">
                        <h2 class="release__date" id="release-title-2026-06-24"><time datetime="2026-06-24">24 June</time></h2>
                    </header>
                    <article class="release-entry">
                        <p class="release-entry__type release-entry__type--improved">Foundation</p>
                        <h3>Shared design tokens and component states</h3>
                        <p>Introduced site-wide semantic colors, status colors, typography tokens, and shared button styling. Browse, dataset details, visualization, gene details, Download, Feedback, Help, and error pages were migrated to the same design foundation.</p>
                    </article>
                </section>
            </div>
        </div>
    </main>
    <script src="JS/whats-new.js?v=20260716a" defer></script>
</body>
</html>
