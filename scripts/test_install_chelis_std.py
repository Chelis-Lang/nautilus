#!/usr/bin/env python3
"""Unit tests for reef-pin resolution in install_chelis_std.py."""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

import install_chelis_std as installer


class InstallChelisStdPinTests(unittest.TestCase):
    def write_reef(self, compiler: str) -> Path:
        tmp = tempfile.TemporaryDirectory(prefix="install-chelis-std-test-")
        self.addCleanup(tmp.cleanup)
        path = Path(tmp.name) / "reef.toml"
        path.write_text(f'[package]\nname = "fixture"\ncompiler = "{compiler}"\n')
        return path

    def test_absent_override_resolves_exact_reef_pin(self) -> None:
        reef = self.write_reef("=0.16.1")
        with mock.patch.dict("os.environ", {}, clear=True):
            self.assertEqual(installer.selected_chelis_tag(reef_path=reef), "v0.16.1")

    def test_non_exact_reef_constraint_fails_loudly(self) -> None:
        reef = self.write_reef("^0.16.1")
        with self.assertRaisesRegex(RuntimeError, "expected '=X.Y.Z'"):
            installer.reef_chelis_tag(reef)

    def test_environment_tag_precedes_reef(self) -> None:
        reef = self.write_reef("=0.16.1")
        with mock.patch.dict("os.environ", {"CHELIS_TAG": "v0.17.0"}, clear=True):
            self.assertEqual(installer.selected_chelis_tag(reef_path=reef), "v0.17.0")


if __name__ == "__main__":
    unittest.main()
