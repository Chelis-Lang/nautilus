# Other Continuous Distributions

Six additional continuous distribution families: Exponential, LogNormal,
Uniform, Weibull, Beta, and F. Each provides PDF and CDF; some also
provide inverse CDF and sampling.

## Exponential

Parameterized by `rate` (not scale). PDF: rate * exp(-rate * x) for x >= 0.

- **`exponential_pdf(x: f32, rate: f32) -> f32`**
- **`exponential_cdf(x: f32, rate: f32) -> f32`** -- 1 - exp(-rate * x)
- **`exponential_inv_cdf(q: f32, rate: f32) -> f32`** -- -ln(1 - q) / rate
- **`exponential_sample[n](k, template, rate) -> tensor`**

```chelis-fragment
import Nautilus.Distributions (exponential_cdf)

cdf = exponential_cdf(cast(1.0, f32), cast(2.0, f32))  -- approximately 0.8647
```

## LogNormal

Parameterized by `mu` and `sigma` of the underlying normal. Delegates
to `normal_cdf`/`normal_inv_cdf` after taking log(x).

- **`lognormal_pdf(x: f32, mu: f32, sigma: f32) -> f32`** -- 0 for x <= 0
- **`lognormal_cdf(x: f32, mu: f32, sigma: f32) -> f32`** -- normal_cdf(ln(x), mu, sigma)
- **`lognormal_inv_cdf(q: f32, mu: f32, sigma: f32) -> f32`** -- exp(normal_inv_cdf(q))
- **`lognormal_sample[n](k, template, mu, sigma) -> tensor`**

```chelis-fragment
import Nautilus.Distributions (lognormal_cdf)

cdf = lognormal_cdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))  -- approximately 0.5
```

## Uniform

Parameterized by `lo` and `hi` endpoints. 1/(hi - lo) inside, 0 outside.

- **`uniform_pdf(x: f32, lo: f32, hi: f32) -> f32`**
- **`uniform_cdf(x: f32, lo: f32, hi: f32) -> f32`**
- **`uniform_inv_cdf(q: f32, lo: f32, hi: f32) -> f32`** -- lo + q*(hi-lo)
- **`uniform_sample[n](k, template, lo, hi) -> tensor`**

```chelis-fragment
import Nautilus.Distributions (uniform_cdf)

cdf = uniform_cdf(cast(0.25, f32), cast(0.0, f32), cast(1.0, f32)) -- 0.25
```

## Weibull

Parameterized by `shape` (k) and `scale` (lambda). CDF is closed-form.

- **`weibull_pdf(x: f32, shape: f32, scale: f32) -> f32`**
- **`weibull_cdf(x: f32, shape: f32, scale: f32) -> f32`** -- 1 - exp(-(x/scale)^shape)
- **`weibull_inv_cdf(q: f32, shape: f32, scale: f32) -> f32`**

```chelis-fragment
import Nautilus.Distributions (weibull_cdf)

cdf = weibull_cdf(cast(1.0, f32), cast(2.0, f32), cast(1.0, f32))
```

## Beta

Parameterized by shape parameters `a` and `b`, both > 0. PDF is 0 outside [0, 1].

- **`beta_pdf(x: f32, a: f32, b: f32) -> f32`** -- via log_gamma
- **`beta_cdf(x: f32, a: f32, b: f32) -> f32`** -- via regularized incomplete beta

```chelis-fragment
import Nautilus.Distributions (beta_cdf)

cdf = beta_cdf(cast(0.3, f32), cast(2.0, f32), cast(5.0, f32))  -- approximately 0.5798
```

The incomplete beta is evaluated in f64 internally and returned as f32, which
keeps the relative error under 1e-6 while **`max(a, b)`** stays under about 3e8.
Past that the iteration budget runs short and the result loses digits silently --
1.2e-3 at 1e10, 21% at 1e11 -- and `beta_cdf(0.5, 3e38, 3e38)` returns a
confident 1.0 against a true 0.5. A value that leaves [0, 1] after the budget is
exhausted comes back as NaN, but that catches only part of the band. See [the
precision guide](../appendix/precision.md) for the measured range per export.

## F distribution

Parameterized by `d1` and `d2` degrees of freedom. Uses `betai` internally.

- **`f_pdf(x: f32, d1: f32, d2: f32) -> f32`** / **`f_cdf(...) -> f32`**

```chelis-fragment
import Nautilus.Distributions (f_cdf)

cdf = f_cdf(cast(3.0, f32), cast(5.0, f32), cast(10.0, f32))  -- approximately 0.9344
```

The documented range is indexed on `max(d1, d2)` here. `f_cdf` forms both
`u = d1*x/(d1*x + d2)` and its complement `d2/(d1*x + d2)` in f64 and passes both
to the incomplete beta, rather than recovering the second by subtraction. In f32 `u` reached exactly 1.0 whenever `d2` was small beside
`d1*x`, and the result was then 1.0 for a distribution whose value is nowhere
near it: `f_cdf(1.0, 1e8, 1.0)` returned 1.0 against a true 0.317.

## Edge cases

| Condition | Result |
|---|---|
| Any PDF with x < 0 (except Uniform) | 0.0 |
| `exponential_inv_cdf(1.0, rate)` | +inf |
| `weibull_inv_cdf(0.0/1.0, ...)` | 0.0 / +inf |
| `beta_pdf` or `f_pdf` with params <= 0 | NaN |
| `lognormal_pdf(0.0, ...)` | 0.0 |
