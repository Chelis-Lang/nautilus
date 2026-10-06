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
def test_golden_nan_tolerance_behaves_as_a_zero_tolerance() -> unit ! { Test } = {
  nan_tol = golden_section_search(opt_parab_3, cast(1.0, f32), cast(5.0, f32), opt_quiet_nan(), cast(40, i64))
  zero_tol = golden_section_search(opt_parab_3, cast(1.0, f32), cast(5.0, f32), cast(0.0, f32), cast(40, i64))
  _ = assert_true(eq(nan_tol, zero_tol), "a NaN tolerance is not rejected: it disables the width exit, which is what a zero tolerance does")
  assert_close(nan_tol, cast(3.0, f32), cast(0.001, f32), "and it still converges")
}
def test_brent_minimize_nan_tolerance_behaves_as_a_zero_tolerance() -> unit ! { Test } = {
  nan_tol = brent_minimize(opt_parab_3, cast(1.0, f32), cast(5.0, f32), opt_quiet_nan(), cast(40, i64))
  zero_tol = brent_minimize(opt_parab_3, cast(1.0, f32), cast(5.0, f32), cast(0.0, f32), cast(40, i64))
  _ = assert_true(eq(nan_tol, zero_tol), "same for brent_minimize")
  assert_close(nan_tol, cast(3.0, f32), cast(0.001, f32), "and it still converges")
}
def test_newton_minimize_nan_tolerance_still_converges() -> unit ! { Test } = {
  r = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_ddparab_3, cast(5.0, f32), opt_quiet_nan(), cast(100, i64))
  assert_close(r, cast(3.0, f32), cast(0.001, f32), "a NaN tolerance forces every step but still reaches the minimiser")
}
def opt_nan_band_above(x: f32) -> f32 =
  if (gt(x, cast(3.4, f32)) |> and(lt(x, cast(3.6, f32)))) then div(cast(0.0, f32), cast(0.0, f32)) else {
    y = sub(x, cast(3.0, f32))
    mul(y, y)
  }
def opt_nan_band_at_two(x: f32) -> f32 =
  if (gt(x, cast(1.9, f32)) |> and(lt(x, cast(2.1, f32)))) then div(cast(0.0, f32), cast(0.0, f32)) else {
    y = sub(x, cast(3.0, f32))
    mul(y, y)
  }
