#!/usr/bin/env python3
"""Corpus source downloader, extractor, staging builder, and report generator.

The pipeline is intentionally conservative: generated material goes into a
staging database and reports, never into the production corpus.
"""

from __future__ import annotations

import argparse
import csv
import dataclasses
import hashlib
import html
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import textwrap
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

try:
    import yaml
except ImportError:  # pragma: no cover - checked at runtime
    yaml = None


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "corpus_sources" / "source_catalog.json"
GENERATED_ROOT = ROOT / "corpus_sources"
RAW_DIR = GENERATED_ROOT / "raw"
TEXT_DIR = GENERATED_ROOT / "text"
STAGING_DIR = GENERATED_ROOT / "staging"
REPORTS_DIR = GENERATED_ROOT / "reports"
STAGING_DB = STAGING_DIR / "corpus_staging.sqlite"
HORARIA_YAML = Path("/Users/eduardoariasbravo/Developer/horaria/horaria/textos.yaml")
HORARIA_REPORT = Path("/Users/eduardoariasbravo/Developer/horaria/docs/fase1_6_informe.md")
LOCAL_LILLY_TEXT = Path("/Users/eduardoariasbravo/Developer/horaria/fuentes/lilly_christian_astrology_completo.txt")
PD_SEED_SQL = ROOT / "Resources" / "migrations" / "001_primary_direction_meanings.sql"


SEARCH_TERMS = {
    "primary_directions": [
        "direction",
        "directions",
        "directed",
        "promissor",
        "significator",
        "ascendant",
        "midheaven",
        "hyleg",
        "radical",
    ],
    "solar_return": [
        "revolution",
        "annual",
        "return",
        "solar",
        "sun return",
        "profection",
    ],
    "lunar_return": [
        "moon",
        "lunar",
        "lunation",
        "monthly",
        "return",
        "revolution",
    ],
}


@dataclasses.dataclass
class SourceResult:
    source_id: str
    status: str
    path: str | None = None
    sha256: str | None = None
    bytes: int | None = None
    error: str | None = None


def ensure_dirs() -> None:
    for directory in (RAW_DIR, TEXT_DIR, STAGING_DIR, REPORTS_DIR):
        directory.mkdir(parents=True, exist_ok=True)


def load_catalog() -> dict[str, Any]:
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def output_path_for(source: dict[str, Any]) -> Path:
    suffix = {
        "pdf": ".pdf",
        "djvu": ".djvu",
        "html": ".html",
        "txt": ".txt",
    }.get(source["format"], ".bin")
    return RAW_DIR / f"{source['id']}{suffix}"


def download_sources(force: bool = False) -> list[SourceResult]:
    ensure_dirs()
    results: list[SourceResult] = []
    headers = {
        "User-Agent": "AstroMalikCorpusBot/1.0 (+local research; contact: local-user)"
    }

    for source in load_catalog()["sources"]:
        destination = output_path_for(source)
        if destination.exists() and not force:
            results.append(
                SourceResult(
                    source_id=source["id"],
                    status="cached",
                    path=str(destination),
                    sha256=sha256_file(destination),
                    bytes=destination.stat().st_size,
                )
            )
            continue

        try:
            download_url(source["url"], destination, headers)
            results.append(
                SourceResult(
                    source_id=source["id"],
                    status="downloaded",
                    path=str(destination),
                    sha256=sha256_file(destination),
                    bytes=destination.stat().st_size,
                )
            )
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            results.append(
                SourceResult(source_id=source["id"], status="failed", error=str(error))
            )

    write_json(REPORTS_DIR / "download_manifest.json", [dataclasses.asdict(r) for r in results])
    return results


