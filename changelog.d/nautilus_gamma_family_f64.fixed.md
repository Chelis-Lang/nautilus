The regularized incomplete gamma behind `gamma_cdf`, `gamma_sf`, `gamma_pdf`,
`chi_squared_cdf`, `chi_squared_sf`, `poisson_cdf`, `gamma_inv_cdf` and
`chi_squared_inv_cdf` is now evaluated in f64 and returned as f32. **Values
change.** The public signatures do not: this is an internal working precision,
not an f64 surface.

Both branches shared one front factor,
`exp(shape*ln(x) - x - lgamma(shape))`, whose exponent is a difference of three
quantities each about `shape*ln(shape)`. At `x = shape = 1e5` three terms of
1.1e6 collapse to 4.84, and one f32 ulp of the largest is 0.125. An absolute
error in an exponent is a multiplicative error in the result, so that single
rounding set the accuracy of the whole family. Measured against
`scipy.special.gammaincc`, `gamma_sf(shape, shape, 1)` was 2.9e-4 relative at
shape 1e3, 4.4% at 1e4, 51% at 1e5, 94% at 1e6 and 100% at 1e7 and above. Every
one of those values was inside [0, 1], so no range check could see it.

**This was not primarily the 200-iteration budget**, which is what
`docs/book/src/distributions/gamma-family.md` attributed it to: at shape 1e3 the
error was already 2.9e-4 while the series needed about 140 terms of its 200. The
budget did explain the saturation plateau above shape ~4e4, where
`gamma_cdf(1e5, 1e5, 1)` and `chi_squared_cdf(2e5, 2e5)` both returned exactly
0.24656442. Both limits are addressed, and the budget is now 65536 spent through
four levels of 16-way chunking, so peak recursion depth is about 64 frames.

**Three things beyond the front factor.**

`gamma_pdf` has the same cancellation in its own log-space body and was not in
nautilus#152's list of affected exports. `gamma_pdf(5e7, 5e7, 1)` returned
exactly 1.0 against a true 5.6418958e-5 -- a density above every value a
Gamma(5e7, 1) density takes, since that point is its maximum. It is fixed here
because `gamma_inv_cdf` reads it as its Newton derivative, so the quantile
inherited the error from the density as well as from the CDF.

`poisson_cdf` formed `k + 1` in f32, where the increment vanishes above
`k = 16777216` (the spacing of f32 values at 5e7 is 4). It therefore evaluated
`Q(k, lambda)` instead of `Q(k + 1, lambda)` and came out short by exactly
`poisson_pmf(k, lambda)`. That was invisible under a 99.87% front-factor error
and is the entire residual once the front factor is fixed: 1.1e-4 relative at
`poisson_cdf(5e7, 5e7)`. `k + 1` is now formed in f64.

The series' convergence test compared its term against `max(|sum|, 1.0)`, and
that floor made the test absolute wherever the sum fell below 1. The sum is
`P(shape, x)` divided by the front factor, which is 1.8e-4 at shape 5e7, so a
nominal 1e-7 bought a relative 5.6e-4 there. The test is now relative to the
sum, at 1e-13.

**`gamma_inv_cdf` keeps its Newton loop.** Its refinement was 1001x *worse* than
its own Wilson-Hilferty start at shape 1e3 and returned 5e29 at shape 1e7,
because Newton converges on the root of the function it is handed and a biased
CDF moves that root. On that same f32 CDF it was also worth a factor of about
8.1e5 at `gamma_inv_cdf(0.05, 1, 1)`, and about 4.0e7 on the f64 one, where the
closed form alone is 23% out, so removing
it would have traded a large-shape error for a small-shape one five orders of
magnitude bigger. The loop now runs on the f64 CDF and density and stops once a
step moves the estimate by less than 1e-10 of itself, which is a cost control
rather than an accuracy one: 80 unconditional steps each cost a full CDF
evaluation, tens of thousands of series terms near the branch point.

**Guard decisions are unchanged.** The parameter guards still read
the f32 `x / scale`, so a finite `x` whose f32 quotient overflows still answers
as `x = +inf` does. Across a 2990-case review sweep over degenerate and extreme
inputs there is no NaN-to-value, zero-to-value, one-to-value or
infinity-to-value transition at any input carrying a zero, negative, NaN or
infinite argument, and the set of inputs that trap the process is identical on
both lanes. Values at extreme *finite* arguments do move, mostly from nonsense
to sense; two degenerate-argument results move in their last digit only
(`chi_squared_pdf(1, -1)`, `poisson_cdf(0, 1)`), so "unchanged" holds of guard
decisions rather than of every degenerate return. The two pre-existing
`cast_trunc` process traps on a non-finite *shape* are unchanged and remain
tracked elsewhere.

Two new gates. `parity/check_gamma_accuracy.py` measures all nine exports
against an arbitrary-precision reference over a grid that walks `x` across
`shape*scale` in units of the distribution's own standard deviation, at and
beyond each documented ceiling, and is wired into the `scipy-parity` CI job
with its own unit tests. The references are mpmath's rather than SciPy's
because `scipy.special.gammainc` is up to 22% wrong in the left tail at a large
shape; the gate's docstring records the measurement and a unit test pins it.
`scripts/check_gamma_c_lane.py` builds the nine through the C lane in-package
and cross-package and requires bit-identical agreement with the eval lane, plus
anchors that need no reference library: the elementary closed forms at shape 1
and 2, the strict median inequalities `P(a, a) > 0.5 > P(a - 1, a)`, and the
strictly positive `poisson_cdf(k, lam) - gamma_sf(lam, k, 1)` gap that the lost
f32 `k + 1` had collapsed to zero. The sampling C-lane check that already
existed covers keyed gamma-family *sampling*; none of these nine exports had
C-lane coverage.

The documented range and its two limits are in
[the precision appendix](docs/book/src/appendix/precision.md).

**The documented quantile range excludes `q` below 1e-4 and `scale` outside
[1e-20, 1e20].** For a shape in
roughly [1.9, 2.5] below that quantile, `gamma_inv_cdf`'s Wilson-Hilferty start
is floored, the first Newton step overshoots by about 27 decades, and the
80-step budget is spent halving back: `gamma_inv_cdf(1e-5, 2, 1)` returns
8.271806 against a true 0.0044788163, which is the 99.8th percentile rather than
the 0.001st. That is pre-existing and bit-identical on the base commit, so it is
tracked separately rather than fixed here; what this change does is keep the new
bound from claiming it. The gate probes the floor at its stated value and
generates no case below it.

The same floor fails from the other side at a large `scale`: it is absolute at
1e-30 while a Gamma density is about `1/(scale*sqrt(2*pi*shape))`, so
`gamma_inv_cdf(0.5, 2, 1e31)` is 3.0e-4 relative at a median. Also pre-existing
and bit-identical on the base commit. Both are convergence limits rather than
precision ones -- raising the budget from 80 to 4000 returns the correctly
rounded answer at both witnesses -- and the quantile rows now vary `scale` so
the bound cannot be stated over an axis the gate holds fixed.
