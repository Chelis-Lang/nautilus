module Nautilus.Tests.Distributions
import Nautilus.Distributions (normal_cdf_t, normal_inv_cdf_t, normal_pdf_t, uniform_pdf, uniform_cdf, uniform_inv_cdf, exponential_pdf, exponential_cdf, exponential_inv_cdf, normal_pdf, normal_cdf, normal_inv_cdf, lognormal_pdf, lognormal_cdf, lognormal_inv_cdf, gamma_pdf, gamma_cdf, gamma_inv_cdf, chi_squared_pdf, chi_squared_cdf, chi_squared_inv_cdf, student_t_pdf, student_t_cdf, poisson_pmf, poisson_cdf, binomial_pmf, binomial_cdf, beta_pdf, beta_cdf, f_pdf, f_cdf, weibull_pdf, weibull_cdf, weibull_inv_cdf)
import Std.Test (assert_close, assert_true)
def test_normal_pdf_at_mean_is_one_over_sqrt_2pi() -> unit ! { Test } = {
  v = normal_pdf(cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.3989422, f32), cast(0.00001, f32), "N(0;0,1) = 1/sqrt(2pi)")
}
def test_normal_pdf_symmetric_unit() -> unit ! { Test } = {
  l = normal_pdf(cast(0.5, f32), cast(0.0, f32), cast(1.0, f32))
  r = normal_pdf(cast(-0.5, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(l, r, cast(1e-7, f32), "N(0.5;0,1) = N(-0.5;0,1)")
}
def test_normal_pdf_symmetric_two() -> unit ! { Test } = {
  l = normal_pdf(cast(2.3, f32), cast(0.0, f32), cast(1.0, f32))
  r = normal_pdf(cast(-2.3, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(l, r, cast(1e-7, f32), "N(2.3;0,1) = N(-2.3;0,1)")
}
def test_normal_pdf_symmetric_about_nonzero_mean() -> unit ! { Test } = {
  l = normal_pdf(cast(3.7, f32), cast(2.0, f32), cast(1.5, f32))
  r = normal_pdf(cast(0.3, f32), cast(2.0, f32), cast(1.5, f32))
  assert_close(l, r, cast(1e-6, f32), "N(mu+d) = N(mu-d)")
}
def test_normal_cdf_at_mean_is_half() -> unit ! { Test } = {
  v = normal_cdf(cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.5, f32), cast(0.00001, f32), "N_cdf(0;0,1) = 0.5")
}
def test_normal_cdf_at_nonzero_mean_is_half() -> unit ! { Test } = {
  v = normal_cdf(cast(7.5, f32), cast(7.5, f32), cast(2.0, f32))
  assert_close(v, cast(0.5, f32), cast(0.00001, f32), "N_cdf(mu;mu,sigma) = 0.5")
}
-- nautilus#113: the deep left tail needs a *relative* contract. The previous
-- `0.5 * (1 + erf(z))` spelling carried absolute error of about
-- `0.5 * ulp(1.0)` however accurate `erf` was, so it returned exactly `0.0`
-- below about `-6`, and an absolute tolerance near zero could not tell that
-- apart from the true value. Every reference below is `Phi` at 40 decimal
-- digits, rounded once to f32.
def dist_rel_err(v: f32, ref: f32) -> f32 = div(abs(sub(v, ref)), ref)
def test_normal_cdf_far_left_is_tiny_and_not_zero() -> unit ! { Test } = {
  v = normal_cdf(cast(-10.0, f32), cast(0.0, f32), cast(1.0, f32))
  _ = assert_true(gt(v, cast(0.0, f32)), "N_cdf(-10;0,1) is strictly positive")
  assert_true(lt(dist_rel_err(v, cast(7.6198528e-24, f32)), cast(0.00001, f32)), "N_cdf(-10;0,1) = 7.6198528e-24")
}
def test_normal_cdf_deep_tail_keeps_significant_digits() -> unit ! { Test } = {
  -- Each of these returned exactly zero under the cancelling form. Every
  -- reference is Phi at the *f32* argument the function receives, not at the
  -- decimal literal: f32(-12.6) is -12.600000381469727, and Phi there differs
  -- from Phi(-12.6) by 57 ulp, which is 5e-6 relative and would eat half this
  -- test's margin.
  a = normal_cdf(cast(-6.0, f32), cast(0.0, f32), cast(1.0, f32))
  b = normal_cdf(cast(-8.0, f32), cast(0.0, f32), cast(1.0, f32))
  c = normal_cdf(cast(-12.6, f32), cast(0.0, f32), cast(1.0, f32))
  _ = assert_true(lt(dist_rel_err(a, cast(9.865877e-10, f32)), cast(0.00001, f32)), "N_cdf(-6;0,1) = 9.865877e-10")
  _ = assert_true(lt(dist_rel_err(b, cast(6.2209604e-16, f32)), cast(0.00001, f32)), "N_cdf(-8;0,1) = 6.2209604e-16")
  assert_true(lt(dist_rel_err(c, cast(1.0557175e-36, f32)), cast(0.00001, f32)), "N_cdf(-12.6;0,1) = 1.0557175e-36")
}
def test_normal_cdf_shifted_tail_is_accurate_within_the_quotient_bound() -> unit ! { Test } = {
  -- A shifted and scaled call rounds `(x-mean)/std` before `Phi` sees it, and
  -- that error is amplified by about `w^2` in the tail, so this lane holds a
  -- looser bound than the standardized one above. It is still about five
  -- orders of magnitude tighter than the cancelling form, which returned zero.
  v = normal_cdf(cast(-13.8, f32), cast(0.2, f32), cast(1.4, f32))
  _ = assert_true(gt(v, cast(0.0, f32)), "shifted N_cdf tail is strictly positive")
  assert_true(lt(dist_rel_err(v, cast(7.6198292e-24, f32)), cast(0.0001, f32)), "N_cdf(-13.8;0.2,1.4) = 7.6198292e-24")
}
def test_normal_cdf_far_right_is_one() -> unit ! { Test } = {
  v = normal_cdf(cast(10.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(0.00001, f32), "N_cdf(+10;0,1) = 1")
}
def test_normal_cdf_monotone() -> unit ! { Test } = {
  a = normal_cdf(cast(-1.0, f32), cast(0.0, f32), cast(1.0, f32))
  b = normal_cdf(cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  c = normal_cdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  _ = assert_true(lt(a, b), "N_cdf monotone: -1 < 0")
  assert_true(lt(b, c), "N_cdf monotone: 0 < 1")
}
def test_normal_cdf_symmetry_sum_unit() -> unit ! { Test } = {
  a = normal_cdf(cast(1.3, f32), cast(0.0, f32), cast(1.0, f32))
  b = normal_cdf(cast(-1.3, f32), cast(0.0, f32), cast(1.0, f32))
  s = add(a, b)
  assert_close(s, cast(1.0, f32), cast(0.00001, f32), "Phi(x) + Phi(-x) = 1")
}
def test_normal_inv_cdf_median_round_trip() -> unit ! { Test } = {
  v = normal_inv_cdf(cast(0.5, f32), cast(2.5, f32), cast(1.5, f32))
  assert_close(v, cast(2.5, f32), cast(0.00001, f32), "inv_cdf(0.5;mu,s) = mu")
}
def test_normal_inv_cdf_round_trip_x() -> unit ! { Test } = {
  x = cast(1.2, f32)
  q = normal_cdf(x, cast(0.0, f32), cast(1.0, f32))
  back = normal_inv_cdf(q, cast(0.0, f32), cast(1.0, f32))
  assert_close(back, x, cast(0.001, f32), "inv_cdf(cdf(x)) = x")
}
def test_normal_inv_cdf_round_trip_neg_x() -> unit ! { Test } = {
  x = cast(-0.7, f32)
  q = normal_cdf(x, cast(0.0, f32), cast(1.0, f32))
  back = normal_inv_cdf(q, cast(0.0, f32), cast(1.0, f32))
  assert_close(back, x, cast(0.001, f32), "inv_cdf(cdf(-0.7)) = -0.7")
}
def test_normal_pdf_scale_invariance() -> unit ! { Test } = {
  v = normal_pdf(cast(3.0, f32), cast(2.0, f32), cast(1.0, f32))
  ref = normal_pdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, ref, cast(1e-6, f32), "N(mu+s;mu,s) = N(1;0,1) when s=1")
}
def test_uniform_pdf_unit_density() -> unit ! { Test } = {
  v = uniform_pdf(cast(0.5, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "U(0,1) pdf = 1")
}
def test_uniform_pdf_constant_density() -> unit ! { Test } = {
  a = uniform_pdf(cast(3.0, f32), cast(2.0, f32), cast(7.0, f32))
  b = uniform_pdf(cast(5.5, f32), cast(2.0, f32), cast(7.0, f32))
  _ = assert_close(a, cast(0.2, f32), cast(1e-7, f32), "U(2,7) pdf at 3 = 0.2")
  _ = assert_close(b, cast(0.2, f32), cast(1e-7, f32), "U(2,7) pdf at 5.5 = 0.2")
  assert_close(a, b, cast(1e-7, f32), "U(2,7) pdf is constant in support")
}
def test_uniform_pdf_outside_support_below() -> unit ! { Test } = {
  v = uniform_pdf(cast(-1.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "U pdf below = 0")
}
def test_uniform_pdf_outside_support_above() -> unit ! { Test } = {
  v = uniform_pdf(cast(2.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "U pdf above = 0")
}
def test_uniform_cdf_at_lower_bound() -> unit ! { Test } = {
  v = uniform_cdf(cast(2.0, f32), cast(2.0, f32), cast(7.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "U_cdf(a;a,b) = 0")
}
def test_uniform_cdf_at_upper_bound() -> unit ! { Test } = {
  v = uniform_cdf(cast(7.0, f32), cast(2.0, f32), cast(7.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "U_cdf(b;a,b) = 1")
}
def test_uniform_cdf_at_midpoint_is_half() -> unit ! { Test } = {
  v = uniform_cdf(cast(5.0, f32), cast(2.0, f32), cast(8.0, f32))
  assert_close(v, cast(0.5, f32), cast(1e-7, f32), "U_cdf((a+b)/2) = 0.5")
}
def test_uniform_cdf_below_support_zero() -> unit ! { Test } = {
  v = uniform_cdf(cast(-5.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "U_cdf below = 0")
}
def test_uniform_cdf_above_support_one() -> unit ! { Test } = {
  v = uniform_cdf(cast(5.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "U_cdf above = 1")
}
def test_uniform_inv_cdf_round_trip() -> unit ! { Test } = {
  q = cast(0.3, f32)
  x = uniform_inv_cdf(q, cast(2.0, f32), cast(8.0, f32))
  back = uniform_cdf(x, cast(2.0, f32), cast(8.0, f32))
  assert_close(back, q, cast(1e-6, f32), "U inv_cdf round-trip")
}
def test_exponential_pdf_at_zero_is_rate() -> unit ! { Test } = {
  v = exponential_pdf(cast(0.0, f32), cast(2.5, f32))
  assert_close(v, cast(2.5, f32), cast(1e-6, f32), "Exp pdf at 0 = rate")
}
def test_exponential_pdf_at_zero_unit_rate() -> unit ! { Test } = {
  v = exponential_pdf(cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "Exp(1) pdf at 0 = 1")
}
def test_exponential_pdf_below_zero() -> unit ! { Test } = {
  v = exponential_pdf(cast(-1.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Exp pdf below 0 = 0")
}
def test_exponential_cdf_at_zero() -> unit ! { Test } = {
  v = exponential_cdf(cast(0.0, f32), cast(1.5, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Exp_cdf(0) = 0")
}
def test_exponential_cdf_far_right() -> unit ! { Test } = {
  v = exponential_cdf(cast(50.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-6, f32), "Exp_cdf(large) = 1")
}
def test_exponential_cdf_monotone() -> unit ! { Test } = {
  a = exponential_cdf(cast(0.5, f32), cast(1.0, f32))
  b = exponential_cdf(cast(1.0, f32), cast(1.0, f32))
  c = exponential_cdf(cast(2.0, f32), cast(1.0, f32))
  _ = assert_true(lt(a, b), "Exp_cdf monotone a<b")
  assert_true(lt(b, c), "Exp_cdf monotone b<c")
}
def test_exponential_inv_cdf_round_trip() -> unit ! { Test } = {
  x = cast(1.5, f32)
  q = exponential_cdf(x, cast(2.0, f32))
  back = exponential_inv_cdf(q, cast(2.0, f32))
  assert_close(back, x, cast(0.0001, f32), "Exp inv_cdf round-trip")
}
def test_exponential_inv_cdf_at_zero() -> unit ! { Test } = {
  v = exponential_inv_cdf(cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Exp inv_cdf(0) = 0")
}
def test_lognormal_pdf_positive_for_positive_x() -> unit ! { Test } = {
  v = lognormal_pdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_true(gt(v, cast(0.0, f32)), "LogN pdf(1;0,1) > 0")
}
def test_lognormal_pdf_at_zero_is_zero() -> unit ! { Test } = {
  v = lognormal_pdf(cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "LogN pdf(0) = 0")
}
def test_lognormal_pdf_below_zero_is_zero() -> unit ! { Test } = {
  v = lognormal_pdf(cast(-1.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "LogN pdf(-1) = 0")
}
def test_lognormal_cdf_at_zero_is_zero() -> unit ! { Test } = {
  v = lognormal_cdf(cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "LogN cdf(0) = 0")
}
def test_lognormal_cdf_at_one_is_half() -> unit ! { Test } = {
  v = lognormal_cdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.5, f32), cast(0.00001, f32), "LogN cdf(1;0,1) = 0.5")
}
def test_lognormal_inv_cdf_round_trip() -> unit ! { Test } = {
  x = cast(2.5, f32)
  q = lognormal_cdf(x, cast(0.0, f32), cast(1.0, f32))
  back = lognormal_inv_cdf(q, cast(0.0, f32), cast(1.0, f32))
  assert_close(back, x, cast(0.01, f32), "LogN inv_cdf round-trip")
}
def test_gamma_pdf_at_zero_with_shape_gt_one() -> unit ! { Test } = {
  v = gamma_pdf(cast(0.0, f32), cast(2.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Gamma pdf(0;2,1) = 0")
}
def test_gamma_cdf_at_zero() -> unit ! { Test } = {
  v = gamma_cdf(cast(0.0, f32), cast(2.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Gamma cdf(0) = 0")
}
def test_gamma_cdf_far_right() -> unit ! { Test } = {
  v = gamma_cdf(cast(60.0, f32), cast(2.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(0.00001, f32), "Gamma cdf(large) = 1")
}
def test_gamma_shape_one_reduces_to_exponential() -> unit ! { Test } = {
  scale = cast(2.0, f32)
  rate = div(cast(1.0, f32), scale)
  x = cast(1.3, f32)
  g = gamma_pdf(x, cast(1.0, f32), scale)
  e = exponential_pdf(x, rate)
  assert_close(g, e, cast(0.00001, f32), "Gamma(1,s) pdf = Exp(1/s) pdf")
}
def test_gamma_shape_one_reduces_to_exponential_x2() -> unit ! { Test } = {
  scale = cast(0.5, f32)
  rate = div(cast(1.0, f32), scale)
  x = cast(0.8, f32)
  g = gamma_pdf(x, cast(1.0, f32), scale)
  e = exponential_pdf(x, rate)
  assert_close(g, e, cast(0.00001, f32), "Gamma(1,0.5) pdf = Exp(2) pdf")
}
def test_gamma_cdf_shape_one_reduces_to_exp_cdf() -> unit ! { Test } = {
  scale = cast(2.0, f32)
  rate = div(cast(1.0, f32), scale)
  x = cast(1.7, f32)
  g = gamma_cdf(x, cast(1.0, f32), scale)
  e = exponential_cdf(x, rate)
  assert_close(g, e, cast(0.0001, f32), "Gamma_cdf(1,s) = Exp_cdf(1/s)")
}
def test_gamma_cdf_monotone() -> unit ! { Test } = {
  a = gamma_cdf(cast(0.5, f32), cast(2.0, f32), cast(1.0, f32))
  b = gamma_cdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))
  c = gamma_cdf(cast(5.0, f32), cast(2.0, f32), cast(1.0, f32))
  _ = assert_true(lt(a, b), "Gamma_cdf monotone a<b")
  assert_true(lt(b, c), "Gamma_cdf monotone b<c")
}
def test_chi2_pdf_at_zero_with_k_gt_two() -> unit ! { Test } = {
  v = chi_squared_pdf(cast(0.0, f32), cast(4.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Chi2 pdf(0;4) = 0")
}
def test_chi2_cdf_at_zero() -> unit ! { Test } = {
  v = chi_squared_cdf(cast(0.0, f32), cast(3.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Chi2 cdf(0;3) = 0")
}
def test_chi2_k2_reduces_to_exponential_pdf() -> unit ! { Test } = {
  x = cast(1.5, f32)
  c = chi_squared_pdf(x, cast(2.0, f32))
  e = exponential_pdf(x, cast(0.5, f32))
  assert_close(c, e, cast(0.00001, f32), "Chi2(k=2) pdf = Exp(0.5) pdf")
}
def test_chi2_k2_reduces_to_exponential_cdf() -> unit ! { Test } = {
  x = cast(2.7, f32)
  c = chi_squared_cdf(x, cast(2.0, f32))
  e = exponential_cdf(x, cast(0.5, f32))
  assert_close(c, e, cast(0.0001, f32), "Chi2(k=2) cdf = Exp(0.5) cdf")
}
def test_chi2_cdf_far_right() -> unit ! { Test } = {
  v = chi_squared_cdf(cast(100.0, f32), cast(3.0, f32))
  assert_close(v, cast(1.0, f32), cast(0.00001, f32), "Chi2 cdf(large;3) = 1")
}
def test_student_t_pdf_symmetric() -> unit ! { Test } = {
  l = student_t_pdf(cast(0.6, f32), cast(5.0, f32))
  r = student_t_pdf(cast(-0.6, f32), cast(5.0, f32))
  assert_close(l, r, cast(1e-6, f32), "t pdf symmetric about 0")
}
def test_student_t_pdf_symmetric_df1() -> unit ! { Test } = {
  l = student_t_pdf(cast(2.0, f32), cast(1.0, f32))
  r = student_t_pdf(cast(-2.0, f32), cast(1.0, f32))
  assert_close(l, r, cast(1e-6, f32), "t(df=1) pdf symmetric")
}
def test_student_t_cdf_at_zero_is_half() -> unit ! { Test } = {
  v = student_t_cdf(cast(0.0, f32), cast(5.0, f32))
  assert_close(v, cast(0.5, f32), cast(0.00001, f32), "t_cdf(0;5) = 0.5")
}
def test_student_t_cdf_at_zero_df1_is_half() -> unit ! { Test } = {
  v = student_t_cdf(cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.5, f32), cast(0.00001, f32), "t_cdf(0;1) = 0.5")
}
def test_student_t_cdf_symmetry_sum_unit() -> unit ! { Test } = {
  a = student_t_cdf(cast(0.7, f32), cast(5.0, f32))
  b = student_t_cdf(cast(-0.7, f32), cast(5.0, f32))
  s = add(a, b)
  assert_close(s, cast(1.0, f32), cast(0.00001, f32), "t_cdf(x) + t_cdf(-x) = 1")
}
def test_student_t_approaches_normal_high_df() -> unit ! { Test } = {
  t_v = student_t_pdf(cast(0.5, f32), cast(1000.0, f32))
  n_v = normal_pdf(cast(0.5, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(t_v, n_v, cast(0.01, f32), "t(df=1000) pdf ~ N(0,1) pdf")
}
def test_student_t_approaches_normal_high_df_at_one() -> unit ! { Test } = {
  t_v = student_t_pdf(cast(1.0, f32), cast(1000.0, f32))
  n_v = normal_pdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(t_v, n_v, cast(0.01, f32), "t(df=1000) pdf at 1 ~ N(0,1)")
}
def test_poisson_pmf_at_zero_is_exp_neg_lambda() -> unit ! { Test } = {
  lam = cast(2.0, f32)
  v = poisson_pmf(cast(0.0, f32), lam)
  expected = exp(neg(lam))
  assert_close(v, expected, cast(1e-6, f32), "P(0;lam) = exp(-lam)")
}
def test_poisson_pmf_at_zero_lambda_one() -> unit ! { Test } = {
  v = poisson_pmf(cast(0.0, f32), cast(1.0, f32))
  expected = exp(neg(cast(1.0, f32)))
  assert_close(v, expected, cast(1e-6, f32), "P(0;1) = 1/e")
}
def test_poisson_pmf_at_zero_lambda_three() -> unit ! { Test } = {
  v = poisson_pmf(cast(0.0, f32), cast(3.0, f32))
  expected = exp(neg(cast(3.0, f32)))
  assert_close(v, expected, cast(1e-6, f32), "P(0;3) = exp(-3)")
}
def test_poisson_pmf_sum_equals_cdf() -> unit ! { Test } = {
  lam = cast(2.0, f32)
  s = add(add(add(poisson_pmf(cast(0.0, f32), lam), poisson_pmf(cast(1.0, f32), lam)), poisson_pmf(cast(2.0, f32), lam)), poisson_pmf(cast(3.0, f32), lam))
  c = poisson_cdf(cast(3.0, f32), lam)
  assert_close(s, c, cast(0.001, f32), "sum_{k=0..3} P(k) = cdf(3)")
}
def test_poisson_pmf_sum_equals_cdf_lambda_one() -> unit ! { Test } = {
  lam = cast(1.0, f32)
  s = add(add(poisson_pmf(cast(0.0, f32), lam), poisson_pmf(cast(1.0, f32), lam)), poisson_pmf(cast(2.0, f32), lam))
  c = poisson_cdf(cast(2.0, f32), lam)
  assert_close(s, c, cast(0.001, f32), "sum_{k=0..2} P(k;1) = cdf(2;1)")
}
def test_poisson_pmf_lambda_zero_at_zero() -> unit ! { Test } = {
  v = poisson_pmf(cast(0.0, f32), cast(0.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "P(0;0) = 1 (degenerate)")
}
def test_poisson_pmf_lambda_zero_at_one() -> unit ! { Test } = {
  v = poisson_pmf(cast(1.0, f32), cast(0.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "P(1;0) = 0 (degenerate)")
}
def test_poisson_cdf_monotone() -> unit ! { Test } = {
  a = poisson_cdf(cast(0.0, f32), cast(2.0, f32))
  b = poisson_cdf(cast(2.0, f32), cast(2.0, f32))
  c = poisson_cdf(cast(5.0, f32), cast(2.0, f32))
  _ = assert_true(lt(a, b), "Poisson cdf monotone a<b")
  assert_true(lt(b, c), "Poisson cdf monotone b<c")
}
def test_binomial_pmf_p_zero_at_zero() -> unit ! { Test } = {
  v = binomial_pmf(cast(0.0, f32), cast(5.0, f32), cast(0.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "Bin(0;n,0) = 1")
}
def test_binomial_pmf_p_zero_at_one() -> unit ! { Test } = {
  v = binomial_pmf(cast(1.0, f32), cast(5.0, f32), cast(0.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Bin(1;n,0) = 0")
}
def test_binomial_pmf_p_one_at_n() -> unit ! { Test } = {
  v = binomial_pmf(cast(5.0, f32), cast(5.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "Bin(n;n,1) = 1")
}
def test_binomial_pmf_p_one_at_zero() -> unit ! { Test } = {
  v = binomial_pmf(cast(0.0, f32), cast(5.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Bin(0;n,1) = 0")
}
def test_binomial_pmf_zero_successes_equals_one_minus_p_pow_n() -> unit ! { Test } = {
  n = cast(4.0, f32)
  p = cast(0.3, f32)
  one_minus_p = sub(cast(1.0, f32), p)
  sq = mul(one_minus_p, one_minus_p)
  expected = mul(sq, sq)
  v = binomial_pmf(cast(0.0, f32), n, p)
  assert_close(v, expected, cast(0.00001, f32), "Bin(0;n,p) = (1-p)^n")
}
def test_binomial_pmf_zero_successes_n3() -> unit ! { Test } = {
  p = cast(0.4, f32)
  q = sub(cast(1.0, f32), p)
  expected = mul(q, mul(q, q))
  v = binomial_pmf(cast(0.0, f32), cast(3.0, f32), p)
  assert_close(v, expected, cast(0.00001, f32), "Bin(0;3,0.4) = 0.6^3")
}
def test_binomial_pmf_symmetric_p_half_k1() -> unit ! { Test } = {
  l = binomial_pmf(cast(1.0, f32), cast(5.0, f32), cast(0.5, f32))
  r = binomial_pmf(cast(4.0, f32), cast(5.0, f32), cast(0.5, f32))
  assert_close(l, r, cast(1e-6, f32), "Bin(1;5,0.5) = Bin(4;5,0.5)")
}
def test_binomial_pmf_symmetric_p_half_k2() -> unit ! { Test } = {
  l = binomial_pmf(cast(2.0, f32), cast(6.0, f32), cast(0.5, f32))
  r = binomial_pmf(cast(4.0, f32), cast(6.0, f32), cast(0.5, f32))
  assert_close(l, r, cast(1e-6, f32), "Bin(2;6,0.5) = Bin(4;6,0.5)")
}
def test_binomial_pmf_symmetric_p_half_k0() -> unit ! { Test } = {
  l = binomial_pmf(cast(0.0, f32), cast(5.0, f32), cast(0.5, f32))
  r = binomial_pmf(cast(5.0, f32), cast(5.0, f32), cast(0.5, f32))
  assert_close(l, r, cast(1e-6, f32), "Bin(0;5,0.5) = Bin(5;5,0.5)")
}
def test_binomial_cdf_at_n_is_one() -> unit ! { Test } = {
  v = binomial_cdf(cast(5.0, f32), cast(5.0, f32), cast(0.4, f32))
  assert_close(v, cast(1.0, f32), cast(1e-6, f32), "Bin_cdf(n;n,p) = 1")
}
def test_beta_pdf_uniform_at_half() -> unit ! { Test } = {
  v = beta_pdf(cast(0.5, f32), cast(1.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-6, f32), "Beta(1,1) pdf at 0.5 = 1")
}
def test_beta_pdf_uniform_at_quarter() -> unit ! { Test } = {
  v = beta_pdf(cast(0.25, f32), cast(1.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-6, f32), "Beta(1,1) pdf at 0.25 = 1")
}
def test_beta_pdf_uniform_at_three_quarter() -> unit ! { Test } = {
  v = beta_pdf(cast(0.75, f32), cast(1.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-6, f32), "Beta(1,1) pdf at 0.75 = 1")
}
def test_beta_pdf_symmetry() -> unit ! { Test } = {
  l = beta_pdf(cast(0.3, f32), cast(2.0, f32), cast(5.0, f32))
  r = beta_pdf(cast(0.7, f32), cast(5.0, f32), cast(2.0, f32))
  assert_close(l, r, cast(0.00001, f32), "Beta(a,b)(x) = Beta(b,a)(1-x)")
}
def test_beta_pdf_symmetry_two() -> unit ! { Test } = {
  l = beta_pdf(cast(0.2, f32), cast(3.0, f32), cast(4.0, f32))
  r = beta_pdf(cast(0.8, f32), cast(4.0, f32), cast(3.0, f32))
  assert_close(l, r, cast(0.00001, f32), "Beta(3,4)(0.2) = Beta(4,3)(0.8)")
}
def test_beta_cdf_at_zero() -> unit ! { Test } = {
  v = beta_cdf(cast(0.0, f32), cast(2.0, f32), cast(3.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Beta_cdf(0) = 0")
}
def test_beta_cdf_at_one() -> unit ! { Test } = {
  v = beta_cdf(cast(1.0, f32), cast(2.0, f32), cast(3.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-6, f32), "Beta_cdf(1) = 1")
}
def test_beta_cdf_symmetry() -> unit ! { Test } = {
  a = beta_cdf(cast(0.4, f32), cast(2.0, f32), cast(3.0, f32))
  b = beta_cdf(cast(0.6, f32), cast(3.0, f32), cast(2.0, f32))
  s = add(a, b)
  assert_close(s, cast(1.0, f32), cast(0.00001, f32), "Beta(a,b)_cdf(x) + Beta(b,a)_cdf(1-x) = 1")
}
def test_f_pdf_nonnegative() -> unit ! { Test } = {
  v = f_pdf(cast(1.0, f32), cast(5.0, f32), cast(10.0, f32))
  assert_true(gte(v, cast(0.0, f32)), "F pdf(1;5,10) >= 0")
}
def test_f_pdf_nonnegative_two() -> unit ! { Test } = {
  v = f_pdf(cast(2.5, f32), cast(3.0, f32), cast(8.0, f32))
  assert_true(gte(v, cast(0.0, f32)), "F pdf(2.5;3,8) >= 0")
}
def test_f_pdf_at_zero() -> unit ! { Test } = {
  v = f_pdf(cast(0.0, f32), cast(5.0, f32), cast(10.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "F pdf(0;5,10) = 0")
}
def test_f_cdf_at_zero() -> unit ! { Test } = {
  v = f_cdf(cast(0.0, f32), cast(5.0, f32), cast(10.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "F cdf(0;5,10) = 0")
}
def test_f_cdf_far_right() -> unit ! { Test } = {
  v = f_cdf(cast(1000.0, f32), cast(5.0, f32), cast(10.0, f32))
  assert_close(v, cast(1.0, f32), cast(0.001, f32), "F cdf(large;5,10) = 1")
}
def test_f_cdf_monotone() -> unit ! { Test } = {
  a = f_cdf(cast(0.5, f32), cast(5.0, f32), cast(10.0, f32))
  b = f_cdf(cast(1.0, f32), cast(5.0, f32), cast(10.0, f32))
  c = f_cdf(cast(2.0, f32), cast(5.0, f32), cast(10.0, f32))
  _ = assert_true(lt(a, b), "F cdf monotone a<b")
  assert_true(lt(b, c), "F cdf monotone b<c")
}
def test_weibull_pdf_at_zero_shape_gt_one() -> unit ! { Test } = {
  v = weibull_pdf(cast(0.0, f32), cast(2.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Weibull pdf(0;k>1) = 0")
}
def test_weibull_cdf_at_scale_is_one_minus_one_over_e() -> unit ! { Test } = {
  v = weibull_cdf(cast(2.5, f32), cast(1.0, f32), cast(2.5, f32))
  assert_close(v, cast(0.6321205, f32), cast(0.00001, f32), "W_cdf(s;1,s) = 1 - 1/e")
}
def test_weibull_cdf_at_scale_shape_two() -> unit ! { Test } = {
  v = weibull_cdf(cast(3.0, f32), cast(2.0, f32), cast(3.0, f32))
  assert_close(v, cast(0.6321205, f32), cast(0.00001, f32), "W_cdf(s;k,s) = 1 - 1/e for any k")
}
def test_weibull_cdf_at_zero() -> unit ! { Test } = {
  v = weibull_cdf(cast(0.0, f32), cast(2.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "W_cdf(0) = 0")
}
def test_weibull_cdf_far_right() -> unit ! { Test } = {
  v = weibull_cdf(cast(50.0, f32), cast(2.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-6, f32), "W_cdf(large) = 1")
}
def test_weibull_inv_cdf_round_trip() -> unit ! { Test } = {
  x = cast(1.5, f32)
  q = weibull_cdf(x, cast(2.0, f32), cast(1.0, f32))
  back = weibull_inv_cdf(q, cast(2.0, f32), cast(1.0, f32))
  assert_close(back, x, cast(0.001, f32), "W inv_cdf round-trip")
}
def test_weibull_inv_cdf_round_trip_diff_scale() -> unit ! { Test } = {
  x = cast(2.2, f32)
  q = weibull_cdf(x, cast(1.5, f32), cast(2.0, f32))
  back = weibull_inv_cdf(q, cast(1.5, f32), cast(2.0, f32))
  assert_close(back, x, cast(0.001, f32), "W inv_cdf round-trip (k=1.5,s=2)")
}
def test_weibull_shape_one_reduces_to_exponential_pdf() -> unit ! { Test } = {
  scale = cast(2.0, f32)
  rate = div(cast(1.0, f32), scale)
  x = cast(1.3, f32)
  w = weibull_pdf(x, cast(1.0, f32), scale)
  e = exponential_pdf(x, rate)
  assert_close(w, e, cast(0.00001, f32), "W(1,s) pdf = Exp(1/s) pdf")
}
def test_weibull_cdf_monotone() -> unit ! { Test } = {
  a = weibull_cdf(cast(0.5, f32), cast(2.0, f32), cast(1.0, f32))
  b = weibull_cdf(cast(1.0, f32), cast(2.0, f32), cast(1.0, f32))
  c = weibull_cdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))
  _ = assert_true(lt(a, b), "W cdf monotone a<b")
  assert_true(lt(b, c), "W cdf monotone b<c")
}
def test_gamma_inv_cdf_roundtrip() -> unit ! { Test } = {
  shape = cast(2.0, f32)
  scale = cast(1.5, f32)
  p = cast(0.4, f32)
  x = gamma_inv_cdf(p, shape, scale)
  q = gamma_cdf(x, shape, scale)
  assert_close(q, p, cast(0.001, f32), "gamma cdf(inv_cdf(p)) = p")
}
def test_gamma_inv_cdf_roundtrip_high_p() -> unit ! { Test } = {
  shape = cast(2.0, f32)
  scale = cast(1.5, f32)
  p = cast(0.95, f32)
  x = gamma_inv_cdf(p, shape, scale)
  q = gamma_cdf(x, shape, scale)
  assert_close(q, p, cast(0.001, f32), "gamma cdf(inv_cdf(0.95)) = 0.95")
}
def test_chi_squared_inv_cdf_roundtrip() -> unit ! { Test } = {
  df = cast(4.0, f32)
  p = cast(0.4, f32)
  x = chi_squared_inv_cdf(p, df)
  q = chi_squared_cdf(x, df)
  assert_close(q, p, cast(0.001, f32), "chi^2 cdf(inv_cdf(p)) = p")
}
def test_chi_squared_inv_cdf_roundtrip_low_p() -> unit ! { Test } = {
  df = cast(4.0, f32)
  p = cast(0.05, f32)
  x = chi_squared_inv_cdf(p, df)
  q = chi_squared_cdf(x, df)
  assert_close(q, p, cast(0.001, f32), "chi^2 cdf(inv_cdf(0.05)) = 0.05")
}
-- nautilus#45: tensor-domain normal family. The contract is elementwise
-- agreement with the scalar reference, including the guard behaviour.
def dist_probe_xs() -> tensor[4, f32] = to_tensor([cast(-2.5, f32), cast(-0.3, f32), cast(0.0, f32), cast(1.7, f32)])
def test_normal_cdf_t_matches_scalar_elementwise() -> unit ! { Test } = {
  mean = cast(0.2, f32)
  std = cast(1.4, f32)
  ys = to_list(normal_cdf_t(dist_probe_xs(), mean, std))
  tol = cast(1e-9, f32)
  _ = assert_close(index(ys, cast(0, i64)), normal_cdf(cast(-2.5, f32), mean, std), tol, "normal_cdf_t[0]")
  _ = assert_close(index(ys, cast(1, i64)), normal_cdf(cast(-0.3, f32), mean, std), tol, "normal_cdf_t[1]")
  _ = assert_close(index(ys, cast(2, i64)), normal_cdf(cast(0.0, f32), mean, std), tol, "normal_cdf_t[2]")
  assert_close(index(ys, cast(3, i64)), normal_cdf(cast(1.7, f32), mean, std), tol, "normal_cdf_t[3]")
}
def test_normal_cdf_t_deep_tail_matches_scalar() -> unit ! { Test } = {
  -- nautilus#113: the elementwise test above probes [-2.5, 1.7], where the
  -- cancelling form still agreed with its own scalar reference. The contract
  -- that distinguishes the two spellings is in the deep tail.
  mean = cast(0.0, f32)
  std = cast(1.0, f32)
  xs = to_tensor([cast(-6.0, f32), cast(-8.0, f32), cast(-10.0, f32)])
  ys = to_list(normal_cdf_t(xs, mean, std))
  _ = assert_true(gt(index(ys, cast(2, i64)), cast(0.0, f32)), "normal_cdf_t deep tail is strictly positive")
  _ = assert_true(lt(dist_rel_err(index(ys, cast(0, i64)), normal_cdf(cast(-6.0, f32), mean, std)), cast(1e-6, f32)), "normal_cdf_t[-6] matches scalar")
  _ = assert_true(lt(dist_rel_err(index(ys, cast(1, i64)), normal_cdf(cast(-8.0, f32), mean, std)), cast(1e-6, f32)), "normal_cdf_t[-8] matches scalar")
  assert_true(lt(dist_rel_err(index(ys, cast(2, i64)), normal_cdf(cast(-10.0, f32), mean, std)), cast(1e-6, f32)), "normal_cdf_t[-10] matches scalar")
}
def test_normal_pdf_t_matches_scalar_elementwise() -> unit ! { Test } = {
  mean = cast(0.2, f32)
  std = cast(1.4, f32)
  ys = to_list(normal_pdf_t(dist_probe_xs(), mean, std))
  tol = cast(1e-9, f32)
  _ = assert_close(index(ys, cast(0, i64)), normal_pdf(cast(-2.5, f32), mean, std), tol, "normal_pdf_t[0]")
  assert_close(index(ys, cast(3, i64)), normal_pdf(cast(1.7, f32), mean, std), tol, "normal_pdf_t[3]")
}
def test_normal_inv_cdf_t_matches_scalar_elementwise() -> unit ! { Test } = {
  mean = cast(0.2, f32)
  std = cast(1.4, f32)
  qs = to_tensor([cast(0.01, f32), cast(0.25, f32), cast(0.5, f32), cast(0.99, f32)])
  ys = to_list(normal_inv_cdf_t(qs, mean, std))
  tol = cast(1e-9, f32)
  _ = assert_close(index(ys, cast(0, i64)), normal_inv_cdf(cast(0.01, f32), mean, std), tol, "normal_inv_cdf_t low tail")
  _ = assert_close(index(ys, cast(1, i64)), normal_inv_cdf(cast(0.25, f32), mean, std), tol, "normal_inv_cdf_t central")
  _ = assert_close(index(ys, cast(2, i64)), normal_inv_cdf(cast(0.5, f32), mean, std), tol, "normal_inv_cdf_t median")
  assert_close(index(ys, cast(3, i64)), normal_inv_cdf(cast(0.99, f32), mean, std), tol, "normal_inv_cdf_t high tail")
}
def test_normal_cdf_t_inv_roundtrip() -> unit ! { Test } = {
  mean = cast(0.0, f32)
  std = cast(1.0, f32)
  xs = to_tensor([cast(-1.5, f32), cast(0.4, f32), cast(2.0, f32)])
  back = to_list(normal_inv_cdf_t(normal_cdf_t(xs, mean, std), mean, std))
  tol = cast(0.00001, f32)
  _ = assert_close(index(back, cast(0, i64)), cast(-1.5, f32), tol, "roundtrip[0]")
  _ = assert_close(index(back, cast(1, i64)), cast(0.4, f32), tol, "roundtrip[1]")
  assert_close(index(back, cast(2, i64)), cast(2.0, f32), tol, "roundtrip[2]")
}
def test_normal_inv_cdf_t_guards_match_scalar() -> unit ! { Test } = {
  -- The guard lanes are the ones a branchless port is most likely to get
  -- wrong: every lane computes the interior value, so the `where` order has
  -- to reinstate the scalar's precedence exactly.
  mean = cast(0.0, f32)
  std = cast(1.0, f32)
  qs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(-0.5, f32), cast(1.5, f32)])
  ys = to_list(normal_inv_cdf_t(qs, mean, std))
  _ = assert_true(lt(index(ys, cast(0, i64)), cast(-1e30, f32)), "q = 0 gives -inf like the scalar")
  _ = assert_true(gt(index(ys, cast(1, i64)), cast(1e30, f32)), "q = 1 gives +inf like the scalar")
  lo = index(ys, cast(2, i64))
  hi = index(ys, cast(3, i64))
  _ = assert_true(neq(lo, lo), "q < 0 gives NaN like the scalar")
  assert_true(neq(hi, hi), "q > 1 gives NaN like the scalar")
}
