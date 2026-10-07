#!/usr/bin/env python3
"""Measure the beta family's accuracy and enforce the range `docs/book` documents.

`docs/book/src/appendix/precision.md` and `SKILL.md` state a relative-error bound
for `beta_cdf`, `f_cdf`, `student_t_cdf` and `binomial_cdf` and the parameter
range it holds over. Those sentences were unpinned, and two rounds of review
found the claim false in a different place each time, so this script is the gate
for both the implementation and the stated range.

**The range has two edges, and the history of this file is that each one was
wrong in turn.** Round 1 found the range indexed on `min(a, b)`, which for
`student_t_cdf` is permanently 0.5 and so described nothing. Round 2 found the
replacement -- a ceiling of 3e8 on the large parameter -- false at its own
boundary for two of four exports, with grids that stopped a decade below it and a
unit test that accepted a case one decade down. So:

- the **ceiling** on the large parameter and the **floor** on the small one are
  both part of the contract, and
- `cases()` probes each edge **at** its stated value, and
  `test_check_beta_accuracy.py` fails if it stops short.

A guard that cannot fail at its own boundary is how the ceiling came to be wrong.

Two kinds of reference, deliberately:

**Reference-free anchors**, which cannot themselves be wrong. `beta_cdf(0.5,a,a)`
and `f_cdf(1,d,d)` are 0.5 exactly by symmetry, and `student_t_cdf(t, df)` tends
to the standard normal CDF as `df` grows with an O(1/df) error -- so at
`df >= 1e10`, `Phi(1) = 0.8413447460685429` is good to 1e-10. These matter because
past `df = 1e15` SciPy's own `betainc` saturates exactly as Nautilus does (f64
`df + t*t` rounds back to `df`), so SciPy agrees with a wrong answer and cannot
adjudicate it.

**SciPy `betainc`** elsewhere, always at the **f32 value** of every argument
rather than at its decimal spelling.

Values come from the shipped compiler through one batched `chelis eval --file`,
the pattern `parity/run_parity.py` uses, so this measures the real lane and not a
transcription.

**This is a regression detector, not a maximiser, and the distinction is the
point.** The error is rounding-driven, so it oscillates in every parameter: its
maximum over a continuum cannot be found by evaluating finitely many points, and
every refinement of this grid has raised the observed worst (5.7e-7, 1.21e-6,
1.45e-6). Review round 4 found 1.45e-6 at `f_cdf(0.501, 1e8, 2.0)` — a point
0.2% off the derived locus, which this grid contains the neighbourhood of but
not the exact peak of. That is not a gap to close; it is what sampling a
rounding surface does.

So the contract is the **bound plus headroom**, which a finite grid can defend,
rather than a published worst case, which it cannot. The grid's job is to hold
the known-hard corners — both range edges, the branch threshold derived per
parameter pair, the mid-range region, and the hardest case any review has found
— so that a real regression trips the bound. No document quotes the number this
prints, deliberately.

This script does **not** read `precision.md` or `SKILL.md`: `DOCUMENTED` below is
transcribed by hand, so it catches an implementation drift but not a document
drift. `test_the_bound_is_not_silently_widened` pins the table so it cannot move
without a deliberate edit; keeping the documents in step is still a reviewer's
job.

    python3 scripts/check_beta_accuracy.py

Success is exit 0 with a final `BETA ACCURACY: PASS` line. Set `CHELIS_BIN` to
validate an explicit toolchain binary. Requires SciPy; the C-lane oracle beside
this one is stdlib-only and is the one that runs without it.
"""
from __future__ import annotations

import os
import re
import math
import struct
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PROBE = REPO / "src" / "accbeta.ch"
MODULE = "Nautilus.AccBeta"
PHI1 = 0.8413447460685429          # the standard normal CDF at 1

# (ceiling on the large parameter, floor on the small one, permitted relative
# error). The bound carries deliberate headroom over the measurement: every
# refinement of the grid below has raised the observed worst (5.7e-7, 1.21e-6,
# 1.45e-6), so a bound that tracks it is a bound the next refinement falsifies.
# The run prints the current worst; no document quotes it, deliberately.
# Just outside the range: `f_cdf(0.5, 2e8, 0.5)` is 1.7e-6,
# `binomial_cdf(1.5e8, 3e8, 0.5)` is 1.3e-6, and `beta_cdf(0.9, 0.5, 1e-4)` is
# 1.9e-6 with a large parameter of only 0.5.
DOCUMENTED = {
    "beta_cdf": (1e8, 1.0, 2e-6),
    "f_cdf": (1e8, 1.0, 2e-6),
    "student_t_cdf": (1e8, 1.0, 2e-6),
    "binomial_cdf": (1e8, 1.0, 2e-6),
}
CEILING, FLOOR, BOUND = 1e8, 1.0, 2e-6

