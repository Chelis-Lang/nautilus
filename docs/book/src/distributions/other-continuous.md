# Other continuous distributions

Six more continuous families. Each has a PDF and CDF; Exponential, LogNormal,
Uniform, and Weibull also have an inverse CDF, and the first three have a
sampler. Every function is f32.

```chelis-fragment
import Nautilus.Distributions (exponential_cdf, exponential_inv_cdf, lognormal_cdf, uniform_cdf, weibull_cdf, weibull_inv_cdf, beta_cdf, f_cdf, f_pdf)

exp_cdf = exponential_cdf(1.0f32, 2.0f32)
exp_median = exponential_inv_cdf(0.5f32, 2.0f32)
logn_cdf = lognormal_cdf(1.0f32, 0.0f32, 1.0f32)
unif_cdf = uniform_cdf(0.25f32, 0.0f32, 1.0f32)
weib_cdf = weibull_cdf(1.0f32, 2.0f32, 1.0f32)
weib_median = weibull_inv_cdf(0.5f32, 2.0f32, 1.0f32)
beta = beta_cdf(0.3f32, 2.0f32, 5.0f32)
f_c = f_cdf(3.0f32, 5.0f32, 10.0f32)
f_p = f_pdf(1.0f32, 5.0f32, 10.0f32)
```

```text
exp_cdf = 0.86466473
exp_median = 0.3465736
logn_cdf = 0.5
unif_cdf = 0.25
weib_cdf = 0.63212055
weib_median = 0.83255464
beta = 0.57982504
f_c = 0.93444246
f_p = 0.49547988
```

Beta and F reject non-positive parameters with NaN. The other four families
do not check their parameters; each section says what an invalid value
returns, so validate computed parameters before the call.

## Exponential

Parameterized by `rate` (lambda), not scale: the mean is `1 / rate`.
`rate` must be positive and finite.

| Function | Signature | Returns |
|---|---|---|
| `exponential_pdf` | `(x: f32, rate: f32) -> f32` | rate * exp(-rate * x) for x >= 0, else 0 |
| `exponential_cdf` | `(x: f32, rate: f32) -> f32` | 1 - exp(-rate * x) for x >= 0, else 0 |
| `exponential_inv_cdf` | `(q: f32, rate: f32) -> f32` | -ln(1 - q) / rate; 0 at q = 0, +inf at q = 1, NaN outside [0, 1] |
| `exponential_sample` | `[n](k: key, template: tensor[n, f32], rate: f32) -> tensor[n, f32]` | n draws of -ln(u) / rate |

With `rate = 0` the PDF and CDF are 0 everywhere and `exponential_inv_cdf`
returns +inf. A negative rate gives negative values:
`exponential_pdf(1, -1)` is `-2.7182817` and `exponential_cdf(1, -1)` is
`-1.7182819`.

The CDF complements in f64, and for a `rate * x` in the half-open interval
from 0 up to 1/16 it sums a Maclaurin series for `1 - exp(-rate * x)` rather
than subtracting. A negative `rate * x` stays on the subtraction, where the
series would diverge. A small `x` therefore
keeps its digits: `exponential_cdf(1e-8, 1.0)` is 1e-8 and
`exponential_cdf(1e-20, 1.0)` is 1e-20, where the subtraction returned 0. The
[precision guide](../appendix/precision.md) states the error over the range.

## LogNormal

Parameterized by `mu` and `sigma`, the mean and standard deviation of
`ln(X)`, not of X. `sigma` must be positive and finite.

| Function | Signature | Returns |
|---|---|---|
| `lognormal_pdf` | `(x: f32, mu: f32, sigma: f32) -> f32` | density of X; 0 for x <= 0 |
| `lognormal_cdf` | `(x: f32, mu: f32, sigma: f32) -> f32` | `normal_cdf(ln(x), mu, sigma)`; 0 for x <= 0 |
| `lognormal_inv_cdf` | `(q: f32, mu: f32, sigma: f32) -> f32` | `exp(normal_inv_cdf(q, mu, sigma))` |
| `lognormal_sample` | `[n](k: key, template: tensor[n, f32], mu: f32, sigma: f32) -> tensor[n, f32]` | `exp` of `normal_sample` draws |

`sigma` behaves as `std` does in the [normal distribution](normal.md):
at 0 the PDF is NaN and the CDF is a step at `exp(mu)`; a negative `sigma`
gives a negative PDF and the upper tail from the CDF.

## Uniform

Parameterized by the endpoints `lo` and `hi`, which must satisfy `lo < hi`.

| Function | Signature | Returns |
|---|---|---|
| `uniform_pdf` | `(x: f32, lo: f32, hi: f32) -> f32` | 1 / (hi - lo) on [lo, hi], else 0 |
| `uniform_cdf` | `(x: f32, lo: f32, hi: f32) -> f32` | 0 at or below `lo`, 1 at or above `hi`, (x - lo) / (hi - lo) between |
| `uniform_inv_cdf` | `(q: f32, lo: f32, hi: f32) -> f32` | lo + q * (hi - lo) |
| `uniform_sample` | `[n](k: key, template: tensor[n, f32], lo: f32, hi: f32) -> tensor[n, f32]` | n draws, each lo + (hi - lo) * u for a uniform u in [0, 1] |

