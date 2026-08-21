#!/usr/bin/env python3
"""Resolve the newest nightly engine SHA from the CDN catalog."""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

NIGHTLY_LATEST = "https://cdn.blazium.app/catalog/versions/nightly/latest.json"
CHANGELOG_RE = re.compile(
    r"^Changelog:\s*([0-9a-fA-F]{7,40})\s*->\s*([0-9a-fA-F]{7,40})\s*$",
    re.MULTILINE,
)


def parse_changelog_sha(text: str) -> str:
    match = CHANGELOG_RE.search(text)
    if not match:
        raise ValueError("changelog missing 'Changelog: <from> -> <to>' line")
    return match.group(2).lower()


def read_fallback_ref(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8").strip()


def fetch_text(url: str, timeout: int = 30) -> str:
    req = urllib.request.Request(url, headers={"Cache-Control": "no-cache"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", "replace")


def resolve_from_catalog(latest_url: str) -> tuple[str, str]:
    latest = json.loads(fetch_text(latest_url))
    version = str(latest.get("version") or "").strip()
    if not version:
        raise ValueError("nightly latest.json missing version")
    changelog_url = str(latest.get("changelog_url") or "").strip()
    if not changelog_url:
        changelog_url = f"https://cdn.blazium.app/nightly/{version}/changelog.txt"
    sha = parse_changelog_sha(fetch_text(changelog_url))
    return version, sha


def resolve(latest_url: str, fallback_path: Path) -> tuple[str, str, str]:
    fallback = read_fallback_ref(fallback_path)
    try:
        version, sha = resolve_from_catalog(latest_url)
        return version, sha, "catalog"
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError, json.JSONDecodeError, OSError) as exc:
        if not fallback:
            raise SystemExit(f"nightly catalog unavailable and no BLAZIUM_REF fallback: {exc}") from exc
        print(f"nightly catalog unavailable ({exc}); using BLAZIUM_REF fallback", file=sys.stderr)
        return "", fallback, "fallback"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--latest-url", default=NIGHTLY_LATEST)
    parser.add_argument("--fallback", default="ci/BLAZIUM_REF")
    parser.add_argument("--github-output", default="")
    args = parser.parse_args()
    version, ref, source = resolve(args.latest_url, Path(args.fallback))
    if not ref:
        raise SystemExit("empty engine ref")
    print(f"nightly_version={version or 'unknown'}")
    print(f"ref={ref}")
    print(f"source={source}")
    out = args.github_output or __import__("os").environ.get("GITHUB_OUTPUT", "")
    if out:
        with open(out, "a", encoding="utf-8") as fh:
            fh.write(f"version={version}\n")
            fh.write(f"ref={ref}\n")
            fh.write(f"source={source}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
