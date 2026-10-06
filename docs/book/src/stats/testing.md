# Hypothesis Testing

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
| `normal_ci_half_width` | `(confidence, pop_std, sample_n: f32) -> f32` | z_crit * sigma / sqrt(n) |

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

`z_test_demo` computes z = (5.2 - 5.0) / (1.5 / sqrt(36)) = 0.8 and its
two-sided p-value, approximately 0.424. `welch_demo` compares two samples
with unequal variances (means 12 and 10, standard deviations 2 and 3, sizes
30 and 25) and returns a two-sided p-value of approximately 0.0069.

## Notes

- All parameters are `f32`, including sample sizes. Pass `cast(n, f32)`.
- The p-value functions use the standard-normal or Student-t CDF
  internally. Accuracy depends on the underlying CDF approximation
  (erf-based for normal, betai-based for Student-t).
- `chi_squared_p_value` returns the upper-tail probability (the
  conventional test p-value for goodness-of-fit tests).

## Right-tail accuracy

Every upper-tail and two-sided p-value here is computed as a tail value
directly, never as `1 - cdf`. The distinction is not cosmetic. Subtracting a
CDF from `1.0` leaves an absolute error of about `0.5 * ulp(1.0)`, which is
6e-8 in f32, however accurate the CDF itself is -- so the subtraction returns
exactly `0.0` as soon as the true tail falls below that, and the result has no
significant digits before it does. The old spelling collapsed at `z = 6`, at a
chi-squared statistic of `40` on 3 degrees of freedom, and at `t = 100` on 5
degrees of freedom (nautilus#137, the right-tail mirror of nautilus#113).

What the current spelling gives you instead, measured over the 265 of those
arguments whose answer is a normal f32 (the subnormal rows are below):

| Family | Worst relative error | Route |
|---|---|---|
| `z_p_value_upper`, `z_p_value_two_sided` | 8.9e-8 | `Phi(-z)`, exact by standard-normal symmetry |
| `t_p_value_upper`, `t_p_value_two_sided` | 4.4e-5 | `student_t_cdf(-t, df)`, exact by Student-t symmetry. The bound is `betai`'s, and it is worst at **mid-range** arguments (4.4e-5) rather than in the tail (2.0e-5): a large `t` drives `betai`'s argument into its clean first branch, while a mid-range `t` takes the branch that itself ends in a subtraction from one. |
| `chi_squared_p_value` | 4.2e-6 | `chi_squared_sf`, which returns the upper regularized incomplete gamma `Q` directly |

No p-value in the sweep crosses 0.05, 0.01 or 0.001 differently from the old
spelling, so no test verdict changes; what changes is the magnitude you can
read off a tail.

Two limits remain, and both are f32's rather than the algorithm's:

- Below about `1e-38` the answer is subnormal and carries only a few bits.
  `z_p_value_upper(14.0)` returns `8.4e-45` against a true `7.8e-45`.
- Below about `7.0e-46` -- half the smallest subnormal, so the point where
  f32 rounds to zero -- there is nothing left and the answer is `0.0`. That is
  correct, not a recurrence of the defect above: `z_p_value_upper(15.0)` is
  `0.0` because `Phi(-15)` is `3.7e-51`. If you need those magnitudes, you
  need a log-scale tail function, which this module does not yet have.

`Nautilus.Stats.likelihood_ratio_p_value` is a chi-squared upper tail and
shares all of this.
