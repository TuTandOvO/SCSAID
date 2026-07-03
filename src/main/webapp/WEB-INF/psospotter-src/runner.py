#!/usr/bin/env python3
"""Web runner for the scSAID psoSpotter feature.

The Java servlet writes a small JSON request descriptor and invokes this script.
We keep the runner intentionally narrow:

- load one or two uploaded h5ad files,
- validate the required AnnData structure,
- downsample deterministically to a bounded, balanced subset,
- run the vendored ``psospotter`` package,
- write a JSON result payload that the servlet can serve back to the browser.
"""

from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
from typing import Any

import anndata as ad
import numpy as np
import pandas as pd
from scipy import sparse

from psospotter import fit_cross_species_panel, fit_panel_model, psospotter_config


REQUIRED_OBS = ("Age", "sex", "condition", "sample")
DEFAULT_RESULT_LIMIT = 20000
DEFAULT_RANDOM_STATE = 42


def emit(progress: int, message: str) -> None:
    print(f"PROGRESS {int(progress)} {message}", flush=True)


def load_request(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def safe_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        tokens = []
        for chunk in value.replace("\r", "\n").split("\n"):
            for token in chunk.replace(",", " ").split():
                token = token.strip()
                if token:
                    tokens.append(token)
        return tokens
    if isinstance(value, (list, tuple)):
        return [str(item).strip() for item in value if str(item).strip()]
    return [str(value).strip()] if str(value).strip() else []


def normalize_genes(raw: list[str]) -> list[str]:
    seen = set()
    genes: list[str] = []
    for gene in raw:
        key = gene.strip()
        if not key:
            continue
        if key.lower() in seen:
            continue
        seen.add(key.lower())
        genes.append(key)
    return genes


def load_h5ad(path: Path) -> ad.AnnData:
    if not path.exists():
        raise FileNotFoundError(f"Missing h5ad file: {path}")
    adata = ad.read_h5ad(path)
    if "counts" not in adata.layers:
        raise ValueError(f"{path.name} is missing layers['counts']")
    missing = [name for name in REQUIRED_OBS if name not in adata.obs.columns]
    if missing:
        raise ValueError(f"{path.name} is missing required obs columns: {', '.join(missing)}")
    if adata.var_names.has_duplicates:
        # Duplicate symbols make gene-panel output ambiguous. Keep the first
        # occurrence to stay deterministic and warn via the result payload.
        adata = adata[:, ~adata.var_names.duplicated()].copy()
    return adata


def gene_subset(adata: ad.AnnData, requested: list[str]) -> tuple[ad.AnnData, list[str], list[str]]:
    genes = [str(x) for x in adata.var_names.tolist()]
    exact = {g: i for i, g in enumerate(genes)}
    upper = {}
    for i, g in enumerate(genes):
        upper.setdefault(g.upper(), i)

    keep_idx: list[int] = []
    matched: list[str] = []
    missing: list[str] = []
    for gene in requested:
        idx = exact.get(gene)
        if idx is None:
            idx = upper.get(gene.upper())
        if idx is None:
            missing.append(gene)
            continue
        keep_idx.append(idx)
        matched.append(genes[idx])

    if keep_idx:
        order = np.array(keep_idx, dtype=np.int64)
        adata = adata[:, order].copy()
    return adata, matched, missing


def balanced_sample(adata: ad.AnnData, target_total: int, seed: int = DEFAULT_RANDOM_STATE) -> tuple[ad.AnnData, dict[str, Any]]:
    if adata.n_obs <= target_total:
        return adata, {"sampled": False, "kept": int(adata.n_obs), "target": int(target_total)}

    rng = np.random.RandomState(seed)
    obs = adata.obs.reset_index(drop=True)
    condition = obs["condition"].astype(str).to_numpy()
    samples = obs["sample"].astype(str).to_numpy()
    classes = sorted({str(x) for x in condition.tolist()})
    if len(classes) < 2:
        # If the dataset only contains one mapped condition, fall back to a
        # deterministic sample across all rows.
        chosen = np.sort(rng.choice(adata.n_obs, size=target_total, replace=False))
        return adata[chosen, :].copy(), {"sampled": True, "kept": int(target_total), "target": int(target_total), "strategy": "global"}

    per_class = max(1, target_total // len(classes))
    selected: list[int] = []
    for cls in classes:
        cls_idx = np.where(condition == cls)[0]
        if cls_idx.size == 0:
            continue
        cls_target = min(per_class, cls_idx.size)
        if cls_target <= 0:
            continue

        # Balanced within sample as much as possible, then deterministic
        # per-sample shuffling for the remainder.
        sample_names = sorted({str(x) for x in samples[cls_idx].tolist()})
        sample_buckets = {name: cls_idx[samples[cls_idx] == name] for name in sample_names}
        base_take = cls_target // max(1, len(sample_names))
        remainder = cls_target % max(1, len(sample_names))

        class_selected: list[int] = []
        for name in sample_names:
            bucket = sample_buckets[name]
            if bucket.size == 0:
                continue
            take = min(bucket.size, base_take + (1 if remainder > 0 else 0))
            if remainder > 0:
                remainder -= 1
            if take >= bucket.size:
                class_selected.extend(bucket.tolist())
            else:
                class_selected.extend(np.sort(rng.choice(bucket, size=take, replace=False)).tolist())

        if len(class_selected) < cls_target:
            remaining = np.setdiff1d(cls_idx, np.array(class_selected, dtype=np.int64), assume_unique=False)
            need = min(cls_target - len(class_selected), remaining.size)
            if need > 0:
                class_selected.extend(np.sort(rng.choice(remaining, size=need, replace=False)).tolist())
        selected.extend(class_selected)

    selected = sorted(set(selected))
    if len(selected) > target_total:
        selected = sorted(rng.choice(selected, size=target_total, replace=False).tolist())
    if len(selected) == 0:
        chosen = np.sort(rng.choice(adata.n_obs, size=target_total, replace=False))
        return adata[chosen, :].copy(), {"sampled": True, "kept": int(target_total), "target": int(target_total), "strategy": "fallback"}
    return adata[selected, :].copy(), {
        "sampled": True,
        "kept": int(len(selected)),
        "target": int(target_total),
        "strategy": "balanced-condition-sample",
        "conditions": classes,
    }


def jsonable(value: Any) -> Any:
    if value is None or isinstance(value, (str, int, float, bool)):
        if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
            return None
        return value
    if isinstance(value, np.generic):
        return jsonable(value.item())
    if isinstance(value, np.ndarray):
        return [jsonable(item) for item in value.tolist()]
    if sparse.issparse(value):
        return jsonable(value.toarray())
    if isinstance(value, pd.DataFrame):
        return [jsonable(row) for row in value.to_dict(orient="records")]
    if isinstance(value, pd.Series):
        return [jsonable(item) for item in value.tolist()]
    if isinstance(value, dict):
        return {str(k): jsonable(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [jsonable(item) for item in value]
    if hasattr(value, "tolist"):
        return jsonable(value.tolist())
    return str(value)


def prepare_single(request: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    payload = request["single"]
    adata = load_h5ad(Path(payload["h5ad"]))
    requested = normalize_genes(safe_list(payload.get("genes")))
    if not requested:
        raise ValueError("A non-empty gene list is required.")
    adata, matched, missing = gene_subset(adata, requested)
    if len(matched) < 5:
        raise ValueError("Too few requested genes are present in the uploaded dataset.")
    adata, sample_info = balanced_sample(adata, int(request.get("target_total", DEFAULT_RESULT_LIMIT)), seed=DEFAULT_RANDOM_STATE)
    info = {
        "species": str(payload.get("species", request.get("species", "human"))),
        "mode": "single",
        "panel_k": int(request.get("panel_k", 20)),
        "requested_genes": requested,
        "matched_genes": matched,
        "missing_genes": missing,
        "sample": sample_info,
        "rows": int(adata.n_obs),
        "genes": int(adata.n_vars),
        "source_file": str(payload["h5ad"]),
    }
    return info, {"adata": adata}


def prepare_cross(request: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    payload = request["cross"]
    train = load_h5ad(Path(payload["train_h5ad"]))
    test = load_h5ad(Path(payload["test_h5ad"]))
    requested = normalize_genes(safe_list(payload.get("genes")))
    if not requested:
        raise ValueError("A non-empty gene list is required.")
    train, matched_train, missing_train = gene_subset(train, requested)
    test, matched_test, missing_test = gene_subset(test, requested)
    if len(matched_train) < 5 or len(matched_test) < 5:
        raise ValueError("Too few requested genes are present in the uploaded datasets.")
    train, train_sample = balanced_sample(train, int(request.get("target_total", DEFAULT_RESULT_LIMIT)), seed=DEFAULT_RANDOM_STATE)
    test, test_sample = balanced_sample(test, int(request.get("target_total", DEFAULT_RESULT_LIMIT)), seed=DEFAULT_RANDOM_STATE)
    ortholog_path = Path(payload["ortholog_tsv"])
    if not ortholog_path.exists():
        raise FileNotFoundError(f"Missing ortholog table: {ortholog_path}")
    info = {
        "species": "cross",
        "mode": "cross",
        "train_species": payload.get("trainSpecies", request.get("species", "human")),
        "test_species": payload.get("testSpecies", "mouse"),
        "requested_genes": requested,
        "matched_train_genes": matched_train,
        "matched_test_genes": matched_test,
        "missing_train_genes": missing_train,
        "missing_test_genes": missing_test,
        "train_sample": train_sample,
        "test_sample": test_sample,
        "train_rows": int(train.n_obs),
        "train_genes": int(train.n_vars),
        "test_rows": int(test.n_obs),
        "test_genes": int(test.n_vars),
        "train_file": str(payload["train_h5ad"]),
        "test_file": str(payload["test_h5ad"]),
        "ortholog_file": str(ortholog_path),
    }
    return info, {"train": train, "test": test, "ortholog_path": ortholog_path}


def config_for(request: dict[str, Any]) -> tuple[Any, dict[str, Any]]:
    mode = request["mode"]
    species = request.get("species", "human")
    if mode == "cross":
        species = request.get("cross", {}).get("trainSpecies", species)
    panel_k = int(request.get("panel_k", 20))
    target_total = int(request.get("target_total", DEFAULT_RESULT_LIMIT))
    if mode == "single":
        cfg = psospotter_config(
            species,
            mode="single",
            min_pruned_genes=5,
            target_nnz_for_selection=5,
            panel_k=panel_k,
            random_state=DEFAULT_RANDOM_STATE,
        )
    else:
        cfg = psospotter_config(
            species,
            mode="cross",
            min_pruned_genes=5,
            target_nnz_for_selection=5,
            panel_k=panel_k,
            random_state=DEFAULT_RANDOM_STATE,
        )
    return cfg, {"panel_k": panel_k, "target_total": target_total}


def run_single(request: dict[str, Any]) -> dict[str, Any]:
    cfg, cfg_info = config_for(request)
    info, payload = prepare_single(request)
    emit(10, "Prepared single-species input")
    adata = payload["adata"]
    X = adata.layers["counts"]
    obs = adata.obs.copy()
    var_names = adata.var_names.astype(str).to_numpy()
    emit(25, "Fitting psoSpotter panel")
    result = fit_panel_model(X, obs, cfg, var_names)
    emit(90, "Formatting results")
    return {
        "status": "succeeded",
        "mode": "single",
        "config": cfg_info,
        "input": info,
        "result": {
            "panel": jsonable(result["panel"]),
            "coefficients": jsonable(result["coefficients"]),
            "metrics": jsonable(result["metrics"]),
            "stability": jsonable(result["stability"]),
            "pruning": jsonable(result["pruning"]),
            "calibration_C": jsonable(result["calibration_C"]),
            "split": jsonable(result["split"]),
            "var_names": jsonable(result["var_names"]),
        },
    }


def load_ortholog_table(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, sep="\t")
    if not {"human_gene", "mouse_gene"}.issubset(df.columns):
        raise ValueError("Ortholog table must contain human_gene and mouse_gene columns.")
    if "orthology_type" not in df.columns:
        df["orthology_type"] = "ortholog_one2one"
    return df[["human_gene", "mouse_gene", "orthology_type"]].copy()


def run_cross(request: dict[str, Any]) -> dict[str, Any]:
    cfg, cfg_info = config_for(request)
    info, payload = prepare_cross(request)
    emit(10, "Prepared cross-species input")
    train = payload["train"]
    test = payload["test"]
    orth = load_ortholog_table(payload["ortholog_path"])
    emit(30, "Fitting psoSpotter cross-species panel")
    result = fit_cross_species_panel(
        train.layers["counts"],
        train.obs.copy(),
        test.layers["counts"],
        test.obs.copy(),
        orth,
        cfg,
        cfg,
        train.var_names.astype(str).to_numpy(),
        test.var_names.astype(str).to_numpy(),
        train_is_human=str(request.get("cross", {}).get("trainSpecies", request.get("species", "human"))).lower() == "human",
    )
    emit(90, "Formatting results")
    return {
        "status": "succeeded",
        "mode": "cross",
        "config": cfg_info,
        "input": info,
        "result": {
            "panel": jsonable(result["panel"]),
            "internal": jsonable(result["internal"]),
            "external": jsonable(result["external"]),
            "stability": jsonable(result["stability"]),
            "split": jsonable(result["split"]),
            "moments": jsonable(result["moments"]),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("request_json", type=Path)
    parser.add_argument("result_json", type=Path)
    args = parser.parse_args()

    request = load_request(args.request_json)
    mode = request.get("mode")
    if mode not in {"single", "cross"}:
        raise ValueError(f"Unsupported mode: {mode!r}")

    emit(1, "Loading request")
    if mode == "single":
        payload = run_single(request)
    else:
        payload = run_cross(request)

    args.result_json.write_text(json.dumps(jsonable(payload), indent=2) + "\n", encoding="utf-8")
    emit(100, "Finished")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
