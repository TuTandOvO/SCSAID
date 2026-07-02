#!/usr/bin/env Rscript
# ==========================================================================
# build_priors.R  —  Build the two SCORPION input priors, once per species.
#
# SCORPION reconstructs a gene-regulatory network (GRN) with the PANDA
# message-passing framework, which integrates THREE data sources:
#   1. a single-cell co-expression network        (computed per dataset from the counts)
#   2. a TF -> target *regulatory prior*  (W0)     <-- built here  (motif_prior_<sp>.txt)
#   3. a TF <-> TF protein-protein interaction net <-- built here  (ppi_<sp>.txt, optional)
#
# The two priors (2 and 3) are species-level and dataset-independent, so we
# build them ONCE and reuse them for every SAID of that species. This keeps
# every per-dataset network reconstructed against the *same* curated prior,
# which is what makes the regulator rankings comparable across datasets.
#
# Provenance (curated, versioned, citable — this is what makes it rigorous):
#   * Regulatory prior : DoRothEA (Garcia-Alonso et al., Genome Res. 2019),
#       confidence levels A/B/C. The regulons ship *inside* the `dorothea` R
#       package as the data objects `dorothea_hs` / `dorothea_mm`, so this step
#       needs NO network access — important on hosts that cannot reach
#       omnipathdb.org. We keep the TF/target pairs as the binary W0 prior.
#   * PPI network      : STRING v12 (Szklarczyk et al., 2023) restricted to the
#       prior's TFs, combined score >= 700, rescaled to [0,1]. BEST EFFORT — if
#       STRING cannot be reached, we skip it and SCORPION runs with the motif
#       prior + expression only (a valid PANDA GRN; ppiNet defaults to identity).
#
# Run once per species:
#   Rscript build_priors.R --species human --out /opt/SkinDB/SCORPION_priors
#   Rscript build_priors.R --species mouse --out /opt/SkinDB/SCORPION_priors
#
# Requires: dorothea (bundled regulons), optparse; STRINGdb (optional, for PPI).
# ==========================================================================

suppressWarnings(suppressMessages({ library(optparse) }))

opt <- parse_args(OptionParser(option_list = list(
  make_option("--species", type = "character", default = "human", help = "human | mouse"),
  make_option("--out", type = "character", default = "SCORPION_priors",
              help = "output directory for the prior files"),
  make_option("--confidence", type = "character", default = "A,B,C",
              help = "comma-separated DoRothEA confidence levels to keep [default A,B,C]"),
  make_option("--string_score", type = "integer", default = 700L,
              help = "minimum STRING combined_score (0-1000) [default 700]"),
  make_option("--skip_ppi", action = "store_true", default = FALSE,
              help = "do not attempt to build the STRING PPI network")
)))

species <- tolower(opt$species)
stopifnot(species %in% c("human", "mouse"))
dir.create(opt$out, showWarnings = FALSE, recursive = TRUE)
conf_levels <- trimws(strsplit(opt$confidence, ",")[[1]])
string_taxon <- if (species == "human") 9606L else 10090L

message(sprintf("[priors] species=%s  taxon=%d  confidence=%s",
                species, string_taxon, paste(conf_levels, collapse = "/")))

# --------------------------------------------------------------------------
# 1. Regulatory prior (motif / W0): TF -> target, binary presence.
#    Uses the DoRothEA regulons bundled in the `dorothea` package (offline).
# --------------------------------------------------------------------------
suppressWarnings(suppressMessages(library(dorothea)))
regulon_name <- if (species == "human") "dorothea_hs" else "dorothea_mm"
data(list = regulon_name, package = "dorothea", envir = environment())
regulon <- get(regulon_name)
regulon <- regulon[regulon$confidence %in% conf_levels, ]
motif <- unique(data.frame(
  tf     = as.character(regulon$tf),
  target = as.character(regulon$target),
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
# 2. PPI network among the TFs, from STRING (best effort).
# --------------------------------------------------------------------------
ppi_file <- file.path(opt$out, sprintf("ppi_%s.txt", species))
if (opt$skip_ppi) {
  message("[priors] --skip_ppi set: no PPI network (SCORPION will use motif + expression only).")
} else {
  ok <- tryCatch({
    suppressWarnings(suppressMessages(library(STRINGdb)))
    message("[priors] mapping TFs to STRING and pulling interactions ...")
    sdb <- STRINGdb$new(version = "12.0", species = string_taxon,
                        score_threshold = opt$string_score, input_directory = opt$out)
    mapped <- sdb$map(data.frame(gene = tfs, stringsAsFactors = FALSE), "gene",
                      removeUnmappedRows = TRUE)
    ints <- sdb$get_interactions(mapped$STRING_id)
    id2sym <- setNames(mapped$gene, mapped$STRING_id)
    ppi <- data.frame(tf1 = id2sym[ints$from], tf2 = id2sym[ints$to],
                      weight = ints$combined_score / 1000, stringsAsFactors = FALSE)
    ppi <- unique(ppi[!is.na(ppi$tf1) & !is.na(ppi$tf2) & ppi$tf1 != ppi$tf2, ])
    ppi <- rbind(ppi, data.frame(tf1 = tfs, tf2 = tfs, weight = 1))   # self-loops
    write.table(ppi, ppi_file, sep = "\t", quote = FALSE, row.names = FALSE)
    message(sprintf("[priors] wrote %s  (%d edges over %d TFs)",
                    ppi_file, nrow(ppi), length(unique(c(ppi$tf1, ppi$tf2)))))
    TRUE
  }, error = function(e) {
    message("[priors] STRING PPI unavailable (", conditionMessage(e),
            ") — continuing without a PPI network.")
    FALSE
  })
}

message("[priors] done.")
