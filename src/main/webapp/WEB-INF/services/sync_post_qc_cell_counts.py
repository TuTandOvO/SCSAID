#!/usr/bin/env python3
"""Synchronize metadata cell counts with the post-QC cells stored in H5AD files."""

from __future__ import annotations

import csv
import os
import sys
import tempfile
from pathlib import Path

import h5py


METADATA_FILES = {
    "human": Path("human/human_obs_by_batch.csv"),
    "mouse": Path("mouse/mouse_obs_by_batch.csv"),
}


def _text(value: object) -> str:
    if isinstance(value, bytes):
        return value.decode("utf-8")
    return str(value)


def h5ad_cell_count(path: Path) -> int:
    with h5py.File(path, "r") as handle:
        obs = handle.get("obs")
        if not isinstance(obs, h5py.Group):
            raise ValueError("missing obs dataframe")

        index_name = _text(obs.attrs.get("_index", "_index"))
        candidates = [index_name, "_index"]
        for candidate in candidates:
            dataset = obs.get(candidate)
            if isinstance(dataset, h5py.Dataset) and dataset.ndim >= 1:
                return int(dataset.shape[0])

        for value in obs.values():
            if isinstance(value, h5py.Dataset) and value.ndim >= 1:
                return int(value.shape[0])
            if isinstance(value, h5py.Group):
                codes = value.get("codes")
                if isinstance(codes, h5py.Dataset) and codes.ndim >= 1:
                    return int(codes.shape[0])
        raise ValueError("unable to determine obs row count")


def synchronize_metadata(data_root: Path, species: str, relative_csv: Path) -> tuple[int, int, list[str]]:
    csv_path = data_root / relative_csv
    with csv_path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle))

    if not rows:
        raise ValueError(f"empty metadata file: {csv_path}")

    updated = 0
    available = 0
    skipped: list[str] = []
    for row_number, row in enumerate(rows[1:], start=2):
        if len(row) < 11:
            skipped.append(f"row {row_number}: malformed")
            continue
        said, gse, gsm = row[10].strip(), row[9].strip(), row[5].strip()
        if not said or not gse or not gsm:
            skipped.append(f"row {row_number}: missing accession")
            continue
        h5ad_path = data_root / "download_data" / "10X" / species / gse / gsm / f"{gse}_{gsm}.h5ad"
        if not h5ad_path.is_file():
            skipped.append(f"{said}: H5AD missing")
            continue
        try:
            count = h5ad_cell_count(h5ad_path)
        except (OSError, ValueError) as exc:
            skipped.append(f"{said}: {exc}")
            continue
        available += 1
        if row[1].strip() != str(count):
            row[1] = str(count)
            updated += 1

    if updated:
        descriptor, temporary_name = tempfile.mkstemp(prefix=f".{csv_path.name}.", dir=csv_path.parent)
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
                writer = csv.writer(handle, lineterminator="\n")
                writer.writerows(rows)
                handle.flush()
                os.fsync(handle.fileno())
            os.chmod(temporary_name, csv_path.stat().st_mode & 0o777)
            os.replace(temporary_name, csv_path)
        finally:
            if os.path.exists(temporary_name):
                os.unlink(temporary_name)

    return available, updated, skipped


def main() -> int:
    data_root = Path(sys.argv[1] if len(sys.argv) > 1 else "/opt/SkinDB")
    total_available = 0
    total_updated = 0
    total_skipped: list[str] = []
    for species, relative_csv in METADATA_FILES.items():
        available, updated, skipped = synchronize_metadata(data_root, species, relative_csv)
        total_available += available
        total_updated += updated
        total_skipped.extend(skipped)
        print(f"{species}: verified {available}, updated {updated}, skipped {len(skipped)}")

    print(f"post-QC cell-count sync: verified {total_available}, updated {total_updated}, skipped {len(total_skipped)}")
    if total_skipped:
        for message in total_skipped[:20]:
            print(f"warning: {message}", file=sys.stderr)
        if len(total_skipped) > 20:
            print(f"warning: {len(total_skipped) - 20} additional rows skipped", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
