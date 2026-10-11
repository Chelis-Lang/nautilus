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

The PMF works in log space, so large counts do not overflow a factorial, and
it evaluates that log-space expression in f64 before returning an f32. The
dominant term is `ln(Gamma(k + 1)) = ln(k!)`, which reaches 1.05e6 at
`k = 1e5`; one f32 rounding of a quantity that size is an absolute error in
an *exponent*, so it reaches the answer multiplied. In f32 the PMF was 5.2%
high at `k = 1e5`, and above `k = 16777216` the `+ 1` vanished because
the spacing of f32 values at 5e7 is 4. This left the normalising constant
computed for the wrong factorial and `poisson_pmf(5e7, 5e7)` returning 1.0.

> Relative error is below 2e-6 at every measured normal-f32 Poisson case
> through `lambda = 1e8`. The [precision guide](../appendix/precision.md)
> lists the sampled `lambda` and `k` axes.

Below f32's smallest normal, 1.18e-38, the return type cannot carry the
value, so a relative comparison measures f32 quantisation. `poisson_pmf(42, 0.7)` returns 0
against a true 1.1e-58.

Measured cases compare the PMF with SciPy at and beyond the stated ceiling.
Above it the same mechanism continues and nothing in the result indicates
the growing error. At `lambda = 1e9` the measured error is 3.8e-6, one f64
ulp of `ln(k!)` at that count. Note also that f32 cannot represent consecutive
integers above 16777216 at all, so a count passed as an f32 above that is
already on a grid coarser than 1.

The CDF does not sum PMF terms; it evaluates the incomplete gamma function,
which inherits the [large-shape limit](gamma-family.md#large-shapes)
at shape `k + 1`. That limit is the incomplete-gamma lane's rather than the
PMF's, and it used to be much the larger effect: while that lane was computed
in f32, `poisson_cdf(5e7, 5e7)` returned 6.731102e-4 against a true 0.50003761,
and fixing the PMF did not touch it. It is now 0.50003755, which is one f32 ulp below the correctly rounded 0.5000376 and 1.2e-7 relative from exact.

`k + 1` is formed in f64 as well. In f32 the increment vanished above
`k = 16777216`, because the spacing of f32 values at 5e7 is 4. The call
evaluated `Q(k, lambda)` rather than `Q(k + 1, lambda)` and came out short by
exactly `poisson_pmf(k, lambda)`, which is 1.1e-4 of the answer at that count.

The CDF reads the incomplete gamma as the upper tail `Q` rather than as
`1 - P`, so a left tail far below the mean keeps its digits:
`poisson_cdf(10, 50)` is 6.450153e-12, seven significant digits of a
reference 6.4501529e-12. Subtracting `P` from 1 returned 0 for every value under about
6e-8.

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
incomplete beta. In f32 the `+ 1` is lost once `k` reaches 16777216, because the
spacing of f32 values there exceeds 1, and the result then describes a different
distribution. The measured cases through `n = 1e8` have relative error
below 2e-6; the [precision guide](../appendix/precision.md) states the sampled axes.

`binomial_pmf` evaluates its whole log-space body in f64 for the reason given
under `poisson_pmf`, and for one more: `ln C(n, k)` is a difference of three
log-factorials, so its f32 error was bounded by the largest of them rather
than by the answer. At `n = 1e8`, `ln(Gamma(n + 1))` is 1.74e9, where one f32
rounding is an absolute error of 128 in an exponent. `binomial_pmf(5e7, 1e8,
0.5)` returned `inf` and `binomial_pmf(2e7, 4e7, 0.5)` returned 1.0; neither
is a probability. The error was continuous in `n` rather than a cliff at
16777216: 15% at `n = 2e5` and 59% at `n = 2e6`.

> Relative error is below 2e-6 at every measured normal-f32 binomial
> case through `n = 2e8`. The [precision guide](../appendix/precision.md)
> lists the sampled `n`, `p` and `k` axes.

The measured `p` values include skewed probabilities as well as `p = 0.5`.
Their errors vary with `p`, so a finite sample does not identify the worst
probability for every `n`. Above the measured ceiling the error grows with no
signal in the result: at `n = 1e9` the measured error is 3.5e-6.

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
