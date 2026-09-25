# Hypothesis Testing

The `Nautilus.Testing` module provides building blocks for classical
hypothesis tests. All functions are pure f32 computations that compose
`normal_cdf`, `student_t_cdf`, and `chi_squared_cdf` from the
Distributions module.

## Z-tests

| Function | Signature | Notes |
|---|---|---|
| `z_statistic` | `(sample_mean, pop_mean, pop_std, sample_n: f32) -> f32` | (x_bar - mu) / (sigma / sqrt(n)) |
| `z_p_value_two_sided` | `(z: f32) -> f32` | 2 * (1 - Phi(\|z\|)) |
| `z_p_value_upper` | `(z: f32) -> f32` | 1 - Phi(z) |
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
| `t_p_value_two_sided` | `(t, df: f32) -> f32` | Via student_t_cdf |
| `t_p_value_upper` | `(t, df: f32) -> f32` | Upper-tail |
| `t_p_value_lower` | `(t, df: f32) -> f32` | Lower-tail |
| `chi_squared_p_value` | `(statistic, df: f32) -> f32` | 1 - chi_squared_cdf(statistic, df) |

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
