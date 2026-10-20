# Gamma family distributions

Three related distributions built on the gamma function: the gamma
distribution itself, chi-squared (a special case of gamma), and
Student's t.

## Gamma distribution

Parameterized by `shape` (k) and `scale` (theta), SciPy's convention: the
mean is `shape * scale`. Both must be positive and finite. Validate computed parameters before
calling these functions. A nonpositive shape can produce a misleading result
from `gamma_pdf`; the CDF and inverse CDF return NaN for the cases below.

| Call | Result |
|---|---|
| `gamma_pdf(1, 0, 1)` or `gamma_pdf(1, -1, 1)` | `0.0` |
| `gamma_cdf(1, 0, 1)` or `gamma_cdf(1, -1, 1)` | NaN |
| `gamma_pdf(1, 2, 0)` or `gamma_pdf(1, 2, -1)` | NaN |
| `gamma_cdf(1, 2, 0)` or `gamma_cdf(1, 2, -1)` | NaN |
| `gamma_inv_cdf(0.5, 0, 1)` or `gamma_inv_cdf(0.5, -1, 1)` | NaN |
| `gamma_inv_cdf(0.5, 2, 0)` or `gamma_inv_cdf(0.5, 2, -1)` | NaN |

**`gamma_pdf(x: f32, shape: f32, scale: f32) -> f32`**

Computes the PDF via log-space: exp((k-1)*ln(x) - x/scale - k*ln(scale) - lgamma(k)).
That expression is evaluated in f64 and returned as f32, because `(k-1)*ln(x)`
and `lgamma(k)` are each about `k*ln(k)` and nearly cancel. Returns 0 for x < 0;
at x = 0 returns 0 when shape > 1, 1/scale when shape = 1, and +inf when
shape < 1.

**`gamma_cdf(x: f32, shape: f32, scale: f32) -> f32`**

Uses the regularized lower incomplete gamma function (series expansion for
x/scale < shape+1, continued-fraction complement otherwise), evaluated in f64
and returned as f32. Returns 0 for x <= 0 and NaN for a non-positive `shape` or
`scale`.

The standardised argument `x / scale` is formed and tested in f64, so a far
lower tail survives a quotient f32 cannot hold: `gamma_cdf(1e-30, 0.5, 1e20)`
is `1.1283791e-25` against a true `1.128379158e-25`, where the f32 quotient is
exactly zero. That needs a shape
below 1, where `P(a, x)` is much larger than `x`. At shape 1 and above the
answer is at most the quotient itself, which is in turn at most half f32's
smallest subnormal there, so f32 can carry none of it and the return is 0.0. A
finite `x` whose f32 quotient overflows still answers as `x = +inf` does,
because `1e38 / 1e-10` is a finite 1e48 in f64 and the continued fraction
returns 1.0 there.

**`gamma_sf(x: f32, shape: f32, scale: f32) -> f32`**

The survival function `1 - gamma_cdf(x, shape, scale)`, calculated without
that subtraction, in f64 and returned as f32. It uses the same two branches as
`gamma_cdf` and takes the one that computes its own answer directly: the series
complement for x/scale < shape+1, and the continued fraction itself otherwise.
That second branch is the reason this function exists, because `gamma_cdf`
reaches its upper branch as a complement, so a caller who subtracts the CDF
from `1.0` loses the tail to `0.5 * ulp(1.0)`.

That loss is about 6e-8, for any accuracy of the incomplete gamma. Use
`gamma_sf` for an upper tail. Do not use
`sub(cast(1.0, f32), gamma_cdf(..))`.

`gamma_sf` reads the same f64 standardised argument, and that matters at a
small shape. `P` grows as `x^shape`, and once `P` passes `2^-25` (about
3.0e-8, half the 6e-8 just mentioned, because `1 - P` rounds to
nearest), the upper tail is resolvable too:
`gamma_sf(1e-30, 0.01, 1e20)` is `0.6819677`, not `1.0`. There is no shape
threshold to quote, because the boundary moves with the quotient. At
`x / scale` of 1e-50 the result differs from 1.0 up to shape 0.15 and is
exactly 1.0 from 0.16, and at 1.4e-65 it differs only up to 0.11.

