# Hypothesis testing

The `Nautilus.Testing` module provides building blocks for classical
hypothesis tests. All functions are pure f32 computations that compose
`normal_cdf`, `student_t_cdf`, and `chi_squared_sf` from the
Distributions module.

## Z-tests

| Function | Signature | Notes |
|---|---|---|
| `z_statistic` | `(sample_mean, pop_mean, pop_std, sample_n: f32) -> f32` | (x_bar - mu) / (sigma / sqrt(n)) |
| `z_p_value_two_sided` | `(z: f32) -> f32` | 2 * Phi(-\|z\|), the upper tail doubled |
| `z_p_value_upper` | `(z: f32) -> f32` | Phi(-z), the upper tail |
| `z_p_value_lower` | `(z: f32) -> f32` | Phi(z) |
| `normal_ci_half_width` | `(confidence, pop_std, sample_n: f32) -> f32` | z_crit * sigma / sqrt(n), with `confidence` a fraction such as 0.95 |

## T-tests

| Function | Signature | Notes |
|---|---|---|
| `t_statistic_one_sample` | `(sample_mean, sample_std, sample_n, pop_mean: f32) -> f32` | One-sample t |
| `t_statistic_two_sample_pooled` | `(mean1, std1, n1, mean2, std2, n2: f32) -> f32` | Equal-variance pooled t |
| `welch_t_statistic` | `(mean1, std1, n1, mean2, std2, n2: f32) -> f32` | Unequal-variance Welch's t |
| `welch_t_df` | `(std1, n1, std2, n2: f32) -> f32` | Welch-Satterthwaite degrees of freedom |

## P-values

| Function | Signature | Notes |
|---|---|---|
| `t_p_value_two_sided` | `(t, df: f32) -> f32` | 2 * student_t_cdf(-\|t\|, df) |
| `t_p_value_upper` | `(t, df: f32) -> f32` | student_t_cdf(-t, df), the upper tail |
| `t_p_value_lower` | `(t, df: f32) -> f32` | student_t_cdf(t, df), the lower tail |
| `chi_squared_p_value` | `(statistic, df: f32) -> f32` | chi_squared_sf(statistic, df), the upper tail |

## Example: a z-test and a Welch t-test

```chelis
module Nautilus.BookTestingDemo
import Nautilus.Testing (z_statistic, z_p_value_two_sided, welch_t_statistic, welch_t_df, t_p_value_two_sided)
export (z_test_demo, welch_demo)
def z_test_demo() -> f32 = {
  z = z_statistic(cast(5.2, f32), cast(5.0, f32), cast(1.5, f32), cast(36.0, f32))
  z_p_value_two_sided(z)
}
def welch_demo() -> f32 = {
  t = welch_t_statistic(cast(12.0, f32), cast(2.0, f32), cast(30.0, f32), cast(10.0, f32), cast(3.0, f32), cast(25.0, f32))
  df = welch_t_df(cast(2.0, f32), cast(30.0, f32), cast(3.0, f32), cast(25.0, f32))
  t_p_value_two_sided(t, df)
}
```

`z_test_demo` computes z = (5.2 - 5.0) / (1.5 / sqrt(36)) = 0.8 and
returns its two-sided p-value, `0.42371124`. `welch_demo` compares two
samples with unequal variances (means 12 and 10, standard deviations 2 and 3,
sizes 30 and 25) and returns a two-sided p-value of `0.0068913926`.

## Notes

- All parameters are `f32`, including sample sizes. Pass `cast(n, f32)`.
- No argument is validated. Pass a sample size of at least 1 (at least 2
  for anything that divides by `n - 1`), a positive standard deviation, and
  a `confidence` strictly between 0 and 1. Out-of-range inputs return a
  number or NaN without an error, as the table shows. A fractional size is
  used as given, not rounded.

