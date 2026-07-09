This guide describes the current scSAID interface, the steps required for each workflow, and the main limits on interpretation. Controls and results can differ by dataset when an input file or precomputed analysis is unavailable.

## Site navigation and global search

The fixed header provides the main routes:

- **Browse** opens the dataset catalogue.
- **Navigate → Search Marker** searches cell-type/sample marker results across datasets.
- **Navigate → Search DEG** searches condition/perturbation-versus-Healthy pseudobulk DEGs.
- **Navigate → Compare conditions** runs cross-condition pseudobulk differential expression and pre-ranked GSEA.
- **Navigate → Expression** overlays a gene on the integrated human or mouse UMAP.
- **Navigate → psoSpotter** opens the beta real-time biomarker-panel workflow.
- **Download** provides integrated atlases and metadata files.
- **Help** contains FAQ, methods, markers, pipeline, and this usage guide.
- **About** contains citation, release-note, privacy, and feedback pages.

### Search anything

The search box in the upper-right corner searches both functions and dataset identifiers.

1. Enter a function name such as `DEG`, `cell clustering`, `enrichment`, `communication`, or `gene set scoring`.
2. Alternatively, enter an exact `SAID`, `GSM`, or `GSE` accession.
3. Combine an accession with an analysis term to open that section directly. For example, `GSM8316003 CCC` resolves the dataset and opens its cell-cell communication section.
4. Select a suggestion with the pointer, or use the keyboard arrow keys and Enter.

The search returns at most the most relevant matches. A dataset accession must be present in scSAID to resolve to a Details page.

### Narrow screens

When the header collapses, use the menu button to open the navigation drawer. Expand **Navigate**, **Help**, or **About** to show their child routes. Press Escape, activate the close button, or select a destination to close the drawer.

## Home page

The Home page is the entry point to the atlas and its major workflows.

1. Use the primary navigation or page links to move to Browse, expression visualization, differential-expression search, comparisons, or downloads.
2. Use **Search anything** when the target dataset accession or analysis name is already known.
3. Treat site totals and summary counts as catalogue descriptions, not statistical results.

The **Home** header item is hidden while already on the Home page and appears on other pages.

## Browse datasets and integrate samples

Open [Browse datasets](../browse.jsp) to inspect the sample-level catalogue.

### Filter and sort

1. Filter by **Species**, **Condition**, and **Tissue**. Filters are combined.
2. Use **Clear Filters** to restore the complete catalogue.
3. Select a column heading to sort by SAID, GSE, GSM, species, cell count, condition, or tissue. Selecting the active heading again reverses the order.
4. Use the pagination controls to move between pages.
5. Select **View** in a row to open that sample’s Details page.

Each row represents one catalogued sample and reports its scSAID identifier, GEO study/sample accessions, species, number of cells, condition, and tissue. Metadata values reproduce the curated catalogue fields; they do not guarantee that two samples are directly comparable.

### Build an integrated UMAP selection

1. Select the checkbox for each dataset to include. Selections are retained in session storage while navigating between Browse pages.
2. Use the selection badge to confirm the total number selected.
3. Select at least two datasets, then activate **Integrate Selected**.
4. The integrated viewer opens with the selected SAIDs in the URL.
5. Use the controls supplied by the integrated viewer to inspect the combined embedding.
6. Use **Clear All** when the selection should be discarded.

Interpret an integrated UMAP as a visualization of the processed embedding. UMAP axes have no direct biological units; local neighborhoods are generally more informative than global distances, and apparent separation may reflect biology, study design, tissue site, technology, or integration behavior.

## Dataset Details page

Open a dataset through Browse or a direct `details.jsp?said=SAID...` link. The left analysis navigation moves between Overview, Cell Proportion, Cell Clustering, DEG Results, Gene Set Scoring, Cell-Cell Communication, Enrichment Analysis, Regulatory Network, and LLM Interpretation.

### Overview and study context

The dataset header reports SAID, GSE, GSM, species, tissue, condition, cell count, age, and sex when available. The study brief can include the GEO title, summary, overall design, and PubMed links.

Use these fields to check the experimental unit, cohort, body site, disease definition, technology, and study design before interpreting any downstream result. Missing metadata is shown as unavailable and should not be inferred from another sample in the study.

### Cell Proportion

1. Choose **Gross Map** for broad annotations or **Fine Map** for detailed cell types.
2. Read the bar chart for absolute cell counts.
3. Read the composition chart for relative proportions within the displayed sample.
4. Use the figure toolbar for PNG, PDF, or full-screen output when available.

