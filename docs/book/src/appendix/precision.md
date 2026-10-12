# Precision guide

Most Nautilus numerical functions operate in f32 (IEEE 754 single precision),
providing approximately 6-7 significant decimal digits. `Nautilus.Special`
functions accept f32 or f64 inputs.
`Nautilus.Rolling` uses f64 series.

The table reports f32 errors. The `{f32, f64}` Special functions can give
different accuracy at f64; their coefficients and formulas still set a
limit. Measure the argument range your calculation uses.

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
| Distribution CDFs | ~1e-5 to 1e-7 | Depends on underlying special functions; the two families below are stated rather than estimated |
| `poisson_pmf`, `binomial_pmf` | below 2e-6 at measured cases through `lambda` of 1e8 and `n` of 2e8 | Log space in f64; the note below states the sampled axes and limits |
| the gamma family, nine exports | below 2e-6 at 1655 measured cases | Incomplete gamma in f64; the note below describes the sampled axes and two known failure regions outside them |
| Beta-family CDFs | below 2e-6 at measured cases through parameter 1e8 | `beta_cdf`, `f_cdf`, `binomial_cdf`; the note below states the sampled axes |
| `student_t_cdf` | below 2e-6 at measured cases through `df` 1e20 | The incomplete beta below `df` of 1e7 and a large-`df` expansion above it |
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

The first two rows follow from the arithmetic. For `mean = 0` and `std = 1`,
the quotient is `x`. For an exactly representable shift and a power-of-two
scale, the subtraction and the division are both exact. Thus no argument
error occurs, and only the builtin error remains.

The third row has an argument error of about half an ulp, which `w^2`
multiplies. Calculate a tolerance that accounts for this growth with `|w|`.

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

### Beta-family accuracy across measured cases

`beta_cdf`, `f_cdf` and `binomial_cdf` all compute the regularized incomplete
beta, and `student_t_cdf` does too below `df` of 1e7. Its normalizing factor is
`exp(lgamma(a+b) - lgamma(a) - lgamma(b) + a*ln x + b*ln(1-x))`, and that exponent
is a difference of large quantities whose rounding error grows with the
parameters. The incomplete beta is computed in f64 and returned as f32, which
keeps that error small over a wide range but not an unlimited one.

> Relative error is below 2e-6 at the measured cases for `beta_cdf`,
> `f_cdf` and `binomial_cdf` through caller parameter 1e8, and for
> `student_t_cdf` through `df` 1e20.

The beta measurements vary `a` and `b` or `d1` and `d2` from 1 through 1e8,
probe CDF values across the domain and around the incomplete-beta branch
boundary, and include symmetric and skewed parameter pairs. The binomial
measurements vary `n` from 10 through 1e8, `p` at 0.01, 0.3, 0.5 and 0.9 and
around its branch boundary, and `k` at fractions of `n` and `n - 1`. The
Student-t measurements vary `df` from 1 through 1e20, `t` from -11 through 3,
and probe both sides of the branch boundary and the handover at `df = 1e7`.
These are sampled axes, not a guarantee for every point between them. An
infinite `df` uses the standard normal distribution exactly.

Outside the measured parameter limits the error can grow in both directions, and nothing in the result
indicates it. Below 1, a small shape parameter amplifies the same cancellation:
`beta_cdf(0.9, 0.5, 1e-4)` errs by about 2e-6 and `beta_cdf(0.9, 0.5, 1e-10)` by
183%. A large and a small parameter together are worse than either alone, so
`f_cdf(0.5, 1e8, 1e-3)` errs by about 2.5e-5. Above 1e8 the continued fraction
runs out of iterations: on `beta_cdf(0.5, a, a)`, whose value is exactly 0.5 by
symmetry, the relative error is about 8e-6 at `a = 1e9`, 1.2e-3 at 1e10 and 21%
at 1e11, and `beta_cdf(0.5, 3e38, 3e38)` returns a confident 1.0.

`student_t_cdf` uses the incomplete beta below `df = 1e7` and the large-`df`
expansion `Phi(t) - phi(t) * (t^3 + t) / (4 df)` at and above that value,
where `Phi` and `phi` are the standard normal CDF and density. It computes
both terms in f64 and returns f32. Keep the `1/df` correction when using a
normal approximation of a large-`df` Student-t tail. At `t = 0`, the
function returns exactly 0.5 for valid `df`.

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

