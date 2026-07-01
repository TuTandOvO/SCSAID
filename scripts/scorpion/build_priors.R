#!/usr/bin/env Rscript
# ==========================================================================
# build_priors.R  —  Build the two SCORPION input priors, once per species.
#
# SCORPION reconstructs a gene-regulatory network (GRN) with the PANDA
# message-passing framework, which integrates THREE data sources:
#   1. a single-cell co-expression network        (computed per dataset from the counts)
#   2. a TF -> target *regulatory prior*  (W0)     <-- built here  (motif_prior_<sp>.txt)
#   3. a TF <-> TF protein-protein interaction net <-- built here  (ppi_<sp>.txt)
#
# The two priors (2 and 3) are species-level and dataset-independent, so we
# build them ONCE and reuse them for every SAID of that species. This keeps
# every per-dataset network reconstructed against the *same* curated prior,
# which is what makes the regulator rankings comparable across datasets.
#
# Provenance (curated, versioned, citable — this is what makes it rigorous):
#   * Regulatory prior : CollecTRI (Muller-Dott et al., 2023) via decoupleR.
#       A literature-curated TF->target collection with sign, available for
#       human and mouse. We keep only the TF/target edges (unsigned presence),
#       which is exactly the binary W0 prior PANDA/SCORPION expects.
#   * PPI network      : STRING v12 (Szklarczyk et al., 2023) restricted to the
#       TFs present in the regulatory prior, combined score >= 700 (high conf.),
#       rescaled to [0,1].
#
# Run once:
#   Rscript build_priors.R --species human --out /opt/SkinDB/SCORPION_priors
#   Rscript build_priors.R --species mouse --out /opt/SkinDB/SCORPION_priors
#
# Requires: decoupleR, STRINGdb, optparse (Bioconductor + CRAN).
# ==========================================================================

suppressWarnings(suppressMessages({
  library(optparse)
}))

opt <- parse_args(OptionParser(option_list = list(
  make_option("--species", type = "character", default = "human",
              help = "human | mouse"),
  make_option("--out", type = "character", default = "SCORPION_priors",
              help = "output directory for the prior files"),
  make_option("--string_score", type = "integer", default = 700L,
              help = "minimum STRING combined_score (0-1000) [default 700]")
)))

species <- tolower(opt$species)
stopifnot(species %in% c("human", "mouse"))
dir.create(opt$out, showWarnings = FALSE, recursive = TRUE)

# STRING / organism identifiers.
string_taxon <- if (species == "human") 9606L else 10090L
collectri_org <- species  # decoupleR accepts "human"/"mouse"

message(sprintf("[priors] species=%s  string_taxon=%d  min_score=%d",
                species, string_taxon, opt$string_score))

# --------------------------------------------------------------------------
# 1. Regulatory prior (motif / W0): TF -> target, binary presence.
# --------------------------------------------------------------------------
suppressWarnings(suppressMessages(library(decoupleR)))
message("[priors] downloading CollecTRI regulons ...")
collectri <- decoupleR::get_collectri(organism = collectri_org, split_complexes = FALSE)
# Columns: source (TF), target (gene), mor (mode of regulation ±1), ...
motif <- unique(data.frame(
  tf     = as.character(collectri$source),
  target = as.character(collectri$target),
  weight = 1,                     # PANDA W0 prior is a binary presence mask
  stringsAsFactors = FALSE
))
motif <- motif[motif$tf != "" & motif$target != "", ]
motif_file <- file.path(opt$out, sprintf("motif_prior_%s.txt", species))
write.table(motif, motif_file, sep = "\t", quote = FALSE, row.names = FALSE)
message(sprintf("[priors] wrote %s  (%d edges, %d TFs, %d targets)",
                motif_file, nrow(motif),
                length(unique(motif$tf)), length(unique(motif$target))))

tfs <- sort(unique(motif$tf))

# --------------------------------------------------------------------------
# 2. PPI network among the TFs, from STRING.
# --------------------------------------------------------------------------
suppressWarnings(suppressMessages(library(STRINGdb)))
message("[priors] mapping TFs to STRING and pulling interactions ...")
sdb <- STRINGdb$new(version = "12.0", species = string_taxon,
                    score_threshold = opt$string_score, input_directory = opt$out)

tf_df <- data.frame(gene = tfs, stringsAsFactors = FALSE)
mapped <- sdb$map(tf_df, "gene", removeUnmappedRows = TRUE)
ints <- sdb$get_interactions(mapped$STRING_id)

# Translate STRING ids back to gene symbols and keep TF<->TF edges only.
id2sym <- setNames(mapped$gene, mapped$STRING_id)
ppi <- data.frame(
  tf1    = id2sym[ints$from],
  tf2    = id2sym[ints$to],
  weight = ints$combined_score / 1000,   # rescale 0-1000 -> 0-1
  stringsAsFactors = FALSE
)
ppi <- ppi[!is.na(ppi$tf1) & !is.na(ppi$tf2) & ppi$tf1 != ppi$tf2, ]
ppi <- unique(ppi)
# Add self-loops (weight 1) — PANDA expects the PPI diagonal to be present.
self <- data.frame(tf1 = tfs, tf2 = tfs, weight = 1, stringsAsFactors = FALSE)
ppi <- rbind(ppi, self)

ppi_file <- file.path(opt$out, sprintf("ppi_%s.txt", species))
write.table(ppi, ppi_file, sep = "\t", quote = FALSE, row.names = FALSE)
message(sprintf("[priors] wrote %s  (%d edges over %d TFs)",
                ppi_file, nrow(ppi), length(unique(c(ppi$tf1, ppi$tf2)))))

message("[priors] done.")