# The floor is on the parameters a CALLER passes -- `a` and `b`, `d1` and `d2` --
# not on the beta parameters `betai` receives. `student_t_cdf` and `binomial_cdf`
# have no user-facing small parameter to floor: the former's beta `b` is
# structurally 0.5 and the latter's are `n - k` and `k + 1`, both at least 1 for
# any legal `k`. Those cases carry NO_SMALL and the floor does not apply to them,
# which is why the two floor tests exempt them by name rather than by accident.
NO_SMALL = float("inf")            # a case that does not bear on the floor


class AccuracyError(Exception):
    pass


def f32(value: float) -> float:
    return struct.unpack("f", struct.pack("f", value))[0]


def cases() -> list[tuple[str, str, str, float, float, float]]:
    """(name, export, expression, large parameter, reference, small parameter)."""
    from scipy.special import betainc, betaincinv

    out: list[tuple[str, str, str, float, float, float]] = []

    def add(export, expr, large, reference, small=NO_SMALL):
        # Positional names: a descriptive one built from the parameters produced
        # `1e+06`, which the lexer read as a literal suffix. `acc_` is the
        # module's own domain shorthand, which chelis §7.1 requires.
        out.append((f"acc_{len(out)}", export, expr, large, reference, small))

    lit = lambda v: f"cast({f32(v)!r}, f32)"

    # The continued fraction switches branch at x == (a+1)/(a+b+2), and that is
    # where it converges slowest -- so it is where the error peaks. A grid of
    # hand-listed points misses it, which is how this claim came to be false
    # three times running. These helpers DERIVE the locus from the parameters,
    # so the grid cannot drift away from the worst case.
    def beta_threshold(a, b):
        return (a + 1.0) / (a + b + 2.0)

    def f_x_at_threshold(d1, d2):
        """The `x` that puts f_cdf's `u` exactly on the branch threshold."""
        u = beta_threshold(d1 / 2.0, d2 / 2.0)
        if not 0.0 < u < 1.0:
            return None
        return u * d2 / (d1 * (1.0 - u))

    def t_at_boundary(df):
        """student_t's branch boundary: x == threshold reduces to t^2 = 3df/(df+2)."""
        return math.sqrt(3.0 * df / (df + 2.0))

    # A neighbourhood of the threshold, in units of the beta distribution's own
    # standard deviation. A percentage band does not work: at a = b = 1e8 the sd
    # is 3.5e-5, so +-5% of the threshold is ~700 sd and every point but the
    # centre lands where the CDF has saturated and is then excluded. Round 4
    # found 278 of 327 exclusions were exactly that shape.
    SD_STEPS = (0.0, 0.5, -0.5, 1.0, -1.0, 2.0, -2.0, 4.0, -4.0)

    def beta_sd(a, b):
        return math.sqrt(a * b / ((a + b) ** 2 * (a + b + 1.0)))

    def near_threshold(a, b):
        """x values around the branch threshold, spaced by the beta sd."""
        thr, sd = beta_threshold(a, b), beta_sd(a, b)
        out = []
        for k in SD_STEPS:
            x = f32(thr + k * sd)
            if 0.0 < x < 1.0:
                out.append(x)
        # and a few true f32 ulps either side of the threshold itself
        bits = struct.unpack("<I", struct.pack("<f", f32(thr)))[0]
        for delta in (-2, -1, 1, 2):
            x = struct.unpack("<f", struct.pack("<I", bits + delta))[0]
            if 0.0 < x < 1.0:
                out.append(x)
        return list(dict.fromkeys(out))

    # ---- beta_cdf -------------------------------------------------------
    for a in [1e2, 1e3, 1e4, 1e5, 1e6, 1e7, CEILING, 3e8]:
        add("beta_cdf", f"beta_cdf({lit(0.5)}, {lit(a)}, {lit(a)})", f32(a), 0.5)
    for a in [FLOOR, 0.25, 0.5, 1.0, 2.0, 10.0, 1e3, 1e5]:
        for b in [FLOOR, 0.25, 1.0, 10.0, 1e4, 1e6, CEILING]:
            for x in [0.01, 0.2, 0.5, 0.8, 0.9, 0.99]:
                A, B, X = f32(a), f32(b), f32(x)
                add("beta_cdf", f"beta_cdf({lit(x)}, {lit(a)}, {lit(b)})",
                    max(A, B), float(betainc(A, B, X)), min(A, B))
    # x ON the branch threshold, for every (a, b) pair in the grid
    for a in [FLOOR, 1.0, 2.0, 10.0, 1e4, 1e6, CEILING]:
        for b in [FLOOR, 1.0, 2.0, 10.0, 1e4, 1e6, CEILING]:
            A, B = f32(a), f32(b)
            for x in near_threshold(A, B):
                add("beta_cdf", f"beta_cdf({lit(x)}, {lit(a)}, {lit(b)})",
                    max(A, B), float(betainc(A, B, x)), min(A, B))

    # the floor itself, in the shape that breaks below it
    for b in [FLOOR, 2e-3, 5e-3]:
        for x in [0.5, 0.9, 0.99]:
            B, X = f32(b), f32(x)
            add("beta_cdf", f"beta_cdf({lit(x)}, {lit(0.5)}, {lit(b)})",
                max(0.5, B), float(betainc(0.5, B, X)), min(0.5, B))

    # ---- f_cdf ----------------------------------------------------------
    for d in [1e2, 1e4, 1e6, CEILING]:
        add("f_cdf", f"f_cdf({lit(1.0)}, {lit(d)}, {lit(d)})", f32(d), 0.5)
    for d1 in [FLOOR, 0.5, 1.0, 4.0, 100.0, 1e4, 1e6, CEILING]:
        for d2 in [FLOOR, 0.5, 1.0, 10.0, 1e3, 1e6, CEILING]:
            for x in [0.5, 1.0, 3.0]:
                D1, D2, X = f32(d1), f32(d2), f32(x)
                u = D1 * X / (D1 * X + D2)
                add("f_cdf", f"f_cdf({lit(x)}, {lit(d1)}, {lit(d2)})",
                    max(D1, D2), float(betainc(D1 / 2, D2 / 2, u)),
                    min(D1, D2))

    # x ON the branch threshold for f_cdf. `d = 2` and `d = 3` are in the list
    # because they make the beta parameter exactly 1.0 and 1.5 -- the beta-space
    # floor, and structurally the worst corner. Round 4 found f_cdf's peak at
    # d2 = 2, which the previous lists skipped by jumping 1.0 -> 10.0.
    for d1 in [FLOOR, 1.0, 2.0, 4.0, 1e4, 1e6, CEILING]:
        for d2 in [FLOOR, 1.0, 2.0, 3.0, 10.0, 1e3, 1e6, CEILING]:
            D1, D2 = f32(d1), f32(d2)
            for u in near_threshold(D1 / 2.0, D2 / 2.0):
                # invert u = d1*x/(d1*x + d2)
                if not 0.0 < u < 1.0:
                    continue
                x = f32(u * D2 / (D1 * (1.0 - u)))
                if not 0.0 < x < float("inf"):
                    continue
                u_actual = D1 * x / (D1 * x + D2)
                if not 0.0 < u_actual < 1.0:
                    continue
                add("f_cdf", f"f_cdf({lit(x)}, {lit(d1)}, {lit(d2)})",
                    max(D1, D2), float(betainc(D1 / 2, D2 / 2, u_actual)),
                    min(D1, D2))

    # ---- student_t_cdf: df is the large parameter; the small one is always 0.5
    for df in [1.0, 10.0, 1e3, 1e5, 1e7, CEILING]:
        for t in [-2.0, -1.0, 0.5, 1.0, 1.5, 3.0]:
            T, D = f32(t), f32(df)
            x = D / (D + T * T)
            upper = float(betainc(D / 2, 0.5, x)) / 2
            add("student_t_cdf", f"student_t_cdf({lit(t)}, {lit(df)})",
                D, upper if T < 0 else 1 - upper)
    # t ON the branch boundary, both tails. This is the locus that made the
    # previous ceiling false: at df = 1e8 and t = -sqrt(3) the error is 1.2e-6.
    # The neighbourhood here is in `t`, not in `x`, so it is relative plus a few
    # true f32 ulps rather than sd-scaled. The 1.2e-6 case sits at the boundary
    # exactly, which is why the ulp steps matter more than the percentage band.
    for df in [1.0, 10.0, 1e3, 1e5, 1e6, 1e7, 3e7, CEILING]:
        D = f32(df)
        base = t_at_boundary(D)
        ts = [f32(base * m) for m in (0.99, 0.999, 1.0, 1.001, 1.01)]
        bits = struct.unpack("<I", struct.pack("<f", f32(base)))[0]
        ts += [struct.unpack("<f", struct.pack("<I", bits + d))[0]
               for d in (-2, -1, 1, 2)]
        for mag in dict.fromkeys(ts):
            for sign in (1.0, -1.0):
                t = f32(sign * mag)
                x = D / (D + t * t)
                upper = float(betainc(D / 2, 0.5, x)) / 2
                add("student_t_cdf", f"student_t_cdf({lit(t)}, {lit(df)})",
                    D, upper if t < 0 else 1 - upper)

    for df in [1e10, 1e11, 1e12]:          # past where SciPy can adjudicate
        add("student_t_cdf", f"student_t_cdf({lit(1.0)}, {lit(df)})", f32(df), PHI1)

    # ---- binomial_cdf: n is the large parameter -------------------------
    for n in [10.0, 1e3, 1e5, 1e6, 1e7, CEILING]:
        for p in [0.01, 0.3, 0.5, 0.9]:
            # `k = n - 1` is the extreme: it makes the beta parameter `n - k`
            # exactly 1, the smallest any legal `k` can produce.
            for frac in [0.1, 0.5, 0.9, None]:
                k = float(int(n) - 1) if frac is None else float(int(frac * n))
                N, P, K = f32(n), f32(p), f32(k)
                if K >= N:
                    continue
                add("binomial_cdf", f"binomial_cdf({lit(k)}, {lit(n)}, {lit(p)})",
                    N, float(betainc(N - K, K + 1, 1 - P)))
    # The MID-RANGE locus, complementary to the threshold one. Relative error is
    # most meaningful where the CDF is neither saturated nor tiny, and round 4
    # found f_cdf's true peak slightly OFF the threshold, at a point where the
    # value is about 0.135 -- i.e. in this region rather than on the branch
    # switch. `betaincinv` gives the x that puts the CDF on a target value, so
    # this locus is derived too rather than guessed.
    # (5e7, 1.0) is here because it is f_cdf(x, 1e8, 2.0) -- the hardest case any
    # review has found (1.45e-6 in round 4), where d2 = 2 puts the beta parameter
    # exactly at 1.0 and d1 at the ceiling. A known worst case belongs in the grid
    # whether or not it is the maximum.
    for a, b in [(1.0, 1.0), (2.0, 1.0), (1e4, 1.0), (1e6, 1.0), (CEILING, 1.0),
                 (CEILING, 2.0), (1.0, CEILING), (2.0, CEILING), (1e4, 1e4),
                 (CEILING, CEILING), (1e4, CEILING), (CEILING, 1e4),
                 (5e7, 1.0), (5e7, 1.5), (5e7, 5e7)]:
        A, B = f32(a), f32(b)
        for target in (0.05, 0.135, 0.25, 0.5, 0.75, 0.95):
            try:
                x = f32(float(betaincinv(A, B, target)))
            except Exception:
                continue
            if not 0.0 < x < 1.0:
                continue
            add("beta_cdf", f"beta_cdf({lit(x)}, {lit(a)}, {lit(b)})",
                max(A, B), float(betainc(A, B, x)), min(A, B))
            # the same locus reached through f_cdf, whose beta parameters are d/2
            D1, D2 = f32(2.0 * a), f32(2.0 * b)
            u = float(betaincinv(A, B, target))
            if 0.0 < u < 1.0:
                fx = f32(u * D2 / (D1 * (1.0 - u)))
                if 0.0 < fx < float("inf"):
                    ua = D1 * fx / (D1 * fx + D2)
                    if 0.0 < ua < 1.0:
                        add("f_cdf", f"f_cdf({lit(fx)}, {lit(D1)}, {lit(D2)})",
                            max(D1, D2), float(betainc(A, B, ua)), min(D1, D2))

    # binomial_cdf's branch threshold was never derived. Its beta call is
    # I_{1-p}(n-k, k+1), so the threshold `1-p = (a+1)/(a+b+2)` reduces to
    # p* = (k+1)/(n+2). Round 4 found probing it raises binomial's worst 1.4x
    # over the hand-listed p values.
    for n in [10.0, 1e3, 1e5, 1e6, 1e7, CEILING]:
        for frac in [0.0, 0.1, 0.5, 0.9, None]:
            k = float(int(n) - 1) if frac is None else float(int(frac * n))
            N, K = f32(n), f32(k)
            if K >= N or K < 0.0:
                continue
            for om in near_threshold(N - K, K + 1.0):
                p = f32(1.0 - om)
                if not 0.0 < p < 1.0:
                    continue
                add("binomial_cdf", f"binomial_cdf({lit(k)}, {lit(n)}, {lit(p)})",
                    N, float(betainc(N - K, K + 1.0, 1.0 - f32(p))))
    return out


