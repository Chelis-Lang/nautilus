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
| Distribution CDFs | ~1e-5 to 1e-7 | Depends on underlying special functions; the two families below are stated rather than estimated |
| `poisson_pmf`, `binomial_pmf` | below 2e-6 up to `lambda` of 1e8 and `n` of 2e8 | Log space in f64; past that, limited by f64's spacing at `ln(k!)`, see the note below |
| the gamma family, nine exports | below 2e-6 at every one of the 1626 cases the accuracy gate enforces | Incomplete gamma in f64; the note below describes what that grid covers, and the three regions outside it that are known wrong |
| Beta-family CDFs | below 2e-6 over a stated parameter range | `beta_cdf`, `f_cdf`, `binomial_cdf`; the range is part of the figure, see the note below |
| `student_t_cdf` | below 2e-6 for every `df` | The incomplete beta below `df` of 1e7, the large-`df` expansion from 1e7 upward, see the note below |
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

`beta_cdf`, `f_cdf` and `binomial_cdf` all compute the regularized incomplete
beta, and `student_t_cdf` does too below `df` of 1e7. Its normalizing factor is
`exp(lgamma(a+b) - lgamma(a) - lgamma(b) + a*ln x + b*ln(1-x))`, and that exponent
is a difference of large quantities whose rounding error grows with the
parameters. The incomplete beta is computed in f64 and returned as f32, which
keeps that error small over a wide range but not an unlimited one.

> Relative error stays below 2e-6 when every parameter you pass is at least 1 and
> the largest is at most 1e8. `student_t_cdf` has no upper limit: it holds below
> 2e-6 for every `df` from 1 upward, including an infinite one.

The range applies to `a` and `b` for `beta_cdf`, to `d1` and `d2` for `f_cdf`, to
`df` for `student_t_cdf`, and to `n` for `binomial_cdf`. The upper limit is the
one the incomplete beta imposes, and `student_t_cdf` is the one member of the
family that can leave it behind, for the reason below.

Outside the range the error grows in both directions, and nothing in the result
indicates it. Below 1, a small shape parameter amplifies the same cancellation:
`beta_cdf(0.9, 0.5, 1e-4)` errs by about 2e-6 and `beta_cdf(0.9, 0.5, 1e-10)` by
183%. A large and a small parameter together are worse than either alone, so
`f_cdf(0.5, 1e8, 1e-3)` errs by about 2.5e-5. Above 1e8 the continued fraction
runs out of iterations: on `beta_cdf(0.5, a, a)`, whose value is exactly 0.5 by
symmetry, the relative error is about 8e-6 at `a = 1e9`, 1.2e-3 at 1e10 and 21%
at 1e11, and `beta_cdf(0.5, 3e38, 3e38)` returns a confident 1.0.

`student_t_cdf` would leave the range earliest, because its cancellation is
driven by `df` alone, so above `df` of 1e7 it does not use the incomplete beta at
all. It evaluates the t distribution's own large-`df` expansion instead, which is
`Phi(t) - phi(t) * (t^3 + t) / (4 df)`, where `Phi` and `phi` are the standard
normal CDF and density. Both terms are computed in f64 and the result is
returned as f32.

The `1/df` term is not a refinement you could drop. A plain `Phi(t)` is within
1.4e-9 of the t distribution at `t = 1, df = 1e8`, but its error is governed by
`t` as well, and in the left tail it falls only as `1/df`: at `t = -11` it is
3.7e-4 at `df = 1e7` and 3.7e-5 at 1e8, first reaching 2e-6 around `df = 1.9e9`.
The incomplete beta's own worst passes 2e-6 between `df = 3e8` and 5e8. So a
bare `Phi` branch has no threshold that holds the bound anywhere, whatever `df`
you pick.

The threshold is 1e7 because by there the expansion has reached the incomplete
beta's own noise floor, not because the two cross there.
Through this region the beta form's worst error is flat rounding noise, about
1.1e-7 to 2.0e-7 from `df = 1e6` to 3e7, so no exact crossing point exists to
be found. The expansion is 8.6e-8 at `df = 1e7` and improves as `1/df^2`, so
both forms sit roughly 20x inside the bound where one hands over to the other.

Three things follow that are worth knowing if you read values near the
threshold. The handover is not a uniform improvement: just above it, at `|t|` of
11 and beyond, the expansion is the less accurate of the two, by about a
factor of three at `t = -11`, and by more in the far tail, all of it still well
inside the bound. The threshold also introduces a discontinuity, and it is
small: across the two adjacent representable `df` either side, the two results
are never more than two f32 ulps apart, one ulp at most of the `t` tested and
two in the far tail. And `student_t_cdf(0, df)` is
exactly 0.5 for every `df`, which is the right answer and not a symptom; the
expansion's correction term vanishes at `t = 0`.

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

