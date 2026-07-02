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
| Regulatory prior (TF → target, `W0`) | **CollecTRI** (Müller-Dott et al., 2023) via the OmniPath static export | curated TF→target pairs, species-cased symbols |
| TF ↔ TF interactions | **STRING v12** (Szklarczyk et al., 2023), score ≥ 700, via the STRING network API | self-loops added so every TF is retained (SCORPION intersects the TF set with the PPI) |

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

## How it was set up on the server

R is provided by a dedicated conda env (`/root/miniconda3/envs/scorpion`) with
`r-base`, **SCORPION** (installed from `kuijjerlab/SCORPION` — note the package
is named `SCORPION`, its function is `scorpion()`), `r-anndata` + a Python with
`anndata` (reticulate), and the deps `RANN`, `irlba`, `RSpectra`, `furrr`,
`RhpcBLASctl`, `matrixStats`.

```bash
# 1. build the two priors per species — run on ANY machine with internet
#    (the deployment host cannot reach omnipathdb.org / string-db.org), then
#    copy the four files to the server's --priors directory:
OUT=./SCORPION_priors ./build_priors.sh
scp SCORPION_priors/*.txt root@<server>:/opt/SkinDB/SCORPION_priors/

# 2. reconstruct every dataset's network (resumable; skips finished ones).
#    Run single-threaded workers in parallel with a virtual-memory backstop
#    (the box has 14 GB RAM, no swap, Tomcat ~4.7 GB):
export RETICULATE_PYTHON=/root/miniconda3/envs/scorpion/bin/python
grep -oE '"SAID[0-9]+"' /opt/tomcat/webapps/ROOT/WEB-INF/classes/mapping.csv.json \
  | tr -d '"' | sort -u \
  | xargs -P 3 -I{} bash -c '
      ulimit -v 12582912; export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
      /root/miniconda3/envs/scorpion/bin/Rscript run_scorpion.R \
        --mapping /opt/tomcat/webapps/ROOT/WEB-INF/classes/mapping.csv.json \
        --data_root /opt/SkinDB --priors /opt/SkinDB/SCORPION_priors --said {} --cores 1'

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
Prior: CollecTRI (Müller-Dott et al., 2023). Interactions: STRING v12 (Szklarczyk et al., 2023).
