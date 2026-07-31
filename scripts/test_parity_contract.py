#!/usr/bin/env python3
"""Contract tests for the reviewed, frozen parity corpus."""
from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from parity import run_parity


ROOT = Path(__file__).resolve().parent.parent


class ParityContractTests(unittest.TestCase):
    def test_checked_in_goldens_match_current_case_recipes(self) -> None:
        self.assertEqual(len(run_parity.load_golden("special")), 91)
        self.assertEqual(len(run_parity.load_golden("distributions")), 125)

    def test_recipe_drift_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="nautilus-parity-test-") as tmp:
            golden_root = Path(tmp)
            source = run_parity.GOLDENS_ROOT / "special.json"
            payload = json.loads(source.read_text())
            payload["cases"][0]["expression"] = "cast(0.0, f32)"
            (golden_root / "special.json").write_text(
                json.dumps(payload), encoding="utf-8"
            )

            with (
                mock.patch.object(run_parity, "GOLDENS_ROOT", golden_root),
                mock.patch.object(run_parity, "PKG", golden_root),
            ):
                with self.assertRaisesRegex(
                    ValueError, "do not match the current case recipe"
                ):
                    run_parity.load_golden("special")

    def test_ci_uses_the_frozen_parity_lock_for_sync_and_run(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("uv sync --project parity --frozen", workflow)
        self.assertIn(
            "uv run --project parity --frozen python parity/run_parity.py --strict",
            workflow,
        )

    def test_parity_honors_chelis_bin_override(self) -> None:
        with tempfile.TemporaryDirectory(prefix="nautilus-parity-bin-test-") as tmp:
            package_root = Path(tmp)
            probe_path = package_root / "src" / "probe.ch"
            probe_path.parent.mkdir()
            completed = subprocess.CompletedProcess(
                args=[], returncode=0, stdout="result_0 = 1.0\n", stderr=""
            )

            with (
                mock.patch.object(run_parity, "PKG", package_root),
                mock.patch.object(run_parity, "PROBE_PATH", probe_path),
                mock.patch.dict("os.environ", {"CHELIS_BIN": "/candidate/chelis"}),
                mock.patch.object(
                    run_parity.subprocess, "run", return_value=completed
                ) as run,
            ):
                self.assertEqual(
                    run_parity.chelis_eval_batch(
                        "import Nautilus.Special exposing (erf)\n",
                        ["result_0 = erf(cast(0.0, f32))"],
                    ),
                    {0: 1.0},
                )

            self.assertEqual(run.call_args.args[0][0], "/candidate/chelis")
            self.assertFalse(probe_path.exists())


if __name__ == "__main__":
    unittest.main()
