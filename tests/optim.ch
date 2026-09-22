module Nautilus.Tests.Optim
import Nautilus.Optim (golden_section_search, brent_minimize, gradient_descent_1d, newton_minimize_1d)
import Std.Test (assert_close, assert_true)
def opt_parab_3(x: f32) -> f32 = {
  d = sub(x, cast(3.0, f32))
  mul(d, d)
}
def opt_dparab_3(x: f32) -> f32 = mul(cast(2.0, f32), sub(x, cast(3.0, f32)))
def opt_ddparab_3(x: f32) -> f32 = cast(2.0, f32)
def opt_parab_neg2(x: f32) -> f32 = {
  d = add(x, cast(2.0, f32))
  mul(d, d)
}
def opt_dparab_neg2(x: f32) -> f32 = mul(cast(2.0, f32), add(x, cast(2.0, f32)))
def opt_ddparab_neg2(x: f32) -> f32 = cast(2.0, f32)
def opt_quartic_sqrt2(x: f32) -> f32 = {
  d = sub(mul(x, x), cast(2.0, f32))
  mul(d, d)
}
def opt_dquartic_sqrt2(x: f32) -> f32 = {
  inner = sub(mul(x, x), cast(2.0, f32))
  mul(mul(cast(4.0, f32), x), inner)
}
def opt_ddquartic_sqrt2(x: f32) -> f32 = sub(mul(cast(12.0, f32), mul(x, x)), cast(8.0, f32))
def opt_quartic_at_1(x: f32) -> f32 = {
  x2 = mul(x, x)
  x4 = mul(x2, x2)
  sub(x4, mul(cast(2.0, f32), x2))
}
def opt_dquartic_at_1(x: f32) -> f32 = {
  x3 = mul(x, mul(x, x))
  sub(mul(cast(4.0, f32), x3), mul(cast(4.0, f32), x))
}
def opt_ddquartic_at_1(x: f32) -> f32 = sub(mul(cast(12.0, f32), mul(x, x)), cast(4.0, f32))
def opt_cos(x: f32) -> f32 = sin(add(x, cast(1.5707963, f32)))
def test_golden_parabola_at_3() -> unit ! { Test } = {
  xmin = golden_section_search(opt_parab_3, cast(0.0, f32), cast(5.0, f32), cast(1e-7, f32), cast(200, i64))
  assert_close(xmin, cast(3.0, f32), cast(0.0001, f32), "golden section: minimizer of (x-3)^2 is x = 3")
}
def test_golden_parabola_min_value_zero() -> unit ! { Test } = {
  xmin = golden_section_search(opt_parab_3, cast(0.0, f32), cast(5.0, f32), cast(1e-7, f32), cast(200, i64))
  fmin = opt_parab_3(xmin)
  assert_close(fmin, cast(0.0, f32), cast(1e-6, f32), "f(xmin) = 0 for (x-3)^2")
}
def test_golden_parabola_at_neg2() -> unit ! { Test } = {
  xmin = golden_section_search(opt_parab_neg2, cast(-5.0, f32), cast(0.0, f32), cast(1e-7, f32), cast(200, i64))
  assert_close(xmin, cast(-2.0, f32), cast(0.0001, f32), "golden section: minimizer of (x+2)^2 is x = -2")
}
def test_golden_quartic_at_sqrt2() -> unit ! { Test } = {
  xmin = golden_section_search(opt_quartic_sqrt2, cast(1.0, f32), cast(2.0, f32), cast(1e-7, f32), cast(200, i64))
  assert_close(xmin, cast(1.4142135, f32), cast(0.0001, f32), "golden section: minimizer of (x^2-2)^2 on [1,2] is sqrt(2)")
}
def test_golden_quartic_at_1() -> unit ! { Test } = {
  xmin = golden_section_search(opt_quartic_at_1, cast(0.5, f32), cast(2.0, f32), cast(1e-7, f32), cast(200, i64))
  assert_close(xmin, cast(1.0, f32), cast(0.0001, f32), "golden section: minimizer of x^4 - 2x^2 on [0.5, 2] is x = 1")
}
def test_golden_cos_at_pi() -> unit ! { Test } = {
  xmin = golden_section_search(opt_cos, cast(0.0, f32), cast(3.1415927, f32), cast(1e-7, f32), cast(200, i64))
  assert_close(xmin, cast(3.1415927, f32), cast(0.001, f32), "golden section: minimizer of cos(x) on [0, pi] is ~pi")
}
def test_brent_parabola_at_3() -> unit ! { Test } = {
  xmin = brent_minimize(opt_parab_3, cast(0.0, f32), cast(5.0, f32), cast(1e-7, f32), cast(200, i64))
  assert_close(xmin, cast(3.0, f32), cast(0.0001, f32), "brent: minimizer of (x-3)^2 is x = 3")
}
def test_brent_quartic_at_sqrt2() -> unit ! { Test } = {
  xmin = brent_minimize(opt_quartic_sqrt2, cast(1.0, f32), cast(2.0, f32), cast(1e-7, f32), cast(200, i64))
  assert_close(xmin, cast(1.4142135, f32), cast(0.0001, f32), "brent: minimizer of (x^2-2)^2 on [1,2] is sqrt(2)")
}
def test_brent_min_value_zero() -> unit ! { Test } = {
  xmin = brent_minimize(opt_parab_neg2, cast(-5.0, f32), cast(0.0, f32), cast(1e-7, f32), cast(200, i64))
  fmin = opt_parab_neg2(xmin)
  assert_close(fmin, cast(0.0, f32), cast(1e-6, f32), "f(xmin) = 0 for (x+2)^2 via brent")
}
def test_gd_parabola_at_3() -> unit ! { Test } = {
  xmin = gradient_descent_1d(opt_parab_3, opt_dparab_3, cast(0.0, f32), cast(0.1, f32), cast(500, i64))
  assert_close(xmin, cast(3.0, f32), cast(0.0001, f32), "gradient descent: minimizer of (x-3)^2 is x = 3")
}
def test_gd_parabola_at_neg2() -> unit ! { Test } = {
  xmin = gradient_descent_1d(opt_parab_neg2, opt_dparab_neg2, cast(0.0, f32), cast(0.1, f32), cast(500, i64))
  assert_close(xmin, cast(-2.0, f32), cast(0.0001, f32), "gradient descent: minimizer of (x+2)^2 is x = -2")
}
def test_newton_parabola_at_3() -> unit ! { Test } = {
  xmin = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_ddparab_3, cast(0.0, f32), cast(1e-7, f32), cast(50, i64))
  assert_close(xmin, cast(3.0, f32), cast(0.00001, f32), "newton: minimizer of (x-3)^2 is x = 3")
}
def test_newton_quartic_at_sqrt2() -> unit ! { Test } = {
  xmin = newton_minimize_1d(opt_quartic_sqrt2, opt_dquartic_sqrt2, opt_ddquartic_sqrt2, cast(1.2, f32), cast(1e-7, f32), cast(100, i64))
  assert_close(xmin, cast(1.4142135, f32), cast(0.0001, f32), "newton: minimizer of (x^2-2)^2 near 1.2 is sqrt(2)")
}
def test_newton_quartic_at_1() -> unit ! { Test } = {
  xmin = newton_minimize_1d(opt_quartic_at_1, opt_dquartic_at_1, opt_ddquartic_at_1, cast(0.8, f32), cast(1e-7, f32), cast(100, i64))
  assert_close(xmin, cast(1.0, f32), cast(0.0001, f32), "newton: minimizer of x^4 - 2x^2 from x0=0.8 is x = 1")
}
def test_golden_bracket_containment() -> unit ! { Test } = {
  a = cast(0.0, f32)
  b = cast(5.0, f32)
  xmin = golden_section_search(opt_parab_3, a, b, cast(1e-7, f32), cast(200, i64))
  assert_true(and(gt(xmin, a), gt(b, xmin)), "golden section: result lies in (a, b)")
}
def test_brent_bracket_containment() -> unit ! { Test } = {
  a = cast(1.0, f32)
  b = cast(2.0, f32)
  xmin = brent_minimize(opt_quartic_sqrt2, a, b, cast(1e-7, f32), cast(200, i64))
  assert_true(and(gt(xmin, a), gt(b, xmin)), "brent: result lies in (a, b)")
}
def test_golden_convergence_tighter_tol() -> unit ! { Test } = {
  xmin_loose = golden_section_search(opt_parab_3, cast(0.0, f32), cast(5.0, f32), cast(0.01, f32), cast(200, i64))
  xmin_tight = golden_section_search(opt_parab_3, cast(0.0, f32), cast(5.0, f32), cast(1e-7, f32), cast(200, i64))
  truth = cast(3.0, f32)
  diff_loose = sub(xmin_loose, truth)
  diff_tight = sub(xmin_tight, truth)
  err_loose = if lt(diff_loose, cast(0.0, f32)) then neg(diff_loose) else diff_loose
  err_tight = if lt(diff_tight, cast(0.0, f32)) then neg(diff_tight) else diff_tight
  assert_true(lte(err_tight, err_loose), "golden section: tighter tol gives error <= looser tol")
}
