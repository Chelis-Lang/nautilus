module Nautilus.Tests.Distributions

import Nautilus.Distributions (
  uniform_pdf, uniform_cdf, uniform_inv_cdf,
  exponential_pdf, exponential_cdf, exponential_inv_cdf,
  normal_pdf, normal_cdf, normal_inv_cdf,
  lognormal_pdf, lognormal_cdf, lognormal_inv_cdf,
  gamma_pdf, gamma_cdf, gamma_inv_cdf,
  chi_squared_pdf, chi_squared_cdf, chi_squared_inv_cdf,
  student_t_pdf, student_t_cdf,
  poisson_pmf, poisson_cdf,
  binomial_pmf, binomial_cdf,
  beta_pdf, beta_cdf,
  f_pdf, f_cdf,
  weibull_pdf, weibull_cdf, weibull_inv_cdf
)
import Std.Test (assert_close, assert_true)

-- ===========================================================================
-- NORMAL distribution identities
-- ===========================================================================

def test_normal_pdf_at_mean_is_one_over_sqrt_2pi() -> unit ! { Test } = {
  -- Standard normal peaks at 1/sqrt(2*pi) = 0.3989422804
  v = normal_pdf(cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.3989422, f32), cast(1e-5, f32),
               "N(0;0,1) = 1/sqrt(2pi)")
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
  -- pdf(mu+d) = pdf(mu-d) for any sigma
  l = normal_pdf(cast(3.7, f32), cast(2.0, f32), cast(1.5, f32))
  r = normal_pdf(cast(0.3, f32), cast(2.0, f32), cast(1.5, f32))
  assert_close(l, r, cast(1e-6, f32), "N(mu+d) = N(mu-d)")
}

def test_normal_cdf_at_mean_is_half() -> unit ! { Test } = {
  v = normal_cdf(cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.5, f32), cast(1e-5, f32), "N_cdf(0;0,1) = 0.5")
}

def test_normal_cdf_at_nonzero_mean_is_half() -> unit ! { Test } = {
  v = normal_cdf(cast(7.5, f32), cast(7.5, f32), cast(2.0, f32))
  assert_close(v, cast(0.5, f32), cast(1e-5, f32), "N_cdf(mu;mu,sigma) = 0.5")
}

def test_normal_cdf_far_left_is_zero() -> unit ! { Test } = {
  -- 10 sigma below mean: CDF effectively 0
  v = normal_cdf(cast(-10.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-5, f32), "N_cdf(-10;0,1) = 0")
}

def test_normal_cdf_far_right_is_one() -> unit ! { Test } = {
  v = normal_cdf(cast(10.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-5, f32), "N_cdf(+10;0,1) = 1")
}

def test_normal_cdf_monotone() -> unit ! { Test } = {
  a = normal_cdf(cast(-1.0, f32), cast(0.0, f32), cast(1.0, f32))
  b = normal_cdf(cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  c = normal_cdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  _ = assert_true(lt(a, b), "N_cdf monotone: -1 < 0");
  assert_true(lt(b, c), "N_cdf monotone: 0 < 1")
}

def test_normal_cdf_symmetry_sum_unit() -> unit ! { Test } = {
  -- Phi(x) + Phi(-x) = 1 for standard normal
  a = normal_cdf(cast(1.3, f32), cast(0.0, f32), cast(1.0, f32))
  b = normal_cdf(cast(-1.3, f32), cast(0.0, f32), cast(1.0, f32))
  s = add(a, b)
  assert_close(s, cast(1.0, f32), cast(1e-5, f32), "Phi(x) + Phi(-x) = 1")
}

def test_normal_inv_cdf_median_round_trip() -> unit ! { Test } = {
  v = normal_inv_cdf(cast(0.5, f32), cast(2.5, f32), cast(1.5, f32))
  assert_close(v, cast(2.5, f32), cast(1e-5, f32), "inv_cdf(0.5;mu,s) = mu")
}

def test_normal_inv_cdf_round_trip_x() -> unit ! { Test } = {
  x = cast(1.2, f32)
  q = normal_cdf(x, cast(0.0, f32), cast(1.0, f32))
  back = normal_inv_cdf(q, cast(0.0, f32), cast(1.0, f32))
  assert_close(back, x, cast(1e-3, f32), "inv_cdf(cdf(x)) = x")
}

def test_normal_inv_cdf_round_trip_neg_x() -> unit ! { Test } = {
  x = cast(-0.7, f32)
  q = normal_cdf(x, cast(0.0, f32), cast(1.0, f32))
  back = normal_inv_cdf(q, cast(0.0, f32), cast(1.0, f32))
  assert_close(back, x, cast(1e-3, f32), "inv_cdf(cdf(-0.7)) = -0.7")
}

def test_normal_pdf_scale_invariance() -> unit ! { Test } = {
  -- N(mu+sigma; mu, sigma) * sigma = N(1; 0, 1) (scale equivariance)
  v = normal_pdf(cast(3.0, f32), cast(2.0, f32), cast(1.0, f32))
  ref = normal_pdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, ref, cast(1e-6, f32), "N(mu+s;mu,s) = N(1;0,1) when s=1")
}

