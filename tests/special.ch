module Nautilus.Tests.Special
import Nautilus.Special (erf, erfinv, log_gamma, digamma, beta, lbeta, trigamma, bessel_i0, bessel_i1, bessel_k0, bessel_k1, bessel_j0, bessel_j1, bessel_y0, bessel_y1, airy_ai, airy_bi, ellipk, ellipe)
import Std.Test (assert_close, assert_true, assert_eq)
def test_erf_zero() -> unit ! { Test } = assert_eq(erf(cast(0.0, f32)), cast(0.0, f32), "erf(0) = 0")
def test_erf_odd_symmetry() -> unit ! { Test } = {
  x = cast(0.7, f32)
  assert_close(erf(neg(x)), neg(erf(x)), cast(0.0000001, f32), "erf is odd")
}
def test_erf_saturates_pos() -> unit ! { Test } = assert_close(erf(cast(5.0, f32)), cast(1.0, f32), cast(0.000001, f32), "erf(5) ~ 1")
def test_erf_saturates_neg() -> unit ! { Test } = assert_close(erf(cast(-5.0, f32)), cast(-1.0, f32), cast(0.000001, f32), "erf(-5) ~ -1")
def test_erf_in_unit_interval() -> unit ! { Test } = {
  y = erf(cast(0.7, f32))
  _ = assert_true(gt(y, cast(0.0, f32)), "erf(0.7) > 0")
  assert_true(lt(y, cast(1.0, f32)), "erf(0.7) < 1")
}
def test_erf_monotone() -> unit ! { Test } = {
  a = erf(cast(0.3, f32))
  b = erf(cast(0.6, f32))
  c = erf(cast(1.2, f32))
  _ = assert_true(lt(a, b), "erf monotone: erf(0.3) < erf(0.6)")
  assert_true(lt(b, c), "erf monotone: erf(0.6) < erf(1.2)")
}
def test_erfinv_zero() -> unit ! { Test } = assert_close(erfinv(cast(0.0, f32)), cast(0.0, f32), cast(0.000001, f32), "erfinv(0) = 0")
def test_erfinv_roundtrip_pos() -> unit ! { Test } = {
  x = cast(0.4, f32)
  assert_close(erfinv(erf(x)), x, cast(0.00001, f32), "erfinv(erf(0.4)) = 0.4")
}
def test_erfinv_roundtrip_neg() -> unit ! { Test } = {
  x = cast(-0.6, f32)
  assert_close(erfinv(erf(x)), x, cast(0.00001, f32), "erfinv(erf(-0.6)) = -0.6")
}
def test_erf_roundtrip_via_erfinv() -> unit ! { Test } = {
  y = cast(0.3, f32)
  assert_close(erf(erfinv(y)), y, cast(0.00001, f32), "erf(erfinv(0.3)) = 0.3")
}
def test_log_gamma_one() -> unit ! { Test } = assert_close(log_gamma(cast(1.0, f32)), cast(0.0, f32), cast(0.000001, f32), "log_gamma(1) = 0")
def test_log_gamma_two() -> unit ! { Test } = assert_close(log_gamma(cast(2.0, f32)), cast(0.0, f32), cast(0.000001, f32), "log_gamma(2) = 0")
def test_log_gamma_half() -> unit ! { Test } = assert_close(log_gamma(cast(0.5, f32)), cast(0.5723649, f32), cast(0.00001, f32), "log_gamma(1/2) = ln(sqrt(pi))")
def test_log_gamma_recurrence() -> unit ! { Test } = {
  x = cast(3.7, f32)
  lhs = sub(log_gamma(add(x, cast(1.0, f32))), log_gamma(x))
  rhs = log(x)
  assert_close(lhs, rhs, cast(0.00001, f32), "log_gamma(x+1) - log_gamma(x) = log(x)")
}
def test_log_gamma_factorial_5() -> unit ! { Test } = assert_close(log_gamma(cast(6.0, f32)), log(cast(120.0, f32)), cast(0.00001, f32), "log_gamma(6) = log(5!) = log(120)")
def test_digamma_one_eulermascheroni() -> unit ! { Test } = assert_close(digamma(cast(1.0, f32)), cast(-0.5772156, f32), cast(0.00001, f32), "digamma(1) = -gamma_E")
def test_digamma_recurrence() -> unit ! { Test } = {
  x = cast(2.3, f32)
  lhs = digamma(add(x, cast(1.0, f32)))
  rhs = add(digamma(x), div(cast(1.0, f32), x))
  assert_close(lhs, rhs, cast(0.00001, f32), "digamma(x+1) = digamma(x) + 1/x")
}
def test_digamma_two() -> unit ! { Test } = assert_close(digamma(cast(2.0, f32)), sub(cast(1.0, f32), cast(0.5772156, f32)), cast(0.00001, f32), "digamma(2) = 1 - gamma_E")
def test_beta_one_one() -> unit ! { Test } = assert_close(beta(cast(1.0, f32), cast(1.0, f32)), cast(1.0, f32), cast(0.000001, f32), "beta(1,1) = 1")
def test_beta_symmetry() -> unit ! { Test } = {
  a = cast(2.5, f32)
  b = cast(3.7, f32)
  assert_close(beta(a, b), beta(b, a), cast(0.000001, f32), "beta(a,b) = beta(b,a)")
}
def test_beta_one_n() -> unit ! { Test } = {
  n = cast(4.0, f32)
  assert_close(beta(cast(1.0, f32), n), div(cast(1.0, f32), n), cast(0.000001, f32), "beta(1, n) = 1/n")
}
def test_trigamma_recurrence() -> unit ! { Test } = {
  x = cast(2.4, f32)
  lhs = trigamma(add(x, cast(1.0, f32)))
  rhs = sub(trigamma(x), div(cast(1.0, f32), mul(x, x)))
  assert_close(lhs, rhs, cast(0.00001, f32), "trigamma(x+1) = trigamma(x) - 1/x^2")
}
def test_trigamma_one_pi2_over_6() -> unit ! { Test } = assert_close(trigamma(cast(1.0, f32)), cast(1.644934, f32), cast(0.0001, f32), "trigamma(1) = pi^2 / 6")
def test_trigamma_positive() -> unit ! { Test } = {
  _ = assert_true(gt(trigamma(cast(0.5, f32)), cast(0.0, f32)), "trigamma(0.5) > 0")
  assert_true(gt(trigamma(cast(3.0, f32)), cast(0.0, f32)), "trigamma(3.0) > 0")
}
def test_bessel_i0_zero() -> unit ! { Test } = assert_close(bessel_i0(cast(0.0, f32)), cast(1.0, f32), cast(0.000001, f32), "I0(0) = 1")
def test_bessel_i0_even() -> unit ! { Test } = {
  x = cast(1.3, f32)
  assert_close(bessel_i0(neg(x)), bessel_i0(x), cast(0.000001, f32), "I0 is even")
}
def test_bessel_i1_zero() -> unit ! { Test } = assert_close(bessel_i1(cast(0.0, f32)), cast(0.0, f32), cast(0.000001, f32), "I1(0) = 0")
def test_bessel_i1_odd() -> unit ! { Test } = {
  x = cast(1.5, f32)
  assert_close(bessel_i1(neg(x)), neg(bessel_i1(x)), cast(0.000001, f32), "I1 is odd")
}
def test_bessel_i0_ge_i1_pos() -> unit ! { Test } = {
  x = cast(2.0, f32)
  i0v = bessel_i0(x)
  i1v = bessel_i1(x)
  _ = assert_true(gt(i1v, cast(0.0, f32)), "I1(2) > 0")
  assert_true(gt(i0v, i1v), "I0(2) > I1(2)")
}
def test_bessel_k0_positive() -> unit ! { Test } = assert_true(gt(bessel_k0(cast(1.0, f32)), cast(0.0, f32)), "K0(1) > 0")
def test_bessel_k0_decreasing() -> unit ! { Test } = {
  a = bessel_k0(cast(0.5, f32))
  b = bessel_k0(cast(1.5, f32))
  c = bessel_k0(cast(3.0, f32))
  _ = assert_true(gt(a, b), "K0 decreasing: K0(0.5) > K0(1.5)")
  assert_true(gt(b, c), "K0 decreasing: K0(1.5) > K0(3.0)")
}
def test_bessel_k1_positive() -> unit ! { Test } = assert_true(gt(bessel_k1(cast(1.0, f32)), cast(0.0, f32)), "K1(1) > 0")
def test_bessel_k1_ge_k0_pos() -> unit ! { Test } = {
  x = cast(1.0, f32)
  assert_true(gt(bessel_k1(x), bessel_k0(x)), "K1(1) > K0(1)")
}
def test_bessel_j0_zero() -> unit ! { Test } = assert_close(bessel_j0(cast(0.0, f32)), cast(1.0, f32), cast(0.000001, f32), "J0(0) = 1")
def test_bessel_j0_even() -> unit ! { Test } = {
  x = cast(2.5, f32)
  assert_close(bessel_j0(neg(x)), bessel_j0(x), cast(0.000001, f32), "J0 is even")
}
def test_bessel_j1_zero() -> unit ! { Test } = assert_close(bessel_j1(cast(0.0, f32)), cast(0.0, f32), cast(0.000001, f32), "J1(0) = 0")
def test_bessel_j1_odd() -> unit ! { Test } = {
  x = cast(2.0, f32)
  assert_close(bessel_j1(neg(x)), neg(bessel_j1(x)), cast(0.000001, f32), "J1 is odd")
}
def test_bessel_j0_bounded() -> unit ! { Test } = {
  v = bessel_j0(cast(3.0, f32))
  abs_v = if lt(v, cast(0.0, f32)) then neg(v) else v
  assert_true(lte(abs_v, cast(1.0, f32)), "|J0(3)| <= 1")
}
def test_bessel_y0_not_nan_pos() -> unit ! { Test } = {
  v = bessel_y0(cast(1.0, f32))
  assert_true(eq(v, v), "Y0(1) is not NaN")
}
def test_bessel_y1_not_nan_pos() -> unit ! { Test } = {
  v = bessel_y1(cast(1.0, f32))
  assert_true(eq(v, v), "Y1(1) is not NaN")
}
def test_bessel_y1_negative_near_zero() -> unit ! { Test } = assert_true(lt(bessel_y1(cast(0.5, f32)), cast(0.0, f32)), "Y1(0.5) < 0")
def test_airy_ai_zero() -> unit ! { Test } = assert_close(airy_ai(cast(0.0, f32)), cast(0.355028, f32), cast(0.00001, f32), "Ai(0) = 1/(3^(2/3) gamma(2/3))")
def test_airy_bi_zero() -> unit ! { Test } = assert_close(airy_bi(cast(0.0, f32)), cast(0.6149266, f32), cast(0.00001, f32), "Bi(0) = 1/(3^(1/6) gamma(2/3))")
def test_airy_ai_decay_pos() -> unit ! { Test } = {
  a = airy_ai(cast(0.5, f32))
  b = airy_ai(cast(1.5, f32))
  c = airy_ai(cast(3.0, f32))
  _ = assert_true(gt(a, b), "Ai decreasing: Ai(0.5) > Ai(1.5)")
  _ = assert_true(gt(b, c), "Ai decreasing: Ai(1.5) > Ai(3.0)")
  assert_true(gt(c, cast(0.0, f32)), "Ai(3) > 0")
}
def test_airy_bi_growth_pos() -> unit ! { Test } = {
  a = airy_bi(cast(0.5, f32))
  b = airy_bi(cast(1.5, f32))
  c = airy_bi(cast(3.0, f32))
  _ = assert_true(lt(a, b), "Bi increasing: Bi(0.5) < Bi(1.5)")
  assert_true(lt(b, c), "Bi increasing: Bi(1.5) < Bi(3.0)")
}
def test_ellipk_zero() -> unit ! { Test } = assert_close(ellipk(cast(0.0, f32)), cast(1.5707963, f32), cast(0.000001, f32), "K(0) = pi/2")
def test_ellipe_zero() -> unit ! { Test } = assert_close(ellipe(cast(0.0, f32)), cast(1.5707963, f32), cast(0.000001, f32), "E(0) = pi/2")
def test_ellipe_one() -> unit ! { Test } = assert_eq(ellipe(cast(1.0, f32)), cast(1.0, f32), "E(1) = 1")
def test_ellipk_increasing() -> unit ! { Test } = {
  a = ellipk(cast(0.1, f32))
  b = ellipk(cast(0.5, f32))
  c = ellipk(cast(0.9, f32))
  _ = assert_true(lt(a, b), "K increasing: K(0.1) < K(0.5)")
  assert_true(lt(b, c), "K increasing: K(0.5) < K(0.9)")
}
def test_ellipe_decreasing() -> unit ! { Test } = {
  a = ellipe(cast(0.1, f32))
  b = ellipe(cast(0.5, f32))
  c = ellipe(cast(0.9, f32))
  _ = assert_true(gt(a, b), "E decreasing: E(0.1) > E(0.5)")
  assert_true(gt(b, c), "E decreasing: E(0.5) > E(0.9)")
}
def test_ellipk_ge_ellipe() -> unit ! { Test } = {
  m = cast(0.5, f32)
  assert_true(gt(ellipk(m), ellipe(m)), "K(0.5) > E(0.5)")
}
def test_lbeta_one_one_zero() -> unit ! { Test } = assert_close(lbeta(cast(1.0, f32), cast(1.0, f32)), cast(0.0, f32), cast(0.000001, f32), "lbeta(1,1) = log(1) = 0")
def test_lbeta_symmetric() -> unit ! { Test } = {
  l = lbeta(cast(2.0, f32), cast(3.0, f32))
  r = lbeta(cast(3.0, f32), cast(2.0, f32))
  assert_close(l, r, cast(0.000001, f32), "lbeta symmetric")
}
def test_lbeta_matches_log_beta() -> unit ! { Test } = {
  a = cast(2.5, f32)
  b = cast(3.5, f32)
  lhs = lbeta(a, b)
  rhs = log(beta(a, b))
  assert_close(lhs, rhs, cast(0.00001, f32), "lbeta = log(beta)")
}