The front factor, the series and the continued fraction are computed in f64 and
returned as f32. In f32 the error was 51% at `gamma_sf(1e5, 1e5, 1)` and 100%
at shape 1e7, `gamma_pdf(5e7, 5e7, 1)` returned 1.0 against a true 5.6418958e-5,
and `gamma_inv_cdf(0.5, 1e7, 1)` returned 5e29 against a true 1e7.

> Relative error is below 2e-6 at **every one of the 1626 cases**
> `parity/check_gamma_accuracy.py` enforces, on every CI run.

That is a statement about a measured set, not about a parameter range, and the
difference is the whole point of how it is worded. Three review rounds
falsified three earlier versions of this sentence, every one of them in the
same way: each stated a range, and each range quantified over a parameter the
gate did not actually walk. First `q`, where the grid stopped three decades
above a failure region. Then `scale`, which the quantile rows did not vary at
all. Then `shape` *downward*, because the range bounded it only from above
while the grid's ladder starts at 0.5 -- `gamma_inv_cdf(1e-4, 0.07062688, 1e20)`
is 41.5x out, with every parameter inside the range as written.

The shape in that witness is written out in full on purpose. `0.0706` is a
*different* f32 from `0.07062688`, so abbreviating it changes the quantity: the
same call at `0.0706` returns 5.8398956e-36 against a reference of
1.3076e-37, which is 44.7x rather than 41.5x. A figure and the arguments it was
measured at have to travel together. Neither shape is on this grid's ladder,
whose smallest quantile rung is 0.5, which is why the witness is a historical
note here and not a gate row.

So the claim no longer asserts a region. It asserts what was measured, which
cannot be falsified by a point nobody measured, and it leaves the region to the
grid rather than to a sentence that drifts from it.

**What the grid covers**, as a description of the instrument and not a
guarantee beyond it: `shape` on a ladder from 0.5 to each export's ceiling
(5e7 for the gamma trio, `df` 1e8 for the chi-squared trio, `lambda` 5e7 for
`poisson_cdf`, `shape` 1e7 and `df` 2e7 for the quantiles) and one rung past
it; `x` and `k` walked across `shape*scale` in units of the distribution's own
standard deviation, from -20 to +20, plus both sides of the branch point
exactly; `scale` over 1, 2.5 and 0.0078125 for the densities and CDFs, and
1e-20, 1, 2.5 and 1e20 for the quantiles; `q` over ten values from 1e-4 to
0.999. References come from an arbitrary-precision oracle and any whose value
f32 cannot hold as a normal number is excluded.

**Outside that set, three regions are known to be wrong** and are tracked
separately rather than bounded here. Two are in the quantiles and are described
below. The third is the CDF: the parameter guards read the **f32** quotient
`x / scale`, so when that quotient underflows, `gamma_cdf` returns exactly 0.0
for an answer f32 can hold -- `gamma_cdf(1e-30, 0.25, 1e20)` is 0.0 against a
true 3.49e-13, while the same call at `scale = 1` returns the correct 3.49e-8.

Those two limits on the quantiles are one defect seen twice, and it is worth
knowing which, because it tells you when to distrust a value. `gamma_inv_cdf`
refines a closed-form start with at most 80 Newton steps, and each step divides
by the density. Two things make that division useless.

Below `q = 1e-4` for a shape in roughly [1.9, 2.6], the Wilson-Hilferty start's
cube goes negative, so the start is floored; the first Newton step then
overshoots the root by about 27 decades and the budget is spent halving back.
`gamma_inv_cdf(1e-5, 2, 1)` returns 8.271806 against a true 0.0044788163 -- the
99.8th percentile where the 0.001st was asked for -- and
`chi_squared_inv_cdf(1e-5, 4)` is the same point at `df/2`. The returned values
at neighbouring parameters are 1, 2 and 3 times 8.271806, which is the signature:
the answer is a function of how many halvings fitted in the budget, not of `q`.

Above `scale` of about 1e27 the same division fails from the other side. The
floor on the density is absolute at 1e-30 while a Gamma density is about
`1/(scale*sqrt(2*pi*shape))`, so past a large enough scale the true density
falls under the floor and each step removes only a fraction of the error.
`gamma_inv_cdf(0.5, 2, 1e31)` is 3.0e-4 relative, at a median -- nowhere near a
tail, and nothing about the start is degenerate.

