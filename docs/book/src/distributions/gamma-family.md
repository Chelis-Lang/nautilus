# Gamma family distributions

Three related distributions built on the gamma function: the gamma
distribution itself, chi-squared (a special case of gamma), and
Student's t (which uses the regularized incomplete beta function
internally).

## Gamma distribution

Parameterized by `shape` (k) and `scale` (theta), SciPy's convention: the
mean is `shape * scale`. Both must be positive and finite. No gamma function
checks them. An invalid value returns a misleading number, NaN, or, under
`chelis eval` at the default 8 MB stack, stops evaluation with
`fatal runtime error: stack overflow, aborting`:

| Call | Result |
|---|---|
| `gamma_pdf(1, 0, 1)` or `gamma_pdf(1, -1, 1)` | `0.0` |
| `gamma_cdf(1, 0, 1)` or `gamma_cdf(1, -1, 1)` | `1.0` |
| `gamma_pdf(1, 2, 0)` or `gamma_pdf(1, 2, -1)` | NaN |
| `gamma_cdf(1, 2, -1)` | `0.0` |
| `gamma_cdf(1, 2, 0)` | stack overflow |
| `gamma_inv_cdf(0.5, 0, 1)` | `0.0` |
| `gamma_inv_cdf(0.5, -1, 1)` | `827180.6` |
| `gamma_inv_cdf(0.5, 2, 0)` or `gamma_inv_cdf(0.5, 2, -1)` | stack overflow |

The stack overflows come from the incomplete-gamma helpers, which recurse
once per series or continued-fraction term and run all 200 terms when the
input is not finite. Each stack-overflow call in this table returns NaN when the
stack limit is raised first with `ulimit -s 65520`. Validate computed
parameters before the call.

**`gamma_pdf(x: f32, shape: f32, scale: f32) -> f32`**

Computes the PDF via log-space: exp((k-1)*ln(x) - x/scale - k*ln(scale) - lgamma(k)).
Returns 0 for x < 0; at x = 0 returns 0 when shape > 1, 1/scale when shape = 1,
and +inf when shape < 1.

**`gamma_cdf(x: f32, shape: f32, scale: f32) -> f32`**

Uses the regularized lower incomplete gamma function (series expansion
`gammap` for x/scale < shape+1, continued-fraction `gammaq` complement
otherwise). Returns 0 for x <= 0.

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

Wilson-Hilferty initial guess refined by 80 Newton iterations on
`gamma_cdf`. Returns 0 at q=0, +inf at q=1, NaN outside [0,1]. It inherits
the large-shape limit below.

**`gamma_sample[n](k: key, template: tensor[n, f32], shape: f32, scale: f32) -> tensor[n, f32]`**

For finite shape >= 1 and positive finite scale, the sampler gives each
element a separate key and selects its first accepted Marsaglia-Tsang
candidate. It tries at most 64 candidates for each element. It returns NaN
at an element if all 64 candidates reject.
See [Sampling limits](sampling.md#sampling-limits).
Below shape 1 the method does not apply; `gamma_sample` still returns
finite numbers there, but they are not Gamma draws.

### Large shapes

Both incomplete-gamma branches stop after 200 terms. That is enough for
moderate shapes and too few for large ones, and the CDF then drifts with no
signal. At `x = shape`, scale 1, against the exact regularized incomplete
gamma, each call evaluated alone:

| shape | `gamma_cdf`, default stack | with `ulimit -s 65520` | exact | relative error |
|---|---|---|---|---|
| 100 | 0.5132978 | 0.5132978 | 0.5132988 | 1.9e-6 |
| 1000 | 0.5043488 | 0.5043488 | 0.5042052 | 2.8e-4 |
| 2000 | stack overflow | 0.50264823 | 0.50297355 | 6.5e-4 |
| 20000 | stack overflow | 0.4219802 | 0.50094032 | 16% |
| 30000 | stack overflow | 0.37090707 | 0.50076776 | 26% |

`chi_squared_cdf` and `chi_squared_sf` reach this at `df / 2`, and
`poisson_cdf` at `k + 1`. For a chi-squared statistic with thousands of
degrees of freedom, compare the table's error with your significance level
before trusting the p-value.

From shape 2000 up, a single `gamma_cdf` call at `x = shape` exhausts the
default 8 MB stack under `chelis eval` and stops with a stack overflow.
Raising the limit with `ulimit -s 65520` lets it finish, with the drifted
values in the third column.

```chelis
module Nautilus.BookGammaFamily
import Nautilus.Distributions (gamma_pdf, gamma_cdf, gamma_inv_cdf, chi_squared_cdf)
export (pdf_at_2, cdf_at_2, median_shape_2, chi2_critical)
def pdf_at_2() -> f32 = gamma_pdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))
def cdf_at_2() -> f32 = gamma_cdf(cast(2.0, f32), cast(1.0, f32), cast(3.0, f32))
def median_shape_2() -> f32 = gamma_inv_cdf(cast(0.5, f32), cast(2.0, f32), cast(1.0, f32))
def chi2_critical() -> f32 = chi_squared_cdf(cast(3.84, f32), cast(1.0, f32))
```

Evaluated, the four functions return `pdf_at_2 = 0.27067044`,
`cdf_at_2 = 0.4865827` (shape 1, scale 3, so 1 - e^(-2/3)),
`median_shape_2 = 1.678348`, and `chi2_critical = 0.94995654`: 3.84 is the
95% critical value of a chi-squared with one degree of freedom.

## Chi-squared distribution

All five functions delegate to the gamma distribution with
shape = df/2 and scale = 2, so `df` must be positive and the gamma
parameter rules above apply at shape df/2.

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

Parameterized by the degrees of freedom `df`, which must be positive.
Non-integer `df` is accepted.

**`student_t_pdf(x: f32, df: f32) -> f32`**

Computed in log-space using `log_gamma` for the normalizing constant. Returns
NaN for df <= 0.

**`student_t_cdf(t: f32, df: f32) -> f32`**

Uses the regularized incomplete beta function (`betai`) with
a = df/2, b = 0.5, x = df/(df + t^2). Returns NaN if df <= 0.

Both `x` and its complement `t^2/(df + t^2)` are formed in f64 and passed to
`betai`, so the complement keeps its digits for large `df` instead of being
recovered as `1 - x`, where it would round to zero.

Relative error stays below 2e-6 for `df` in [1, 1e8]. Past that it grows: about
2e-6 at `df = 1e9`, 4e-4 at 1e12 and 51% at 1e14, and from `df = 1e16` the
function returns exactly 0.5, which is also its value at `t = 0`. **Above `df` of
about 1e9, use `normal_cdf`.** The t distribution is within 1e-9 of the standard
normal there, so the substitution costs nothing f32 can measure. The precision
guide covers the whole beta family.

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
