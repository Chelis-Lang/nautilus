`poisson_cdf`, `exponential_cdf` and `weibull_cdf` no longer return exactly
`0.0` where the probability they are asked for is itself the small quantity.
**Values change.** The public signatures do not.

This is nautilus#137's class on the other edge. There the lost quantity was a
right tail, which a survival function can compute directly; here it is the
CDF's own small value, which no survival function can reach.

- `poisson_cdf(k, lambda)` spelled `1 - gamma_cdf(lambda, k+1, 1)`, where
  `gamma_cdf` returns a value near `1.0` for `lambda >> k`, so the whole left
  tail arrived as `0.0`. It now returns `gamma_sf(lambda, k+1, 1)`, the same
  quantity `Q(k+1, lambda)` with no round trip through `1.0`.
  `poisson_cdf(10, 50)` returns `6.450134e-12` where it returned `0.0`, six
  significant digits against a true `6.4501529e-12`. The remaining 2.9e-6 is
  `gamma_sf`'s, not the complement's, and the last paragraphs below say why.
  `gamma_sf`'s branch point is the one this needs: a small
  `P(X <= k)` means `lambda >> k + 1`, which is exactly where `gamma_sf`
  evaluates the continued fraction directly instead of complementing.
- `exponential_cdf(x, rate)` and `weibull_cdf(x, shape, scale)` spelled
  `1 - exp(-t)`, which carries absolute error of about `0.5 * ulp(1.0)` --
  6e-8 in f32 -- however accurate `exp` is. Both now form `t` in f64 and
  complement it there, summing a Maclaurin series for `1 - exp(-t)` below
  `t = 1/16` and subtracting above it. `exponential_cdf(1e-8, 1.0)` is `1e-8`
  and `exponential_cdf(1e-20, 1.0)` is `1e-20`, both previously `0.0`.
  `weibull_cdf` forms `(x/scale)^shape` in f64 too: in f32 the round trip
  through `exp(shape * log(x/scale))` carries `eps_f32 * |log(x/scale)|`,
  which is 1.1e-6 at `x/scale = 1e-8` even for `shape = 1`, so an exact
  complement of an f32 `t` would still have lost the sixth digit.

**No new primitive was needed, and none was available.** The issue expected
this half to block on an upstream `expm1`. Chelis has neither `expm1` nor
`log1p`, and its runtime deliberately links no host math-library
transcendental, so every Chelis transcendental is a correctly rounded vendored
kernel whose bits do not depend on the machine. An in-library series is
therefore the route that stays lane-stable, not a stopgap for a missing
builtin.

**Evaluating in f64 alone would not have been enough**, which is why the
series exists. It moves the collapse rather than removing it: the absolute
error becomes `0.5 * ulp_f64(1.0)`, so `1.1e-16 / t` is the envelope on the
relative error. Measured on an f64-only build, through the same f32 return:
indistinguishable from the series at `t = 1e-8` and `t = 1e-9`, 8.7e-8
relative at `1e-10`, 2.2e-5 at `1e-12`, 8.0e-4 at `1e-15`, 11% high at
`1e-16`, and exactly `0.0` from `t = 1e-17` down.
`weibull_cdf(1e-8, 2, 1)` reaches `t = 1e-16` from ordinary arguments and
`exponential_cdf(1e-20, 1.0)` is well inside the dead band; tests pin three
points on that ladder, and the f64-only form fails all three.

Measured against the f64 value of each defining expression, rounded once to
f32, with every argument first rounded to f32 so the reference answers the
call that is actually made. The grid is `poisson_cdf` `lambda` in
(5,10,20,30,50,80,120,200) by `k` at ten fractions of `lambda` from 0 to 2;
`exponential_cdf` `x` over 31 decades from 1 to 1e-30, a dense band either
side of the `1/16` cut, and twelve ordinary values, each at rates
(1, 1.5, 0.25); and `weibull_cdf` thirteen `x` from 1e-12 to 4 by shapes
(0.5, 1, 1.5, 2, 3) by scales (1, 2.5). That is 347 distinct arguments: 76
`poisson_cdf`, 141 `exponential_cdf` and 130 `weibull_cdf`.

