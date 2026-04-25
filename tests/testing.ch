module Nautilus.Tests.Testing

-- Identity / structural tests for Nautilus.Testing
-- (the hypothesis-test module: z-test, t-test, chi^2, CI helpers).
-- All expected values are mathematical identities, exact constants,
-- or documented bounds. No scipy-derived numerics.

import Nautilus.Testing (
  z_statistic,
  z_p_value_two_sided,
  z_p_value_upper,
  z_p_value_lower,
  normal_ci_half_width,
  chi_squared_p_value,
  t_statistic_one_sample,
  t_statistic_two_sample_pooled,
  t_p_value_two_sided,
  t_p_value_upper,
  t_p_value_lower,
  welch_t_statistic,
  welch_t_df
)
import Std.Test (assert_close, assert_true)

-- ===== z_statistic =====

def test_zstat_no_deviation() -> unit ! { Test } =
  -- sample mean = pop mean -> z = 0 exactly
  assert_close(
    z_statistic(cast(5.0, f32), cast(5.0, f32),
                cast(2.0, f32), cast(30.0, f32)),
    cast(0.0, f32), cast(1.0e-7, f32),
    "z-stat is zero when sample mean = pop mean")

def test_zstat_one_standard_error() -> unit ! { Test } = {
  -- shift sample mean by exactly sigma/sqrt(n) -> z = 1
  -- pop_std = 2, n = 16  ->  se = 2/4 = 0.5
  -- sample_mean = mu + 0.5 -> z = 1
  z = z_statistic(cast(5.5, f32), cast(5.0, f32),
                  cast(2.0, f32), cast(16.0, f32))
  assert_close(z, cast(1.0, f32), cast(1.0e-6, f32),
               "z-stat = 1 when sample mean is one SE above pop mean")
}

def test_zstat_antisymmetric() -> unit ! { Test } = {
  -- z(mu - delta) = -z(mu + delta)
  zp = z_statistic(cast(5.5, f32), cast(5.0, f32),
                   cast(2.0, f32), cast(16.0, f32))
  zn = z_statistic(cast(4.5, f32), cast(5.0, f32),
                   cast(2.0, f32), cast(16.0, f32))
  assert_close(zn, neg(zp), cast(1.0e-6, f32),
               "z-stat is antisymmetric around the pop mean")
}

-- ===== t_statistic_one_sample =====

def test_tstat_one_sample_no_deviation() -> unit ! { Test } =
  -- sample mean = pop mean -> t = 0 exactly
  assert_close(
    t_statistic_one_sample(cast(7.0, f32), cast(1.5, f32),
                           cast(20.0, f32), cast(7.0, f32)),
    cast(0.0, f32), cast(1.0e-7, f32),
    "one-sample t = 0 when sample mean = pop mean")

def test_tstat_one_sample_one_se() -> unit ! { Test } = {
  -- sample_std = 4, n = 16 -> se = 4/4 = 1.0
  -- sample_mean - pop_mean = 1.0 -> t = 1
  t = t_statistic_one_sample(cast(8.0, f32), cast(4.0, f32),
                             cast(16.0, f32), cast(7.0, f32))
  assert_close(t, cast(1.0, f32), cast(1.0e-6, f32),
               "one-sample t = 1 at one standard error above pop mean")
}

-- ===== t_statistic_two_sample_pooled =====

def test_tstat_pooled_equal_means() -> unit ! { Test } =
  -- equal sample means -> t = 0
  assert_close(
    t_statistic_two_sample_pooled(
      cast(3.0, f32), cast(1.0, f32), cast(10.0, f32),
      cast(3.0, f32), cast(2.0, f32), cast(15.0, f32)),
    cast(0.0, f32), cast(1.0e-7, f32),
    "pooled two-sample t = 0 when sample means are equal")

-- ===== welch_t_statistic =====

def test_welch_t_equal_means() -> unit ! { Test } =
  -- two samples with the same mean -> welch t = 0
  assert_close(
    welch_t_statistic(
      cast(4.0, f32), cast(1.5, f32), cast(12.0, f32),
      cast(4.0, f32), cast(2.5, f32), cast(20.0, f32)),
    cast(0.0, f32), cast(1.0e-7, f32),
    "Welch t = 0 when sample means are equal")

def test_welch_t_identical_samples() -> unit ! { Test } =
  -- two identical samples (same mean, std, n) -> welch t = 0
  assert_close(
    welch_t_statistic(
      cast(2.7, f32), cast(0.9, f32), cast(25.0, f32),
      cast(2.7, f32), cast(0.9, f32), cast(25.0, f32)),
    cast(0.0, f32), cast(1.0e-7, f32),
    "Welch t = 0 for two identical samples")

