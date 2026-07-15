#!/usr/bin/env python3
"""Contract tests for the reviewed, frozen parity corpus."""
from __future__ import annotations

import json
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


if __name__ == "__main__":
    unittest.main()
