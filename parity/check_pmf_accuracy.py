#!/usr/bin/env python3
"""Measure `poisson_pmf` / `binomial_pmf` accuracy and enforce the documented range.

`docs/book/src/appendix/precision.md` and
`docs/book/src/distributions/discrete.md` state a relative-error bound for the
two discrete PMFs and the parameter range it holds over (nautilus#146). This
script is the gate for both the implementation and those sentences; without it
they are prose, and the sibling beta claim was found false in a different place
in each of two review rounds while it was prose.

**The error has one mechanism and it sets the shape of the grid.** Both PMFs are
`exp` of a log-space expression whose dominant term is
`ln(Gamma(k + 1)) = ln(k!)`. An absolute error there is a *multiplicative* error
in the answer, and `ln(k!)` grows without bound: 1.05e6 at `k = 1e5`, 1.74e9 at
`k = 1e8`, 1.97e10 at `k = 1e9`. So the error is governed by the spacing of the
arithmetic that forms that term, at the magnitude the parameter puts it at --
not by where `k` sits relative to the mode, and not by a convergence budget.
One f64 ulp of `ln(k!)` at `k = 1e9` is 3.8e-6, and the measured relative error
there is 3.8e-6: the error *is* that rounding. In f32 the same ulp is 128 at
`n = 1e8`, which is why `binomial_pmf(5e7, 1e8, 0.5)` returned `inf`.

**The grid therefore probes the CEILING, and it probes every `p`.** Two failures
are on record from building it:

1. A first version required every argument to be exactly representable in f32.
   `0.2` and `0.01` are not f32 values, so that filter silently discarded
   *every* skewed `p` and left the large-`n` claim resting on `p = 0.5` alone.
   A skewed `p` can be worse than `p = 0.5`, so the grid has to carry them.
   Arguments are now emitted as the shortest decimal that round-trips to the
   intended f32, and every reference is computed at that f32 value rather than
   at the decimal spelling.

   **The location of the worst case is as grid-dependent as its value, and
   neither this file nor any document may claim either.** A review round built
   an independent 3352-case grid and found `binomial_pmf(6.5e7, 1.3e8, 0.5)` at
   1.04e-06 -- 1.9x the `p = 0.999999` row this grid's ceiling produces, and at
   `p = 0.5` after all. That case is in the grid below now, as a known-hard case
   rather than as a maximum. Both rows are far inside the bound; what moved was
   the superlative, which has been removed from the documents.
2. An error bound indexed on a parameter the grid never reaches at its stated
   value cannot fail at its own boundary. `cases()` probes `n` and `lambda`
   *at* the documented ceiling, and `test_check_pmf_accuracy.py` fails if it
   stops short or drops below the `p` count.

A reference below f32's smallest normal is excluded: measuring one there
measures f32's own quantisation, not this implementation. So is a reference of
exactly 1.0, which has no relative resolution.

    uv run --project parity --frozen python parity/check_pmf_accuracy.py

It lives under `parity/` because it imports SciPy, and this repository confines
external-oracle libraries to that directory: `scripts/check_oracle_isolation.py`
fails the build when an oracle import appears anywhere else.

Success is exit 0 with a final `PMF ACCURACY: PASS` line. Set `CHELIS_BIN` to
validate an explicit toolchain binary.

This script does **not** read the documents. `DOCUMENTED` below is transcribed
by hand, so it catches an implementation drift but not a document drift;
`test_the_bound_is_not_silently_widened` pins the table so it cannot move
without a deliberate edit, and keeping the documents in step is a reviewer's
job.
"""
from __future__ import annotations

import os
import re
import struct
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PROBE = REPO / "src" / "accpmf.ch"
MODULE = "Nautilus.AccPmf"

# f32's smallest normal. Below it a reference cannot be carried by the return
# type at all, so the comparison would measure f32 rather than Nautilus.
F32_MIN_NORMAL = 1.1754943508222875e-38

# (ceiling on the count parameter, permitted relative error).
# `lambda` for `poisson_pmf`, `n` for `binomial_pmf`.
#
# The bound carries deliberate headroom over the measurement, because the error
# is rounding-driven: its maximum over a continuum is not findable by evaluating
# finitely many points, so a bound that tracks the observed worst is a bound the
# next grid refinement falsifies. The run prints the current worst; no document
# quotes it.
#
# Just outside the range, the same mechanism gives 3.8e-6 at `lambda = 1e9` and
# 3.6e-6 at `n = 1e9` -- above this bound, which is the point: the documents say
# the error grows past the ceiling with nothing in the result to signal it.
DOCUMENTED = {
    "poisson_pmf": (1e8, 2e-6),
    "binomial_pmf": (2e8, 2e-6),
}

# Probed beyond each ceiling as well, so the run reports what the out-of-range
# growth actually is instead of leaving the documents' claim about it unmeasured.
BEYOND = 1e9