def download_url(url: str, destination: Path, headers: dict[str, str]) -> None:
    """Download a URL with urllib, falling back to curl for local cert issues."""
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            destination.write_bytes(response.read())
        return
    except urllib.error.URLError as urllib_error:
        if not command_exists("curl"):
            raise urllib_error

    user_agent = headers.get("User-Agent", "AstroMalikCorpusBot/1.0")
    result = run_command(
        [
            "curl",
            "--location",
            "--fail",
            "--silent",
            "--show-error",
            "--user-agent",
            user_agent,
            "--output",
            str(destination),
            url,
        ],
        timeout=300,
    )
    if result.returncode != 0:
        if destination.exists():
            destination.unlink()
        raise OSError(result.stderr.strip() or f"curl failed with {result.returncode}")


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def run_command(args: list[str], timeout: int = 180) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        check=False,
        text=True,
        capture_output=True,
        timeout=timeout,
    )


def strip_html(raw: str) -> str:
    try:
        from bs4 import BeautifulSoup

        soup = BeautifulSoup(raw, "html.parser")
        for tag in soup(["script", "style", "noscript"]):
            tag.decompose()
        return normalize_text(soup.get_text("\n"))
    except Exception:
        pass
    raw = re.sub(r"(?is)<(script|style).*?</\\1>", " ", raw)
    raw = re.sub(r"(?is)<br\\s*/?>", "\n", raw)
    raw = re.sub(r"(?is)</p>", "\n\n", raw)
    raw = re.sub(r"(?is)<.*?>", " ", raw)
    raw = html.unescape(raw)
    return normalize_text(raw)


def normalize_text(raw: str) -> str:
    raw = raw.replace("\r\n", "\n").replace("\r", "\n")
    raw = re.sub(r"[ \t]+", " ", raw)
    raw = re.sub(r"\n{3,}", "\n\n", raw)
    return raw.strip() + "\n"


def extract_sources() -> list[SourceResult]:
    ensure_dirs()
    results: list[SourceResult] = []
    catalog = {s["id"]: s for s in load_catalog()["sources"]}

    for raw_path in sorted(RAW_DIR.iterdir()):
        source_id = raw_path.stem
        source = catalog.get(source_id)
        if not source:
            continue
        text_path = TEXT_DIR / f"{source_id}.txt"
        fmt = source["format"]
        try:
            if fmt == "html":
                text = strip_html(raw_path.read_text(encoding="utf-8", errors="ignore"))
                text_path.write_text(text, encoding="utf-8")
            elif fmt == "pdf" and command_exists("pdftotext"):
                result = run_command(["pdftotext", "-layout", str(raw_path), str(text_path)], timeout=300)
                if result.returncode != 0:
                    raise RuntimeError(result.stderr.strip() or "pdftotext failed")
                text_path.write_text(normalize_text(text_path.read_text(errors="ignore")), encoding="utf-8")
            elif fmt == "pdf":
                text_path.write_text(extract_pdf_with_python(raw_path), encoding="utf-8")
            elif fmt == "djvu" and command_exists("djvutxt"):
                result = run_command(["djvutxt", str(raw_path)], timeout=300)
                if result.returncode != 0:
                    raise RuntimeError(result.stderr.strip() or "djvutxt failed")
                text_path.write_text(normalize_text(result.stdout), encoding="utf-8")
            else:
                reason = f"no extractor available for {fmt}"
                results.append(SourceResult(source_id=source_id, status="skipped", path=str(raw_path), error=reason))
                continue
            results.append(
                SourceResult(
                    source_id=source_id,
                    status="extracted",
                    path=str(text_path),
                    sha256=sha256_file(text_path),
                    bytes=text_path.stat().st_size,
                )
            )
        except Exception as error:  # noqa: BLE001 - report and continue per source
            results.append(SourceResult(source_id=source_id, status="failed", path=str(raw_path), error=str(error)))

    write_json(REPORTS_DIR / "extract_manifest.json", [dataclasses.asdict(r) for r in results])
    return results


