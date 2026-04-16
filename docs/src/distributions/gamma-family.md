# Gamma Family Distributions

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

**`gamma_inv_cdf(q: f32, shape: f32, scale: f32) -> f32`**

Wilson-Hilferty initial guess refined by up to 80 Newton iterations.
Returns 0 at q=0, +inf at q=1, NaN outside [0,1].

**`gamma_sample[n](template: tensor[n, f32], shape: f32, scale: f32) -> tensor[n, f32] ! { Random }`**

Marsaglia-Tsang method for shape >= 1. Carries the `Random` effect.

```chelis-fragment
import Nautilus.Distributions (gamma_pdf, gamma_cdf, gamma_inv_cdf)

pdf = gamma_pdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))  -- approximately 0.2707
cdf = gamma_cdf(cast(2.0, f32), cast(1.0, f32), cast(3.0, f32))  -- approximately 0.4866
x = gamma_inv_cdf(cast(0.5, f32), cast(2.0, f32), cast(1.0, f32))
```

## Chi-squared distribution

All three functions delegate to the gamma distribution with
shape = df/2 and scale = 2.

**`chi_squared_pdf(x: f32, df: f32) -> f32`** -- via `gamma_pdf(x, df/2, 2)`

**`chi_squared_cdf(x: f32, df: f32) -> f32`** -- via `gamma_cdf(x, df/2, 2)`

**`chi_squared_inv_cdf(q: f32, df: f32) -> f32`** -- via `gamma_inv_cdf(q, df/2, 2)`

**`chi_squared_sample[n](template: tensor[n, f32], df: f32) -> tensor[n, f32] ! { Random }`**

```chelis-fragment
import Nautilus.Distributions (chi_squared_cdf)

p = chi_squared_cdf(cast(3.84, f32), cast(1.0, f32))  -- approximately 0.95
```

## Student's t distribution

**`student_t_pdf(x: f32, df: f32) -> f32`**

Computed in log-space using `log_gamma` for the normalizing constant.

**`student_t_cdf(t: f32, df: f32) -> f32`**

Uses the regularized incomplete beta function (`betai`) with
a = df/2, b = 0.5, x = df/(df + t^2). Returns NaN if df <= 0.

**`student_t_sample[n](template: tensor[n, f32], df: f32) -> tensor[n, f32] ! { Random }`**

Generates Normal(0,1) / sqrt(ChiSq(df)/df).

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
| `student_t_cdf(t, df)` with df <= 0 | NaN |
| Any `_pdf` at x = 0 with shape < 1 | +inf |
