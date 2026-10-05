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
  r = bisection(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(1.4142135, f32), cast(0.0001, f32), "bisection f(x)=x^2-2 -> sqrt(2)")
}
def test_bisection_sqrt3() -> unit ! { Test } = {
  r = bisection(root_xsq_minus_3, cast(1.0, f32), cast(2.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(1.7320508, f32), cast(0.0001, f32), "bisection f(x)=x^2-3 -> sqrt(3)")
}
def test_bisection_xsq_minus_1() -> unit ! { Test } = {
  r = bisection(root_xsq_minus_1, cast(0.0, f32), cast(2.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(1.0, f32), cast(0.0001, f32), "bisection f(x)=x^2-1 on [0,2] -> 1")
}
def test_bisection_trivial_linear() -> unit ! { Test } = {
  r = bisection(root_x_minus_1, cast(0.0, f32), cast(2.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(1.0, f32), cast(0.0001, f32), "bisection f(x)=x-1 -> 1")
}
def test_newton_sqrt2() -> unit ! { Test } = {
  r = newton(root_xsq_minus_2, root_xsq_minus_2_deriv, cast(1.5, f32), cast(1e-6, f32), cast(50, i64))
  assert_close(r, cast(1.4142135, f32), cast(0.00001, f32), "newton f(x)=x^2-2 -> sqrt(2)")
}
def test_newton_sqrt3() -> unit ! { Test } = {
  r = newton(root_xsq_minus_3, root_xsq_minus_3_deriv, cast(2.0, f32), cast(1e-6, f32), cast(50, i64))
  assert_close(r, cast(1.7320508, f32), cast(0.00001, f32), "newton f(x)=x^2-3 -> sqrt(3)")
}
def test_newton_ln2() -> unit ! { Test } = {
  r = newton(root_exp_minus_2, root_exp_minus_2_deriv, cast(1.0, f32), cast(1e-6, f32), cast(50, i64))
  assert_close(r, cast(0.6931471, f32), cast(0.00001, f32), "newton f(x)=exp(x)-2 -> ln(2)")
}
def test_newton_trivial_linear() -> unit ! { Test } = {
  r = newton(root_x_minus_1, root_x_minus_1_deriv, cast(5.0, f32), cast(1e-6, f32), cast(50, i64))
  assert_close(r, cast(1.0, f32), cast(0.00001, f32), "newton f(x)=x-1 -> 1")
}
def test_brent_sqrt2() -> unit ! { Test } = {
  r = brent(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(1.4142135, f32), cast(0.00001, f32), "brent f(x)=x^2-2 -> sqrt(2)")
}
def test_brent_sqrt3() -> unit ! { Test } = {
  r = brent(root_xsq_minus_3, cast(1.0, f32), cast(2.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(1.7320508, f32), cast(0.00001, f32), "brent f(x)=x^2-3 -> sqrt(3)")
}
def test_brent_ln2() -> unit ! { Test } = {
  r = brent(root_exp_minus_2, cast(0.0, f32), cast(1.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(0.6931471, f32), cast(0.00001, f32), "brent f(x)=exp(x)-2 -> ln(2)")
}
def test_bisection_root_above_lo() -> unit ! { Test } = {
  r = bisection(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_true(gt(r, cast(1.0, f32)), "bisection root > 1")
}
def test_bisection_root_below_hi() -> unit ! { Test } = {
  r = bisection(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_true(lt(r, cast(2.0, f32)), "bisection root < 2")
}
def is_nan(x: f32) -> bool = neq(x, x)
def root_nan_everywhere(_x: f32) -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def root_unit_slope(_x: f32) -> f32 = cast(1.0, f32)
def root_bracketed_nan_inside(x: f32) -> f32 = if lte(x, cast(-0.5, f32)) then neg(cast(1.0, f32)) else if gte(x, cast(2.0, f32)) then cast(1.0, f32) else div(cast(0.0, f32), cast(0.0, f32))
def root_minus_inf_at_lo(x: f32) -> f32 = if lte(x, cast(-0.5, f32)) then neg(div(cast(1.0, f32), cast(0.0, f32))) else sub(x, cast(1.0, f32))
def test_bisection_nan_residual_is_nan() -> unit ! { Test } = {
  r = bisection(root_nan_everywhere, cast(-0.5, f32), cast(2.0, f32), cast(1e-7, f32), cast(100000, i64))
  assert_true(is_nan(r), "bisection on a nowhere-finite residual is NaN, not a point in the collapsed bracket")
}
def test_brent_nan_residual_is_nan() -> unit ! { Test } = {
  r = brent(root_nan_everywhere, cast(-0.5, f32), cast(2.0, f32), cast(1e-7, f32), cast(100000, i64))
  assert_true(is_nan(r), "brent on a nowhere-finite residual is NaN without consuming the budget")
}
def test_newton_nan_residual_is_nan() -> unit ! { Test } = {
  r = newton(root_nan_everywhere, root_unit_slope, cast(1.0, f32), cast(1e-7, f32), cast(100000, i64))
  assert_true(is_nan(r), "newton on a nowhere-finite residual is NaN without consuming the budget")
}
def test_bisection_nan_inside_a_valid_bracket_is_nan() -> unit ! { Test } = {
  r = bisection(root_bracketed_nan_inside, cast(-0.5, f32), cast(2.0, f32), cast(1e-7, f32), cast(100000, i64))
  assert_true(is_nan(r), "bisection reports NaN when the endpoints bracket but an interior residual is NaN")
}
def test_brent_nan_inside_a_valid_bracket_is_nan() -> unit ! { Test } = {
  r = brent(root_bracketed_nan_inside, cast(-0.5, f32), cast(2.0, f32), cast(1e-7, f32), cast(100000, i64))
  assert_true(is_nan(r), "brent reports NaN when the endpoints bracket but an interior residual is NaN")
}
def test_newton_nan_derivative_is_nan() -> unit ! { Test } = {
  r = newton(root_xsq_minus_2, root_nan_everywhere, cast(1.5, f32), cast(1e-6, f32), cast(100000, i64))
  assert_true(is_nan(r), "newton reports NaN for a NaN derivative, as it does for a near-zero one")
}
def test_brent_nan_tolerance_is_nan() -> unit ! { Test } = {
  r = brent(root_xsq_minus_2, cast(1.0, f32), cast(2.0, f32), div(cast(0.0, f32), cast(0.0, f32)), cast(100000, i64))
  assert_true(is_nan(r), "a NaN tolerance is rejected rather than disabling every stopping condition")
}
def test_brent_nan_bracket_endpoint_is_nan() -> unit ! { Test } = {
  r = brent(root_xsq_minus_2, div(cast(0.0, f32), cast(0.0, f32)), cast(2.0, f32), cast(1e-6, f32), cast(100000, i64))
  assert_true(is_nan(r), "a NaN bracket endpoint is rejected")
}
def test_brent_same_sign_bracket_is_nan() -> unit ! { Test } = {
  r = brent(root_xsq_minus_1, cast(2.0, f32), cast(3.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_true(is_nan(r), "brent still returns NaN when f(lo) and f(hi) share a sign")
}
def test_bisection_infinite_endpoint_residual_finds_the_root() -> unit ! { Test } = {
  r = bisection(root_minus_inf_at_lo, cast(-0.5, f32), cast(2.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(1.0, f32), cast(0.0001, f32), "an infinite endpoint residual still carries a sign, so bisection converges")
}
def test_brent_infinite_endpoint_residual_finds_the_root() -> unit ! { Test } = {
  r = brent(root_minus_inf_at_lo, cast(-0.5, f32), cast(2.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(1.0, f32), cast(0.0001, f32), "an infinite endpoint residual still carries a sign, so brent converges")
}
def root_sign_only(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(cast(1.0, f32)) else cast(1.0, f32)
def test_bisection_unbounded_bracket_is_nan() -> unit ! { Test } = {
  inf = div(cast(1.0, f32), cast(0.0, f32))
  r = bisection(root_sign_only, neg(inf), inf, cast(1e-6, f32), cast(100000, i64))
  assert_true(is_nan(r), "an unbounded bracket has a NaN midpoint, which bisection reports rather than iterating on")
}
def test_brent_unbounded_bracket_is_nan() -> unit ! { Test } = {
  inf = div(cast(1.0, f32), cast(0.0, f32))
  r = brent(root_sign_only, neg(inf), inf, cast(1e-6, f32), cast(100000, i64))
  assert_true(is_nan(r), "and so does brent, whose trial point is NaN for the same reason")
}
