This page shows the end-to-end workflow behind scSAID, from raw public data to the interactive site.

## Overview
scSAID follows one path per species:

1. **Collect and label.** Public droplet-based skin datasets are gathered from GEO and GSA, then labelled with species, condition, sex, age, and tissue site.
2. **Quality control.** Each sample is filtered on total counts, detected genes, and mitochondrial, ribosomal, and haemoglobin fractions, and likely doublets are removed with Scrublet.
3. **Integrate per species.** Samples are merged and integrated with scVI on 8,000 highly variable genes, correcting for batch and study, to give one shared latent space and UMAP per species.
4. **Annotate.** Leiden clusters are labelled into broad (`Gross_Map`) and fine (`Fine_Map`) cell types using differential expression and canonical markers.
5. **Analyse.** The integrated objects feed the site's analysis modes: gene expression on the UMAP, per-sample composition, differential expression, GSEA and ORA, gene-set scoring, and cell-cell communication.
6. **Serve.** A Java and Tomcat frontend calls a Python API that reads Zarr expression slices for visual requests and h5ad objects for numeric analyses, then returns results to the browser.

## Overview figure
The figure below summarises the same flow.

<figure class="help-pdf" style="margin:1.5rem 0;">
  <iframe src="/help/pdf/Fig1-overview.pdf#view=FitH" title="scSAID overview figure"
          style="width:100%;height:72vh;min-height:540px;border:1px solid #e5e0d8;border-radius:12px;background:#fff;"></iframe>
  <figcaption style="font-size:.85rem;color:#5a6473;margin-top:.5rem;">
    Figure 1. scSAID overview: data collection, per-species integration, annotation, and the analysis modes exposed on the website.
    <a href="/help/pdf/Fig1-overview.pdf" target="_blank" rel="noopener">Open the PDF</a>.
  </figcaption>
</figure>