### The gamma family holds below 2e-6 over a measured set of cases

`gamma_cdf`, `gamma_sf`, `gamma_pdf`, `chi_squared_cdf`, `chi_squared_sf`,
`chi_squared_pdf`, `poisson_cdf`, `gamma_inv_cdf` and `chi_squared_inv_cdf` all
reach the regularized incomplete gamma. Its front factor is
`exp(shape*ln(x) - x - lgamma(shape))`, a difference of three quantities each
about `shape*ln(shape)`. At `x = shape` they nearly cancel: three terms of 1.1e6
leave 4.84 at shape 1e5. An absolute error in an exponent is a multiplicative
error in the result, so one rounding of the largest term sets the accuracy of
the whole family, and the size of that rounding grows with the shape.

The front factor, series, and continued fraction are computed in f64 and
returned as f32.

> Relative error is below 2e-6 at every one of 1655 measured cases.

This describes measured cases, not every parameter in a range. In particular,
`gamma_inv_cdf(1e-4, 0.07062688, 1e20)` returns 5.8421183e-36 against a
reference of 1.3742135e-37, a relative error of 41.5. Its shape is below the
smallest quantile shape in the measured set, 0.5. The full shape matters:
`0.0706` is a different f32 and changes the result.

**The measured set covers:** `shape` on a ladder from 0.5 to each export's ceiling
(5e7 for the gamma trio, `df` 1e8 for the chi-squared trio, `lambda` 5e7 for
`poisson_cdf`, `shape` 1e7 and `df` 2e7 for the quantiles) and one rung past
it; `x` and `k` walked across `shape*scale` in units of the distribution's own
standard deviation, from -20 to +20, plus both sides of the branch point
exactly; `scale` over 1, 2.5 and 0.0078125 for the densities and CDFs, and
1e-20, 1, 2.5 and 1e20 for the quantiles; `q` over ten values from 1e-4 to
0.999. References come from an arbitrary-precision oracle and any whose value
f32 cannot hold as a normal number is excluded.

The four CDFs and survival functions carry one rung off that walk: a far lower
tail at a shape below 1, where the standardised argument `x / scale` is zero in
f32 and exact in f64 -- `gamma_cdf(1e-30, 0.5, 1e20)` and
`chi_squared_cdf(1.4e-45, 1)` among them. The walk cannot reach it at any
scale, because it places `x` within twenty standard deviations of
`shape*scale`, where the quotient is about `shape`. Two of the rung's shapes
are small enough that the *upper* tails resolve there as well, since `1 - P` is
visible in f32 only once `P` passes `2^-25`, about 3.0e-8 -- half the spacing
below 1.0, because the subtraction rounds to nearest. Without them a guard
reinstated on one direction alone would be invisible to every gate.

**Outside that set, two regions are known to be wrong.** Both are in the
quantiles and are described below.

Those two limits on the quantiles are one defect seen twice, and it is worth
knowing which, because it tells you when to distrust a value. `gamma_inv_cdf`
refines a closed-form start with at most 80 Newton steps, and each step divides
by the density. Two things make that division useless.

Below `q = 1e-4` for a shape in roughly [1.9, 2.6], the Wilson-Hilferty start's
cube goes negative, so the start is floored; the first Newton step then
overshoots the root by about 27 decades and the budget is spent halving back.
`gamma_inv_cdf(1e-5, 2, 1)` returns 8.271806 against a true 0.0044788163,
the 99.8th percentile where the 0.001st was asked for, and
`chi_squared_inv_cdf(1e-5, 4)` is the same point at `df/2`. The returned values
at neighbouring parameters are 1, 2 and 3 times 8.271806, which is the signature:
the answer is a function of how many halvings fitted in the budget, not of `q`.

Above `scale` of about 1e27 the same division fails from the other side. The
floor on the density is absolute at 1e-30 while a Gamma density is about
`1/(scale*sqrt(2*pi*shape))`, so past a large enough scale the true density
falls under the floor and each step removes only a fraction of the error.
`gamma_inv_cdf(0.5, 2, 1e31)` is 3.0e-4 relative at a median, far from a
tail, and nothing about the start is degenerate.

Both are convergence limits of the 80-step Newton refinement. A wider
working precision alone does not extend that iteration budget.

**Do not reach for the CDF as a substitute without checking the same
parameters.** The CDF is accurate over the measured scale values, which is not
the same as accurate over the quantile's range; it is not a general escape from
the quantile's limits.

