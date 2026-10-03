#!/usr/bin/env python3
"""Generate the pandas goldens for `Nautilus.Rolling`.

nautilus#85 asks for warm-up behaviour that matches pandas. This is the only
file in the repository that knows what pandas does: it writes the reviewed
expected series to `parity/goldens/rolling.json`, and
`scripts/check_rolling_parity.py` -- which imports nothing outside the
standard library -- replays them against `chelis eval`.

The split exists so that validating parity needs neither pandas nor a network,
while the numbers still come from the reference implementation rather than from
a second hand-written one. A reimplemented oracle would encode the same
misreading as the code it checks, which is how a `rolling` off-by-one survives
a green suite.

Regenerate (manual gate, needs network on first run):

    uv run --with 'pandas==2.3.3' --no-project python parity/rolling_goldens.py --write
    git diff -- parity/goldens/rolling.json
    uv run --no-project --python 3.12 python scripts/check_rolling_parity.py

Review every changed number before committing. CI never runs this file.
"""

from __future__ import annotations

import argparse
import json
import platform
import sys
from pathlib import Path

import pandas as pd

PARITY_ROOT = Path(__file__).resolve().parent
GOLDEN = PARITY_ROOT / "goldens" / "rolling.json"
SCHEMA = "nautilus-rolling-goldens/1"

# Fixtures. `xs` is non-monotonic with repeats, so a min/max that silently
# returned the first or last element of its window would differ; `ys` carries
# negatives and fractions a mistaken `abs` or an f32 round-trip would move;
# `zs` is the cancellation fixture, a large mean with a small spread, where a
# running-accumulator variance loses most of its significant digits.
FIXTURES: dict[str, list[float]] = {
    "xs": [3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0],
    "ys": [-2.5, 0.5, -1.25, 3.75, -0.75],
    "zs": [1.0e8 + 4.0, 1.0e8 + 7.0, 1.0e8 + 13.0, 1.0e8 + 16.0],
}

# Relative tolerance. pandas accumulates a rolling window incrementally where
# this module re-reduces it, so the two agree to within a few ulp rather than
# bit-for-bit. Structure -- which positions are absent -- is compared exactly.
RTOL = 1e-12


def chelis_list(values: list[float]) -> str:
    return "[" + ", ".join(f"cast({float(v)!r}, f64)" for v in values) + "]"


def i64(value: int) -> str:
    return f"cast({value}, i64)"


def f64(value: float) -> str:
    return f"cast({float(value)!r}, f64)"


def series(name: str) -> pd.Series:
    return pd.Series(FIXTURES[name], dtype="float64")


def expected_from(result: pd.Series) -> list[float | None]:
    """pandas NaN means "not enough observations"; the module says `None`.

    Only pandas' own warm-up NaN is mapped. A value this module would return
    as `Some(NaN)` -- a zero base in `pct_change`, or `ddof >= count` -- is
    kept out of the golden set entirely rather than conflated here, and is
    covered by the native suite instead.
    """
    return [None if pd.isna(v) else float(v) for v in result]