**`gamma_inv_cdf(q: f32, shape: f32, scale: f32) -> f32`**

Solves `P(shape, y) = q` on the unit-scale distribution and multiplies by
`scale` once at the end, in f64. `scale` is a pure dilation of this family, so
dividing it out is exact and nothing inside the solve has a magnitude a scale
can move. The variable is `u = ln y`, because a quantile ranges over decades;
`dP/du` is then the front factor `exp(shape*ln y - y - lgamma(shape))` this page
already describes.

The start is Wilson-Hilferty where its cube is positive and the small-`q`
asymptotic `y ~ (q*Gamma(shape+1))^(1/shape)` where it is not, using the leading
term of the same series, so it is accurate exactly where the closed form
degenerates. From there it is Newton on `ln P`, safeguarded by a straddling
bracket: a candidate that leaves the bracket is replaced by a bisection, so the
iteration cannot leave the root's basin, and the loop exits on convergence, on
a bracket narrower than its 1e-10 tolerance, or on the 80-step budget. On
every exit the value returned lies inside a bracket containing the root.

The iteration count depends on the distance between the clamped start and
the root. A sampled maximum does not bound the cost for every argument.

Returns 0 at q=0, +inf at q=1, and NaN for a `q` outside [0,1], a NaN `q`, or a
`shape` or `scale` that is NaN, not positive, or infinite. An infinite shape is
positive and is not NaN, so finiteness requires a separate check. It inherits the
large-shape limit below.

**`gamma_sample[n](k: key, template: tensor[n, f32], shape: f32, scale: f32) -> tensor[n, f32]`**

