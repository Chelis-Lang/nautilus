# Descriptive statistics

The `Nautilus.Stats` module provides descriptive statistics over
`tensor[n, f32]` vectors. All functions are polymorphic over the tensor
length `n`. The reductions return `f32` scalars; `rank_vec` and
`zscore_vec` return a tensor of the same length, and the covariance and
correlation matrices return a square tensor over the variables.

## Central tendency

| Function | Signature | Notes |
|---|---|---|
| `mean_vec` | `[n](v: &tensor[n, f32]) -> f32` | Arithmetic mean |
| `median_vec` | `[n](v: &tensor[n, f32]) -> f32` | Sorts internally; averages middle two for even n |
| `trimmed_mean_vec` | `[n](v: &tensor[n, f32], proportion: f32) -> f32` | Trims `proportion` from each tail; NaN if proportion >= 0.5 |

## Dispersion

| Function | Signature | Notes |
|---|---|---|
| `variance_vec` | `[n](v: &tensor[n, f32], ddof: i64) -> f32` | ddof=0 for population, ddof=1 for sample |
| `std_vec` | `[n](v: &tensor[n, f32], ddof: i64) -> f32` | sqrt(variance_vec) |
| `range_vec` | `[n](v: &tensor[n, f32]) -> f32` | max - min |

## Shape

| Function | Signature | Notes |
|---|---|---|
| `skewness_vec` | `[n](v: &tensor[n, f32]) -> f32` | Population skewness (biased, not adjusted) |
| `kurtosis_vec` | `[n](v: &tensor[n, f32]) -> f32` | Excess kurtosis (Fisher convention, subtracts 3) |

## Order statistics

| Function | Signature | Notes |
|---|---|---|
| `min_vec` | `[n](v: &tensor[n, f32]) -> f32` | |
| `max_vec` | `[n](v: &tensor[n, f32]) -> f32` | |
| `quantile_vec` | `[n](v: &tensor[n, f32], q: f32) -> f32` | q in [0,1], linear interpolation, sorts internally |
| `percentile_vec` | `[n](v: &tensor[n, f32], p: f32) -> f32` | p in [0,100], delegates to quantile_vec |

## Two-sample

| Function | Signature | Notes |
|---|---|---|
| `covariance_scalar` | `[n](a: &tensor[n, f32], b: &tensor[n, f32], ddof: i64) -> f32` | Scalar covariance between two vectors |
| `correlation_scalar` | `[n](a: &tensor[n, f32], b: &tensor[n, f32]) -> f32` | Pearson r (uses ddof=0 internally) |

## Standardization and ranks

These return a tensor of the same length rather than a scalar.

| Function | Signature | Notes |
|---|---|---|
| `rank_vec` | `[n](v: &tensor[n, f32]) -> tensor[n, f32]` | 1-based ranks; ties share the average of the ranks they span |
| `zscore_vec` | `[n](v: &tensor[n, f32], ddof: i64) -> tensor[n, f32]` | `(x - mean) / std`; NaN throughout for a constant vector |

For finite input `rank_vec` matches `scipy.stats.rankdata`'s default
`method="average"`, so `rank_vec([3, 1, 4, 1])` is `[3, 1.5, 4, 1.5]` and the
ranks sum to `n(n+1)/2` whether or not there are ties.

`rank_vec` counts each element against every other, so it is O(n^2) and is
markedly slower than the sort-based reductions in this module; prefer
`quantile_vec` or `median_vec` when a rank vector is not what you need.

## Many variables

| Function | Signature | Notes |
|---|---|---|
| `covariance_matrix` | `[m, n](x: &tensor[m, n, f32], ddof: i64) -> tensor[m, m, f32]` | m variables by n observations |
| `correlation_matrix` | `[m, n](x: &tensor[m, n, f32]) -> tensor[m, m, f32]` | Pearson correlation over the same layout |

Each **row** is a variable and each **column** an observation, matching
`numpy.cov`'s default `rowvar=True`. `covariance_matrix` over two stacked
rows therefore agrees entrywise with `covariance_matrix_2` on the same two
vectors. `correlation_matrix` is
scale-invariant, so it takes no `ddof`.

## Example

```chelis
module Nautilus.BookStatsSummary
import Nautilus.Stats (mean_vec, variance_vec, median_vec)
export (summary)
def summary[n](data: tensor[n, f32]) -> (f32, f32, f32) = {
  mu = mean_vec(data)
  v = variance_vec(data, cast(1, i64))
  med = median_vec(data)
  (mu, v, med)
}
```

## Notes

- Every function borrows its input (`&tensor`), so the same tensor can be
  passed to several statistics without `copy`.
- `skewness_vec` and `kurtosis_vec` use population (biased) moments,
  matching the default behavior of scipy.stats.skew/kurtosis with
  bias=True.
- `quantile_vec` clamps q to [0, 1] and uses linear interpolation
  between adjacent sorted values.
- `trimmed_mean_vec` truncates (floor) the trim count, so small
  proportions on short vectors may trim nothing.
- `zscore_vec` and `correlation_matrix` divide by a standard deviation.
  A constant vector (or a constant row) has zero spread, so the result is
  NaN rather than 0, as `numpy.corrcoef` also does.
- **`rank_vec` does not propagate NaN.** `lt` and `eq` are both false
  against NaN, so a NaN element ranks as `0.5` and is counted by no other
  element: the result is finite, wrong, and gives the caller no signal.
  `scipy.stats.rankdata` returns all-NaN instead. Screen NaN before
  ranking. `zscore_vec`, `covariance_matrix` and `correlation_matrix` all
  propagate NaN correctly. Infinities rank correctly.
- The whole module is f32; its functions do not accept f64 inputs.
