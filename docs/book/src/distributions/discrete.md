# Discrete distributions

Two discrete families, Poisson and binomial, each with a probability mass
function (PMF) and a cumulative distribution function (CDF). Counts and trial
numbers are `f32` values; pass integer values such as `3.0f32`.

```chelis-fragment
import Nautilus.Distributions (poisson_pmf, poisson_cdf, binomial_pmf, binomial_cdf)

ppmf = poisson_pmf(3.0f32, 2.5f32)
pcdf = poisson_cdf(3.0f32, 2.5f32)
bpmf = binomial_pmf(3.0f32, 10.0f32, 0.3f32)
bcdf = binomial_cdf(3.0f32, 10.0f32, 0.3f32)
```

```text
ppmf = 0.21376301
pcdf = 0.7575761
bpmf = 0.26682794
bcdf = 0.6496107
```

## Poisson

| Function | Signature | Returns |
|---|---|---|
| `poisson_pmf` | `(k: f32, lambda: f32) -> f32` | P(X = k) = exp(k*ln(lambda) - lambda - ln(Gamma(k+1))) |
| `poisson_cdf` | `(k: f32, lambda: f32) -> f32` | P(X <= k) = Q(k+1, lambda), the regularized upper incomplete gamma |

Domain: `k` a non-negative integer value, `lambda >= 0` and finite.

| Input | `poisson_pmf` | `poisson_cdf` |
|---|---|---|
| `lambda < 0` | NaN | NaN |
| `lambda = 0` | 1 at k = 0, else 0 | 1 for every k >= 0 |
| `lambda` NaN | NaN | NaN |
| `k < 0` | 0 | 0 |
| non-integer `k` | 0 | not rounded: uses the continuous incomplete-gamma formula |

The PMF evaluates its log-space expression in f64 before returning f32, so
it does not form a large factorial. The `k + 1` in `ln(Gamma(k + 1))` is
formed in f64. Counts above 16777216 are spaced more than one integer apart
in f32, so the input type cannot represent every consecutive count there.

> Relative error is below 2e-6 at every measured normal-f32 Poisson case
> through `lambda = 1e8`. The [precision guide](../appendix/precision.md)
> lists the sampled `lambda` and `k` axes.

Below f32's smallest normal, 1.18e-38, the return type cannot carry the
value, so a relative comparison measures f32 quantisation. `poisson_pmf(42, 0.7)` returns 0
against a true 1.1e-58.

Outside the measured range, calibrate the PMF against a reference for the
counts and rates you use. At `lambda = 1e9`, one measured relative error is
3.8e-6.

The CDF does not sum PMF terms; it evaluates the incomplete gamma function,
which inherits the [large-shape limit](gamma-family.md#large-shapes) at shape
`k + 1`. It forms that increment in f64, where it survives for every f32
count. `poisson_cdf(5e7, 5e7)` returns `0.50003755` against a reference
`0.50003761`.

The CDF reads the incomplete gamma as the upper tail `Q` rather than as
`1 - P`, so a left tail far below the mean keeps its digits:
`poisson_cdf(10, 50)` is 6.450153e-12 against a reference 6.4501529e-12.

## Binomial

| Function | Signature | Returns |
|---|---|---|
| `binomial_pmf` | `(k: f32, n: f32, p: f32) -> f32` | P(X = k) = C(n, k) p^k (1-p)^(n-k), in log space via `log_gamma` |
| `binomial_cdf` | `(k: f32, n: f32, p: f32) -> f32` | P(X <= k) = I_(1-p)(n - k, k + 1), the regularized incomplete beta, computed in f64 |

Domain: `n` a non-negative integer value, `k` an integer value, `p` in [0, 1].

| Input | `binomial_pmf` | `binomial_cdf` |
|---|---|---|
| `p` outside [0, 1] | NaN | NaN |
| `p = 0` | 1 at k = 0, else 0 | 1 for every k >= 0 |
| `p = 1` | 1 at k = n, else 0 | 0 for k < n, 1 at k >= n |
| `k < 0` | 0 | 0 |
| `k > n` | 0 | 1 |
| non-integer `k` | 0 | not rounded: interpolates between the neighboring counts |
| non-integer `n` | NaN | a value from the continuous formula, not a probability of any binomial |
| `n < 0` | 0 | 1 for k >= 0 |

The CDF checks `p` first, then returns 0 for `k < 0` and 1 for `k >= n`
before reading `n` again, so a bad `n` does not produce NaN there.

`binomial_cdf` forms `n - k`, `k + 1` and `1 - p` in f64 before computing the
incomplete beta. The measured cases through `n = 1e8` have relative error
below 2e-6; the [precision guide](../appendix/precision.md) states the sampled axes.

`binomial_pmf` evaluates its whole log-space body in f64. Its normalization
`ln C(n, k)` subtracts three large log-factorials, so roundoff in that
difference limits accuracy at large counts.

> Relative error is below 2e-6 at every measured normal-f32 binomial
> case through `n = 2e8`. The [precision guide](../appendix/precision.md)
> lists the sampled `n`, `p` and `k` axes.

The measured `p` values include skewed probabilities as well as `p = 0.5`.
They do not bound every probability. At `n = 1e9`, one measured relative
error is 3.5e-6.

## Pitfalls

- Non-integer counts are not rounded by the CDFs.
  `binomial_cdf(3.5, 10, 0.3)` returns `0.761939`, between
  `binomial_cdf(3, 10, 0.3) = 0.6496107` and
  `binomial_cdf(4, 10, 0.3) = 0.8497316`, and is not P(X <= 3). Round a
  computed count with `floor` before the call.
- A NaN count stops `poisson_cdf` evaluation with
  `numeric trap: domain in cast_trunc at i64`. A NaN `lambda` returns NaN.
  Check computed arguments for NaN before the call.
- For an upper tail, subtracting the CDF from 1 loses values below about
  6e-8. Neither family has a survival function.
