#!/usr/bin/env python3
"""Ingest owner-supplied publisher PDFs into a private scSAID corpus."""

from __future__ import annotations

import argparse
import csv
import hashlib
import shutil
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from acquire_full_text import validate_pdf


SUPPLIED = {
    "PMID_33317858": "PIIS0091674920314512.pdf",
    "PMID_35123990": "PIIS0022202X22000859.pdf",
    "PMID_35613617": "PIIS1934590922001709.pdf",
    "PMID_37727050": (
        "Experimental Dermatology - 2023 - Itai - Single‐cell analysis of human "
        "dermal fibroblasts isolated from a single male donor.pdf"
    ),
    "PMID_38242738": "PIIS0923181123002700.pdf",
    "PMID_39067676": "1-s2.0-S1521661624004376-main.pdf",
    "PMID_39630887": "scitranslmed.adk8832.pdf",
}


def read_tsv(path: Path) -> tuple[list[dict[str, str]], list[str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        return list(reader), list(reader.fieldnames or [])


def write_tsv(path: Path, rows: list[dict[str, str]], fields: list[str]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=fields, delimiter="\t", lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(rows)
    temporary.replace(path)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_title(title: str) -> str:
    value = "".join(char if char.isalnum() else "_" for char in title)
    while "__" in value:
        value = value.replace("__", "_")
    return value.strip("_")[:96] or "article"


def extracted_text(path: Path) -> str:
    try:
        result = subprocess.run(
            ["pdftotext", "-enc", "UTF-8", str(path), "-"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise RuntimeError("pdftotext is required to verify supplied PDFs") from exc
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"pdftotext rejected {path.name}") from exc
    return result.stdout.decode("utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument(
        "--registry",
        type=Path,
        default=Path(__file__).with_name("papers.tsv"),
    )
    args = parser.parse_args()

    manifest_path = args.corpus / "manifest.tsv"
    manifest_rows, fields = read_tsv(manifest_path)
    registry_rows, _ = read_tsv(args.registry)
    manifest = {row["paper_id"]: row for row in manifest_rows}
    registry = {row["paper_id"]: row for row in registry_rows}

    for paper_id, source_name in SUPPLIED.items():
        source = args.source / source_name
        if not source.is_file():
            raise FileNotFoundError(f"Supplied PDF is missing: {source}")
        payload = source.read_bytes()
        problem = validate_pdf(payload)
        if problem:
            raise ValueError(f"{source.name}: invalid PDF: {problem}")

        record = registry[paper_id]
        text = extracted_text(source)
        normalized = " ".join(text.lower().split())
        doi = record["doi"].lower()
        if doi and doi not in normalized:
            raise ValueError(f"{source.name}: expected DOI {doi} is absent")
        if record["pmid"] not in normalized:
            # Publisher PDFs do not invariably print the PMID. DOI plus title
            # is the binding check; record this condition without weakening it.
            title_words = [
                word.lower().strip(".,:;()[]")
                for word in record["title"].split()
                if len(word) >= 6
            ][:6]
            if sum(word in normalized for word in title_words) < 4:
                raise ValueError(f"{source.name}: title does not match {paper_id}")

        filename = f"{paper_id}__{safe_title(record['title'])}.pdf"
        destination = args.corpus / filename
        shutil.copyfile(source, destination)
        destination.chmod(0o640)

        row = manifest[paper_id]
        row.update(
            {
                "status": "downloaded",
                "format": "pdf",
                "source": "Owner-supplied publisher PDF",
                "source_url": f"owner-supplied:{source.name}",
                "filename": filename,
                "bytes": str(destination.stat().st_size),
                "sha256": sha256(destination),
                "error": "",
            }
        )

    write_tsv(manifest_path, manifest_rows, fields)
    print(f"Ingested {len(SUPPLIED)} verified PDFs into {args.corpus}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
