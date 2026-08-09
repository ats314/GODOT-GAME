#!/usr/bin/env python3
"""Validate the resource catalog and regenerate the library index.

``library/catalog.json`` is the hand-curated source of truth: what each vendored
resource is, what it is licensed under, and — the part that matters for agents —
which questions it answers. Everything mechanical (size on disk, file counts,
whether the path still exists) is measured here rather than typed by hand, so the
index cannot drift away from the tree.

Outputs:
  library/INDEX.json   machine-readable, measurements merged in
  library/INDEX.md     human-readable, grouped by the need each resource serves

Run with --check to validate without writing (used by CI):

    python3 tools/build_resource_index.py --check
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "library" / "catalog.json"
INDEX_JSON = REPO / "library" / "INDEX.json"
INDEX_MD = REPO / "library" / "INDEX.md"
LICENSE_LEDGER = REPO / "THIRD_PARTY_LICENSES.md"

REQUIRED_FIELDS = ("id", "name", "path", "license", "kind", "summary", "use_when")

# Anything outside this set needs a deliberate decision, not a silent commit.
ALLOWED_LICENSES = {
    "MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "Zlib",
    "Unlicense", "CC0-1.0", "OFL-1.1", "CC-BY-3.0", "CC-BY-4.0", "MPL-2.0",
    "MIT + CC0-1.0 assets", "MIT + CC-BY-4.0 assets", "MIT + OFL-1.1 fonts",
}


def measure(path: Path) -> tuple[int, int]:
    """Return (bytes, file count) for a directory or file, ignoring .git."""
    if path.is_file():
        return path.stat().st_size, 1
    total = 0
    count = 0
    for child in path.rglob("*"):
        if ".git" in child.parts:
            continue
        if child.is_file():
            try:
                total += child.stat().st_size
            except OSError:
                continue
            count += 1
    return total, count


def git_tracked(path: Path) -> bool:
    """True when git knows about the path (catches vendored trees left untracked)."""
    result = subprocess.run(
        ["git", "ls-files", "--error-unmatch", "--", str(path.relative_to(REPO))],
        cwd=REPO, capture_output=True, text=True,
    )
    return result.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate only, write nothing")
    args = parser.parse_args()

    if not CATALOG.is_file():
        print(f"error: {CATALOG.relative_to(REPO)} is missing", file=sys.stderr)
        return 1

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    resources = catalog.get("resources", [])
    if not resources:
        print("error: catalog contains no resources", file=sys.stderr)
        return 1

    ledger = LICENSE_LEDGER.read_text(encoding="utf-8") if LICENSE_LEDGER.is_file() else ""
    problems: list[str] = []
    seen_ids: set[str] = set()
    entries = []

    for resource in resources:
        rid = resource.get("id", "<no id>")

        missing = [f for f in REQUIRED_FIELDS if not resource.get(f)]
        if missing:
            problems.append(f"{rid}: missing required field(s): {', '.join(missing)}")

        if rid in seen_ids:
            problems.append(f"{rid}: duplicate id")
        seen_ids.add(rid)

        license_name = resource.get("license", "")
        if license_name and license_name not in ALLOWED_LICENSES:
            problems.append(
                f"{rid}: license {license_name!r} is not in the allowed set — "
                "add it to ALLOWED_LICENSES only after checking the policy in THIRD_PARTY_LICENSES.md"
            )

        rel_path = resource.get("path", "")
        target = REPO / rel_path
        if not rel_path:
            continue
        if not target.exists():
            problems.append(f"{rid}: path {rel_path} does not exist")
            continue
        if not git_tracked(target):
            problems.append(f"{rid}: path {rel_path} is not tracked by git (is it gitignored?)")

        # Vendored third-party bytes must be traceable in the licence ledger.
        upstream = resource.get("upstream", "")
        if rel_path.startswith(("third_party/", "assets/")) and upstream and upstream not in ledger:
            problems.append(f"{rid}: upstream {upstream} is not recorded in THIRD_PARTY_LICENSES.md")

        size_bytes, file_count = measure(target)
        entry = dict(resource)
        entry["size_bytes"] = size_bytes
        entry["size_mb"] = round(size_bytes / (1024 * 1024), 2)
        entry["file_count"] = file_count
        entries.append(entry)

    if problems:
        print("Resource index validation failed:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    entries.sort(key=lambda e: (e.get("kind", ""), e.get("id", "")))
    total_mb = round(sum(e["size_bytes"] for e in entries) / (1024 * 1024), 2)

    index = {
        "schema_version": catalog.get("schema_version", 1),
        "resource_count": len(entries),
        "total_size_mb": total_mb,
        "generated_by": "tools/build_resource_index.py",
        "resources": entries,
    }

    if args.check:
        print(f"OK: {len(entries)} resources, {total_mb} MB, all paths and licences check out.")
        return 0

    INDEX_JSON.write_text(json.dumps(index, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    INDEX_MD.write_text(render_markdown(entries, total_mb), encoding="utf-8")
    print(f"Wrote {INDEX_JSON.relative_to(REPO)} and {INDEX_MD.relative_to(REPO)} "
          f"({len(entries)} resources, {total_mb} MB)")
    return 0


def render_markdown(entries: list[dict], total_mb: float) -> str:
    """Group the index by the need each resource serves, not by upstream name."""
    by_kind: dict[str, list[dict]] = {}
    for entry in entries:
        by_kind.setdefault(entry.get("kind", "other"), []).append(entry)

    lines = [
        "# Resource index",
        "",
        "Generated by `tools/build_resource_index.py` from `library/catalog.json`.",
        "Do not edit by hand — edit the catalog and regenerate.",
        "",
        f"{len(entries)} resources, {total_mb} MB on disk.",
        "",
    ]

    for kind in sorted(by_kind):
        lines.append(f"## {kind}")
        lines.append("")
        lines.append("| Resource | Path | Licence | Size | Use it when |")
        lines.append("| --- | --- | --- | --- | --- |")
        for entry in sorted(by_kind[kind], key=lambda e: e["name"].lower()):
            use_when = entry.get("use_when") or []
            first_use = use_when[0] if use_when else entry.get("summary", "")
            lines.append(
                f"| {entry['name']} | `{entry['path']}` | {entry['license']} | "
                f"{entry['size_mb']} MB | {first_use} |"
            )
        lines.append("")

    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
