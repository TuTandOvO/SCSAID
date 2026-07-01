## What is scSAID?
scSAID is a single-cell atlas of skin. It brings public droplet-based skin scRNA-seq data from human and mouse into one integrated, queryable resource, with a web interface for browsing samples, viewing gene expression, comparing conditions, and running enrichment and cell-cell communication analyses.

## Which species and how much data are included?
Two species, human and mouse. The atlas holds 252 samples (133 human, 119 mouse) drawn from 49 studies (23 human, 26 mouse), integrated into over 1.2 million cells. Each species is integrated separately into its own shared space.

## Where does the data come from, and is it public?
All datasets are public. They were collected from the Gene Expression Omnibus (GEO) and the Genome Sequence Archive (GSA), reprocessed with one consistent workflow, and re-annotated with standardised metadata. Accession numbers are listed in the manuscript.

## How were cell types annotated?
Cells were clustered in the integrated space, and each cluster was labelled from its top differentially expressed genes together with canonical lineage markers. Two levels are provided: a broad level (`Gross_Map`) and a fine level (`Fine_Map`). See the Markers and Methods pages for details.

## How do I find whether my gene is differentially expressed?
Use **Search**. Type the gene symbol (partial and misspelled input is tolerated) and you will see, across every dataset and cell population, whether it is up or down regulated and at what effect size.

## How do I see a gene's expression on the UMAP?
Use **Expression**. Choose the human or mouse atlas and search a gene. The UMAP is colored by that gene's expression, with a legend and per-cell hover values. This is the fastest way to see which cell types express a gene.

## What does Compare do, and which comparisons are trustworthy?
**Compare** runs pseudobulk differential expression and pre-ranked GSEA between two conditions in one species, where samples are the statistical replicates. A disease against Healthy is the most interpretable contrast. Disease against disease has no shared baseline, so results can reflect skin region, cohort, or study batch, and comparisons with very few samples are underpowered. The page flags these cases before you run.

## GSEA or ORA: which should I use?
Both test pathway enrichment but answer different questions. GSEA ranks the whole gene list and asks whether a pathway is skewed toward the top or bottom. ORA takes the significant up-regulated markers and asks whether a pathway is over-represented among them, using a hypergeometric test. GSEA is sensitive to broad shifts, while ORA is easy to read when you care about the strong markers. Running both is reasonable.

## Can I download the data and figures, and under what license?
Yes. The Download page offers metadata tables and the full integrated atlases (AnnData `.h5ad`) on Zenodo, released under CC-BY-4.0. Every chart can be saved as a high-resolution PNG or a vector PDF, or opened full screen.

## How do I cite scSAID, and who do I contact?
Please cite the scSAID manuscript (in preparation) and this website, https://skin-scsaid.com. For questions or corrections, use the Feedback page.