Cell proportions are descriptive counts after the dataset’s processing and quality control. A higher displayed fraction is not, by itself, evidence of biological expansion: capture efficiency, dissociation, filtering, sampling depth, and annotation resolution can change the composition. Formal condition-level proportion testing requires biological replicates and an appropriate compositional model.

### Cell Clustering

1. Choose an available annotation or metadata field in **Color by**.
2. Inspect the sample UMAP and its legend.
3. Use hover information to identify cells or groups when supported.
4. Use **Download PDF** or the figure toolbar to export the current view.

UMAP is a nonlinear embedding. Cluster position, orientation, and axis values are arbitrary; proximity suggests similarity in the input representation but does not establish lineage or direct transition. Always interpret labels together with marker expression and study context.

### Differentially Expressed Genes

The initial table contains precomputed marker results for the sample. Columns report gene, log fold change, p-value, score, and cell type when those fields are available.

1. Inspect the default marker table or select another dataset in **Compare with**.
2. For an on-demand dataset comparison, choose the comparison dataset and activate **Run comparison**. Wait for the job status to complete.
3. Adjust **p-value threshold** to set the maximum adjusted p-value retained.
4. Adjust **Log fold change** to set the minimum effect-size threshold.
5. Select one cell type or keep all cell types.
6. Toggle **Hide pseudogenes** as required. The client-side filter recognizes common mouse pseudogene naming patterns such as `Gm` numbers, `-ps`, `Rik`, and `Pn` suffixes.
7. Sort or paginate the table.
8. Use **Export Excel** to save the filtered result.

Positive and negative fold changes must be interpreted using the contrast shown by the page. For precomputed cluster markers, the contrast is the indicated group against the remaining cells. For an on-demand dataset comparison, confirm which sample is treated as the reference. Statistical significance does not imply a large biological effect, and cells are not independent biological replicates for condition-level inference.

### Gene Set Scoring

Gene Set Scoring summarizes a user-defined or curated signature across cells and groups the resulting scores by annotation.

1. Choose an input mode:
   - **Custom Genes**: enter comma-separated gene symbols.
   - **MSigDB Library**: select a library, search the available sets, and select one set.
   - **Upload GMT**: upload a GMT file and select a parsed set. A GMT row contains a set name, description, and tab-separated genes.
2. Choose **Group By**: `Fine_Map` for detailed annotations or `Gross_Map` for broad annotations.
3. Choose a method: **AUCell**, **Scanpy score_genes**, **UCell**, **ssGSEA**, or **GSVA**.
4. Activate **Run Scoring** and wait for the violin plot.
5. Review the status line for the method, set name, genes found, genes not found, and grouping field.

The violin distributions show within-dataset score variation by annotation. Scores from different methods have different definitions and scales and should not be compared numerically as if equivalent. A high score indicates stronger representation of the submitted signature under the selected method; it does not prove pathway activation, regulatory causality, or cell identity. Check the matched-gene count and investigate whether the result is driven by a small subset of genes.

### Cell-Cell Communication

The CellPhoneDB workflow infers candidate ligand-receptor interactions between selected annotated populations.

1. Choose **All Combinations** to analyze every selected pair, or **Sender → Receiver** to define a directed comparison.
2. Choose **Fine_Map** or **Gross_Map** annotation resolution.
3. In All Combinations mode, select at least two cell types. **Select All** and **Clear** manage the list.
4. In directed mode, select sender populations and receiver populations separately.
5. Activate **Run Analysis** and wait for the queued job to finish.
6. Review:
   - **Interaction Heatmap** for aggregate communication patterns between population pairs.
   - **Dot Plot** for individual interaction strength and significance patterns.
   - **Results Table** for interaction pair, sender, receiver, mean expression, and p-value.
7. Use **Export Excel** to save the tabular results.

CellPhoneDB results are hypotheses based on ligand/receptor expression and the method’s interaction database and permutation framework. Mean expression is not a physical signaling rate, and a low p-value does not demonstrate contact, direction of protein transport, or functional response. Results are sensitive to annotation granularity, cell number, detection rate, and the selected sender/receiver sets.

### Enrichment Analysis

This section uses the sample’s differential-expression results as its source.

1. Choose **GSEA (ranked)** or **ORA (over-representation)**.
2. Choose a gene-set library.
3. Select a cell type when that control is available.
4. Choose the number of top results to display.
5. Choose **All results** or **Significant only**.
6. Inspect the enrichment chart and export the figure if required.