| | `poisson_cdf` | `exponential_cdf` | `weibull_cdf` |
|---|---|---|---|
| arguments with an answer that is a normal f32 | 70 | 141 | 130 |
| of those, exactly `0.0` before | 20 | 70 | 36 |
| of those, exactly `0.0` after | 0 | 0 | 0 |
| worst relative error after | 7.2e-5 | 9.0e-8 | 9.5e-8 |

`exponential_cdf` and `weibull_cdf` are inside one f32 ulp across the whole
grid. Rounding error oscillates and no finite sample locates its maximum, so
read those two figures as the absence of anything above the ulp floor rather
than as a located peak.

`poisson_cdf` is a different case: its own complement is gone, and what is
left is the gamma family's limit. `gammaq`'s front factor
`exp(a*ln x - x - lgamma(a))` is still formed in f32, where one rounding of a
term near 850 is an absolute 6e-5 in the exponent. That is 7.2e-5 relative at
`poisson_cdf(160, 200)` here and 6.8e-5 on the previous spelling, so it is not
this change's error. Seven of the 70 rows are relatively worse than before, by
at most 3.8e-6, all of them mid-range values the old double complement
happened to round favourably; one `exponential_cdf` row is worse by 4.9e-8 and
one `weibull_cdf` row by 2.7e-8, both under half an f32 ulp.

Two limits are f32's and remain. Two `poisson_cdf` arguments in the grid have
a true value between `1.2e-38` and `1.4e-45`, which is subnormal and carries
only a few bits; both were `0.0` before and are now within a third of one
subnormal spacing. Four have a true value below half the smallest subnormal,
where `0.0` is the correctly rounded f32 answer, and they return `0.0` both
before and after.

**Ordinary answers move too, and a consumer holding pinned f32 expectations
should plan to re-baseline them.** Moving the arithmetic to f64 changes the
last digit wherever the f32 form was not already correctly rounded, which is
most places. Of the 347 arguments in the grid, **264 return a different f32**:
45 of 76 `poisson_cdf`, 119 of 141 `exponential_cdf`, 100 of 130
`weibull_cdf`. Restricting to the ordinary range, where no small-value
cancellation is in play, 72 of the 124 `exponential_cdf` and `weibull_cdf`
arguments with a reference at or above 1e-3 move, and 16 of the 64 at or above
0.1. For example `weibull_cdf(2, 2, 2.5)` was `0.47270763` and is
`0.47270757` against a reference of `0.472707576`, and
`exponential_cdf(0.25, 1.5)` was `0.3127107` and is `0.31271073` against
`0.312710721`.

**Every one of those ordinary-range moves is toward the reference**, 70 of the
72 at or above 1e-3 and all 16 at or above 0.1; the two exceptions are the
4.9e-8 and 2.7e-8 rows named above. So the change is an accuracy improvement
across the range and not only at the edge, but it is not a no-op anywhere, and
"values change" above should be read literally.

A negative rate is not a distribution and neither spelling rejects it, so
those answers move as well, and by more than a last digit where they had
collapsed: `exponential_cdf(1, -1)` was `-1.7182817` and is `-1.7182819`
against a true `1 - e` of `-1.718281828`, `exponential_cdf(0.01, -1)` was
`-0.010050178` and is `-0.010050166` against `-0.0100501669`, and
`exponential_cdf(1e-8, -1)` was `0.0` and is `-1e-8`. All three are the
correctly rounded f32. What the `[0, 1/16)` window preserves is the branch,
not the precision: a negative `t` keeps landing on the subtraction it always
landed on rather than on a series that would diverge there, and a test pins
that edge.

Addresses nautilus#139.