-- ===========================================================================
-- UNIFORM distribution identities
-- ===========================================================================

def test_uniform_pdf_unit_density() -> unit ! { Test } = {
  v = uniform_pdf(cast(0.5, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "U(0,1) pdf = 1")
}

def test_uniform_pdf_constant_density() -> unit ! { Test } = {
  -- U(2,7) density = 1/(7-2) = 0.2
  a = uniform_pdf(cast(3.0, f32), cast(2.0, f32), cast(7.0, f32))
  b = uniform_pdf(cast(5.5, f32), cast(2.0, f32), cast(7.0, f32))
  _ = assert_close(a, cast(0.2, f32), cast(1e-7, f32), "U(2,7) pdf at 3 = 0.2");
  _ = assert_close(b, cast(0.2, f32), cast(1e-7, f32), "U(2,7) pdf at 5.5 = 0.2");
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
  -- midpoint of [2,8] is 5
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

-- ===========================================================================
-- EXPONENTIAL distribution identities
-- ===========================================================================

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
  -- rate*x = 50 -> exp(-50) is essentially 0
  v = exponential_cdf(cast(50.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-6, f32), "Exp_cdf(large) = 1")
}

def test_exponential_cdf_monotone() -> unit ! { Test } = {
  a = exponential_cdf(cast(0.5, f32), cast(1.0, f32))
  b = exponential_cdf(cast(1.0, f32), cast(1.0, f32))
  c = exponential_cdf(cast(2.0, f32), cast(1.0, f32))
  _ = assert_true(lt(a, b), "Exp_cdf monotone a<b");
  assert_true(lt(b, c), "Exp_cdf monotone b<c")
}

def test_exponential_inv_cdf_round_trip() -> unit ! { Test } = {
  x = cast(1.5, f32)
  q = exponential_cdf(x, cast(2.0, f32))
  back = exponential_inv_cdf(q, cast(2.0, f32))
  assert_close(back, x, cast(1e-4, f32), "Exp inv_cdf round-trip")
}

def test_exponential_inv_cdf_at_zero() -> unit ! { Test } = {
  v = exponential_inv_cdf(cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Exp inv_cdf(0) = 0")
}

-- ===========================================================================
-- LOGNORMAL distribution identities
-- ===========================================================================

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
  -- lognormal_cdf(1; 0, sigma) = Phi(log(1)/sigma) = Phi(0) = 0.5
  v = lognormal_cdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.5, f32), cast(1e-5, f32), "LogN cdf(1;0,1) = 0.5")
}

def test_lognormal_inv_cdf_round_trip() -> unit ! { Test } = {
  x = cast(2.5, f32)
  q = lognormal_cdf(x, cast(0.0, f32), cast(1.0, f32))
  back = lognormal_inv_cdf(q, cast(0.0, f32), cast(1.0, f32))
  assert_close(back, x, cast(1e-2, f32), "LogN inv_cdf round-trip")
}

-- ===========================================================================
-- GAMMA distribution identities
-- ===========================================================================

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
  assert_close(v, cast(1.0, f32), cast(1e-5, f32), "Gamma cdf(large) = 1")
}