Both are convergence limits and not precision limits: raising the budget from 80
to 4000 returns the correctly rounded answer at both witnesses. Neither is
affected by the f64 work described here. Their values move by about eleven f32
ulps across it and their relative errors agree to three digits, so the f64 work
neither causes nor repairs them.

**Do not reach for the CDF as a substitute without checking the same
parameters.** An earlier version of this note recommended solving
`gamma_cdf(x, shape, scale) = q` instead, on the grounds that the CDF is
accurate over fifty decades of `scale`. That was false, for the underflow
reason given above. The CDF is accurate over the grid's own scale range; it is
not a general escape from the quantile's limits.

`parity/check_gamma_accuracy.py` measures all nine exports on every CI run, at
and beyond those ceilings and at the `q` floor, and fails if the bound is exceeded at any case it enforces.
Its grid walks `x` across `shape*scale` in units of the distribution's own
standard deviation, because that is the only place the cancellation is total:
the broken f32 lane was 2.8e-8 relative at `gamma_cdf(10500, 10000, 1)` while
being 4.4e-2 at `gamma_cdf(10000, 10000, 1)`.

Its references are arbitrary-precision rather than SciPy's. `scipy.special`'s
lower regularized incomplete gamma is not accurate enough to adjudicate a
2e-6 claim in the left tail at a large shape: it is 4.3e-6 relative out at
shape 1e6 five standard deviations below the mean, and 22% out at shape 5e7.
Its upper function holds to about 1e-16 over the same grid. If you are
calibrating against a reference of your own, check it in the region you are
calibrating in rather than at the mean.

The two ceilings differ because the quantile costs about six incomplete-gamma
evaluations rather than one, so its grid reaches one decade lower inside a
tolerable run time. Neither ceiling is where the answer becomes wrong; it is
where this bound stops being measured.

Outside the grid two separate limits take over and nothing in the result
indicates either.

The first is the f64 rounding itself. The floor is one f64 ulp of
`lgamma(shape)`, which is quantized and so steps at binade boundaries rather
than growing smoothly: 2.3e-10 at shape 1e5, 3.0e-8 at 1e7, 1.2e-7 at 5e7 and
4.8e-7 at 2e8. It crosses f32's own resolution, about 1.2e-7 relative, at
around shape 3.3e7, so below that the return type hides it completely.

`gamma_pdf` is the one export that probes that floor cleanly, because it is a
single log-space expression with no iteration budget to confound it and no
shape at which it stops converging. Two different things are measured below,
with two different instruments, and keeping them apart is the point.

**That the error grows at all** is settled by evaluating one argument,
`x = shape`, over seven decades:

| shape | relative error at `x = shape` | as a multiple of one f32 ulp |
|---|---|---|
| 1e5 | 3.4e-8 | 0.3x |
| 5e7 | 1.4e-7 | 1.2x |
| 1e9 | 3.4e-6 | 28x |
| 1e10 | 2.1e-5 | 175x |
| 1e11 | 1.5e-4 | 1248x |

One f32 ulp is about 1.2e-7 relative wherever the result lies, so a factor of
1248 cannot be the rounding of the return type. The growth is real.

**How large the error can be** is a different question, and a single argument
cannot answer it. The error is a rounding, so it oscillates: at shape 2e8 this
same measurement gives 1.1e-8, two roundings having cancelled, while the worst
over a neighbourhood of that shape is 3.5e-7 -- thirty times larger at the
same shape. Only the second is a bound, which is why the accuracy gate measures
a neighbourhood rather than a point. Its worst cases sit at 1.2x and 0.7x of
one f64 ulp of `lgamma(shape)`, so that quantity is the envelope.

Read neither table as a function of the shape, and read both as measurements
recorded once rather than as values anything enforces: the only gated claim here
is the quotable bound above. Calibrate against a reference over the parameters
your own calculation visits.

One trap if you measure this yourself. A printed f32 read back as a double is
not the f32 it denotes -- round-tripping guarantees that rounding the double to
f32 recovers the value, not that the double equals it -- and the gap is about
3e-8 relative. At the 1e-7 level that chooses the leading digit of your answer.
Round the parsed value to f32 before comparing.

The second limit is the iteration budget, which is 65536. At the branch point
the series needs 2197 terms at shape 1e5 and 45662 at 5e7, so it is a
square-root scaling rather than a formula -- those are 6.9 and 6.5 times the
square root of the shape. The budget carries the series past shape 1e8, with
exhaustion crossing at about 1.049e8, and beyond that it returns an
unconverged partial sum. Past that point the budget dominates and the rounding floor can no
longer be read off the result: at shape 2e8 the CDFs are 3.8e-6 out while the
density, which spends no iterations, is 3.5e-7.