def test_welch_t_antisymmetric() -> unit ! { Test } = {
  -- swapping the two samples flips the sign
  t12 = welch_t_statistic(
    cast(5.0, f32), cast(1.0, f32), cast(20.0, f32),
    cast(4.0, f32), cast(1.0, f32), cast(20.0, f32))
  t21 = welch_t_statistic(
    cast(4.0, f32), cast(1.0, f32), cast(20.0, f32),
    cast(5.0, f32), cast(1.0, f32), cast(20.0, f32))
  assert_close(t21, neg(t12), cast(1.0e-6, f32),
               "Welch t is antisymmetric in sample order")
}

-- ===== welch_t_df =====

def test_welch_df_symmetric_identical() -> unit ! { Test } = {
  -- For two identical samples (same std and n), Welch-Satterthwaite df
  -- collapses to 2*(n - 1).  std = 1, n = 11  ->  df = 20.
  df = welch_t_df(cast(1.0, f32), cast(11.0, f32),
                  cast(1.0, f32), cast(11.0, f32))
  assert_close(df, cast(20.0, f32), cast(1.0e-5, f32),
               "Welch df = 2*(n-1) for two identical samples")
}

-- ===== normal_ci_half_width =====

def test_ci_half_width_positive() -> unit ! { Test } = {
  -- half-width is strictly positive for any real confidence in (0, 1)
  hw = normal_ci_half_width(cast(0.95, f32), cast(2.0, f32),
                            cast(30.0, f32))
  assert_true(gt(hw, cast(0.0, f32)),
              "CI half-width is positive at 95% confidence")
}

def test_ci_half_width_grows_with_confidence() -> unit ! { Test } = {
  -- higher confidence -> wider interval
  hw90 = normal_ci_half_width(cast(0.90, f32), cast(2.0, f32),
                              cast(30.0, f32))
  hw99 = normal_ci_half_width(cast(0.99, f32), cast(2.0, f32),
                              cast(30.0, f32))
  assert_true(lt(hw90, hw99),
              "CI half-width grows with confidence level")
}

def test_ci_symmetric_around_mean() -> unit ! { Test } = {
  -- For sample_mean = 10 and a symmetric two-sided normal CI,
  -- (lo + hi) / 2 = sample_mean exactly (lo = mean - hw, hi = mean + hw).
  mean = cast(10.0, f32)
  hw = normal_ci_half_width(cast(0.95, f32), cast(2.0, f32),
                            cast(40.0, f32))
  lo = sub(mean, hw)
  hi = add(mean, hw)
  mid = mul(cast(0.5, f32), add(lo, hi))
  assert_close(mid, mean, cast(1.0e-6, f32),
               "CI is symmetric around the sample mean")
}

def test_ci_shrinks_with_n() -> unit ! { Test } = {
  -- half-width scales as 1/sqrt(n), so larger n -> narrower interval
  hw_small = normal_ci_half_width(cast(0.95, f32), cast(2.0, f32),
                                  cast(25.0, f32))
  hw_large = normal_ci_half_width(cast(0.95, f32), cast(2.0, f32),
                                  cast(100.0, f32))
  assert_true(lt(hw_large, hw_small),
              "CI half-width shrinks as sample size grows")
}

-- ===== z p-values =====

def test_z_p_two_sided_at_zero() -> unit ! { Test } =
  -- p-value at z = 0 is 1 (two-sided): 2 * (1 - Phi(0)) = 2 * 0.5 = 1
  assert_close(z_p_value_two_sided(cast(0.0, f32)),
               cast(1.0, f32), cast(1.0e-6, f32),
               "two-sided z p-value at z=0 is 1")

def test_z_p_upper_at_zero() -> unit ! { Test } =
  -- upper-tail p at z = 0 is 0.5 (median of standard normal)
  assert_close(z_p_value_upper(cast(0.0, f32)),
               cast(0.5, f32), cast(1.0e-6, f32),
               "upper-tail z p-value at z=0 is 0.5")

def test_z_p_lower_at_zero() -> unit ! { Test } =
  -- lower-tail p at z = 0 is 0.5
  assert_close(z_p_value_lower(cast(0.0, f32)),
               cast(0.5, f32), cast(1.0e-6, f32),
               "lower-tail z p-value at z=0 is 0.5")

