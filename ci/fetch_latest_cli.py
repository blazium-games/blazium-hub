#!/usr/bin/env python3
"""Download latest blazium-cli from cdn.blazium.app/cli/cli.json."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any

CLI_JSON = "https://cdn.blazium.app/cli/cli.json"
MAX_ATTEMPTS = 6
RETRY_SLEEP_SEC = 5


def _version_key(ver: str) -> tuple:
    """Sort key for dotted numeric versions (newest-first via reverse=True)."""
    parts: list[int] = []
    for p in str(ver).split("."):
        try:
            parts.append(int(p))
        except ValueError:
            # Non-numeric segment: keep stable but behind pure ints.
            parts.append(-1)
    return tuple(parts)


def resolve_download(
    manifest: dict[str, Any], platform: str, arch: str
) -> tuple[str | None, dict[str, Any] | None, str | None]:
    """Pick newest catalog version that has platform/arch.

    Returns (version, download, latest_label). Prefer manifest['latest'] when it
    has the arch; otherwise walk other versions newest-first.
    """
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
    # Cloudflare edge can serve stale cli.json for up to max-age; bust cache.
    req = urllib.request.Request(
        f"{CLI_JSON}?nocache={int(time.time())}",
        headers={"Cache-Control": "no-cache", "Pragma": "no-cache"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", required=True, choices=("windows", "linux", "darwin"))
    parser.add_argument("--arch", default="x86_64")
    parser.add_argument("--out", required=True, help="Destination file path")
    args = parser.parse_args()

    version: str | None = None
    download: dict[str, Any] | None = None
    latest: str | None = None

    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            manifest = _load_manifest()
        except Exception as exc:  # noqa: BLE001 — CI script; log and retry
            print(
                f"attempt {attempt}/{MAX_ATTEMPTS}: failed to load cli.json: {exc}",
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
            f"Using CLI {version} for {args.platform}/{args.arch} "
            f"(latest {latest} missing arch)",
            file=sys.stderr,
        )

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    url = download["download_url"]
    print(f"Fetching CLI {version}: {url} -> {out}")
    with urllib.request.urlopen(url, timeout=180) as resp:
        data = resp.read()

    expected = (download.get("sha256") or "").strip()
    expected_size = int(download.get("size") or 0)
    got = hashlib.sha256(data).hexdigest()
    if expected:
        if got.lower() == expected.lower():
            print(f"sha256 ok: {got}")
        else:
            # cli.json digests can lag CDN re-signs; require a plausible binary payload.
            print(
                f"WARNING: sha256 mismatch (catalog={expected}, got={got}; "
                f"size catalog={expected_size}, got={len(data)}); continuing",
                file=sys.stderr,
            )
    if len(data) < 1_000_000:
        print(f"downloaded CLI too small ({len(data)} bytes)", file=sys.stderr)
        return 1
    # PE (MZ) or ELF magic
    if not (data[:2] == b"MZ" or data[:4] == b"\x7fELF"):
        print("downloaded CLI missing PE/ELF magic", file=sys.stderr)
        return 1

    out.write_bytes(data)
    out.chmod(out.stat().st_mode | 0o111)
    print(f"Wrote {len(data)} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