| Call | Result |
|---|---|
| `normal_ci_half_width(0.95, 1.5, 36.0)` | `0.48996764` |
| `normal_ci_half_width(95.0, 1.5, 36.0)` | `NaN`: 95 is read as a probability |
| `z_statistic(5.2, 5.0, 1.5, 0.0)` | `0.0`: the standard error is `inf` |
| `z_statistic(5.2, 5.0, 1.5, -4.0)` | `NaN`: square root of a negative size |
| `welch_t_df(2.0, 1.0, 3.0, 25.0)` | `0.0`: `n1 - 1 = 0` makes a term infinite |

- The p-value functions use the standard-normal or Student-t CDF
  internally. Accuracy depends on the underlying CDF approximation: erf-based
  for normal, and for Student-t the regularized incomplete beta below `df` of
  1e7 and the large-`df` expansion above it.
- `chi_squared_p_value` returns the upper-tail probability (the
  conventional test p-value for goodness-of-fit tests).

## Right-tail accuracy

Every upper-tail and two-sided p-value here is a tail value that the module
calculates directly, not as `1 - cdf`. A subtraction of a CDF from `1.0` has
an absolute error of about `0.5 * ulp(1.0)`, which is 6e-8 in f32, for any
CDF accuracy. Thus the subtraction returns exactly `0.0` when the true tail
is below that value. Above that point, the result has no significant digits
for some distance.

The `1 - cdf` form gives `0.0` at `z = 6`, at a chi-squared statistic of `40`
with 3 degrees of freedom, and at `t = 100` with 5 degrees of freedom. The
table gives the worst relative error of the direct tail over a sweep of 265
arguments where the result is a normal f32. The subnormal results follow the
table.

| Family | Worst relative error | Route |
|---|---|---|
| `z_p_value_upper`, `z_p_value_two_sided` | 8.9e-8 | `Phi(-z)`, exact by standard-normal symmetry |
| `t_p_value_upper`, `t_p_value_two_sided` | 1.2e-7 | `student_t_cdf(-t, df)`, exact by Student-t symmetry |
| `chi_squared_p_value` | 4.2e-6 | `chi_squared_sf`, which returns the upper regularized incomplete gamma `Q` directly |

The Student-t bound comes from `betai` below `df` of 1e7 and from the large-`df`
expansion above it. It no longer grows with `df`: over a
406-point sweep the worst error is 1.15e-7 at `df = 1`, 9.1e-8 at `df = 2`,
6.7e-8 at `df = 10` and 4.9e-8 at `df = 100`, with no result above 1e-6. It did
grow with `df` while the incomplete beta was computed in f32, because the
normalizing factor is a difference of log-gammas that grow with `df`. The figure
is a sweep maximum rather than a bound: a denser sweep raised it once, so rely on
the shape (flat in `df`, below 1e-6) and calibrate tolerances against a reference
over the degrees of freedom your calculation uses.

No p-value in the sweep is on a different side of 0.05, 0.01 or 0.001 than
the `1 - cdf` form. Thus no test decision changes. The direct tail changes
only the tail magnitudes that you can read.

Two limits remain, and both come from f32, not from the algorithm:

- Below about `1.2e-38`, the result is subnormal and has only a few bits.
  `z_p_value_upper(14.0)` returns `8.4e-45`, but the true value is `7.8e-45`.
- Near `1e-45`, no bits remain and the result is `0.0`. The f32
  round-to-zero point is `7.0e-46`, half the smallest subnormal.
  `z_p_value_upper` gets to zero at a true tail of about `8e-46`, slightly
  above that point. At `z = 14.160367`, the standardized tail is the
  smallest subnormal, and half of that value rounds to zero. In both
  situations the zero is correct: `z_p_value_upper(15.0)` is `0.0` because
  `Phi(-15)` is `3.7e-51`.

For tails this small, you need a log-scale tail function, which this module
does not have.

`Nautilus.Stats.likelihood_ratio_p_value` is a chi-squared upper tail and has
the same properties.
