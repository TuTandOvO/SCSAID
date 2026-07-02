#!/usr/bin/env bash
# ==========================================================================
# build_priors.sh  —  Build SCORPION's two species-level priors from public
#                     web services, WITHOUT needing R/Bioconductor.
#
# Run this on any machine with plain internet access (curl + awk), then copy
# the four output files to the server's --priors directory. We build them off
# the deployment host on purpose: that host (Alibaba Cloud, CN) cannot reach
# omnipathdb.org or string-db.org, but can serve files placed on its disk.
#
# Produces, in $OUT:
#   motif_prior_human.txt / motif_prior_mouse.txt   (tf  target  weight)
#   ppi_human.txt         / ppi_mouse.txt           (tf1 tf2     weight)
#
# Provenance:
#   * Regulatory prior (W0): CollecTRI (Müller-Dott et al. 2023), the curated
#     TF->target collection, taken from the OmniPath static export. We keep the
#     (source_genesymbol, target_genesymbol) pairs as a binary presence prior;
#     symbols are already species-cased (human UPPER, mouse Title-case).
#   * PPI: STRING v12 (Szklarczyk et al. 2023), restricted to the prior's TFs,
#     combined score >= 700, via the STRING network API. Self-loops are added
#     for every TF so SCORPION keeps all of them (runPANDA intersects the TF
#     set with the PPI, so a TF absent from STRING would otherwise be dropped).
#
# Usage:  OUT=./SCORPION_priors ./build_priors.sh   &&   scp $OUT/* server:/opt/SkinDB/SCORPION_priors/
# ==========================================================================
set -euo pipefail
OUT="${OUT:-SCORPION_priors}"
SCORE="${SCORE:-700}"
mkdir -p "$OUT"

declare -A TAX=( [human]=9606 [mouse]=10090 )

for sp in human mouse; do
  tax="${TAX[$sp]}"
  echo "[priors] $sp (taxon $tax)"

  # --- 1. CollecTRI regulatory prior -------------------------------------
  curl -fsSL "https://static.omnipathdb.org/resources/interactions_collectri_${tax}.tsv.gz" \
    | gunzip \
    | awk -F'\t' 'NR>1 && $3!="" && $4!="" && $3!~/COMPLEX/ && $4!~/COMPLEX/ {print $3"\t"$4"\t1"}' \
    | sort -u > "$OUT/.motif_body"
  { printf 'tf\ttarget\tweight\n'; cat "$OUT/.motif_body"; } > "$OUT/motif_prior_${sp}.txt"
  cut -f1 "$OUT/.motif_body" | sort -u > "$OUT/.tfs"
  echo "  motif_prior_${sp}.txt: $(wc -l < "$OUT/.motif_body") edges, $(wc -l < "$OUT/.tfs") TFs"

  # --- 2. STRING PPI among those TFs (score >= $SCORE) + self-loops -------
  curl -fsSL --data-urlencode "identifiers=$(tr '\n' '\r' < "$OUT/.tfs")" \
       --data "species=${tax}" --data "required_score=${SCORE}" --data "caller_identity=scsaid" \
       "https://string-db.org/api/tsv/network" > "$OUT/.string"
  {
    printf 'tf1\ttf2\tweight\n'
    awk -F'\t' 'NR>1 && $3!="" && $4!="" {print $3"\t"$4"\t"$6}' "$OUT/.string"   # preferredName_A/B, combined score
    awk '{print $1"\t"$1"\t1"}' "$OUT/.tfs"                                       # self-loops
  } > "$OUT/ppi_${sp}.txt"
  echo "  ppi_${sp}.txt: $(($(wc -l < "$OUT/ppi_${sp}.txt")-1)) rows (STRING edges + self-loops)"

  rm -f "$OUT/.motif_body" "$OUT/.tfs" "$OUT/.string"
done
echo "[priors] done -> $OUT"
