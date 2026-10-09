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
-- nautilus#155. The segment polynomial is evaluated in f64, so a tiny knot
-- magnitude no longer costs the curvature. A cubic spline is scale
-- equivariant: scaling the knots, the values and the query by one factor must
-- scale the result by that factor, so [0, 1, 2, 3] with [0, 1, 4, 9] at
-- x = 1.5, which gives 2.2, must give 2.2 times the factor. Each tolerance
-- below is 1e-5 of its expected value: four orders tighter than the 13.6% the
-- quadratic term is worth, and about 70 times looser than the 1.4e-7 the f64
-- path achieves on these rows, so they separate the two without pinning an ulp.
def interp_abs(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def test_spline_equivariant_at_1em24() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1e-24, f32), cast(2e-24, f32), cast(3e-24, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1e-24, f32), cast(4e-24, f32), cast(9e-24, f32)])
  v = spline_eval(xs, ys, cast(1.5e-24, f32))
  assert_close(v, cast(2.2e-24, f32), cast(2.2e-29, f32), "knots scaled by 1e-24 scale the result by 1e-24. The offset here is 5e-25, whose square is below f32's 2^-150 flush threshold, so in f32 the quadratic term became exactly zero and this returned 1.8999999e-24")
}
def test_spline_keeps_the_curvature_at_1em24() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1e-24, f32), cast(2e-24, f32), cast(3e-24, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1e-24, f32), cast(4e-24, f32), cast(9e-24, f32)])
  v = spline_eval(xs, ys, cast(1.5e-24, f32))
  assert_true(gt(interp_abs(sub(v, cast(1.8999999e-24, f32))), cast(2e-25, f32)), "and the result is not the segment polynomial's linear part a_c + b_c*t, which is what the collapse returned. That is not the chord through the bracketing knots: the chord gives 2.5e-24, 14% high, where the defect gave 1.8999999e-24, 14% low, so linear_interp_sorted does not detect it. The equivariance assertion above would also fail for a quadratic term restored at the wrong magnitude; this one fails only for the collapse, which is the defect's exact signature")
}
def test_spline_equivariant_at_1em26() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1e-26, f32), cast(2e-26, f32), cast(3e-26, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1e-26, f32), cast(4e-26, f32), cast(9e-26, f32)])
  v = spline_eval(xs, ys, cast(1.5e-26, f32))
  assert_close(v, cast(2.2e-26, f32), cast(2.2e-31, f32), "knots scaled by 1e-26 scale the result by 1e-26. Here the fit leaves a rounding residue of -3.689349e19 in the difference of second derivatives, which over 6h overflowed the cubic coefficient to -inf in f32; that infinity times the flushed cube of the offset returned NaN")
}
def test_spline_equivariant_at_1em28() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1e-28, f32), cast(2e-28, f32), cast(3e-28, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1e-28, f32), cast(4e-28, f32), cast(9e-28, f32)])
  v = spline_eval(xs, ys, cast(1.5e-28, f32))
  assert_close(v, cast(2.2e-28, f32), cast(2.2e-33, f32), "and knots scaled by 1e-28 likewise, where the residue was 1.8889466e22 and the overflow was to +inf. This row and the 1e-26 one are what distinguish f64 arithmetic from merely rewriting the f32 polynomial in Horner form, which clears the 1e-24 row but still returns an infinity here")
}
def test_spline_equivariant_just_above_the_pivot_floor() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(3e-31, f32), cast(6e-31, f32), cast(9e-31, f32)])
  ys = to_tensor([cast(0.0, f32), cast(3e-31, f32), cast(1.2e-30, f32), cast(2.7e-30, f32)])
  v = spline_eval(xs, ys, cast(4.5e-31, f32))
  assert_close(v, cast(6.6e-31, f32), cast(6.6e-36, f32), "a gap of 3e-31 leaves every eliminated pivot above the 1e-30 below which la_tridiag_solve substitutes 1, so the fit is sound and the evaluator carries it. This is not the smallest such gap: for four knots the last eliminated pivot is 3.75h and the boundary is 2.667e-31, and the sibling test below sits under it")
}
def test_spline_not_equivariant_just_below_the_pivot_floor() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(2e-31, f32), cast(4e-31, f32), cast(6e-31, f32)])
  ys = to_tensor([cast(0.0, f32), cast(2e-31, f32), cast(8e-31, f32), cast(1.8e-30, f32)])
  v = spline_eval(xs, ys, cast(3e-31, f32))
  assert_true(gt(interp_abs(sub(v, cast(4.4e-31, f32))), cast(4.4e-33, f32)), "and a gap of 2e-31 puts 4h at 8e-31, under the floor, so both interior pivots are substituted and the second derivatives come back as 12.0 instead of 1.2e31. This asserts only that equivariance fails, not any particular wrong value; 5e-31 is what it measured when written. It pins the boundary of the f64 evaluator's reach, which reproduces a wrong fit faithfully rather than repairing one. If the pivot floor is ever removed this assertion is expected to fail, and the pair above and below the floor should be re-measured rather than retuned")
}
-- The gap at which the solve's last eliminated pivot crosses 1e-30 depends on
-- the knot count. Forward elimination gives d[k] = 4 - 1/d[k-1] in units of h,
-- starting at 4, so the last interior pivot is 4h for three knots, 3.75h for
-- four, 3.7333h for five, and tends to (2 + sqrt 3)h = 3.7320508h. The
-- boundary therefore rises with knot count, from 2.5e-31 at three knots, and
-- no single count's figure is general. These two pin that for five knots,
-- where the correct ratio is 2.232143 rather than the four-knot 2.2.
def test_spline_five_knot_threshold_is_above_the_four_knot_one() -> unit ! { Test } = {
  s = cast(2.667e-31, f32)
  xs = to_tensor([cast(0.0, f32), s, mul(cast(2.0, f32), s), mul(cast(3.0, f32), s), mul(cast(4.0, f32), s)])
  ys = to_tensor([cast(0.0, f32), s, mul(cast(4.0, f32), s), mul(cast(9.0, f32), s), mul(cast(16.0, f32), s)])
  v = div(spline_eval(xs, ys, mul(cast(1.5, f32), s)), s)
  assert_true(gt(interp_abs(sub(v, cast(2.232143, f32))), cast(0.000022, f32)), "five knots at the four-knot boundary gap of 2.667e-31 are not equivariant: 3.7333h is 9.956e-31 here, under the floor, and the ratio collapses to the four-knot 2.2 against a correct 2.232143. A page or comment quoting 2.667e-31 as the general threshold is wrong in the unsafe direction")
}
def test_spline_five_knot_equivariant_at_the_universal_bound() -> unit ! { Test } = {
  s = cast(2.6795e-31, f32)
  xs = to_tensor([cast(0.0, f32), s, mul(cast(2.0, f32), s), mul(cast(3.0, f32), s), mul(cast(4.0, f32), s)])
  ys = to_tensor([cast(0.0, f32), s, mul(cast(4.0, f32), s), mul(cast(9.0, f32), s), mul(cast(16.0, f32), s)])
  v = div(spline_eval(xs, ys, mul(cast(1.5, f32), s)), s)
  assert_close(v, cast(2.232143, f32), cast(0.000022, f32), "and 2.6795e-31 is equivariant for five knots. It sits just above 1e-30 over (2 + sqrt 3), which is 2.6794919e-31, and the margin is the point: the exact quotient is not safe, because nine knots at 2.6794919e-31 return 2.2253525 against a correct 2.2255154, outside this tolerance. Do not replace this literal with the exact quotient")
}
