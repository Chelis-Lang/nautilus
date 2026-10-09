#!/usr/bin/env python3
"""Measure the incomplete-gamma family's accuracy and enforce the documented range.

`docs/book/src/appendix/precision.md` and
`docs/book/src/distributions/gamma-family.md` state a relative-error bound for
the nine exports that reach the regularised incomplete gamma, and the
parameter range it holds over (nautilus#152). This script is the gate for both
the implementation and those sentences. Its sibling
`parity/check_beta_accuracy.py` exists because the same claim about the beta
family was found false in a different place in each of two review rounds while
it was prose.

**The error has one mechanism and it sets the shape of the grid.** Every one of
these exports is `exp` of a log-space front factor,
`a*log(x) - x - log_gamma(a)`, multiplied by a series or a continued fraction.
At `x = a` the three terms of that exponent are each about `a*log(a)` and what
they leave is about `0.5*log(a/(2*pi))`: 1.1e6 collapsing to 4.84 at
`a = 1e5`. An absolute error in an exponent is a *multiplicative* error in the
answer, so the floor is one ulp of the largest term -- `a*log(a)*2.2e-16` in
f64 -- and it grows without bound in `a`. In f32 the same ulp is 0.125 at
`a = 1e5`, which is why `gamma_sf(1e5, 1e5, 1)` returned 0.753 against a true
0.4996 and `gamma_pdf(5e7, 5e7, 1)` returned 1.0 against a true 5.64e-5.

**So the grid walks `x` across the branch point in units of the distribution's
own standard deviation** and probes the shape ladder up to and past the
documented ceiling. A fixed offset in `x` would mean nothing across eight
decades of shape, and a grid that stays away from `x ~ a` would miss the defect
entirely: `gamma_cdf(1.05e4, 1e4, 1)` was 2.8e-8 relative on the broken lane
while `gamma_cdf(1e4, 1e4, 1)` was 4.4e-2.

**Two lessons from the sibling gates are built in.**

1. An error bound indexed on a parameter the grid never reaches at its stated
   value cannot fail at its own boundary. `cases()` probes each export's shape
   parameter *at* its documented ceiling, and `test_check_gamma_accuracy.py`
   fails if it stops short.
2. **The location of the worst case is as grid-dependent as its value, and
   neither this file nor any document may claim either.** The run prints the
   current worst; no document quotes it. The bound carries deliberate headroom
   because a rounding-driven maximum over a continuum is not findable by
   evaluating finitely many points.

**The references are mpmath's, because SciPy cannot adjudicate this.** The
first version of this gate used `scipy.special.gammainc`, validated at `x = a`
for `a` from 1e2 to 1e9, where it agrees with mpmath to 1.1e-16. That
validation was not wide enough. `gammainc` is the *lower* regularised
incomplete gamma, and in the left tail at a large shape it is wrong by far more
than the bound this file enforces: 4.3e-6 at `P(1e6, 995000)`, 9.6e-2 at
`P(5e7, 5e7 - 8*sqrt(5e7))` and **22% at `P(5e7, 5e7 - 5*sqrt(5e7))`**. The
gate reported its own subject as failing at the first of those, and the subject
was returning the correctly rounded f32 -- 1.5e-8 from the true value, against
the oracle's 4.3e-6. Had the sign gone the other way it would have passed a
wrong answer.

`gammaincc` -- the *upper* function -- holds to about 1e-16 over the same grid
with one 6.3e-8 outlier, so SciPy's two directions are not equally reliable and
it is the one this family's small values come from that fails. Rather than
reference one direction and not the other, every reference here is mpmath's.

Two things follow and both are deliberate. mpmath is a locked `parity/`
dependency and is named in `scripts/check_oracle_isolation.py`'s oracle set,
so it is confined exactly as SciPy and NumPy are. And the mpmath reference is
itself validated two independent ways, in
`test_check_gamma_accuracy.py`: against a high-precision quadrature of the
density, and against the elementary closed forms at shape 1 and 2. A
disagreement between an oracle and its subject cannot be attributed without a
second route to the oracle.

This is the same shape of finding the beta sibling hit one family over:
`scipy.special.betainc` is 2.15 relative wrong at `df = 1e16`, where it agrees
with the exact wrong answer the implementation used to return.

A reference below f32's smallest normal is excluded: measuring one there
measures f32's own quantisation, not this implementation. For the CDFs and
survival functions a reference of exactly 1.0 is excluded too, since it has no
relative resolution.

    uv run --project parity --frozen python parity/check_gamma_accuracy.py

It runs about eleven minutes on a quiet workstation, over 1673 cases. Most of
that is the compiler evaluating the series near the branch point at the top of
the shape ladder, and about half of it arrived with the `scale` axis the quantile
rows gained in review -- which is the axis that caught a 152x error, so the cost
is bought. Running two copies at once makes both much slower than that; the
grid is CPU-bound and the probe file is shared.

It lives under `parity/` because it imports SciPy, and this repository confines
external-oracle libraries to that directory: `scripts/check_oracle_isolation.py`
fails the build when an oracle import appears anywhere else. The C-lane oracle
`scripts/check_gamma_c_lane.py` is stdlib-only and stays there.

Success is exit 0 with a final `GAMMA ACCURACY: PASS` line. Set `CHELIS_BIN` to
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
PROBE = REPO / "src" / "accgamma.ch"
MODULE = "Nautilus.AccGamma"

# f32's smallest normal. Below it a reference cannot be carried by the return
# type at all, so the comparison would measure f32 rather than Nautilus.
F32_MIN_NORMAL = 1.1754943508222875e-38

# (ceiling on the export's shape-like parameter, permitted relative error).
#
# The parameter is `shape` for the three gamma functions, `df` for the two
# chi-squared ones (whose gamma shape is `df / 2`), and `lambda` for
# `poisson_cdf` (whose gamma shape is `k + 1`, so its `k` axis is uncapped).
#
# Two ceilings and not one, because the quantile costs about six times the CDF.
# The series the CDF spends near the branch point costs 45662 terms at
# `shape = 5e7`, against a 65536 budget, and
# `gamma_inv_cdf` pays that once per Newton step. 1e7 is where the quantile's
# grid stays inside a tolerable run time, so that is what its row claims; the
# CDFs claim 5e7. Neither ceiling is the point at which the answer becomes
# wrong: it is the point past which nothing here measures it.
#
# The bound matches the beta sibling's deliberately. Both families fail through
# one f64 rounding of a log-gamma front factor, so the number that bounds one
# should bound the other, and a reader comparing the two documents should not
# have to work out whether a difference is meaningful. It carries headroom over
# the measurement for the reason in the docstring.
DOCUMENTED = {
    "gamma_cdf": (5e7, 2e-6),
    "gamma_sf": (5e7, 2e-6),
    "gamma_pdf": (5e7, 2e-6),
    "chi_squared_cdf": (1e8, 2e-6),
    "chi_squared_sf": (1e8, 2e-6),
    "chi_squared_pdf": (1e8, 2e-6),
    "poisson_cdf": (5e7, 2e-6),
    "gamma_inv_cdf": (1e7, 2e-6),
    "chi_squared_inv_cdf": (2e7, 2e-6),
}

# Probed past each ceiling as well, so the run reports what the out-of-range
# growth actually is instead of leaving the documents' claim about it
# unmeasured. These rows exercise budget exhaustion and not only the rounding.
# Each is past its ceiling and past the point where the subject's own
# 65536-term budget is exhausted, which crosses just past shape 1e8 -- 64035
# terms at 1e8 and 65576 at 1.05e8. The series needs
# a square-root number of terms at the branch point. A decade past would not
# demonstrate anything more and the reference's cost is linear in those terms.
BEYOND = {
    "gamma_cdf": 2e8, "gamma_sf": 2e8, "gamma_pdf": 2e8,
    "chi_squared_cdf": 4e8, "chi_squared_sf": 4e8, "chi_squared_pdf": 4e8,
    "poisson_cdf": 2e8,
    "gamma_inv_cdf": 5e7, "chi_squared_inv_cdf": 1e8,
}

# `x` is walked in units of the distribution's own standard deviation about its
# own mean. The branch point `x = shape*scale` sits at z = 0 and is where both
# the cancellation and the iteration cost peak, so it is always visited.
Z_WALK = (-20.0, -8.0, -5.0, -3.0, -1.0, 0.0, 1.0, 3.0, 5.0, 8.0, 20.0)
# Above this shape the series costs tens of thousands of terms per case, so the
# walk is thinned rather than the ladder truncated: the ceiling has to be
# probed at its stated value (lesson 1 above) and a thinner walk there still
# straddles the branch point.
THIN_ABOVE = 1e6
Z_THIN = (-3.0, -1.0, 0.0, 1.0, 5.0)
# Three scales, so the standardisation `x / scale` is exercised rather than
# assumed. 0.0078125 is a power of two, which makes the quotient exact and
# isolates the front factor from the division; 2.5 does not, so between them
# they separate a division error from a front-factor one.
#
# Above `THIN_ABOVE` only `scale = 1` is used, for the same cost reason the
# walk is thinned there. The scales are a property of the standardisation,
# which is one division and does not interact with the shape, so probing all
# three at eleven shapes and one at the top four is coverage of the same thing
# rather than a gap. `test_every_scale_is_actually_probed` holds either way.
SCALES = (1.0, 2.5, 0.0078125)
SCALES_THIN = (1.0,)
# The quantiles' documented lower bound on `q`, and the reason it exists.
#
# Below it `gamma_inv_cdf` is not accurate to 2e-6 for a shape in roughly
# [1.9, 2.6]: Wilson-Hilferty's `s` goes negative there, the start is floored
# to `gamma_inv_floor()`, the first Newton step overshoots by about 27 decades
# and the 80-step budget is exhausted halving back. `gamma_inv_cdf(1e-5, 2, 1)`
# returns 8.271806 against a true 0.00447881626 -- the wrong tail, and nothing
# about 8.27 looks wrong to a caller. Measured identical on `0be29bb`, so it is
# pre-existing and tracked separately; what this constant does is stop the
# documents claiming a bound over it.
#
# The region is patchy rather than a clean boundary -- shape 2.1 fails at
# `q = 1e-5` and is correct at `3e-5` -- so the exclusion is stated on `q`,
# which is checkable, and not on shape. At `q = 1e-4` twenty dense shapes from
# 1.6 to 5.4 are all within 5.9e-8, and the upper tail is clean to
# `q = 0.999999`.
QUANTILE_FLOOR = 1e-4
QUANTILES = (QUANTILE_FLOOR, 0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999)
# Shapes where the floored Wilson-Hilferty start is reached, so the quantile
# rows exercise that path rather than only the ordinary one. 1.25 is the shape
# at which raising `gamma_inv_floor()` to the continued fraction's Lentz tiny
# sent the result to +inf; without a row here the whole test suite, the C lane
# and this gate all passed that mutation.
QUANTILE_FLOOR_SHAPES = (1.1, 1.25, 1.5, 1.9, 2.0, 2.5)
# Scales the quantile rows vary, and the reason this axis exists at all.
#
# Round 1 of review found the documented quantile bound false below `q = 1e-4`.
# Round 2 found it false again at a large `scale`, by the same mechanism, on an
# axis the grid did not vary: `gamma_inv_cdf(0.5, 2, 1e31)` is 3.0e-4 relative,
# 152 times the bound, and `q = 0.5` was already in the set. The cause is that
# `gamma_inv_floor()` is an ABSOLUTE 1e-30 floor applied to a DENSITY, whose
# magnitude is about `1/(scale*sqrt(2*pi*shape))`; past a large enough scale the
# true density falls under the floor, the Newton step divides by the floor
# instead, and each step then removes only a fraction `pdf/floor` of the error.
#
# A third round then falsified the narrowed bound a third time, on `shape`
# downward: the range bounded shape only from above while this ladder starts at
# 0.5, and `gamma_inv_cdf(1e-4, 0.0706, 1e20)` is 45x out with every parameter
# inside the range as written. So adding axes to chase a range-shaped claim did
# not work either, and the documents no longer state a range -- they state this
# grid's measured result. This axis stays because it is the one that found the
# round-2 error, not because a sentence quantifies over it.
# The quantiles are clean from 1e-20 to 1e25 at every shape and `q` probed and
# first exceed the bound at 1e27 (`gamma_inv_cdf(1e-4, 1e2, 1e27)` is 7.1e-6),
# so the upper endpoint of 1e20 is seven decades inside the measured failure.
# No failure exists at the small-scale end at all, so 1e-20 is a probing choice
# rather than a margin.
QUANTILE_SCALES = (1e-20, 1.0, 2.5, 1e20)
QUANTILE_SCALES_THIN = (1.0, 1e20)


class AccuracyError(Exception):
    pass


def f32(value: float) -> float:
    return struct.unpack("f", struct.pack("f", value))[0]


def returned(raw: str) -> float:
    """The f32 the lane returned, recovered from the decimal it printed.

    `float(raw)` is NOT that value. Chelis prints the shortest decimal that
    round-trips, and round-tripping guarantees `f32(float(printed)) == the f32`
    -- not `float(printed) == the f32`. Read as a double the decimal sits up to
    about 3e-8 relatively away from the f32 it denotes: `0.8413448` parses to
    0.8413448 where the f32 is 0.84134477376937866, a gap of 3.12e-08.

    That gap is 1.5% of this gate's 2e-6 bound, so it cannot change a verdict,
    but it is a large fraction of the figures the run REPORTS. Measured on this
    gate's own worst cases, comparing `float(raw)` against recovering the f32:
    `gamma_inv_cdf(0.25, 1, 1)` reads as 9.73e-08 one way and 4.95e-08 the
    other, a factor of 1.97. Any figure quoted from this gate at the 1e-7 level
    is otherwise half convention.
    """
    return f32(float(raw))


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


def shape_ladder(ceiling: float, beyond: float) -> list[float]:
    base = [0.5, 1.0, 2.5, 10.0, 100.0, 1e3, 1e4, 1e5, 1e6, 1e7]
    return [s for s in base if s < ceiling] + [ceiling, beyond]


# Working precision for every reference, in decimal digits. Only about ten are
# needed to measure a 2e-6 bound; thirty leaves the reference's own error about
# twenty orders of magnitude below the quantity being measured, so it never
# enters, and the cost of these recursions is linear in the precision.
MP_DPS = 30
# Terms the reference's own series or continued fraction may spend. At the
# branch point the series needs a square-root number of terms, which is wide
# inside this budget at every shape any row reaches. Exhausting it raises
# rather than returning a partial sum: an unconverged reference is not a
# reference, and the sibling gates record what happens when a gate's oracle is
# quietly wrong instead of loudly absent.
MP_MAX_TERMS = 4_000_000
# Relative tolerance for those two recursions, at MP_DPS digits.
MP_TOL = "1e-25"


def references():
    """mpmath reference functions for the five quantities this gate needs.

    The series and the continued fraction are spelled out here rather than taken
    from `mpmath.gammainc`, which ties its own term budget to the working
    precision -- it raises `NoConvergence` on `Q(2^24 + 1, 2^24)` at fifty
    digits, one of the rows this gate exists to measure, and would need the
    precision raised as a proxy for the budget. Spelling them out makes the
    budget explicit and the cost predictable.

    Each branch computes the quantity that is *small* there and takes the other
    as its complement, so no subtraction cancels: the series gives `P` below the
    branch point, where `Q` is near 1, and the continued fraction gives `Q`
    above it.

    Sharing an algorithm with the subject would be a weak oracle on its own --
    a reference cannot catch an error it makes identically, and what it shares
    is the whole composition and not just a kernel. What separates them is the
    arithmetic: at MP_DPS digits these recursions agree with an independent
    high-precision quadrature of the density to about 1e-22, while the
    subject's error is f64 rounding at 1e-16 and worse. The
    independent checks in `test_check_gamma_accuracy.py` close the rest of that
    gap: `mpmath.gammainc` wherever it converges, a high-precision quadrature of
    the density, and the elementary closed forms at shape 1 and 2.
    """
    from mpmath import exp, findroot, log, loggamma, mp, mpf

    mp.dps = MP_DPS
    tol = mpf(MP_TOL)

    def front(a, x):
        return exp(a * log(x) - x - loggamma(a))

    # `P` and `Q` at one `(a, x)` are each other's complement, and `gamma_cdf`,
    # `gamma_sf` and the chi-squared pair reach the same `(shape, x/scale)`.
    # Without this the most expensive recursions in the grid run four times.
    memo: dict = {}

    def cached(kind, a, x, compute):
        key = (kind, str(a), str(x))
        if key not in memo:
            memo[key] = compute(a, x)
        return memo[key]

    def lower_series_uncached(a, x):
        """P(a, x) for x below the branch point."""
        ap, term, acc = a, 1 / a, 1 / a
        for _ in range(MP_MAX_TERMS):
            ap += 1
            term *= x / ap
            acc += term
            if abs(term) < tol * abs(acc):
                return front(a, x) * acc
        raise AccuracyError(
            f"the reference series did not converge for P({a}, {x}) in "
            f"{MP_MAX_TERMS} terms")

    def lower_series(a, x):
        return cached("P", a, x, lower_series_uncached)

    def upper_cf_uncached(a, x):
        """Q(a, x) for x at or above the branch point, by modified Lentz.

        Only called for `x >= a + 1`. Below that this recursion still meets its
        convergence test and the value it converges to is wrong -- measured
        agreeing with the series to 1e-18 at `x = a - sqrt(a)` for shape 1e6 and
        disagreeing by 100% at `x = a - 2*sqrt(a)` -- which is why the split
        exists and why neither this nor the implementation may widen it.
        """
        tiny = mpf(10) ** (-(MP_DPS * 4))
        b = x - a + 1
        c = 1 / tiny
        d = 1 / b
        h = d
        for i in range(1, MP_MAX_TERMS + 1):
            an = -i * (i - a)
            b += 2
            d = an * d + b
            if abs(d) < tiny:
                d = tiny
            c = b + an / c
            if abs(c) < tiny:
                c = tiny
            d = 1 / d
            delta = c * d
            h *= delta
            if abs(delta - 1) < tol:
                return front(a, x) * h
        raise AccuracyError(
            f"the reference continued fraction did not converge for Q({a}, {x}) "
            f"in {MP_MAX_TERMS} terms")

    def upper_cf(a, x):
        return cached("Q", a, x, upper_cf_uncached)

    def p(a, x):
        A, X = mpf(a), mpf(x)
        if X <= 0:
            return mpf(0)
        return lower_series(A, X) if X < A + 1 else 1 - upper_cf(A, X)

    def q(a, x):
        A, X = mpf(a), mpf(x)
        if X <= 0:
            return mpf(1)
        return 1 - lower_series(A, X) if X < A + 1 else upper_cf(A, X)

    def pdf(x, shape, scale):
        X, K, S = mpf(x), mpf(shape), mpf(scale)
        return exp((K - 1) * log(X) - X / S - K * log(S) - loggamma(K))

    def inv(shape, quantile):
        """x with P(shape, x) = quantile, to reference precision.

        Newton's method on the reference `P`, with the reference density as its
        exact derivative, started from SciPy's `gammaincinv`. A root of the
        *reference* is what this gate needs: `gammaincinv` inverts the SciPy
        function the docstring above disqualifies, so it is a starting point and
        not an answer. Four or five steps suffice even when that start is a
        decade out, and each one costs one `P` and one density.

        The result is verified against `P` before it is returned, and a bisection
        over a widened bracket is the fallback. That ordering is the whole point:
        bisection is correct but needs about 170 `P` evaluations, and each `P`
        near the branch point at the largest shape these quantiles reach, 5e7,
        is 69640 series terms.
        """
        from scipy.special import gammaincinv

        K, Q = mpf(shape), mpf(quantile)
        start = float(gammaincinv(shape, quantile))
        if not (0.0 < start < float("inf")):
            start = float(shape)
        x = mpf(start)
        for _ in range(60):
            residual = p(K, x) - Q
            slope = pdf(x, K, 1)
            if slope <= 0:
                break
            step = residual / slope
            nxt = x - step
            if nxt <= 0:
                nxt = x / 2
            converged = abs(nxt - x) < mpf(10) ** (-(MP_DPS - 12)) * abs(x)
            x = nxt
            if converged:
                break
        if abs(p(K, x) - Q) <= mpf(10) ** (-(MP_DPS - 15)) * Q:
            return x
        lo = hi = mpf(start)
        for _ in range(4096):
            if p(K, lo) <= Q:
                break
            lo /= 4
        else:
            raise AccuracyError(f"no lower bracket for inv({shape}, {quantile})")
        for _ in range(4096):
            if p(K, hi) >= Q:
                break
            hi *= 4
        else:
            raise AccuracyError(f"no upper bracket for inv({shape}, {quantile})")
        return findroot(lambda t: p(K, t) - Q, (lo, hi), solver="bisect",
                        tol=mpf(10) ** (-(MP_DPS - 10)))

    return p, q, pdf, inv


def cases() -> list[tuple[str, str, str, float, float]]:
    """(name, export, expression, the export's shape-like parameter, reference)."""
    mp_p, mp_q, mp_pdf, mp_inv = references()

    out: list[tuple[str, str, str, float, float]] = []
    seen: set[tuple[str, tuple[float, ...]]] = set()

    def reference_for(export: str, x: float, shape: float, scale: float) -> float:
        if export == "gamma_cdf":
            return float(mp_p(shape, x / scale))
        if export == "gamma_sf":
            return float(mp_q(shape, x / scale))
        return float(mp_pdf(x, shape, scale))

    def chi_reference(export: str, x: float, df: float) -> float:
        # chi-squared with `df` degrees of freedom is Gamma(df/2, 2).
        shape = f32(0.5) * df
        if export == "chi_squared_cdf":
            return float(mp_p(shape, x / 2.0))
        if export == "chi_squared_sf":
            return float(mp_q(shape, x / 2.0))
        return float(mp_pdf(x, shape, 2.0))

    # Exports whose reference is a probability and must lie in [0, 1].
    probabilities = {"gamma_cdf", "gamma_sf", "chi_squared_cdf",
                     "chi_squared_sf", "poisson_cdf"}

    def add(export: str, args: tuple[float, ...], reference: float,
            parameter: float, allow_one: bool = False) -> None:
        key = (export, args)
        if key in seen:
            return
        seen.add(key)
        # A broken reference must stop the run, not quietly leave the grid.
        # Every exclusion below drops a case, and a negative or NaN reference
        # would be dropped by the smallest-normal test while meaning that the
        # oracle failed rather than that the case is unmeasurable. A sibling
        # gate measured exactly this: forming the lower branch as `1 - Q` at
        # insufficient precision returned a NEGATIVE probability, and the
        # scorer reported a clean-looking 1.00e+00 relative error against it.
        # This reference never forms the cancelling complement, so that path
        # does not exist here -- the assertion is cheap and it is the one that
        # would catch it if it ever did.
        if reference != reference:
            raise AccuracyError(
                f"the reference for {export}{args} is NaN. That is an oracle "
                f"failure, not an unmeasurable case")
        if export in probabilities and not (0.0 <= reference <= 1.0):
            raise AccuracyError(
                f"the reference for {export}{args} is {reference!r}, which is "
                f"not a probability. The oracle is broken, not the subject")
        if reference in (float("inf"), float("-inf")):
            raise AccuracyError(
                f"the reference for {export}{args} is infinite")
        if reference < F32_MIN_NORMAL:
            return
        if not allow_one and reference >= 1.0:
            return
        spelled = ", ".join(lit(value) for value in args)
        # Positional names: a descriptive one built from the parameters
        # produces `1e+06`, which the lexer reads as a literal suffix. `acc_`
        # is the module's own domain shorthand, which chelis §7.1 requires.
        out.append((f"acc_{len(out)}", export, f"{export}({spelled})",
                    parameter, reference))

    # ---- the three gamma functions of (x, shape, scale) ------------------
    for export in ("gamma_cdf", "gamma_sf", "gamma_pdf"):
        ceiling, _ = DOCUMENTED[export]
        for shape in shape_ladder(ceiling, BEYOND[export]):
            K = f32(shape)
            walk = Z_WALK if shape <= THIN_ABOVE else Z_THIN
            for scale in (SCALES if shape <= THIN_ABOVE else SCALES_THIN):
                S = f32(scale)
                mean = K * S
                sd = (K ** 0.5) * S
                for z in walk:
                    X = f32(max(0.0, mean + z * sd))
                    if X <= 0.0:
                        continue
                    # A density is not a probability: it exceeds 1 for a small
                    # shape, so the `< 1` exclusion does not apply to it.
                    add(export, (X, K, S), reference_for(export, X, K, S), shape,
                        allow_one=(export == "gamma_pdf"))
                # The branch point itself, exactly, at both of its sides. The
                # implementation sends `x < shape*scale + scale` to the series
                # and the rest to the continued fraction, so these two cases
                # are the only ones guaranteed to exercise each route against
                # the other at the same parameters.
                for X in (f32(mean), f32(mean + S), f32(mean - S)):
                    if X <= 0.0:
                        continue
                    add(export, (X, K, S), reference_for(export, X, K, S), shape,
                        allow_one=(export == "gamma_pdf"))

    # ---- the chi-squared trio of (x, df) ---------------------------------
    # `chi_squared_pdf(x, df)` is `gamma_pdf(x, df/2, 2)`. It belongs here
    # rather than being taken as covered by `gamma_pdf`, because scale 2 is the
    # only scale it ever uses and `SCALES` does not contain 2.0 -- so without
    # this arm its exact configuration was unprobed.
    for export in ("chi_squared_cdf", "chi_squared_sf", "chi_squared_pdf"):
        ceiling, _ = DOCUMENTED[export]
        for df in shape_ladder(ceiling, BEYOND[export]):
            D = f32(df)
            walk = Z_WALK if df <= 2.0 * THIN_ABOVE else Z_THIN
            sd = (2.0 * D) ** 0.5
            for z in walk:
                X = f32(max(0.0, D + z * sd))
                if X <= 0.0:
                    continue
                # A density is not a probability and may exceed 1.
                add(export, (X, D), chi_reference(export, X, D), df,
                    allow_one=(export == "chi_squared_pdf"))
            add(export, (f32(D), D), chi_reference(export, f32(D), D), df,
                allow_one=(export == "chi_squared_pdf"))

    # ---- poisson_cdf of (k, lambda) --------------------------------------
    # `k` is walked in standard deviations of the Poisson itself. `k = lambda`
    # is the case the lost f32 `+ 1` reached: above `k = 2^24` the increment
    # rounded away, so the call evaluated the wrong gamma shape.
    ceiling, _ = DOCUMENTED["poisson_cdf"]
    for lam in shape_ladder(ceiling, BEYOND["poisson_cdf"]):
        L = f32(lam)
        sd = L ** 0.5
        walk = Z_WALK if lam <= THIN_ABOVE else Z_THIN
        counts = [f32(max(0.0, float(int(L + z * sd)))) for z in walk]
        counts += [0.0, 1.0, f32(float(int(L)))]
        for k in dict.fromkeys(counts):
            # P(X <= k) for a Poisson is Q(k + 1, lambda) exactly.
            add("poisson_cdf", (k, L), float(mp_q(k + 1.0, L)), lam)
    # The 2^24 neighbourhood, where the f32 `k + 1` lost its increment
    # outright. Kept as named rows whether or not they are the worst case.
    for k in (2.0 ** 24 - 1, 2.0 ** 24, 2.0 ** 24 + 2, 5e7):
        K = f32(k)
        add("poisson_cdf", (K, K), float(mp_q(K + 1.0, K)), float(K))

    # ---- the two quantiles -----------------------------------------------
    # The reference is the regularised inverse, so these rows check the whole
    # Wilson-Hilferty-plus-Newton path against the function it is inverting
    # rather than against a round trip through this same implementation.
    ceiling, _ = DOCUMENTED["gamma_inv_cdf"]
    for shape in shape_ladder(ceiling, BEYOND["gamma_inv_cdf"]):
        K = f32(shape)
        # `QUANTILE_FLOOR` stays in the thin set, so the `q` floor and the
        # shape ceiling are probed TOGETHER. A claim with two boundaries can be
        # false where they meet while holding at each one alone, and a corner is
        # the cheapest thing for a thinned grid to drop.
        quantiles = (QUANTILES if shape <= THIN_ABOVE
                     else (QUANTILE_FLOOR, 0.001, 0.5, 0.999))
        for q in quantiles:
            Q = f32(q)
            scales = (QUANTILE_SCALES if shape <= THIN_ABOVE
                      else QUANTILE_SCALES_THIN)
            for scale in scales:
                S = f32(scale)
                add("gamma_inv_cdf", (Q, K, S),
                    float(mp_inv(K, Q)) * S, shape, allow_one=True)
    # The documented `q` floor, at the shapes where the floored Wilson-Hilferty
    # start is actually reached. A bound has to be probed AT its stated value or
    # it cannot fail at its own boundary -- the same rule the ceilings follow,
    # and the rule this gate's docstring names as the reason it exists.
    for shape in QUANTILE_FLOOR_SHAPES:
        K, Q = f32(shape), f32(QUANTILE_FLOOR)
        add("gamma_inv_cdf", (Q, K, f32(1.0)), float(mp_inv(K, Q)), shape,
            allow_one=True)
        # 0.001 as well, which is where raising `gamma_inv_floor()` to the
        # Lentz tiny sent shape 1.25 to +inf.
        Q3 = f32(0.001)
        add("gamma_inv_cdf", (Q3, K, f32(1.0)), float(mp_inv(K, Q3)), shape,
            allow_one=True)
        add("gamma_inv_cdf", (Q3, K, f32(2.0)), float(mp_inv(K, Q3)) * 2.0, shape,
            allow_one=True)
        D = f32(2.0 * shape)
        add("chi_squared_inv_cdf", (Q, D), float(mp_inv(f32(0.5) * D, Q)) * 2.0,
            float(D), allow_one=True)
        add("chi_squared_inv_cdf", (Q3, D), float(mp_inv(f32(0.5) * D, Q3)) * 2.0,
            float(D), allow_one=True)

    ceiling, _ = DOCUMENTED["chi_squared_inv_cdf"]
    for df in shape_ladder(ceiling, BEYOND["chi_squared_inv_cdf"]):
        D = f32(df)
        quantiles = (QUANTILES if df <= 2.0 * THIN_ABOVE
                     else (QUANTILE_FLOOR, 0.001, 0.5, 0.999))
        for q in quantiles:
            Q = f32(q)
            # chi-squared is Gamma(df/2, 2), so its quantile is twice the
            # gamma quantile at half the degrees of freedom.
            add("chi_squared_inv_cdf", (Q, D), float(mp_inv(f32(0.5) * D, Q)) * 2.0,
                df, allow_one=True)
    return out


def evaluate(chelis: str, spec: list) -> dict[str, str]:
    names = [case[0] for case in spec]
    body = "\n".join(f"def {case[0]}() -> f32 = {case[2]}" for case in spec)
    PROBE.write_text(f"module {MODULE}\n"
                     "import Nautilus.Distributions (gamma_cdf, gamma_sf, "
                     "gamma_pdf, gamma_inv_cdf, chi_squared_cdf, "
                     "chi_squared_sf, chi_squared_pdf, chi_squared_inv_cdf, "
                     "poisson_cdf)\n"
                     f"export ({', '.join(names)})\n{body}\n")
    try:
        relative = str(PROBE.relative_to(REPO))
        formatted = subprocess.run([chelis, "fmt", "--inplace", relative], cwd=REPO,
                                   capture_output=True, text=True, timeout=900)
        if formatted.returncode != 0:
            raise AccuracyError(f"chelis fmt failed: {formatted.stderr.strip()[-500:]}")
        done = subprocess.run([chelis, "eval", "--file", relative], cwd=REPO,
                              capture_output=True, text=True, timeout=5400)
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
        print(f"GAMMA ACCURACY: FAIL\n{error}", file=sys.stderr)
        return 1

    # Tracked separately on purpose: the documented bound is a claim about the
    # documented range, so a worst case that mixes out-of-range inputs in is
    # the number/scope mismatch that made the sibling beta range wrong.
    worst_in: dict[str, tuple[float, str]] = {}
    worst_all: dict[str, tuple[float, str]] = {}
    violations: list[str] = []
    for name, export, expr, parameter, reference in spec:
        raw = got.get(name)
        if raw is None:
            print(f"GAMMA ACCURACY: FAIL\n{name} missing from the eval output",
                  file=sys.stderr)
            return 1
        ceiling, bound = DOCUMENTED[export]
        in_range = parameter <= ceiling
        if raw.lower() == "nan" or raw.lower().endswith("inf"):
            # Every reference that reached this list is finite and positive, so
            # neither NaN nor an infinity is an answer to the question asked,
            # in range or out of it. Neither is ever an exclusion here.
            violations.append(f"  {export}: {expr} returned {raw}, which is not "
                              f"a finite value (reference {reference:.9g})")
            continue
        error = abs(returned(raw) - reference) / reference
        where = f"{expr} -> {raw}, reference {reference:.9g}"
        if error > worst_all.get(export, (0.0, ""))[0]:
            worst_all[export] = (error, where)
        if in_range and error > worst_in.get(export, (0.0, ""))[0]:
            worst_in[export] = (error, where)
        if in_range and error > bound:
            violations.append(
                f"  {export}: {expr} = {raw}, reference {reference:.9g}, relative "
                f"error {error:.2e} > the documented {bound:.0e} "
                f"(parameter {parameter:.3g} <= {ceiling:.0e})")

    counts = {export: sum(1 for case in spec if case[1] == export)
              for export in DOCUMENTED}
    for export in DOCUMENTED:
        error, where = worst_in.get(export, (0.0, "NO USABLE IN-RANGE CASE"))
        print(f"  {export:21s} {counts[export]:>4} cases, worst IN RANGE "
              f"(<= {DOCUMENTED[export][0]:.0e}) {error:.2e}   {where}")
    print()
    for export in DOCUMENTED:
        error, where = worst_all.get(export, (0.0, "no usable case"))
        print(f"  {export:21s} worst anywhere {error:.2e}   {where}")
    if any(export not in worst_in for export in DOCUMENTED):
        print("\nGAMMA ACCURACY: FAIL\nan export has no usable case inside its "
              "documented range, so the gate cannot fail for it", file=sys.stderr)
        return 1

    if violations:
        print("\nGAMMA ACCURACY: FAIL", file=sys.stderr)
        for line in violations:
            print(line, file=sys.stderr)
        print("\nEither the implementation regressed or docs/book overstates the "
              "range. Do not widen DOCUMENTED to make this pass without changing "
              "those documents in the same commit.", file=sys.stderr)
        return 1

    print("GAMMA ACCURACY: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
