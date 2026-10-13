#!/usr/bin/env python3
"""Check imported distribution and Hermite claims and their counterexamples."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PASSING = {
    "uniform_cdf_range",
    "uniform_inverse_range",
    "hermite_nonovershoot_lower",
    "hermite_nonovershoot_upper",
    "hermite_decreasing_lower",
    "hermite_decreasing_upper",
}
FAILING = {
    "uniform_cdf_upper_wrong",
    "uniform_inverse_upper_wrong",
    "hermite_unrestricted_slope_wrong",
    "hermite_decreasing_unrestricted_wrong",
}


# Canonical authored goals include the guards and imported function identity.
GOALS = {'uniform_cdf_range': 'forall(x: f32, lo: f32, hi: f32) where hi > lo: '
                      '((Nautilus.Distributions.uniform_cdf(x, lo, hi) >= 0.0f32) && '
                      '(Nautilus.Distributions.uniform_cdf(x, lo, hi) <= 1.0f32))',
 'uniform_inverse_range': 'forall(q: f32, lo: f32, hi: f32) where hi > lo, q >= 0.0f32, q <= 1.0f32: '
                          '((Nautilus.Distributions.uniform_inv_cdf(q, lo, hi) >= lo) && '
                          '(Nautilus.Distributions.uniform_inv_cdf(q, lo, hi) <= hi))',
 'hermite_nonovershoot_lower': 'forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x: f32) where '
                               'x1 > x0, y1 > y0, x >= x0, x <= x1, m0 >= 0.0f32, m1 >= 0.0f32, ((x1 - x0) * '
                               'm0) <= (3.0f32 * (y1 - y0)), ((x1 - x0) * m1) <= (3.0f32 * (y1 - y0)): '
                               '(Nautilus.Interpolation.cubic_hermite(x0, x1, y0, y1, m0, m1, x) >= y0)',
 'hermite_nonovershoot_upper': 'forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x: f32) where '
                               'x1 > x0, y1 > y0, x >= x0, x <= x1, m0 >= 0.0f32, m1 >= 0.0f32, ((x1 - x0) * '
                               'm0) <= (3.0f32 * (y1 - y0)), ((x1 - x0) * m1) <= (3.0f32 * (y1 - y0)): '
                               '(Nautilus.Interpolation.cubic_hermite(x0, x1, y0, y1, m0, m1, x) <= y1)',
 'hermite_decreasing_lower': 'forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x: f32) where x1 '
                             '> x0, y1 < y0, x >= x0, x <= x1, m0 <= 0.0f32, m1 <= 0.0f32, ((x1 - x0) * m0) '
                             '>= (3.0f32 * (y1 - y0)), ((x1 - x0) * m1) >= (3.0f32 * (y1 - y0)): '
                             '(Nautilus.Interpolation.cubic_hermite(x0, x1, y0, y1, m0, m1, x) >= y1)',
 'hermite_decreasing_upper': 'forall(x0: f32, x1: f32, y0: f32, y1: f32, m0: f32, m1: f32, x: f32) where x1 '
                             '> x0, y1 < y0, x >= x0, x <= x1, m0 <= 0.0f32, m1 <= 0.0f32, ((x1 - x0) * m0) '
                             '>= (3.0f32 * (y1 - y0)), ((x1 - x0) * m1) >= (3.0f32 * (y1 - y0)): '
                             '(Nautilus.Interpolation.cubic_hermite(x0, x1, y0, y1, m0, m1, x) <= y0)',
 'uniform_cdf_upper_wrong': 'forall(lo: f32, hi: f32) where hi > lo: (Nautilus.Distributions.uniform_cdf(hi, '
                            'lo, hi) <= 0.9f32)',
 'uniform_inverse_upper_wrong': 'forall(q: f32) where q >= 0.1f32, q <= 0.9f32: '
                                '(Nautilus.Distributions.uniform_inv_cdf(q, 2.0f32, 8.0f32) <= 7.0f32)',
 'hermite_unrestricted_slope_wrong': 'forall(x: f32) where x >= 0.0f32, x <= 1.0f32: '
                                     '(Nautilus.Interpolation.cubic_hermite(0.0f32, 1.0f32, 0.0f32, 1.0f32, '
                                     '4.0f32, 0.0f32, x) <= 1.0f32)',
 'hermite_decreasing_unrestricted_wrong': 'forall(x: f32) where x >= 0.0f32, x <= 1.0f32: '
                                          '(Nautilus.Interpolation.cubic_hermite(0.0f32, 1.0f32, 1.0f32, '
                                          '0.0f32, -4.0f32, 0.0f32, x) >= 0.0f32)'}


def validate_goal(record: dict) -> None:
    assert record.get("goal") == GOALS[record["name"]], record


def prove(path: str, expected_names: set[str], expected_returncode: int) -> list[dict]:
    result = subprocess.run(
        ["chelis", "prove", path, "--tier", "smt-only", "--smt-timeout", "20000", "--json"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == expected_returncode, result.stderr or result.stdout
    records = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
    properties = [record for record in records if record.get("kind") == "property"]
    assert {record["name"] for record in properties} == expected_names, properties
    for record in properties:
        validate_goal(record)
    return properties


def main() -> None:
    for record in prove("properties/literature.ch", PASSING, 0):
        assert record["status"] == "passed", record
        assert record["proof_tier"] == "smt", record
        assert record["composite_verdict"] == "proven_modulo_real_arithmetic", record
        assert record["qualifiers"] == ["real_arithmetic"], record
        assert record["samples"] == 0, record
        assert all(
            assumption["non_vacuity"]["status"] == "established"
            for assumption in record["assumptions"]
        ), record
    for record in prove("proof_controls/literature_wrong.ch", FAILING, 1):
        assert record["status"] == "failed", record
        assert record["proof_tier"] == "smt", record
        assert record["counterexample"], record
    print("LITERATURE PROPERTIES: PASS (six SMT proofs, four counterexamples)")


if __name__ == "__main__":
    main()
