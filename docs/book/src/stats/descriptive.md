# Descriptive Statistics

The `Nautilus.Stats` module provides descriptive statistics over
`tensor[n, f32]` vectors. All functions are polymorphic over the tensor
length `n` and return `f32` scalars.

## Central tendency

| Function | Signature | Notes |
|---|---|---|
| `mean_vec` | `[n](v: tensor[n, f32]) -> f32` | Arithmetic mean |
| `median_vec` | `[n](v: tensor[n, f32]) -> f32` | Sorts internally; averages middle two for even n |
| `trimmed_mean_vec` | `[n](v: tensor[n, f32], proportion: f32) -> f32` | Trims `proportion` from each tail; NaN if proportion >= 0.5 |

## Dispersion

| Function | Signature | Notes |
|---|---|---|
| `variance_vec` | `[n](v: tensor[n, f32], ddof: int64) -> f32` | ddof=0 for population, ddof=1 for sample |
| `std_vec` | `[n](v: tensor[n, f32], ddof: int64) -> f32` | sqrt(variance_vec) |
| `range_vec` | `[n](v: tensor[n, f32]) -> f32` | max - min |

## Shape

| Function | Signature | Notes |
|---|---|---|
| `skewness_vec` | `[n](v: tensor[n, f32]) -> f32` | Population skewness (biased, not adjusted) |
| `kurtosis_vec` | `[n](v: tensor[n, f32]) -> f32` | Excess kurtosis (Fisher convention, subtracts 3) |

## Order statistics

| Function | Signature | Notes |
|---|---|---|
| `min_vec` | `[n](v: tensor[n, f32]) -> f32` | |
| `max_vec` | `[n](v: tensor[n, f32]) -> f32` | |
| `quantile_vec` | `[n](v: tensor[n, f32], q: f32) -> f32` | q in [0,1], linear interpolation, sorts internally |
| `percentile_vec` | `[n](v: tensor[n, f32], p: f32) -> f32` | p in [0,100], delegates to quantile_vec |

## Two-sample

| Function | Signature | Notes |
|---|---|---|
| `covariance_scalar` | `[n](a: tensor[n, f32], b: tensor[n, f32], ddof: int64) -> f32` | Scalar covariance between two vectors |
| `correlation_scalar` | `[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32` | Pearson r (uses ddof=0 internally) |

## Example

```chelis
module Nautilus.BookStatsSummary
import Nautilus.Stats (mean_vec, variance_vec, median_vec)
export (summary)
def summary[n](data: tensor[n, f32]) -> (f32, f32, f32) = {
  mu = mean_vec(copy(data))
  v = variance_vec(copy(data), cast(1, int64))
  med = median_vec(data)
  (mu, v, med)
}
```

## Notes

- Use `copy(data)` when passing the same tensor to multiple statistics
  functions (linear-use discipline).
- `skewness_vec` and `kurtosis_vec` use population (biased) moments,
  matching the default behavior of scipy.stats.skew/kurtosis with
  bias=True.
- `quantile_vec` clamps q to [0, 1] and uses linear interpolation
  between adjacent sorted values.
- `trimmed_mean_vec` truncates (floor) the trim count, so small
  proportions on short vectors may trim nothing.