For your own calibration, check the reference in the tails and at the
parameters you use. A match near the mean does not establish tail accuracy.

Outside the grid two separate limits take over and nothing in the result
indicates either.

The first is the f64 rounding itself. The floor is one f64 ulp of
`lgamma(shape)`, which is quantized and so steps at binade boundaries rather
than growing smoothly: 2.3e-10 at shape 1e5, 3.0e-8 at 1e7, 1.2e-7 at 5e7 and
4.8e-7 at 2e8. It crosses f32's own resolution, about 1.2e-7 relative, at
around shape 3.3e7, so below that the return type hides it completely.

`gamma_pdf` exposes this limit without an iteration budget. At
`x = shape = 1e11`, one measured relative error is 1.5e-4. Rounding error
varies with the parameters, so calibrate against a reference over the region
your calculation visits. When comparing a printed f32 value with a double
reference, round the parsed value back to f32 first.

The second limit is the iteration budget, which is 65536. At the branch point
the series needs 2197 terms at shape 1e5 and 45662 at 5e7, so it is a
square-root scaling: those are 6.9 and 6.5 times the
square root of the shape. The budget carries the series past shape 1e8, with
exhaustion crossing at about 1.049e8, and beyond that it returns an
unconverged partial sum. Past that point the budget dominates and the rounding floor can no
longer be read off the result: at shape 2e8 the CDFs are 3.8e-6 out while the
density, which spends no iterations, is 3.5e-7.

The error is driven by rounding, so it oscillates in every parameter and no
finite set of sample points locates its maximum. Calibrate tolerances against a
reference over the parameters your calculation actually uses.

### Large-count discrete PMFs

`poisson_pmf` and `binomial_pmf` are exponentials of a log-space expression
whose dominant term is `ln(Gamma(k + 1)) = ln(k!)`. An absolute error in that
term is a *multiplicative* error in the answer, and `ln(k!)` grows without
bound: 1.05e6 at `k = 1e5` and 1.74e9 at `k = 1e8`. The precision of the
arithmetic that forms it therefore limits the accuracy of the result. The
formula avoids forming the factorial itself.

Both evaluate that expression in f64 and return f32. The `k + 1` term is
formed in f64. For non-negative integer `k` below `2^53`, that increment is
exact; at `k = 2^53`, adding 1 rounds back to `k`.

> Relative error is below 2e-6 at every measured normal-f32 case through
> `lambda = 1e8` for `poisson_pmf` and `n = 2e8` for `binomial_pmf`.

The Poisson cases sample `lambda` from 0.5 through 1e8. At each value they
probe integer `k` at offsets from -20 to +20 standard deviations around the
mean, plus 0, 1, twice the mean and ten times the mean. The binomial cases
sample `n` from 10 through 2e8. They probe fractions of `n` at `p = 0.5`,
and the mode, both endpoints, and offsets from -5 to +5 standard deviations
for `p` values from 1e-7 to 0.999999, including 0.5. The measured set also
includes cases beyond both ceilings. References below f32's smallest normal
are excluded because relative error there measures output quantisation.

At `k = 1e9`, measured relative errors are 3.8e-6 for `poisson_pmf` and
3.5e-6 for `binomial_pmf`. Outside the sampled range, calibrate a tolerance
against a reference over the parameters your calculation uses.

Note also that f32 cannot represent consecutive integers above 16777216, so a
count passed as an f32 above that is already on a grid coarser than 1. If your
counts are that large, the dtype is the first thing to fix.

### Cancellation in subtraction-heavy expressions

Any computation involving subtraction of nearly-equal f32 values will
suffer catastrophic cancellation. This affects:

- `cosine_distance` when vectors are nearly parallel (1 - sim near 0)
- `variance_vec` for data with very small variance relative to the mean
- `gamma_cdf` for extreme shape/scale ratios, bounded as stated above

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
1e-16. Calibrate against a reference over the parameters your calculation
visits.

`weibull_cdf` also forms `(x/scale)^shape` in f64 before complementing it.

`poisson_cdf` computes `Q(k+1, lambda)` directly, with no round trip through
1.0. At `(k, lambda) = (10, 50)` it returns 6.450153e-12 against a reference
6.4501529e-12. It forms `k + 1` in f64. Below f32's smallest normal value
the answer has subnormal precision; below about 7.0e-46 it rounds to zero.

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
