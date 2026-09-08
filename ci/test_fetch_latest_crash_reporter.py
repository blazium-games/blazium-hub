#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from fetch_latest_crash_reporter import version_sidecar_path, write_version_sidecar


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