def extract_pdf_with_python(path: Path) -> str:
    try:
        from pypdf import PdfReader
    except ImportError as error:
        raise RuntimeError("no extractor available for pdf; install poppler or pypdf") from error

    reader = PdfReader(str(path))
    pages: list[str] = []
    for index, page in enumerate(reader.pages, start=1):
        try:
            text = page.extract_text() or ""
        except Exception:
            text = ""
        pages.append(f"[[PAGE {index}]]\n{text}")
    extracted = normalize_text("\n\n".join(pages))
    if len(extracted.strip()) < 50:
        raise RuntimeError("pdf extraction produced too little text; OCR may be required")
    return extracted


def init_db() -> sqlite3.Connection:
    ensure_dirs()
    if STAGING_DB.exists():
        STAGING_DB.unlink()
    conn = sqlite3.connect(STAGING_DB)
    conn.executescript(
        """
        PRAGMA journal_mode = WAL;

        CREATE TABLE source_manifest (
            source_id TEXT PRIMARY KEY,
            author TEXT NOT NULL,
            title TEXT NOT NULL,
            year INTEGER,
            url TEXT NOT NULL,
            landing_url TEXT,
            format TEXT NOT NULL,
            rights_status TEXT NOT NULL,
            license_note TEXT,
            priority INTEGER,
            downloaded_path TEXT,
            downloaded_sha256 TEXT,
            downloaded_bytes INTEGER,
            extracted_path TEXT,
            extracted_sha256 TEXT,
            extracted_bytes INTEGER,
            created_at TEXT NOT NULL
        );

        CREATE TABLE corpus_staging_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            module TEXT NOT NULL,
            key TEXT NOT NULL,
            source_id TEXT,
            source_name TEXT,
            reference TEXT,
            page TEXT,
            quote_short TEXT,
            draft_es TEXT,
            quality TEXT NOT NULL,
            semaphore TEXT NOT NULL CHECK(semaphore IN ('green', 'yellow', 'red')),
            reuse_scope TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL
        );

        CREATE TABLE primary_direction_seed_audit (
            key TEXT PRIMARY KEY,
            promissor TEXT,
            significator TEXT,
            aspect TEXT,
            current_reference TEXT,
            candidate_count INTEGER NOT NULL DEFAULT 0,
            semaphore TEXT NOT NULL CHECK(semaphore IN ('green', 'yellow', 'red')),
            notes TEXT
        );

        CREATE INDEX idx_staging_module_key ON corpus_staging_entries(module, key);
        CREATE INDEX idx_staging_semaphore ON corpus_staging_entries(semaphore);
        """
    )
    return conn


def write_json(path: Path, data: Any) -> None:
    ensure_dirs()
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def current_time() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def merge_manifests() -> dict[str, dict[str, Any]]:
    download_rows = rows_by_id(REPORTS_DIR / "download_manifest.json")
    extract_rows = rows_by_id(REPORTS_DIR / "extract_manifest.json")
    merged: dict[str, dict[str, Any]] = {}
    for source in load_catalog()["sources"]:
        sid = source["id"]
        merged[sid] = {
            **source,
            "download": download_rows.get(sid, {}),
            "extract": extract_rows.get(sid, {}),
        }
    return merged


def rows_by_id(path: Path) -> dict[str, dict[str, Any]]:
    if not path.exists():
        return {}
    rows = json.loads(path.read_text(encoding="utf-8"))
    return {row["source_id"]: row for row in rows}


