module Nautilus.Tests.Testing
import Nautilus.Testing (z_statistic, z_p_value_two_sided, z_p_value_upper, z_p_value_lower, normal_ci_half_width, chi_squared_p_value, t_statistic_one_sample, t_statistic_two_sample_pooled, t_p_value_two_sided, t_p_value_upper, t_p_value_lower, welch_t_statistic, welch_t_df)
import Std.Test (assert_close, assert_true)
def test_zstat_no_deviation() -> unit ! { Test } = assert_close(z_statistic(cast(5.0, f32), cast(5.0, f32), cast(2.0, f32), cast(30.0, f32)), cast(0.0, f32), cast(1e-7, f32), "z-stat is zero when sample mean = pop mean")
def test_zstat_one_standard_error() -> unit ! { Test } = {
  z = z_statistic(cast(5.5, f32), cast(5.0, f32), cast(2.0, f32), cast(16.0, f32))
  assert_close(z, cast(1.0, f32), cast(1e-6, f32), "z-stat = 1 when sample mean is one SE above pop mean")
}
def test_zstat_antisymmetric() -> unit ! { Test } = {
  zp = z_statistic(cast(5.5, f32), cast(5.0, f32), cast(2.0, f32), cast(16.0, f32))
  zn = z_statistic(cast(4.5, f32), cast(5.0, f32), cast(2.0, f32), cast(16.0, f32))
  assert_close(zn, neg(zp), cast(1e-6, f32), "z-stat is antisymmetric around the pop mean")
}
def test_tstat_one_sample_no_deviation() -> unit ! { Test } = assert_close(t_statistic_one_sample(cast(7.0, f32), cast(1.5, f32), cast(20.0, f32), cast(7.0, f32)), cast(0.0, f32), cast(1e-7, f32), "one-sample t = 0 when sample mean = pop mean")
def test_tstat_one_sample_one_se() -> unit ! { Test } = {
  t = t_statistic_one_sample(cast(8.0, f32), cast(4.0, f32), cast(16.0, f32), cast(7.0, f32))
  assert_close(t, cast(1.0, f32), cast(1e-6, f32), "one-sample t = 1 at one standard error above pop mean")
}
def test_tstat_pooled_equal_means() -> unit ! { Test } = assert_close(t_statistic_two_sample_pooled(cast(3.0, f32), cast(1.0, f32), cast(10.0, f32), cast(3.0, f32), cast(2.0, f32), cast(15.0, f32)), cast(0.0, f32), cast(1e-7, f32), "pooled two-sample t = 0 when sample means are equal")
def test_welch_t_equal_means() -> unit ! { Test } = assert_close(welch_t_statistic(cast(4.0, f32), cast(1.5, f32), cast(12.0, f32), cast(4.0, f32), cast(2.5, f32), cast(20.0, f32)), cast(0.0, f32), cast(1e-7, f32), "Welch t = 0 when sample means are equal")
def test_welch_t_identical_samples() -> unit ! { Test } = assert_close(welch_t_statistic(cast(2.7, f32), cast(0.9, f32), cast(25.0, f32), cast(2.7, f32), cast(0.9, f32), cast(25.0, f32)), cast(0.0, f32), cast(1e-7, f32), "Welch t = 0 for two identical samples")
def test_welch_t_antisymmetric() -> unit ! { Test } = {
  t12 = welch_t_statistic(cast(5.0, f32), cast(1.0, f32), cast(20.0, f32), cast(4.0, f32), cast(1.0, f32), cast(20.0, f32))
  t21 = welch_t_statistic(cast(4.0, f32), cast(1.0, f32), cast(20.0, f32), cast(5.0, f32), cast(1.0, f32), cast(20.0, f32))
  assert_close(t21, neg(t12), cast(1e-6, f32), "Welch t is antisymmetric in sample order")
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
  assert_close(mid, mean, cast(1e-6, f32), "CI is symmetric around the sample mean")
}
def test_ci_shrinks_with_n() -> unit ! { Test } = {
  hw_small = normal_ci_half_width(cast(0.95, f32), cast(2.0, f32), cast(25.0, f32))
  hw_large = normal_ci_half_width(cast(0.95, f32), cast(2.0, f32), cast(100.0, f32))
  assert_true(lt(hw_large, hw_small), "CI half-width shrinks as sample size grows")
}
def test_z_p_two_sided_at_zero() -> unit ! { Test } = assert_close(z_p_value_two_sided(cast(0.0, f32)), cast(1.0, f32), cast(1e-6, f32), "two-sided z p-value at z=0 is 1")
def test_z_p_upper_at_zero() -> unit ! { Test } = assert_close(z_p_value_upper(cast(0.0, f32)), cast(0.5, f32), cast(1e-6, f32), "upper-tail z p-value at z=0 is 0.5")
def test_z_p_lower_at_zero() -> unit ! { Test } = assert_close(z_p_value_lower(cast(0.0, f32)), cast(0.5, f32), cast(1e-6, f32), "lower-tail z p-value at z=0 is 0.5")
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
  assert_close(pp, pn, cast(1e-6, f32), "two-sided z p-value is symmetric in z")
}
def test_z_p_upper_lower_complement() -> unit ! { Test } = {
  z = cast(0.8, f32)
  s = add(z_p_value_upper(z), z_p_value_lower(z))
  assert_close(s, cast(1.0, f32), cast(1e-6, f32), "z upper + lower p-values sum to 1")
}
def test_t_p_two_sided_at_zero() -> unit ! { Test } = assert_close(t_p_value_two_sided(cast(0.0, f32), cast(10.0, f32)), cast(1.0, f32), cast(1e-6, f32), "two-sided t p-value at t=0 is 1")
def test_t_p_upper_at_zero() -> unit ! { Test } = assert_close(t_p_value_upper(cast(0.0, f32), cast(10.0, f32)), cast(0.5, f32), cast(1e-6, f32), "upper-tail t p-value at t=0 is 0.5")
def test_t_p_lower_at_zero() -> unit ! { Test } = assert_close(t_p_value_lower(cast(0.0, f32), cast(10.0, f32)), cast(0.5, f32), cast(1e-6, f32), "lower-tail t p-value at t=0 is 0.5")
def test_t_p_upper_lower_complement() -> unit ! { Test } = {
  t = cast(1.2, f32)
  df = cast(8.0, f32)
  s = add(t_p_value_upper(t, df), t_p_value_lower(t, df))
  assert_close(s, cast(1.0, f32), cast(1e-6, f32), "t upper + lower p-values sum to 1")
}
def test_t_p_two_sided_monotone() -> unit ! { Test } = {
  df = cast(10.0, f32)
  p1 = t_p_value_two_sided(cast(0.5, f32), df)
  p2 = t_p_value_two_sided(cast(1.5, f32), df)
  p3 = t_p_value_two_sided(cast(3.0, f32), df)
  _ = assert_true(lt(p2, p1), "two-sided t p decreases: p(1.5) < p(0.5)")
  assert_true(lt(p3, p2), "two-sided t p decreases: p(3.0) < p(1.5)")
}
def test_chi2_p_at_zero_is_one() -> unit ! { Test } = assert_close(chi_squared_p_value(cast(0.0, f32), cast(3.0, f32)), cast(1.0, f32), cast(1e-6, f32), "chi^2 p-value is 1 when statistic = 0")
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
-- nautilus#137: the right tail needs a *relative* contract, for the mirror of
-- the reason nautilus#113 gave the left one. `1 - cdf` carries absolute error
-- of about `0.5 * ulp(1.0)` however accurate the CDF is, so each of these
-- returned exactly `0.0` once the true tail fell below about 6e-8 -- from
-- `z = 6`, from a chi-squared statistic of 40 on 3 df, and from `t = 100` on
-- 5 df. Every assertion on a tail value is therefore relative: an absolute
-- tolerance near zero passes on `0.0` and on the true answer alike, which is
-- what let the pre-existing cases at |statistic| <= 3 miss this entirely.
-- References are the exact tail at 60 decimal digits, rounded once to f32,
-- and every argument below is exactly representable in f32 so the reference
-- is taken at the value the function actually receives.
def pv_rel_err(v: f32, ref: f32) -> f32 = div(abs(sub(v, ref)), ref)
def test_z_p_upper_deep_tail_keeps_significant_digits() -> unit ! { Test } = {
  a = z_p_value_upper(cast(6.0, f32))
  b = z_p_value_upper(cast(8.0, f32))
  c = z_p_value_upper(cast(10.0, f32))
  d = z_p_value_upper(cast(13.0, f32))
  _ = assert_true(lt(pv_rel_err(a, cast(9.865877e-10, f32)), cast(0.00001, f32)), "z_p_value_upper(6) = 9.865877e-10")
  _ = assert_true(lt(pv_rel_err(b, cast(6.2209604e-16, f32)), cast(0.00001, f32)), "z_p_value_upper(8) = 6.2209604e-16")
  _ = assert_true(lt(pv_rel_err(c, cast(7.619853e-24, f32)), cast(0.00001, f32)), "z_p_value_upper(10) = 7.619853e-24")
  assert_true(lt(pv_rel_err(d, cast(6.117164e-39, f32)), cast(0.00001, f32)), "z_p_value_upper(13) = 6.117164e-39")
}
def test_z_p_two_sided_deep_tail_keeps_significant_digits() -> unit ! { Test } = {
  a = z_p_value_two_sided(cast(6.0, f32))
  b = z_p_value_two_sided(cast(-10.0, f32))
  _ = assert_true(lt(pv_rel_err(a, cast(1.9731754e-9, f32)), cast(0.00001, f32)), "z_p_value_two_sided(6) = 1.9731754e-9")
  assert_true(lt(pv_rel_err(b, cast(1.5239706e-23, f32)), cast(0.00001, f32)), "z_p_value_two_sided(-10) = 1.5239706e-23")
}
def test_z_p_tail_is_never_exactly_zero_in_f32_range() -> unit ! { Test } = {
  -- The failure case: the cancelling form returned exactly 0.0 at every one
  -- of these, so each `gt` below is a test the old spelling fails.
  _ = assert_true(gt(z_p_value_upper(cast(6.0, f32)), cast(0.0, f32)), "z_p_value_upper(6) is strictly positive")
  _ = assert_true(gt(z_p_value_upper(cast(10.0, f32)), cast(0.0, f32)), "z_p_value_upper(10) is strictly positive")
  _ = assert_true(gt(z_p_value_upper(cast(13.0, f32)), cast(0.0, f32)), "z_p_value_upper(13) is strictly positive")
  assert_true(gt(z_p_value_two_sided(cast(10.0, f32)), cast(0.0, f32)), "z_p_value_two_sided(10) is strictly positive")
}
def test_z_p_upper_strictly_decreasing_in_the_tail() -> unit ! { Test } = {
  -- The cancelling form tied every pair at 0.0, so strict `lt` is the
  -- discriminator: a monotonicity test that stops at z = 2.5, as the
  -- pre-existing one does, cannot see a tail that has collapsed.
  p6 = z_p_value_upper(cast(6.0, f32))
  p8 = z_p_value_upper(cast(8.0, f32))
  p10 = z_p_value_upper(cast(10.0, f32))
  _ = assert_true(lt(p8, p6), "z upper p decreases: p(8) < p(6)")
  assert_true(lt(p10, p8), "z upper p decreases: p(10) < p(8)")
}
def test_z_p_upper_underflows_only_below_the_f32_floor() -> unit ! { Test } = {
  -- Phi(-13) is 6.1e-39 and representable; Phi(-15) is 3.7e-51, which no f32
  -- can hold, so 0.0 there is the correct answer and not the #137
  -- cancellation. Pinned so the boundary is not mistaken for the defect.
  _ = assert_true(gt(z_p_value_upper(cast(13.0, f32)), cast(0.0, f32)), "z_p_value_upper(13) is representable and nonzero")
  assert_true(eq(z_p_value_upper(cast(15.0, f32)), cast(0.0, f32)), "z_p_value_upper(15) underflows f32: 3.7e-51 is unrepresentable")
}
def test_t_p_upper_deep_tail_keeps_significant_digits() -> unit ! { Test } = {
  a = t_p_value_upper(cast(30.0, f32), cast(5.0, f32))
  b = t_p_value_upper(cast(100.0, f32), cast(5.0, f32))
  c = t_p_value_upper(cast(20.0, f32), cast(10.0, f32))
  d = t_p_value_upper(cast(8.0, f32), cast(30.0, f32))
  _ = assert_true(lt(pv_rel_err(a, cast(3.8593242e-7, f32)), cast(0.00001, f32)), "t_p_value_upper(30, 5) = 3.8593242e-7")
  _ = assert_true(lt(pv_rel_err(b, cast(9.480007e-10, f32)), cast(0.00001, f32)), "t_p_value_upper(100, 5) = 9.480007e-10")
  _ = assert_true(lt(pv_rel_err(c, cast(1.0730311e-9, f32)), cast(0.00001, f32)), "t_p_value_upper(20, 10) = 1.0730311e-9")
  assert_true(lt(pv_rel_err(d, cast(3.1329113e-9, f32)), cast(0.00001, f32)), "t_p_value_upper(8, 30) = 3.1329113e-9")
}
def test_t_p_two_sided_deep_tail_keeps_significant_digits() -> unit ! { Test } = {
  a = t_p_value_two_sided(cast(100.0, f32), cast(5.0, f32))
  b = t_p_value_two_sided(cast(-20.0, f32), cast(10.0, f32))
  _ = assert_true(lt(pv_rel_err(a, cast(1.8960014e-9, f32)), cast(0.00001, f32)), "t_p_value_two_sided(100, 5) = 1.8960014e-9")
  assert_true(lt(pv_rel_err(b, cast(2.1460622e-9, f32)), cast(0.00001, f32)), "t_p_value_two_sided(-20, 10) = 2.1460622e-9")
}
def test_t_p_tail_is_never_exactly_zero() -> unit ! { Test } = {
  -- Each of these returned exactly 0.0 under the cancelling form.
  _ = assert_true(gt(t_p_value_upper(cast(100.0, f32), cast(5.0, f32)), cast(0.0, f32)), "t_p_value_upper(100, 5) is strictly positive")
  _ = assert_true(gt(t_p_value_upper(cast(1000.0, f32), cast(5.0, f32)), cast(0.0, f32)), "t_p_value_upper(1000, 5) is strictly positive")
  _ = assert_true(gt(t_p_value_upper(cast(8.0, f32), cast(30.0, f32)), cast(0.0, f32)), "t_p_value_upper(8, 30) is strictly positive")
  assert_true(gt(t_p_value_two_sided(cast(100.0, f32), cast(5.0, f32)), cast(0.0, f32)), "t_p_value_two_sided(100, 5) is strictly positive")
}
def test_t_p_upper_strictly_decreasing_in_the_tail() -> unit ! { Test } = {
  df = cast(5.0, f32)
  p30 = t_p_value_upper(cast(30.0, f32), df)
  p100 = t_p_value_upper(cast(100.0, f32), df)
  p1000 = t_p_value_upper(cast(1000.0, f32), df)
  _ = assert_true(lt(p100, p30), "t upper p decreases: p(100) < p(30)")
  assert_true(lt(p1000, p100), "t upper p decreases: p(1000) < p(100)")
}
def test_chi2_p_deep_tail_keeps_significant_digits() -> unit ! { Test } = {
  -- A chi-squared statistic of 40 on 3 df is an ordinary goodness-of-fit
  -- result, and it is where the cancelling form first returned exactly 0.0:
  -- a far lower threshold for user-visible breakage than the z case.
  df3 = cast(3.0, f32)
  a = chi_squared_p_value(cast(40.0, f32), df3)
  b = chi_squared_p_value(cast(50.0, f32), df3)
  c = chi_squared_p_value(cast(100.0, f32), df3)
  d = chi_squared_p_value(cast(80.0, f32), cast(10.0, f32))
  e = chi_squared_p_value(cast(200.0, f32), cast(50.0, f32))
  _ = assert_true(lt(pv_rel_err(a, cast(1.065509e-8, f32)), cast(0.00001, f32)), "chi_squared_p_value(40, 3) = 1.065509e-8")
  _ = assert_true(lt(pv_rel_err(b, cast(7.9891795e-11, f32)), cast(0.00001, f32)), "chi_squared_p_value(50, 3) = 7.9891795e-11")
  _ = assert_true(lt(pv_rel_err(c, cast(1.5541595e-21, f32)), cast(0.00001, f32)), "chi_squared_p_value(100, 3) = 1.5541595e-21")
  _ = assert_true(lt(pv_rel_err(d, cast(5.0204643e-13, f32)), cast(0.00001, f32)), "chi_squared_p_value(80, 10) = 5.0204643e-13")
  assert_true(lt(pv_rel_err(e, cast(7.857611e-20, f32)), cast(0.00001, f32)), "chi_squared_p_value(200, 50) = 7.857611e-20")
}
def test_chi2_p_moderate_statistic_is_unchanged() -> unit ! { Test } = {
  -- The region the cancelling form did get right has to stay right: these
  -- two are on the `gammap` side of the branch, where the survival function
  -- is still `1 - P(a, x)` and no tail accuracy is at stake.
  df3 = cast(3.0, f32)
  a = chi_squared_p_value(cast(1.0, f32), df3)
  b = chi_squared_p_value(cast(5.0, f32), df3)
  c = chi_squared_p_value(cast(2.5, f32), cast(4.0, f32))
  _ = assert_true(lt(pv_rel_err(a, cast(0.80125195, f32)), cast(0.00001, f32)), "chi_squared_p_value(1, 3) = 0.80125195")
  _ = assert_true(lt(pv_rel_err(b, cast(0.17179714, f32)), cast(0.00001, f32)), "chi_squared_p_value(5, 3) = 0.17179714")
  assert_true(lt(pv_rel_err(c, cast(0.6446358, f32)), cast(0.00001, f32)), "chi_squared_p_value(2.5, 4) = 0.6446358")
}
def test_chi2_p_tail_is_never_exactly_zero_in_f32_range() -> unit ! { Test } = {
  df3 = cast(3.0, f32)
  _ = assert_true(gt(chi_squared_p_value(cast(40.0, f32), df3), cast(0.0, f32)), "chi_squared_p_value(40, 3) is strictly positive")
  _ = assert_true(gt(chi_squared_p_value(cast(100.0, f32), df3), cast(0.0, f32)), "chi_squared_p_value(100, 3) is strictly positive")
  assert_true(gt(chi_squared_p_value(cast(200.0, f32), cast(50.0, f32)), cast(0.0, f32)), "chi_squared_p_value(200, 50) is strictly positive")
}
def test_chi2_p_strictly_decreasing_in_the_tail() -> unit ! { Test } = {
  df = cast(3.0, f32)
  p40 = chi_squared_p_value(cast(40.0, f32), df)
  p50 = chi_squared_p_value(cast(50.0, f32), df)
  p100 = chi_squared_p_value(cast(100.0, f32), df)
  _ = assert_true(lt(p50, p40), "chi^2 p decreases: p(50) < p(40)")
  assert_true(lt(p100, p50), "chi^2 p decreases: p(100) < p(50)")
}
-- Q(1, 150) is 7.2e-66, unrepresentable in f32, so 0.0 is correct here for the
-- same range reason as z = 15 above, not for the #137 reason.
def test_chi2_p_underflows_only_below_the_f32_floor() -> unit ! { Test } = assert_true(eq(chi_squared_p_value(cast(300.0, f32), cast(2.0, f32)), cast(0.0, f32)), "chi_squared_p_value(300, 2) underflows f32: 7.2e-66 is unrepresentable")
def test_z_p_upper_lower_complement_in_the_tail() -> unit ! { Test } = {
  -- The pre-existing complement test uses z = 0.8, where both terms are O(1)
  -- and the identity is insensitive to the tail. At z = 6 the upper term is
  -- 1e-9, so this says the lower term is 1 and the upper is not lost -- the
  -- old spelling satisfied it by returning 0.0, which is why the sum alone
  -- is not enough and the relative tests above are the real contract.
  z = cast(6.0, f32)
  s = add(z_p_value_upper(z), z_p_value_lower(z))
  assert_close(s, cast(1.0, f32), cast(1e-6, f32), "z upper + lower p-values sum to 1 at z=6")
}
