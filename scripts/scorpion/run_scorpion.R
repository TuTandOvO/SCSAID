#!/usr/bin/env Rscript
# ==========================================================================
# run_scorpion.R  —  Per-dataset gene-regulatory-network reconstruction.
#
# For each SAID in mapping.csv.json this script:
#   1. reads the dataset's single-cell counts (.h5ad, genes x cells),
#   2. reconstructs a TF x gene regulatory network with SCORPION, using the
#      species-level priors from build_priors.R,
#   3. summarises the network into the three small files the website serves:
#         SCORPION/tf_activity.csv   per-TF regulator ranking
#         SCORPION/tf_targets.csv    top targets for every TF (the "targetome")
#         SCORPION/meta.json         provenance + parameters for reproducibility
#      written next to the dataset, i.e.
#         <dataRoot>/SkinDB_New/10X/<species>/<GSE>/<GSM>/SCORPION/
#
# Why precompute (not on-the-fly): SCORPION coarse-grains the full single-cell
# matrix and runs PANDA message passing — minutes and gigabytes per dataset.
# The network is a *static property* of the dataset, so it is computed once
# here and the Java servlet only ever reads the three CSV/JSON summaries.
# This mirrors how GSEA is precomputed in this project.
#
# Usage:
#   Rscript run_scorpion.R \
#     --mapping /path/to/mapping.csv.json \
#     --data_root /opt/SkinDB \
#     --priors /opt/SkinDB/SCORPION_priors \
#     [--said SAID001]        # optional: run a single dataset
#     [--overwrite]           # recompute even if outputs already exist
#     [--cores 4]
#
# Requires: scorpion, anndata (reticulate), jsonlite, Matrix, optparse.
# ==========================================================================

suppressWarnings(suppressMessages({
  library(optparse); library(jsonlite); library(Matrix)
}))

opt <- parse_args(OptionParser(option_list = list(
  make_option("--mapping",   type = "character"),
  make_option("--data_root", type = "character", default = "/opt/SkinDB"),
  make_option("--priors",    type = "character", default = "/opt/SkinDB/SCORPION_priors"),
  make_option("--said",      type = "character", default = NULL),
  make_option("--overwrite", action = "store_true", default = FALSE),
  make_option("--cores",     type = "integer", default = 1L),
  # network-summary parameters (documented in meta.json for every run):
  make_option("--edge_quantile", type = "double", default = 0.99,
              help = "an edge counts toward a TF's out-degree if its weight is above this within-network quantile"),
  make_option("--targets_per_tf", type = "integer", default = 25L,
              help = "how many top targets to store per TF")
)))

stopifnot(!is.null(opt$mapping))
suppressWarnings(suppressMessages({ library(scorpion); library(anndata) }))

mapping <- jsonlite::fromJSON(opt$mapping, simplifyVector = FALSE)
saids <- if (is.null(opt$said)) names(mapping) else opt$said
scorpion_version <- as.character(utils::packageVersion("scorpion"))

# Cache the two priors per species so we read them at most once each.
prior_cache <- new.env()
load_priors <- function(species) {
  if (!is.null(prior_cache[[species]])) return(prior_cache[[species]])
  mf <- file.path(opt$priors, sprintf("motif_prior_%s.txt", species))
  pf <- file.path(opt$priors, sprintf("ppi_%s.txt", species))
  if (!file.exists(mf) || !file.exists(pf))
    stop(sprintf("missing priors for %s — run build_priors.R first (%s / %s)", species, mf, pf))
  motif <- read.table(mf, header = TRUE, sep = "\t", stringsAsFactors = FALSE, quote = "")
  ppi   <- read.table(pf, header = TRUE, sep = "\t", stringsAsFactors = FALSE, quote = "")
  p <- list(motif = motif, ppi = ppi)
  prior_cache[[species]] <- p
  p
}

# Derive the per-GSM directory (and species) from the mapping's csv_path, so
# this script and the servlet resolve the exact same location.
#   csv_path = SkinDB_New/10X/<species>/<GSE>/<GSM>/DEG_results/<...>.csv
gsm_dir_of <- function(csv_path) dirname(dirname(csv_path))          # -> .../<GSM>
species_of <- function(csv_path) {
  if (grepl("/mouse/", csv_path)) "mouse" else "human"
}

read_counts <- function(h5ad_path) {
  ad <- anndata::read_h5ad(h5ad_path)
  # Prefer an explicit raw-counts layer; fall back to .raw, then .X.
  m <- NULL
  if (!is.null(ad$layers) && "counts" %in% names(ad$layers)) m <- ad$layers[["counts"]]
  if (is.null(m) && !is.null(ad$raw)) m <- ad$raw$X
  if (is.null(m)) m <- ad$X
  genes <- if (!is.null(ad$raw) && identical(m, ad$raw$X)) ad$raw$var_names else ad$var_names
  m <- as(Matrix::t(m), "CsparseMatrix")   # AnnData is cells x genes -> want genes x cells
  rownames(m) <- as.character(genes)
  colnames(m) <- as.character(ad$obs_names)
  # Collapse duplicate gene symbols (keep the first occurrence) — SCORPION needs unique rows.
  m[!duplicated(rownames(m)), , drop = FALSE]
}

