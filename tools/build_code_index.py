#!/usr/bin/env python3
"""Index the vendored Godot source so agents can search it by symbol, not by path.

``third_party/`` holds thousands of files across ~150 separate Godot projects.
Grepping it blind is slow and noisy. This builds flat tables that turn "who
implements object pooling?" or "which demo has a state machine?" into one grep:

  library/code/scripts.tsv    one row per .gd file  (path, class_name, extends, funcs)
  library/code/shaders.tsv    one row per .gdshader (path, shader_type, uniforms)
  library/code/projects.tsv   one row per project.godot (path, name, features, autoloads)
  library/code/addons.tsv     one row per plugin.cfg (path, name, version, description)

Run:

    python3 tools/build_code_index.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCES = ("third_party",)
OUT_DIR = REPO / "library" / "code"

RE_CLASS_NAME = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
RE_EXTENDS = re.compile(r"^\s*extends\s+([A-Za-z_\"][^\s#]*)", re.M)
RE_FUNC = re.compile(r"^\s*(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
RE_SIGNAL = re.compile(r"^\s*signal\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
RE_SHADER_TYPE = re.compile(r"^\s*shader_type\s+([a-z_]+)", re.M)
RE_UNIFORM = re.compile(r"^\s*uniform\s+\S+\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
RE_CFG_FIELD = re.compile(r'^\s*(name|description|version|author)\s*=\s*"(.*)"\s*$', re.M)


def cell(value: str) -> str:
    return value.replace("\t", " ").replace("\n", " ").strip()


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def iter_files(pattern: str):
    for source in SOURCES:
        root = REPO / source
        if not root.is_dir():
            continue
        for path in sorted(root.rglob(pattern)):
            if ".git" in path.parts or ".godot" in path.parts:
                continue
            yield path


def index_scripts() -> list[str]:
    rows = []
    for path in iter_files("*.gd"):
        text = read(path)
        class_name = RE_CLASS_NAME.search(text)
        extends = RE_EXTENDS.search(text)
        funcs = RE_FUNC.findall(text)
        signals = RE_SIGNAL.findall(text)
        rows.append("\t".join(cell(x) for x in (
            str(path.relative_to(REPO)),
            class_name.group(1) if class_name else "",
            extends.group(1).strip('"') if extends else "",
            str(len(text.splitlines())),
            ",".join(signals),
            ",".join(funcs),
        )))
    return rows


def index_shaders() -> list[str]:
    rows = []
    for path in iter_files("*.gdshader"):
        text = read(path)
        shader_type = RE_SHADER_TYPE.search(text)
        rows.append("\t".join(cell(x) for x in (
            str(path.relative_to(REPO)),
            shader_type.group(1) if shader_type else "",
            str(len(text.splitlines())),
            ",".join(RE_UNIFORM.findall(text)),
        )))
    return rows


def index_projects() -> list[str]:
    rows = []
    for path in iter_files("project.godot"):
        text = read(path)
        name = re.search(r'config/name\s*=\s*"(.*)"', text)
        features = re.search(r'config/features\s*=\s*PackedStringArray\((.*)\)', text)
        description = re.search(r'config/description\s*=\s*"(.*)"', text)
        autoload_block = re.search(r"\[autoload\]\n(.*?)(?:\n\[|\Z)", text, re.S)
        autoloads = re.findall(r"^([A-Za-z_][A-Za-z0-9_]*)=", autoload_block.group(1), re.M) \
            if autoload_block else []
        rows.append("\t".join(cell(x) for x in (
            str(path.parent.relative_to(REPO)),
            name.group(1) if name else path.parent.name,
            (features.group(1).replace('"', "") if features else ""),
            ",".join(autoloads),
            description.group(1) if description else "",
        )))
    return rows


def index_addons() -> list[str]:
    rows = []
    for path in iter_files("plugin.cfg"):
        fields = dict(RE_CFG_FIELD.findall(read(path)))
        rows.append("\t".join(cell(x) for x in (
            str(path.parent.relative_to(REPO)),
            fields.get("name", path.parent.name),
            fields.get("version", ""),
            fields.get("author", ""),
            fields.get("description", ""),
        )))
    return rows


def write(filename: str, header: str, rows: list[str]) -> None:
    (OUT_DIR / filename).write_text(header + "\n".join(rows) + "\n", encoding="utf-8")
    print(f"{filename}: {len(rows)} rows")


def main() -> int:
    if not (REPO / "third_party").is_dir():
        print("error: third_party/ not found", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    write("scripts.tsv", "# path\tclass_name\textends\tlines\tsignals\tfuncs\n", index_scripts())
    write("shaders.tsv", "# path\tshader_type\tlines\tuniforms\n", index_shaders())
    write("projects.tsv", "# path\tname\tfeatures\tautoloads\tdescription\n", index_projects())
    write("addons.tsv", "# path\tname\tversion\tauthor\tdescription\n", index_addons())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
