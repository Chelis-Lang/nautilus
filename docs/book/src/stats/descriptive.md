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
| `trimmed_mean_vec` | `[n](v: &tensor[n, f32], proportion: f32) -> f32` | Trims `proportion` from each tail; NaN unless 0 <= proportion < 0.5 |

## Dispersion

| Function | Signature | Notes |
|---|---|---|
| `variance_vec` | `[n](v: &tensor[n, f32], ddof: i64) -> f32` | Sum of squared deviations divided by `n - ddof`: ddof=0 for population, ddof=1 for sample |
| `std_vec` | `[n](v: &tensor[n, f32], ddof: i64) -> f32` | sqrt(variance_vec) |
| `range_vec` | `[n](v: &tensor[n, f32]) -> f32` | max - min |

`ddof` is not validated, so keep it in `0 <= ddof < n`. Outside that range
the divisor `n - ddof` is zero or negative and the result is not a variance.
On the six-element vector in the example below:

| Call | Result | Why |
|---|---|---|
| `variance_vec(data, 6)` | `inf` | divides a positive sum by 0 |
| `variance_vec(data, 7)` | `-30.833332` | divides by -1 |
| `variance_vec(one_value, 1)` | `NaN` | 0 / 0 for a single element |
| `variance_vec(data, -1)` | `4.404762` | divides by 7, a meaningless denominator |

`std_vec` takes the square root, so the negative case becomes NaN there.
An empty vector (`n = 0`) gives NaN from `mean_vec` but `-0.0` from
`variance_vec(v, 1)`, because its sum of squares is 0 and the divisor is -1.
Check the length before reducing data that can be empty.

## Shape

| Function | Signature | Notes |
|---|---|---|
| `skewness_vec` | `[n](v: &tensor[n, f32]) -> f32` | Population skewness (biased, not adjusted) |
| `kurtosis_vec` | `[n](v: &tensor[n, f32]) -> f32` | Excess kurtosis (Fisher convention, subtracts 3) |

## Order statistics

| Function | Signature | Notes |
|---|---|---|
| `min_vec` | `[n](v: &tensor[n, f32]) -> f32` | `inf` for an empty vector; skips NaN |
| `max_vec` | `[n](v: &tensor[n, f32]) -> f32` | `-inf` for an empty vector; skips NaN |
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

## Multiple testing and likelihood ratios

| Function | Signature | Returns |
|---|---|---|
| `bonferroni_adjust` | `[n](p_values: &tensor[n, f32]) -> tensor[n, f32]` | `min(1, n * p)` for each p-value |
| `stat_holm_adjust` | `[n](p_values: &tensor[n, f32]) -> tensor[n, f32]` | Holm step-down adjusted p-values, in input order |
| `benjamini_hochberg_adjust` | `[n](p_values: &tensor[n, f32]) -> tensor[n, f32]` | Benjamini-Hochberg false-discovery-rate adjusted p-values, in input order |
| `fdr_adjust` | same as `benjamini_hochberg_adjust` | the same values |
| `likelihood_ratio_stat` | `(log_likelihood_null: f32, log_likelihood_alt: f32) -> f32` | `2 * (alt - null)` |
| `likelihood_ratio_p_value` | `(log_likelihood_null: f32, log_likelihood_alt: f32, df: f32) -> f32` | `chi_squared_sf(stat, df)` |

```chelis-fragment
import Nautilus.Stats (bonferroni_adjust, stat_holm_adjust, benjamini_hochberg_adjust, likelihood_ratio_p_value)

def pv() -> tensor[4, f32] = to_tensor([0.01f32, 0.04f32, 0.03f32, 0.2f32])
bonf = bonferroni_adjust(pv())
holm = stat_holm_adjust(pv())
bh = benjamini_hochberg_adjust(pv())
lr_p = likelihood_ratio_p_value(-120.0f32, -115.0f32, 2.0f32)
```

```text
pv = tensor(shape=[4], data=[0.01, 0.04, 0.03, 0.2])
bonf = tensor(shape=[4], data=[0.04, 0.16, 0.12, 0.8])
holm = tensor(shape=[4], data=[0.04, 0.089999996, 0.089999996, 0.2])
bh = tensor(shape=[4], data=[0.04, 0.05333333, 0.05333333, 0.2])
lr_p = 0.0067379437
```

Each adjusted value is capped at 1 and keeps the position of its input.
`df` in the likelihood ratio test is the number of extra parameters in the
alternative model. The adjustments sort internally and are O(n^2).

## Example

```chelis-fragment
import Nautilus.Stats (mean_vec, variance_vec, median_vec, quantile_vec, trimmed_mean_vec)

def data() -> tensor[6, f32] = to_tensor([2.0f32, 4.0f32, 4.0f32, 5.0f32, 7.0f32, 9.0f32])
summary = (mean_vec(data()), variance_vec(data(), 1i64), median_vec(data()))
q = quantile_vec(data(), 0.25f32)
trim_ok = trimmed_mean_vec(data(), 0.2f32)
trim_neg = trimmed_mean_vec(data(), -0.1f32)
```

`chelis eval --file` prints:

```text
data = tensor(shape=[6], data=[2.0, 4.0, 4.0, 5.0, 7.0, 9.0])
summary.0 = 5.1666665
summary.1 = 6.1666665
summary.2 = 4.5
q = 4.0
trim_ok = 5.0
trim_neg = NaN
```

The sample variance uses `ddof = 1`, so it divides 30.833332 by 5. The
median of an even-length vector averages the third and fourth sorted values.
`quantile_vec` at 0.25 lands on position 1.25 of the sorted vector, between
two equal values. A 20% trim of six values drops `floor(1.2) = 1` value from
each end and averages `[4, 4, 5, 7]`.

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
