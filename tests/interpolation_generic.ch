module Nautilus.Tests.InterpolationGeneric
import Nautilus.Interpolation (linear_interp_uniform, linear_interp_sorted, cubic_hermite)
import Std.Test (assert_true)
-- nautilus#67: linear and Hermite interpolation are dtype-generic over the
-- Float family. The f64 expectations sit below f32 resolution, so an f32-only
-- kernel with wider casts cannot satisfy them.
def ig_abs_f64(x: f64) -> f64 = if lt(x, cast(0.0, f64)) then neg(x) else x
def test_linear_interp_sorted_f64_below_f32_resolution() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f64), cast(1.0, f64), cast(3.0, f64)])
  ys = to_tensor([cast(0.0, f64), cast(0.1, f64), cast(0.7, f64)])
  v = linear_interp_sorted(xs, ys, cast(0.3, f64))
  assert_true(lt(ig_abs_f64(sub(v, cast(0.03, f64))), cast(1e-15, f64)), "f64 linear_interp_sorted at 0.3 on [0,1] -> [0,0.1] is 0.03 to 1e-15 (f32 gives 0.030000001)")
}
def test_linear_interp_sorted_f64_second_segment_and_clamps() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f64), cast(1.0, f64), cast(3.0, f64)])
  ys = to_tensor([cast(0.0, f64), cast(0.1, f64), cast(0.7, f64)])
  mid = linear_interp_sorted(copy(xs), copy(ys), cast(2.0, f64))
  lo = linear_interp_sorted(copy(xs), copy(ys), cast(-1.0, f64))
  hi = linear_interp_sorted(xs, ys, cast(9.0, f64))
  _ = assert_true(lt(ig_abs_f64(sub(mid, cast(0.4, f64))), cast(1e-15, f64)), "f64 second segment midpoint is 0.4")
  _ = assert_true(eq(lo, cast(0.0, f64)), "f64 query left of the grid clamps to ys[0]")
  assert_true(eq(hi, cast(0.7, f64)), "f64 query right of the grid clamps to ys[last]")
}
def test_linear_interp_uniform_f64_below_f32_resolution() -> unit ! { Test } = {
  ys = to_tensor([cast(0.0, f64), cast(0.1, f64), cast(0.2, f64)])
  v = linear_interp_uniform(ys, cast(0.0, f64), cast(2.0, f64), cast(0.3, f64))
  assert_true(lt(ig_abs_f64(sub(v, cast(0.03, f64))), cast(1e-15, f64)), "f64 linear_interp_uniform at 0.3 is 0.03 to 1e-15")
}
def test_cubic_hermite_f64_reproduces_cubic() -> unit ! { Test } = {
  v = cubic_hermite(cast(0.0, f64), cast(1.0, f64), cast(0.0, f64), cast(1.0, f64), cast(0.0, f64), cast(3.0, f64), cast(0.3, f64))
  assert_true(lt(ig_abs_f64(sub(v, cast(0.027, f64))), cast(1e-15, f64)), "f64 cubic_hermite with x^3 endpoint data reproduces 0.3^3 = 0.027 to 1e-15")
}
def test_cubic_hermite_f64_degenerate_interval_is_nan() -> unit ! { Test } = {
  v = cubic_hermite(cast(1.0, f64), cast(1.0, f64), cast(0.0, f64), cast(1.0, f64), cast(0.0, f64), cast(0.0, f64), cast(1.0, f64))
  assert_true(neq(v, v), "f64 cubic_hermite on a zero-width interval returns NaN, as at f32")
}
def test_linear_interp_uniform_f64_later_cells_and_clamps() -> unit ! { Test } = {
  ys = to_tensor([cast(0.0, f64), cast(0.1, f64), cast(0.2, f64), cast(0.7, f64)])
  last_cell = linear_interp_uniform(copy(ys), cast(0.0, f64), cast(3.0, f64), cast(2.5, f64))
  on_knot = linear_interp_uniform(copy(ys), cast(0.0, f64), cast(3.0, f64), cast(1.0, f64))
  right = linear_interp_uniform(copy(ys), cast(0.0, f64), cast(3.0, f64), cast(3.0, f64))
  beyond = linear_interp_uniform(ys, cast(0.0, f64), cast(3.0, f64), cast(7.0, f64))
  _ = assert_true(lt(ig_abs_f64(sub(last_cell, cast(0.45, f64))), cast(1e-15, f64)), "f64 uniform query 2.5 lands in the last cell: 0.2 + 0.5 * 0.5 = 0.45")
  _ = assert_true(lt(ig_abs_f64(sub(on_knot, cast(0.1, f64))), cast(1e-15, f64)), "f64 uniform query on an interior knot returns that knot's value")
  _ = assert_true(lt(ig_abs_f64(sub(right, cast(0.7, f64))), cast(1e-15, f64)), "f64 uniform query at x_max returns ys[last]")
  assert_true(lt(ig_abs_f64(sub(beyond, cast(0.7, f64))), cast(1e-15, f64)), "f64 uniform query beyond x_max clamps to ys[last]")
}
def test_linear_interp_uniform_f32_later_cell() -> unit ! { Test } = {
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32)])
  v = linear_interp_uniform(ys, cast(0.0, f32), cast(3.0, f32), cast(1.5, f32))
  assert_true(eq(v, cast(2.5, f32)), "f32 uniform query 1.5 interpolates the middle cell to 2.5 through the generic signature")
}
