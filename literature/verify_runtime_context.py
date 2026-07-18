#!/usr/bin/env python3
"""Strictly verify runtime sample, paper-selection, and full-text indexes."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument(
        "--registry", type=Path, default=Path(__file__).with_name("registry.json")
    )
    parser.add_argument(
        "--samples", type=Path, default=Path(__file__).with_name("sample_context.json")
    )
    parser.add_argument(
        "--selection",
        type=Path,
        default=Path(__file__).with_name("canonical_sample_papers.json"),
    )
    args = parser.parse_args()

    registry = json.loads(args.registry.read_text(encoding="utf-8"))
    samples = json.loads(args.samples.read_text(encoding="utf-8"))["samples"]
    selection_rows = json.loads(args.selection.read_text(encoding="utf-8"))["samples"]
    selection = {row["said"]: row for row in selection_rows}
    datasets = {row["said"]: row for row in registry["datasets"]}
    papers = {row["paper_id"]: row for row in registry["papers"]}
    if (
        len(datasets) != 252
        or len(samples) != 252
        or len(selection_rows) != 252
        or len(selection) != 252
    ):
        raise ValueError("all three runtime indexes must contain exactly 252 datasets")
    if len(papers) != 56:
        raise ValueError("publication registry must contain exactly 56 unique papers")

    text_rows = list(
        csv.DictReader(
            (args.root / "text" / "manifest.tsv").open(encoding="utf-8"),
            delimiter="\t",
        )
    )
    text_index = {row["paper_id"]: row for row in text_rows}
    if len(text_rows) != 56 or len(text_index) != 56:
        raise ValueError("canonical text manifest must contain exactly 56 papers")

    for said, dataset in datasets.items():
        if said not in samples or said not in selection:
            raise ValueError(f"{said}: missing exact sample or paper-selection record")
        context = samples[said]
        chosen = selection[said]
        if context["sample_accession"] != dataset["sample_accession"]:
            raise ValueError(f"{said}: exact sample metadata mismatch")
        if context["parent_study_accession"] != dataset["study_accession"]:
            raise ValueError(f"{said}: parent study mismatch")
        if chosen["sample_accession"] != dataset["sample_accession"]:
            raise ValueError(f"{said}: paper-selection sample mismatch")
        if chosen["status"] not in {"verified_primary", "no_verified_primary"}:
            raise ValueError(f"{said}: unsupported paper-selection status")
        if chosen["status"] == "verified_primary":
            paper_id = chosen["paper_id"]
            if paper_id not in papers:
                raise ValueError(f"{said}: selected paper is absent from the registry")
            if paper_id not in text_index:
                raise ValueError(f"{said}: selected paper lacks canonical full text")
            registered = papers[paper_id]
            for key in ("pmid", "doi", "title"):
                if chosen.get(key, "").strip() != registered.get(key, "").strip():
                    raise ValueError(f"{said}: selected paper {key} conflicts with registry")
        elif any(chosen.get(key) for key in ("paper_id", "pmid", "doi")):
            raise ValueError(f"{said}: no-primary record contains a publication identity")

    for paper_id, row in text_index.items():
        if paper_id not in papers:
            raise ValueError(f"{paper_id}: canonical text has no publication registry record")
        registered = papers[paper_id]
        if row["pmid"] != registered["pmid"] or row["doi"] != registered["doi"]:
            raise ValueError(f"{paper_id}: canonical-text PMID/DOI mismatch")
        text_root = (args.root / "text").resolve()
        path = (text_root / row["text_filename"]).resolve()
        try:
            path.relative_to(text_root)
        except ValueError:
            raise ValueError(f"{paper_id}: unsafe canonical text path")
        if not path.is_file() or path.stat().st_size < 1_000:
            raise ValueError(f"{paper_id}: canonical text is absent or too short")
        if sha256(path) != row["text_sha256"]:
            raise ValueError(f"{paper_id}: canonical text checksum mismatch")

    print(
        "Runtime context verification passed: 252 exact sample records, "
        f"{sum(r['status'] == 'verified_primary' for r in selection_rows)} "
        "canonical sample-paper links, and 56 complete article texts."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
