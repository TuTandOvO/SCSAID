#!/usr/bin/env python3
"""Acquire legally available full text for the scSAID literature registry.

The script resolves free article files through PMC, Europe PMC, and Unpaywall,
writes them to an external output directory, validates the downloaded files,
and records a checksum-bearing manifest. It does not attempt to bypass
paywalls.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path
from typing import Any


USER_AGENT = (
    "scSAID-literature-acquisition/1.0 "
    "(https://skin-scsaid.com; contact: admin@skin-scsaid.com)"
)
MIN_PDF_BYTES = 10_000
KNOWN_OPEN_FULL_TEXTS = {
    "PMID_34274346": (
        "University of Edinburgh Research Explorer",
        "https://www.pure.ed.ac.uk/ws/portalfiles/portal/329640359/"
        "PIIS0022202X21014536.pdf",
        "pdf",
    ),
    "PMID_34380039": (
        "Cell Reports full-text HTML",
        "https://www.cell.com/cell-reports/fulltext/S2211-1247(21)00955-4",
        "html",
    ),
    "PMID_36994549": (
        "PubMed Central full-text HTML",
        "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10183823/",
        "html",
    ),
    "PMID_37318953": (
        "Cell Reports full-text HTML",
        "https://www.cell.com/cell-reports/fulltext/S2211-1247(23)00654-X",
        "html",
    ),
    "PMID_37972124": (
        "Oxford University Research Archive",
        "https://ora.ox.ac.uk/objects/"
        "uuid%3A021cb1c7-c5ab-40ac-908d-12138a0f4962/files/rsj139294q",
        "pdf",
    ),
    "PMID_38739763": (
        "Oxford Academic",
        "https://academic.oup.com/bjd/article-pdf/191/3/397/58820409/ljae193.pdf",
        "pdf",
    ),
    "PMID_38815020": (
        "Medical University of Bialystok institutional repository (CC BY 4.0)",
        "https://ppm.edu.pl/docstore/download/"
        "UMB82e0f4436cff4a9aa0bc45b42e114763/0000074854.pdf"
        "?entityType=article&entityId=UMBc31df4e362054d7ab9cebf52979dec31",
        "pdf",
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--registry",
        type=Path,
        default=Path(__file__).with_name("papers.tsv"),
        help="Path to the normalized papers.tsv registry.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help="External directory in which article files and manifest.tsv are written.",
    )
    parser.add_argument(
        "--email",
        default="admin@skin-scsaid.com",
        help="Contact email supplied to the Unpaywall API.",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.15,
        help="Delay in seconds between remote requests.",
    )
    parser.add_argument(
        "--only-missing",
        action="store_true",
        help="Keep already validated files and acquire only missing papers.",
    )
    parser.add_argument(
        "--prefer-pmc-xml",
        action="store_true",
        help=(
            "Prefer complete NLM/JATS XML over PDF for PMC articles. "
            "This is substantially smaller and better suited to text analysis."
        ),
    )
    return parser.parse_args()


def request_bytes(url: str, accept: str, attempts: int = 2) -> tuple[bytes, str]:
    last_error: Exception | None = None
    for attempt in range(attempts):
        headers = {
            "Accept": accept,
            "User-Agent": USER_AGENT,
        }
        # The repository issues this non-identifying clearance cookie before
        # serving its publicly deposited CC BY article file.
        if urllib.parse.urlparse(url).hostname == "ppm.edu.pl":
            headers["Cookie"] = "clearance=true"
        request = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                return response.read(), response.geturl()
        except (urllib.error.URLError, TimeoutError) as exc:
            last_error = exc
            if attempt + 1 < attempts:
                time.sleep(1.5 * (attempt + 1))
    assert last_error is not None
    raise last_error


def request_json(url: str) -> dict[str, Any]:
    payload, _ = request_bytes(url, "application/json")
    return json.loads(payload.decode("utf-8"))


def europe_pmc_record(pmid: str) -> dict[str, Any] | None:
    query = urllib.parse.quote(f"EXT_ID:{pmid} AND SRC:MED")
    url = (
        "https://www.ebi.ac.uk/europepmc/webservices/rest/search"
        f"?query={query}&format=json&resultType=core"
    )
    result = request_json(url).get("resultList", {}).get("result", [])
    return result[0] if result else None


def unpaywall_record(doi: str, email: str) -> dict[str, Any] | None:
    encoded_doi = urllib.parse.quote(doi, safe="")
    encoded_email = urllib.parse.quote(email)
    url = f"https://api.unpaywall.org/v2/{encoded_doi}?email={encoded_email}"
    try:
        return request_json(url)
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None
        raise


class _PdfLinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(
        self, tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        if tag != "a":
            return
        href = dict(attrs).get("href") or ""
        if "/pdf/" in href.lower() or href.lower().startswith("pdf/"):
            self.links.append(href)


def pubmed_central_pdf_url(pmcid: str) -> str | None:
    article_url = f"https://pmc.ncbi.nlm.nih.gov/articles/{pmcid}/"
    payload, final_url = request_bytes(article_url, "text/html")
    parser = _PdfLinkParser()
    parser.feed(payload.decode("utf-8", errors="ignore"))
    for href in parser.links:
        if "/bin/" not in href.lower() and "supp" not in href.lower():
            return urllib.parse.urljoin(final_url, href)
    return None


def pmc_aws_article_files(pmcid: str) -> dict[str, str]:
    """Return current article objects from NCBI's public PMC AWS dataset."""

    bucket = "https://pmc-oa-opendata.s3.amazonaws.com/"
    namespace = {"s3": "http://s3.amazonaws.com/doc/2006-03-01/"}
    prefix_query = urllib.parse.urlencode(
        {"list-type": "2", "prefix": f"{pmcid}.", "delimiter": "/"}
    )
    payload, _ = request_bytes(f"{bucket}?{prefix_query}", "application/xml,text/xml")
    root = ET.fromstring(payload)
    prefixes = [
        node.text or ""
        for node in root.findall(".//s3:CommonPrefixes/s3:Prefix", namespace)
    ]
    versions: list[tuple[int, str]] = []
    for prefix in prefixes:
        match = re.fullmatch(rf"{re.escape(pmcid)}\.(\d+)/", prefix)
        if match:
            versions.append((int(match.group(1)), prefix))
    if not versions:
        return {}

    _, current_prefix = max(versions)
    object_query = urllib.parse.urlencode(
        {"list-type": "2", "prefix": current_prefix}
    )
    payload, _ = request_bytes(f"{bucket}?{object_query}", "application/xml,text/xml")
    root = ET.fromstring(payload)
    keys = [
        node.text or "" for node in root.findall(".//s3:Contents/s3:Key", namespace)
    ]

    files: dict[str, str] = {}
    version_name = current_prefix.rstrip("/")
    for extension in ("pdf", "xml", "txt"):
        exact_key = f"{current_prefix}{version_name}.{extension}"
        key = next(
            (
                item
                for item in keys
                if item == exact_key
            ),
            "",
        )
        if key:
            files[extension] = bucket + urllib.parse.quote(key, safe="/")
    return files


