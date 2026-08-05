module Nautilus.Tests.Interpolation
import Nautilus.Interpolation (linear_interp_sorted, spline_eval)
import Std.Test (assert_close)
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