GSEA evaluates whether members of a set accumulate toward an end of the complete ranked gene list. ORA tests whether significantly up-regulated markers—adjusted p-value below 0.05 and log2 fold change at least 1 in the current implementation—are over-represented using a hypergeometric test. GSEA and ORA answer different questions and can disagree legitimately. Interpret normalized/enrichment scores together with adjusted significance, set size, gene overlap or leading-edge genes, and redundancy among related pathways.

### Gene Regulatory Network (SCORPION) — Beta

This beta section displays precomputed SCORPION/PANDA network summaries when they are available for the selected dataset.

1. In **Top TFs**, choose how many ranked regulators to display.
2. In **Targetome of TF**, select a transcription factor to view its leading predicted targets and edge weights.
3. Inspect the circular **Regulator → target network** for the leading TF-target subnetwork.
4. If the page reports that a network is being prepared, no precomputed SCORPION files are available for that dataset.

Regulators are ranked from network strength summaries such as total score and out-degree. Edges are predictions from single-cell co-expression combined with the CollecTRI regulatory prior and STRING v12 protein interactions through PANDA message passing. An edge is not evidence of direct binding, directionally validated regulation, or activity in an individual cell. Treat the network as prioritization for downstream validation.

### LLM Interpretation — Beta

This optional panel sends selected, already-loaded scSAID results and publication context to OpenAI, DeepSeek, Claude, or Gemini using your own provider API key.

1. Activate **LLM interpretation** and read the inline privacy statement.
2. Select the consent checkbox. The provider and API-key controls do not appear before consent.
3. Select one or more result sources marked **Ready**. A source becomes ready only after that result has loaded or run on the current page. UMAP images are not sent in this version.
4. Choose **OpenAI**, **DeepSeek**, **Claude**, or **Gemini** and enter the corresponding provider API key.
5. Activate **Generate interpretation**. The key field is cleared immediately after submission and must be entered again for another request.
6. Review the attributed response, linked paper identifiers, and the result-specific evidence sections.

The server constructs the prompt from the selected result snapshots, canonical SAID metadata, available linked-paper abstracts, GEO study summary/design, and a skin single-cell interpretation framework. The prompt is not displayed in the interface. The key is handled transiently for the single provider request and is not placed in application storage or logs. The scientific content sent to the provider and the provider response remain subject to that provider’s API data controls and your account settings; provider charges may apply.

LLM interpretation is a synthesis aid, not an additional statistical analysis. Verify every gene, pathway, direction, statistic, and citation against the displayed or downloaded source result. The model may conflate site-derived results with publication findings, overstate inferred communication or regulation, or produce unsupported biological explanations despite the prompt safeguards. Do not use the output for clinical decisions.

## Search markers across datasets

Open [Search Marker](../gene-search.jsp) to query all available marker files.

1. Enter a gene symbol or partial symbol. Matching is case-insensitive and based on substring matching.
2. Choose an autocomplete suggestion or activate **Search**.
3. Results are sorted by adjusted p-value and capped at 500 rows.
4. Read the dataset, GSE, marker group, log2 fold change, and adjusted p-value for each match.
5. Open **Dataset** to inspect the source analysis or **Gene Info** to open the gene page.
6. Select one or more unique genes and activate **Visualize on UMAP** to open the integrated expression visualization when available.

A result means the symbol occurred in an available marker result file; it is not a disease-versus-Healthy DEG and it is not a direct search of raw expression in every cell. Partial searches can match multiple gene families. Verify the exact symbol, species, marker group, effect direction, and adjusted p-value before using a row.

## Search condition DEGs across datasets

Open [Search DEG](../deg-search.jsp) to query cached condition/perturbation-versus-Healthy pseudobulk DEG results.

1. Choose **Human** or **Mouse**. The two species are searched separately to avoid mixing HUGO and MGI symbols.
2. Enter a gene symbol or partial symbol.
3. Optionally filter by condition, cell type, direction, adjusted p-value, absolute log2 fold change, and pseudogene visibility.
4. Results are sorted by adjusted p-value and capped at 500 rows.
5. Interpret log2 fold change as the selected disease, perturbation, or condition relative to **Healthy** within the same species and cell type.
6. Use **Compare** to open the broader condition comparison page, or **Gene Info** for the gene annotation page.

