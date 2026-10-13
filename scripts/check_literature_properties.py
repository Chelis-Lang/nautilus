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
