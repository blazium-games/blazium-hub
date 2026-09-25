#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from fetch_latest_cli import resolve_download as resolve_cli
from fetch_latest_crash_reporter import resolve_download as resolve_crash
from fetch_latest_crash_reporter import version_sidecar_path, write_version_sidecar


def _catalog() -> dict:
    return {
        "latest": "0.1.18",
        "versions": {
            "0.1.18": {
                "downloads": [
                    {"platform": "windows", "arch": "x86_32", "download_url": "https://cdn.example/32"},
                ]
            },
            "0.1.10": {
                "downloads": [
                    {"platform": "windows", "arch": "x86_64", "download_url": "https://cdn.example/64"},
                ]
            },
        },
    }


class LatestOnlyTests(unittest.TestCase):
    def test_cli_does_not_fall_back(self) -> None:
        version, download, latest = resolve_cli(_catalog(), "windows", "x86_64")
        self.assertEqual(latest, "0.1.18")
        self.assertIsNone(version)
        self.assertIsNone(download)

    def test_crash_reporter_does_not_fall_back(self) -> None:
        catalog = _catalog()
        catalog["latest"] = "0.1.6"
        catalog["versions"]["0.1.6"] = catalog["versions"].pop("0.1.18")
        catalog["versions"]["0.1.4"] = catalog["versions"].pop("0.1.10")
        version, download, latest = resolve_crash(catalog, "windows", "x86_64")
        self.assertEqual(latest, "0.1.6")
        self.assertIsNone(version)
        self.assertIsNone(download)
        self.assertNotEqual(version, "0.1.4")


class VersionSidecarTests(unittest.TestCase):
    def test_write_version_sidecar(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            out = Path(raw) / "crash_reporter.exe"
            out.write_bytes(b"MZ")
            path = write_version_sidecar(out, "0.1.2")
            self.assertEqual(path, version_sidecar_path(out))
            self.assertEqual(path.name, "crash_reporter.version")
            self.assertEqual(path.read_text(encoding="utf-8").strip(), "0.1.2")


if __name__ == "__main__":
    unittest.main()
