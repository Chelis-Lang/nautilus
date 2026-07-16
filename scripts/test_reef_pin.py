#!/usr/bin/env python3
"""Tests for the shared reef.toml Chelis pin resolver."""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts import reef_pin


VERSION = "1.2.3"  # Parser fixture, deliberately unrelated to the live pin.


class ReefPinTests(unittest.TestCase):
    def write_reef(self, compiler: str) -> Path:
        tmp = tempfile.TemporaryDirectory(prefix="reef-pin-test-")
        self.addCleanup(tmp.cleanup)
        path = Path(tmp.name) / "reef.toml"
        path.write_text(
            f'[package]\nname = "fixture"\ncompiler = "{compiler}"\n',
            encoding="utf-8",
        )
        return path

    def test_reads_exact_pin(self) -> None:
        self.assertEqual(
            reef_pin.read_exact_reef_pin(self.write_reef(f"={VERSION}")), VERSION
        )

    def test_rejects_non_exact_constraint(self) -> None:
        with self.assertRaisesRegex(ValueError, "expected package.compiler"):
            reef_pin.read_exact_reef_pin(self.write_reef(f"^{VERSION}"))

    def test_rejects_missing_compiler_key(self) -> None:
        tmp = tempfile.TemporaryDirectory(prefix="reef-pin-test-")
        self.addCleanup(tmp.cleanup)
        path = Path(tmp.name) / "reef.toml"
        path.write_text('[package]\nname = "fixture"\n', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "cannot read compiler pin"):
            reef_pin.read_exact_reef_pin(path)

    def test_renders_github_action_outputs(self) -> None:
        self.assertEqual(
            reef_pin.github_outputs(VERSION),
            f"chelis-tag=v{VERSION}\nchelis-version={VERSION}\n",
        )

    def test_installer_action_uses_reef_outputs_not_version_inputs(self) -> None:
        action_path = reef_pin.REPO_ROOT / ".github/actions/install-chelis/action.yml"
        action = action_path.read_text(encoding="utf-8")
        inputs = action.split("inputs:\n", 1)[1].split("outputs:\n", 1)[0]

        self.assertNotIn("chelis-tag:", inputs)
        self.assertNotIn("chelis-version:", inputs)
        self.assertNotIn("inputs.chelis-tag", action)
        self.assertNotIn("inputs.chelis-version", action)
        self.assertIn("python3 scripts/reef_pin.py", action)
        self.assertIn("steps.reef-pin.outputs.chelis-tag", action)
        self.assertIn("steps.reef-pin.outputs.chelis-version", action)


if __name__ == "__main__":
    unittest.main()
