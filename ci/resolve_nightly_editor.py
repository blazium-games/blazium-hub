#!/usr/bin/env python3
"""Resolve a nightly Linux editor zip, skipping versions whose editors.json 404s."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from typing import Any, Callable

CDN = "https://cdn.blazium.app"
NIGHTLY_LATEST = f"{CDN}/catalog/versions/nightly/latest.json"
NIGHTLY_HISTORY = f"{CDN}/catalog/versions/nightly.json"
LINUX_ZIP_SUFFIX = "linux.x86_64.zip"

FetchJSON = Callable[[str], Any]


class NotFoundError(Exception):
    pass


def fetch_json(url: str, timeout: int = 30) -> Any:
    req = urllib.request.Request(url, headers={"Cache-Control": "no-cache"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            raise NotFoundError(url) from exc
        raise


def linux_zip_url(editors: Any) -> str:
    if not isinstance(editors, list):
        return ""
    for entry in editors:
        if not isinstance(entry, dict):
            continue
        name = str(entry.get("filename") or "")
        url = str(entry.get("download_url") or "").strip()
        if name.endswith(LINUX_ZIP_SUFFIX) and ".mono." not in name and url:
            return url
    return ""


def _editors_url(channel: str, version: str, explicit: str = "") -> str:
    if explicit:
        return explicit
    return f"{CDN}/{channel}/{version}/editors.json"


def candidate_versions(latest: dict[str, Any] | None, history: list[Any], channel: str = "nightly") -> list[tuple[str, str]]:
    seen: set[str] = set()
    out: list[tuple[str, str]] = []

    def add(version: str, editors_url: str = "") -> None:
        ver = str(version or "").strip()
        if not ver or ver in seen:
            return
        seen.add(ver)
        out.append((ver, _editors_url(channel, ver, editors_url)))

    if latest:
        add(str(latest.get("version") or ""), str(latest.get("editors_url") or ""))
    for entry in history:
        if not isinstance(entry, dict):
            continue
        add(
            str(entry.get("version") or ""),
            str(entry.get("version_url") or entry.get("editors_url") or ""),
        )
    return out


def resolve_linux_zip(
    fetch: FetchJSON,
    latest_url: str = NIGHTLY_LATEST,
    history_url: str = NIGHTLY_HISTORY,
    channel: str = "nightly",
) -> tuple[str, str]:
    latest: dict[str, Any] | None = None
    try:
        data = fetch(latest_url)
        if isinstance(data, dict):
            latest = data
    except NotFoundError:
        latest = None

    history: list[Any] = []
    try:
        data = fetch(history_url)
        if isinstance(data, list):
            history = data
    except NotFoundError:
        history = []

    last_err = "no nightly versions"
    for version, editors_url in candidate_versions(latest, history, channel):
        try:
            editors = fetch(editors_url)
        except NotFoundError:
            last_err = f"editors.json missing for {version}"
            continue
        zip_url = linux_zip_url(editors)
        if zip_url:
            return version, zip_url
        last_err = f"linux editor zip not found in {version}"
    raise SystemExit(last_err)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--github-output", default="")
    args = parser.parse_args()
    version, zip_url = resolve_linux_zip(fetch_json)
    print(f"version={version}")
    print(f"zip_url={zip_url}")
    out = args.github_output or os.environ.get("GITHUB_OUTPUT", "")
    if out:
        with open(out, "a", encoding="utf-8") as fh:
            fh.write(f"version={version}\n")
            fh.write(f"zip_url={zip_url}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
