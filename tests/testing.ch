module Nautilus.Tests.Testing
import Nautilus.Testing (z_statistic, z_p_value_two_sided, z_p_value_upper, z_p_value_lower, normal_ci_half_width, chi_squared_p_value, t_statistic_one_sample, t_statistic_two_sample_pooled, t_p_value_two_sided, t_p_value_upper, t_p_value_lower, welch_t_statistic, welch_t_df)
import Std.Test (assert_close, assert_true)
def test_zstat_no_deviation() -> unit ! { Test } = assert_close(z_statistic(cast(5.0, f32), cast(5.0, f32), cast(2.0, f32), cast(30.0, f32)), cast(0.0, f32), cast(0.0000001, f32), "z-stat is zero when sample mean = pop mean")
def test_zstat_one_standard_error() -> unit ! { Test } = {
  z = z_statistic(cast(5.5, f32), cast(5.0, f32), cast(2.0, f32), cast(16.0, f32))
  assert_close(z, cast(1.0, f32), cast(0.000001, f32), "z-stat = 1 when sample mean is one SE above pop mean")
}
def test_zstat_antisymmetric() -> unit ! { Test } = {
  zp = z_statistic(cast(5.5, f32), cast(5.0, f32), cast(2.0, f32), cast(16.0, f32))
  zn = z_statistic(cast(4.5, f32), cast(5.0, f32), cast(2.0, f32), cast(16.0, f32))
  assert_close(zn, neg(zp), cast(0.000001, f32), "z-stat is antisymmetric around the pop mean")
}
def test_tstat_one_sample_no_deviation() -> unit ! { Test } = assert_close(t_statistic_one_sample(cast(7.0, f32), cast(1.5, f32), cast(20.0, f32), cast(7.0, f32)), cast(0.0, f32), cast(0.0000001, f32), "one-sample t = 0 when sample mean = pop mean")
def test_tstat_one_sample_one_se() -> unit ! { Test } = {
  t = t_statistic_one_sample(cast(8.0, f32), cast(4.0, f32), cast(16.0, f32), cast(7.0, f32))
  assert_close(t, cast(1.0, f32), cast(0.000001, f32), "one-sample t = 1 at one standard error above pop mean")
}
def test_tstat_pooled_equal_means() -> unit ! { Test } = assert_close(t_statistic_two_sample_pooled(cast(3.0, f32), cast(1.0, f32), cast(10.0, f32), cast(3.0, f32), cast(2.0, f32), cast(15.0, f32)), cast(0.0, f32), cast(0.0000001, f32), "pooled two-sample t = 0 when sample means are equal")
def test_welch_t_equal_means() -> unit ! { Test } = assert_close(welch_t_statistic(cast(4.0, f32), cast(1.5, f32), cast(12.0, f32), cast(4.0, f32), cast(2.5, f32), cast(20.0, f32)), cast(0.0, f32), cast(0.0000001, f32), "Welch t = 0 when sample means are equal")
def test_welch_t_identical_samples() -> unit ! { Test } = assert_close(welch_t_statistic(cast(2.7, f32), cast(0.9, f32), cast(25.0, f32), cast(2.7, f32), cast(0.9, f32), cast(25.0, f32)), cast(0.0, f32), cast(0.0000001, f32), "Welch t = 0 for two identical samples")
def test_welch_t_antisymmetric() -> unit ! { Test } = {
  t12 = welch_t_statistic(cast(5.0, f32), cast(1.0, f32), cast(20.0, f32), cast(4.0, f32), cast(1.0, f32), cast(20.0, f32))
  t21 = welch_t_statistic(cast(4.0, f32), cast(1.0, f32), cast(20.0, f32), cast(5.0, f32), cast(1.0, f32), cast(20.0, f32))
  assert_close(t21, neg(t12), cast(0.000001, f32), "Welch t is antisymmetric in sample order")
}
def test_welch_df_symmetric_identical() -> unit ! { Test } = {
  df = welch_t_df(cast(1.0, f32), cast(11.0, f32), cast(1.0, f32), cast(11.0, f32))
  assert_close(df, cast(20.0, f32), cast(0.00001, f32), "Welch df = 2*(n-1) for two identical samples")
}
def test_ci_half_width_positive() -> unit ! { Test } = {
  hw = normal_ci_half_width(cast(0.95, f32), cast(2.0, f32), cast(30.0, f32))
  assert_true(gt(hw, cast(0.0, f32)), "CI half-width is positive at 95% confidence")
}
def test_ci_half_width_grows_with_confidence() -> unit ! { Test } = {
  hw90 = normal_ci_half_width(cast(0.9, f32), cast(2.0, f32), cast(30.0, f32))
  hw99 = normal_ci_half_width(cast(0.99, f32), cast(2.0, f32), cast(30.0, f32))
  assert_true(lt(hw90, hw99), "CI half-width grows with confidence level")
}
def test_ci_symmetric_around_mean() -> unit ! { Test } = {
  mean = cast(10.0, f32)
  hw = normal_ci_half_width(cast(0.95, f32), cast(2.0, f32), cast(40.0, f32))
  lo = sub(mean, hw)
  hi = add(mean, hw)
  mid = mul(cast(0.5, f32), add(lo, hi))
  assert_close(mid, mean, cast(0.000001, f32), "CI is symmetric around the sample mean")
}
def test_ci_shrinks_with_n() -> unit ! { Test } = {
  hw_small = normal_ci_half_width(cast(0.95, f32), cast(2.0, f32), cast(25.0, f32))
  hw_large = normal_ci_half_width(cast(0.95, f32), cast(2.0, f32), cast(100.0, f32))
  assert_true(lt(hw_large, hw_small), "CI half-width shrinks as sample size grows")
}
def test_z_p_two_sided_at_zero() -> unit ! { Test } = assert_close(z_p_value_two_sided(cast(0.0, f32)), cast(1.0, f32), cast(0.000001, f32), "two-sided z p-value at z=0 is 1")
def test_z_p_upper_at_zero() -> unit ! { Test } = assert_close(z_p_value_upper(cast(0.0, f32)), cast(0.5, f32), cast(0.000001, f32), "upper-tail z p-value at z=0 is 0.5")
def test_z_p_lower_at_zero() -> unit ! { Test } = assert_close(z_p_value_lower(cast(0.0, f32)), cast(0.5, f32), cast(0.000001, f32), "lower-tail z p-value at z=0 is 0.5")
def test_z_p_two_sided_monotone() -> unit ! { Test } = {
  p1 = z_p_value_two_sided(cast(0.5, f32))
  p2 = z_p_value_two_sided(cast(1.5, f32))
  p3 = z_p_value_two_sided(cast(2.5, f32))
  _ = assert_true(lt(p2, p1), "two-sided p decreases: p(1.5) < p(0.5)")
  assert_true(lt(p3, p2), "two-sided p decreases: p(2.5) < p(1.5)")
}
def test_z_p_two_sided_symmetric() -> unit ! { Test } = {
  pp = z_p_value_two_sided(cast(1.7, f32))
  pn = z_p_value_two_sided(cast(-1.7, f32))
  assert_close(pp, pn, cast(0.000001, f32), "two-sided z p-value is symmetric in z")
}
def test_z_p_upper_lower_complement() -> unit ! { Test } = {
  z = cast(0.8, f32)
  s = add(z_p_value_upper(z), z_p_value_lower(z))
  assert_close(s, cast(1.0, f32), cast(0.000001, f32), "z upper + lower p-values sum to 1")
}
def test_t_p_two_sided_at_zero() -> unit ! { Test } = assert_close(t_p_value_two_sided(cast(0.0, f32), cast(10.0, f32)), cast(1.0, f32), cast(0.000001, f32), "two-sided t p-value at t=0 is 1")
def test_t_p_upper_at_zero() -> unit ! { Test } = assert_close(t_p_value_upper(cast(0.0, f32), cast(10.0, f32)), cast(0.5, f32), cast(0.000001, f32), "upper-tail t p-value at t=0 is 0.5")
def test_t_p_lower_at_zero() -> unit ! { Test } = assert_close(t_p_value_lower(cast(0.0, f32), cast(10.0, f32)), cast(0.5, f32), cast(0.000001, f32), "lower-tail t p-value at t=0 is 0.5")
def test_t_p_upper_lower_complement() -> unit ! { Test } = {
  t = cast(1.2, f32)
  df = cast(8.0, f32)
  s = add(t_p_value_upper(t, df), t_p_value_lower(t, df))
  assert_close(s, cast(1.0, f32), cast(0.000001, f32), "t upper + lower p-values sum to 1")
}
def test_t_p_two_sided_monotone() -> unit ! { Test } = {
  df = cast(10.0, f32)
  p1 = t_p_value_two_sided(cast(0.5, f32), df)
  p2 = t_p_value_two_sided(cast(1.5, f32), df)
  p3 = t_p_value_two_sided(cast(3.0, f32), df)
  _ = assert_true(lt(p2, p1), "two-sided t p decreases: p(1.5) < p(0.5)")
  assert_true(lt(p3, p2), "two-sided t p decreases: p(3.0) < p(1.5)")
}
def test_chi2_p_at_zero_is_one() -> unit ! { Test } = assert_close(chi_squared_p_value(cast(0.0, f32), cast(3.0, f32)), cast(1.0, f32), cast(0.000001, f32), "chi^2 p-value is 1 when statistic = 0")
def test_chi2_p_in_unit_interval() -> unit ! { Test } = {
  p = chi_squared_p_value(cast(2.5, f32), cast(4.0, f32))
  _ = assert_true(gte(p, cast(0.0, f32)), "chi^2 p-value >= 0")
  assert_true(lte(p, cast(1.0, f32)), "chi^2 p-value <= 1")
}
def test_chi2_p_decreases_with_statistic() -> unit ! { Test } = {
  df = cast(4.0, f32)
  p1 = chi_squared_p_value(cast(1.0, f32), df)
  p2 = chi_squared_p_value(cast(5.0, f32), df)
  p3 = chi_squared_p_value(cast(15.0, f32), df)
  _ = assert_true(lt(p2, p1), "chi^2 p decreases: p(5) < p(1)")
  assert_true(lt(p3, p2), "chi^2 p decreases: p(15) < p(5)")
}
