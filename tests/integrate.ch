module Nautilus.Tests.Integrate
import Nautilus.Integrate (trapezoidal, simpsons, gauss_legendre_5, adaptive_simpson, romberg_5, gauss_legendre_10, gauss_hermite_10, gauss_laguerre_10)
import Std.Test (assert_close)
def f_one(x: f32) -> f32 = cast(1.0, f32)
def f_x(x: f32) -> f32 = x
def f_xsq(x: f32) -> f32 = mul(x, x)
def f_xcube(x: f32) -> f32 = mul(mul(x, x), x)
def f_sin(x: f32) -> f32 = sin(x)
def f_exp(x: f32) -> f32 = exp(x)
def f_recip(x: f32) -> f32 = div(cast(1.0, f32), x)
def test_trap_const_one() -> unit ! { Test } = {
  v = trapezoidal(f_one, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(1.0, f32), cast(0.000001, f32), "trapezoidal: integral of 1 over [0,1] = 1")
}
def test_simp_const_one() -> unit ! { Test } = {
  v = simpsons(f_one, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(1.0, f32), cast(0.000001, f32), "simpsons: integral of 1 over [0,1] = 1")
}
def test_gl5_const_one() -> unit ! { Test } = {
  v = gauss_legendre_5(f_one, cast(0.0, f32), cast(1.0, f32), cast(5, int64))
  assert_close(v, cast(1.0, f32), cast(0.000001, f32), "gauss_legendre_5: integral of 1 over [0,1] = 1")
}
def test_gl10_const_one() -> unit ! { Test } = {
  v = gauss_legendre_10(f_one, cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(0.000001, f32), "gauss_legendre_10: integral of 1 over [0,1] = 1")
}
def test_romberg_const_one() -> unit ! { Test } = {
  v = romberg_5(f_one, cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.0, f32), cast(0.000001, f32), "romberg_5: integral of 1 over [0,1] = 1")
}
def test_trap_x() -> unit ! { Test } = {
  v = trapezoidal(f_x, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(0.5, f32), cast(0.000001, f32), "trapezoidal: integral of x over [0,1] = 0.5 (trap exact for linear)")
}
def test_simp_x() -> unit ! { Test } = {
  v = simpsons(f_x, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(0.5, f32), cast(0.000001, f32), "simpsons: integral of x over [0,1] = 0.5")
}
def test_gl5_x() -> unit ! { Test } = {
  v = gauss_legendre_5(f_x, cast(0.0, f32), cast(1.0, f32), cast(5, int64))
  assert_close(v, cast(0.5, f32), cast(0.000001, f32), "gauss_legendre_5: integral of x over [0,1] = 0.5")
}
def test_gl10_x() -> unit ! { Test } = {
  v = gauss_legendre_10(f_x, cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.5, f32), cast(0.000001, f32), "gauss_legendre_10: integral of x over [0,1] = 0.5")
}
def test_trap_x_0_2() -> unit ! { Test } = {
  v = trapezoidal(f_x, cast(0.0, f32), cast(2.0, f32), cast(10, int64))
  assert_close(v, cast(2.0, f32), cast(0.000001, f32), "trapezoidal: integral of x over [0,2] = 2 (1/2 * 2^2)")
}
def test_simp_x_symmetric() -> unit ! { Test } = {
  v = simpsons(f_x, cast(-1.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(0.0, f32), cast(0.000001, f32), "simpsons: integral of x over [-1,1] = 0 (odd on symmetric)")
}
def test_gl10_x_symmetric() -> unit ! { Test } = {
  v = gauss_legendre_10(f_x, cast(-1.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.0, f32), cast(0.000001, f32), "gauss_legendre_10: integral of x over [-1,1] = 0 (odd on symmetric)")
}
def test_simp_xsq_symmetric_bracket() -> unit ! { Test } = {
  v = simpsons(f_xsq, cast(-1.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(0.6666666, f32), cast(0.00001, f32), "simpsons: x^2 over [-1,1] = 2/3 (weight check)")
}
def test_gl10_xsq_symmetric_bracket() -> unit ! { Test } = {
  v = gauss_legendre_10(f_xsq, cast(-1.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.6666666, f32), cast(0.00001, f32), "gauss_legendre_10: x^2 over [-1,1] = 2/3 (weight check)")
}
def test_simp_xsq() -> unit ! { Test } = {
  v = simpsons(f_xsq, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(0.3333333, f32), cast(0.00001, f32), "simpsons: integral of x^2 over [0,1] = 1/3")
}
def test_gl5_xsq() -> unit ! { Test } = {
  v = gauss_legendre_5(f_xsq, cast(0.0, f32), cast(1.0, f32), cast(5, int64))
  assert_close(v, cast(0.3333333, f32), cast(0.00001, f32), "gauss_legendre_5: integral of x^2 over [0,1] = 1/3")
}
def test_gl10_xsq() -> unit ! { Test } = {
  v = gauss_legendre_10(f_xsq, cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.3333333, f32), cast(0.00001, f32), "gauss_legendre_10: integral of x^2 over [0,1] = 1/3")
}
def test_romberg_xsq() -> unit ! { Test } = {
  v = romberg_5(f_xsq, cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.3333333, f32), cast(0.00001, f32), "romberg_5: integral of x^2 over [0,1] = 1/3")
}
def test_simp_xsq_symmetric() -> unit ! { Test } = {
  v = simpsons(f_xsq, cast(-1.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(0.6666666, f32), cast(0.00001, f32), "simpsons: integral of x^2 over [-1,1] = 2/3")
}
def test_gl10_xsq_symmetric() -> unit ! { Test } = {
  v = gauss_legendre_10(f_xsq, cast(-1.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.6666666, f32), cast(0.00001, f32), "gauss_legendre_10: integral of x^2 over [-1,1] = 2/3")
}
def test_simp_xcube() -> unit ! { Test } = {
  v = simpsons(f_xcube, cast(0.0, f32), cast(1.0, f32), cast(10, int64))
  assert_close(v, cast(0.25, f32), cast(0.00001, f32), "simpsons: integral of x^3 over [0,1] = 0.25 (Simpson exact for cubic)")
}
def test_gl5_xcube() -> unit ! { Test } = {
  v = gauss_legendre_5(f_xcube, cast(0.0, f32), cast(1.0, f32), cast(5, int64))
  assert_close(v, cast(0.25, f32), cast(0.000001, f32), "gauss_legendre_5: integral of x^3 over [0,1] = 0.25")
}
def test_gl10_xcube() -> unit ! { Test } = {
  v = gauss_legendre_10(f_xcube, cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(0.25, f32), cast(0.000001, f32), "gauss_legendre_10: integral of x^3 over [0,1] = 0.25")
}
def test_simp_sin_0_pi() -> unit ! { Test } = {
  pi = cast(3.1415927, f32)
  v = simpsons(f_sin, cast(0.0, f32), pi, cast(64, int64))
  assert_close(v, cast(2.0, f32), cast(0.0001, f32), "simpsons: integral of sin over [0,pi] = 2")
}
def test_gl10_sin_0_pi() -> unit ! { Test } = {
  pi = cast(3.1415927, f32)
  v = gauss_legendre_10(f_sin, cast(0.0, f32), pi)
  assert_close(v, cast(2.0, f32), cast(0.00001, f32), "gauss_legendre_10: integral of sin over [0,pi] = 2")
}
def test_romberg_sin_0_pi() -> unit ! { Test } = {
  pi = cast(3.1415927, f32)
  v = romberg_5(f_sin, cast(0.0, f32), pi)
  assert_close(v, cast(2.0, f32), cast(0.0001, f32), "romberg_5: integral of sin over [0,pi] = 2")
}
def test_adapt_sin_0_pi() -> unit ! { Test } = {
  pi = cast(3.1415927, f32)
  v = adaptive_simpson(f_sin, cast(0.0, f32), pi, cast(0.000001, f32), cast(20, int64))
  assert_close(v, cast(2.0, f32), cast(0.0001, f32), "adaptive_simpson: integral of sin over [0,pi] = 2")
}
def test_gl10_sin_halfpi_pi() -> unit ! { Test } = {
  v = gauss_legendre_10(f_sin, cast(1.5707963, f32), cast(3.1415927, f32))
  assert_close(v, cast(1.0, f32), cast(0.00001, f32), "gauss_legendre_10: integral of sin over [pi/2,pi] = 1 (= antideriv of cos on [0,pi/2])")
}
def test_gl10_sin_period() -> unit ! { Test } = {
  two_pi = cast(6.2831853, f32)
  v = gauss_legendre_10(f_sin, cast(0.0, f32), two_pi)
  assert_close(v, cast(0.0, f32), cast(0.0001, f32), "gauss_legendre_10: integral of sin over [0,2pi] = 0 (full period)")
}
def test_simp_sin_period() -> unit ! { Test } = {
  two_pi = cast(6.2831853, f32)
  v = simpsons(f_sin, cast(0.0, f32), two_pi, cast(64, int64))
  assert_close(v, cast(0.0, f32), cast(0.0001, f32), "simpsons: integral of sin over [0,2pi] = 0 (full period)")
}
def test_simp_exp_0_1() -> unit ! { Test } = {
  v = simpsons(f_exp, cast(0.0, f32), cast(1.0, f32), cast(64, int64))
  assert_close(v, cast(1.7182818, f32), cast(0.00001, f32), "simpsons: integral of exp over [0,1] = e - 1")
}
def test_gl10_exp_0_1() -> unit ! { Test } = {
  v = gauss_legendre_10(f_exp, cast(0.0, f32), cast(1.0, f32))
  assert_close(v, cast(1.7182818, f32), cast(0.00001, f32), "gauss_legendre_10: integral of exp over [0,1] = e - 1")
}
def test_adapt_exp_0_1() -> unit ! { Test } = {
  v = adaptive_simpson(f_exp, cast(0.0, f32), cast(1.0, f32), cast(0.000001, f32), cast(20, int64))
  assert_close(v, cast(1.7182818, f32), cast(0.00001, f32), "adaptive_simpson: integral of exp over [0,1] = e - 1")
}
def test_gl10_recip_1_e() -> unit ! { Test } = {
  e = cast(2.7182817, f32)
  v = gauss_legendre_10(f_recip, cast(1.0, f32), e)
  assert_close(v, cast(1.0, f32), cast(0.00001, f32), "gauss_legendre_10: integral of 1/x over [1,e] = ln(e) - ln(1) = 1")
}
def test_romberg_recip_1_e() -> unit ! { Test } = {
  e = cast(2.7182817, f32)
  v = romberg_5(f_recip, cast(1.0, f32), e)
  assert_close(v, cast(1.0, f32), cast(0.0001, f32), "romberg_5: integral of 1/x over [1,e] = 1")
}
def test_consistency_trap_simp_sin() -> unit ! { Test } = {
  pi = cast(3.1415927, f32)
  vt = trapezoidal(f_sin, cast(0.0, f32), pi, cast(100, int64))
  vs = simpsons(f_sin, cast(0.0, f32), pi, cast(100, int64))
  assert_close(vt, vs, cast(0.001, f32), "trapezoidal vs simpsons agree within 1e-3 on smooth sin over [0,pi]")
}
def test_consistency_simp_gl5_xsq() -> unit ! { Test } = {
  vs = simpsons(f_xsq, cast(0.0, f32), cast(1.0, f32), cast(100, int64))
  vg = gauss_legendre_5(f_xsq, cast(0.0, f32), cast(1.0, f32), cast(5, int64))
  assert_close(vs, vg, cast(0.0001, f32), "simpsons vs gauss_legendre_5 agree within 1e-4 on smooth x^2 over [0,1]")
}
def test_consistency_gl10_romberg_sin() -> unit ! { Test } = {
  pi = cast(3.1415927, f32)
  vg = gauss_legendre_10(f_sin, cast(0.0, f32), pi)
  vr = romberg_5(f_sin, cast(0.0, f32), pi)
  assert_close(vg, vr, cast(0.0001, f32), "gauss_legendre_10 vs romberg_5 agree within 1e-4 on smooth sin over [0,pi]")
}
def test_consistency_gl10_adapt_exp() -> unit ! { Test } = {
  vg = gauss_legendre_10(f_exp, cast(0.0, f32), cast(1.0, f32))
  va = adaptive_simpson(f_exp, cast(0.0, f32), cast(1.0, f32), cast(0.000001, f32), cast(20, int64))
  assert_close(vg, va, cast(0.00001, f32), "gauss_legendre_10 vs adaptive_simpson agree within 1e-5 on smooth exp over [0,1]")
}
def test_hermite_const_one() -> unit ! { Test } = {
  v = gauss_hermite_10(f_one)
  assert_close(v, cast(1.7724539, f32), cast(0.0001, f32), "gauss_hermite_10(1) = integral of exp(-x^2) over R = sqrt(pi)")
}
def test_hermite_xsq_identity() -> unit ! { Test } = {
  v = gauss_hermite_10(f_xsq)
  assert_close(v, cast(0.8862269, f32), cast(0.0001, f32), "gauss_hermite_10(x^2) = sqrt(pi)/2")
}
def test_hermite_x_odd() -> unit ! { Test } = {
  v = gauss_hermite_10(f_x)
  assert_close(v, cast(0.0, f32), cast(0.000001, f32), "gauss_hermite_10(x) = 0 (odd integrand)")
}
def test_laguerre_const_one() -> unit ! { Test } = {
  v = gauss_laguerre_10(f_one)
  assert_close(v, cast(1.0, f32), cast(0.00001, f32), "gauss_laguerre_10(1) = integral of exp(-x) over [0,inf) = 1")
}
def test_laguerre_x_identity() -> unit ! { Test } = {
  v = gauss_laguerre_10(f_x)
  assert_close(v, cast(1.0, f32), cast(0.00001, f32), "gauss_laguerre_10(x) = gamma(2) = 1! = 1")
}
def test_laguerre_xsq_identity() -> unit ! { Test } = {
  v = gauss_laguerre_10(f_xsq)
  assert_close(v, cast(2.0, f32), cast(0.0001, f32), "gauss_laguerre_10(x^2) = gamma(3) = 2! = 2")
}
def test_adapt_sub_ulp_tol_plateau_terminates_sum() -> unit ! { Test } = {
  v = adaptive_simpson(f_one, cast(0.0, f32), cast(1.0, f32), cast(0.0, f32), cast(30, int64))
  assert_close(v, cast(1.0, f32), cast(0.000001, f32), "adaptive_simpson: plateau-stop terminates accumulated sum when sum_lr == whole bit-exact under zero tol (sub-f32-ULP regime)")
}
