"""Check Nautilus interpolation properties and a false-claim control with SMT."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CASES = (
    ("properties/interpolation.ch", 0, {"hermite_left_endpoint": "passed", "hermite_right_endpoint": "passed"}),
    ("proof_controls/hermite_wrong.ch", 1, {"hermite_left_returns_right": "failed"}),
)


def validate_records(records: list[dict], expected: dict[str, str]) -> None:
    properties = {record["name"]: record for record in records if record.get("kind") == "property"}
    summaries = [record for record in records if record.get("kind") == "summary"]
    if set(properties) != set(expected) or len(summaries) != 1:
        raise ValueError(f"property/summary set differs from expected: {set(properties)}, {len(summaries)} summaries")
    summary = summaries[0]
    if (summary.get("total") != len(expected) or summary.get("errors") != 0
            or summary.get("unsupported") != 0
            or summary.get("passed") != sum(status == "passed" for status in expected.values())
            or summary.get("failed") != sum(status == "failed" for status in expected.values())):
        raise ValueError(f"incomplete property summary: {summary}")
    for name, wanted_status in expected.items():
        result = properties[name]
        if (result.get("status"), result.get("proof_tier"), result.get("samples"), result.get("arith_model")) != (
            wanted_status, "smt", 0, "real"
        ):
            raise ValueError(f"{name} did not reach the expected SMT verdict")
        if wanted_status == "passed":
            if result.get("qualifiers") != ["real_arithmetic"]:
                raise ValueError(f"{name} has unexpected proof qualifiers")
            assumptions = result.get("assumptions", [])
            if not assumptions or not all(item.get("non_vacuity", {}).get("status") == "established" for item in assumptions):
                raise ValueError(f"{name} has an unestablished guard")
        elif not result.get("counterexample"):
            raise ValueError(f"{name} refuted without a counterexample")


def main() -> int:
    for path, expected_exit, expected in CASES:
        run = subprocess.run(
            ["chelis", "prove", path, "--tier", "smt-only", "--smt-timeout", "20000", "--json"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        if run.returncode != expected_exit:
            raise RuntimeError(f"{path}: exit {run.returncode}, expected {expected_exit}\n{run.stdout}\n{run.stderr}")
        records = [json.loads(line) for line in run.stdout.splitlines() if line]
        validate_records(records, expected)
        print(f"{path}: {', '.join(expected)} checked by SMT")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
