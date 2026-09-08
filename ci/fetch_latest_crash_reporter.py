#!/usr/bin/env python3
"""Download latest crash_reporter from cdn.blazium.app/crash_reporter/crash_reporter.json."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any

CRASH_REPORTER_JSON = "https://cdn.blazium.app/crash_reporter/crash_reporter.json"
MAX_ATTEMPTS = 6
RETRY_SLEEP_SEC = 5


def _version_key(ver: str) -> tuple:
    """Sort key for dotted numeric versions (newest-first via reverse=True)."""
    parts: list[int] = []
    for p in str(ver).split("."):
        try:
            parts.append(int(p))
        except ValueError:
            parts.append(-1)
    return tuple(parts)


def resolve_download(
    manifest: dict[str, Any], platform: str, arch: str
) -> tuple[str | None, dict[str, Any] | None, str | None]:
    versions: dict[str, Any] = manifest.get("versions") or {}
    latest = (manifest.get("latest") or "").strip() or None

    order: list[str] = []
    if latest and latest in versions:
        order.append(latest)
    for ver in sorted(versions.keys(), key=_version_key, reverse=True):
        if ver not in order:
            order.append(ver)

    for ver in order:
        entry = versions.get(ver) or {}
        for d in entry.get("downloads") or []:
            if (
                d.get("platform") == platform
                and d.get("arch") == arch
                and (d.get("download_url") or "").strip()
            ):
                return ver, d, latest
    return None, None, latest


def _load_manifest() -> dict[str, Any]:
    req = urllib.request.Request(
        f"{CRASH_REPORTER_JSON}?nocache={int(time.time())}",
        headers={"Cache-Control": "no-cache", "Pragma": "no-cache"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def version_sidecar_path(out: Path) -> Path:
    return out.with_name("crash_reporter.version")


def write_version_sidecar(out: Path, version: str) -> Path:
    path = version_sidecar_path(out)
    path.write_text(version.strip() + "\n", encoding="utf-8")
    print(f"Wrote {path} ({version.strip()})")
    return path


def stamp_project_sha256(path: Path, sha: str) -> None:
    text = path.read_text(encoding="utf-8")
    line = f'crash_reporter/reporter_sha256="{sha.lower()}"'
    new, n = re.subn(r'(?m)^crash_reporter/reporter_sha256="[^"]*"$', line, text, count=1)
    if n != 1:
        raise SystemExit(f"{path}: crash_reporter/reporter_sha256 not found or ambiguous ({n})")
    path.write_text(new, encoding="utf-8")
    print(f"Stamped {path} reporter_sha256={sha.lower()}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", required=True, choices=("windows", "linux", "darwin"))
    parser.add_argument("--arch", default="x86_64")
    parser.add_argument("--out", default="", help="Destination file path (omit with --stamp-project to skip download)")
    parser.add_argument("--stamp-project", default="", help="Write catalog sha256 into project.godot")
    args = parser.parse_args()
    if not args.out and not args.stamp_project:
        parser.error("need --out and/or --stamp-project")

    version: str | None = None
    download: dict[str, Any] | None = None
    latest: str | None = None

    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            manifest = _load_manifest()
        except Exception as exc:  # noqa: BLE001 — CI script; log and retry
            print(
                f"attempt {attempt}/{MAX_ATTEMPTS}: failed to load crash_reporter.json: {exc}",
                file=sys.stderr,
            )
            if attempt < MAX_ATTEMPTS:
                time.sleep(RETRY_SLEEP_SEC)
            continue

        version, download, latest = resolve_download(manifest, args.platform, args.arch)
        if version and download:
            break
        print(
            f"attempt {attempt}/{MAX_ATTEMPTS}: no download for "
            f"{args.platform}/{args.arch} (latest={latest or '?'})",
            file=sys.stderr,
        )
        if attempt < MAX_ATTEMPTS:
            time.sleep(RETRY_SLEEP_SEC)

    if not version or not download:
        print(
            f"no download for {args.platform}/{args.arch} after {MAX_ATTEMPTS} attempts",
            file=sys.stderr,
        )
        return 1

    if latest and version != latest:
        print(
            f"Using crash_reporter {version} for {args.platform}/{args.arch} "
            f"(latest {latest} missing arch)",
            file=sys.stderr,
        )

    expected = (download.get("sha256") or "").strip().lower()
    if args.stamp_project:
        if not expected:
            print("catalog entry has no sha256; cannot stamp project", file=sys.stderr)
            return 1
        stamp_project_sha256(Path(args.stamp_project), expected)
        if not args.out:
            return 0

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    url = download["download_url"]
    print(f"Fetching crash_reporter {version}: {url} -> {out}")
    with urllib.request.urlopen(url, timeout=180) as resp:
        data = resp.read()

    expected = (download.get("sha256") or "").strip()
    expected_size = int(download.get("size") or 0)
    got = hashlib.sha256(data).hexdigest()
    if expected:
        if got.lower() == expected.lower():
            print(f"sha256 ok: {got}")
        else:
            print(
                f"WARNING: sha256 mismatch (catalog={expected}, got={got}; "
                f"size catalog={expected_size}, got={len(data)}); continuing",
                file=sys.stderr,
            )
    if len(data) < 1_000_000:
        print(f"downloaded crash_reporter too small ({len(data)} bytes)", file=sys.stderr)
        return 1
    if not (data[:2] == b"MZ" or data[:4] == b"\x7fELF"):
        print("downloaded crash_reporter missing PE/ELF magic", file=sys.stderr)
        return 1

    out.write_bytes(data)
    out.chmod(out.stat().st_mode | 0o111)
    write_version_sidecar(out, version)
    print(f"Wrote {len(data)} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
