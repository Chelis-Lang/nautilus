# Gamma family distributions

Three related distributions built on the gamma function: the gamma
distribution itself, chi-squared (a special case of gamma), and
Student's t (which uses the regularized incomplete beta function
internally).

## Gamma distribution

**`gamma_pdf(x: f32, shape: f32, scale: f32) -> f32`**

Computes the PDF via log-space: exp((k-1)*ln(x) - x/scale - k*ln(scale) - lgamma(k)).
Returns 0 for x < 0; at x = 0 returns 1/scale when shape = 1, +inf when shape < 1.

**`gamma_cdf(x: f32, shape: f32, scale: f32) -> f32`**

Uses the regularized lower incomplete gamma function (series expansion
`gammap` for x < shape+1, continued-fraction `gammaq` complement
otherwise).

**`gamma_sf(x: f32, shape: f32, scale: f32) -> f32`**

The survival function `1 - gamma_cdf(x, shape, scale)`, calculated without
that subtraction. It uses the same branches as `gamma_cdf`: the series
`1 - gammap` for x/scale < shape+1, and the continued fraction `gammaq`
directly otherwise. The second branch is the reason for this function.
`gamma_cdf` calculates its upper branch as `1 - gammaq(..)`. Thus a caller
that subtracts the CDF from `1.0` loses the tail to `0.5 * ulp(1.0)`.

That loss is about 6e-8, for any accuracy of the incomplete gamma. Use
`gamma_sf` for an upper tail. Do not use
`sub(cast(1.0, f32), gamma_cdf(..))`.

**`gamma_inv_cdf(q: f32, shape: f32, scale: f32) -> f32`**

Wilson-Hilferty initial guess refined by up to 80 Newton iterations.
Returns 0 at q=0, +inf at q=1, NaN outside [0,1].

**`gamma_sample[n](k: key, template: tensor[n, f32], shape: f32, scale: f32) -> tensor[n, f32]`**

For finite shape >= 1 and positive finite scale, the sampler gives each
element a separate key and selects its first accepted Marsaglia-Tsang
candidate. It tries at most 64 candidates for each element. It returns NaN
at an element if all 64 candidates reject.
See [Sampling limits](sampling.md#sampling-limits).

```chelis
module Nautilus.BookGammaFamily
import Nautilus.Distributions (gamma_pdf, gamma_cdf, gamma_inv_cdf, chi_squared_cdf)
export (pdf_at_2, cdf_at_2, median_shape_2, chi2_critical)
def pdf_at_2() -> f32 = gamma_pdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))
def cdf_at_2() -> f32 = gamma_cdf(cast(2.0, f32), cast(1.0, f32), cast(3.0, f32))
def median_shape_2() -> f32 = gamma_inv_cdf(cast(0.5, f32), cast(2.0, f32), cast(1.0, f32))
def chi2_critical() -> f32 = chi_squared_cdf(cast(3.84, f32), cast(1.0, f32))
```

`pdf_at_2` is approximately 0.2707, `cdf_at_2` (shape 1, scale 3, so
1 - e^(-2/3)) approximately 0.4866, `median_shape_2` approximately 1.678, and
`chi2_critical` approximately 0.950: 3.84 is the 95% critical value of a
chi-squared with one degree of freedom.

## Chi-squared distribution

All four functions delegate to the gamma distribution with
shape = df/2 and scale = 2.

**`chi_squared_pdf(x: f32, df: f32) -> f32`** -- via `gamma_pdf(x, df/2, 2)`

**`chi_squared_cdf(x: f32, df: f32) -> f32`** -- via `gamma_cdf(x, df/2, 2)`

**`chi_squared_sf(x: f32, df: f32) -> f32`** -- via `gamma_sf(x, df/2, 2)`.
This function is the upper tail, which a goodness-of-fit test needs.
`chi_squared_sf(40, 3)` is `1.07e-8`, but `1 - chi_squared_cdf(40, 3)` is
exactly `0.0`. `Nautilus.Testing.chi_squared_p_value` is this function.

**`chi_squared_inv_cdf(q: f32, df: f32) -> f32`** -- via `gamma_inv_cdf(q, df/2, 2)`

**`chi_squared_sample[n](k: key, template: tensor[n, f32], df: f32) -> tensor[n, f32]`**

`chi2_critical` in the module above shows `chi_squared_cdf` in use.
The sampler uses `gamma_sample` with shape df/2 and scale 2, so it needs
`df >= 2`. It uses separate keyed gamma trials for each element.

## Student's t distribution

**`student_t_pdf(x: f32, df: f32) -> f32`**

Computed in log-space using `log_gamma` for the normalizing constant.

**`student_t_cdf(t: f32, df: f32) -> f32`**

Uses the regularized incomplete beta function (`betai`) with
a = df/2, b = 0.5, x = df/(df + t^2). Returns NaN if df <= 0.

**`student_t_sample[n](k: key, template: tensor[n, f32], df: f32) -> tensor[n, f32]`**

The sampler divides each normal draw by the square root of its related
chi-squared draw divided by `df`. It needs `df >= 2`. It returns NaN at an
element if its chi-squared sampler uses all 64 gamma trials without an
accepted candidate.

```chelis-fragment
import Nautilus.Distributions (student_t_pdf, student_t_cdf)

pdf = student_t_pdf(cast(0.0, f32), cast(5.0, f32))  -- peak of t(5)
cdf = student_t_cdf(cast(2.0, f32), cast(10.0, f32)) -- approximately 0.963
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
