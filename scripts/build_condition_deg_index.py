#!/usr/bin/env python3
"""Build the condition-vs-Healthy DEG search index on the production server.

The comparison API keeps each completed pseudobulk DESeq2 contrast in
``condition_compare_cache``.  This builder reuses those durable results,
publishes an atomic searchable snapshot immediately, and computes only missing
contrasts.  Jobs are deliberately submitted one at a time because concurrent
HDF5/AnnData reads have previously deadlocked the shared comparison process.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


HEADER = "species\tcondition\treference\tcell_type\tgene\tlogFC\tpval\tpval_adj\n"
REFERENCE = "Healthy"


def log(message: str) -> None:
    print(time.strftime("%Y-%m-%d %H:%M:%S"), message, flush=True)


def request_json(url: str, payload: dict[str, Any] | None = None) -> Any:
    data = None
    headers: dict[str, str] = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def job_id(species: str, condition: str) -> str:
    raw = f"cc|{species}|{condition}|{REFERENCE}".encode("utf-8")
    return hashlib.sha1(raw).hexdigest()[:16]


def clean(value: Any) -> str:
    if value is None:
        return ""
    return str(value).replace("\t", " ").replace("\n", " ").replace("\r", " ")


class IndexBuilder:
    def __init__(self, args: argparse.Namespace) -> None:
        self.api_base = args.api_base.rstrip("/")
        self.compare_dir = Path(args.compare_dir)
        self.output_dir = Path(args.output_dir)
        self.poll_seconds = args.poll_seconds
        self.timeout_seconds = args.timeout_minutes * 60
        self.retries = args.retries
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def conditions(self, species: str) -> list[str]:
        query = urllib.parse.urlencode({"species": species})
        rows = request_json(f"{self.api_base}/api/conditions?{query}")
        return [
            str(row["condition"])
            for row in rows
            if row.get("condition") and row["condition"] != REFERENCE
        ]

    def result_path(self, species: str, condition: str) -> Path:
        return self.compare_dir / job_id(species, condition) / "result.json"

    def status_path(self, species: str, condition: str) -> Path:
        return self.compare_dir / job_id(species, condition) / "status.json"

    def publish(self, species: str, conditions: list[str]) -> dict[str, Any]:
        complete = [c for c in conditions if self.result_path(species, c).is_file()]
        missing = [c for c in conditions if c not in complete]
        tmp_path = self.output_dir / f".{species}.tsv.new"
        output_path = self.output_dir / f"{species}.tsv"
        rows_written = 0

        with tmp_path.open("w", encoding="utf-8", newline="") as output:
            output.write(HEADER)
            for condition in conditions:
                result_path = self.result_path(species, condition)
                if not result_path.is_file():
                    continue
                with result_path.open(encoding="utf-8") as source:
                    rows = json.load(source)
                for row in rows:
                    gene = clean(row.get("gene"))
                    if not gene:
                        continue
                    values = (
                        species,
                        condition,
                        REFERENCE,
                        row.get("cell_type"),
                        gene,
                        row.get("logFC"),
                        row.get("pval"),
                        row.get("pval_adj"),
                    )
                    output.write("\t".join(clean(value) for value in values) + "\n")
                    rows_written += 1
            output.flush()
            os.fsync(output.fileno())

        os.replace(tmp_path, output_path)
        metadata = {
            "species": species,
            "reference": REFERENCE,
            "conditions": len(complete),
            "totalConditions": len(conditions),
            "rows": rows_written,
            "skipped": len(missing),
            "missingConditions": missing,
            "complete": not missing,
            "updatedAt": int(time.time() * 1000),
        }
        meta_tmp = self.output_dir / f".{species}.meta.json.new"
        meta_path = self.output_dir / f"{species}.meta.json"
        with meta_tmp.open("w", encoding="utf-8") as output:
            json.dump(metadata, output, ensure_ascii=False, indent=2)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(meta_tmp, meta_path)
        log(
            f"published {species}: {len(complete)}/{len(conditions)} contrasts, "
            f"{rows_written:,} rows"
        )
        return metadata

    def reset_incomplete_status(self, species: str, condition: str) -> None:
        status_path = self.status_path(species, condition)
        if self.result_path(species, condition).is_file() or not status_path.exists():
            return
        try:
            with status_path.open(encoding="utf-8") as source:
                status = json.load(source)
        except (OSError, ValueError):
            status = {}
        if status.get("state") in {"running", "queued"}:
            status_path.write_text(
                json.dumps(
                    {
                        "state": "error",
                        "error": "stale job reset by condition DEG index builder",
                    }
                ),
                encoding="utf-8",
            )

    def run_contrast(self, species: str, condition: str) -> bool:
        jid = job_id(species, condition)
        for attempt in range(1, self.retries + 2):
            self.reset_incomplete_status(species, condition)
            log(f"starting {species}: {condition} vs {REFERENCE} (attempt {attempt})")
            request_json(
                f"{self.api_base}/api/condition-compare/run",
                {
                    "species": species,
                    "conditionA": condition,
                    "conditionB": REFERENCE,
                },
            )
            deadline = time.monotonic() + self.timeout_seconds
            last_summary = ""
            while time.monotonic() < deadline:
                if self.result_path(species, condition).is_file():
                    log(f"completed {species}: {condition}")
                    return True
                try:
                    status = request_json(
                        f"{self.api_base}/api/condition-compare/status?"
                        + urllib.parse.urlencode({"jobId": jid})
                    )
                except urllib.error.HTTPError as exc:
                    status = {"state": "error", "error": f"HTTP {exc.code}"}
                state = status.get("state", "unknown")
                summary = (
                    f"{state} {status.get('progress', 0)}% "
                    f"{status.get('phase', '')}"
                ).strip()
                if summary != last_summary:
                    log(f"{species}/{condition}: {summary}")
                    last_summary = summary
                if state == "done":
                    return self.result_path(species, condition).is_file()
                if state == "error":
                    log(f"{species}/{condition} failed: {status.get('error', 'unknown error')}")
                    break
                time.sleep(self.poll_seconds)
            else:
                log(f"{species}/{condition} timed out after {self.timeout_seconds // 60} min")
            if attempt <= self.retries:
                time.sleep(5)
        return False

    def build(self, species_order: list[str], publish_only: bool) -> bool:
        by_species = {species: self.conditions(species) for species in species_order}
        for species in species_order:
            self.publish(species, by_species[species])
        if publish_only:
            return all(
                all(self.result_path(species, condition).is_file() for condition in conditions)
                for species, conditions in by_species.items()
            )

        failures: list[str] = []
        for species in species_order:
            for condition in by_species[species]:
                if self.result_path(species, condition).is_file():
                    continue
                if not self.run_contrast(species, condition):
                    failures.append(f"{species}: {condition}")
                self.publish(species, by_species[species])
        for species in species_order:
            self.publish(species, by_species[species])
        if failures:
            log("failed contrasts: " + "; ".join(failures))
            return False
        return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-base", default="http://127.0.0.1:8054")
    parser.add_argument("--compare-dir", default="/root/SkinDB/condition_compare_cache")
    parser.add_argument("--output-dir", default="/opt/SkinDB/runtime/condition_deg_index")
    parser.add_argument("--species", nargs="+", choices=("human", "mouse"), default=["human", "mouse"])
    parser.add_argument("--poll-seconds", type=int, default=5)
    parser.add_argument("--timeout-minutes", type=int, default=45)
    parser.add_argument("--retries", type=int, default=1)
    parser.add_argument("--publish-only", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    builder = IndexBuilder(args)
    lock_path = builder.output_dir / ".build.lock"
    with lock_path.open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            log("another condition DEG index builder is already running")
            return 2
        return 0 if builder.build(args.species, args.publish_only) else 1


if __name__ == "__main__":
    sys.exit(main())
