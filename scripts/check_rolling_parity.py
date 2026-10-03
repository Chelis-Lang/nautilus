#!/usr/bin/env python3
"""Replay the pandas goldens for `Nautilus.Rolling` against `chelis eval`.

nautilus#85's contract is that warm-up and `min_periods` behave as pandas
does. `parity/rolling_goldens.py` records what pandas answers; this script
checks that Nautilus answers the same, and imports nothing outside the
standard library so it runs wherever the pinned compiler does.

    uv run --no-project --python 3.12 python scripts/check_rolling_parity.py

Success is exit 0 with a final `ROLLING PARITY: PASS` line. Set `CHELIS_BIN`
to validate an explicit toolchain binary; otherwise `chelis` is resolved from
`PATH`, which inside the package means the pin in `reef.toml`.

Absence is compared exactly: a golden `null` must come back as `None` and a
golden number must come back as `Some`. Values are compared to the golden's
own relative tolerance, because pandas accumulates a window incrementally
where this module re-reduces it.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import struct
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GOLDEN = REPO / "parity" / "goldens" / "rolling.json"
PROBE = REPO / "src" / "proberolling.ch"
SCHEMA = "nautilus-rolling-goldens/1"
MODULE = "Nautilus.Rolling"
MIN_CONFIGURATIONS = 2


class GoldenError(Exception):
    """The golden file itself is unusable, which is a failure, not a skip."""


def load_golden(path: Path) -> dict:
    if not path.exists():
        raise GoldenError(f"missing golden file {path}")
    data = json.loads(path.read_text())
    if data.get("schema") != SCHEMA:
        raise GoldenError(f"{path}: schema {data.get('schema')!r} != {SCHEMA!r}")
    cases = data.get("cases")
    if not isinstance(cases, list) or not cases:
        raise GoldenError(f"{path}: no cases")
    fixtures = data.get("fixtures")
    if not isinstance(fixtures, dict) or not fixtures:
        raise GoldenError(f"{path}: no fixtures")

    configurations: dict[str, set[str]] = {}
    for index, case in enumerate(cases):
        for key in ("label", "configuration", "fixture", "expression",
                    "expected", "rel_tolerance"):
            if key not in case:
                raise GoldenError(f"{path}: case {index} is missing {key!r}")
        if case["fixture"] not in fixtures:
            raise GoldenError(
                f"{path}: case {index} names unknown fixture {case['fixture']!r}"
            )
        if not isinstance(case["expected"], list) or not case["expected"]:
            raise GoldenError(f"{path}: case {index} has an empty expectation")
        for position, value in enumerate(case["expected"]):
            if value is None:
                continue
            if not isinstance(value, (int, float)) or not math.isfinite(value):
                raise GoldenError(
                    f"{path}: case {index} position {position} expects "
                    f"{value!r}, which is not a finite number; a non-finite "
                    f"expectation belongs in the native suite, not here"
                )
        configurations.setdefault(case["label"], set()).add(case["configuration"])

    thin = sorted(
        label for label, configs in configurations.items()
        if len(configs) < MIN_CONFIGURATIONS
    )
    if thin:
        raise GoldenError(
            f"{path}: {thin} have fewer than {MIN_CONFIGURATIONS} distinct "
            f"configurations; one configuration cannot distinguish an "
            f"implementation from a constant"
        )
    return data


def probe_source(golden: dict) -> tuple[str, list[str]]:
    """Return the probe module text and the binding name for each case."""
    labels = sorted({case["label"] for case in golden["cases"]})
    names: list[str] = []
    lines = [
        "module Nautilus.ProbeRolling",
        f"import {MODULE} ({', '.join(labels)})",
    ]
    for index, case in enumerate(golden["cases"]):
        literal = golden["fixtures"][case["fixture"]]["literal"]
        name = f"case_{index}"
        names.append(name)
        lines.append(f"{name} = {case['expression'].replace('FIXTURE', literal)}")
    return "\n".join(lines) + "\n", names


def run_eval(source: str) -> dict:
    PROBE.write_text(source)
    try:
        completed = subprocess.run(
            [os.environ.get("CHELIS_BIN", "chelis"), "eval", "--file",
             str(PROBE.relative_to(REPO)), "--json"],
            cwd=str(REPO),
            capture_output=True,
            text=True,
            timeout=600,
        )
    finally:
        PROBE.unlink(missing_ok=True)

    if completed.returncode != 0:
        raise GoldenError(
            f"chelis eval rc={completed.returncode}: "
            f"{completed.stderr.strip()[-800:]}"
        )
    for line in completed.stdout.splitlines():
        line = line.strip()
        if line.startswith("{"):
            return json.loads(line)
    raise GoldenError(f"chelis eval printed no JSON object: {completed.stdout[-400:]}")


def scalar(node: dict) -> float:
    if node.get("type") != "scalar":
        raise GoldenError(f"expected a scalar node, got {node.get('type')!r}")
    value = node["value"]
    if value.get("dtype") != "f64":
        raise GoldenError(f"expected dtype f64, got {value.get('dtype')!r}")
    return struct.unpack(">d", bytes.fromhex(value["bits"]))[0]


def decode(node: dict) -> list[float | None]:
    """Decode `List[f64]` or `List[Option[f64]]` into optional floats."""
    if node.get("type") != "list":
        raise GoldenError(f"expected a list result, got {node.get('type')!r}")
    out: list[float | None] = []
    for element in node["value"]:
        kind = element.get("type")
        if kind == "scalar":
            out.append(scalar(element))
        elif kind == "adt":
            ctor = element.get("ctor")
            if ctor == "None":
                out.append(None)
            elif ctor == "Some":
                fields = element.get("fields") or []
                if len(fields) != 1:
                    raise GoldenError(f"Some with {len(fields)} fields")
                out.append(scalar(fields[0]))
            else:
                raise GoldenError(f"unexpected constructor {ctor!r}")
        else:
            raise GoldenError(f"unexpected element node {kind!r}")
    return out


def compare(case: dict, actual: list[float | None]) -> list[str]:
    expected = case["expected"]
    rtol = float(case["rel_tolerance"])
    failures: list[str] = []
    if len(actual) != len(expected):
        return [f"length {len(actual)} != golden {len(expected)}"]
    for position, (want, got) in enumerate(zip(expected, actual)):
        if want is None:
            if got is not None:
                failures.append(f"[{position}] expected None, got Some({got!r})")
            continue
        if got is None:
            failures.append(f"[{position}] expected Some({want!r}), got None")
            continue
        if not math.isfinite(got):
            failures.append(f"[{position}] expected {want!r}, got {got!r}")
            continue
        limit = rtol * max(abs(want), 1.0)
        if abs(got - want) > limit:
            failures.append(
                f"[{position}] expected {want!r}, got {got!r} "
                f"(|delta| {abs(got - want):.3e} > {limit:.3e})"
            )
    return failures


def check(golden: dict, roots: list[dict], names: list[str]) -> list[str]:
    by_name = {root.get("name"): root for root in roots}
    problems: list[str] = []
    for index, case in enumerate(golden["cases"]):
        name = names[index]
        root = by_name.get(name)
        label = f"{case['label']}[{case['configuration']}] on {case['fixture']}"
        if root is None:
            # A case whose binding never came back is a failure. Treating it as
            # "nothing to compare" is how a parity gate goes green over an
            # expression the compiler silently dropped.
            problems.append(f"{label}: no `{name}` root in chelis eval output")
            continue
        try:
            actual = decode(root["value"])
        except GoldenError as exc:
            problems.append(f"{label}: {exc}")
            continue
        problems.extend(f"{label}: {failure}" for failure in compare(case, actual))
    extra = sorted(set(by_name) - set(names))
    if extra:
        problems.append(f"chelis eval returned unexpected roots {extra}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--golden", type=Path, default=GOLDEN)
    args = parser.parse_args()

    try:
        golden = load_golden(args.golden)
        source, names = probe_source(golden)
        payload = run_eval(source)
    except GoldenError as exc:
        print(f"ROLLING PARITY: FAIL -- {exc}", file=sys.stderr)
        return 1

    problems = check(golden, payload.get("roots") or [], names)
    cases = len(golden["cases"])
    labels = len({case["label"] for case in golden["cases"]})
    positions = sum(len(case["expected"]) for case in golden["cases"])
    if problems:
        print(f"ROLLING PARITY: FAIL -- {len(problems)} problem(s)", file=sys.stderr)
        for problem in problems[:40]:
            print(f"  {problem}", file=sys.stderr)
        if len(problems) > 40:
            print(f"  ... ({len(problems) - 40} more)", file=sys.stderr)
        return 1

    generated = golden.get("generated_with", {})
    print(
        f"{cases} cases over {labels} exports, {positions} positions compared; "
        f"oracle pandas {generated.get('pandas', '?')}"
    )
    print("ROLLING PARITY: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
