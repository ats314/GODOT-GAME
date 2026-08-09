#!/usr/bin/env python3
"""Generate flat, greppable lookup tables from the vendored Godot class reference.

The class reference (``third_party/godot-class-reference/classes/*.xml``) is the
engine's own documentation source, so it is authoritative for the exact Godot
version we vendored. One XML file per class is great for reading a class you can
already name, and useless for the far more common question: *which class has the
method I half-remember?*

This script flattens all of it into two tab-separated tables that answer that
question with a single grep:

  library/api/classes.tsv   one row per class    name, inherits, brief
  library/api/symbols.tsv   one row per member   class, kind, name, signature, brief

Regenerate after re-vendoring the class reference:

    python3 tools/build_api_index.py
"""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CLASSES_DIR = REPO / "third_party" / "godot-class-reference" / "classes"
OUT_DIR = REPO / "library" / "api"

# Descriptions in the class reference are multi-paragraph prose with BBCode-ish
# markup. For a lookup table we want one short, single-line gist per symbol.
BRIEF_LIMIT = 240
_MARKUP = re.compile(r"\[/?[a-zA-Z_][^\]]*\]")
_WS = re.compile(r"\s+")


def brief(text: str | None) -> str:
    """First sentence of a doc blurb, flattened to a single clean line."""
    if not text:
        return ""
    plain = _MARKUP.sub("", text)
    plain = _WS.sub(" ", plain).strip()
    # Cut at the first sentence end that is not a decimal point or an ellipsis.
    match = re.search(r"(?<!\d)\.(?:\s|$)", plain)
    if match:
        plain = plain[: match.start() + 1]
    if len(plain) > BRIEF_LIMIT:
        plain = plain[: BRIEF_LIMIT - 1].rstrip() + "…"
    return plain


def cell(value: str) -> str:
    """TSV cells must not contain tabs or newlines."""
    return value.replace("\t", " ").replace("\n", " ").strip()


def method_signature(name: str, node: ET.Element) -> str:
    """Render a method/signal/operator as ``ret name(arg: Type = default)``."""
    args = []
    for arg in node.findall("param"):
        arg_text = f"{arg.get('name', '?')}: {arg.get('type', 'Variant')}"
        default = arg.get("default")
        if default is not None:
            arg_text += f" = {default}"
        args.append(arg_text)
    ret_node = node.find("return")
    ret = ret_node.get("type", "void") if ret_node is not None else "void"
    qualifiers = node.get("qualifiers", "")
    suffix = f" {qualifiers}" if qualifiers else ""
    return f"{ret} {name}({', '.join(args)}){suffix}"


def main() -> int:
    if not CLASSES_DIR.is_dir():
        print(f"error: {CLASSES_DIR} not found — vendor the class reference first", file=sys.stderr)
        return 1

    xml_files = sorted(CLASSES_DIR.glob("*.xml"))
    if not xml_files:
        print(f"error: no class XML files in {CLASSES_DIR}", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    class_rows: list[str] = []
    symbol_rows: list[str] = []
    version = ""

    for path in xml_files:
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError as exc:
            print(f"warning: skipping unparseable {path.name}: {exc}", file=sys.stderr)
            continue

        name = root.get("name", path.stem)
        version = version or root.get("version", "")
        inherits = root.get("inherits", "")
        summary = brief(root.findtext("brief_description") or root.findtext("description"))
        class_rows.append("\t".join(cell(x) for x in (name, inherits, summary)))

        for member in root.findall("./methods/method"):
            member_name = member.get("name", "")
            symbol_rows.append("\t".join(cell(x) for x in (
                name, "method", member_name, method_signature(member_name, member),
                brief(member.findtext("description")),
            )))

        for member in root.findall("./signals/signal"):
            member_name = member.get("name", "")
            symbol_rows.append("\t".join(cell(x) for x in (
                name, "signal", member_name, method_signature(member_name, member),
                brief(member.findtext("description")),
            )))

        for member in root.findall("./members/member"):
            member_name = member.get("name", "")
            signature = f"{member.get('type', 'Variant')} {member_name}"
            default = member.get("default")
            if default is not None:
                signature += f" = {default}"
            symbol_rows.append("\t".join(cell(x) for x in (
                name, "property", member_name, signature, brief(member.text),
            )))

        for member in root.findall("./constants/constant"):
            member_name = member.get("name", "")
            enum = member.get("enum")
            kind = "enum-value" if enum else "constant"
            signature = f"{enum}.{member_name} = {member.get('value', '')}" if enum \
                else f"{member_name} = {member.get('value', '')}"
            symbol_rows.append("\t".join(cell(x) for x in (
                name, kind, member_name, signature, brief(member.text),
            )))

        for member in root.findall("./theme_items/theme_item"):
            member_name = member.get("name", "")
            signature = f"{member.get('data_type', '')} {member.get('type', '')} {member_name}"
            symbol_rows.append("\t".join(cell(x) for x in (
                name, "theme-item", member_name, signature, brief(member.text),
            )))

    header_note = f"# Godot {version} class reference".rstrip() if version else "# Godot class reference"

    (OUT_DIR / "classes.tsv").write_text(
        f"{header_note} — one row per class\n"
        "# class\tinherits\tbrief\n" + "\n".join(class_rows) + "\n",
        encoding="utf-8",
    )
    (OUT_DIR / "symbols.tsv").write_text(
        f"{header_note} — one row per member\n"
        "# class\tkind\tname\tsignature\tbrief\n" + "\n".join(symbol_rows) + "\n",
        encoding="utf-8",
    )

    print(f"classes.tsv: {len(class_rows)} classes")
    print(f"symbols.tsv: {len(symbol_rows)} members")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