run_one <- function(said) {
  meta <- mapping[[said]]
  if (is.null(meta$csv_path)) { message(sprintf("[%s] no csv_path, skip", said)); return(invisible()) }
  species <- species_of(meta$csv_path)
  gse <- meta$GSE; gsm <- meta$GSM
  gsm_dir <- file.path(opt$data_root, gsm_dir_of(meta$csv_path))
  out_dir <- file.path(gsm_dir, "SCORPION")

  done_flag <- file.path(out_dir, "meta.json")
  if (file.exists(done_flag) && !opt$overwrite) {
    message(sprintf("[%s] already done, skip (use --overwrite)", said)); return(invisible())
  }

  h5ad <- file.path(gsm_dir, sprintf("%s_%s.h5ad", gse, gsm))
  if (!file.exists(h5ad)) { message(sprintf("[%s] h5ad missing: %s", said, h5ad)); return(invisible()) }

  message(sprintf("[%s] %s  reading counts ...", said, species))
  gex <- tryCatch(read_counts(h5ad), error = function(e) { message("  read error: ", conditionMessage(e)); NULL })
  if (is.null(gex) || nrow(gex) < 100) { message(sprintf("[%s] too few genes, skip", said)); return(invisible()) }

  pr <- load_priors(species)
  # Keep only prior edges whose genes/TFs are measured in this dataset.
  measured <- rownames(gex)
  motif <- pr$motif[pr$motif$tf %in% measured & pr$motif$target %in% measured, ]
  if (nrow(motif) < 50) { message(sprintf("[%s] prior overlap too small, skip", said)); return(invisible()) }
  ppi <- pr$ppi[pr$ppi$tf1 %in% motif$tf & pr$ppi$tf2 %in% motif$tf, ]

  message(sprintf("[%s] SCORPION: %d genes x %d cells, %d prior edges, %d TFs ...",
                  said, nrow(gex), ncol(gex), nrow(motif), length(unique(motif$tf))))
  net <- tryCatch(
    scorpion::scorpion(tfMotifs = motif, gexMatrix = gex, ppiNet = ppi, nCores = opt$cores),
    error = function(e) { message("  scorpion error: ", conditionMessage(e)); NULL })
  if (is.null(net) || is.null(net$regNet)) { message(sprintf("[%s] no regNet, skip", said)); return(invisible()) }

  reg <- as.matrix(net$regNet)             # rows = TFs, cols = target genes; weights ~ z-scores
  # ---- summarise ---------------------------------------------------------
  thr <- as.numeric(stats::quantile(reg, opt$edge_quantile, na.rm = TRUE))
  pos <- reg; pos[pos < 0] <- 0            # regulatory "strength" = positive edge weight
  tf_activity <- data.frame(
    tf          = rownames(reg),
    out_degree  = rowSums(reg > thr),                       # # of strongly-targeted genes
    total_score = round(rowSums(pos), 4),                   # summed positive regulatory weight
    mean_weight = round(rowMeans(reg), 4),
    stringsAsFactors = FALSE
  )
  tf_activity <- tf_activity[order(-tf_activity$total_score), ]
  tf_activity$rank <- seq_len(nrow(tf_activity))

  # Top targets per TF (the "targetome"): highest positive edge weights.
  k <- opt$targets_per_tf
  tt <- do.call(rbind, lapply(rownames(reg), function(tf) {
    w <- reg[tf, ]; w <- w[is.finite(w)]
    w <- sort(w, decreasing = TRUE)
    w <- w[w > 0]; if (length(w) == 0) return(NULL)
    w <- head(w, k)
    data.frame(tf = tf, target = names(w), weight = round(as.numeric(w), 4),
               stringsAsFactors = FALSE)
  }))

  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  write.csv(tf_activity, file.path(out_dir, "tf_activity.csv"), row.names = FALSE)
  write.csv(tt,          file.path(out_dir, "tf_targets.csv"),  row.names = FALSE)
  jsonlite::write_json(list(
    said = said, species = species, gse = gse, gsm = gsm,
    n_tfs = nrow(reg), n_genes = ncol(reg), n_cells = ncol(gex),
    edge_threshold = round(thr, 4), edge_quantile = opt$edge_quantile,
    targets_per_tf = k,
    method = "SCORPION (PANDA message passing on single-cell coexpression)",
    regulatory_prior = "CollecTRI", ppi = "STRING v12 (score>=700)",
    scorpion_version = scorpion_version,
    run_date = format(Sys.time(), "%Y-%m-%d")
  ), file.path(out_dir, "meta.json"), auto_unbox = TRUE, pretty = TRUE)

  message(sprintf("[%s] wrote %d TFs -> %s", said, nrow(reg), out_dir))
}

for (s in saids) {
  tryCatch(run_one(s), error = function(e) message(sprintf("[%s] FAILED: %s", s, conditionMessage(e))))
}
message("[scorpion] all done.")
