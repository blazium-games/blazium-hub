#!/usr/bin/env python3
"""Offline tests for nightly changelog SHA parsing and fallback."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from resolve_nightly_engine import parse_changelog_sha, resolve


CHANGELOG_767 = """Changelog: 9c1ca49b199b1b65bb1e6644b9cb24ccb36c89fe -> 598455d3a90ae8f7095c6dfd1e8a5c77a64cc085

Summary:
- Build Type: nightly
- Version: 0.6.767
"""


class ParseTests(unittest.TestCase):
    def test_parse_to_sha(self) -> None:
        self.assertEqual(
            parse_changelog_sha(CHANGELOG_767),
            "598455d3a90ae8f7095c6dfd1e8a5c77a64cc085",
        )

    def test_parse_missing_line(self) -> None:
        with self.assertRaises(ValueError):
            parse_changelog_sha("no changelog header")


class ResolveTests(unittest.TestCase):
    def test_catalog_wins_over_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            pin = Path(raw) / "BLAZIUM_REF"
            pin.write_text("0756aa7bfa5cc725e3819151ff05bf8bdb4d7e8a\n", encoding="utf-8")

            def fake_fetch(url: str, timeout: int = 30) -> str:
                if url.endswith("latest.json"):
                    return '{"version":"0.6.767","changelog_url":"https://cdn.example/changelog.txt"}'
                return CHANGELOG_767

            with mock.patch("resolve_nightly_engine.fetch_text", side_effect=fake_fetch):
                version, sha, source = resolve("https://cdn.example/latest.json", pin)
            self.assertEqual(version, "0.6.767")
            self.assertEqual(sha, "598455d3a90ae8f7095c6dfd1e8a5c77a64cc085")
            self.assertEqual(source, "catalog")

    def test_fallback_when_catalog_down(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            pin = Path(raw) / "BLAZIUM_REF"
            pin.write_text("0756aa7bfa5cc725e3819151ff05bf8bdb4d7e8a\n", encoding="utf-8")
            with mock.patch("resolve_nightly_engine.fetch_text", side_effect=OSError("down")):
                version, sha, source = resolve("https://cdn.example/latest.json", pin)
            self.assertEqual(version, "")
            self.assertEqual(sha, "0756aa7bfa5cc725e3819151ff05bf8bdb4d7e8a")
            self.assertEqual(source, "fallback")


if __name__ == "__main__":
    unittest.main()