def test_z_p_two_sided_monotone() -> unit ! { Test } = {
  -- two-sided p decreases as |z| increases
  p1 = z_p_value_two_sided(cast(0.5, f32))
  p2 = z_p_value_two_sided(cast(1.5, f32))
  p3 = z_p_value_two_sided(cast(2.5, f32))
  _ = assert_true(lt(p2, p1), "two-sided p decreases: p(1.5) < p(0.5)")
  assert_true(lt(p3, p2), "two-sided p decreases: p(2.5) < p(1.5)")
}

def test_z_p_two_sided_symmetric() -> unit ! { Test } = {
  -- two-sided p depends only on |z|: p(z) = p(-z)
  pp = z_p_value_two_sided(cast(1.7, f32))
  pn = z_p_value_two_sided(cast(-1.7, f32))
  assert_close(pp, pn, cast(1.0e-6, f32),
               "two-sided z p-value is symmetric in z")
}

def test_z_p_upper_lower_complement() -> unit ! { Test } = {
  -- upper(z) + lower(z) = 1
  z = cast(0.8, f32)
  s = add(z_p_value_upper(z), z_p_value_lower(z))
  assert_close(s, cast(1.0, f32), cast(1.0e-6, f32),
               "z upper + lower p-values sum to 1")
}

-- ===== t p-values =====

def test_t_p_two_sided_at_zero() -> unit ! { Test } =
  -- t = 0 -> two-sided p = 1 (Student-t is symmetric around 0)
  assert_close(t_p_value_two_sided(cast(0.0, f32), cast(10.0, f32)),
               cast(1.0, f32), cast(1.0e-6, f32),
               "two-sided t p-value at t=0 is 1")

def test_t_p_upper_at_zero() -> unit ! { Test } =
  -- upper-tail p at t = 0 is 0.5
  assert_close(t_p_value_upper(cast(0.0, f32), cast(10.0, f32)),
               cast(0.5, f32), cast(1.0e-6, f32),
               "upper-tail t p-value at t=0 is 0.5")

def test_t_p_lower_at_zero() -> unit ! { Test } =
  -- lower-tail p at t = 0 is 0.5
  assert_close(t_p_value_lower(cast(0.0, f32), cast(10.0, f32)),
               cast(0.5, f32), cast(1.0e-6, f32),
               "lower-tail t p-value at t=0 is 0.5")

def test_t_p_upper_lower_complement() -> unit ! { Test } = {
  -- upper(t, df) + lower(t, df) = 1
  t = cast(1.2, f32)
  df = cast(8.0, f32)
  s = add(t_p_value_upper(t, df), t_p_value_lower(t, df))
  assert_close(s, cast(1.0, f32), cast(1.0e-6, f32),
               "t upper + lower p-values sum to 1")
}

def test_t_p_two_sided_monotone() -> unit ! { Test } = {
  -- two-sided t p-value decreases as |t| increases (df fixed)
  df = cast(10.0, f32)
  p1 = t_p_value_two_sided(cast(0.5, f32), df)
  p2 = t_p_value_two_sided(cast(1.5, f32), df)
  p3 = t_p_value_two_sided(cast(3.0, f32), df)
  _ = assert_true(lt(p2, p1), "two-sided t p decreases: p(1.5) < p(0.5)")
  assert_true(lt(p3, p2), "two-sided t p decreases: p(3.0) < p(1.5)")
}

-- ===== chi-squared p-value =====

def test_chi2_p_at_zero_is_one() -> unit ! { Test } =
  -- chi^2 statistic = 0 -> no deviation -> upper-tail p = 1
  assert_close(chi_squared_p_value(cast(0.0, f32), cast(3.0, f32)),
               cast(1.0, f32), cast(1.0e-6, f32),
               "chi^2 p-value is 1 when statistic = 0")

def test_chi2_p_in_unit_interval() -> unit ! { Test } = {
  -- p-value lies in [0, 1]
  p = chi_squared_p_value(cast(2.5, f32), cast(4.0, f32))
  _ = assert_true(gte(p, cast(0.0, f32)), "chi^2 p-value >= 0")
  assert_true(lte(p, cast(1.0, f32)), "chi^2 p-value <= 1")
}

def test_chi2_p_decreases_with_statistic() -> unit ! { Test } = {
  -- with df fixed, larger statistic -> smaller upper-tail p
  df = cast(4.0, f32)
  p1 = chi_squared_p_value(cast(1.0, f32), df)
  p2 = chi_squared_p_value(cast(5.0, f32), df)
  p3 = chi_squared_p_value(cast(15.0, f32), df)
  _ = assert_true(lt(p2, p1), "chi^2 p decreases: p(5) < p(1)")
  assert_true(lt(p3, p2), "chi^2 p decreases: p(15) < p(5)")
}