def pdf_candidates(
    paper: dict[str, str],
    epmc: dict[str, Any] | None,
    unpaywall: dict[str, Any] | None,
    pmc_pdf_url: str | None,
) -> list[tuple[str, str]]:
    candidates: list[tuple[str, str]] = []

    if pmc_pdf_url:
        candidates.append(("PubMed Central", pmc_pdf_url))

    if epmc:
        for item in epmc.get("fullTextUrlList", {}).get("fullTextUrl", []):
            if (
                item.get("documentStyle") == "pdf"
                and item.get("availabilityCode") == "F"
                and item.get("site") != "Europe_PMC"
                and item.get("url")
            ):
                candidates.append(("Europe PMC", item["url"]))

    if unpaywall and unpaywall.get("is_oa"):
        locations = []
        if unpaywall.get("best_oa_location"):
            locations.append(unpaywall["best_oa_location"])
        locations.extend(unpaywall.get("oa_locations") or [])
        for location in locations:
            url = location.get("url_for_pdf")
            if url:
                candidates.append(("Unpaywall-listed open access", url))

    deduplicated: list[tuple[str, str]] = []
    seen: set[str] = set()
    for source, url in candidates:
        if url.startswith("http://"):
            url = "https://" + url.removeprefix("http://")
        if url not in seen:
            seen.add(url)
            deduplicated.append((source, url))
    return deduplicated