# Every `p` the binomial grid visits. Most are not f32 values; that is the
# point of the round-trip spelling.
PROBABILITIES = (1e-7, 1e-5, 1e-3, 0.01, 0.1, 0.2, 0.3, 0.5, 0.7, 0.8, 0.9,
                 0.99, 0.999999)


class AccuracyError(Exception):
    pass


def f32(value: float) -> float:
    return struct.unpack("f", struct.pack("f", value))[0]


def lit(value: float) -> str:
    """The shortest decimal that round-trips to `f32(value)`.

    Chelis reads a digit string with no `.` or `e` as an integer literal, which
    is an i32 at these call sites, so an integral value gets a `.0`.
    """
    target = f32(value)
    for precision in range(1, 12):
        text = "%.*g" % (precision, target)
        if f32(float(text)) == target:
            return text if ("." in text or "e" in text) else text + ".0"
    raise AccuracyError(f"no round-tripping f32 spelling for {value!r}")


def cases() -> list[tuple[str, str, str, float, float]]:
    """(name, export, expression, count parameter, reference)."""
    from scipy.stats import binom, poisson

    out: list[tuple[str, str, str, float, float]] = []
    seen: set[tuple[str, tuple[float, ...]]] = set()

    def add(export: str, args: tuple[float, ...], reference: float) -> None:
        key = (export, args)
        if key in seen:
            return
        seen.add(key)
        if not (F32_MIN_NORMAL <= reference < 1.0):
            return
        spelled = ", ".join(lit(value) for value in args)
        # Positional names: a descriptive one built from the parameters produces
        # `1e+06`, which the lexer reads as a literal suffix. `acc_` is the
        # module's own domain shorthand, which chelis §7.1 requires.
        out.append((f"acc_{len(out)}", export, f"{export}({spelled})",
                    args[-1] if export == "poisson_pmf" else args[1], reference))

    # ---- poisson_pmf: lambda is the count parameter ---------------------
    # Walked in units of the standard deviation, which is the only scale the
    # PMF has: at `lambda` the mode is `lambda` and the width is `sqrt(lambda)`,
    # so a fixed offset means nothing across eleven decades.
    for lam in [0.5, 1.0, 2.5, 10.0, 100.0, 1e3, 1e4, 1e5, 1e6, 1e7, 2e7, 5e7,
                DOCUMENTED["poisson_pmf"][0], 5e8, BEYOND]:
        L = f32(lam)
        sd = L ** 0.5
        counts = [f32(max(0.0, float(int(L + z * sd))))
                  for z in (-20.0, -8.0, -5.0, -3.0, -1.0, 0.0, 1.0, 3.0, 5.0,
                            8.0, 20.0)]
        counts += [0.0, 1.0, f32(2.0 * L), f32(10.0 * L)]
        for k in dict.fromkeys(counts):
            add("poisson_pmf", (k, L), float(poisson.pmf(k, L)))

    # ---- binomial_pmf: n is the count parameter --------------------------
    # p = 0.5 spine first, at fractions of n including both endpoints.
    for n in [10.0, 100.0, 200.0, 1e3, 2e3, 1e4, 2e4, 1e5, 2e5, 1e6, 2e6, 1e7,
              2e7, 1e8, DOCUMENTED["binomial_pmf"][0], BEYOND]:
        N = f32(n)
        for frac in (0.0, 0.25, 0.5, 0.75, 1.0):
            K = f32(float(int(N * frac)))
            add("binomial_pmf", (K, N, f32(0.5)), float(binom.pmf(K, N, f32(0.5))))
    # Then every `p`, at the mode and at +-2 and +-5 standard deviations, plus
    # both endpoints of `k`. The endpoints matter because `k = 0` and `k = n`
    # make one of the three log-gammas `ln(Gamma(1)) = 0`, so the cancellation
    # that the f32 body got wrong is structurally different there.
    for n in [100.0, 1e4, 1e6, 1e7, 1e8, DOCUMENTED["binomial_pmf"][0], BEYOND]:
        N = f32(n)
        for p in PROBABILITIES:
            P = f32(p)
            mu = N * P
            sd = (N * P * (1.0 - P)) ** 0.5
            counts = [f32(max(0.0, min(N, float(int(mu + z * sd)))))
                      for z in (-5.0, -2.0, 0.0, 2.0, 5.0)]
            counts += [0.0, N]
            for k in dict.fromkeys(counts):
                add("binomial_pmf", (k, N, P), float(binom.pmf(k, N, P)))
    # A known-hard case a review round found with an independent 3352-case grid:
    # 1.04e-06, 1.9x the worst this grid's own ceiling rows produce, and at
    # `p = 0.5`. A known worst case belongs in the grid whether or not it is the
    # maximum -- the same reason the sibling beta gate carries round 4's case.
    for k, n in [(6.5e7, 1.3e8)]:
        K, N = f32(k), f32(n)
        add("binomial_pmf", (K, N, f32(0.5)), float(binom.pmf(K, N, f32(0.5))))
    # The 2^24 neighbourhood, where the f32 `k + 1` lost its `+ 1` outright.
    # Kept as named rows whether or not they are the worst case.
    for n in [2.0 ** 25, 2.0 ** 26]:
        N = f32(n)
        for k in (2.0 ** 24 - 1, 2.0 ** 24, 2.0 ** 24 + 2, N / 2.0):
            K = f32(k)
            if K < N:
                add("binomial_pmf", (K, N, f32(0.5)),
                    float(binom.pmf(K, N, f32(0.5))))
    return out


