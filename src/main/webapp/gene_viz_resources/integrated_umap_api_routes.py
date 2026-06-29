# ─────────────────────────────────────────────────────────────────────────────
# JSON API routes for the client-side gene-expression UMAP overlay
# (umap-explorer.jsp / JS/umap-explorer.js).
#
# DEPLOYMENT NOTE — this block is NOT a standalone module. It is appended verbatim
# into the live `/root/SkinDB/services/integrated_umap_app.py`, just before its
# `if __name__ == "__main__":` guard, so it shares that module's already-loaded
# globals: `server` (the Flask app), `np`, `pd`, `_expr_for`, `get_gene_column`,
# `match_gene_case_insensitive`. After splicing, restart with:
#     systemctl restart skindb-dash
# nginx already proxies `/integrated_umap/ -> 127.0.0.1:8050`, so these routes are
# reachable same-origin at `https://skin-scsaid.com/integrated_umap/api/...`.
#
# This file in the repo is the source of record / review copy; the deployed
# artifact is the on-server integrated_umap_app.py (the repo Python is not run).
# ─────────────────────────────────────────────────────────────────────────────

from flask import request, jsonify

# Deterministic, stratified-by-cell-type down-sample so the browser renders a
# manageable point cloud. The SAME row indices back both /umap-base and
# /expression, so a gene vector aligns positionally with the plotted points.
# Fixed seed => every gunicorn worker computes an identical sample.
_SAMPLE_TARGET = 50000
_SAMPLE_FLOOR = 300        # min cells kept per cell-type (preserves rare types)
_SAMPLE_SEED = 0
_SAMPLE_IDX_CACHE: dict = {}


def _sample_idx(species: str):
    """Return (and cache) the deterministic row indices for a species."""
    if species in _SAMPLE_IDX_CACHE:
        return _SAMPLE_IDX_CACHE[species]
    _, _, _, umap, obs = _expr_for(species)
    n = int(umap.shape[0])
    if n <= _SAMPLE_TARGET:
        idx = np.arange(n, dtype=np.int64)
    else:
        rng = np.random.default_rng(_SAMPLE_SEED)
        cats = obs["Gross_Map"].astype(str).to_numpy()
        frac = _SAMPLE_TARGET / n
        picks = []
        for c in np.unique(cats):
            ci = np.where(cats == c)[0]
            k = int(min(len(ci), max(round(len(ci) * frac),
                                     min(len(ci), _SAMPLE_FLOOR))))
            picks.append(rng.choice(ci, size=k, replace=False))
        idx = np.concatenate(picks)
        if idx.size > _SAMPLE_TARGET:
            idx = rng.choice(idx, size=_SAMPLE_TARGET, replace=False)
        idx = np.sort(idx).astype(np.int64)
    _SAMPLE_IDX_CACHE[species] = idx
    return idx


def _norm_species(raw):
    sp = (raw or "human").strip().lower()
    return sp if sp in ("human", "mouse") else "human"


def _cat_block(obs, idx, col):
    """Serialize an obs column as {categories:[...], codes:[...]} for the sample."""
    if col not in obs.columns:
        return {"categories": [], "codes": [-1] * len(idx)}
    cat = obs[col].astype("category")
    categories = [str(c) for c in cat.cat.categories]
    codes = cat.cat.codes.to_numpy()[idx].astype(int).tolist()
    return {"categories": categories, "codes": codes}


def _json(payload, max_age):
    resp = jsonify(payload)
    resp.headers["Cache-Control"] = f"public, max-age={max_age}"
    return resp


@server.route("/integrated_umap/api/genes")
def api_genes():
    species = _norm_species(request.args.get("species"))
    _, genes, _, _, _ = _expr_for(species)
    return _json({"species": species, "genes": list(genes)}, 86400)


@server.route("/integrated_umap/api/umap-base")
def api_umap_base():
    species = _norm_species(request.args.get("species"))
    _, _, _, umap, obs = _expr_for(species)
    idx = _sample_idx(species)
    xs = np.round(umap[idx, 0].astype(np.float64), 3).tolist()
    ys = np.round(umap[idx, 1].astype(np.float64), 3).tolist()
    cell_ids = [str(c) for c in obs.index.to_numpy()[idx]]
    meta = {
        "cell_type": _cat_block(obs, idx, "Gross_Map"),
        "cluster":   _cat_block(obs, idx, "leiden_scVI_0_5"),
        "sample":    _cat_block(obs, idx, "GSM"),
    }
    return _json({
        "species": species,
        "n": int(idx.size),
        "x": xs,
        "y": ys,
        "cell_ids": cell_ids,
        "meta": meta,
    }, 86400)


@server.route("/integrated_umap/api/expression")
def api_expression():
    species = _norm_species(request.args.get("species"))
    gene_raw = (request.args.get("gene") or "").strip()
    if not gene_raw:
        return jsonify({"error": "missing_gene"}), 400
    resolved = match_gene_case_insensitive(species, gene_raw)
    if resolved is None:
        return jsonify({"error": "gene_not_found", "gene": gene_raw,
                        "species": species}), 404
    full = get_gene_column(species, resolved)        # dense float32, length n_cells
    if full is None:
        return jsonify({"error": "gene_not_found", "gene": gene_raw,
                        "species": species}), 404
    idx = _sample_idx(species)
    vals = full[idx]
    vmin = float(np.min(vals)) if vals.size else 0.0
    vmax = float(np.max(vals)) if vals.size else 0.0
    n_nonzero = int(np.count_nonzero(vals))
    return _json({
        "gene": resolved,
        "species": species,
        "values": np.round(vals.astype(np.float64), 4).tolist(),
        "min": vmin,
        "max": vmax,
        "n_nonzero": n_nonzero,
    }, 86400)
