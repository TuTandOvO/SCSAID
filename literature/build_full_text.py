#!/usr/bin/env python3
"""Build and verify canonical text for every article in a private corpus."""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path

sys.dont_write_bytecode = True


BLOCK_TAGS = {
    "abstract", "ack", "article-title", "body", "caption", "fig", "fn",
    "p", "ref", "ref-list", "sec", "table", "table-wrap", "title",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalize(value: str) -> str:
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r" *\n *", "\n", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()


def xml_text(path: Path) -> str:
    root = ET.parse(path).getroot()
    lines: list[str] = []

    def visit(node: ET.Element) -> None:
        tag = node.tag.rsplit("}", 1)[-1].lower()
        if tag in {"script", "style"}:
            return
        if tag in BLOCK_TAGS and lines and lines[-1] != "":
            lines.append("")
        if node.text and node.text.strip():
            lines.append(node.text.strip())
        for child in node:
            visit(child)
            if child.tail and child.tail.strip():
                lines.append(child.tail.strip())
        if tag in BLOCK_TAGS and lines and lines[-1] != "":
            lines.append("")

    visit(root)
    return normalize("\n".join(lines))


class ArticleHtmlParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.skip = 0
        self.lines: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in {"script", "style", "nav", "noscript"}:
            self.skip += 1
        elif tag in {"article", "section", "p", "h1", "h2", "h3", "h4", "li",
                     "figcaption", "caption", "tr", "br"}:
            self.lines.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style", "nav", "noscript"} and self.skip:
            self.skip -= 1
        elif tag in {"article", "section", "p", "h1", "h2", "h3", "h4", "li",
                     "figcaption", "caption", "tr"}:
            self.lines.append("\n")

    def handle_data(self, data: str) -> None:
        if not self.skip and data.strip():
            self.lines.append(data.strip())


def html_text(path: Path) -> str:
    parser = ArticleHtmlParser()
    parser.feed(path.read_text(encoding="utf-8", errors="replace"))
    return normalize(html.unescape(" ".join(parser.lines)))


def pdf_text(path: Path) -> str:
    try:
        result = subprocess.run(
            ["pdftotext", "-layout", "-enc", "UTF-8", str(path), "-"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise RuntimeError("pdftotext (Poppler) is required for PDF extraction") from exc
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"pdftotext rejected {path.name}") from exc
    pages = result.stdout.decode("utf-8", errors="replace").split("\f")
    rendered = []
    for number, page in enumerate(pages, start=1):
        page = normalize(page)
        if page:
            rendered.append(f"[PDF page {number}]\n{page}")
    return "\n\n".join(rendered)


def read_tsv(path: Path) -> tuple[list[dict[str, str]], list[str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        return list(reader), list(reader.fieldnames or [])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--registry", type=Path, default=Path(__file__).with_name("papers.tsv")
    )
    args = parser.parse_args()

    rows, _ = read_tsv(args.corpus / "manifest.tsv")
    registry_rows, _ = read_tsv(args.registry)
    registry = {row["paper_id"]: row for row in registry_rows}
    args.output.mkdir(parents=True, exist_ok=True)
    manifest_rows: list[dict[str, str]] = []

    for row in rows:
        paper_id = row["paper_id"]
        if row["status"] != "downloaded":
            raise ValueError(f"{paper_id}: full text is unavailable")
        source = args.corpus / row["filename"]
        extractor = {"xml": xml_text, "html": html_text, "pdf": pdf_text}.get(
            row["format"].lower()
        )
        if extractor is None:
            raise ValueError(f"{paper_id}: unsupported format {row['format']}")
        body = extractor(source)
        record = registry[paper_id]
        if len(body) < 1_000:
            raise ValueError(f"{paper_id}: extracted text is unexpectedly short")
        title_terms = [word.lower() for word in record["title"].split() if len(word) >= 7]
        if title_terms and sum(word in body.lower() for word in title_terms[:8]) < 3:
            raise ValueError(f"{paper_id}: extracted article title did not validate")

        document = normalize(
            "\n".join(
                [
                    f"Paper ID: {paper_id}",
                    f"PMID: {record['pmid']}",
                    f"DOI: {record['doi']}",
                    f"Title: {record['title']}",
                    "",
                    body,
                ]
            )
        ) + "\n"
        destination = args.output / f"{paper_id}.txt"
        destination.write_text(document, encoding="utf-8")
        destination.chmod(0o640)
        manifest_rows.append(
            {
                "paper_id": paper_id,
                "pmid": record["pmid"],
                "doi": record["doi"],
                "source_filename": row["filename"],
                "source_sha256": row["sha256"],
                "text_filename": destination.name,
                "characters": str(len(document)),
                "text_sha256": sha256(destination),
            }
        )

    fields = list(manifest_rows[0])
    with (args.output / "manifest.tsv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=fields, delimiter="\t", lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(manifest_rows)
    print(f"Built validated canonical text for {len(manifest_rows)} papers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