The endpoints are not checked:

- `lo = hi`: `uniform_pdf(lo, lo, lo)` is `inf` and `uniform_cdf(lo, lo, lo)` is 0.
- `lo > hi`: the PDF and CDF are 0 between the endpoints, and
  `uniform_inv_cdf(0.25, 1, 0)` is `0.75`, counting down from `lo`.
- `uniform_inv_cdf` does not reject q outside [0, 1]; it extrapolates, so
  `uniform_inv_cdf(1.5, 0, 1)` is `1.5`.

## Weibull

Parameterized by `shape` (k) and `scale` (lambda), both positive. The CDF is
the closed form 1 - exp(-(x/scale)^shape).

| Function | Signature | Returns |
|---|---|---|
| `weibull_pdf` | `(x: f32, shape: f32, scale: f32) -> f32` | density; 0 for x < 0 |
| `weibull_cdf` | `(x: f32, shape: f32, scale: f32) -> f32` | P(X <= x); 0 for x < 0 |
| `weibull_inv_cdf` | `(q: f32, shape: f32, scale: f32) -> f32` | scale * (-ln(1 - q))^(1/shape); 0 at q = 0, +inf at q = 1, NaN outside [0, 1] |

`shape <= 0` or `scale <= 0` returns NaN, except where the result is fixed
before the parameters are read: x < 0 gives 0, and q = 0 or q = 1 gives 0 or
+inf. At x = 0 the PDF is 0 for shape > 1, `1/scale` for shape = 1, and +inf
for shape < 1.

`weibull_cdf` forms both `(x/scale)^shape` and its complement in f64, and
below a `(x/scale)^shape` of 1/16 it sums a Maclaurin series for `1 - exp(-t)`
rather than subtracting; `shape` and `scale` are positive here, so the
argument is never negative. `weibull_cdf(1e-8, 2.0, 1.0)` is therefore 1e-16
rather than 0. The [precision guide](../appendix/precision.md) states the
error over the range.

## Beta

Parameterized by shape parameters `a` and `b`, both positive.

| Function | Signature | Returns |
|---|---|---|
| `beta_pdf` | `(x: f32, a: f32, b: f32) -> f32` | density, computed in log space with `log_gamma`; 0 outside [0, 1] |
| `beta_cdf` | `(x: f32, a: f32, b: f32) -> f32` | regularized incomplete beta I_x(a, b); 0 for x <= 0, 1 for x >= 1 |

`a <= 0` or `b <= 0` returns NaN. At x = 0 the PDF is 0 for a > 1, `b` for
a = 1, and +inf for a < 1; x = 1 mirrors this with `b`.

The incomplete beta is computed in f64 and returned as f32. Relative error stays
below 2e-6 while `a` and `b` are both at least 1 and the larger is at most 1e8,
and grows outside that range in both directions. The precision guide states the
range and what happens beyond it.

## F distribution

Parameterized by the numerator and denominator degrees of freedom `d1` and
`d2`, both positive. The CDF evaluates the regularized incomplete beta
function at `d1*x / (d1*x + d2)`.

| Function | Signature | Returns |
|---|---|---|
| `f_pdf` | `(x: f32, d1: f32, d2: f32) -> f32` | density; 0 for x <= 0 |
| `f_cdf` | `(x: f32, d1: f32, d2: f32) -> f32` | P(X <= x); 0 for x <= 0 |

`d1 <= 0` or `d2 <= 0` returns NaN for x > 0. Non-integer degrees of freedom
are accepted.

Both `d1*x / (d1*x + d2)` and its complement `d2 / (d1*x + d2)` are formed in f64,
so a small `d2` beside a large `d1*x` keeps its digits instead of rounding the
argument to 1. Relative error stays below 2e-6 while `d1` and `d2` are both at
least 1 and the larger is at most 1e8, and grows outside that range in both
directions: `f_cdf(0.5, 2e8, 0.5)` errs by about 2e-6 and
`f_cdf(0.5, 1e8, 1e-3)` by 2.5e-5. The
[precision guide](../appendix/precision.md) states the range for every export in
this family.

## Pitfalls

- Where the text above gives a CDF as `1 - exp(..)`, that is its definition
  and not how it is evaluated. Subtracting that way loses every small value,
  so both functions complement in f64 through a series instead. Their own
  small values are sound; what still loses everything below about 6e-8 is a
  caller writing `1 - exponential_cdf(x, rate)` for the upper tail.
- Only the gamma family has survival functions. For the upper tail of these
  families, subtracting the CDF from 1 loses everything below about 6e-8.
