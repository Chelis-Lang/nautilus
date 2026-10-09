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

The stack overflows came from the incomplete-gamma helpers, which recursed
once per series or continued-fraction term. They now spend their budget through
four levels of chunked recursion, so a long run costs about 64 stack frames
rather than one per term, and a non-finite standardized argument is answered by
a guard instead of running the budget out: neither a convergence test on a term
nor one on a continued-fraction ratio can be satisfied by a NaN. Validate
computed parameters before the call anyway.

The measured results in the table above predate the degenerate-argument work
and several of them are no longer what these calls return. They are tracked
separately and are not corrected here, because nothing in this page's accuracy
work changes them.

**`gamma_pdf(x: f32, shape: f32, scale: f32) -> f32`**

Computes the PDF via log-space: exp((k-1)*ln(x) - x/scale - k*ln(scale) - lgamma(k)).
That expression is evaluated in f64 and returned as f32, because `(k-1)*ln(x)`
and `lgamma(k)` are each about `k*ln(k)` and nearly cancel. Returns 0 for x < 0;
at x = 0 returns 0 when shape > 1, 1/scale when shape = 1, and +inf when
shape < 1.

**`gamma_cdf(x: f32, shape: f32, scale: f32) -> f32`**

Uses the regularized lower incomplete gamma function (series expansion for
x/scale < shape+1, continued-fraction complement otherwise), evaluated in f64
and returned as f32. Returns 0 for x <= 0. The parameter guards read the f32
`x / scale`, so a finite `x` whose f32 quotient overflows still answers as
`x = +inf` does.

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

Wilson-Hilferty initial guess refined by Newton's method on the f64 CDF and
density, at most 80 iterations and stopping once a step moves the estimate by
less than 1e-10 of itself. Returns 0 at q=0, +inf at q=1, NaN outside [0,1]. It
inherits the large-shape limit below.

The refinement is not optional at a small shape and is not harmful at a large
one. Against the exact inverse it is worth a factor of 754536 at
`gamma_inv_cdf(0.05, 1, 1)`, where the closed form alone is 23% out. While the
CDF underneath it was computed in f32 it was also worth a factor of 1001
*against* you at shape 1000, because Newton converges on the root of the
function it is handed and a biased CDF moves that root. The CDF is the fix;
the loop stays.

**`gamma_sample[n](k: key, template: tensor[n, f32], shape: f32, scale: f32) -> tensor[n, f32]`**

For finite shape >= 1 and positive finite scale, the sampler gives each
element a separate key and selects its first accepted Marsaglia-Tsang
candidate. It tries at most 64 candidates for each element. It returns NaN
at an element if all 64 candidates reject.
See [Sampling limits](sampling.md#sampling-limits).
Below shape 1 the method does not apply; `gamma_sample` still returns
finite numbers there, but they are not Gamma draws.

### Large shapes

Every export that reaches the incomplete gamma shares one front factor,
`exp(shape*ln(x) - x - lgamma(shape))`. Its exponent is a difference of three
quantities each about `shape*ln(shape)`, and at `x = shape` what they leave is
about `0.5*ln(shape/(2*pi))`: at shape 1e5 three terms of 1.1e6 collapse to
4.84. An absolute error in an exponent is a multiplicative error in the result,
so the accuracy of this whole family is set by one rounding of the largest term.
In f32 that rounding is 0.125 at shape 1e5 and 1.0 at shape 1e6.

The front factor, the series and the continued fraction are now computed in
f64 and returned as f32. At `x = shape`, scale 1, against the exact regularized
incomplete gamma:

| shape | `gamma_cdf` in f32 | relative error | `gamma_cdf` now | exact |
|---|---|---|---|---|
| 100 | 0.5132978 | 1.9e-6 | 0.5132988 | 0.513298798 |
| 1000 | 0.5043488 | 2.8e-4 | 0.5042052 | 0.504205244 |
| 10000 | 0.47919172 | 4.4% | 0.5013298 | 0.501329808 |
| 100000 | 0.24656442 | 51% | 0.5004205 | 0.500420522 |
| 1000000 | 0.029631412 | 94% | 0.500133 | 0.500132981 |
| 10000000 | 1.9999999e-7 | 100% | 0.5000421 | 0.500042052 |
| 50000000 | 0.9993269 | 100% | 0.5000188 | 0.500018806 |

Every value in the fourth column is within two f32 ulps of the fifth, so what
remains is the rounding of the return type rather than of the computation.

The second column stays inside [0, 1] at every one of those shapes, which made
the error hard to notice, but that was a property of `x = shape` and not of the
f32 lane. A little above the branch point at a large shape the continued
fraction diverged outright: `gamma_cdf(50007070, 50000000, 1)` returned
**-5.7809985e23** against a true 0.8413766, and `gamma_pdf(50035356, 50000000,
1)` returned 6.235149e27 against a true 2.1e-10. A negative probability of that
magnitude is not a value a caller can mistake for an answer.

Away from the branch point in the other direction the f32 lane was accurate,
which is the rest of why this was easy to miss: `gamma_cdf(10500, 10000, 1)`
was 2.8e-8 relative while the same shape at `x = shape` was 4.4e-2. The failure is specifically at `x` near
`shape*scale`, which is where `poisson_cdf(k, k)` and a chi-squared statistic at
its own expectation both land.

`chi_squared_cdf` and `chi_squared_sf` reach this at `df / 2`, `poisson_cdf` at
`k + 1`, and both quantiles through the CDF and density inside their Newton
step. `gamma_pdf` has the same cancellation in its own log-space body:
`gamma_pdf(50000000, 50000000, 1)` returned exactly 1.0 in f32, against a true
5.6418958e-5 -- a density above every value a Gamma(5e7, 1) density takes,
since that point is its maximum.

f64 moves this limit rather than removing it. The floor is one f64 ulp of
`lgamma(shape)`, which crosses f32's own resolution at around shape 3.3e7 and
reaches about 4.8e-7 by shape 2e8. The iteration budget is the other limit, and
it is now 65536 rather than 200: the series needs about `6.8*sqrt(shape)` terms
at the branch point, measured at 48119 for shape 5e7, so the budget carries it
to about shape 9e7.
[The precision appendix](../appendix/precision.md) states the range both limits
leave and names the gate that measures it.

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
95% critical value of a chi-squared with one degree of freedom. All four are
the correctly rounded f32 of their exact values; all four moved by one to two
f32 ulps when the family's internals went to f64.

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
1.7e-6 at `df = 1e9`, 4e-4 at 1e12 and 51% at 1e14, and from `df = 1e16` the
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
