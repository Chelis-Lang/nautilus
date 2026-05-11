#!/usr/bin/env python3
"""parity/run_parity.py - scipy oracle for Nautilus.

This is the ONLY Python in the post-cutover Nautilus repo. It exists to
compare Chelis-side function output against scipy reference values.
Internal correctness is asserted in `tests/*.ch` via `chelis test`; this
script catches drift between Nautilus implementations and scipy semantics.

Usage:
    python3 parity/run_parity.py             # diagnostic table
    python3 parity/run_parity.py --strict    # exit 1 on any abs-diff > tol

Mechanics:
    Each chelis eval --file invocation pays the full module-graph compile
    cost (~30-40s on Nautilus). To keep the suite practical, ALL samples for
    a domain (special, distributions) are batched into a single probe with
    `result_N = expr` bindings, then one chelis eval call returns N floats
    that the script parses as `result_N = value` lines from stdout. With
    two domains, total wall-clock is ~70s instead of N * 35s.

If scipy is missing the script prints a diagnostic and exits 0, so the
harness is non-fatal in minimal environments.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import Callable, Iterable, Tuple

PKG = Path(__file__).resolve().parent.parent
PROBE_PATH = PKG / "src" / "probe.ch"

# Result line format from `chelis eval --file`:
#   result_<index> = <float>
# The value side accepts plain floats, scientific notation, and the
# `NaN` / `inf` / `-inf` literals chelis emits for non-finite results.
# Recognising those explicitly lets us distinguish "chelis returned a
# non-finite value" (legitimate FAIL) from "the parser missed the line"
# (parser regression — the line gets logged at the bottom of the run).
# Red-team round 3 HIGH-1.
RESULT_RE = re.compile(
    r"^result_(\d+)\s*=\s*"
    r"(-?(?:\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|nan|NaN|inf|Inf|-inf|-Inf))\s*$"
)


def load_scipy():
    try:
        import numpy as np  # type: ignore
        import scipy.special  # type: ignore
        import scipy.stats  # type: ignore
        return scipy_module(), np
    except ImportError as exc:
        print(f"scipy not available ({exc}); skipping parity", file=sys.stderr)
        return None, None


def scipy_module():
    import scipy  # type: ignore
    return scipy


def chelis_eval_batch(
    imports: str,
    bindings: list[str],
    timeout: int = 120,
) -> dict[int, float]:
    """Write a single batched probe with `bindings` (each a `result_N = expr`
    line), invoke `chelis eval --file`, parse and return {N: value} for every
    matched `result_N = value` line on stdout. Missing entries imply NaN.

    The probe lives at src/probe.ch (chelis requires probes inside the
    package source root). Always unlinked after the call.
    """
    body = (
        "module Nautilus.Probe\n"
        + imports
        + "\n".join(bindings)
        + "\n"
    )
    PROBE_PATH.write_text(body)
    try:
        completed = subprocess.run(
            ["chelis", "eval", "--file", str(PROBE_PATH.relative_to(PKG))],
            cwd=str(PKG),
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        print(f"chelis eval batch failed: {exc}", file=sys.stderr)
        return {}
    finally:
        try:
            PROBE_PATH.unlink()
        except FileNotFoundError:
            pass

    if completed.returncode != 0:
        print(
            f"chelis eval rc={completed.returncode}: {completed.stderr.strip()[:400]}",
            file=sys.stderr,
        )
        return {}

    out: dict[int, float] = {}
    unparsed_result_lines: list[str] = []
    seen: set[int] = set()
    for line in completed.stdout.splitlines():
        s = line.strip()
        m = RESULT_RE.match(s)
        if m is None:
            # Anything that *looks like* a result binding (starts with
            # `result_<digits>`) but doesn't match the value regex is a
            # parser-regression smell — surface it loudly so a future
            # chelis output-format change doesn't masquerade as silent
            # NaN. Red-team round 3 HIGH-1.
            if s.startswith("result_") and "=" in s:
                unparsed_result_lines.append(s)
            continue
        idx = int(m.group(1))
        if idx in seen:
            print(
                f"WARN: duplicate result_{idx} binding in chelis output; "
                f"last-wins (probable run_parity flat-list index collision)",
                file=sys.stderr,
            )
        seen.add(idx)
        try:
            out[idx] = float(m.group(2))
        except ValueError:
            unparsed_result_lines.append(s)
    if unparsed_result_lines:
        print("WARN: chelis emitted result lines the parser couldn't read:",
              file=sys.stderr)
        for s in unparsed_result_lines[:10]:
            print(f"  {s}", file=sys.stderr)
        if len(unparsed_result_lines) > 10:
            print(f"  ... ({len(unparsed_result_lines) - 10} more)",
                  file=sys.stderr)
    return out


def cast_f32(x: float) -> str:
    return f"cast({float(x)!r}, f32)"


# ---------------------------------------------------------------------------
# Per-domain reference tables.
# ---------------------------------------------------------------------------


def special_cases(scipy):
    sp = scipy.special

    def mk1(fn: str):
        return lambda x: f"{fn}({cast_f32(x)})"

    def mk2(fn: str):
        return lambda ab: f"{fn}({cast_f32(ab[0])}, {cast_f32(ab[1])})"

    def trigamma_ref(x):
        return float(sp.polygamma(1, x))

    def airy_ai_ref(x):
        return float(sp.airy(x)[0])

    def airy_bi_ref(x):
        return float(sp.airy(x)[2])

    return [
        ("erf",        mk1("erf"),       lambda x: float(sp.erf(x)),
                                                       [-2.0, -0.5, 0.0, 0.7, 2.0],            5e-6),
        # `erfc` is implemented as `1 - erf(x)`; the tolerance widens for
        # large positive x where catastrophic cancellation eats f32
        # precision (`erf(2)` is already ~0.995, so the tail bits of
        # `1 - erf(2) ~ 0.0047` are at f32 epsilon). Keep samples in the
        # range Shoals actually uses (option pricing tail probabilities).
        ("erfc",       mk1("erfc"),      lambda x: float(sp.erfc(x)),
                                                       [-2.0, -0.5, 0.0, 0.7, 1.5],            5e-5),
        ("erfinv",     mk1("erfinv"),    lambda x: float(sp.erfinv(x)),
                                                       [-0.9, -0.3, 0.5, 0.95],                5e-4),
        ("gamma",      mk1("gamma"),     lambda x: float(sp.gamma(x)),
                                                       [0.5, 1.5, 2.5, 5.0, -0.5, -1.5],       5e-4),
        ("log_gamma",  mk1("log_gamma"), lambda x: float(sp.gammaln(x)),
                                                       [0.5, 1.5, 2.5, 5.0, 10.0],             5e-4),
        ("digamma",    mk1("digamma"),   lambda x: float(sp.digamma(x)),
                                                       [0.5, 1.5, 2.5, 5.0, 10.0],             5e-4),
        ("trigamma",   mk1("trigamma"),  trigamma_ref,
                                                       [0.6, 1.0, 2.0, 5.0, 10.0],             5e-4),
        ("beta",       mk2("beta"),      lambda ab: float(sp.beta(ab[0], ab[1])),
                                                       [(1.0, 1.0), (2.0, 3.0), (4.0, 2.0)],   5e-5),
        ("bessel_i0",  mk1("bessel_i0"), lambda x: float(sp.i0(x)),
                                                       [0.0, 0.5, 1.0, 2.0, 4.0],              5e-3),
        ("bessel_i1",  mk1("bessel_i1"), lambda x: float(sp.i1(x)),
                                                       [0.5, 1.0, 2.0, 4.0],                   5e-3),
        ("bessel_k0",  mk1("bessel_k0"), lambda x: float(sp.k0(x)),
                                                       [0.5, 1.0, 2.0, 4.0],                   5e-3),
        ("bessel_k1",  mk1("bessel_k1"), lambda x: float(sp.k1(x)),
                                                       [0.5, 1.0, 2.0, 4.0],                   5e-3),
        ("bessel_j0",  mk1("bessel_j0"), lambda x: float(sp.j0(x)),
                                                       [0.0, 1.0, 5.0, 8.0],                   5e-3),
        ("bessel_j1",  mk1("bessel_j1"), lambda x: float(sp.j1(x)),
                                                       [0.5, 1.0, 5.0, 8.0],                   5e-3),
        ("bessel_y0",  mk1("bessel_y0"), lambda x: float(sp.y0(x)),
                                                       [0.5, 1.0, 2.0, 5.0],                   5e-2),
        ("bessel_y1",  mk1("bessel_y1"), lambda x: float(sp.y1(x)),
                                                       [0.5, 1.0, 2.0, 5.0],                   5e-2),
        ("airy_ai",    mk1("airy_ai"),   airy_ai_ref,
                                                       [-2.0, -0.5, 0.0, 1.0, 3.0],            5e-3),
        ("airy_bi",    mk1("airy_bi"),   airy_bi_ref,
                                                       [-2.0, -0.5, 0.0, 1.0, 3.0],            5e-3),
        ("ellipk",     mk1("ellipk"),    lambda x: float(sp.ellipk(x)),
                                                       [0.0, 0.25, 0.5, 0.75, 0.9],            5e-3),
        ("ellipe",     mk1("ellipe"),    lambda x: float(sp.ellipe(x)),
                                                       [0.0, 0.25, 0.5, 0.75, 0.9],            5e-3),
    ]


def distribution_cases(scipy):
    st = scipy.stats

    def mk_pdf_3(fn: str, params: tuple):
        # params = (mu, sigma) for normal, (a, b) for uniform, etc.
        return lambda x: f"{fn}({cast_f32(x)}, {cast_f32(params[0])}, {cast_f32(params[1])})"

    def mk_pdf_2(fn: str, params: tuple):
        return lambda x: f"{fn}({cast_f32(x)}, {cast_f32(params[0])})"

    def mk_pmf_2(fn: str, params: tuple):
        # poisson_pmf(k, lambda)
        return lambda k: f"{fn}({cast_f32(k)}, {cast_f32(params[0])})"

    def mk_pmf_3(fn: str, params: tuple):
        # binomial_pmf(k, n, p)
        return lambda k: f"{fn}({cast_f32(k)}, {cast_f32(params[0])}, {cast_f32(params[1])})"

    cases: list = []

    # Normal (mu=1, sigma=2)
    cases += [
        ("normal_pdf(.,1,2)", mk_pdf_3("normal_pdf", (1.0, 2.0)),
            lambda x: float(st.norm.pdf(x, loc=1.0, scale=2.0)),
            [-2.0, 0.0, 1.0, 3.0, 5.0], 5e-5),
        ("normal_cdf(.,1,2)", mk_pdf_3("normal_cdf", (1.0, 2.0)),
            lambda x: float(st.norm.cdf(x, loc=1.0, scale=2.0)),
            [-2.0, 0.0, 1.0, 3.0, 5.0], 5e-5),
        ("normal_inv_cdf(.,1,2)", mk_pdf_3("normal_inv_cdf", (1.0, 2.0)),
            lambda p: float(st.norm.ppf(p, loc=1.0, scale=2.0)),
            [0.05, 0.25, 0.5, 0.75, 0.95], 5e-3),
    ]

    # Uniform (a=0, b=2)
    cases += [
        ("uniform_pdf(.,0,2)", mk_pdf_3("uniform_pdf", (0.0, 2.0)),
            lambda x: float(st.uniform.pdf(x, loc=0.0, scale=2.0)),
            [-1.0, 0.5, 1.0, 1.5, 3.0], 5e-6),
        ("uniform_cdf(.,0,2)", mk_pdf_3("uniform_cdf", (0.0, 2.0)),
            lambda x: float(st.uniform.cdf(x, loc=0.0, scale=2.0)),
            [-1.0, 0.5, 1.0, 1.5, 3.0], 5e-6),
    ]

    # Exponential (lambda=1.5)
    cases += [
        ("exponential_pdf(.,1.5)", mk_pdf_2("exponential_pdf", (1.5,)),
            lambda x: float(st.expon.pdf(x, scale=1.0 / 1.5)),
            [0.0, 0.5, 1.0, 2.0, 4.0], 5e-5),
        ("exponential_cdf(.,1.5)", mk_pdf_2("exponential_cdf", (1.5,)),
            lambda x: float(st.expon.cdf(x, scale=1.0 / 1.5)),
            [0.0, 0.5, 1.0, 2.0, 4.0], 5e-5),
    ]

    # Lognormal (mu=0, sigma=1)
    cases += [
        ("lognormal_pdf(.,0,1)", mk_pdf_3("lognormal_pdf", (0.0, 1.0)),
            lambda x: float(st.lognorm.pdf(x, s=1.0, scale=1.0)),
            [0.5, 1.0, 1.5, 2.0, 3.0], 5e-4),
        ("lognormal_cdf(.,0,1)", mk_pdf_3("lognormal_cdf", (0.0, 1.0)),
            lambda x: float(st.lognorm.cdf(x, s=1.0, scale=1.0)),
            [0.5, 1.0, 1.5, 2.0, 3.0], 5e-4),
    ]

    # Gamma (shape=2, scale=1.5)
    cases += [
        ("gamma_pdf(.,2,1.5)", mk_pdf_3("gamma_pdf", (2.0, 1.5)),
            lambda x: float(st.gamma.pdf(x, a=2.0, scale=1.5)),
            [0.5, 1.0, 2.0, 4.0, 8.0], 5e-4),
        ("gamma_cdf(.,2,1.5)", mk_pdf_3("gamma_cdf", (2.0, 1.5)),
            lambda x: float(st.gamma.cdf(x, a=2.0, scale=1.5)),
            [0.5, 1.0, 2.0, 4.0, 8.0], 5e-4),
    ]

    # Chi-squared (k=4)
    cases += [
        ("chi_squared_pdf(.,4)", mk_pdf_2("chi_squared_pdf", (4.0,)),
            lambda x: float(st.chi2.pdf(x, df=4.0)),
            [0.5, 1.0, 2.0, 4.0, 8.0], 5e-4),
        ("chi_squared_cdf(.,4)", mk_pdf_2("chi_squared_cdf", (4.0,)),
            lambda x: float(st.chi2.cdf(x, df=4.0)),
            [0.5, 1.0, 2.0, 4.0, 8.0], 5e-4),
    ]

    # Student-t (df=5)
    cases += [
        ("student_t_pdf(.,5)", mk_pdf_2("student_t_pdf", (5.0,)),
            lambda x: float(st.t.pdf(x, df=5.0)),
            [-2.0, -0.5, 0.0, 1.0, 3.0], 5e-4),
        ("student_t_cdf(.,5)", mk_pdf_2("student_t_cdf", (5.0,)),
            lambda x: float(st.t.cdf(x, df=5.0)),
            [-2.0, -0.5, 0.0, 1.0, 3.0], 5e-4),
    ]

    # Poisson (lambda=2.5)
    cases += [
        ("poisson_pmf(.,2.5)", mk_pmf_2("poisson_pmf", (2.5,)),
            lambda k: float(st.poisson.pmf(int(k), mu=2.5)),
            [0, 1, 2, 3, 5], 5e-4),
        ("poisson_cdf(.,2.5)", mk_pmf_2("poisson_cdf", (2.5,)),
            lambda k: float(st.poisson.cdf(int(k), mu=2.5)),
            [0, 1, 2, 3, 5], 5e-4),
    ]

    # Binomial (n=10, p=0.3)
    cases += [
        ("binomial_pmf(.,10,0.3)", mk_pmf_3("binomial_pmf", (10.0, 0.3)),
            lambda k: float(st.binom.pmf(int(k), n=10, p=0.3)),
            [0, 2, 3, 5, 8], 5e-4),
        ("binomial_cdf(.,10,0.3)", mk_pmf_3("binomial_cdf", (10.0, 0.3)),
            lambda k: float(st.binom.cdf(int(k), n=10, p=0.3)),
            [0, 2, 3, 5, 8], 5e-4),
    ]

    # Beta (a=2, b=5)
    cases += [
        ("beta_pdf(.,2,5)", mk_pdf_3("beta_pdf", (2.0, 5.0)),
            lambda x: float(st.beta.pdf(x, a=2.0, b=5.0)),
            [0.05, 0.2, 0.4, 0.6, 0.8], 5e-4),
        ("beta_cdf(.,2,5)", mk_pdf_3("beta_cdf", (2.0, 5.0)),
            lambda x: float(st.beta.cdf(x, a=2.0, b=5.0)),
            [0.05, 0.2, 0.4, 0.6, 0.8], 5e-4),
    ]

    # F (d1=4, d2=10)
    cases += [
        ("f_pdf(.,4,10)", mk_pdf_3("f_pdf", (4.0, 10.0)),
            lambda x: float(st.f.pdf(x, dfn=4.0, dfd=10.0)),
            [0.5, 1.0, 2.0, 4.0, 8.0], 5e-4),
        ("f_cdf(.,4,10)", mk_pdf_3("f_cdf", (4.0, 10.0)),
            lambda x: float(st.f.cdf(x, dfn=4.0, dfd=10.0)),
            [0.5, 1.0, 2.0, 4.0, 8.0], 5e-4),
    ]

    # Weibull (shape=1.5, scale=2.0)
    cases += [
        ("weibull_pdf(.,1.5,2)", mk_pdf_3("weibull_pdf", (1.5, 2.0)),
            lambda x: float(st.weibull_min.pdf(x, c=1.5, scale=2.0)),
            [0.5, 1.0, 2.0, 3.0, 5.0], 5e-4),
        ("weibull_cdf(.,1.5,2)", mk_pdf_3("weibull_cdf", (1.5, 2.0)),
            lambda x: float(st.weibull_min.cdf(x, c=1.5, scale=2.0)),
            [0.5, 1.0, 2.0, 3.0, 5.0], 5e-4),
    ]

    return cases


# ---------------------------------------------------------------------------
# Per-domain runner: builds the batched probe, parses results.
# ---------------------------------------------------------------------------


SPECIAL_IMPORTS = (
    "import Nautilus.Special (erf, erfc, erfinv, gamma, log_gamma, digamma, trigamma, beta, "
    "bessel_i0, bessel_i1, bessel_k0, bessel_k1, "
    "bessel_j0, bessel_j1, bessel_y0, bessel_y1, "
    "airy_ai, airy_bi, ellipk, ellipe)\n"
)
DIST_IMPORTS = (
    "import Nautilus.Distributions (normal_pdf, normal_cdf, normal_inv_cdf, "
    "uniform_pdf, uniform_cdf, "
    "exponential_pdf, exponential_cdf, "
    "lognormal_pdf, lognormal_cdf, "
    "gamma_pdf, gamma_cdf, "
    "chi_squared_pdf, chi_squared_cdf, "
    "student_t_pdf, student_t_cdf, "
    "poisson_pmf, poisson_cdf, "
    "binomial_pmf, binomial_cdf, "
    "beta_pdf, beta_cdf, "
    "f_pdf, f_cdf, "
    "weibull_pdf, weibull_cdf)\n"
)


def run_domain(name: str, imports: str, cases: list) -> tuple[int, int]:
    """Run one batched chelis eval for a domain. Returns (passed, failed).

    `cases` is a list of (label, snippet_builder, scipy_ref_callable, samples, tol)
    where snippet_builder(sample) returns a Chelis expression like `erf(cast(0.5, f32))`.
    """
    # Build flat list of (case_idx, sample_idx, label, expr, ref, tol, sample)
    flat = []
    for label, snippet_fn, ref_fn, samples, tol in cases:
        for s in samples:
            flat.append((label, snippet_fn(s), ref_fn(s), tol, s))

    # `chelis eval` can render some scalar-valued expressions as zero-rank
    # tensors, or omit them from multi-binding output. Adding scalar zero is a
    # value-preserving way to force the result line into the numeric scalar
    # form this harness parses.
    bindings = [
        f"result_{i} = add({expr}, cast(0.0, f32))"
        for i, (_, expr, _, _, _) in enumerate(flat)
    ]
    print(f"\n=== {name}: {len(bindings)} samples (one batched chelis eval) ===",
          flush=True)

    # Batched probe (single compile cost)
    results = chelis_eval_batch(imports, bindings, timeout=240)

    passed = 0
    failed = 0
    for i, (label, expr, ref, tol, sample) in enumerate(flat):
        ours = results.get(i, float("nan"))
        diff = abs(ours - ref) if ours == ours else float("inf")
        ok = diff <= tol
        passed += int(ok)
        failed += int(not ok)
        marker = "OK  " if ok else "FAIL"
        print(f"  [{marker}] {label} sample={sample!r:20s} "
              f"chelis={ours:+.7g}  scipy={ref:+.7g}  diff={diff:.2e}",
              flush=True)
    return passed, failed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true",
                        help="exit 1 if any sample exceeds tol")
    args = parser.parse_args()

    scipy, _ = load_scipy()
    if scipy is None:
        return 0

    print(f"parity oracle: chelis vs scipy on {PKG.name}")

    total_pass = 0
    total_fail = 0

    p, f = run_domain("Special", SPECIAL_IMPORTS, special_cases(scipy))
    total_pass += p; total_fail += f

    p, f = run_domain("Distributions", DIST_IMPORTS, distribution_cases(scipy))
    total_pass += p; total_fail += f

    print(f"\nparity totals: {total_pass} passed, {total_fail} failed",
          flush=True)
    if args.strict and total_fail:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