def slugify(title: str, maximum: int = 90) -> str:
    slug = re.sub(r"[^A-Za-z0-9]+", "_", title).strip("_")
    return slug[:maximum].rstrip("_") or "paper"


def validate_pdf(payload: bytes) -> str | None:
    if len(payload) < MIN_PDF_BYTES:
        return f"response was only {len(payload)} bytes"
    if not payload.lstrip().startswith(b"%PDF-"):
        return "response was not a PDF"
    if b"%%EOF" not in payload[-4096:]:
        return "PDF end marker was missing"
    return None


def validate_xml(payload: bytes) -> str | None:
    if len(payload) < MIN_PDF_BYTES:
        return f"response was only {len(payload)} bytes"
    try:
        root = ET.fromstring(payload)
    except ET.ParseError as exc:
        return f"response was not valid XML: {exc}"
    if root.tag.rsplit("}", 1)[-1] != "article":
        return f"XML root was {root.tag!r}, not an article"
    return None


def validate_html(payload: bytes) -> str | None:
    if len(payload) < MIN_PDF_BYTES:
        return f"response was only {len(payload)} bytes"
    text = payload.decode("utf-8", errors="ignore").lower()
    if "<html" not in text or "<article" not in text or "<h1" not in text:
        return "response was not a complete article HTML document"
    blocked_markers = (
        "are you a robot?",
        "checking your browser",
        "captcha challenge",
        "access denied",
    )
    if any(marker in text for marker in blocked_markers):
        return "response was an access-interstitial page, not article full text"
    return None


def sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def read_registry(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def prior_manifest(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        return {}
    with path.open(newline="", encoding="utf-8") as handle:
        return {
            row["paper_id"]: row
            for row in csv.DictReader(handle, delimiter="\t")
            if row.get("paper_id")
        }


def acquire_one(
    paper: dict[str, str],
    output: Path,
    email: str,
    delay: float,
    prefer_pmc_xml: bool = False,
) -> dict[str, str]:
    paper_id = paper["paper_id"]
    result = {
        "paper_id": paper_id,
        "pmid": paper.get("pmid", ""),
        "pmcid": paper.get("pmcid", ""),
        "doi": paper.get("doi", ""),
        "title": paper.get("title", ""),
        "status": "unavailable",
        "format": "",
        "source": "",
        "source_url": "",
        "filename": "",
        "bytes": "",
        "sha256": "",
        "error": "",
    }

    errors: list[str] = []
    known_open_full_text = KNOWN_OPEN_FULL_TEXTS.get(paper_id)
    if known_open_full_text:
        source, url, content_format = known_open_full_text
        validator = {
            "html": validate_html,
            "pdf": validate_pdf,
            "xml": validate_xml,
        }[content_format]
        accept = {
            "html": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.1",
            "pdf": "application/pdf,application/octet-stream;q=0.9,*/*;q=0.1",
            "xml": "application/xml,text/xml;q=0.9,*/*;q=0.1",
        }[content_format]
        try:
            payload, final_url = request_bytes(url, accept)
            problem = validator(payload)
            if problem:
                raise ValueError(problem)
            filename = (
                f"{paper_id}__{slugify(paper['title'])}.{content_format}"
            )
            (output / filename).write_bytes(payload)
            result.update(
                {
                    "status": "downloaded",
                    "format": content_format,
                    "source": source,
                    "source_url": final_url,
                    "filename": filename,
                    "bytes": str(len(payload)),
                    "sha256": sha256(payload),
                    "error": "",
                }
            )
            return result
        except Exception as exc:
            errors.append(f"{source} download {url}: {exc}")

    epmc: dict[str, Any] | None = None
    unpaywall: dict[str, Any] | None = None
    pmc_pdf_url: str | None = None
    pmc_files: dict[str, str] = {}
    pmcid = paper.get("pmcid", "").strip()
    if pmcid:
        try:
            pmc_files = pmc_aws_article_files(pmcid)
        except Exception as exc:
            errors.append(f"NCBI PMC AWS lookup: {exc}")
        time.sleep(delay)

    if prefer_pmc_xml and pmc_files.get("xml"):
        url = pmc_files["xml"]
        try:
            payload, final_url = request_bytes(
                url, "application/xml,text/xml;q=0.9,*/*;q=0.1"
            )
            problem = validate_xml(payload)
            if problem:
                raise ValueError(problem)
            filename = f"{paper_id}__{slugify(paper['title'])}.xml"
            (output / filename).write_bytes(payload)
            result.update(
                {
                    "status": "downloaded",
                    "format": "xml",
                    "source": "NCBI PMC article dataset on AWS",
                    "source_url": final_url,
                    "filename": filename,
                    "bytes": str(len(payload)),
                    "sha256": sha256(payload),
                    "error": "",
                }
            )
            return result
        except Exception as exc:
            errors.append(f"NCBI PMC AWS XML download {url}: {exc}")

    if pmc_files.get("pdf"):
        url = pmc_files["pdf"]
        try:
            payload, final_url = request_bytes(
                url, "application/pdf,application/octet-stream;q=0.9,*/*;q=0.1"
            )
            problem = validate_pdf(payload)
            if problem:
                raise ValueError(problem)
            filename = f"{paper_id}__{slugify(paper['title'])}.pdf"
            (output / filename).write_bytes(payload)
            result.update(
                {
                    "status": "downloaded",
                    "format": "pdf",
                    "source": "NCBI PMC article dataset on AWS",
                    "source_url": final_url,
                    "filename": filename,
                    "bytes": str(len(payload)),
                    "sha256": sha256(payload),
                    "error": "",
                }
            )
            return result
        except Exception as exc:
            errors.append(f"NCBI PMC AWS PDF download {url}: {exc}")

    try:
        epmc = europe_pmc_record(paper["pmid"])
    except Exception as exc:  # continue with the next resolver
        errors.append(f"Europe PMC metadata: {exc}")
    time.sleep(delay)

    doi = paper.get("doi", "").strip()
    if doi:
        try:
            unpaywall = unpaywall_record(doi, email)
        except Exception as exc:  # continue with Europe PMC
            errors.append(f"Unpaywall metadata: {exc}")
        time.sleep(delay)

    candidates = pdf_candidates(paper, epmc, unpaywall, pmc_pdf_url)
    if not candidates:
        errors.append("no freely available full-text location was returned")

    for source, url in candidates:
        try:
            payload, final_url = request_bytes(
                url, "application/pdf,application/octet-stream;q=0.9,*/*;q=0.1"
            )
        except Exception as exc:
            errors.append(f"{source} download {url}: {exc}")
            continue
        problem = validate_pdf(payload)
        if problem:
            errors.append(f"{source} download {url}: {problem}")
            continue

        filename = f"{paper_id}__{slugify(paper['title'])}.pdf"
        destination = output / filename
        destination.write_bytes(payload)
        result.update(
            {
                "status": "downloaded",
                "format": "pdf",
                "source": source,
                "source_url": final_url,
                "filename": filename,
                "bytes": str(len(payload)),
                "sha256": sha256(payload),
                "error": "",
            }
        )
        return result

    if pmc_files.get("xml"):
        url = pmc_files["xml"]
        try:
            payload, final_url = request_bytes(
                url, "application/xml,text/xml;q=0.9,*/*;q=0.1"
            )
            problem = validate_xml(payload)
            if problem:
                raise ValueError(problem)
            filename = f"{paper_id}__{slugify(paper['title'])}.xml"
            (output / filename).write_bytes(payload)
            result.update(
                {
                    "status": "downloaded",
                    "format": "xml",
                    "source": "NCBI PMC article dataset on AWS",
                    "source_url": final_url,
                    "filename": filename,
                    "bytes": str(len(payload)),
                    "sha256": sha256(payload),
                    "error": "",
                }
            )
            return result
        except Exception as exc:
            errors.append(f"NCBI PMC AWS XML download {url}: {exc}")

    result["error"] = " | ".join(errors)
    return result


def write_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    fields = [
        "paper_id",
        "pmid",
        "pmcid",
        "doi",
        "title",
        "status",
        "format",
        "source",
        "source_url",
        "filename",
        "bytes",
        "sha256",
        "error",
    ]
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    args = parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest_path = args.output / "manifest.tsv"
    previous = prior_manifest(manifest_path) if args.only_missing else {}
    rows: list[dict[str, str]] = []
    papers = read_registry(args.registry)

    for index, paper in enumerate(papers, start=1):
        paper_id = paper["paper_id"]
        prior = previous.get(paper_id)
        if prior and prior.get("status") == "downloaded":
            existing = args.output / prior.get("filename", "")
            if existing.is_file():
                payload = existing.read_bytes()
                content_format = prior.get("format") or existing.suffix.lstrip(".")
                validators = {
                    "html": validate_html,
                    "xml": validate_xml,
                    "pdf": validate_pdf,
                }
                validator = validators.get(content_format)
                if validator is None:
                    print(
                        f"[{index}] {paper_id}: unsupported prior format "
                        f"{content_format!r}",
                        flush=True,
                    )
                elif validator(payload) is None and sha256(payload) == prior["sha256"]:
                    prior["format"] = content_format
                    rows.append(prior)
                    print(f"[{index}] {paper_id}: already verified", flush=True)
                    continue

        print(f"[{index}] {paper_id}: resolving", flush=True)
        row = acquire_one(
            paper,
            args.output,
            args.email,
            args.delay,
            prefer_pmc_xml=args.prefer_pmc_xml,
        )
        rows.append(row)
        checkpoint = list(rows)
        if args.only_missing:
            # Preserve every unprocessed prior row if acquisition is
            # interrupted. A later verifier can then identify a missing file
            # without the existing 56-row manifest being truncated.
            for remaining in papers[index:]:
                prior_remaining = previous.get(remaining["paper_id"])
                if prior_remaining:
                    checkpoint.append(prior_remaining)
        write_manifest(manifest_path, checkpoint)
        print(f"    {row['status']}: {row['source'] or row['error']}", flush=True)

    write_manifest(manifest_path, rows)
    downloaded = sum(row["status"] == "downloaded" for row in rows)
    pdfs = sum(
        row["status"] == "downloaded" and row.get("format") == "pdf"
        for row in rows
    )
    xmls = sum(
        row["status"] == "downloaded" and row.get("format") == "xml"
        for row in rows
    )
    htmls = sum(
        row["status"] == "downloaded" and row.get("format") == "html"
        for row in rows
    )
    print(
        f"Completed: {downloaded}/{len(rows)} full texts downloaded "
        f"({pdfs} PDF, {xmls} XML, {htmls} HTML); "
        f"{len(rows) - downloaded} unavailable.",
        flush=True,
    )
    return 0 if downloaded == len(rows) else 2


if __name__ == "__main__":
    sys.exit(main())
