#!/usr/bin/env python3
"""Offline tests for nightly editor zip fallback when editors.json 404s."""

from __future__ import annotations

import unittest

from resolve_nightly_editor import (
    NotFoundError,
    candidate_versions,
    linux_zip_url,
    resolve_linux_zip,
)


LINUX_ZIP = {
    "filename": "BlaziumEditor_v0.6.817_linux.x86_64.zip",
    "download_url": "https://cdn.example/nightly/0.6.817/linux.zip",
}
MONO_ZIP = {
    "filename": "BlaziumEditor_v0.6.817_linux.mono.x86_64.zip",
    "download_url": "https://cdn.example/nightly/0.6.817/linux.mono.zip",
}


class LinuxZipTests(unittest.TestCase):
    def test_prefers_non_mono_linux(self) -> None:
        self.assertEqual(linux_zip_url([MONO_ZIP, LINUX_ZIP]), LINUX_ZIP["download_url"])

    def test_empty_when_only_mono(self) -> None:
        self.assertEqual(linux_zip_url([MONO_ZIP]), "")


class CandidateTests(unittest.TestCase):
    def test_latest_then_history_deduped(self) -> None:
        got = candidate_versions(
            {"version": "0.6.828", "editors_url": "https://cdn.example/828.json"},
            [
                {"version": "0.6.828", "version_url": "https://cdn.example/828-hist.json"},
                {"version": "0.6.817"},
            ],
        )
        self.assertEqual(
            got,
            [
                ("0.6.828", "https://cdn.example/828.json"),
                ("0.6.817", "https://cdn.blazium.app/nightly/0.6.817/editors.json"),
            ],
        )


class ResolveTests(unittest.TestCase):
    def test_skips_latest_when_editors_missing(self) -> None:
        catalog = {
            "https://cdn.example/latest.json": {"version": "0.6.828"},
            "https://cdn.example/history.json": [
                {"version": "0.6.828"},
                {"version": "0.6.817"},
            ],
            "https://cdn.blazium.app/nightly/0.6.817/editors.json": [LINUX_ZIP],
        }

        def fetch(url: str):
            if url.endswith("/0.6.828/editors.json"):
                raise NotFoundError(url)
            if url not in catalog:
                raise NotFoundError(url)
            return catalog[url]

        version, zip_url = resolve_linux_zip(
            fetch,
            latest_url="https://cdn.example/latest.json",
            history_url="https://cdn.example/history.json",
        )
        self.assertEqual(version, "0.6.817")
        self.assertEqual(zip_url, LINUX_ZIP["download_url"])

    def test_uses_latest_when_editors_exist(self) -> None:
        def fetch(url: str):
            if url.endswith("latest.json"):
                return {"version": "0.6.828", "editors_url": "https://cdn.example/828.json"}
            if url.endswith("history.json"):
                return [{"version": "0.6.817"}]
            if url == "https://cdn.example/828.json":
                return [LINUX_ZIP]
            raise NotFoundError(url)

        version, zip_url = resolve_linux_zip(
            fetch,
            latest_url="https://cdn.example/latest.json",
            history_url="https://cdn.example/history.json",
        )
        self.assertEqual(version, "0.6.828")
        self.assertEqual(zip_url, LINUX_ZIP["download_url"])

    def test_history_when_latest_404(self) -> None:
        def fetch(url: str):
            if url.endswith("latest.json"):
                raise NotFoundError(url)
            if url.endswith("history.json"):
                return [{"version": "0.6.817", "version_url": "https://cdn.example/817.json"}]
            if url == "https://cdn.example/817.json":
                return [LINUX_ZIP]
            raise NotFoundError(url)

        version, zip_url = resolve_linux_zip(
            fetch,
            latest_url="https://cdn.example/latest.json",
            history_url="https://cdn.example/history.json",
        )
        self.assertEqual(version, "0.6.817")
        self.assertEqual(zip_url, LINUX_ZIP["download_url"])


if __name__ == "__main__":
    unittest.main()