For finite shape >= 1 and positive finite scale, the sampler gives each
element a separate key and selects its first accepted Marsaglia-Tsang
candidate. It tries at most 64 candidates for each element. It returns NaN
at an element if all 64 candidates reject.
See [Sampling limits](sampling.md#sampling-limits).
Below shape 1 the method does not apply; `gamma_sample` still returns
finite numbers there, but they are not Gamma draws.

### Large shapes

Every export that reaches the incomplete gamma shares a front factor,
`exp(shape*ln(x) - x - lgamma(shape))`. Near `x = shape*scale`, its exponent
subtracts large terms to leave a small result. The front factor, series, and
continued fraction run in f64 and return f32, but rounding in `lgamma(shape)`
still limits accuracy at very large shapes. The series and continued fraction
each have a 65,536-step limit. `chi_squared_cdf` and `chi_squared_sf` reach
this computation at `df/2`; `poisson_cdf` reaches it at `k+1`.

For the measured PDF/CDF cases through shape `5e7` and quantile cases through
shape `1e7`, relative error is below 2e-6. These are sampled ranges, not a
bound on every argument between their points. [The precision appendix](../appendix/precision.md)
gives the sampled axes and known limits. Calibrate other shapes and tails
against a reference.

```chelis
module Nautilus.BookGammaFamily
import Nautilus.Distributions (gamma_pdf, gamma_cdf, gamma_inv_cdf, chi_squared_cdf)
export (pdf_at_2, cdf_at_2, median_shape_2, chi2_critical)
def pdf_at_2() -> f32 = gamma_pdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))
def cdf_at_2() -> f32 = gamma_cdf(cast(2.0, f32), cast(1.0, f32), cast(3.0, f32))
def median_shape_2() -> f32 = gamma_inv_cdf(cast(0.5, f32), cast(2.0, f32), cast(1.0, f32))
def chi2_critical() -> f32 = chi_squared_cdf(cast(3.84, f32), cast(1.0, f32))
```

Evaluated, the four functions return `pdf_at_2 = 0.27067056`,
`cdf_at_2 = 0.48658288` (shape 1, scale 3, so 1 - e^(-2/3)),
`median_shape_2 = 1.678347`, and `chi2_critical = 0.9499565`: 3.84 is the
95% critical value of a chi-squared with one degree of freedom.

## Chi-squared distribution

All five functions delegate to the gamma distribution with
shape = df/2 and scale = 2, so `df` must be positive and the gamma
parameter rules above apply at shape df/2.

**`chi_squared_pdf(x: f32, df: f32) -> f32`**: via `gamma_pdf(x, df/2, 2)`

**`chi_squared_cdf(x: f32, df: f32) -> f32`**: via `gamma_cdf(x, df/2, 2)`

**`chi_squared_sf(x: f32, df: f32) -> f32`**: via `gamma_sf(x, df/2, 2)`.
This function is the upper tail, which a goodness-of-fit test needs.
`chi_squared_sf(40, 3)` is `1.07e-8`, but `1 - chi_squared_cdf(40, 3)` is
exactly `0.0`. `Nautilus.Testing.chi_squared_p_value` is this function.

**`chi_squared_inv_cdf(q: f32, df: f32) -> f32`**: via `gamma_inv_cdf(q, df/2, 2)`

**`chi_squared_sample[n](k: key, template: tensor[n, f32], df: f32) -> tensor[n, f32]`**

`chi2_critical` in the module above shows `chi_squared_cdf` in use.
The sampler uses `gamma_sample` with shape df/2 and scale 2, so it needs
`df >= 2`. It uses separate keyed gamma trials for each element.

## Student's t distribution

Parameterized by the degrees of freedom `df`, which must be positive.
Non-integer `df` is accepted.

**`student_t_pdf(x: f32, df: f32) -> f32`**

Computed in log-space using `log_gamma` for the normalizing constant. Returns
NaN for df <= 0.

**`student_t_cdf(t: f32, df: f32) -> f32`**

Two forms, by `df`. Returns NaN if df <= 0 in either.

For `df` below 1e7 it uses the regularized incomplete beta function (`betai`)
with a = df/2, b = 0.5, x = df/(df + t^2). Both `x` and its complement
`t^2/(df + t^2)` are formed in f64 and passed to `betai`, so the complement keeps
its digits for large `df` instead of being recovered as `1 - x`, where it would
round to zero.

From `df` of 1e7 upward it uses the t distribution's own large-`df` expansion,
`Phi(t) - phi(t) * (t^3 + t) / (4 df)`, where `Phi` and `phi` are the standard
normal CDF and density. Both terms are computed in f64 and the result returned as
f32. An infinite `df` is the normal distribution exactly, and the correction term
vanishes there.

`betai`'s normalizing factor is a difference of log-gammas in `df`, so its error
grows without bound and no working precision removes it; the expansion has no
such term. At the measured `t` and `df` cases through `df = 1e20`, relative
error stays below 2e-6. An infinite `df` uses the normal distribution exactly.
`student_t_cdf(0, df)` is exactly 0.5 for valid `df`, which is the correct
value. The [precision guide](../appendix/precision.md) states the
sampled axes for both forms and the beta family they share.

**`student_t_sample[n](k: key, template: tensor[n, f32], df: f32) -> tensor[n, f32]`**

The sampler divides each normal draw by the square root of its related
chi-squared draw divided by `df`. It needs `df >= 2`. It returns NaN at an
element if its chi-squared sampler uses all 64 gamma trials without an
accepted candidate.

```chelis-fragment
import Nautilus.Distributions (student_t_pdf, student_t_cdf)

t_peak = student_t_pdf(0.0f32, 5.0f32)
t_cdf = student_t_cdf(2.0f32, 10.0f32)
```

```text
t_peak = 0.37960654
t_cdf = 0.963306
```

## Edge cases

| Condition | Result |
|---|---|
| `gamma_pdf(x, shape, scale)` with x < 0 | 0.0 |
| `gamma_inv_cdf(q, ...)` with q outside [0,1] | NaN |
| `chi_squared_cdf(x, df)` with x <= 0 | 0.0 |
| `gamma_sf(x, ...)` or `chi_squared_sf(x, df)` with x <= 0 | 1.0 |
| `chi_squared_sf(x, df)` with a true tail below about 7.0e-46 | 0.0, the f32 floor |
| `student_t_cdf(t, df)` with df <= 0 | NaN |
| Any `_pdf` at x = 0 with shape < 1 | +inf |
