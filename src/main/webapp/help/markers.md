Cell types in scSAID were defined from marker genes, the genes most specific to each population. This page shows the top markers per broad cell type in each species.

## How cell types were defined
After integration and Leiden clustering, each cluster was tested for its most differentially expressed genes (Wilcoxon test, adjusted P < 0.05, log fold change > 0.5, detected in at least 10% of cells). Clusters were then labelled into broad types (`Gross_Map`) and fine types (`Fine_Map`) using these markers together with canonical lineage genes.

## How to read a dot plot
Each row is a cell type and each column is a gene. Dot size shows the fraction of cells in that type that express the gene, and dot color shows the mean expression across those cells. A large, dark dot means the gene is both widely and strongly expressed in that cell type, which makes it a good marker.

## Human broad cell types (top 3 markers each)

<figure class="help-pdf" style="margin:1.25rem 0;">
  <iframe src="/help/pdf/dotplot_DE_Human_Gross_Map_top3.pdf#view=FitH" title="Human broad cell-type markers"
          style="width:100%;height:62vh;min-height:460px;border:1px solid #e5e0d8;border-radius:12px;background:#fff;"></iframe>
  <figcaption style="font-size:.85rem;color:#5a6473;margin-top:.5rem;">
    Top 3 marker genes per human broad cell type (Gross_Map).
    <a href="/help/pdf/dotplot_DE_Human_Gross_Map_top3.pdf" target="_blank" rel="noopener">Open the PDF</a>.
  </figcaption>
</figure>

## Mouse broad cell types (top 3 markers each)

<figure class="help-pdf" style="margin:1.25rem 0;">
  <iframe src="/help/pdf/dotplot_DE_Mouse_Gross_Map_top3.pdf#view=FitH" title="Mouse broad cell-type markers"
          style="width:100%;height:62vh;min-height:460px;border:1px solid #e5e0d8;border-radius:12px;background:#fff;"></iframe>
  <figcaption style="font-size:.85rem;color:#5a6473;margin-top:.5rem;">
    Top 3 marker genes per mouse broad cell type (Gross_Map).
    <a href="/help/pdf/dotplot_DE_Mouse_Gross_Map_top3.pdf" target="_blank" rel="noopener">Open the PDF</a>.
  </figcaption>
</figure>
