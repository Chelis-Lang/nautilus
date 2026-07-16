#!/usr/bin/env python3
"""Unit tests for reef-pin resolution in install_chelis_std.py."""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from scripts import install_chelis_std as installer


# Parser fixtures intentionally do not mirror the repository's live Chelis pin.
FIXTURE_VERSION = "1.2.3"
FIXTURE_TAG = f"v{FIXTURE_VERSION}"


class InstallChelisStdPinTests(unittest.TestCase):
    def write_reef(self, compiler: str) -> Path:
        tmp = tempfile.TemporaryDirectory(prefix="install-chelis-std-test-")
        self.addCleanup(tmp.cleanup)
        path = Path(tmp.name) / "reef.toml"
        path.write_text(f'[package]\nname = "fixture"\ncompiler = "{compiler}"\n')
        return path

    def test_resolves_exact_reef_pin(self) -> None:
        reef = self.write_reef(f"={FIXTURE_VERSION}")
        self.assertEqual(installer.reef_chelis_tag(reef_path=reef), FIXTURE_TAG)

    def test_non_exact_reef_constraint_fails_loudly(self) -> None:
        reef = self.write_reef(f"^{FIXTURE_VERSION}")
        with self.assertRaisesRegex(RuntimeError, "expected package.compiler"):
            installer.reef_chelis_tag(reef)

    def test_workflow_pin_mirror_cannot_override_reef(self) -> None:
        reef = self.write_reef(f"={FIXTURE_VERSION}")
        with mock.patch.dict("os.environ", {"CHELIS_TAG": "v9.8.7"}, clear=True):
            self.assertEqual(installer.reef_chelis_tag(reef_path=reef), FIXTURE_TAG)


if __name__ == "__main__":
    unittest.main()
