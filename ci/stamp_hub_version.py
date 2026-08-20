#!/usr/bin/env python3
"""Stamp CI Hub version into project.godot and export_presets.cfg (workspace only)."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def four_part(semver: str) -> str:
    parts = [p for p in re.split(r"[^\d]+", semver.strip()) if p != ""]
    nums = [(int(p) if p.isdigit() else 0) for p in parts[:3]]
    while len(nums) < 3:
        nums.append(0)
    return f"{nums[0]}.{nums[1]}.{nums[2]}.0"


def stamp_project_godot(path: Path, version: str) -> None:
    text = path.read_text(encoding="utf-8")
    new, n = re.subn(
        r'(?m)^config/version="[^"]*"$',
        f'config/version="{version}"',
        text,
        count=1,
    )
    if n != 1:
        raise SystemExit(f"{path}: config/version not found or ambiguous ({n})")
    text = new
    for key in ("crash_reporter/build_id", "crash_reporter/app_version"):
        text, n = re.subn(
            rf'(?m)^{re.escape(key)}="[^"]*"$',
            f'{key}="{version}"',
            text,
            count=1,
        )
        if n != 1:
            raise SystemExit(f"{path}: {key} not found or ambiguous ({n})")
    path.write_text(text, encoding="utf-8")


def stamp_export_presets(path: Path, file_version: str) -> None:
    text = path.read_text(encoding="utf-8")
    out = []
    changed = 0
    for line in text.splitlines():
        if line.startswith("application/file_version="):
            out.append(f'application/file_version="{file_version}"')
            changed += 1
        elif line.startswith("application/product_version="):
            out.append(f'application/product_version="{file_version}"')
            changed += 1
        else:
            out.append(line)
    if changed < 2:
        raise SystemExit(f"{path}: expected file/product version lines, changed={changed}")
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("version", help="Semver string, e.g. 0.1.2")
    ap.add_argument("--root", default=".", help="Project root")
    args = ap.parse_args()
    version = args.version.strip()
    if not version:
        print("empty version", file=sys.stderr)
        return 1
    root = Path(args.root)
    pe = four_part(version)
    stamp_project_godot(root / "project.godot", version)
    stamp_export_presets(root / "export_presets.cfg", pe)
    print(f"Stamped Hub version {version} (PE {pe})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
