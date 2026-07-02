# SCORPION regulatory-network analysis

Adds a **Gene Regulatory Network (SCORPION)** analysis to every dataset's
details page. For each dataset we reconstruct a transcription-factor → target
gene regulatory network (GRN) with
[SCORPION](https://github.com/kuijjerlab/SCORPION) and surface three views on
the site: the **master regulators**, a selected TF's **targetome**, and a
**regulator → target network** diagram.

## Why it is precomputed

SCORPION coarse-grains the full single-cell matrix and runs PANDA message
passing — minutes of compute and gigabytes of memory per dataset. A dataset's
network is a *static property*, so it is computed **once, offline** and the web
app only ever reads three small summary files. This mirrors how GSEA is
precomputed in this project (the servlet reads CSVs; it never runs the model).

## Method (what makes it rigorous)

SCORPION integrates three sources into one GRN via the PANDA framework:

| Input | Source | Notes |
|-------|--------|-------|
| Single-cell co-expression | the dataset's own `.h5ad` counts | genes × cells; SCORPION builds metacells internally |
| Regulatory prior (TF → target, `W0`) | **DoRothEA** (Garcia-Alonso et al., 2019), confidence A/B/C | curated regulons bundled in the `dorothea` package — no network needed |
| TF ↔ TF interactions | **STRING v12** (Szklarczyk et al., 2023) | combined score ≥ 700, rescaled to [0,1] |

The priors are species-level, so they are built **once per species** and reused
for every dataset of that species — which is what makes regulator rankings
comparable across datasets. Every run records its parameters and prior versions
in `meta.json` for reproducibility.

## Outputs (what the servlet serves)

Written next to each dataset at
`<dataRoot>/SCORPION/<species>/<GSE>/<GSM>/` (matrices are read from
`<dataRoot>/download_data/<species>/<GSE>/<GSM>/*.h5ad`):

- `tf_activity.csv` — `tf,out_degree,total_score,mean_weight,rank`
  (per-TF regulator ranking; `total_score` = summed positive edge weight).
- `tf_targets.csv` — `tf,target,weight` (top ~25 targets per TF).
- `meta.json` — provenance + parameters (`n_tfs`, `n_genes`, `n_cells`, prior
  versions, SCORPION version, run date, thresholds).

`ScorpionServlet` (`/scorpion`) reads only these files and returns JSON. If they
are absent the page shows a graceful "being prepared" message, so deploying the
UI before the pipeline has run is safe.

## How to run (on the server, where the data + R live)

```bash
# 1. install once
Rscript -e 'install.packages(c("scorpion","anndata","jsonlite","optparse","Matrix"))'
Rscript -e 'if (!requireNamespace("BiocManager", quietly=TRUE)) install.packages("BiocManager"); \
            BiocManager::install(c("dorothea","STRINGdb"))'
# anndata needs a Python with the `anndata` package (reticulate) — the project's
# scrna conda env already has it: reticulate::use_python(".../envs/scrna/bin/python")

# 2. build the species priors once
Rscript build_priors.R --species human --out /opt/SkinDB/SCORPION_priors
Rscript build_priors.R --species mouse --out /opt/SkinDB/SCORPION_priors

# 3. reconstruct every dataset's network (resumable; skips finished ones)
Rscript run_scorpion.R \
    --mapping /opt/tomcat/webapps/ROOT/WEB-INF/classes/mapping.csv.json \
    --data_root /opt/SkinDB \
    --priors /opt/SkinDB/SCORPION_priors \
    --cores 4

# single dataset / force recompute:
Rscript run_scorpion.R --mapping ... --said SAID001 --overwrite
```

`run_scorpion.R` derives each dataset's `.h5ad` path and its output directory
from `mapping.csv.json` (the same file the servlet uses), so the two never drift
apart. It is safe to re-run: datasets that already have a `meta.json` are skipped
unless `--overwrite` is given.

## Citation

Osorio D., et al. *SCORPION: single-cell oriented reconstruction of PANDA
individual optimized gene regulatory networks.* Kuijjer Lab.
Prior: DoRothEA (Garcia-Alonso et al., Genome Research 2019). Interactions: STRING v12.
