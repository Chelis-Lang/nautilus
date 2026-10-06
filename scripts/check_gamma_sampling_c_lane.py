#!/usr/bin/env python3
"""Compare keyed gamma-family sampling in the evaluator and compiled C."""

from __future__ import annotations

import difflib
import os
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCE = REPO / "tests" / "gamma_sampling_c_parity.ch"
EXPECTED_NAMES = ("gamma_three", "gamma_one", "chi_three", "student_three")


def run(command: list[str]) -> str:
    result = subprocess.run(
        command, cwd=REPO, capture_output=True, text=True, timeout=120
    )
    if result.returncode:
        raise RuntimeError(
            f"{' '.join(command)} exited {result.returncode}:\n"
            f"{result.stdout}{result.stderr}"
        )
    return result.stdout


def main() -> int:
    chelis = os.environ.get("CHELIS_BIN", "chelis")
    try:
        expected = run([chelis, "eval", "--file", str(SOURCE), "--timeout", "120"])
        if any(f"{name} = tensor(" not in expected for name in EXPECTED_NAMES):
            raise RuntimeError("evaluator omitted a gamma-family sampling result")
        with tempfile.TemporaryDirectory(prefix="nautilus-gamma-c-") as scratch:
            output = Path(scratch) / "built"
            run([chelis, "build", str(SOURCE), "--output", str(output)])
            actual = run([str(output / SOURCE.stem)])
        if actual != expected:
            difference = "".join(
                difflib.unified_diff(
                    expected.splitlines(keepends=True),
                    actual.splitlines(keepends=True),
                    fromfile="evaluator",
                    tofile="compiled C",
                )
            )
            raise RuntimeError(f"gamma-family evaluator/C mismatch:\n{difference}")
    except (OSError, subprocess.TimeoutExpired, RuntimeError) as error:
        print(f"GAMMA SAMPLING C LANE: FAIL: {error}", file=sys.stderr)
        return 1
    print("GAMMA SAMPLING C LANE: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