def test_golden_partially_defined_objective_reports_the_nan_it_reaches() -> unit ! { Test } = {
  r = golden_section_search(opt_nan_band_above, cast(1.0, f32), cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_true(opt_is_nan(r), "golden section probes 3.472, so a NaN band there is reported instead of parking on its edge")
}
def test_golden_unreached_nan_region_does_not_change_the_answer() -> unit ! { Test } = {
  r = golden_section_search(opt_nan_band_at_two, cast(1.0, f32), cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(3.0, f32), cast(0.001, f32), "and a NaN band golden section never probes leaves the result untouched")
}
def test_brent_minimize_partially_defined_objective_reports_the_nan_it_reaches() -> unit ! { Test } = {
  r = brent_minimize(opt_nan_band_at_two, cast(1.0, f32), cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_true(opt_is_nan(r), "brent_minimize seeds at the quarter point 2.0, so the same band is inside its sample set")
}
def opt_inf() -> f32 = div(cast(1.0, f32), cast(0.0, f32))
def opt_inf_curvature(_x: f32) -> f32 = div(cast(1.0, f32), cast(0.0, f32))
def opt_neg_inf_curvature(_x: f32) -> f32 = neg(div(cast(1.0, f32), cast(0.0, f32)))
def opt_huge_curvature(_x: f32) -> f32 = cast(1e30, f32)
def opt_huge_neg_curvature(_x: f32) -> f32 = cast(-1e30, f32)
def opt_curvature_below_floor(_x: f32) -> f32 = cast(0.005, f32)
def opt_curvature_below_step_guard(_x: f32) -> f32 = cast(1e-35, f32)
def opt_inf_gradient(_x: f32) -> f32 = div(cast(1.0, f32), cast(0.0, f32))
def opt_unit_gradient(_x: f32) -> f32 = cast(1.0, f32)
def opt_dflat_3(x: f32) -> f32 = mul(cast(0.002, f32), sub(x, cast(3.0, f32)))
def opt_ddflat_3(_x: f32) -> f32 = cast(0.002, f32)
def opt_feeble_dparab_3(x: f32) -> f32 = mul(cast(1e-30, f32), sub(x, cast(3.0, f32)))
def opt_dsteep_3(x: f32) -> f32 = mul(cast(2e30, f32), sub(x, cast(3.0, f32)))
def opt_late_inf_curvature(x: f32) -> f32 = if lt(x, cast(4.5, f32)) then div(cast(1.0, f32), cast(0.0, f32)) else cast(2.0, f32)
def opt_late_neg_inf_curvature(x: f32) -> f32 = if lt(x, cast(4.5, f32)) then neg(div(cast(1.0, f32), cast(0.0, f32))) else cast(2.0, f32)
def opt_concave_3(x: f32) -> f32 = {
  d = sub(x, cast(3.0, f32))
  neg(mul(d, d))
}
def opt_dconcave_3(x: f32) -> f32 = mul(cast(-2.0, f32), sub(x, cast(3.0, f32)))
def opt_ddconcave_3(_x: f32) -> f32 = cast(-2.0, f32)
def test_newton_minimize_infinite_curvature_does_not_return_the_start_point() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_inf_curvature, cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r1), "an infinite second derivative makes the Newton step zero, so the iterate stalls at a point whose gradient is 4; a stall on a non-finite quantity is not a minimiser and is not returned as one")
  r2 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_neg_inf_curvature, cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r2), "and the same for a negative infinity, where the start point was returned rather than rejected by the sign test")
  r3 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_inf_curvature, cast(5.0, f32), cast(1e-6, f32), cast(10000, i64))
  assert_true(opt_is_nan(r3), "a larger iteration budget cannot unstall it either")
}
def test_newton_minimize_stall_runs_the_curvature_check() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_huge_neg_curvature, cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r1), "a curvature of -1e30 underflows the step so the iterate stalls, and the stalled point is now certified rather than returned, so the negative sign is caught")
  r2 = newton_minimize_1d(opt_concave_3, opt_dconcave_3, opt_ddconcave_3, cast(5.0, f32), cast(0.0, f32), cast(1000, i64))
  assert_true(opt_is_nan(r2), "and Newton on a concave objective at tol = 0 stalls at the maximiser, which the same check rejects")
}
def opt_one_ulp_above_3() -> f32 = add(cast(3.0, f32), cast(2.4e-7, f32))
def test_newton_minimize_stall_near_a_minimiser_needs_a_positive_tolerance() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_inf_curvature, opt_one_ulp_above_3(), cast(1e-6, f32), cast(100, i64))
  _ = assert_close(r1, cast(3.0, f32), cast(0.001, f32), "one ulp from the minimiser with an infinite curvature, a positive tolerance accepts the gradient of 4.8e-7 and the point is returned")
  r2 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_inf_curvature, opt_one_ulp_above_3(), cast(0.0, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r2), "at tol = 0 the same call is NaN: the gradient is not exactly zero, the step underflows, and an infinite curvature cannot certify the stall. This is a real loss against the old behaviour and the documented limit of what one point can tell the method")
  r3 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_huge_curvature, opt_one_ulp_above_3(), cast(0.0, f32), cast(100, i64))
  assert_close(r3, cast(3.0, f32), cast(0.001, f32), "while a finite 1e30 curvature at the same point and tolerance still returns it, which is the asymmetry: finiteness is the only discriminator available, not a claim that 1e30 is better evidence than infinity")
}
def opt_zero_gradient(_x: f32) -> f32 = cast(0.0, f32)
def opt_square(x: f32) -> f32 = mul(x, x)
def opt_dsquare(x: f32) -> f32 = mul(cast(2.0, f32), x)
def opt_ddsquare(_x: f32) -> f32 = cast(2.0, f32)
def test_newton_minimize_never_certifies_a_non_finite_point() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_zero_gradient, opt_ddparab_3, opt_inf(), cast(0.0, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r1), "a gradient that is zero everywhere makes an infinite starting point satisfy the convergence test, so the finiteness requirement belongs in the certification rather than on the stall path alone")
  r2 = newton_minimize_1d(opt_parab_3, opt_zero_gradient, opt_ddparab_3, neg(opt_inf()), cast(0.0, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r2), "and at negative infinity")
  r3 = newton_minimize_1d(opt_parab_3, opt_zero_gradient, opt_ddparab_3, opt_inf(), cast(1e-6, f32), cast(100, i64))
  assert_true(opt_is_nan(r3), "and at a positive tolerance, where lt(0, tol) reaches the same certification")
}
def test_newton_minimize_returns_the_point_it_stopped_on_signed_zero_included() -> unit ! { Test } = {
  r = newton_minimize_1d(opt_square, opt_dsquare, opt_ddsquare, cast(-0.0, f32), cast(0.0, f32), cast(100, i64))
  recip = div(cast(1.0, f32), r)
  _ = assert_true(lt(recip, cast(0.0, f32)), "the certified point is x itself, so a negative zero start is returned as a negative zero; the previous code returned x - x/2 and so normalised it to positive zero. assert_close cannot see this, hence the reciprocal")
  assert_close(r, cast(0.0, f32), cast(1e-9, f32), "either zero is the minimiser of x^2, so this pins the sign rather than the value")
}
def opt_scaled_parab_3(x: f32) -> f32 = {
  d = sub(x, cast(3.0, f32))
  mul(cast(2e38, f32), mul(d, d))
}
def opt_dscaled_parab_3(x: f32) -> f32 = mul(cast(2.0, f32), mul(cast(2e38, f32), sub(x, cast(3.0, f32))))
def opt_ddscaled_parab_3(_x: f32) -> f32 = mul(cast(2.0, f32), cast(2e38, f32))
def test_newton_minimize_overflowing_curvature_has_no_tolerance_remedy() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_scaled_parab_3, opt_dscaled_parab_3, opt_ddscaled_parab_3, opt_one_ulp_above_3(), cast(1e-6, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r1), "2e38*(x-3)^2 has a correct ddf of 4e38, which overflows f32 to +inf while its df stays finite at 9.5e31, so one ulp from the minimiser the step underflows and the stall cannot be certified")
  r2 = newton_minimize_1d(opt_scaled_parab_3, opt_dscaled_parab_3, opt_ddscaled_parab_3, opt_one_ulp_above_3(), cast(1.0, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r2), "and no usable tolerance recovers it: the escape needs tol above |df(x)| = 9.5e31, so unlike the unscaled case a positive tolerance is not a remedy here")
  r3 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_inf_curvature, opt_one_ulp_above_3(), cast(1e-9, f32), cast(100, i64))
  assert_true(opt_is_nan(r3), "and the unscaled case loses it too once tol drops below its 4.8e-7 gradient, which is why the remedy is stated as a bound rather than as any positive tolerance")
}
def opt_shallow_quartic(x: f32) -> f32 = {
  d = sub(mul(x, x), cast(2.0, f32))
  mul(cast(0.00031, f32), mul(d, d))
}
def opt_dshallow_quartic(x: f32) -> f32 = mul(cast(0.00031, f32), mul(mul(cast(4.0, f32), x), sub(mul(x, x), cast(2.0, f32))))
def opt_ddshallow_quartic(x: f32) -> f32 = mul(cast(0.00031, f32), sub(mul(cast(12.0, f32), mul(x, x)), cast(8.0, f32)))
def test_newton_minimize_sub_floor_curvature_is_rejected_at_a_stall_too() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_shallow_quartic, opt_dshallow_quartic, opt_ddshallow_quartic, cast(1.2, f32), cast(1e-10, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r1), "3.1e-4*(x^2-2)^2 with its own correct derivatives stalls at sqrt(2) with a curvature of 0.00496, below the 0.01 floor, and the floor now applies at a stall as it already did at convergence; before, only the converged exit checked it")
  r2 = newton_minimize_1d(opt_shallow_quartic, opt_dshallow_quartic, opt_ddshallow_quartic, cast(1.2, f32), cast(1e-6, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r2), "a tolerance above the 2.1e-10 gradient routes it to the converged exit, which applied the same floor before this change, so no tolerance recovers this family")
  r3 = newton_minimize_1d(opt_shallow_quartic, opt_dshallow_quartic, opt_ddshallow_quartic, cast(1.2, f32), cast(0.0, f32), cast(100, i64))
  assert_true(opt_is_nan(r3), "and tol = 0 is the same stall. This is the documented flat-minimum rejection applied uniformly, and it costs a correct minimiser at the tolerances that previously reached the stall")
}
def test_newton_minimize_does_not_detect_inconsistent_derivatives() -> unit ! { Test } = {
  r = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_huge_curvature, cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r, cast(5.0, f32), cast(0.001, f32), "a ddf of 1e30 is not the derivative of this df: it underflows the step at a point whose gradient is 4, and 1e30 is certifiable curvature, so the stalled point is returned. Consistent derivatives are a precondition the method cannot check from one point, and this pins that it does not pretend to")
}
def test_newton_minimize_runaway_iterate_is_not_a_minimiser() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_ddconcave_3, cast(5.0, f32), cast(1e-6, f32), cast(1000, i64))
  _ = assert_true(opt_is_nan(r1), "a second derivative inconsistent with df sends the iterate to infinity, where every further step stalls; infinity is not returned as a minimiser")
  r2 = newton_minimize_1d(opt_parab_3, opt_inf_gradient, opt_ddparab_3, cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_true(opt_is_nan(r2), "and an infinite first derivative sends it to -infinity, which stalls the same way")
}
def test_newton_minimize_infinite_iterate_with_finite_derivatives_is_nan() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_unit_gradient, opt_ddparab_3, opt_inf(), cast(1e-6, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r1), "an infinite iterate stalls while its gradient and curvature are both finite and the curvature certifies, so rejecting the stalled point needs the iterate itself tested, not only the derivatives")
  r2 = newton_minimize_1d(opt_parab_3, opt_unit_gradient, opt_ddparab_3, neg(opt_inf()), cast(1e-6, f32), cast(100, i64))
  assert_true(opt_is_nan(r2), "and the same at negative infinity")
}
def test_newton_minimize_stall_at_a_stationary_point_still_certifies() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_feeble_dparab_3, opt_ddparab_3, cast(3.0, f32), cast(0.0, f32), cast(100, i64))
  _ = assert_close(r1, cast(3.0, f32), cast(0.001, f32), "a stall with an exactly zero gradient is a genuine stationary point and is certified by its curvature, not rejected")
  r2 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_ddparab_3, cast(5.0, f32), cast(0.0, f32), cast(100, i64))
  _ = assert_close(r2, cast(3.0, f32), cast(0.001, f32), "which is what keeps tol = 0 converging: the exit is the stall, not the tolerance")
  r3 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_ddparab_3, cast(5.0, f32), opt_quiet_nan(), cast(100, i64))
  assert_close(r3, cast(3.0, f32), cast(0.001, f32), "and a NaN tolerance, which also never satisfies the gradient test, reaches the minimiser the same way")
}
def test_newton_minimize_infinite_curvature_at_a_stationary_point_still_converges() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_inf_curvature, cast(3.0, f32), cast(1e-6, f32), cast(100, i64))
  _ = assert_close(r1, cast(3.0, f32), cast(0.001, f32), "an infinite curvature at a point the gradient test already accepted is strictly positive curvature, so the minimiser is returned rather than discarded")
  r2 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_late_inf_curvature, cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_close(r2, cast(3.0, f32), cast(0.001, f32), "including when the curvature is finite where the steps are taken and infinite only at the point reached")
}
def test_newton_minimize_infinite_curvature_at_a_stationary_point_converges_at_every_tolerance() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_inf_curvature, cast(3.0, f32), cast(0.0, f32), cast(100, i64))
  _ = assert_close(r1, cast(3.0, f32), cast(0.001, f32), "tol = 0 makes lt(|df(x)|, tol) false even at an exactly zero gradient, so a zero gradient must count as converged on its own or the whole tolerance range below zero loses this answer")
  r2 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_inf_curvature, cast(3.0, f32), opt_quiet_nan(), cast(100, i64))
  _ = assert_close(r2, cast(3.0, f32), cast(0.001, f32), "a NaN tolerance compares false the same way")
  r3 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_inf_curvature, cast(3.0, f32), cast(-1.0, f32), cast(100, i64))
  _ = assert_close(r3, cast(3.0, f32), cast(0.001, f32), "and so does a negative one")
  r4 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_inf_curvature, cast(3.0, f32), neg(opt_inf()), cast(100, i64))
  _ = assert_close(r4, cast(3.0, f32), cast(0.001, f32), "including negative infinity")
  r5 = newton_minimize_1d(opt_parab_3, opt_dsteep_3, opt_inf_curvature, cast(3.0, f32), cast(0.0, f32), cast(100, i64))
  _ = assert_close(r5, cast(3.0, f32), cast(0.001, f32), "and with a first derivative steep enough to be consistent with a huge curvature, which is the case that makes the infinity look like overflow rather than nonsense")
  r6 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_late_inf_curvature, cast(5.0, f32), cast(0.0, f32), cast(100, i64))
  assert_close(r6, cast(3.0, f32), cast(0.001, f32), "and when the steps are taken at a finite curvature and only the point reached has an infinite one")
}
def test_newton_minimize_certifies_at_a_non_positive_tolerance_too() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_neg_inf_curvature, cast(3.0, f32), cast(0.0, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r1), "a negatively infinite curvature is rejected at tol = 0 exactly as it is at tol = 1e-6; previously tol = 0 reached no curvature check at all and returned the point")
  r2 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_late_neg_inf_curvature, cast(5.0, f32), cast(0.0, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r2), "including when only the point reached has it")
  r3 = newton_minimize_1d(opt_parab_3, opt_dflat_3, opt_ddflat_3, cast(5.0, f32), cast(0.0, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r3), "and a curvature of 0.002 is rejected by the 0.01 floor at tol = 0, which is the same flat-minimum rejection tol = 1e-6 already made")
  r4 = newton_minimize_1d(opt_parab_3, opt_dflat_3, opt_ddflat_3, cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_true(opt_is_nan(r4), "pinning that tol = 1e-6 was already rejecting it, so this is tol = 0 becoming consistent rather than a new rejection")
}
def test_newton_minimize_negative_curvature_at_a_stationary_point_is_nan() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_concave_3, opt_dconcave_3, opt_ddconcave_3, cast(3.0, f32), cast(1e-6, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r1), "the maximiser of -(x-3)^2 is a stationary point with finite negative curvature, which the sign test rejects on its own")
  r2 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_neg_inf_curvature, cast(3.0, f32), cast(1e-6, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r2), "and a negatively infinite curvature is rejected by the same sign test, unlike a positively infinite one")
  r3 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_late_neg_inf_curvature, cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  assert_true(opt_is_nan(r3), "including when it only becomes infinite at the point the steps reach")
}
def test_newton_minimize_finite_curvature_unchanged_by_the_stall_guard() -> unit ! { Test } = {
  r1 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_ddparab_3, cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  _ = assert_close(r1, cast(3.0, f32), cast(0.001, f32), "the stall guard never fires on a well-posed problem")
  r2 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_curvature_below_floor, cast(3.0, f32), cast(1e-6, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r2), "a finite curvature below the 0.01 floor is still rejected by the floor")
  r3 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_curvature_below_step_guard, cast(5.0, f32), cast(1e-6, f32), cast(100, i64))
  _ = assert_true(opt_is_nan(r3), "and one below the 1e-30 step guard is still rejected before any step is taken")
  r4 = newton_minimize_1d(opt_parab_3, opt_dparab_3, opt_ddparab_3, cast(5.0, f32), cast(10.0, f32), cast(100, i64))
  assert_close(r4, cast(5.0, f32), cast(0.001, f32), "and a tolerance of 10 still accepts x0 = 5 on its own gradient, which is the caller's choice of tolerance and not a stall")
}