def evaluate(chelis: str, spec: list) -> dict[str, str]:
    names = [case[0] for case in spec]
    body = "\n".join(f"def {case[0]}() -> f32 = {case[2]}" for case in spec)
    PROBE.write_text(f"module {MODULE}\n"
                     "import Nautilus.Distributions (beta_cdf, f_cdf, student_t_cdf, binomial_cdf)\n"
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
        print(f"BETA ACCURACY: FAIL\n{error}", file=sys.stderr)
        return 1

    # Tracked separately on purpose. The documented bound is a claim about the
    # documented range, so quoting a worst case that includes out-of-range inputs
    # is the same number/scope mismatch that made the previous range wrong.
    worst_in: dict[str, tuple[float, str]] = {}
    worst_all: dict[str, tuple[float, str]] = {}
    violations: list[str] = []
    nans: list[str] = []
    excluded = 0
    for name, export, expr, large, reference, small in spec:
        raw = got.get(name)
        if raw is None:
            print(f"BETA ACCURACY: FAIL\n{name} missing from the eval output", file=sys.stderr)
            return 1
        in_range = large <= DOCUMENTED[export][0] and small >= DOCUMENTED[export][1]
        if raw.lower() == "nan":
            # A NaN inside the documented range is a failure, not an exclusion.
            if in_range:
                nans.append(f"  {export}: {expr} returned NaN inside the documented range")
            else:
                excluded += 1
            continue
        if abs(reference) < 1e-30 or reference == 1.0:
            excluded += 1
            continue
        error = abs(float(raw) - reference) / abs(reference)
        where = f"{expr} -> {raw}, reference {reference:.9g}"
        if error > worst_all.get(export, (0.0, ""))[0]:
            worst_all[export] = (error, where)
        if in_range and error > worst_in.get(export, (0.0, ""))[0]:
            worst_in[export] = (error, where)
        if in_range and error > DOCUMENTED[export][2]:
            violations.append(
                f"  {export}: {expr} = {raw}, reference {reference:.9g}, relative error "
                f"{error:.2e} > the documented {DOCUMENTED[export][2]:.0e} "
                f"(large parameter {large:.3g} <= {DOCUMENTED[export][0]:.0e}, "
                f"small {small:.3g} >= {DOCUMENTED[export][1]:.0e})")

    for export in DOCUMENTED:
        error, where = worst_in.get(export, (0.0, "NO USABLE IN-RANGE CASE"))
        print(f"  {export:16s} worst IN RANGE {error:.2e}   {where}")
    print()
    for export in DOCUMENTED:
        error, where = worst_all.get(export, (0.0, "no usable case"))
        print(f"  {export:16s} worst anywhere {error:.2e}   {where}")
    if any(e not in worst_in for e in DOCUMENTED):
        print("\nBETA ACCURACY: FAIL\nan export has no usable case inside its "
              "documented range, so the gate cannot fail for it", file=sys.stderr)
        return 1
    print(f"  ({excluded} cases excluded outside the documented range, or with a "
          f"reference below 1e-30 or exactly 1.0)")

    if violations or nans:
        print("\nBETA ACCURACY: FAIL", file=sys.stderr)
        for line in nans + violations:
            print(line, file=sys.stderr)
        print("\nEither the implementation regressed or docs/book and SKILL.md overstate "
              "the range. Do not widen DOCUMENTED to make this pass without changing "
              "those documents in the same commit.", file=sys.stderr)
        return 1

    print("BETA ACCURACY: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
