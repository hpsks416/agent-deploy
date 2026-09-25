#!/usr/bin/env python3
"""Pack a project directory into a GitHub-ready zip.

Writes entries individually so runtime artifacts can be excluded reliably,
and normalizes archive paths to forward slashes.

Usage:
    python package_for_github.py --src <project-dir> --out <project-dir>.zip
    python package_for_github.py --src <project-dir> --out <project-dir>.zip \
        --exclude-dir output --suffix .log --exclude-file .env
"""

from __future__ import annotations

import argparse
import zipfile
from pathlib import Path


DEFAULT_EXCLUDED_DIRS = {
    "__pycache__",
    ".git",
    ".venv",
    "venv",
    "node_modules",
    ".mypy_cache",
    ".pytest_cache",
    ".tox",
    ".idea",
    ".vscode",
    ".svn",
}

DEFAULT_EXCLUDED_SUFFIXES = {".pyc", ".pyo", ".pyd", ".log", ".tmp", ".bak"}

DEFAULT_EXCLUDED_FILES = {".DS_Store", "Thumbs.db"}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Package a project directory into a GitHub-ready zip.")
    parser.add_argument("--src", type=Path, required=True, help="Source project directory.")
    parser.add_argument("--out", type=Path, required=True, help="Output zip path (outside --src).")
    parser.add_argument("--exclude-dir", action="append", default=[], help="Extra directory name to exclude (repeatable).")
    parser.add_argument("--suffix", action="append", default=[], help="Extra file suffix to exclude, e.g. .log (repeatable).")
    parser.add_argument("--exclude-file", action="append", default=[], help="Extra file name to exclude (repeatable).")
    return parser


def excluded(path: Path, extra_dirs: set[str], extra_suffixes: set[str], extra_files: set[str]) -> bool:
    parts = path.parts
    if any(part in DEFAULT_EXCLUDED_DIRS or part in extra_dirs for part in parts):
        return True
    if path.name in DEFAULT_EXCLUDED_FILES or path.name in extra_files:
        return True
    return path.suffix.lower() in DEFAULT_EXCLUDED_SUFFIXES | extra_suffixes


def main(argv=None) -> int:
    opts = build_parser().parse_args(argv)
    src = opts.src.resolve()
    if not src.is_dir():
        raise SystemExit(f"Source directory not found: {src}")
    out = opts.out.resolve()
    if out == src or src in out.parents:
        raise SystemExit("--out must be outside --src to avoid packaging the archive itself.")

    extra_dirs = {d.rstrip("/\\") for d in opts.exclude_dir}
    extra_suffixes = {s if s.startswith(".") else "." + s for s in opts.suffix}
    extra_files = set(opts.exclude_file)

    files = [p for p in sorted(src.rglob("*")) if p.is_file() and not excluded(p, extra_dirs, extra_suffixes, extra_files)]

    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for file_path in files:
            arcname = file_path.relative_to(src).as_posix()
            archive.write(file_path, arcname)

    print(f"Packaged {len(files)} files -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
