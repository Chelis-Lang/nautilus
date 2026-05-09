module Nautilus.Tests.Roots
import Nautilus.Roots (bisection, newton, brent)
import Std.Test (assert_close, assert_true)
def root_xsq_minus_2(x: f32) -> f32 = sub(mul(x, x), cast(2.0, f32))
def root_xsq_minus_2_deriv(x: f32) -> f32 = mul(cast(2.0, f32), x)
def root_xsq_minus_3(x: f32) -> f32 = sub(mul(x, x), cast(3.0, f32))
def root_xsq_minus_3_deriv(x: f32) -> f32 = mul(cast(2.0, f32), x)
def root_xsq_minus_1(x: f32) -> f32 = sub(mul(x, x), cast(1.0, f32))
def root_exp_minus_2(x: f32) -> f32 = sub(exp(x), cast(2.0, f32))
def root_exp_minus_2_deriv(x: f32) -> f32 = exp(x)
def root_x_minus_1(x: f32) -> f32 = sub(x, cast(1.0, f32))
def root_x_minus_1_deriv(_x: f32) -> f32 = cast(1.0, f32)
def test_bisection_sqrt2() -> unit ! { Test } = {
  r = bisection(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32), cast(0.000001, f32), cast(100, int64))
  assert_close(r, cast(1.4142135, f32), cast(0.0001, f32), "bisection f(x)=x^2-2 -> sqrt(2)")
}
def test_bisection_sqrt3() -> unit ! { Test } = {
  r = bisection(root_xsq_minus_3, cast(1.0, f32), cast(2.0, f32), cast(0.000001, f32), cast(100, int64))
  assert_close(r, cast(1.7320508, f32), cast(0.0001, f32), "bisection f(x)=x^2-3 -> sqrt(3)")
}
def test_bisection_xsq_minus_1() -> unit ! { Test } = {
  r = bisection(root_xsq_minus_1, cast(0.0, f32), cast(2.0, f32), cast(0.000001, f32), cast(100, int64))
  assert_close(r, cast(1.0, f32), cast(0.0001, f32), "bisection f(x)=x^2-1 on [0,2] -> 1")
}
def test_bisection_trivial_linear() -> unit ! { Test } = {
  r = bisection(root_x_minus_1, cast(0.0, f32), cast(2.0, f32), cast(0.000001, f32), cast(100, int64))
  assert_close(r, cast(1.0, f32), cast(0.0001, f32), "bisection f(x)=x-1 -> 1")
}
def test_newton_sqrt2() -> unit ! { Test } = {
  r = newton(root_xsq_minus_2, root_xsq_minus_2_deriv, cast(1.5, f32), cast(0.000001, f32), cast(50, int64))
  assert_close(r, cast(1.4142135, f32), cast(0.00001, f32), "newton f(x)=x^2-2 -> sqrt(2)")
}
def test_newton_sqrt3() -> unit ! { Test } = {
  r = newton(root_xsq_minus_3, root_xsq_minus_3_deriv, cast(2.0, f32), cast(0.000001, f32), cast(50, int64))
  assert_close(r, cast(1.7320508, f32), cast(0.00001, f32), "newton f(x)=x^2-3 -> sqrt(3)")
}
def test_newton_ln2() -> unit ! { Test } = {
  r = newton(root_exp_minus_2, root_exp_minus_2_deriv, cast(1.0, f32), cast(0.000001, f32), cast(50, int64))
  assert_close(r, cast(0.6931471, f32), cast(0.00001, f32), "newton f(x)=exp(x)-2 -> ln(2)")
}
def test_newton_trivial_linear() -> unit ! { Test } = {
  r = newton(root_x_minus_1, root_x_minus_1_deriv, cast(5.0, f32), cast(0.000001, f32), cast(50, int64))
  assert_close(r, cast(1.0, f32), cast(0.00001, f32), "newton f(x)=x-1 -> 1")
}
def test_brent_sqrt2() -> unit ! { Test } = {
  r = brent(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32), cast(0.000001, f32), cast(100, int64))
  assert_close(r, cast(1.4142135, f32), cast(0.00001, f32), "brent f(x)=x^2-2 -> sqrt(2)")
}
def test_brent_sqrt3() -> unit ! { Test } = {
  r = brent(root_xsq_minus_3, cast(1.0, f32), cast(2.0, f32), cast(0.000001, f32), cast(100, int64))
  assert_close(r, cast(1.7320508, f32), cast(0.00001, f32), "brent f(x)=x^2-3 -> sqrt(3)")
}
def test_brent_ln2() -> unit ! { Test } = {
  r = brent(root_exp_minus_2, cast(0.0, f32), cast(1.0, f32), cast(0.000001, f32), cast(100, int64))
  assert_close(r, cast(0.6931471, f32), cast(0.00001, f32), "brent f(x)=exp(x)-2 -> ln(2)")
}
def test_bisection_root_above_lo() -> unit ! { Test } = {
  r = bisection(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32), cast(0.000001, f32), cast(100, int64))
  assert_true(gt(r, cast(1.0, f32)), "bisection root > 1")
}
def test_bisection_root_below_hi() -> unit ! { Test } = {
  r = bisection(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32), cast(0.000001, f32), cast(100, int64))
  assert_true(lt(r, cast(2.0, f32)), "bisection root < 2")
}
