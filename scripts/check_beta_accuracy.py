#!/usr/bin/env python3
"""Measure the beta family's accuracy and enforce the range `docs/book` documents.

`docs/book/src/appendix/precision.md` and `SKILL.md` state a relative-error bound
for `beta_cdf`, `f_cdf`, `student_t_cdf` and `binomial_cdf` and the parameter
range it holds over. Those sentences were unpinned: a red-team round found two
in-band inputs that exceeded the published bound, and the published safe range
was indexed on `min(a, b)` when the error is driven by the **large** parameter.
This script is the oracle for both, so neither claim can drift again.

Two kinds of reference, deliberately:

**Reference-free anchors**, which cannot themselves be wrong. `beta_cdf(0.5,a,a)`
and `f_cdf(1,d,d)` are 0.5 exactly by symmetry, and `student_t_cdf(t, df)` tends
to the standard normal CDF as `df` grows, with an O(1/df) error -- so at
`df >= 1e10`, `Phi(1) = 0.8413447460685429` is a reference good to 1e-10. These
matter because at `df = 1e16` SciPy's own `betainc` saturates exactly as Nautilus
does (f64 `df + t*t` rounds back to `df`), so SciPy agrees with a wrong answer and
cannot adjudicate it.

**SciPy `betainc`** elsewhere, always evaluated at the **f32 value** of every
argument rather than at its decimal spelling.

Values come from the shipped compiler via one batched `chelis eval --file`, the
pattern `parity/run_parity.py` uses, so this measures the real lane and not a
transcription.

    python3 scripts/check_beta_accuracy.py            # enforce the documented bounds
    python3 scripts/check_beta_accuracy.py --report    # print the full tables

Success is exit 0 with a final `BETA ACCURACY: PASS` line. Set `CHELIS_BIN` to
validate an explicit toolchain binary. Requires scipy; the C-lane oracle beside
this one is stdlib-only and is the one CI runs without it.
"""
from __future__ import annotations

import argparse
import math
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PROBE = REPO / "src" / "accbeta.ch"
MODULE = "Nautilus.AccBeta"
PHI1 = 0.8413447460685429          # the standard normal CDF at 1
NORMAL_LIMIT_DF = 1e10             # from here the O(1/df) correction is below 1e-10

# What docs/book and SKILL.md are allowed to claim. Keyed by export, each entry is
# (governing parameter limit, worst permitted relative error). The governing
# parameter is the LARGE one: max(a, b) for beta, max(d1, d2) for F, df for t and
# n for binomial. Indexing on the small one is the error this script exists to
# prevent recurring.
# Measured worst case inside each range: beta_cdf 4.8e-7 at max(a,b) = 3e8,
# f_cdf 9.3e-7 at max(d1,d2) = 1e8, student_t_cdf 2.9e-7 at df = 3e8,
# binomial_cdf 1.9e-7 at n = 1e8. student_t_cdf is 1.7e-6 at df = 1e9, which is
# why its range ends where the others' do rather than a decade later.
DOCUMENTED = {
    "beta_cdf": (3e8, 1e-6),
    "f_cdf": (3e8, 1e-6),
    "student_t_cdf": (3e8, 1e-6),
    "binomial_cdf": (3e8, 1e-6),
}


class AccuracyError(Exception):
    pass


def f32(value: float) -> float:
    import struct
    return struct.unpack("f", struct.pack("f", value))[0]


