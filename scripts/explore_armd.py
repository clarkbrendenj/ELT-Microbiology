r"""Explore the ARMD raw data
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import platform
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


EXPECTED_FILES = (
    "microbiology_cultures_cohort.csv",
    "microbiology_cultures_demographics.csv",
    "microbiology_cultures_ward_info.csv",
)
SOURCE_URL = "https://datadryad.org/dataset/doi:10.5061/dryad.jq2bvq8kp"


def inspect_file(path: Path, encoding: str) -> dict:
    """Read strings only; count parsed CSV records, including width errors."""
    before = path.stat()
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)

    row_count = 0
    blank_records = 0
    width_errors = 0
    first_width_errors = []
    with path.open("r", encoding=encoding, newline="") as source:
        reader = csv.reader(source, strict=True)
        columns = next(reader, None)
        if not columns:
            raise ValueError("The CSV has no header.")
        for record_number, row in enumerate(reader, start=2):
            if not row:
                blank_records += 1
                continue
            row_count += 1
            if len(row) != len(columns):
                width_errors += 1
                if len(first_width_errors) < 5:
                    first_width_errors.append(record_number)

    after = path.stat()
    if (before.st_size, before.st_mtime_ns) != (
        after.st_size, after.st_mtime_ns
    ):
        raise ValueError("The source file changed during inspection. Run again.")

    duplicate_headers = [
        name for name, count in Counter(columns).items() if count > 1
    ]
    blank_headers = [i + 1 for i, name in enumerate(columns) if not name.strip()]
    warnings = []
    if duplicate_headers:
        warnings.append("Duplicate column names need review.")
    if blank_headers:
        warnings.append("Blank column names need review.")
    if width_errors:
        warnings.append("Some records have a different field count from the header.")
    if blank_records:
        warnings.append("Empty CSV records were excluded from the data-row count.")
    if row_count == 0:
        warnings.append("The file contains no data rows.")

    return {
        "file_name": path.name,
        "size_bytes": before.st_size,
        "sha256": digest.hexdigest(),
        "encoding_used": encoding,
        "data_row_count": row_count,
        "column_count": len(columns),
        "columns": columns,
        "empty_record_count": blank_records,
        "field_count_error_count": width_errors,
        "first_field_count_error_record_numbers": first_width_errors,
        "duplicate_column_names": duplicate_headers,
        "blank_column_positions": blank_headers,
        "warnings": warnings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root", type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Project folder; defaults to the parent of the scripts folder.",
    )
    parser.add_argument(
        "--source-version", default=None,
        help="Publisher release date, if known. Do not use the download date.",
    )
    parser.add_argument("--encoding", default="utf-8-sig")
    args = parser.parse_args()
    raw_dir = args.project_root / "data" / "raw"
    missing = [name for name in EXPECTED_FILES if not (raw_dir / name).is_file()]
    if missing:
        print(f"Missing files in: {raw_dir}", file=sys.stderr)
        for name in missing:
            print(f"  {name}", file=sys.stderr)
        print("Place the three CSVs there with their original filenames.", file=sys.stderr)
        return 1

    # Support reasonably large text cells while remaining portable on Windows.
    csv.field_size_limit(10 * 1024 * 1024)
    report = {
        "source_url": SOURCE_URL,
        "source_version": args.source_version,
        "inspected_at_utc": datetime.now(timezone.utc).isoformat(),
        "python_version": platform.python_version(),
        "scope": "File inventory and CSV structure; not clinical validation.",
        "files": [],
        "errors": [],
    }
    print(f"Python: {platform.python_version()}")
    print(f"Reading: {raw_dir}")
    for name in EXPECTED_FILES:
        print(f"\nInspecting {name} ...", flush=True)
        try:
            result = inspect_file(raw_dir / name, args.encoding)
        except (OSError, UnicodeError, csv.Error, ValueError) as exc:
            report["errors"].append({"file_name": name, "error": str(exc)})
            print(f"  ERROR: {exc}")
            continue
        report["files"].append(result)
        print(f"  Rows: {result['data_row_count']:,}")
        print(f"  Columns: {result['column_count']}")
        print(f"  Size: {result['size_bytes'] / 1_000_000:.2f} MB")
        print(f"  Field-count errors: {result['field_count_error_count']:,}")
        print("  Column names:")
        for column in result["columns"]:
            print(f"    {column!r}")
        for warning in result["warnings"]:
            print(f"  REVIEW: {warning}")

    report["inspection_complete"] = not report["errors"]
    docs_dir = args.project_root / "docs"
    docs_dir.mkdir(parents=True, exist_ok=True)
    output = docs_dir / "source_inventory.json"
    output.write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(f"\nSaved: {output}")
    if report["errors"]:
        print("Inspection incomplete; review the errors above.")
        return 1
    if any(item["warnings"] for item in report["files"]):
        print("Inspection finished with findings to review before ingestion.")
        return 2
    print("CSV structure checks passed. Keys, joins, and clinical values still need profiling.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