The error is driven by rounding, so it oscillates in every parameter and no
finite set of sample points locates its maximum. Calibrate tolerances against a
reference over the parameters your calculation actually uses.

### The discrete PMFs are limited by the size of `ln(k!)`, not by the count

`poisson_pmf` and `binomial_pmf` are exponentials of a log-space expression
whose dominant term is `ln(Gamma(k + 1)) = ln(k!)`. An absolute error in that
term is a *multiplicative* error in the answer, and `ln(k!)` grows without
bound: 1.05e6 at `k = 1e5` and 1.74e9 at `k = 1e8`. The precision of the
arithmetic that forms it therefore sets the accuracy of the result, and the
count itself never overflows anything.

Both evaluate that expression in f64 and return an f32. In f32 the error was
5.2% at `poisson_pmf(1e5, 1e5)` and 15% at `binomial_pmf(1e5, 2e5, 0.5)`, and
above `k = 16777216` the `+ 1` in `k + 1` vanished -- the spacing of f32
values at 5e7 is 4 -- so `binomial_pmf(5e7, 1e8, 0.5)` returned `inf` and
`poisson_pmf(5e7, 5e7)` returned 1.0. Neither is a probability, which is the
cheapest way to notice the defect but not its boundary: the error was
continuous in the parameter rather than a cliff at 2^24, already 0.13% at
`binomial_pmf(1e3, 2e3, 0.5)` and 5.4e-6 at `binomial_pmf(100, 200, 0.5)`.

The same bound now applies one dtype up, and it is a gate rather than a
sentence:

> Relative error stays below 2e-6 for `lambda` up to 1e8 and for `n` up to
> 2e8, at every `p`, for any result f32 can hold as a normal number.

`parity/check_pmf_accuracy.py` measures both functions against SciPy on every
CI run, at and beyond those ceilings, and fails if the bound is exceeded
inside the range. The last clause matters: below f32's smallest normal the
return type cannot carry the value at all, and a relative bound there would
measure f32's quantisation rather than this function.

One f64 ulp of `ln(k!)` is 3.81e-6 at `k = 1e9`, and the gate measures 3.8e-6
for `poisson_pmf` and 3.5e-6 for `binomial_pmf` there -- within that one
rounding, so the remaining error is a property of the dtype rather than
something a better algorithm would remove. Nothing in the result signals it,
so outside the range calibrate against a reference over your own parameters.

Eight rows are additionally pinned by name against SciPy references in
`tests/distributions.ch`, from `k = 1e3` to `k = 5e7`. `p` is part of the
claim, not an afterthought: a first version of the gate's grid admitted only
exactly-representable arguments, which silently discarded every skewed `p`
and left the large-`n` figure resting on `p = 0.5` alone. **Which parameters
are worst is a property of the grid, not of the function**, so no figure here
names one -- the error is rounding-driven and its maximum over a continuum is
not findable by evaluating finitely many points.

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
1e-16, which an f64 subtraction gets 11% high and which it returns as 0 once
`t` falls below about 1e-17. Over a sweep of `t` from about 1e-30 to 30, three
rates, five shapes and two scales, both functions return the correctly rounded
f32 at every argument, so neither is half an f32 ulp out anywhere in it.
Rounding is still rounding: calibrate against a reference over the parameters
your own calculation visits rather than reading a guarantee out of a finite
sweep.

`weibull_cdf` forms `(x/scale)^shape` in f64 as well. In f32 that round trip
through `exp(shape * log(x/scale))` carries half an f32 ulp of
`log(x/scale)`, amplified by `exp`. That is 1.1e-6 at an `x/scale` of 1e-8
even when `shape` is 1, so an exact complement of an f32 argument would still
have lost the sixth digit.

`poisson_cdf` lost its left tail the same way, spelled
`1 - gamma_cdf(lambda, k+1, 1)`. It computes `Q(k+1, lambda)` directly instead,
with no round trip through 1.0, so `poisson_cdf(10, 50)` is 6.450153e-12 rather
than 0, seven significant digits of a reference 6.4501529e-12. Its accuracy is
the gamma family's, which is now the measured set stated above rather than the f32
front factor. `k + 1` is formed in f64 as well: in f32 the increment vanished
above `k = 16777216`, since the spacing of f32 values at 5e7 is 4, so
`poisson_cdf(5e7, 5e7)` evaluated `Q(5e7, 5e7)` and came out short by
`poisson_pmf(5e7, 5e7)`. Below f32's smallest normal value the answer is a
subnormal and carries subnormal precision; below half the smallest subnormal,
about 7.0e-46, it is 0 because f32 has nothing else to return.

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