def test_gamma_shape_one_reduces_to_exponential() -> unit ! { Test } = {
  -- Gamma(shape=1, scale=s) is Exponential(rate=1/s)
  scale = cast(2.0, f32)
  rate = div(cast(1.0, f32), scale)
  x = cast(1.3, f32)
  g = gamma_pdf(x, cast(1.0, f32), scale)
  e = exponential_pdf(x, rate)
  assert_close(g, e, cast(1e-5, f32), "Gamma(1,s) pdf = Exp(1/s) pdf")
}

def test_gamma_shape_one_reduces_to_exponential_x2() -> unit ! { Test } = {
  scale = cast(0.5, f32)
  rate = div(cast(1.0, f32), scale)
  x = cast(0.8, f32)
  g = gamma_pdf(x, cast(1.0, f32), scale)
  e = exponential_pdf(x, rate)
  assert_close(g, e, cast(1e-5, f32), "Gamma(1,0.5) pdf = Exp(2) pdf")
}

def test_gamma_cdf_shape_one_reduces_to_exp_cdf() -> unit ! { Test } = {
  scale = cast(2.0, f32)
  rate = div(cast(1.0, f32), scale)
  x = cast(1.7, f32)
  g = gamma_cdf(x, cast(1.0, f32), scale)
  e = exponential_cdf(x, rate)
  assert_close(g, e, cast(1e-4, f32), "Gamma_cdf(1,s) = Exp_cdf(1/s)")
}

def test_gamma_cdf_monotone() -> unit ! { Test } = {
  a = gamma_cdf(cast(0.5, f32), cast(2.0, f32), cast(1.0, f32))
  b = gamma_cdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))
  c = gamma_cdf(cast(5.0, f32), cast(2.0, f32), cast(1.0, f32))
  _ = assert_true(lt(a, b), "Gamma_cdf monotone a<b");
  assert_true(lt(b, c), "Gamma_cdf monotone b<c")
}

-- ===========================================================================
-- CHI-SQUARED distribution identities
-- ===========================================================================

