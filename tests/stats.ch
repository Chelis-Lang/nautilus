module Nautilus.Tests.Stats
import Nautilus.Stats (mean_vec, variance_vec, std_vec, median_vec, min_vec, max_vec, range_vec, skewness_vec, kurtosis_vec, covariance_scalar, correlation_scalar, quantile_vec, percentile_vec, trimmed_mean_vec, bonferroni_adjust, stat_holm_adjust, benjamini_hochberg_adjust, fdr_adjust, likelihood_ratio_stat, covariance_2x2, correlation_2x2)
import Nautilus.LinAlg (matvec, inner_product)
import Std.Test (assert_close, assert_true)
-- chelis:provenance/v1 carrier
-- id = NAUT-CARRIER-STATS-TESTS
-- role = positive
-- atoms = NAUT-MOD-STATS@xxh3-128:83e4d24feb0b0af7a179db04db8ace9b
-- item-digest = xxh3-128:b0b67356f7ba7993e46555b982386de5
-- oracle-id = NAUT-GATE-CHELIS-TEST
-- oracle-digest = xxh3-128:b5a32db6d41c30665962063a6052d0a5
-- configuration-digest = xxh3-128:ae3dfc4c0cfdd00cc99d50805da0931e
-- scope-schema = nautilus-carrier-scope/v1
-- scope = the exact descriptive-statistics assertions in tests/stats.ch
def test_mean_constant() -> unit ! { Test } = {
  v = to_tensor([cast(7.0, f32), cast(7.0, f32), cast(7.0, f32), cast(7.0, f32), cast(7.0, f32)])
  assert_close(mean_vec(v), cast(7.0, f32), cast(1e-6, f32), "mean of constant vector = constant")
}
def test_mean_zero_vector() -> unit ! { Test } = {
  v = to_tensor([cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  assert_close(mean_vec(v), cast(0.0, f32), cast(1e-6, f32), "mean of zero vector = 0")
}
def test_mean_arithmetic_progression_5() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  assert_close(mean_vec(v), cast(3.0, f32), cast(1e-6, f32), "mean(1..5) = 3")
}
def test_mean_arithmetic_progression_6() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])
  assert_close(mean_vec(v), cast(3.5, f32), cast(1e-6, f32), "mean(1..6) = 3.5")
}
def test_mean_homogeneity() -> unit ! { Test } = {
  v2 = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32)])
  base = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  lhs = mean_vec(v2)
  rhs = mul(cast(2.0, f32), mean_vec(base))
  assert_close(lhs, rhs, cast(1e-6, f32), "mean(2v) = 2 * mean(v)")
}
def test_variance_constant_zero_pop() -> unit ! { Test } = {
  v = to_tensor([cast(5.0, f32), cast(5.0, f32), cast(5.0, f32), cast(5.0, f32)])
  assert_close(variance_vec(v, cast(0, int64)), cast(0.0, f32), cast(1e-6, f32), "population variance of constant = 0")
}
def test_variance_constant_zero_sample() -> unit ! { Test } = {
  v = to_tensor([cast(5.0, f32), cast(5.0, f32), cast(5.0, f32), cast(5.0, f32)])
  assert_close(variance_vec(v, cast(1, int64)), cast(0.0, f32), cast(1e-6, f32), "sample variance of constant = 0")
}
def test_variance_two_points_population() -> unit ! { Test } = {
  v = to_tensor([cast(0.0, f32), cast(2.0, f32)])
  assert_close(variance_vec(v, cast(0, int64)), cast(1.0, f32), cast(1e-6, f32), "population variance of [0,2] = 1")
}
def test_variance_two_points_sample() -> unit ! { Test } = {
  v = to_tensor([cast(0.0, f32), cast(2.0, f32)])
  assert_close(variance_vec(v, cast(1, int64)), cast(2.0, f32), cast(1e-6, f32), "sample variance of [0,2] = 2")
}
def test_variance_nonnegative() -> unit ! { Test } = {
  v = to_tensor([cast(-3.5, f32), cast(1.2, f32), cast(4.8, f32), cast(-1.0, f32), cast(2.7, f32)])
  vv = variance_vec(v, cast(0, int64))
  assert_true(gte(vv, cast(0.0, f32)), "variance >= 0 for any vector")
}
def test_std_constant_zero() -> unit ! { Test } = {
  v = to_tensor([cast(3.0, f32), cast(3.0, f32), cast(3.0, f32)])
  assert_close(std_vec(v, cast(0, int64)), cast(0.0, f32), cast(1e-6, f32), "std of constant = 0")
}
def test_std_sqrt_variance_identity() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(4.0, f32), cast(7.0, f32), cast(11.0, f32)])
  s = std_vec(copy(v), cast(0, int64))
  rhs = sqrt(variance_vec(v, cast(0, int64)))
  assert_close(s, rhs, cast(1e-6, f32), "std(v) = sqrt(variance(v))")
}
def test_std_two_point_closed_form() -> unit ! { Test } = {
  v = to_tensor([cast(0.0, f32), cast(2.0, f32)])
  assert_close(std_vec(v, cast(0, int64)), cast(1.0, f32), cast(1e-6, f32), "std([0,2], pop) = 1")
}
def test_min_unsorted_input() -> unit ! { Test } = {
  v = to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)])
  assert_close(min_vec(v), cast(1.0, f32), cast(1e-6, f32), "min([3,1,2]) = 1")
}
def test_max_unsorted_input() -> unit ! { Test } = {
  v = to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)])
  assert_close(max_vec(v), cast(3.0, f32), cast(1e-6, f32), "max([3,1,2]) = 3")
}
def test_min_le_max() -> unit ! { Test } = {
  v = to_tensor([cast(-2.5, f32), cast(0.4, f32), cast(7.1, f32), cast(3.3, f32), cast(-1.0, f32)])
  mn = min_vec(copy(v))
  mx = max_vec(v)
  assert_true(lte(mn, mx), "min(v) <= max(v)")
}
def test_range_max_minus_min() -> unit ! { Test } = {
  v = to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)])
  assert_close(range_vec(v), cast(2.0, f32), cast(1e-6, f32), "range([3,1,2]) = 2")
}
def test_median_odd_length() -> unit ! { Test } = {
  v = to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)])
  assert_close(median_vec(v), cast(2.0, f32), cast(1e-6, f32), "median([3,1,2]) = 2")
}
def test_median_even_length() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  assert_close(median_vec(v), cast(2.5, f32), cast(1e-6, f32), "median([1,2,3,4]) = 2.5")
}
def test_median_constant() -> unit ! { Test } = {
  v = to_tensor([cast(4.0, f32), cast(4.0, f32), cast(4.0, f32), cast(4.0, f32), cast(4.0, f32)])
  assert_close(median_vec(v), cast(4.0, f32), cast(1e-6, f32), "median of constant = constant")
}
def test_skewness_symmetric_zero() -> unit ! { Test } = {
  v = to_tensor([cast(-2.0, f32), cast(-1.0, f32), cast(0.0, f32), cast(1.0, f32), cast(2.0, f32)])
  assert_close(skewness_vec(v), cast(0.0, f32), cast(0.00001, f32), "skewness of symmetric vector = 0")
}
def test_covariance_self_is_variance() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  c = covariance_scalar(copy(v), copy(v), cast(1, int64))
  vv = variance_vec(v, cast(1, int64))
  assert_close(c, vv, cast(0.00001, f32), "cov(x, x) = var(x)")
}
def test_covariance_symmetric() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  y = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(5.0, f32), cast(8.0, f32), cast(11.0, f32)])
  c_xy = covariance_scalar(copy(x), copy(y), cast(1, int64))
  c_yx = covariance_scalar(y, x, cast(1, int64))
  assert_close(c_xy, c_yx, cast(0.00001, f32), "cov(x, y) = cov(y, x)")
}
def test_correlation_self_is_one() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  r = correlation_scalar(copy(v), v)
  assert_close(r, cast(1.0, f32), cast(0.0001, f32), "corr(x, x) = 1")
}
def test_correlation_perfect_linear() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  y = to_tensor([cast(3.0, f32), cast(5.0, f32), cast(7.0, f32), cast(9.0, f32), cast(11.0, f32)])
  r = correlation_scalar(x, y)
  assert_close(r, cast(1.0, f32), cast(0.0001, f32), "corr(x, 2x + 1) = 1")
}
def test_quantile_at_median() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  q50 = quantile_vec(copy(v), cast(0.5, f32))
  m = median_vec(v)
  assert_close(q50, m, cast(0.00001, f32), "quantile(v, 0.5) = median(v)")
}
def test_percentile_matches_quantile() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  p50 = percentile_vec(copy(v), cast(50.0, f32))
  q50 = quantile_vec(v, cast(0.5, f32))
  assert_close(p50, q50, cast(0.00001, f32), "percentile(v, 50) = quantile(v, 0.5)")
}
def test_trimmed_mean_zero_proportion_is_mean() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  t = trimmed_mean_vec(copy(v), cast(0.0, f32))
  m = mean_vec(v)
  assert_close(t, m, cast(0.00001, f32), "trimmed_mean(v, 0) = mean(v)")
}
def test_bonferroni_adjust_caps_at_one() -> unit ! { Test } = {
  p = to_tensor([cast(0.01, f32), cast(0.5, f32)])
  adjusted = bonferroni_adjust(p)
  _ = assert_close(index(to_list(adjusted), cast(0, int64)), cast(0.02, f32), cast(1e-6, f32), "Bonferroni multiplies by m")
  assert_close(index(to_list(adjusted), cast(1, int64)), cast(1.0, f32), cast(1e-6, f32), "Bonferroni caps at 1")
}
def test_holm_adjust_monotone_example() -> unit ! { Test } = {
  p = to_tensor([cast(0.01, f32), cast(0.04, f32), cast(0.03, f32)])
  adjusted = stat_holm_adjust(p)
  _ = assert_close(index(to_list(adjusted), cast(0, int64)), cast(0.03, f32), cast(1e-6, f32), "Holm first sorted p uses multiplier m")
  assert_close(index(to_list(adjusted), cast(1, int64)), cast(0.06, f32), cast(1e-6, f32), "Holm adjusted p-values are step-down monotone")
}
def test_bh_and_fdr_alias() -> unit ! { Test } = {
  p = to_tensor([cast(0.01, f32), cast(0.04, f32), cast(0.03, f32)])
  bh = benjamini_hochberg_adjust(copy(p))
  fdr = fdr_adjust(p)
  _ = assert_close(index(to_list(bh), cast(0, int64)), cast(0.03, f32), cast(1e-6, f32), "BH adjusts smallest p by m/rank")
  assert_close(index(to_list(bh), cast(1, int64)), index(to_list(fdr), cast(1, int64)), cast(1e-6, f32), "fdr_adjust aliases BH")
}
def test_likelihood_ratio_stat() -> unit ! { Test } = assert_close(likelihood_ratio_stat(cast(-12.0, f32), cast(-10.0, f32)), cast(4.0, f32), cast(1e-6, f32), "LR statistic is 2*(alt-null)")
def basis2(idx: int64, value: f32) -> tensor[2, f32] = {
  zero_i = cast(0, int64)
  if eq(idx, zero_i) then to_tensor([value, cast(0.0, f32)]) else to_tensor([cast(0.0, f32), value])
}
def mat2_get(m: &tensor[2, 2, f32], i: int64, j: int64) -> f32 = {
  col = matvec(m, basis2(j, cast(1.0, f32)))
  inner_product(col, basis2(i, cast(1.0, f32)))
}
def test_covariance_2x2_diagonal_matches_variance() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  y = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32)])
  cov = covariance_2x2(copy(x), copy(y), cast(0, int64))
  corr = correlation_2x2(x, y)
  _ = assert_close(mat2_get(copy(cov), cast(0, int64), cast(0, int64)), cast(0.6666667, f32), cast(1e-6, f32), "covariance_2x2[0,0] is var(x)")
  assert_close(mat2_get(corr, cast(0, int64), cast(1, int64)), cast(1.0, f32), cast(0.0001, f32), "correlation_2x2 off diagonal for y=2x is 1")
}
