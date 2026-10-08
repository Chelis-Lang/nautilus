module Nautilus.Tests.Interpolation
import Nautilus.Interpolation (linear_interp_sorted, spline_eval, spline_fit)
import Std.Test (assert_close, assert_true)
def test_linear_interp_at_knot0() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(0.0, f32))
  assert_close(v, cast(10.0, f32), cast(1e-6, f32), "linear_interp at xs[0] returns ys[0]")
}
def test_linear_interp_at_knot1() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(1.0, f32))
  assert_close(v, cast(20.0, f32), cast(1e-6, f32), "linear_interp at xs[1] returns ys[1]")
}
def test_linear_interp_at_knot2() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(2.0, f32))
  assert_close(v, cast(30.0, f32), cast(1e-6, f32), "linear_interp at xs[2] returns ys[2]")
}
def test_linear_interp_at_knot3() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(3.0, f32))
  assert_close(v, cast(40.0, f32), cast(1e-6, f32), "linear_interp at xs[3] returns ys[3]")
}
def test_linear_interp_midpoint() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(0.5, f32))
  assert_close(v, cast(15.0, f32), cast(1e-6, f32), "linear_interp at midpoint of [0,1] is mean of endpoints")
}
def test_linear_interp_clamp_left() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(-1.0, f32))
  assert_close(v, cast(10.0, f32), cast(1e-6, f32), "linear_interp x < xs[0] clamps to ys[0]")
}
def test_linear_interp_clamp_right() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(10.0, f32))
  assert_close(v, cast(40.0, f32), cast(1e-6, f32), "linear_interp x > xs[m-1] clamps to ys[m-1]")
}
def test_spline_at_knot_left_boundary() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(0.0, f32))
  assert_close(v, cast(0.0, f32), cast(0.00001, f32), "spline_eval at xs[0] returns ys[0]")
}
def test_spline_at_knot_interior() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(2.0, f32))
  assert_close(v, cast(4.0, f32), cast(0.0001, f32), "spline_eval at interior knot xs[2] returns ys[2]")
}
def test_spline_at_knot_right_boundary() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(4.0, f32))
  assert_close(v, cast(16.0, f32), cast(0.001, f32), "spline_eval at xs[m-1] returns ys[m-1]")
}
def test_spline_clamp_left() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(-1.0, f32))
  assert_close(v, cast(0.0, f32), cast(1e-6, f32), "spline_eval x < xs[0] clamps to ys[0]")
}
def test_spline_clamp_right() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(5.0, f32))
  assert_close(v, cast(16.0, f32), cast(1e-6, f32), "spline_eval x > xs[m-1] clamps to ys[m-1]")
}
def test_spline_quadratic_midpoint() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(1.5, f32))
  assert_close(v, cast(2.25, f32), cast(0.5, f32), "spline_eval on y=x^2 near x=1.5 within natural-BC error")
}
def test_spline_linear_recovers_at_midpoint() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  v = spline_eval(xs, ys, cast(1.5, f32))
  assert_close(v, cast(1.5, f32), cast(0.00001, f32), "spline_eval recovers y=x exactly between knots")
}
def test_spline_linear_recovers_at_knot() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  v = spline_eval(xs, ys, cast(2.0, f32))
  assert_close(v, cast(2.0, f32), cast(0.00001, f32), "spline_eval recovers y=x at interior knot")
}
-- nautilus#120. spline_fit and spline_eval require strictly increasing knots.
-- Before the guard was unified, each consumer of the knot gap treated it
-- differently, so a negative gap built a tridiagonal system in which one leg
-- substituted 1.0 and the other three used the raw signed value.
def interp_is_nan(x: f32) -> bool = if eq(x, x) then false else true
def spline_fit_head[m](xs: &tensor[m, f32], ys: &tensor[m, f32]) -> f32 = index(to_list(spline_fit(xs, ys)), cast(0, i64))
def test_spline_refuses_reordered_knots() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(2.0, f32), cast(1.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(4.0, f32), cast(1.0, f32), cast(9.0, f32)])
  v = spline_eval(xs, ys, cast(1.5, f32))
  assert_true(interp_is_nan(v), "spline_eval refuses reordered knots instead of returning the 4.3125 it used to")
}
def test_spline_refuses_duplicate_knots() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(1.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(1.0, f32), cast(9.0, f32)])
  v = spline_eval(xs, ys, cast(1.5, f32))
  assert_true(interp_is_nan(v), "spline_eval refuses a zero-width segment instead of returning the 2.0298913 it used to")
}
def test_spline_refuses_duplicate_knots_outside_range() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(1.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(5.0, f32), cast(9.0, f32)])
  v = spline_eval(xs, ys, cast(-1.0, f32))
  assert_true(interp_is_nan(v), "the strictness of the knot test is observable only off the clamp path: an admitted duplicate still NaNs at an interior query by dividing a zero-width segment, but returns ys[0] = 0.0 here, so this is the fixture that separates gt from gte")
}
def test_spline_refuses_violation_in_the_first_pair() -> unit ! { Test } = {
  xs = to_tensor([cast(1.0, f32), cast(0.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(1.0, f32), cast(0.0, f32), cast(4.0, f32), cast(9.0, f32)])
  v = spline_eval(xs, ys, cast(1.5, f32))
  assert_true(interp_is_nan(v), "the first knot pair is checked: every other bad-knot fixture here first violates at an interior index, so a guard that skipped the opening pair would pass them all")
}
def test_spline_refuses_violation_in_the_last_pair() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(1.5, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(2.25, f32)])
  v = spline_eval(xs, ys, cast(-5.0, f32))
  assert_true(interp_is_nan(v), "the final knot pair is checked, on the clamp arm where a guard that skipped it would return ys[0] = 0.0")
}
def test_spline_refuses_strictly_decreasing_knots() -> unit ! { Test } = {
  xs = to_tensor([cast(3.0, f32), cast(2.0, f32), cast(1.0, f32), cast(0.0, f32)])
  ys = to_tensor([cast(9.0, f32), cast(4.0, f32), cast(1.0, f32), cast(0.0, f32)])
  v = spline_eval(xs, ys, cast(1.5, f32))
  assert_true(interp_is_nan(v), "spline_eval refuses a fully reversed knot vector")
}
def test_spline_refuses_one_ulp_descent() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(0.99999994, f32), cast(2.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(1.0, f32), cast(4.0, f32)])
  v = spline_eval(xs, ys, cast(0.5, f32))
  assert_true(interp_is_nan(v), "a gap of -5.9604645e-8, one f32 ulp below 1.0, is refused: the guard tests the sign, not a magnitude")
}
def test_spline_refuses_bad_knots_below_range() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(2.0, f32), cast(1.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(4.0, f32), cast(1.0, f32), cast(9.0, f32)])
  v = spline_eval(xs, ys, cast(-1.0, f32))
  assert_true(interp_is_nan(v), "the clamp-left arm refuses bad knots instead of returning ys[0]: it never reads the fitted moments, so NaN propagation alone would miss it")
}
def test_spline_refuses_bad_knots_above_range() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(2.0, f32), cast(1.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(4.0, f32), cast(1.0, f32), cast(9.0, f32)])
  v = spline_eval(xs, ys, cast(5.0, f32))
  assert_true(interp_is_nan(v), "the clamp-right arm refuses bad knots instead of returning ys[m-1]")
}
def test_spline_fit_refuses_reordered_knots() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(2.0, f32), cast(1.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(4.0, f32), cast(1.0, f32), cast(9.0, f32)])
  v = spline_fit_head(xs, ys)
  assert_true(interp_is_nan(v), "spline_fit itself refuses, not only spline_eval: it is exported separately")
}
def test_spline_accepts_one_ulp_ascent() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(1.0000001, f32), cast(2.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(1.0, f32), cast(4.0, f32)])
  v = spline_eval(xs, ys, cast(0.5, f32))
  assert_true(not(interp_is_nan(v)), "a gap of +1.1920929e-7, one f32 ulp above 1.0, is accepted: the guard refuses non-increasing knots, not ill-conditioned ones")
}
def test_spline_accepts_a_gap_below_the_old_magnitude_threshold() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1e-31, f32), cast(1.0, f32), cast(2.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(5.0, f32)])
  v = spline_eval(xs, ys, cast(0.5, f32))
  _ = assert_true(not(interp_is_nan(v)), "a gap of 1e-31 is accepted, not refused: the deleted per-leg guards replaced anything under 1e-30 with a unit gap, and nothing else pins that this is now admitted rather than rejected")
  assert_true(gt(v, cast(1e29, f32)), "and the real gap is used, so the result is huge rather than the 1.35 a substituted unit gap used to fabricate. This pins acceptance and the use of the gap, not accuracy: see the knot requirements in the book")
}
def test_spline_refuses_descent_at_small_knot_magnitude() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(0.001, f32), cast(0.0009999999, f32), cast(0.002, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(1.0, f32), cast(4.0, f32)])
  v = spline_eval(xs, ys, cast(0.0005, f32))
  assert_true(interp_is_nan(v), "a descent of one ulp of 0.001 is refused. Every other bad-knot fixture here uses knots at magnitude 1 or above, where an absolute slack smaller than one ulp of 1.0 would be invisible, so without this case a guard carrying such a slack would pass the whole suite")
}
def test_spline_accepts_two_knots() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(2.0, f32)])
  v = spline_eval(xs, ys, cast(0.5, f32))
  assert_true(not(interp_is_nan(v)), "the shortest admissible knot vector is still accepted")
}
def test_spline_sorted_path_unchanged_by_the_guard() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32)])
  v = spline_eval(xs, ys, cast(1.5, f32))
  assert_close(v, cast(2.2, f32), cast(1e-6, f32), "strictly increasing knots give the same 2.2 as before the guard: no leg substituted on this path")
}