def harvest_horaria_yaml() -> list[dict[str, Any]]:
    if not HORARIA_YAML.exists() or yaml is None:
        return []
    data = yaml.safe_load(HORARIA_YAML.read_text(encoding="utf-8"))
    entries: list[dict[str, Any]] = []

    def walk(node: Any, path: str = "") -> None:
        if isinstance(node, dict):
            if "clave" in node:
                reference = str(node.get("referencia") or "")
                text = str(node.get("texto") or "")
                verified = bool(node.get("referencias_verificadas"))
                semaphore = classify_horaria_entry(reference, text, verified)
                entries.append(
                    {
                        "module": "horary",
                        "key": str(node["clave"]),
                        "source_id": "horaria_textos_yaml",
                        "source_name": "Horaria textos.yaml",
                        "reference": reference,
                        "page": extract_page(reference),
                        "quote_short": "",
                        "draft_es": text,
                        "quality": "verified" if verified else "needs_review",
                        "semaphore": semaphore,
                        "reuse_scope": "direct_horary" if semaphore == "green" else "supporting_doctrine",
                        "notes": f"Imported from {HORARIA_YAML}; path={path}",
                    }
                )
            for key, value in node.items():
                walk(value, f"{path}.{key}" if path else str(key))
        elif isinstance(node, list):
            for index, value in enumerate(node):
                walk(value, f"{path}[{index}]")

    walk(data)
    return entries


def classify_horaria_entry(reference: str, text: str, verified: bool) -> str:
    if not text.strip() or not reference.strip():
        return "red"
    lower = reference.lower()
    if "frawley" in lower or "inferido" in lower:
        return "yellow"
    if verified and ("lilly" in lower or "bonatti" in lower or "sahl" in lower):
        return "green"
    return "yellow"


def extract_page(reference: str) -> str:
    match = re.search(r"\bp+\.?\s*([0-9]+)", reference, flags=re.IGNORECASE)
    return match.group(1) if match else ""


def parse_pd_seed_rows() -> list[dict[str, str]]:
    if not PD_SEED_SQL.exists():
        return []
    sql = PD_SEED_SQL.read_text(encoding="utf-8")
    pattern = re.compile(
        r"\('([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']*)'\s*,\s*0\)",
        re.MULTILINE,
    )
    return [
        {
            "key": match.group(1),
            "promissor": match.group(2),
            "significator": match.group(3),
            "aspect": match.group(4),
            "reference": match.group(5),
        }
        for match in pattern.finditer(sql)
    ]


def iter_text_sources() -> Iterable[tuple[str, str, str]]:
    if LOCAL_LILLY_TEXT.exists():
        yield "local_lilly_complete_ocr", "William Lilly OCR local", LOCAL_LILLY_TEXT.read_text(encoding="utf-8", errors="ignore")
    for path in sorted(TEXT_DIR.glob("*.txt")):
        yield path.stem, path.stem, path.read_text(encoding="utf-8", errors="ignore")


def find_candidates_for_terms(module: str, terms: list[str], limit: int = 80) -> list[dict[str, str]]:
    candidates: list[dict[str, str]] = []
    term_regex = re.compile("|".join(re.escape(term) for term in terms), re.IGNORECASE)
    page_regex = re.compile(r"(?:page|pagina|p[áa]gina|PÁGINA)\s+([0-9]+)", re.IGNORECASE)

    for source_id, source_name, text in iter_text_sources():
        for match in term_regex.finditer(text):
            start = max(0, match.start() - 360)
            end = min(len(text), match.end() + 520)
            window = normalize_text(text[start:end])
            page_match = page_regex.search(text[max(0, match.start() - 3000):match.start() + 100])
            candidates.append(
                {
                    "module": module,
                    "key": f"{module}.candidate.{len(candidates) + 1:04d}",
                    "source_id": source_id,
                    "source_name": source_name,
                    "reference": "",
                    "page": page_match.group(1) if page_match else "",
                    "quote_short": window[:700],
                    "draft_es": "",
                    "quality": "machine_candidate",
                    "semaphore": "yellow",
                    "reuse_scope": "candidate_passage",
                    "notes": f"Matched term: {match.group(0)}",
                }
            )
            if len(candidates) >= limit:
                return candidates
    return candidates