def evaluate(chelis: str, spec: list) -> dict[str, str]:
    names = [case[0] for case in spec]
    body = "\n".join(f"def {case[0]}() -> f32 = {case[2]}" for case in spec)
    PROBE.write_text(f"module {MODULE}\n"
                     "import Nautilus.Distributions (poisson_pmf, binomial_pmf)\n"
                     f"export ({', '.join(names)})\n{body}\n")
    try:
        relative = str(PROBE.relative_to(REPO))
        formatted = subprocess.run([chelis, "fmt", "--inplace", relative], cwd=REPO,
                                   capture_output=True, text=True, timeout=900)
        if formatted.returncode != 0:
            raise AccuracyError(f"chelis fmt failed: {formatted.stderr.strip()[-500:]}")
        done = subprocess.run([chelis, "eval", "--file", relative], cwd=REPO,
                              capture_output=True, text=True, timeout=1800)
        if done.returncode != 0:
            raise AccuracyError(f"chelis eval --file failed (rc={done.returncode}):\n"
                                f"{(done.stderr or done.stdout).strip()[-800:]}")
        return dict(re.findall(r"^\s*(\w+)\s*=\s*(\S+)\s*$", done.stdout, re.M))
    finally:
        PROBE.unlink(missing_ok=True)


def main() -> int:
    chelis = os.environ.get("CHELIS_BIN", "chelis")
    try:
        spec = cases()
        got = evaluate(chelis, spec)
    except AccuracyError as error:
        print(f"PMF ACCURACY: FAIL\n{error}", file=sys.stderr)
        return 1

    # Tracked separately on purpose: the documented bound is a claim about the
    # documented range, so a worst case that mixes out-of-range inputs in is the
    # number/scope mismatch that made the sibling beta range wrong.
    worst_in: dict[str, tuple[float, str]] = {}
    worst_all: dict[str, tuple[float, str]] = {}
    violations: list[str] = []
    for name, export, expr, count, reference in spec:
        raw = got.get(name)
        if raw is None:
            print(f"PMF ACCURACY: FAIL\n{name} missing from the eval output",
                  file=sys.stderr)
            return 1
        ceiling, bound = DOCUMENTED[export]
        in_range = count <= ceiling
        if raw.lower() == "nan" or raw.lower().endswith("inf"):
            # A PMF is a probability. Neither NaN nor an infinity is one, in
            # range or out of it, so neither is ever an exclusion here.
            violations.append(f"  {export}: {expr} returned {raw}, which is not "
                              f"a probability (reference {reference:.9g})")
            continue
        error = abs(float(raw) - reference) / reference
        where = f"{expr} -> {raw}, reference {reference:.9g}"
        if error > worst_all.get(export, (0.0, ""))[0]:
            worst_all[export] = (error, where)
        if in_range and error > worst_in.get(export, (0.0, ""))[0]:
            worst_in[export] = (error, where)
        if in_range and error > bound:
            violations.append(
                f"  {export}: {expr} = {raw}, reference {reference:.9g}, relative "
                f"error {error:.2e} > the documented {bound:.0e} "
                f"(count parameter {count:.3g} <= {ceiling:.0e})")

    counts = {export: sum(1 for case in spec if case[1] == export)
              for export in DOCUMENTED}
    for export in DOCUMENTED:
        error, where = worst_in.get(export, (0.0, "NO USABLE IN-RANGE CASE"))
        print(f"  {export:14s} {counts[export]:>4} cases, worst IN RANGE "
              f"(<= {DOCUMENTED[export][0]:.0e}) {error:.2e}   {where}")
    print()
    for export in DOCUMENTED:
        error, where = worst_all.get(export, (0.0, "no usable case"))
        print(f"  {export:14s} worst anywhere {error:.2e}   {where}")
    if any(export not in worst_in for export in DOCUMENTED):
        print("\nPMF ACCURACY: FAIL\nan export has no usable case inside its "
              "documented range, so the gate cannot fail for it", file=sys.stderr)
        return 1

    if violations:
        print("\nPMF ACCURACY: FAIL", file=sys.stderr)
        for line in violations:
            print(line, file=sys.stderr)
        print("\nEither the implementation regressed or docs/book overstates the "
              "range. Do not widen DOCUMENTED to make this pass without changing "
              "those documents in the same commit.", file=sys.stderr)
        return 1

    print("PMF ACCURACY: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
