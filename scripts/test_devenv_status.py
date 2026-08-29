"""Unit tests for the reef-pinned toolchain status check."""

from __future__ import annotations

import os
import pathlib
import stat
import subprocess
import sys
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts" / "devenv_status.py"


def run_status(repo: pathlib.Path, chelis_home: pathlib.Path, check: bool) -> subprocess.CompletedProcess[str]:
    arguments = [sys.executable, str(SCRIPT), "--repo", str(repo)]
    if check:
        arguments.append("--check")
    environment = dict(os.environ, CHELIS_HOME=str(chelis_home))
    return subprocess.run(arguments, capture_output=True, text=True, env=environment, check=False)


def write_shim(chelis_home: pathlib.Path, version: str) -> None:
    shim = chelis_home / "bin" / "chelis"
    shim.parent.mkdir(parents=True, exist_ok=True)
    shim.write_text(f"#!/bin/sh\necho 'chelis {version}'\n")
    shim.chmod(shim.stat().st_mode | stat.S_IEXEC)


class DevenvStatusTests(unittest.TestCase):
    def scratch_repo(self, pin: str = "=9.9.9") -> pathlib.Path:
        scratch = pathlib.Path(tempfile.mkdtemp(prefix="naut-status-"))
        (scratch / "reef.toml").write_text(f'[package]\nname = "nautilus"\ncompiler = "{pin}"\n')
        return scratch

    def test_exact_pin_resolves_against_matching_shim(self) -> None:
        repo = self.scratch_repo()
        home = pathlib.Path(tempfile.mkdtemp(prefix="naut-home-"))
        write_shim(home, "9.9.9")
        result = run_status(repo, home, check=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("resolves the reef pin", result.stdout)

    def test_check_fails_loudly_on_version_mismatch(self) -> None:
        repo = self.scratch_repo()
        home = pathlib.Path(tempfile.mkdtemp(prefix="naut-home-"))
        write_shim(home, "1.0.0")
        result = run_status(repo, home, check=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("does not resolve", result.stderr)

    def test_check_fails_loudly_when_shim_is_absent(self) -> None:
        repo = self.scratch_repo()
        home = pathlib.Path(tempfile.mkdtemp(prefix="naut-home-"))
        result = run_status(repo, home, check=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("shim absent", result.stderr)

    def test_status_mode_reports_without_failing(self) -> None:
        repo = self.scratch_repo()
        home = pathlib.Path(tempfile.mkdtemp(prefix="naut-home-"))
        result = run_status(repo, home, check=False)
        self.assertEqual(result.returncode, 0)
        self.assertIn("shim absent", result.stdout)

    def test_inexact_pin_is_rejected(self) -> None:
        repo = self.scratch_repo(pin="^9.9")
        home = pathlib.Path(tempfile.mkdtemp(prefix="naut-home-"))
        write_shim(home, "9.9.9")
        result = run_status(repo, home, check=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("must be exact", result.stderr)

    def test_real_repository_pin_is_exact(self) -> None:
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--repo", str(REPO)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
