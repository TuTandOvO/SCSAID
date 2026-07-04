# scSAID literature registry

This directory is the source registry for publications associated with scSAID
datasets. It models the relationship as many-to-many: one study can support many
SAID datasets, and one dataset can be associated with more than one publication.

## Files

- `dataset_paper_index.tsv` — the requested dataset-level lookup table. One row
  represents one SAID-to-paper relation.
- `study_paper_index.tsv` — the same relations collapsed to study accession.
- `papers.tsv` — normalized paper catalogue.
- `registry.json` — application-friendly copy of the catalogue and links.
- `papers/PMID_<id>/metadata.json` — canonical metadata for one paper.
- `papers/PMID_<id>/README.md` — human-readable citation, source links, and
  related scSAID studies.
- `unresolved_studies.tsv` — studies for which no primary publication has yet
  been verified. Keeping these explicit prevents silent coverage gaps.
- `study_publication_overrides.json` — reviewed additions or relation corrections
  not present in the source workbook.

## Relation values

- `primary_dataset_publication` — paper reports generation of the dataset.
- `repository_linked_publication` — publication identifier is associated by the
  existing scSAID/GEO metadata, but generation was not independently asserted.
- `preprint` — preprint version of a primary publication.
- `correction` — published correction to a primary publication.

## Rebuild

Export the required PubMed records as XML, then run:

```sh
python3 literature/build_registry.py \
  --pubmed-xml /path/to/pubmed.xml \
  --verified-on YYYY-MM-DD
```

`AllData.xlsx` remains the canonical SAID/study/sample mapping. The build fails
if a referenced PMID is missing from the supplied XML.

Registry schema version 2 also includes one canonical metadata record per SAID
and author abstracts parsed from the supplied PubMed XML. Maven packages only
`registry.json` into the application classpath; the TSV files and per-paper
directories remain the human-auditable source registry.

## Full text policy

The repository stores paper records, citations, and stable official links. It
does not copy publisher PDFs. When PubMed Central provides open full text, the
paper record includes that URL. This keeps the registry copyright-safe and
prevents large binary files from inflating the application repository.
