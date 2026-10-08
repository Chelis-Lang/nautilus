# Precision guide

Most Nautilus numerical functions operate in f32 (IEEE 754 single precision),
providing approximately 6-7 significant decimal digits. `Nautilus.Special`
functions accept f32 or f64 inputs.
`Nautilus.Rolling` uses f64 series.

The table reports f32 errors. Improvements from f64 vary by function.
Six functions (`gamma`, `log_gamma`, `beta`, `lbeta`, `ellipk`, and `ellipe`)
are limited by f32 rounding rather than by their own coefficients, so at f64
their errors are much smaller. The other approximations improve by less,
depending on the function and argument. Measure the argument range your
calculation uses.

Treat the table as an f32 guide. It has no figure for `beta` or `lbeta`, and
`bessel_y1` has an absolute error of about 1.2e-4 at either dtype just below its large-x seam
at x = 7.5, well away from any zero.

Two cases need separate guidance:

- The Chelis `erf` and `erfc` builtins are correctly rounded at f32 and f64.
  `erfc` calculates the positive tail directly, which prevents the
  cancellation in `1 - erf(x)`.
- `airy_ai` and `airy_bi` above x = 5 use only the leading asymptotic term and
  gain nothing from f64 there; the two dtypes agree to three digits. Below
  x = 5 f64 is far better.

## Precision by function family

| Family | Error guide (relative unless marked absolute) | Notes |
|---|---|---|
| Chelis `erf`, `erfc` | correctly rounded | Builtins, not Nautilus exports |
| `erfinv` | ~1e-8 | Acklam rational approximation via `norminv` |
| `gamma` | ~1e-7 | Lanczos (g=7) with reflection |
| `log_gamma` | ~1e-9 | Lanczos (g=7) with reflection |
| `digamma` | ~1e-7 | Recurrence + asymptotic (x >= 6) |
| `trigamma` | ~1e-6 | Recurrence + asymptotic (x >= 6) |
| `ellipk`, `ellipe` | ~1e-8 | AGM recurrence (quadratic convergence) |
| `bessel_j0`, `j1` | Use absolute comparisons near zeros | Rational polynomial + large-x trig |
| `bessel_y0` | Use absolute comparisons near zeros | Rational + log-singularity |
| `bessel_y1` | ~1.2e-4 absolute at x ≈ 7.4 | Large-x branch from x = 7.5; use absolute comparisons near zeros |
| `bessel_i0`, `i1` | f32 | Polynomial + asymptotic, crossover 3.75 |
| `bessel_k0`, `k1` | f32 | Polynomial/log + asymptotic, crossover 2.0 |
| `airy_ai`, `airy_bi` | f32 for \|x\| <= 5 | See large-negative-x note below |
| Distribution CDFs | ~1e-5 to 1e-7 | Depends on underlying special functions |
| Beta-family CDFs | below 2e-6 over a stated parameter range | `beta_cdf`, `f_cdf`, `student_t_cdf`, `binomial_cdf`; the range is part of the figure, see the note below |
| `normal_cdf` | below 1 ulp for a standard normal, larger for a shifted point (see below) | Chelis `standard_normal_cdf` on `(x-mean)/std` |
| `normal_inv_cdf` | ~1e-7 | Acklam rational via `erfinv` |

## Known precision issues

### The normal CDF left tail depends on the parameters

