"""Keep the package manifest and public version metadata in sync."""

from __future__ import annotations

import re
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class PackageVersionTests(unittest.TestCase):
    def test_core_reports_manifest_version(self) -> None:
        manifest = tomllib.loads((ROOT / "reef.toml").read_text())
        source = (ROOT / "src" / "core.ch").read_text()
        match = re.search(r'def version\(\) -> string = "([^"]+)"', source)
        self.assertIsNotNone(match, "Core.version must return an exact string")
        self.assertEqual(match.group(1), manifest["package"]["version"])


if __name__ == "__main__":
    unittest.main()
