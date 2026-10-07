# Discrete Distributions

Two discrete distribution families: Poisson and Binomial. Both provide
a probability mass function (PMF) and a cumulative distribution function
(CDF). Pass counts as integer-valued `f32` values. The PMFs return zero
for non-integer `k`, but the CDFs do not round `k` to a count.

## Poisson

**`poisson_pmf(k: f32, lambda: f32) -> f32`**

Computes P(X = k) = exp(k*ln(lambda) - lambda - ln(Gamma(k+1))) in
log-space to avoid factorial overflow. Returns 0 for non-integer or
negative k. At lambda = 0, returns 1 if k = 0, else 0.

**`poisson_cdf(k: f32, lambda: f32) -> f32`**

Computes P(X <= k) via the complement of the regularized lower
incomplete gamma function: 1 - gammaP(k+1, lambda). This avoids
summing individual PMF values.

- **Parameters:** k >= 0 (integer-valued f32), lambda > 0
- **lambda < 0:** returns NaN
- **lambda = 0:** CDF returns 1.0 for all k >= 0

```chelis-fragment
import Nautilus.Distributions (poisson_pmf, poisson_cdf)

pmf = poisson_pmf(cast(3.0, f32), cast(2.5, f32))  -- approximately 0.2138
cdf = poisson_cdf(cast(3.0, f32), cast(2.5, f32))  -- approximately 0.7576
```

## Binomial

**`binomial_pmf(k: f32, n: f32, p: f32) -> f32`**

Computes P(X = k) = C(n,k) * p^k * (1-p)^(n-k) in log-space using
`log_gamma` for the binomial coefficient. Returns 0 for non-integer k
or k outside [0, n].

**`binomial_cdf(k: f32, n: f32, p: f32) -> f32`**

Computes P(X <= k) via the regularized incomplete beta function:
betaI(n-k, k+1, 1-p). Returns 0 for k < 0, returns 1 for k >= n.

`1-p` is formed in f64, where it is exact for any f32 `p`, and `p` itself is
passed as the complement rather than being recovered by a second subtraction.
Computed in f32, `1-p` was exactly 1.0 for tiny `p`, so `binomial_cdf(0, 1e6,
1e-8)` returned 1.0 against a true 0.990; and it lost its digits for `p` near 1,
where `binomial_cdf(999999, 1e6, 0.99999994)` was wrong by 84%.

- **Parameters:** k in [0, n] (integer-valued f32), n positive integer, p in [0, 1]
- **p = 0:** returns 1 if k = 0, else 0
- **p = 1:** returns 1 if k = n, else 0
- **p outside [0, 1]:** returns NaN

```chelis-fragment
import Nautilus.Distributions (binomial_pmf, binomial_cdf)

pmf = binomial_pmf(cast(3.0, f32), cast(10.0, f32), cast(0.3, f32))
-- approximately 0.2668
cdf = binomial_cdf(cast(3.0, f32), cast(10.0, f32), cast(0.3, f32))
-- approximately 0.6496
```

## Edge cases

| Condition | PMF | CDF |
|---|---|---|
| Non-integer k | 0.0 | no count rounding; pass an integer-valued `f32` |
| k < 0 | 0.0 | 0.0 |
| lambda < 0 (Poisson) | NaN | NaN |
| p outside [0,1] (Binomial) | NaN | NaN |
| k > n (Binomial) | 0.0 | 1.0 |