def cases() -> list[tuple[str, str, str, float, float]]:
    """(name, export, chelis expression, governing parameter, reference)."""
    from scipy.special import betainc

    out: list[tuple[str, str, str, float, float]] = []

    def add(_label, export, expr, governing, reference):
        # The name is positional on purpose: a descriptive one built from the
        # parameters produced `1e+06`, which the lexer read as a literal suffix.
        # `acc_` is the module's own domain shorthand, which §7.1 requires.
        out.append((f"acc_{len(out)}", export, expr, governing, reference))

    lit = lambda v: f"cast({f32(v)!r}, f32)"

    # beta_cdf: the symmetric anchor (exactly 0.5) plus an asymmetric grid.
    for a in [1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 3e8]:
        add(f"b_sym_{a:.0e}", "beta_cdf",
            f"beta_cdf({lit(0.5)}, {lit(a)}, {lit(a)})", a, 0.5)
    for a in [0.25, 0.5, 1.0, 2.0, 10.0, 1e3, 1e5]:
        for b in [0.25, 1.0, 10.0, 1e4, 1e6, 1e8]:
            for x in [0.01, 0.2, 0.5, 0.8, 0.99]:
                A, B, X = f32(a), f32(b), f32(x)
                add(f"b_{a:g}_{b:g}_{x:g}".replace(".", "p").replace("-", "m"),
                    "beta_cdf", f"beta_cdf({lit(x)}, {lit(a)}, {lit(b)})",
                    max(A, B), float(betainc(A, B, X)))

    # f_cdf: the symmetric anchor plus a grid that includes a tiny denominator df,
    # which is where the published bound was exceeded.
    for d in [1e2, 1e4, 1e6, 1e8]:
        add(f"f_sym_{d:.0e}", "f_cdf", f"f_cdf({lit(1.0)}, {lit(d)}, {lit(d)})", d, 0.5)
    for d1 in [0.5, 1.0, 4.0, 100.0, 1e4, 1e6, 1e8]:
        for d2 in [0.5, 1.0, 10.0, 1e3, 1e6, 1e8]:
            for x in [0.5, 1.0, 3.0]:
                D1, D2, X = f32(d1), f32(d2), f32(x)
                u = D1 * X / (D1 * X + D2)
                add(f"f_{d1:g}_{d2:g}_{x:g}".replace(".", "p"),
                    "f_cdf", f"f_cdf({lit(x)}, {lit(d1)}, {lit(d2)})",
                    max(D1, D2), float(betainc(D1 / 2, D2 / 2, u)))

    # student_t_cdf: df is the governing parameter, and min(a, b) is always 0.5.
    for df in [1.0, 10.0, 1e3, 1e5, 1e7, 1e8, 1e9]:
        for t in [-2.0, -1.0, 0.5, 1.0, 3.0]:
            T, D = f32(t), f32(df)
            x = D / (D + T * T)
            upper = float(betainc(D / 2, 0.5, x)) / 2
            add(f"t_{df:.0e}_{t:g}".replace(".", "p").replace("-", "m"),
                "student_t_cdf", f"student_t_cdf({lit(t)}, {lit(df)})",
                D, upper if T < 0 else 1 - upper)
    # and the reference-free normal limit, beyond where SciPy can adjudicate
    for df in [1e10, 1e11, 1e12]:
        add(f"t_norm_{df:.0e}".replace(".", "p"), "student_t_cdf",
            f"student_t_cdf({lit(1.0)}, {lit(df)})", f32(df), PHI1)

    # binomial_cdf: n is the governing parameter.
    for n in [10.0, 1e3, 1e5, 1e6, 1e8]:
        for p in [0.01, 0.3, 0.5, 0.9]:
            for frac in [0.1, 0.5, 0.9]:
                k = float(int(frac * n))
                N, P, K = f32(n), f32(p), f32(k)
                if K >= N:
                    continue
                add(f"n_{n:.0e}_{p:g}_{frac:g}".replace(".", "p"),
                    "binomial_cdf", f"binomial_cdf({lit(k)}, {lit(n)}, {lit(p)})",
                    N, float(betainc(N - K, K + 1, 1 - P)))
    return out


def evaluate(chelis: str, spec: list) -> dict[str, str]:
    names = [name for name, _, _, _, _ in spec]
    body = "\n".join(f"def {name}() -> f32 = {expr}" for name, _, expr, _, _ in spec)
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
    parser = argparse.ArgumentParser(description="Beta-family accuracy oracle.")
    parser.add_argument("--report", action="store_true", help="print the full tables")
    args = parser.parse_args()
    chelis = os.environ.get("CHELIS_BIN", "chelis")

    try:
        spec = cases()
        got = evaluate(chelis, spec)
    except AccuracyError as error:
        print(f"BETA ACCURACY: FAIL\n{error}", file=sys.stderr)
        return 1

    worst: dict[str, tuple[float, str]] = {}
    violations = []
    unusable = 0
    for name, export, expr, governing, reference in spec:
        raw = got.get(name)
        if raw is None:
            print(f"BETA ACCURACY: FAIL\n{name} missing from the eval output", file=sys.stderr)
            return 1
        if raw.lower() == "nan" or abs(reference) < 1e-30 or reference == 1.0:
            unusable += 1
            continue
        error = abs(float(raw) - reference) / abs(reference)
        if error > worst.get(export, (0.0, ""))[0]:
            worst[export] = (error, f"{expr} -> {raw}, reference {reference:.9g}")
        limit, bound = DOCUMENTED[export]
        if governing <= limit and error > bound:
            violations.append((export, expr, raw, reference, error, governing, bound))

    for export in DOCUMENTED:
        error, where = worst.get(export, (0.0, "no usable case"))
        print(f"  {export:16s} worst relative error {error:.2e}   {where}")
    print(f"  ({unusable} cases excluded: a reference below 1e-30, exactly 1.0, or a NaN result)")

    if violations:
        print("\nBETA ACCURACY: FAIL", file=sys.stderr)
        for export, expr, raw, reference, error, governing, bound in violations:
            print(f"  {export}: {expr} = {raw}, reference {reference:.9g}, "
                  f"relative error {error:.2e} > the documented {bound:.0e} "
                  f"at governing parameter {governing:.3g}", file=sys.stderr)
        print("\nEither the implementation regressed or docs/book and SKILL.md "
              "overstate the bound. Do not widen DOCUMENTED to make this pass "
              "without changing those documents in the same commit.", file=sys.stderr)
        return 1

    print("BETA ACCURACY: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