def test_chi2_pdf_at_zero_with_k_gt_two() -> unit ! { Test } = {
  v = chi_squared_pdf(cast(0.0, f32), cast(4.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Chi2 pdf(0;4) = 0")
}

def test_chi2_cdf_at_zero() -> unit ! { Test } = {
  v = chi_squared_cdf(cast(0.0, f32), cast(3.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Chi2 cdf(0;3) = 0")
}

def test_chi2_k2_reduces_to_exponential_pdf() -> unit ! { Test } = {
  -- Chi-squared with df=2 is Exponential with rate 1/2
  x = cast(1.5, f32)
  c = chi_squared_pdf(x, cast(2.0, f32))
  e = exponential_pdf(x, cast(0.5, f32))
  assert_close(c, e, cast(1e-5, f32), "Chi2(k=2) pdf = Exp(0.5) pdf")
}

def test_chi2_k2_reduces_to_exponential_cdf() -> unit ! { Test } = {
  x = cast(2.7, f32)
  c = chi_squared_cdf(x, cast(2.0, f32))
  e = exponential_cdf(x, cast(0.5, f32))
  assert_close(c, e, cast(1e-4, f32), "Chi2(k=2) cdf = Exp(0.5) cdf")
}

def test_chi2_cdf_far_right() -> unit ! { Test } = {
  v = chi_squared_cdf(cast(100.0, f32), cast(3.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-5, f32), "Chi2 cdf(large;3) = 1")
}

-- ===========================================================================
-- STUDENT-T distribution identities
-- ===========================================================================

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
  assert_close(v, cast(0.5, f32), cast(1e-5, f32), "t_cdf(0;5) = 0.5")
}

def test_student_t_cdf_at_zero_df1_is_half() -> unit ! { Test } = {
  v = student_t_cdf(cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.5, f32), cast(1e-5, f32), "t_cdf(0;1) = 0.5")
}

def test_student_t_cdf_symmetry_sum_unit() -> unit ! { Test } = {
  a = student_t_cdf(cast(0.7, f32), cast(5.0, f32))
  b = student_t_cdf(cast(-0.7, f32), cast(5.0, f32))
  s = add(a, b)
  assert_close(s, cast(1.0, f32), cast(1e-5, f32), "t_cdf(x) + t_cdf(-x) = 1")
}

def test_student_t_approaches_normal_high_df() -> unit ! { Test } = {
  -- as df -> infinity, student_t_pdf approaches standard normal pdf
  t_v = student_t_pdf(cast(0.5, f32), cast(1000.0, f32))
  n_v = normal_pdf(cast(0.5, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(t_v, n_v, cast(1e-2, f32), "t(df=1000) pdf ~ N(0,1) pdf")
}

def test_student_t_approaches_normal_high_df_at_one() -> unit ! { Test } = {
  t_v = student_t_pdf(cast(1.0, f32), cast(1000.0, f32))
  n_v = normal_pdf(cast(1.0, f32), cast(0.0, f32), cast(1.0, f32))
  assert_close(t_v, n_v, cast(1e-2, f32), "t(df=1000) pdf at 1 ~ N(0,1)")
}

-- ===========================================================================
-- POISSON distribution identities
-- ===========================================================================

def test_poisson_pmf_at_zero_is_exp_neg_lambda() -> unit ! { Test } = {
  -- Exact identity: P(0; lambda) = exp(-lambda)
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
  -- P(0) + P(1) + P(2) + P(3) = poisson_cdf(3; lambda)
  lam = cast(2.0, f32)
  s = add(add(add(
        poisson_pmf(cast(0.0, f32), lam),
        poisson_pmf(cast(1.0, f32), lam)),
        poisson_pmf(cast(2.0, f32), lam)),
        poisson_pmf(cast(3.0, f32), lam))
  c = poisson_cdf(cast(3.0, f32), lam)
  assert_close(s, c, cast(1e-3, f32), "sum_{k=0..3} P(k) = cdf(3)")
}

def test_poisson_pmf_sum_equals_cdf_lambda_one() -> unit ! { Test } = {
  lam = cast(1.0, f32)
  s = add(add(
        poisson_pmf(cast(0.0, f32), lam),
        poisson_pmf(cast(1.0, f32), lam)),
        poisson_pmf(cast(2.0, f32), lam))
  c = poisson_cdf(cast(2.0, f32), lam)
  assert_close(s, c, cast(1e-3, f32), "sum_{k=0..2} P(k;1) = cdf(2;1)")
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
  _ = assert_true(lt(a, b), "Poisson cdf monotone a<b");
  assert_true(lt(b, c), "Poisson cdf monotone b<c")
}

-- ===========================================================================
-- BINOMIAL distribution identities
-- ===========================================================================

def test_binomial_pmf_p_zero_at_zero() -> unit ! { Test } = {
  -- Bin(0; n, 0) = 1 exactly: no successes guaranteed when p=0
  v = binomial_pmf(cast(0.0, f32), cast(5.0, f32), cast(0.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "Bin(0;n,0) = 1")
}

def test_binomial_pmf_p_zero_at_one() -> unit ! { Test } = {
  -- Bin(k>0; n, 0) = 0
  v = binomial_pmf(cast(1.0, f32), cast(5.0, f32), cast(0.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Bin(1;n,0) = 0")
}

def test_binomial_pmf_p_one_at_n() -> unit ! { Test } = {
  -- Bin(n; n, 1) = 1 exactly: all successes when p=1
  v = binomial_pmf(cast(5.0, f32), cast(5.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(1e-7, f32), "Bin(n;n,1) = 1")
}

def test_binomial_pmf_p_one_at_zero() -> unit ! { Test } = {
  v = binomial_pmf(cast(0.0, f32), cast(5.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Bin(0;n,1) = 0")
}

def test_binomial_pmf_zero_successes_equals_one_minus_p_pow_n() -> unit ! { Test } = {
  -- Bin(0; n, p) = (1-p)^n
  n = cast(4.0, f32)
  p = cast(0.3, f32)
  one_minus_p = sub(cast(1.0, f32), p)
  -- (1-p)^4 = ((1-p)^2)^2
  sq = mul(one_minus_p, one_minus_p)
  expected = mul(sq, sq)
  v = binomial_pmf(cast(0.0, f32), n, p)
  assert_close(v, expected, cast(1e-5, f32), "Bin(0;n,p) = (1-p)^n")
}

def test_binomial_pmf_zero_successes_n3() -> unit ! { Test } = {
  -- Bin(0; 3, 0.4) = (0.6)^3 = 0.216
  p = cast(0.4, f32)
  q = sub(cast(1.0, f32), p)
  expected = mul(q, mul(q, q))
  v = binomial_pmf(cast(0.0, f32), cast(3.0, f32), p)
  assert_close(v, expected, cast(1e-5, f32), "Bin(0;3,0.4) = 0.6^3")
}

def test_binomial_pmf_symmetric_p_half_k1() -> unit ! { Test } = {
  -- Bin(k; n, 0.5) = Bin(n-k; n, 0.5)
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

-- ===========================================================================
-- BETA distribution identities
-- ===========================================================================

def test_beta_pdf_uniform_at_half() -> unit ! { Test } = {
  -- Beta(1,1) is Uniform(0,1): pdf = 1 everywhere in (0,1)
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
  -- Beta(a,b) pdf at x = Beta(b,a) pdf at 1-x
  l = beta_pdf(cast(0.3, f32), cast(2.0, f32), cast(5.0, f32))
  r = beta_pdf(cast(0.7, f32), cast(5.0, f32), cast(2.0, f32))
  assert_close(l, r, cast(1e-5, f32), "Beta(a,b)(x) = Beta(b,a)(1-x)")
}

def test_beta_pdf_symmetry_two() -> unit ! { Test } = {
  l = beta_pdf(cast(0.2, f32), cast(3.0, f32), cast(4.0, f32))
  r = beta_pdf(cast(0.8, f32), cast(4.0, f32), cast(3.0, f32))
  assert_close(l, r, cast(1e-5, f32), "Beta(3,4)(0.2) = Beta(4,3)(0.8)")
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
  -- Beta(a,b)_cdf(x) + Beta(b,a)_cdf(1-x) = 1
  a = beta_cdf(cast(0.4, f32), cast(2.0, f32), cast(3.0, f32))
  b = beta_cdf(cast(0.6, f32), cast(3.0, f32), cast(2.0, f32))
  s = add(a, b)
  assert_close(s, cast(1.0, f32), cast(1e-5, f32),
               "Beta(a,b)_cdf(x) + Beta(b,a)_cdf(1-x) = 1")
}

-- ===========================================================================
-- F distribution identities
-- ===========================================================================

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
  assert_close(v, cast(1.0, f32), cast(1e-3, f32), "F cdf(large;5,10) = 1")
}

def test_f_cdf_monotone() -> unit ! { Test } = {
  a = f_cdf(cast(0.5, f32), cast(5.0, f32), cast(10.0, f32))
  b = f_cdf(cast(1.0, f32), cast(5.0, f32), cast(10.0, f32))
  c = f_cdf(cast(2.0, f32), cast(5.0, f32), cast(10.0, f32))
  _ = assert_true(lt(a, b), "F cdf monotone a<b");
  assert_true(lt(b, c), "F cdf monotone b<c")
}

-- ===========================================================================
-- WEIBULL distribution identities
-- ===========================================================================

def test_weibull_pdf_at_zero_shape_gt_one() -> unit ! { Test } = {
  v = weibull_pdf(cast(0.0, f32), cast(2.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-7, f32), "Weibull pdf(0;k>1) = 0")
}

def test_weibull_cdf_at_scale_is_one_minus_one_over_e() -> unit ! { Test } = {
  -- Weibull cdf(scale; 1, scale) = 1 - exp(-1) = 0.6321205588 (documented)
  v = weibull_cdf(cast(2.5, f32), cast(1.0, f32), cast(2.5, f32))
  assert_close(v, cast(0.6321205, f32), cast(1e-5, f32),
               "W_cdf(s;1,s) = 1 - 1/e")
}

def test_weibull_cdf_at_scale_shape_two() -> unit ! { Test } = {
  -- Weibull cdf(scale; k, scale) = 1 - exp(-1) for any shape k > 0
  v = weibull_cdf(cast(3.0, f32), cast(2.0, f32), cast(3.0, f32))
  assert_close(v, cast(0.6321205, f32), cast(1e-5, f32),
               "W_cdf(s;k,s) = 1 - 1/e for any k")
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
  assert_close(back, x, cast(1e-3, f32), "W inv_cdf round-trip")
}

def test_weibull_inv_cdf_round_trip_diff_scale() -> unit ! { Test } = {
  x = cast(2.2, f32)
  q = weibull_cdf(x, cast(1.5, f32), cast(2.0, f32))
  back = weibull_inv_cdf(q, cast(1.5, f32), cast(2.0, f32))
  assert_close(back, x, cast(1e-3, f32), "W inv_cdf round-trip (k=1.5,s=2)")
}

def test_weibull_shape_one_reduces_to_exponential_pdf() -> unit ! { Test } = {
  -- Weibull(shape=1, scale=s) is Exponential(rate=1/s)
  scale = cast(2.0, f32)
  rate = div(cast(1.0, f32), scale)
  x = cast(1.3, f32)
  w = weibull_pdf(x, cast(1.0, f32), scale)
  e = exponential_pdf(x, rate)
  assert_close(w, e, cast(1e-5, f32), "W(1,s) pdf = Exp(1/s) pdf")
}

def test_weibull_cdf_monotone() -> unit ! { Test } = {
  a = weibull_cdf(cast(0.5, f32), cast(2.0, f32), cast(1.0, f32))
  b = weibull_cdf(cast(1.0, f32), cast(2.0, f32), cast(1.0, f32))
  c = weibull_cdf(cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))
  _ = assert_true(lt(a, b), "W cdf monotone a<b");
  assert_true(lt(b, c), "W cdf monotone b<c")
}

-- ===== Inverse-CDF round-trips for gamma + chi-squared =====
-- Round-trip tests don't need scipy: cdf(inv_cdf(p)) ~= p by definition.

def test_gamma_inv_cdf_roundtrip() -> unit ! { Test } = {
  -- gamma_cdf(gamma_inv_cdf(p, shape, scale), shape, scale) ~= p
  shape = cast(2.0, f32)
  scale = cast(1.5, f32)
  p = cast(0.4, f32)
  x = gamma_inv_cdf(p, shape, scale)
  q = gamma_cdf(x, shape, scale)
  assert_close(q, p, cast(1.0e-3, f32),
               "gamma cdf(inv_cdf(p)) = p")
}

def test_gamma_inv_cdf_roundtrip_high_p() -> unit ! { Test } = {
  shape = cast(2.0, f32)
  scale = cast(1.5, f32)
  p = cast(0.95, f32)
  x = gamma_inv_cdf(p, shape, scale)
  q = gamma_cdf(x, shape, scale)
  assert_close(q, p, cast(1.0e-3, f32),
               "gamma cdf(inv_cdf(0.95)) = 0.95")
}

def test_chi_squared_inv_cdf_roundtrip() -> unit ! { Test } = {
  -- chi_squared_cdf(chi_squared_inv_cdf(p, df), df) ~= p
  -- p=0.4 (not 0.5) — Newton lands at 0.5 bit-exactly because the chi^2
  -- median is a fixed point of the iteration on f32; off-median p
  -- exercises the actual Newton step. Red-team round 2 MEDIUM-1.
  df = cast(4.0, f32)
  p = cast(0.4, f32)
  x = chi_squared_inv_cdf(p, df)
  q = chi_squared_cdf(x, df)
  assert_close(q, p, cast(1.0e-3, f32),
               "chi^2 cdf(inv_cdf(p)) = p")
}

def test_chi_squared_inv_cdf_roundtrip_low_p() -> unit ! { Test } = {
  df = cast(4.0, f32)
  p = cast(0.05, f32)
  x = chi_squared_inv_cdf(p, df)
  q = chi_squared_cdf(x, df)
  assert_close(q, p, cast(1.0e-3, f32),
               "chi^2 cdf(inv_cdf(0.05)) = 0.05")
}
