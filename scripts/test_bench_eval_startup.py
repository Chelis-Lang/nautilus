#!/usr/bin/env python3
"""Unit tests for the eval-startup benchmark's failure classification."""
from __future__ import annotations

import subprocess
import unittest
from unittest import mock

import bench_eval_startup as benchmark


class EvalStartupBenchmarkTests(unittest.TestCase):
    def test_timeouts_exceed_observed_file_eval_startup(self) -> None:
        self.assertGreaterEqual(benchmark._PROBE_TIMEOUT_S, 60)
        self.assertGreaterEqual(benchmark._TIMED_TIMEOUT_S, 60)

    @mock.patch.object(benchmark.subprocess, "run")
    def test_toolchain_description_uses_version_output(
        self, run: mock.Mock
    ) -> None:
        run.return_value = subprocess.CompletedProcess(
            ["chelis", "--version"], 0, stdout="chelis 0.16.1\n", stderr=""
        )
        self.assertEqual(benchmark.toolchain_description(), "chelis 0.16.1")

    def test_symbolic_input_residue_is_not_reported_as_hang(self) -> None:
        baseline = benchmark.ScenarioResult(
            label="baseline", stats=None, status="blocked", detail="not measured"
        )
        import_failure = benchmark.ScenarioResult(
            label="Nautilus.Special",
            stats=None,
            status="blocked",
            detail="missing required input `a` for symbolic dimension `k`",
        )

        recommendations = benchmark.recommended_changes(
            baseline, baseline, [import_failure]
        )

        self.assertTrue(any("historical package-import hang is fixed" in item for item in recommendations))
        self.assertTrue(any("eval_unused_reef_import_symbolic_input.md" in item for item in recommendations))


if __name__ == "__main__":
    unittest.main()
