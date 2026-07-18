#!/usr/bin/env python3
"""Build exact accession-level sample metadata and canonical paper selection."""

from __future__ import annotations

import argparse
import gzip
import json
import re
import sys
import time
import urllib.request
from html.parser import HTMLParser
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

USER_AGENT = "scSAID-sample-metadata/1.0 (https://skin-scsaid.com)"


def request(url: str) -> bytes:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/json,text/html,*/*",
        },
    )
    with urllib.request.urlopen(req, timeout=90) as response:
        return response.read()


def geo_bucket(accession: str) -> str:
    return re.sub(r"\d{3}$", "nnn", accession)


def parse_soft(payload: bytes) -> dict[str, dict[str, Any]]:
    text = gzip.decompress(payload).decode("utf-8", errors="replace")
    samples: dict[str, dict[str, Any]] = {}
    current: dict[str, Any] | None = None
    for line in text.splitlines():
        if line.startswith("^SAMPLE = "):
            accession = line.split("=", 1)[1].strip()
            current = {"sample_accession": accession, "fields": {}}
            samples[accession] = current
            continue
        if line.startswith("^") and current is not None:
            current = None
            continue
        if current is None or not line.startswith("!Sample_") or " = " not in line:
            continue
        key, value = line[8:].split(" = ", 1)
        fields = current["fields"]
        if key in fields:
            if not isinstance(fields[key], list):
                fields[key] = [fields[key]]
            fields[key].append(value.strip())
        else:
            fields[key] = value.strip()
    return samples


def compact_geo(record: dict[str, Any], study: str) -> dict[str, Any]:
    fields = record["fields"]
    allowed = {
        "title", "geo_accession", "status", "submission_date", "last_update_date",
        "type", "source_name_ch1", "organism_ch1", "taxid_ch1",
        "characteristics_ch1", "growth_protocol_ch1", "treatment_protocol_ch1",
        "extract_protocol_ch1", "molecule_ch1", "data_processing",
        "platform_id", "instrument_model", "library_selection", "library_source",
        "library_strategy", "relation", "description",
    }
    exact = {key: value for key, value in fields.items() if key in allowed}
    return {
        "sample_accession": record["sample_accession"],
        "parent_study_accession": study,
        "repository": "NCBI GEO",
        "source_url": (
            "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc="
            + record["sample_accession"]
        ),
        "metadata": exact,
    }


class TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.in_cell = False
        self.cell: list[str] = []
        self.row: list[str] = []
        self.rows: list[list[str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"th", "td"}:
            self.in_cell = True
            self.cell = []

    def handle_endtag(self, tag: str) -> None:
        if tag in {"th", "td"} and self.in_cell:
            self.row.append(" ".join(self.cell).strip())
            self.in_cell = False
        elif tag == "tr" and self.row:
            self.rows.append(self.row)
            self.row = []

    def handle_data(self, data: str) -> None:
        if self.in_cell and data.strip():
            self.cell.append(data.strip())


def table_fields(url: str) -> dict[str, str]:
    parser = TableParser()
    parser.feed(request(url).decode("utf-8", errors="replace"))
    fields: dict[str, str] = {}
    for row in parser.rows:
        if len(row) >= 2 and row[0] and len(row[0]) < 80:
            fields.setdefault(row[0], " ".join(row[1:]).strip())
    return fields


def samc_metadata(accession: str, study: str) -> dict[str, Any]:
    url = f"https://ngdc.cncb.ac.cn/gwh/api/public/bioSample/{accession}"
    raw = json.loads(request(url))
    attribute = raw.get("sampleAttribute") or {}
    taxon = attribute.get("taxon") or raw.get("taxon") or {}
    exact = {
        "name": raw.get("name"),
        "sample_type": (raw.get("sampletype") or {}).get("sampleTypeName"),
        "organism": taxon.get("name"),
        "taxon_id": taxon.get("taxonId"),
    }
    for key in (
        "age", "ageUnit", "sex", "tissue", "treatment", "disease", "diseaseStage",
        "healthState", "genotype", "cellType", "cellSubtype", "devStage",
        "isolationSource", "phenotype", "strain", "biomaterialProvider",
        "collectionDate", "growthProtocol",
    ):
        value = attribute.get(key)
        if value not in (None, "", []):
            exact[key] = value
    return {
        "sample_accession": accession,
        "parent_study_accession": study,
        "repository": "CNCB-NGDC BioSample",
        "source_url": f"https://ngdc.cncb.ac.cn/biosample/browse/{accession}",
        "metadata": exact,
    }


def hrr_metadata(accession: str, study: str) -> dict[str, Any]:
    base = "https://ngdc.cncb.ac.cn/gsa-human/browse/"
    run = table_fields(base + "runDetail/" + accession)
    exact: dict[str, Any] = {"run": run}
    sample_id = run.get("Sample", "")
    individual_id = run.get("Individual", "")
    experiment_id = run.get("Experiment", "")
    if sample_id:
        exact["sample"] = table_fields(base + "sampleDetail/" + sample_id)
    if individual_id:
        exact["individual"] = table_fields(base + "individualDetail/" + individual_id)
    if experiment_id:
        exact["experiment"] = table_fields(base + "experimentDetail/" + experiment_id)
    if run.get("Accession") != accession or run.get("Study accession") != study:
        raise ValueError(f"{accession}: GSA-Human accession/study mismatch")
    return {
        "sample_accession": accession,
        "parent_study_accession": study,
        "repository": "CNCB-NGDC GSA-Human",
        "source_url": base + "runDetail/" + accession,
        "metadata": exact,
    }


def build_paper_selection(registry: dict[str, Any]) -> list[dict[str, Any]]:
    papers = {paper["paper_id"]: paper for paper in registry["papers"]}
    primary: dict[str, list[dict[str, Any]]] = {}
    for link in registry["dataset_paper_links"]:
        if link.get("relation") == "primary_dataset_publication":
            primary.setdefault(link["said"], []).append(link)
    selection = []
    for dataset in registry["datasets"]:
        links = primary.get(dataset["said"], [])
        if len(links) > 1:
            raise ValueError(f"{dataset['said']}: multiple canonical primary papers")
        item: dict[str, Any] = {
            "said": dataset["said"],
            "sample_accession": dataset["sample_accession"],
            "study_accession": dataset["study_accession"],
            "status": "verified_primary" if links else "no_verified_primary",
        }
        if links:
            link = links[0]
            paper = papers[link["paper_id"]]
            item.update(
                {
                    "paper_id": link["paper_id"],
                    "pmid": paper.get("pmid", ""),
                    "doi": paper.get("doi", ""),
                    "title": paper.get("title", ""),
                    "journal": paper.get("journal", ""),
                    "year": paper.get("year", ""),
                    "evidence": link.get("evidence", ""),
                    "verified_on": link.get("verified_on", ""),
                }
            )
        selection.append(item)
    return selection


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--registry", type=Path, default=Path(__file__).with_name("registry.json")
    )
    parser.add_argument(
        "--output", type=Path, default=Path(__file__).with_name("sample_context.json")
    )
    parser.add_argument(
        "--paper-output",
        type=Path,
        default=Path(__file__).with_name("canonical_sample_papers.json"),
    )
    parser.add_argument("--cache", type=Path)
    parser.add_argument("--delay", type=float, default=0.2)
    args = parser.parse_args()
    registry = json.loads(args.registry.read_text(encoding="utf-8"))
    cache = args.cache
    if cache:
        cache.mkdir(parents=True, exist_ok=True)

    by_study: dict[str, list[dict[str, Any]]] = {}
    for dataset in registry["datasets"]:
        by_study.setdefault(dataset["study_accession"], []).append(dataset)

    contexts: dict[str, dict[str, Any]] = {}
    for study, datasets in by_study.items():
        if study.startswith("GSE"):
            cache_path = cache / f"{study}.soft.gz" if cache else None
            if cache_path and cache_path.is_file():
                payload = cache_path.read_bytes()
            else:
                url = (
                    "https://ftp.ncbi.nlm.nih.gov/geo/series/"
                    f"{geo_bucket(study)}/{study}/soft/{study}_family.soft.gz"
                )
                payload = request(url)
                if cache_path:
                    cache_path.write_bytes(payload)
            records = parse_soft(payload)
            for dataset in datasets:
                accession = dataset["sample_accession"]
                if accession not in records:
                    raise ValueError(f"{study}: exact sample {accession} is absent")
                contexts[dataset["said"]] = compact_geo(records[accession], study)
        else:
            for dataset in datasets:
                accession = dataset["sample_accession"]
                if accession.startswith("SAMC"):
                    contexts[dataset["said"]] = samc_metadata(accession, study)
                elif accession.startswith("HRR"):
                    contexts[dataset["said"]] = hrr_metadata(accession, study)
                else:
                    raise ValueError(f"{dataset['said']}: unsupported sample accession")
                time.sleep(args.delay)
        time.sleep(args.delay)

    expected = {dataset["said"] for dataset in registry["datasets"]}
    if set(contexts) != expected or len(contexts) != 252:
        raise ValueError("sample context coverage is incomplete or duplicated")
    for dataset in registry["datasets"]:
        context = contexts[dataset["said"]]
        if context["sample_accession"] != dataset["sample_accession"]:
            raise ValueError(f"{dataset['said']}: sample context mismatch")

    payload = {
        "schema_version": 1,
        "generated_from": "exact repository sample/run records",
        "count": len(contexts),
        "samples": contexts,
    }
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    papers = build_paper_selection(registry)
    args.paper_output.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "selection_policy": "verified primary publication only",
                "count": len(papers),
                "samples": papers,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(
        f"Built {len(contexts)} exact sample contexts and "
        f"{sum(row['status'] == 'verified_primary' for row in papers)} canonical links"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