def cases() -> list[dict]:
    out: list[dict] = []

    def add(
        label: str,
        configuration: str,
        fixture: str,
        call: str,
        oracle: str,
        result: pd.Series,
    ) -> None:
        out.append(
            {
                "label": label,
                "configuration": configuration,
                "fixture": fixture,
                "expression": f"{label}({call})",
                "oracle": oracle,
                "expected": expected_from(result),
                "rel_tolerance": RTOL,
            }
        )

    # Rolling reductions. Every label gets a full-window configuration and a
    # `min_periods < window` one, because the short leading windows that
    # configuration produces are the specific thing hand-written versions get
    # wrong, and a suite that only ever passes min_periods == window cannot
    # tell the two implementations apart.
    rolling_specs = [
        ("xs", 3, 3),
        ("xs", 3, 1),
        ("xs", 1, 1),
        ("ys", 4, 2),
    ]
    reducers = {
        "rolling_sum": ("sum", lambda r: r.sum()),
        "rolling_mean": ("mean", lambda r: r.mean()),
        "rolling_min": ("min", lambda r: r.min()),
        "rolling_max": ("max", lambda r: r.max()),
    }
    for fixture, window, min_periods in rolling_specs:
        roll = series(fixture).rolling(window=window, min_periods=min_periods)
        for label, (method, apply) in reducers.items():
            add(
                label,
                f"window={window},min_periods={min_periods}",
                fixture,
                f"FIXTURE, {i64(window)}, {i64(min_periods)}",
                f"pd.Series({fixture}).rolling(window={window}, "
                f"min_periods={min_periods}).{method}()",
                apply(roll),
            )

    # ddof is varied against a fixed window as well as the reverse, so neither
    # axis is constant across the variance cases.
    for fixture, window, min_periods, ddof in [
        ("xs", 3, 3, 1),
        ("xs", 3, 3, 0),
        ("xs", 4, 2, 1),
        ("ys", 3, 2, 0),
    ]:
        roll = series(fixture).rolling(window=window, min_periods=min_periods)
        for label, method in [("rolling_var", "var"), ("rolling_std", "std")]:
            add(
                label,
                f"window={window},min_periods={min_periods},ddof={ddof}",
                fixture,
                f"FIXTURE, {i64(window)}, {i64(min_periods)}, {i64(ddof)}",
                f"pd.Series({fixture}).rolling(window={window}, "
                f"min_periods={min_periods}).{method}(ddof={ddof})",
                getattr(roll, method)(ddof=ddof),
            )

    for fixture, min_periods in [("xs", 1), ("xs", 3), ("ys", 2)]:
        exp = series(fixture).expanding(min_periods=min_periods)
        for label, method in [
            ("expanding_sum", "sum"),
            ("expanding_mean", "mean"),
            ("expanding_min", "min"),
            ("expanding_max", "max"),
        ]:
            add(
                label,
                f"min_periods={min_periods}",
                fixture,
                f"FIXTURE, {i64(min_periods)}",
                f"pd.Series({fixture}).expanding("
                f"min_periods={min_periods}).{method}()",
                getattr(exp, method)(),
            )

    for fixture, min_periods, ddof in [("xs", 2, 1), ("xs", 2, 0), ("ys", 3, 1)]:
        exp = series(fixture).expanding(min_periods=min_periods)
        for label, method in [("expanding_var", "var"), ("expanding_std", "std")]:
            add(
                label,
                f"min_periods={min_periods},ddof={ddof}",
                fixture,
                f"FIXTURE, {i64(min_periods)}, {i64(ddof)}",
                f"pd.Series({fixture}).expanding("
                f"min_periods={min_periods}).{method}(ddof={ddof})",
                getattr(exp, method)(ddof=ddof),
            )

    # The lag family. Both signs and zero, because this module is total in `k`
    # and a negative `k` is pandas' lead rather than a trap.
    for fixture, k in [("xs", 1), ("xs", 2), ("xs", -1), ("xs", 0), ("ys", 3)]:
        s = series(fixture)
        add(
            "shift",
            f"k={k}",
            fixture,
            f"FIXTURE, {i64(k)}",
            f"pd.Series({fixture}).shift({k})",
            s.shift(k),
        )
        add(
            "diff",
            f"k={k}",
            fixture,
            f"FIXTURE, {i64(k)}",
            f"pd.Series({fixture}).diff({k})",
            s.diff(k),
        )

    # pct_change needs a nonzero base at every offset it reaches, so it runs on
    # the two fixtures that have one. A zero base is `Some(inf)` and belongs in
    # the native suite, not here.
    for fixture, k in [("xs", 1), ("xs", 2), ("xs", -1), ("ys", 1)]:
        add(
            "pct_change",
            f"k={k}",
            fixture,
            f"FIXTURE, {i64(k)}",
            f"pd.Series({fixture}).pct_change(periods={k}, fill_method=None)",
            series(fixture).pct_change(periods=k, fill_method=None),
        )

    # `shift_fill` and `shift_clamped` return no `Option`, so their goldens
    # carry no `null`. `.shift(k).bfill().ffill()` IS the edge clamp: for a
    # positive k only leading positions are NaN and backfill reaches the first
    # observation; for a negative k only trailing ones are, and forward fill
    # reaches the last.
    for fixture, k, fill in [("xs", 1, 0.0), ("xs", -2, -1.0), ("ys", 2, 9.5)]:
        add(
            "shift_fill",
            f"k={k},fill={fill}",
            fixture,
            f"FIXTURE, {i64(k)}, {f64(fill)}",
            f"pd.Series({fixture}).shift({k}).fillna({fill!r})",
            series(fixture).shift(k).fillna(fill),
        )
    for fixture, k in [("xs", 1), ("xs", -2), ("ys", 3)]:
        add(
            "shift_clamped",
            f"k={k}",
            fixture,
            f"FIXTURE, {i64(k)}",
            f"pd.Series({fixture}).shift({k}).bfill().ffill()",
            series(fixture).shift(k).bfill().ffill(),
        )

    return out


def build() -> dict:
    return {
        "schema": SCHEMA,
        "generated_with": {
            "pandas": pd.__version__,
            "python": platform.python_version(),
        },
        "rel_tolerance": RTOL,
        "fixtures": {
            name: {"values": values, "literal": chelis_list(values)}
            for name, values in FIXTURES.items()
        },
        "cases": cases(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--write",
        action="store_true",
        help="write parity/goldens/rolling.json instead of printing a summary",
    )
    args = parser.parse_args()

    golden = build()
    if args.write:
        GOLDEN.parent.mkdir(parents=True, exist_ok=True)
        GOLDEN.write_text(json.dumps(golden, indent=1, sort_keys=True) + "\n")
        print(f"wrote {GOLDEN.relative_to(PARITY_ROOT.parent)}: "
              f"{len(golden['cases'])} cases, pandas {pd.__version__}")
    else:
        print(json.dumps(golden, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