If the species-level DEG index is not ready, the page starts a background preparation step. The index is built from the existing pseudobulk DESeq2 comparison service by running every non-Healthy condition against Healthy. Biological samples are the replicates. Very small condition sample counts remain underpowered even when a row is statistically reported.

### Gene information page

The Gene Info page reports available identifiers, description, genomic location, biotype, strand, species, and links to external databases. It also provides actions to copy the symbol, share the page, print, or return to scSAID expression search.

External annotations are retrieved from external services and may be unavailable or updated independently of scSAID. Confirm identifiers and genome builds in the linked source before reporting them.

## Integrated Expression feature plot

Open [Expression](../featureplot.jsp) to overlay one gene on the integrated human or mouse skin atlas.

1. Choose **Human** or **Mouse**. The species preference is retained locally.
2. Enter a gene symbol and select an autocomplete result. Matching is case-insensitive.
3. The default view colors cells categorically by cell type. After gene selection, cells are recolored by expression and the legend reports the observed range.
4. Hover points to inspect UMAP coordinates, cell identity, and expression value.
5. Use **Clear gene** to restore cell-type coloring.
6. Use Plotly controls to zoom, pan, reset, export, or view full screen.
7. A `featureplot.jsp?gene=SYMBOL` link attempts to detect the species containing the gene and loads it directly.

The gene catalogue is restricted to genes available in the integrated visualization data. Grey or missing points indicate unavailable signal; zero or low values can reflect biological absence or technical dropout. Color scales describe the current gene and should not be compared visually between genes without checking their numeric ranges.

## Compare conditions in real time

Open [Compare conditions](../compare.jsp) for condition-level analysis within one species.

### Run pseudobulk differential expression

1. Choose **Human** or **Mouse**.
2. Select condition A and condition B. Only conditions with at least two samples are offered.
3. Treat condition A as the case and condition B as the reference when interpreting log2 fold change.
4. Review any advisory about disease-versus-disease contrasts or small sample numbers.
5. Activate **Run comparison** and wait for the asynchronous job.
6. Review the summary for sample counts, analyzed cell types, and cell types skipped for insufficient data.
7. Filter results by adjusted p-value, absolute fold change, cell type, and pseudogene visibility.
8. Search, sort, paginate, and export the DEG table.

The backend performs per-cell-type pseudobulk DESeq2, using biological samples—not individual cells—as replicates. Low replicate counts reduce power and stability. Disease-versus-disease comparisons without a shared healthy baseline may reflect tissue site, study, cohort, or batch differences in addition to disease biology.

### Run pre-ranked GSEA

1. Complete the DEG job first.
2. Select one analyzed cell type.
3. Choose an available gene-set library.
4. Choose the number of top pathways and the result direction.
5. Activate **Run GSEA** and wait for completion.
6. Inspect the chart and table, including normalized enrichment score, p-value, adjusted p-value, and leading-edge genes.
7. Export the GSEA table when required.

Genes are ranked using signed negative log10 adjusted p-value in the current workflow. Positive and negative enrichment follow the direction of the condition-A-versus-condition-B ranking. Highly tied, sparse, or underpowered rankings can produce unstable enrichment; inspect the DEG evidence and leading edge rather than reporting pathway names alone.

## psoSpotter beta workflow

Open [psoSpotter](../psospotter.jsp) to run biomarker-panel selection on uploaded AnnData files. This is a beta, resource-limited backend workflow.

### Prepare inputs

- Provide candidate gene symbols separated by commas, spaces, tabs, or new lines.
- Upload `.h5ad` or `.h5ad.gz` data.
- Raw counts must be stored in `layers["counts"]`.
- The quick-start lightbulb loads an example list; individual example chips append genes.

### Single-species mode

1. Choose **Single species**.
2. Choose Human or Mouse.
3. Choose a panel size from 5 to 50.
4. Enter candidate genes and upload one h5ad file.
5. Activate **Run psoSpotter**.

### Cross-species mode

1. Choose **Cross species**.
2. Choose Human → Mouse or Mouse → Human.
3. Choose the panel size and enter candidate genes.
4. Upload a training h5ad and a testing h5ad in the displayed direction.
5. Activate **Run psoSpotter**. The workflow uses the bundled Ensembl 116 human-mouse ortholog table.

### Queue, outputs, and retention

The server runs one psoSpotter job at a time and accepts a maximum of five active/queued jobs globally. One unfinished job is allowed per browser session. The live panel reports queue state, progress, messages, summary panels, tables, and metrics. Use **Download JSON** to retain the result or **Reset view** to clear the display.

