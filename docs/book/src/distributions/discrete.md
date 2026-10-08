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
pcdf = 0.75757635
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
| `lambda` NaN | NaN | stack overflow under `chelis eval` at the default 8 MB stack; NaN after `ulimit -s 65520` |
| `k < 0` | 0 | 0 |
| non-integer `k` | 0 | not rounded: interpolates between the neighboring counts |

The PMF works in log space, so large counts do not overflow a factorial, and
it evaluates that log-space expression in f64 before returning an f32. The
dominant term is `ln(Gamma(k + 1)) = ln(k!)`, which reaches 1.05e6 at
`k = 1e5`; one f32 rounding of a quantity that size is an absolute error in
an *exponent*, so it reaches the answer multiplied. In f32 the PMF was 5.2%
high at `k = 1e5`, and above `k = 16777216` the `+ 1` vanished outright --
the spacing of f32 values at 5e7 is 4 -- which left the normalising constant
computed for the wrong factorial and `poisson_pmf(5e7, 5e7)` returning 1.0.

> Relative error stays below 2e-6 for `lambda` up to 1e8.

That range is a gate, not a sentence: `parity/check_pmf_accuracy.py` measures
both PMFs against SciPy at and beyond the stated ceiling on every CI run.
Above it the same mechanism keeps going and nothing in the result indicates
it -- at `lambda = 1e9` the gate measures 3.8e-6, which is one f64 ulp of
`ln(k!)` at that count. Note also that f32 cannot represent consecutive
integers above 16777216 at all, so a count passed as an f32 above that is
already on a grid coarser than 1.

The CDF does not sum PMF terms; it evaluates the incomplete gamma function,
which inherits the [large-shape limit](gamma-family.md#large-shapes)
at shape `k + 1`. **That limit is the f32 incomplete-gamma lane's, not the
PMF's, and it is much the larger effect**: `poisson_cdf(5e7, 5e7)` returns
6.731102e-4 against a true 0.50003761. Fixing the PMF does not touch it.

The CDF reads that function as the upper tail `Q` rather than as
`1 - P`, so a left tail far below the mean keeps its digits:
`poisson_cdf(10, 50)` is 6.450134e-12, five significant digits of a
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
distribution. Relative error stays below 2e-6 for `n` up to 1e8.

`binomial_pmf` evaluates its whole log-space body in f64 for the reason given
under `poisson_pmf`, and for one more: `ln C(n, k)` is a difference of three
log-factorials, so its f32 error was bounded by the largest of them rather
than by the answer. At `n = 1e8`, `ln(Gamma(n + 1))` is 1.74e9, where one f32
rounding is an absolute error of 128 in an exponent. `binomial_pmf(5e7, 1e8,
0.5)` returned `inf` and `binomial_pmf(2e7, 4e7, 0.5)` returned 1.0; neither
is a probability. The error was continuous in `n` rather than a cliff at
16777216: 15% at `n = 2e5` and 59% at `n = 2e6`.

> Relative error stays below 2e-6 for `n` up to 2e8, at every `p`.

`p` is part of that claim because it is where the range was first measured
wrongly: the worst in-range case is at `p = 0.999999`, not at `p = 0.5`.
Above the ceiling the error grows with no signal in the result, as it does
for `poisson_pmf`: at `n = 1e9` the gate measures 3.5e-6, at `p = 0.1`.

## Pitfalls

- Non-integer counts are not rounded by the CDFs.
  `binomial_cdf(3.5, 10, 0.3)` returns `0.761939`, between
  `binomial_cdf(3, 10, 0.3) = 0.6496107` and
  `binomial_cdf(4, 10, 0.3) = 0.8497316`, and is not P(X <= 3). Round a
  computed count with `floor` before the call.
- A NaN argument does not give a clean NaN from `poisson_cdf`:
  `poisson_cdf(NaN, lambda)` stops evaluation with
  `numeric trap: domain in cast_trunc at i64`, and `poisson_cdf(k, NaN)`
  exhausts the default stack. Check computed arguments for NaN first.
- For an upper tail, subtracting the CDF from 1 loses values below about
  6e-8. Neither family has a survival function.