def build_staging() -> None:
    conn = init_db()
    created = current_time()
    manifests = merge_manifests()

    for sid, row in manifests.items():
        download = row.get("download") or {}
        extract = row.get("extract") or {}
        conn.execute(
            """
            INSERT INTO source_manifest (
                source_id, author, title, year, url, landing_url, format,
                rights_status, license_note, priority, downloaded_path,
                downloaded_sha256, downloaded_bytes, extracted_path,
                extracted_sha256, extracted_bytes, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                sid,
                row["author"],
                row["title"],
                row.get("year"),
                row["url"],
                row.get("landing_url"),
                row["format"],
                row["rights_status"],
                row.get("license_note"),
                row.get("priority"),
                download.get("path"),
                download.get("sha256"),
                download.get("bytes"),
                extract.get("path"),
                extract.get("sha256"),
                extract.get("bytes"),
                created,
            ),
        )

    entries = harvest_horaria_yaml()
    for module, terms in SEARCH_TERMS.items():
        entries.extend(find_candidates_for_terms(module, terms))

    for entry in entries:
        conn.execute(
            """
            INSERT INTO corpus_staging_entries (
                module, key, source_id, source_name, reference, page, quote_short,
                draft_es, quality, semaphore, reuse_scope, notes, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                entry["module"],
                entry["key"],
                entry.get("source_id"),
                entry.get("source_name"),
                entry.get("reference"),
                entry.get("page"),
                entry.get("quote_short"),
                entry.get("draft_es"),
                entry["quality"],
                entry["semaphore"],
                entry["reuse_scope"],
                entry.get("notes"),
                created,
            ),
        )

    pd_candidates = conn.execute(
        """
        SELECT COUNT(*)
        FROM corpus_staging_entries
        WHERE module = 'primary_directions'
        """
    ).fetchone()[0]
    for row in parse_pd_seed_rows():
        conn.execute(
            """
            INSERT INTO primary_direction_seed_audit (
                key, promissor, significator, aspect, current_reference,
                candidate_count, semaphore, notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                row["key"],
                row["promissor"],
                row["significator"],
                row["aspect"],
                row["reference"],
                pd_candidates,
                "yellow" if pd_candidates else "red",
                "Candidate passages require human citation mapping before populated=1.",
            ),
        )

    conn.commit()
    export_csv(conn)
    conn.close()


def export_csv(conn: sqlite3.Connection) -> None:
    for table in ("source_manifest", "corpus_staging_entries", "primary_direction_seed_audit"):
        rows = conn.execute(f"SELECT * FROM {table}").fetchall()
        headers = [description[0] for description in conn.execute(f"SELECT * FROM {table} LIMIT 1").description]
        path = STAGING_DIR / f"{table}.csv"
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(headers)
            writer.writerows(rows)


def generate_report() -> Path:
    ensure_dirs()
    conn = sqlite3.connect(STAGING_DB)
    conn.row_factory = sqlite3.Row

    def scalar(query: str, args: tuple[Any, ...] = ()) -> Any:
        return conn.execute(query, args).fetchone()[0]

    source_count = scalar("SELECT COUNT(*) FROM source_manifest")
    downloaded = scalar("SELECT COUNT(*) FROM source_manifest WHERE downloaded_sha256 IS NOT NULL")
    extracted = scalar("SELECT COUNT(*) FROM source_manifest WHERE extracted_sha256 IS NOT NULL")
    staging_count = scalar("SELECT COUNT(*) FROM corpus_staging_entries")
    pd_seed_count = scalar("SELECT COUNT(*) FROM primary_direction_seed_audit")
    semaphores = conn.execute(
        "SELECT semaphore, COUNT(*) AS total FROM corpus_staging_entries GROUP BY semaphore ORDER BY semaphore"
    ).fetchall()
    modules = conn.execute(
        "SELECT module, COUNT(*) AS total FROM corpus_staging_entries GROUP BY module ORDER BY module"
    ).fetchall()
    pd_rows = conn.execute(
        "SELECT key, semaphore, candidate_count FROM primary_direction_seed_audit ORDER BY key"
    ).fetchall()
    yellow_examples = conn.execute(
        """
        SELECT module, key, source_name, reference, notes
        FROM corpus_staging_entries
        WHERE semaphore != 'green'
        ORDER BY module, key
        LIMIT 20
        """
    ).fetchall()

    lines = [
        "# Corpus Consolidation Report",
        "",
        f"Generated: {current_time()}",
        "",
        "## Summary",
        "",
        f"- Sources in catalog: {source_count}",
        f"- Sources downloaded/cached: {downloaded}",
        f"- Sources text-extracted: {extracted}",
        f"- Staging entries: {staging_count}",
        f"- Primary direction seed keys audited: {pd_seed_count}",
        "",
        "## Semaphores",
        "",
    ]
    lines.extend(f"- {row['semaphore']}: {row['total']}" for row in semaphores)
    lines.extend(["", "## Modules", ""])
    lines.extend(f"- {row['module']}: {row['total']}" for row in modules)
    lines.extend(["", "## Primary Direction Seed Audit", ""])
    lines.extend(f"- {row['key']}: {row['semaphore']} ({row['candidate_count']} candidate passages)" for row in pd_rows)
    lines.extend(["", "## Non-Green Examples", ""])
    for row in yellow_examples:
        lines.append(f"- {row['module']} / {row['key']} / {row['source_name']} / {row['reference']} / {row['notes']}")
    lines.extend(
        [
            "",
            "## Next Human Tasks",
            "",
            "- Map candidate passages to exact pages before any primary direction seed becomes populated=1.",
            "- Keep Frawley/inferred entries yellow unless legal excerpts and human review are supplied.",
            "- Review solar/lunar return candidates before transforming them into Spanish interpretive text.",
            "- Promote entries to green only after citation, scope, translation, and doctrine review.",
        ]
    )

    path = REPORTS_DIR / "corpus_consolidation_report.md"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    conn.close()
    return path


def smoke_test() -> None:
    catalog = load_catalog()
    assert catalog["sources"], "source catalog must not be empty"
    ids = [source["id"] for source in catalog["sources"]]
    assert len(ids) == len(set(ids)), "source ids must be unique"
    assert all(source["rights_status"] for source in catalog["sources"])
    pd_rows = parse_pd_seed_rows()
    assert len(pd_rows) >= 20, "expected primary direction seed rows"
    if HORARIA_YAML.exists():
        if yaml is None:
            raise AssertionError("PyYAML is required to harvest horaria/textos.yaml")
        entries = harvest_horaria_yaml()
        assert len(entries) >= 200, "expected horaria YAML entries"
        assert {entry["semaphore"] for entry in entries} <= {"green", "yellow", "red"}
    print("smoke-test ok")


def print_results(label: str, results: list[SourceResult]) -> None:
    print(label)
    for result in results:
        detail = result.path or result.error or ""
        print(f"- {result.source_id}: {result.status} {detail}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("download", help="Download public source files")
    download_force = sub.add_parser("download-force", help="Download all source files again")
    sub.add_parser("extract", help="Extract source text where local tools are available")
    sub.add_parser("stage", help="Build staging SQLite and CSV files")
    sub.add_parser("report", help="Generate markdown report from staging")
    sub.add_parser("all", help="Download, extract, stage, and report")
    sub.add_parser("smoke-test", help="Run lightweight pipeline checks")
    _ = download_force

    args = parser.parse_args(argv)
    started = time.time()

    if args.command == "download":
        print_results("Download results", download_sources(force=False))
    elif args.command == "download-force":
        print_results("Download results", download_sources(force=True))
    elif args.command == "extract":
        print_results("Extraction results", extract_sources())
    elif args.command == "stage":
        build_staging()
        print(f"staging db: {STAGING_DB}")
    elif args.command == "report":
        print(f"report: {generate_report()}")
    elif args.command == "all":
        print_results("Download results", download_sources(force=False))
        print_results("Extraction results", extract_sources())
        build_staging()
        print(f"staging db: {STAGING_DB}")
        print(f"report: {generate_report()}")
    elif args.command == "smoke-test":
        smoke_test()

    print(f"elapsed: {time.time() - started:.1f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
