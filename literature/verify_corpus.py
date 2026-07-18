#!/usr/bin/env python3
"""Verify an external scSAID full-text corpus against the paper registry."""

from __future__ import annotations

import argparse
import csv
import hashlib
import sys
from collections import Counter
from pathlib import Path

# Keep the private server tools directory reproducible and free of generated
# bytecode artifacts when an operator runs this one-shot audit.
sys.dont_write_bytecode = True

from acquire_full_text import validate_html, validate_pdf, validate_xml


VALIDATORS = {
    "html": validate_html,
    "pdf": validate_pdf,
    "xml": validate_xml,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--registry",
        type=Path,
        default=Path(__file__).with_name("papers.tsv"),
        help="Normalized scSAID papers.tsv registry.",
    )
    parser.add_argument(
        "--corpus",
        type=Path,
        required=True,
        help="External directory containing manifest.tsv and article files.",
    )
    parser.add_argument(
        "--expect-downloaded",
        type=int,
        help="Fail unless exactly this many records have validated full text.",
    )
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def unique_by_id(
    rows: list[dict[str, str]], source: str, errors: list[str]
) -> dict[str, dict[str, str]]:
    indexed: dict[str, dict[str, str]] = {}
    for row_number, row in enumerate(rows, start=2):
        paper_id = row.get("paper_id", "").strip()
        if not paper_id:
            errors.append(f"{source}:{row_number}: paper_id is empty")
        elif paper_id in indexed:
            errors.append(f"{source}:{row_number}: duplicate paper_id {paper_id}")
        else:
            indexed[paper_id] = row
    return indexed


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    args = parse_args()
    errors: list[str] = []
    manifest_path = args.corpus / "manifest.tsv"
    if not args.registry.is_file():
        print(f"ERROR: registry not found: {args.registry}", file=sys.stderr)
        return 1
    if not manifest_path.is_file():
        print(f"ERROR: manifest not found: {manifest_path}", file=sys.stderr)
        return 1

    registry = unique_by_id(read_tsv(args.registry), str(args.registry), errors)
    manifest = unique_by_id(read_tsv(manifest_path), str(manifest_path), errors)

    missing = sorted(set(registry) - set(manifest))
    extra = sorted(set(manifest) - set(registry))
    if missing:
        errors.append("manifest is missing registry IDs: " + ", ".join(missing))
    if extra:
        errors.append("manifest has unknown registry IDs: " + ", ".join(extra))

    referenced_files: set[str] = set()
    status_counts: Counter[str] = Counter()
    format_counts: Counter[str] = Counter()

    for paper_id in sorted(set(registry) & set(manifest)):
        expected = registry[paper_id]
        row = manifest[paper_id]
        status = row.get("status", "").strip()
        status_counts[status] += 1

        for field in ("pmid", "pmcid", "doi", "title"):
            if row.get(field, "").strip() != expected.get(field, "").strip():
                errors.append(f"{paper_id}: manifest {field} does not match registry")

        if status == "unavailable":
            if row.get("filename", "").strip():
                errors.append(f"{paper_id}: unavailable record references a file")
            if not row.get("error", "").strip():
                errors.append(f"{paper_id}: unavailable record has no reason")
            continue
        if status != "downloaded":
            errors.append(f"{paper_id}: unsupported status {status!r}")
            continue

        content_format = row.get("format", "").strip().lower()
        validator = VALIDATORS.get(content_format)
        if validator is None:
            errors.append(f"{paper_id}: unsupported format {content_format!r}")
            continue
        format_counts[content_format] += 1

        filename = row.get("filename", "").strip()
        if not filename or Path(filename).name != filename:
            errors.append(f"{paper_id}: unsafe or empty filename {filename!r}")
            continue
        if filename in referenced_files:
            errors.append(f"{paper_id}: duplicate manifest filename {filename}")
        referenced_files.add(filename)

        path = args.corpus / filename
        if not path.is_file():
            errors.append(f"{paper_id}: article file is missing: {filename}")
            continue
        payload = path.read_bytes()
        problem = validator(payload)
        if problem:
            errors.append(f"{paper_id}: invalid {content_format}: {problem}")
        if path.suffix.lower() != f".{content_format}":
            errors.append(
                f"{paper_id}: filename extension does not match {content_format}"
            )
        if row.get("bytes", "").strip() != str(len(payload)):
            errors.append(f"{paper_id}: byte count does not match manifest")
        if row.get("sha256", "").strip().lower() != sha256(path):
            errors.append(f"{paper_id}: SHA-256 does not match manifest")
        if not row.get("source", "").strip() or not row.get("source_url", "").strip():
            errors.append(f"{paper_id}: downloaded record lacks source provenance")

    article_files = {
        path.name
        for path in args.corpus.iterdir()
        if path.is_file() and path.suffix.lower() in {".html", ".pdf", ".xml"}
    }
    unmanifested = sorted(article_files - referenced_files)
    if unmanifested:
        errors.append("unmanifested article files: " + ", ".join(unmanifested))

    downloaded = status_counts["downloaded"]
    if args.expect_downloaded is not None and downloaded != args.expect_downloaded:
        errors.append(
            f"downloaded count is {downloaded}, expected {args.expect_downloaded}"
        )

    print(
        f"Registry: {len(registry)} papers; manifest: {len(manifest)} records; "
        f"downloaded: {downloaded}; unavailable: {status_counts['unavailable']}; "
        f"formats: PDF={format_counts['pdf']}, XML={format_counts['xml']}, "
        f"HTML={format_counts['html']}"
    )
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Corpus verification passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
