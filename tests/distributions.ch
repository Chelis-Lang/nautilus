module Nautilus.Tests.Distributions
import Nautilus.Distributions (normal_cdf_t, normal_inv_cdf_t, normal_pdf_t, uniform_pdf, uniform_cdf, uniform_inv_cdf, exponential_pdf, exponential_cdf, exponential_inv_cdf, normal_pdf, normal_cdf, normal_inv_cdf, lognormal_pdf, lognormal_cdf, lognormal_inv_cdf, gamma_pdf, gamma_cdf, gamma_sf, gamma_inv_cdf, chi_squared_pdf, chi_squared_cdf, chi_squared_sf, chi_squared_inv_cdf, student_t_pdf, student_t_cdf, poisson_pmf, poisson_cdf, binomial_pmf, binomial_cdf, beta_pdf, beta_cdf, f_pdf, f_cdf, weibull_pdf, weibull_cdf, weibull_inv_cdf)
import Nautilus.ExampleDistributions (example_gamma_cdf_degenerate_arguments)
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
-- nautilus#137: `gamma_sf` and `chi_squared_sf` are the survival functions
-- that `1 - gamma_cdf(..)` and `1 - chi_squared_cdf(..)` cannot compute. The
-- CDF spells the upper branch `1 - gammaq(a, x)`, so a caller that subtracts
-- the CDF from 1 makes a round trip through 1.0 and loses the tail to
-- `0.5 * ulp(1.0)`. These functions return `gammaq` directly on that branch
-- and keep full f32 relative precision. References are `Q(a, x)` at 60
-- decimal digits rounded once to f32; the worst relative error measured over
-- 144 (x, df) pairs with a representable answer is 4.3e-6.
def test_gamma_sf_complements_the_cdf_where_both_are_ordinary() -> unit ! { Test } = {
  -- On the `gammap` branch neither form loses anything, so the pair must
  -- still sum to 1 exactly to f32 tolerance.
  a = gamma_sf(cast(1.0, f32), cast(3.0, f32), cast(2.0, f32))
  b = gamma_sf(cast(0.5, f32), cast(2.0, f32), cast(1.0, f32))
  c = gamma_sf(cast(2.0, f32), cast(5.0, f32), cast(1.0, f32))
  _ = assert_true(lt(dist_rel_err(a, cast(0.98561233, f32)), cast(0.00001, f32)), "gamma_sf(1;3,2) = 0.98561233")
  _ = assert_true(lt(dist_rel_err(b, cast(0.909796, f32)), cast(0.00001, f32)), "gamma_sf(0.5;2,1) = 0.909796")
  _ = assert_true(lt(dist_rel_err(c, cast(0.947347, f32)), cast(0.00001, f32)), "gamma_sf(2;5,1) = 0.947347")
  s = add(gamma_sf(cast(1.0, f32), cast(3.0, f32), cast(2.0, f32)), gamma_cdf(cast(1.0, f32), cast(3.0, f32), cast(2.0, f32)))
  assert_close(s, cast(1.0, f32), cast(1e-6, f32), "gamma_sf + gamma_cdf = 1 on the lower branch")
}
def test_gamma_sf_at_zero_is_one() -> unit ! { Test } = {
  v = gamma_sf(cast(0.0, f32), cast(3.0, f32), cast(2.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "gamma_sf(0;3,2) = 1")
}
def test_gamma_sf_deep_tail_keeps_significant_digits() -> unit ! { Test } = {
  -- Both of these are on the `gammaq` branch, and `1 - gamma_cdf` returns
  -- exactly 0.0 at both.
  a = gamma_sf(cast(60.0, f32), cast(1.5, f32), cast(2.0, f32))
  b = gamma_sf(cast(100.0, f32), cast(5.0, f32), cast(2.0, f32))
  _ = assert_true(gt(a, cast(0.0, f32)), "gamma_sf(60;1.5,2) is strictly positive")
  _ = assert_true(lt(dist_rel_err(a, cast(5.878231e-13, f32)), cast(0.00001, f32)), "gamma_sf(60;1.5,2) = 5.878231e-13")
  _ = assert_true(gt(b, cast(0.0, f32)), "gamma_sf(100;5,2) is strictly positive")
  assert_true(lt(dist_rel_err(b, cast(5.449702e-17, f32)), cast(0.00001, f32)), "gamma_sf(100;5,2) = 5.449702e-17")
}
def test_chi_squared_sf_deep_tail_keeps_significant_digits() -> unit ! { Test } = {
  df3 = cast(3.0, f32)
  a = chi_squared_sf(cast(40.0, f32), df3)
  b = chi_squared_sf(cast(100.0, f32), df3)
  c = chi_squared_sf(cast(80.0, f32), cast(10.0, f32))
  _ = assert_true(lt(dist_rel_err(a, cast(1.065509e-8, f32)), cast(0.00001, f32)), "chi_squared_sf(40, 3) = 1.065509e-8")
  _ = assert_true(lt(dist_rel_err(b, cast(1.5541595e-21, f32)), cast(0.00001, f32)), "chi_squared_sf(100, 3) = 1.5541595e-21")
  assert_true(lt(dist_rel_err(c, cast(5.0204643e-13, f32)), cast(0.00001, f32)), "chi_squared_sf(80, 10) = 5.0204643e-13")
}
def test_chi_squared_sf_complements_the_cdf() -> unit ! { Test } = {
  -- The identity has to hold on both sides of the `shape + 1` branch.
  lo = add(chi_squared_sf(cast(1.0, f32), cast(3.0, f32)), chi_squared_cdf(cast(1.0, f32), cast(3.0, f32)))
  hi = add(chi_squared_sf(cast(30.0, f32), cast(3.0, f32)), chi_squared_cdf(cast(30.0, f32), cast(3.0, f32)))
  _ = assert_close(lo, cast(1.0, f32), cast(1e-6, f32), "chi_squared_sf + cdf = 1 below the branch")
  assert_close(hi, cast(1.0, f32), cast(1e-6, f32), "chi_squared_sf + cdf = 1 above the branch")
}
def test_chi_squared_sf_at_zero_is_one() -> unit ! { Test } = {
  v = chi_squared_sf(cast(0.0, f32), cast(3.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "chi_squared_sf(0, 3) = 1")
}
def test_chi_squared_sf_is_what_one_minus_the_cdf_cannot_be() -> unit ! { Test } = {
  -- The failure case stated directly: at a statistic of 40 on 3 df the
  -- cancelling form is exactly 0.0 while the survival function is 1.07e-8.
  -- `gt` on the difference is the discriminator.
  sf = chi_squared_sf(cast(40.0, f32), cast(3.0, f32))
  cancelled = sub(cast(1.0, f32), chi_squared_cdf(cast(40.0, f32), cast(3.0, f32)))
  _ = assert_true(eq(cancelled, cast(0.0, f32)), "1 - chi_squared_cdf(40, 3) cancels to exactly 0")
  assert_true(gt(sf, cancelled), "chi_squared_sf(40, 3) recovers a tail the subtraction loses")
}
-- nautilus#137 follow-up: the upper tail of a *non-standard* normal needs the
-- mean reflected as well as the point. `docs/book/src/distributions/overview.md`
-- prescribes `normal_cdf(neg(x), neg(mean), std)`, and this test is what makes
-- that sentence checkable. Negating only the point computes
-- `Phi((-x - mu) / sigma)`, a different number entirely: for N(10, 2) at x = 13
-- it is 6.6e-31 where the upper tail is 0.0668. Reference is
-- `erfc((13 - 10) / (2 * sqrt(2))) / 2` at 60 decimal digits, rounded to f32.
def test_normal_upper_tail_reflects_the_mean_not_only_the_point() -> unit ! { Test } = {
  -- Three rows, not one. A single positive-mean point with x > mean is also
  -- satisfied by `Phi((|mean| - x) / std)`, a near-miss that is wrong for
  -- every negative mean: at N(-7, 1.5) it gives 1.0 against a true 0.00383.
  -- The negative-mean row is what separates the documented rule from it; the
  -- x < mean row covers the other ordering.
  a = normal_cdf(neg(cast(13.0, f32)), neg(cast(10.0, f32)), cast(2.0, f32))
  b = normal_cdf(neg(cast(-3.0, f32)), neg(cast(-7.0, f32)), cast(1.5, f32))
  c = normal_cdf(neg(cast(5.0, f32)), neg(cast(10.0, f32)), cast(3.0, f32))
  point_only = normal_cdf(neg(cast(13.0, f32)), cast(10.0, f32), cast(2.0, f32))
  _ = assert_true(lt(dist_rel_err(a, cast(0.0668072, f32)), cast(0.00001, f32)), "upper tail of N(10,2) at 13 is 0.0668072")
  _ = assert_true(lt(dist_rel_err(b, cast(0.0038303805, f32)), cast(0.00001, f32)), "upper tail of N(-7,1.5) at -3 is 0.0038303805, so the mean must be negated too")
  _ = assert_true(lt(dist_rel_err(c, cast(0.9522096, f32)), cast(0.00001, f32)), "upper tail of N(10,3) at 5 is 0.9522096, so the rule holds for x < mean")
  assert_true(gt(a, mul(cast(1e20, f32), point_only)), "negating only the point is wrong by orders of magnitude, not by rounding")
}
-- nautilus#140: `gamma_cdf` and `gamma_sf` validated neither parameter, so a
-- degenerate `scale` or a non-finite `x` produced a non-finite standardised
-- argument `xs = x / scale`, took the `gammaq` branch, and never satisfied the
-- continued fraction's convergence test. The recursion then spent its whole
-- 200-iteration budget, which the `chelis eval` lane cannot afford: see
-- the eval-lane entry in `docs/UPSTREAM_BUGS.md` (chelis#2471). The guards below
-- are the ones `weibull_cdf`, `gamma_pdf` and `gamma_inv_cdf` already use in
-- this module, and they agree with SciPy on every row.
def test_gamma_cdf_rejects_a_nonpositive_scale() -> unit ! { Test } = {
  z = gamma_cdf(cast(1.0, f32), cast(2.0, f32), cast(0.0, f32))
  n = gamma_cdf(cast(1.0, f32), cast(2.0, f32), cast(-1.0, f32))
  _ = assert_true(neq(z, z), "gamma_cdf(1;2,0) is NaN, not a crash")
  assert_true(neq(n, n), "gamma_cdf(1;2,-1) is NaN; a negative scale is not a left tail")
}
def test_gamma_cdf_rejects_a_nonpositive_shape() -> unit ! { Test } = {
  z = gamma_cdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  n = gamma_cdf(cast(1.0, f32), cast(-2.0, f32), cast(1.0, f32))
  _ = assert_true(neq(z, z), "gamma_cdf(1;0,1) is NaN like SciPy, not 1.0")
  assert_true(neq(n, n), "gamma_cdf(1;-2,1) is NaN")
}
def test_gamma_sf_rejects_the_same_parameters() -> unit ! { Test } = {
  s = gamma_sf(cast(1.0, f32), cast(2.0, f32), cast(0.0, f32))
  h = gamma_sf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  _ = assert_true(neq(s, s), "gamma_sf(1;2,0) is NaN")
  assert_true(neq(h, h), "gamma_sf(1;0,1) is NaN")
}
def test_gamma_cdf_at_positive_infinity_is_one() -> unit ! { Test } = {
  -- The limit, not a guard against a crash: F(+inf) = 1 and its survival
  -- function is 0. A finite `x` with a tiny `scale` overflows `xs` to +inf and
  -- has to land on the same answer, which is why the guard reads `xs`.
  inf_x = div(cast(1.0, f32), cast(0.0, f32))
  c = gamma_cdf(inf_x, cast(2.0, f32), cast(1.0, f32))
  s = gamma_sf(inf_x, cast(2.0, f32), cast(1.0, f32))
  o = gamma_cdf(cast(1e30, f32), cast(2.0, f32), cast(1e-30, f32))
  _ = assert_close(c, cast(1.0, f32), cast(1e-7, f32), "gamma_cdf(+inf;2,1) = 1")
  _ = assert_close(s, cast(0.0, f32), cast(1e-7, f32), "gamma_sf(+inf;2,1) = 0")
  assert_close(o, cast(1.0, f32), cast(1e-7, f32), "gamma_cdf(1e30;2,1e-30) = 1 through an overflowing xs")
}
def test_gamma_cdf_at_negative_infinity_is_zero() -> unit ! { Test } = {
  neg_inf_x = neg(div(cast(1.0, f32), cast(0.0, f32)))
  c = gamma_cdf(neg_inf_x, cast(2.0, f32), cast(1.0, f32))
  s = gamma_sf(neg_inf_x, cast(2.0, f32), cast(1.0, f32))
  _ = assert_close(c, cast(0.0, f32), cast(1e-7, f32), "gamma_cdf(-inf;2,1) = 0")
  assert_close(s, cast(1.0, f32), cast(1e-7, f32), "gamma_sf(-inf;2,1) = 1")
}
def test_gamma_cdf_propagates_a_nan_argument() -> unit ! { Test } = {
  nan_x = div(cast(0.0, f32), cast(0.0, f32))
  c = gamma_cdf(nan_x, cast(2.0, f32), cast(1.0, f32))
  s = gamma_sf(nan_x, cast(2.0, f32), cast(1.0, f32))
  _ = assert_true(neq(c, c), "gamma_cdf(NaN;2,1) is NaN")
  assert_true(neq(s, s), "gamma_sf(NaN;2,1) is NaN")
}
def test_chi_squared_inherits_the_guards() -> unit ! { Test } = {
  -- `chi_squared_cdf` standardises to `gamma_cdf(x, df/2, 2)`, so df <= 0
  -- reaches the shape guard. `chi_squared_p_value` is `chi_squared_sf`, and it
  -- returned 0.0 on df = 0 before this change.
  inf_x = div(cast(1.0, f32), cast(0.0, f32))
  ci = chi_squared_cdf(inf_x, cast(3.0, f32))
  si = chi_squared_sf(inf_x, cast(3.0, f32))
  zc = chi_squared_cdf(cast(5.0, f32), cast(0.0, f32))
  zs = chi_squared_sf(cast(5.0, f32), cast(0.0, f32))
  nc = chi_squared_cdf(cast(5.0, f32), cast(-1.0, f32))
  _ = assert_close(ci, cast(1.0, f32), cast(1e-7, f32), "chi_squared_cdf(+inf,3) = 1")
  _ = assert_close(si, cast(0.0, f32), cast(1e-7, f32), "chi_squared_sf(+inf,3) = 0")
  _ = assert_true(neq(zc, zc), "chi_squared_cdf(5,0) is NaN like SciPy, not 1.0")
  _ = assert_true(neq(zs, zs), "chi_squared_sf(5,0) is NaN, not 0.0")
  assert_true(neq(nc, nc), "chi_squared_cdf(5,-1) is NaN")
}
-- nautilus#140, second half: the guards stop the *degenerate* inputs reaching
-- the recursions, but an ordinary large `shape` reaches them too, needing more
-- iterations than the eval lane has frames for. `gamma_cdf(2000;2000,1)` wants
-- 187 series terms and aborted the `chelis eval` process before this change;
-- the series and continued fraction now spend their 200-iteration budget in
-- about 30 frames by running it in chunks of 16. References are the
-- regularised incomplete gamma at 60 decimal digits, rounded once to f32; the
-- f32 errors quoted in the messages are the series' own accumulation error,
-- unchanged by this fix and documented in the book, not a loss introduced by
-- chunking. Every value is bit-identical to what the flat recursion returned
-- in a lane with enough stack to run it.
--
-- Read these three as value pins, not as detectors. `chelis test` runs each
-- file on a `chelis-test-worker` thread whose stack holds about 500 frames of
-- this shape, so a 200-frame recursion fits and all three pass against the
-- unpatched module too. The abort is only observable in the `chelis eval`
-- lane, which runs on `main` and holds about 135; the detector for it is
-- `example_gamma_cdf_degenerate_arguments`, evaluated by the CI step that runs
-- `chelis eval --file` over `src/example*.ch`, and pinned in the test lane by
-- `test_example_degenerate_arguments_oracle_is_all_ones` below.
def test_gamma_cdf_large_shape_returns_a_value_on_the_series_branch() -> unit ! { Test } = {
  v = gamma_cdf(cast(2000.0, f32), cast(2000.0, f32), cast(1.0, f32))
  _ = assert_true(not(neq(v, v)), "gamma_cdf(2000;2000,1) is a number")
  assert_true(lt(dist_rel_err(v, cast(0.50297356, f32)), cast(0.001, f32)), "gamma_cdf(2000;2000,1) = 0.50297356 to 6.5e-4, the f32 series error")
}
def test_gamma_cdf_large_shape_returns_a_value_on_the_cf_branch() -> unit ! { Test } = {
  v = gamma_cdf(cast(20001.0, f32), cast(20000.0, f32), cast(1.0, f32))
  _ = assert_true(not(neq(v, v)), "gamma_cdf(20001;20000,1) is a number")
  assert_true(lt(dist_rel_err(v, cast(0.5037612, f32)), cast(0.002, f32)), "gamma_cdf(20001;20000,1) = 0.5037612 to 1.5e-3, the f32 continued-fraction error")
}
def test_chi_squared_cdf_large_df_returns_a_value() -> unit ! { Test } = {
  v = chi_squared_cdf(cast(4000.0, f32), cast(4000.0, f32))
  _ = assert_true(not(neq(v, v)), "chi_squared_cdf(4000,4000) is a number")
  assert_true(lt(dist_rel_err(v, cast(0.50297356, f32)), cast(0.001, f32)), "chi_squared_cdf(4000,4000) = 0.50297356 to 6.5e-4")
}
def test_gamma_cdf_past_the_budget_returns_the_partial_sum() -> unit ! { Test } = {
  -- Past shape 2338 at x = shape the series needs more than its 200 terms, so
  -- the budget runs out and the result is the unconverged partial sum. It is
  -- deliberately not NaN. Both values below are exactly what the flat
  -- recursion returned in any lane with enough stack to run 200 frames, so
  -- this fix changes no value here, and converting them to NaN would have
  -- discarded a 1.5e-4-accurate answer at shape 2339 while keeping the 1.6e-3
  -- one at 2338. The accuracy limit itself is long-standing and documented in
  -- `docs/book/src/distributions/gamma-family.md`.
  a = gamma_cdf(cast(2339.0, f32), cast(2339.0, f32), cast(1.0, f32))
  b = gamma_cdf(cast(30000.0, f32), cast(30000.0, f32), cast(1.0, f32))
  _ = assert_close(a, cast(0.50282675, f32), cast(1e-7, f32), "gamma_cdf(2339;2339,1) = 0.50282675, the flat form's value")
  assert_close(b, cast(0.37090707, f32), cast(1e-7, f32), "gamma_cdf(30000;30000,1) = 0.37090707, the flat form's value, 26% from the true 0.5007678")
}
-- The companion to the three pins above. `example_gamma_cdf_degenerate_arguments`
-- encodes five of nautilus#140's cases as decimal digits so one f32 says which
-- ones hold: 11111.0 is all five. This test pins that value in the test lane,
-- where the unpatched module scores 10001.0 (only the NaN scale and the large
-- df survive the missing guards). What this test cannot see is the abort
-- itself: evaluating the same def through `chelis eval --file` on the
-- unpatched module exits 134 with `fatal runtime error: stack overflow`, which
-- is what the CI example-evaluation step catches.
def test_example_degenerate_arguments_oracle_is_all_ones() -> unit ! { Test } = {
  v = example_gamma_cdf_degenerate_arguments()
  assert_close(v, cast(11111.0, f32), cast(1e-7, f32), "every nautilus#140 case holds, so the oracle digit sum is 11111")
}