`normal_cdf` and its elementwise tensor version `normal_cdf_t` (see
[Normal distribution](../distributions/normal.md#tensor-versions))
call the Chelis `standard_normal_cdf` builtin on the standardized point
`w = (x - mean) / std`. The builtin error bound is
about 1.5 units in the last place (ulp). Nautilus rounds `w` before the builtin
receives it. A relative error `d` in `w` becomes a relative error of about
`w^2 d` in `Phi`. Thus the error of these three-argument functions depends on
whether the quotient is exact.

| Parameters | Worst error for `w` in [-12.6, -3] |
|---|---|
| `mean = 0`, `std = 1` | below 1 ulp |
| exactly representable shift, power-of-two scale | below 1 ulp |
| `mean = 0.2`, `std = 1.4` | order 10^2 ulp |

These values are f32 measurements against mpmath at 60 decimal digits. The
reference uses the exact real quotient of the f32 inputs.

The first two rows follow from the arithmetic. For `mean = 0` and `std = 1`,
the quotient is `x`. For an exactly representable shift and a power-of-two
scale, the subtraction and the division are both exact. Thus no argument
error occurs, and only the builtin error remains.

The third row has an argument error of about half an ulp, which `w^2`
multiplies. A check of every f32 in the interval puts the worst case near
215 ulp. Calculate a tolerance from this mechanism, which grows with `|w|`.
Do not calculate it from one sampled value.

The `(x, mean, std)` signature causes this residual error, not the builtin.
To get the stable figure, standardize the point first.

### Bessel function zeros

For `bessel_j0`, `bessel_j1`, `bessel_y0`, and `bessel_y1`, a small absolute
error can produce a large relative error near a zero: relative error divides
the absolute difference by the reference value's magnitude. At an exact zero,
that ratio is undefined. Compare absolute differences there and calibrate
tolerances against a reference over the arguments your calculation uses.
The `bessel_y1` measurement at x ≈ 7.4 describes its approximation-branch
boundary, not an error bound near zeros or across the full domain.

### Airy functions at large negative x

`airy_ai` uses a power series for |x| <= 5 and an exponential asymptotic
for x > 5. For large negative x, only the power series is available (no
asymptotic oscillatory branch is implemented). The function enters an
oscillatory regime for x < 0 and the power series degrades for |x| much
larger than 5. `airy_bi` has the same limitation but is less affected
because it grows exponentially for positive x where the asymptotic
branch covers it.

### The beta family holds below 2e-6 over a stated parameter range

`beta_cdf`, `f_cdf`, `student_t_cdf` and `binomial_cdf` all compute the
regularized incomplete beta. Its normalizing factor is
`exp(lgamma(a+b) - lgamma(a) - lgamma(b) + a*ln x + b*ln(1-x))`, and that exponent
is a difference of large quantities whose rounding error grows with the
parameters. The incomplete beta is computed in f64 and returned as f32, which
keeps that error small over a wide range but not an unlimited one.

> Relative error stays below 2e-6 when every parameter you pass is at least 1 and
> the largest is at most 1e8.

The range applies to `a` and `b` for `beta_cdf`, to `d1` and `d2` for `f_cdf`, to
`df` for `student_t_cdf`, and to `n` for `binomial_cdf`.

Outside the range the error grows in both directions, and nothing in the result
indicates it. Below 1, a small shape parameter amplifies the same cancellation:
`beta_cdf(0.9, 0.5, 1e-4)` errs by about 2e-6 and `beta_cdf(0.9, 0.5, 1e-10)` by
183%. A large and a small parameter together are worse than either alone, so
`f_cdf(0.5, 1e8, 1e-3)` errs by about 2.5e-5. Above 1e8 the continued fraction
runs out of iterations: on `beta_cdf(0.5, a, a)`, whose value is exactly 0.5 by
symmetry, the relative error is about 8e-6 at `a = 1e9`, 1.2e-3 at 1e10 and 21%
at 1e11, and `beta_cdf(0.5, 3e38, 3e38)` returns a confident 1.0.

`student_t_cdf` leaves the range earliest, because its cancellation is driven by
`df` alone: 1.7e-6 at `df = 1e9`, 4e-4 at 1e12, 51% at 1e14, and from
`df = 1e16` it returns exactly 0.5, which is also its value at `t = 0`. **Above
`df` of about 1e9, use `normal_cdf` instead.** The t distribution is within 1e-9
of the standard normal there, so the substitution costs nothing f32 can measure.

A regularized incomplete beta lies in [0, 1]. A converged computation that
overshoots that range by a rounding is clamped to the boundary, because the
boundary is the answer. A computation that exhausts its iteration budget and
lands outside the range returns NaN instead, since such a value carries no
information: `beta_cdf(0.5, 1e12, 1e12)` is NaN. An exhausted budget whose value
is still inside the range is returned, because near the budget the partial value
is usually the better answer.

The error is driven by rounding, so it oscillates in every parameter and no
finite set of sample points locates its maximum. Calibrate tolerances against a
reference over the parameters your calculation actually uses.

### Cancellation in subtraction-heavy expressions

Any computation involving subtraction of nearly-equal f32 values will
suffer catastrophic cancellation. This affects:

- `cosine_distance` when vectors are nearly parallel (1 - sim near 0)
- `variance_vec` for data with very small variance relative to the mean
- `gamma_cdf` for extreme shape/scale ratios

The worst case is `1 - cdf` for an upper tail. The subtraction has an
absolute error of about `0.5 * ulp(1.0)`, which is 6e-8 in f32, for any CDF
accuracy. It returns exactly `0.0` when the true tail is below that value.
Above that value, the result has no significant digits for some distance.
Do not use this subtraction.

Get the upper tail directly. Use `normal_cdf(neg(z), 0, 1)` and
`student_t_cdf(neg(t), df)` by symmetry. Use `gamma_sf` and `chi_squared_sf`
as separate functions. Every upper-tail and two-sided p-value in
`Nautilus.Testing` uses one of these. The two `_lower` functions use the CDF
directly, because the CDF is the tail that they need.

`exponential_cdf` and `weibull_cdf` meet the same subtraction on the other
edge, where the CDF itself is the small value and no survival function can
reach it. Both complement in f64 and sum a Maclaurin series for `1 - exp(-t)`
below `t` of 1/16, so they keep relative precision rather than absolute.
`exponential_cdf(1e-8, 1.0)` is 1e-8, and `weibull_cdf(1e-8, 2.0, 1.0)` is
1e-16, which an f64 subtraction gets 11% high and which it returns as 0 once
`t` falls below about 1e-17. Over a sweep of `t`
from about 1e-30 to 30, three rates, five shapes and two scales, the largest
relative error seen is 9.5e-8, under one f32 ulp. Rounding error oscillates
and no finite sample locates its maximum, so read that as the absence of
anything above the ulp floor and not as a measured peak.

`weibull_cdf` forms `(x/scale)^shape` in f64 as well. In f32 that round trip
through `exp(shape * log(x/scale))` carries about `eps_f32` times
`|log(x/scale)|`, which is 1.1e-6 at an `x/scale` of 1e-8 even when `shape` is
1, so an exact complement of an f32 argument would still have lost the sixth
digit.

`poisson_cdf` lost its left tail the same way, spelled
`1 - gamma_cdf(lambda, k+1, 1)`. It returns `gamma_sf(lambda, k+1, 1)`
instead, the same quantity `Q(k+1, lambda)` with no round trip through 1.0, so
`poisson_cdf(10, 50)` is 6.450134e-12 rather than 0, against a reference of
6.4501529e-12. Its accuracy is the gamma
family's now: the complement is gone, but `gammaq`'s front factor is still
formed in f32, where one rounding of a term near 850 is an absolute 6e-5 in an
exponent, and that reaches 7.2e-5 relative at `poisson_cdf(160, 200)`. Below
f32's smallest normal value the answer is a subnormal and carries subnormal
precision; below half the smallest subnormal, about 7.0e-46, it is 0 because
f32 has nothing else to return.

When f32 precision is insufficient in `Nautilus.Special`, call it at f64
directly. Its functions have an explicit `{f32, f64}` dtype bound. Read the
caveats above first, because several of them are coefficient-limited rather
than dtype-limited. The distribution, linear-algebra, and solver APIs
described here are f32-only.

`Nautilus.Special` does not admit `f16` or `bf16`; these calls are type errors.

## Comparison to scipy

SciPy typically computes in f64, while most Nautilus functions return f32.
Compare values at the precision and inputs appropriate to the calculation;
the functions' approximations have different numerical domains.
