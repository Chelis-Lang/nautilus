module Nautilus.Tests.Stats
import Nautilus.Stats (mean_vec, variance_vec, std_vec, median_vec, min_vec, max_vec, range_vec, skewness_vec, kurtosis_vec, covariance_scalar, correlation_scalar, quantile_vec, percentile_vec, trimmed_mean_vec, rank_vec, zscore_vec, bonferroni_adjust, stat_holm_adjust, benjamini_hochberg_adjust, fdr_adjust, likelihood_ratio_stat, likelihood_ratio_p_value, covariance_2x2, correlation_2x2, covariance_matrix, correlation_matrix)
import Nautilus.LinAlg (matvec, inner_product)
import Std.Test (assert_close, assert_close_tensor, assert_true)
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
  assert_close(variance_vec(v, cast(0, i64)), cast(0.0, f32), cast(1e-6, f32), "population variance of constant = 0")
}
def test_variance_constant_zero_sample() -> unit ! { Test } = {
  v = to_tensor([cast(5.0, f32), cast(5.0, f32), cast(5.0, f32), cast(5.0, f32)])
  assert_close(variance_vec(v, cast(1, i64)), cast(0.0, f32), cast(1e-6, f32), "sample variance of constant = 0")
}
def test_variance_two_points_population() -> unit ! { Test } = {
  v = to_tensor([cast(0.0, f32), cast(2.0, f32)])
  assert_close(variance_vec(v, cast(0, i64)), cast(1.0, f32), cast(1e-6, f32), "population variance of [0,2] = 1")
}
def test_variance_two_points_sample() -> unit ! { Test } = {
  v = to_tensor([cast(0.0, f32), cast(2.0, f32)])
  assert_close(variance_vec(v, cast(1, i64)), cast(2.0, f32), cast(1e-6, f32), "sample variance of [0,2] = 2")
}
def test_variance_nonnegative() -> unit ! { Test } = {
  v = to_tensor([cast(-3.5, f32), cast(1.2, f32), cast(4.8, f32), cast(-1.0, f32), cast(2.7, f32)])
  vv = variance_vec(v, cast(0, i64))
  assert_true(gte(vv, cast(0.0, f32)), "variance >= 0 for any vector")
}
def test_std_constant_zero() -> unit ! { Test } = {
  v = to_tensor([cast(3.0, f32), cast(3.0, f32), cast(3.0, f32)])
  assert_close(std_vec(v, cast(0, i64)), cast(0.0, f32), cast(1e-6, f32), "std of constant = 0")
}
def test_std_sqrt_variance_identity() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(4.0, f32), cast(7.0, f32), cast(11.0, f32)])
  s = std_vec(copy(v), cast(0, i64))
  rhs = sqrt(variance_vec(v, cast(0, i64)))
  assert_close(s, rhs, cast(1e-6, f32), "std(v) = sqrt(variance(v))")
}
def test_std_two_point_closed_form() -> unit ! { Test } = {
  v = to_tensor([cast(0.0, f32), cast(2.0, f32)])
  assert_close(std_vec(v, cast(0, i64)), cast(1.0, f32), cast(1e-6, f32), "std([0,2], pop) = 1")
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
  c = covariance_scalar(copy(v), copy(v), cast(1, i64))
  vv = variance_vec(v, cast(1, i64))
  assert_close(c, vv, cast(0.00001, f32), "cov(x, x) = var(x)")
}
def test_covariance_symmetric() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  y = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(5.0, f32), cast(8.0, f32), cast(11.0, f32)])
  c_xy = covariance_scalar(copy(x), copy(y), cast(1, i64))
  c_yx = covariance_scalar(y, x, cast(1, i64))
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
  _ = assert_close(index(to_list(adjusted), cast(0, i64)), cast(0.02, f32), cast(1e-6, f32), "Bonferroni multiplies by m")
  assert_close(index(to_list(adjusted), cast(1, i64)), cast(1.0, f32), cast(1e-6, f32), "Bonferroni caps at 1")
}
def test_holm_adjust_monotone_example() -> unit ! { Test } = {
  p = to_tensor([cast(0.01, f32), cast(0.04, f32), cast(0.03, f32)])
  adjusted = stat_holm_adjust(p)
  _ = assert_close(index(to_list(adjusted), cast(0, i64)), cast(0.03, f32), cast(1e-6, f32), "Holm first sorted p uses multiplier m")
  assert_close(index(to_list(adjusted), cast(1, i64)), cast(0.06, f32), cast(1e-6, f32), "Holm adjusted p-values are step-down monotone")
}
def test_bh_and_fdr_alias() -> unit ! { Test } = {
  p = to_tensor([cast(0.01, f32), cast(0.04, f32), cast(0.03, f32)])
  bh = benjamini_hochberg_adjust(copy(p))
  fdr = fdr_adjust(p)
  _ = assert_close(index(to_list(bh), cast(0, i64)), cast(0.03, f32), cast(1e-6, f32), "BH adjusts smallest p by m/rank")
  assert_close(index(to_list(bh), cast(1, i64)), index(to_list(fdr), cast(1, i64)), cast(1e-6, f32), "fdr_adjust aliases BH")
}
def test_likelihood_ratio_stat() -> unit ! { Test } = assert_close(likelihood_ratio_stat(cast(-12.0, f32), cast(-10.0, f32)), cast(4.0, f32), cast(1e-6, f32), "LR statistic is 2*(alt-null)")
def basis2(idx: i64, value: f32) -> tensor[2, f32] = {
  zero_i = cast(0, i64)
  if eq(idx, zero_i) then to_tensor([value, cast(0.0, f32)]) else to_tensor([cast(0.0, f32), value])
}
def mat2_get(m: &tensor[2, 2, f32], i: i64, j: i64) -> f32 = {
  col = matvec(m, basis2(j, cast(1.0, f32)))
  inner_product(col, basis2(i, cast(1.0, f32)))
}
def test_covariance_2x2_diagonal_matches_variance() -> unit ! { Test } = {
  x = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  y = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32)])
  cov = covariance_2x2(copy(x), copy(y), cast(0, i64))
  corr = correlation_2x2(x, y)
  _ = assert_close(mat2_get(copy(cov), cast(0, i64), cast(0, i64)), cast(0.6666667, f32), cast(1e-6, f32), "covariance_2x2[0,0] is var(x)")
  assert_close(mat2_get(corr, cast(0, i64), cast(1, i64)), cast(1.0, f32), cast(0.0001, f32), "correlation_2x2 off diagonal for y=2x is 1")
}
def test_rank_no_ties_is_ordinal() -> unit ! { Test } = {
  v = to_tensor([cast(30.0, f32), cast(10.0, f32), cast(20.0, f32)])
  expected = to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)])
  assert_close_tensor(rank_vec(v), expected, cast(1e-6, f32), "rank_vec of a tie-free vector is its ordinal position")
}
def test_rank_averages_ties() -> unit ! { Test } = {
  v = to_tensor([cast(3.0, f32), cast(1.0, f32), cast(4.0, f32), cast(1.0, f32)])
  expected = to_tensor([cast(3.0, f32), cast(1.5, f32), cast(4.0, f32), cast(1.5, f32)])
  assert_close_tensor(rank_vec(v), expected, cast(1e-6, f32), "tied values share the average of the ranks they span (scipy method=average)")
}
def test_rank_all_tied_is_midpoint() -> unit ! { Test } = {
  v = to_tensor([cast(5.0, f32), cast(5.0, f32), cast(5.0, f32), cast(5.0, f32)])
  expected = to_tensor([cast(2.5, f32), cast(2.5, f32), cast(2.5, f32), cast(2.5, f32)])
  assert_close_tensor(rank_vec(v), expected, cast(1e-6, f32), "an all-tied vector ranks every entry at (n+1)/2")
}
def test_rank_tie_is_not_the_bare_ordinal() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(1.0, f32)])
  r0 = index(to_list(rank_vec(v)), cast(0, i64))
  assert_true(neq(r0, cast(1.0, f32)), "a tied first element must not receive the bare ordinal rank 1")
}
def test_rank_sum_is_triangular() -> unit ! { Test } = {
  v = to_tensor([cast(2.0, f32), cast(7.0, f32), cast(2.0, f32), cast(-1.0, f32), cast(7.0, f32)])
  total = fold(fn (acc: f32, x: f32) -> add(acc, x), cast(0.0, f32), to_list(rank_vec(v)))
  assert_close(total, cast(15.0, f32), cast(0.00001, f32), "ranks sum to n(n+1)/2 whether or not there are ties")
}
def test_rank_invariant_under_increasing_map() -> unit ! { Test } = {
  v = to_tensor([cast(2.0, f32), cast(7.0, f32), cast(2.0, f32), cast(-1.0, f32)])
  mapped = to_tensor([cast(5.0, f32), cast(15.0, f32), cast(5.0, f32), cast(-1.0, f32)])
  assert_close_tensor(rank_vec(v), rank_vec(mapped), cast(1e-6, f32), "rank_vec is invariant under the strictly increasing map 2x+1")
}
def test_zscore_known_values() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  expected = to_tensor([cast(-1.2247449, f32), cast(0.0, f32), cast(1.2247449, f32)])
  assert_close_tensor(zscore_vec(v, cast(0, i64)), expected, cast(0.00001, f32), "zscore_vec([1,2,3], ddof=0) = [-sqrt(3/2), 0, sqrt(3/2)]")
}
def test_zscore_has_zero_mean() -> unit ! { Test } = {
  v = to_tensor([cast(4.0, f32), cast(-2.0, f32), cast(9.0, f32), cast(1.5, f32)])
  z = zscore_vec(v, cast(0, i64))
  assert_close(mean_vec(z), cast(0.0, f32), cast(0.00001, f32), "standardised data has mean 0")
}
def test_zscore_has_unit_std() -> unit ! { Test } = {
  v = to_tensor([cast(4.0, f32), cast(-2.0, f32), cast(9.0, f32), cast(1.5, f32)])
  z = zscore_vec(v, cast(0, i64))
  assert_close(std_vec(z, cast(0, i64)), cast(1.0, f32), cast(0.00001, f32), "standardised data has population std 1")
}
def test_zscore_ddof_rescales_by_sqrt_n_over_n_minus_one() -> unit ! { Test } = {
  v = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(10.0, f32)])
  z0 = index(to_list(zscore_vec(copy(v), cast(0, i64))), cast(0, i64))
  z1 = index(to_list(zscore_vec(v, cast(1, i64))), cast(0, i64))
  ratio = sqrt(div(cast(4.0, f32), cast(3.0, f32)))
  assert_close(div(z0, z1), ratio, cast(0.00001, f32), "ddof=1 rescales every z-score by sqrt(n/(n-1))")
}
def test_zscore_constant_vector_is_nan() -> unit ! { Test } = {
  v = to_tensor([cast(7.0, f32), cast(7.0, f32), cast(7.0, f32)])
  z0 = index(to_list(zscore_vec(v, cast(0, i64))), cast(0, i64))
  assert_true(neq(z0, z0), "a constant vector has zero spread, so zscore_vec is NaN rather than 0")
}
def test_covariance_matrix_agrees_with_pairwise_2x2() -> unit ! { Test } = {
  a = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  b = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(7.0, f32)])
  stacked = to_tensor([[cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)], [cast(2.0, f32), cast(4.0, f32), cast(7.0, f32)]])
  general = covariance_matrix(stacked, cast(0, i64))
  pair = covariance_2x2(a, b, cast(0, i64))
  assert_close_tensor(general, pair, cast(1e-6, f32), "covariance_matrix over stacked rows equals covariance_2x2 on the same two variables")
}
def test_covariance_matrix_diagonal_is_variance() -> unit ! { Test } = {
  x = to_tensor([[cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)], [cast(2.0, f32), cast(4.0, f32), cast(7.0, f32)]])
  row0 = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  cov = covariance_matrix(x, cast(0, i64))
  assert_close(mat2_get(cov, cast(0, i64), cast(0, i64)), variance_vec(row0, cast(0, i64)), cast(1e-6, f32), "covariance_matrix[i,i] is variance_vec of row i")
}
def test_covariance_matrix_ddof_scales() -> unit ! { Test } = {
  x = to_tensor([[cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)], [cast(2.0, f32), cast(4.0, f32), cast(7.0, f32)]])
  pop = mat2_get(covariance_matrix(copy(x), cast(0, i64)), cast(0, i64), cast(1, i64))
  samp = mat2_get(covariance_matrix(x, cast(1, i64)), cast(0, i64), cast(1, i64))
  assert_close(div(samp, pop), cast(1.5, f32), cast(0.00001, f32), "ddof=1 scales covariance by n/(n-1) = 3/2")
}
def test_correlation_matrix_diagonal_is_one() -> unit ! { Test } = {
  x = to_tensor([[cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)], [cast(2.0, f32), cast(4.0, f32), cast(7.0, f32)]])
  corr = correlation_matrix(x)
  assert_close(mat2_get(corr, cast(0, i64), cast(0, i64)), cast(1.0, f32), cast(0.00001, f32), "correlation_matrix has a unit diagonal")
}
def test_correlation_matrix_perfect_linear_is_one() -> unit ! { Test } = {
  x = to_tensor([[cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)], [cast(3.0, f32), cast(5.0, f32), cast(7.0, f32)]])
  corr = correlation_matrix(x)
  assert_close(mat2_get(corr, cast(0, i64), cast(1, i64)), cast(1.0, f32), cast(0.0001, f32), "corr(x, 2x+1) = 1 off the diagonal")
}
def test_correlation_matrix_keeps_negative_sign() -> unit ! { Test } = {
  x = to_tensor([[cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)], [cast(9.0, f32), cast(6.0, f32), cast(3.0, f32)]])
  corr = correlation_matrix(x)
  assert_close(mat2_get(corr, cast(0, i64), cast(1, i64)), cast(-1.0, f32), cast(0.0001, f32), "corr(x, -3x+12) = -1, so the sign survives the sqrt(diag) normalisation")
}
def test_correlation_matrix_constant_row_is_nan() -> unit ! { Test } = {
  x = to_tensor([[cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)], [cast(5.0, f32), cast(5.0, f32), cast(5.0, f32)]])
  corr = correlation_matrix(x)
  c01 = mat2_get(corr, cast(0, i64), cast(1, i64))
  assert_true(neq(c01, c01), "a constant row has zero variance, so its correlations are NaN rather than 0")
}
def stats_three_by_four() -> tensor[3, 4, f32] = to_tensor([[cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)], [cast(2.0, f32), cast(4.0, f32), cast(7.0, f32), cast(8.0, f32)], [cast(5.0, f32), cast(3.0, f32), cast(2.0, f32), cast(1.0, f32)]])
def test_covariance_matrix_three_variables() -> unit ! { Test } = {
  expected = to_tensor([[cast(1.25, f32), cast(2.625, f32), cast(-1.625, f32)], [cast(2.625, f32), cast(5.6875, f32), cast(-3.4375, f32)], [cast(-1.625, f32), cast(-3.4375, f32), cast(2.1875, f32)]])
  assert_close_tensor(covariance_matrix(stats_three_by_four(), cast(0, i64)), expected, cast(0.00001, f32), "covariance_matrix over 3 variables by 4 observations matches the NumPy covariance reference with bias true, entrywise")
}
def test_correlation_matrix_three_variables() -> unit ! { Test } = {
  expected = to_tensor([[cast(1.0, f32), cast(0.9844952, f32), cast(-0.9827076, f32)], [cast(0.9844952, f32), cast(1.0, f32), cast(-0.9745586, f32)], [cast(-0.9827076, f32), cast(-0.9745586, f32), cast(1.0, f32)]])
  assert_close_tensor(correlation_matrix(stats_three_by_four()), expected, cast(0.00001, f32), "correlation_matrix over 3 variables by 4 observations matches the NumPy correlation reference, entrywise")
}
-- nautilus#137: `likelihood_ratio_p_value` is a chi-squared right-tail
-- p-value and had the same `1 - chi_squared_cdf(..)` spelling as
-- `Nautilus.Testing.chi_squared_p_value`, so it returned exactly 0.0 for any
-- statistic past about 40 on 3 df. It now calls `chi_squared_sf`. References
-- are `Q(df/2, stat/2)` at 60 decimal digits rounded once to f32.
def stat_pv_rel_err(v: f32, ref: f32) -> f32 = div(abs(sub(v, ref)), ref)
def test_likelihood_ratio_p_value_moderate_statistic() -> unit ! { Test } = {
  -- stat = 2 * (-10 - -12.5) = 5, on 3 df
  v = likelihood_ratio_p_value(cast(-12.5, f32), cast(-10.0, f32), cast(3.0, f32))
  assert_true(lt(stat_pv_rel_err(v, cast(0.17179714, f32)), cast(0.00001, f32)), "LR p-value at stat=5, df=3 is 0.17179714")
}
def test_likelihood_ratio_p_value_deep_tail_keeps_significant_digits() -> unit ! { Test } = {
  -- stat = 2 * (-40 - -60) = 40, on 3 df: a routine nested-model comparison,
  -- and exactly where the cancelling form returned 0.0.
  v = likelihood_ratio_p_value(cast(-60.0, f32), cast(-40.0, f32), cast(3.0, f32))
  _ = assert_true(gt(v, cast(0.0, f32)), "LR p-value at stat=40, df=3 is strictly positive")
  assert_true(lt(stat_pv_rel_err(v, cast(1.065509e-8, f32)), cast(0.00001, f32)), "LR p-value at stat=40, df=3 is 1.065509e-8")
}
def test_likelihood_ratio_p_value_decreases_with_the_statistic() -> unit ! { Test } = {
  -- The cancelling form tied these two at 0.0, so strict `lt` is the test it
  -- fails.
  df = cast(3.0, f32)
  p40 = likelihood_ratio_p_value(cast(-60.0, f32), cast(-40.0, f32), df)
  p100 = likelihood_ratio_p_value(cast(-90.0, f32), cast(-40.0, f32), df)
  assert_true(lt(p100, p40), "LR p-value decreases as the statistic grows")
}
def test_likelihood_ratio_p_value_is_one_when_the_models_tie() -> unit ! { Test } = {
  v = likelihood_ratio_p_value(cast(-10.0, f32), cast(-10.0, f32), cast(3.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-6, f32), "LR p-value is 1 when the log-likelihoods are equal")
}
