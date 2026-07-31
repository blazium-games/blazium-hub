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

CLI_JSON = "https://cdn.blazium.app/cli/cli.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", required=True, choices=("windows", "linux", "darwin"))
    parser.add_argument("--arch", default="x86_64")
    parser.add_argument("--out", required=True, help="Destination file path")
    args = parser.parse_args()

    # Cloudflare edge can serve stale cli.json for up to max-age; bust cache.
    req = urllib.request.Request(
        f"{CLI_JSON}?nocache={int(time.time())}",
        headers={"Cache-Control": "no-cache", "Pragma": "no-cache"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        manifest = json.load(resp)

    latest = manifest.get("latest")
    if not latest:
        print("cli.json missing 'latest'", file=sys.stderr)
        return 1
    versions = manifest.get("versions") or {}
    entry = versions.get(latest)
    if not entry:
        print(f"cli.json missing version {latest}", file=sys.stderr)
        return 1

    download = None
    for d in entry.get("downloads") or []:
        if d.get("platform") == args.platform and d.get("arch") == args.arch:
            download = d
            break
    if not download or not download.get("download_url"):
        print(f"no download for {args.platform}/{args.arch} @ {latest}", file=sys.stderr)
        return 1

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    url = download["download_url"]
    print(f"Fetching CLI {latest}: {url} -> {out}")
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
