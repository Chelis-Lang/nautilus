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
def opt_is_nan(x: f32) -> bool = neq(x, x)
def opt_quiet_nan() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def opt_nan_everywhere(_x: f32) -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def test_golden_nan_objective_is_nan() -> unit ! { Test } = {
  r = golden_section_search(opt_nan_everywhere, cast(-0.5, f32), cast(2.0, f32), cast(1e-7, f32), cast(100, i64))
  assert_true(opt_is_nan(r), "golden section reports NaN for an objective with no values, not a point near hi")
}
def test_golden_nan_objective_large_budget_is_nan() -> unit ! { Test } = {
  r = golden_section_search(opt_nan_everywhere, cast(-0.5, f32), cast(2.0, f32), cast(1e-7, f32), cast(100000, i64))
  assert_true(opt_is_nan(r), "and reports it without exhausting a large budget first")
}
def test_brent_minimize_nan_objective_is_nan() -> unit ! { Test } = {
  r = brent_minimize(opt_nan_everywhere, cast(-0.5, f32), cast(2.0, f32), cast(1e-7, f32), cast(100000, i64))
  assert_true(opt_is_nan(r), "brent_minimize reports NaN for an objective with no values, not an interior point")
}
def test_golden_nan_bracket_endpoint_is_nan() -> unit ! { Test } = {
  r = golden_section_search(opt_parab_3, opt_quiet_nan(), cast(5.0, f32), cast(1e-6, f32), cast(100000, i64))
  assert_true(opt_is_nan(r), "golden section rejects a NaN bracket endpoint")
}
def test_brent_minimize_nan_bracket_endpoint_is_nan() -> unit ! { Test } = {
  r = brent_minimize(opt_parab_3, opt_quiet_nan(), cast(5.0, f32), cast(1e-6, f32), cast(100000, i64))
  assert_true(opt_is_nan(r), "brent_minimize rejects a NaN bracket endpoint")
}
def test_golden_nan_tolerance_is_nan() -> unit ! { Test } = {
  r = golden_section_search(opt_parab_3, cast(1.0, f32), cast(5.0, f32), opt_quiet_nan(), cast(100000, i64))
  assert_true(opt_is_nan(r), "a NaN tolerance is rejected rather than disabling the width stopping condition")
}
def test_brent_minimize_nan_tolerance_is_nan() -> unit ! { Test } = {
  r = brent_minimize(opt_parab_3, cast(1.0, f32), cast(5.0, f32), opt_quiet_nan(), cast(100000, i64))
  assert_true(opt_is_nan(r), "and brent_minimize rejects it too")
}
def test_gradient_descent_nan_gradient_is_nan() -> unit ! { Test } = {
  r = gradient_descent_1d(opt_parab_3, opt_nan_everywhere, cast(5.0, f32), cast(0.1, f32), cast(100000, i64))
  assert_true(opt_is_nan(r), "gradient_descent_1d already reported NaN for a NaN gradient; this pins it")
}
def test_newton_minimize_nan_derivatives_are_nan() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_nan_everywhere, opt_ddparab_3, cast(5.0, f32), cast(1e-6, f32), cast(100000, i64))
  _ = assert_true(opt_is_nan(r1), "newton_minimize_1d reports NaN for a NaN first derivative")
  r2 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_nan_everywhere, cast(5.0, f32), cast(1e-6, f32), cast(100000, i64))
  assert_true(opt_is_nan(r2), "and for a NaN second derivative")
}
def test_golden_finite_objective_unchanged_by_the_nan_guard() -> unit ! { Test } = {
  r = golden_section_search(opt_parab_3, cast(1.0, f32), cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(3.0, f32), cast(0.001, f32), "the NaN guard never fires on a finite objective")
}
def test_brent_minimize_finite_objective_unchanged_by_the_nan_guard() -> unit ! { Test } = {
  r = brent_minimize(opt_parab_3, cast(1.0, f32), cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(3.0, f32), cast(0.001, f32), "and brent_minimize is unchanged too")
}
def test_newton_minimize_nan_curvature_at_the_converged_point_is_nan() -> unit ! { Test } = {
  r = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_nan_everywhere, cast(3.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_true(opt_is_nan(r), "a NaN second derivative cannot verify positive curvature, so the converged point is not returned as a minimum")
}
def test_newton_minimize_nan_start_point_is_nan() -> unit ! { Test } = {
  r = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_ddparab_3, opt_quiet_nan(), cast(1e-6, f32), cast(100000, i64))
  assert_true(opt_is_nan(r), "newton_minimize_1d rejects a NaN starting point")
}
def test_newton_minimize_nan_tolerance_is_nan() -> unit ! { Test } = {
  r = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_ddparab_3, cast(5.0, f32), opt_quiet_nan(), cast(100000, i64))
  assert_true(opt_is_nan(r), "and a NaN tolerance, which otherwise forces every iteration to take the step branch")
}