Uploaded h5ad inputs are deleted after processing. A completed or failed job result is retained for 30 minutes and then removed. The worker has a 45-minute execution timeout. Form preferences and the previous candidate-gene input can remain in local browser preferences, but uploaded files are never restored automatically.

Selected panels are algorithmic priorities conditional on the supplied candidate set, preprocessing, labels, species mapping, and optimization settings. Validate performance on independent data and inspect class balance, expression prevalence, ortholog mapping, and failure modes before treating a panel as a biological or clinical biomarker set.

## Download Center

Open [Download](../download.jsp) for atlas objects and metadata.

### Integrated atlases

- **Human integrated atlas** and **Mouse integrated atlas** are distributed as AnnData `.h5ad` objects through Zenodo.
- Load an object in Python with `scanpy.read_h5ad` or another AnnData-compatible tool.
- Check object layers, observation fields, variable identifiers, and version metadata before analysis.

### Metadata and summary files

- **Browse Data**: Excel overview with SAID, accessions, species, condition, and tissue.
- **Complete Dataset**: comprehensive Excel metadata and experimental information.
- **Integration Table**: precomputed information used for cross-dataset integration and UMAP workflows.
- **Sample Metadata (CSV)**: flat UTF-8 metadata table for R or Python.

Downloaded resources can have different update dates. Record the file name, download date, scSAID release/version when supplied, and source study citations in reproducible analyses.

## Figure and table export

Plotly-based figures expose controls for high-resolution PNG, vector PDF, zoom/pan/reset, and full-screen display where supported. Some cards also provide explicit PDF or Excel buttons.

Before publication:

1. Confirm the active filters, species, annotation level, contrast, method, and selected gene set.
2. Prefer vector PDF for editable text and lines; use high-resolution PNG for raster workflows.
3. Check legends and axis labels after export.
4. Export the corresponding table when a figure depends on filtered results.
5. Record analysis parameters in the figure legend or methods.

## Help, About, privacy, and feedback

- **FAQ** answers common resource questions.
- **Methods** summarizes analysis definitions.
- **Markers** documents marker references used by the resource.
- **Pipeline** outlines data processing.
- **How to Cite** provides the scSAID citation and slots for method-specific references.
- **What’s New** records releases and reproducibility-relevant changes.
- **Privacy** explains first-party session cookies, visit-count protection, and locally saved interface preferences. It also provides a control to clear saved preferences.
- **Feedback** uses a verification step before revealing the submission form. Use it for corrections, reproducibility problems, missing datasets, broken analyses, or interface issues; include the URL, SAID/accession, inputs, expected behavior, and observed error.

scSAID does not use advertising or third-party tracking cookies. Clearing local preferences resets remembered interface choices but does not alter server-side source data.

## Interpretation and reproducibility checklist

For any result used in a report or publication, record:

1. Page and dataset identifier (`SAID`, `GSE`, and `GSM`).
2. Species, tissue/site, condition, cohort, technology, and biological replicate count.
3. Annotation level and cell populations included or excluded.
4. Analysis method and all thresholds, filters, libraries, gene sets, and comparison direction.
5. Whether results were precomputed or generated in real time.
6. Genes or cell types skipped because they were absent or insufficient.
7. Export date and resource/file versions.
8. scSAID, source dataset, method, and external database citations.

Use scSAID results as evidence within the limits of the underlying study design. Association, co-expression, enrichment, inferred communication, and predicted regulation do not establish causality. Where possible, reproduce key findings from downloaded data and validate them in independent samples or experiments.

## Troubleshooting

- **A page has no result:** verify the species, symbol, SAID, required selections, and whether the card reports that precomputed data are unavailable.
- **A real-time job remains queued:** another job may be running; keep the page open and monitor the status panel.
- **A job fails:** retry once with valid inputs, then report the URL, parameters, file type/size, time, and visible error through Feedback.
- **A gene is missing:** confirm the official species-specific symbol and whether the gene is present in the relevant processed matrix or DEG file.
- **A plot is crowded:** use full screen, reduce the number of displayed results, choose a broader annotation, or export PDF.
- **The interface remembers an unwanted option:** change it directly or clear saved preferences on the Privacy page.
- **A header or control covers content:** reload once to obtain the latest versioned styles; if it persists, report the browser, viewport size, URL, and screenshot.
