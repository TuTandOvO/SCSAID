This guide walks through each part of the scSAID website and how to use it.

## Browse datasets
Open **Browse** to see every sample as a filterable table. Filter by species, condition, and tissue to narrow the list, then click a sample to open its **Details** page. Each row shows the sample identifier (SAID), study accession (GSE and GSM), species, condition, and cell count.

## Search a gene
Open **Search**, then type a gene symbol. Suggestions appear as you type and tolerate partial and misspelled input, so `Ap` suggests `APOE` and `Cok1a1` suggests `COL1A1`. Pick a suggestion or press Enter to see, across every dataset and cell population, whether the gene is up or down regulated and at what effect size. Click a result to open the dataset or the gene detail view.

## Expression on the UMAP
Open **Expression** to paint a gene onto the integrated UMAP. Choose the human or mouse atlas, then search a gene. Cells are colored by expression level, with a legend that shows the range and grey for cells with no signal. Hover a cell for its identity and value, use **Clear gene** to return to cell-type coloring, and use the chart toolbar to download or view full screen. Gene names are case-insensitive.

## Compare two conditions
Open **Compare** to contrast two conditions in one species. Pick a species and two conditions, then run the comparison. The site computes pseudobulk differential expression per cell type and a pre-ranked GSEA. Read the guidance note before you run: a disease against Healthy is the cleanest contrast, disease against disease can reflect skin region, cohort, or study differences because there is no shared baseline, and very small sample sizes are underpowered. The page flags these cases and still lets you run.

## Analyses on a dataset's Details page
From a **Details** page you can run several analyses on that sample:

- **Cell Proportion**: bar and donut charts of cell-type composition.
- **Cell Clustering**: the sample's UMAP colored by cluster or cell type.
- **DEG Results**: marker genes per cluster, filterable by significance and effect size, with Excel export.
- **Gene Set Scoring**: score a gene set across cells with AUCell.
- **Enrichment**: choose **GSEA** or **ORA** and a gene-set library. GSEA ranks the whole gene list; ORA tests the significant up-regulated markers for over-representation.
- **Cell-Cell Communication**: ligand-receptor signalling between cell types with CellPhoneDB, shown as a heatmap and dot plot.

## Download data
Open **Download** for metadata tables (dataset overview, full metadata, the integration table, and a sample CSV for R or Python) and for the full integrated single-cell atlases, which are deposited on Zenodo as AnnData (`.h5ad`) objects, one per species.

## Download any figure
Every chart has a toolbar. Use it to save a **high-resolution PNG**, a **vector PDF** with crisp text, or to open the figure **full screen** so dense plots are not squashed.
