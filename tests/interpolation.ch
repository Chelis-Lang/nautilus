module Nautilus.Tests.Interpolation
import Nautilus.Interpolation (linear_interp_sorted, spline_eval)
import Std.Test (assert_close)
def test_linear_interp_at_knot0() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(0.0, f32))
  __borrow_migration_out_0 = assert_close(v, cast(10.0, f32), cast(0.000001, f32), "linear_interp at xs[0] returns ys[0]")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_0
}
def test_linear_interp_at_knot1() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(1.0, f32))
  __borrow_migration_out_1 = assert_close(v, cast(20.0, f32), cast(0.000001, f32), "linear_interp at xs[1] returns ys[1]")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_1
}
def test_linear_interp_at_knot2() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(2.0, f32))
  __borrow_migration_out_2 = assert_close(v, cast(30.0, f32), cast(0.000001, f32), "linear_interp at xs[2] returns ys[2]")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_2
}
def test_linear_interp_at_knot3() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(3.0, f32))
  __borrow_migration_out_3 = assert_close(v, cast(40.0, f32), cast(0.000001, f32), "linear_interp at xs[3] returns ys[3]")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_3
}
def test_linear_interp_midpoint() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(0.5, f32))
  __borrow_migration_out_4 = assert_close(v, cast(15.0, f32), cast(0.000001, f32), "linear_interp at midpoint of [0,1] is mean of endpoints")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_4
}
def test_linear_interp_clamp_left() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(-1.0, f32))
  __borrow_migration_out_5 = assert_close(v, cast(10.0, f32), cast(0.000001, f32), "linear_interp x < xs[0] clamps to ys[0]")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_5
}
def test_linear_interp_clamp_right() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32)])
  v = linear_interp_sorted(xs, ys, cast(10.0, f32))
  __borrow_migration_out_6 = assert_close(v, cast(40.0, f32), cast(0.000001, f32), "linear_interp x > xs[m-1] clamps to ys[m-1]")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_6
}
def test_spline_at_knot_left_boundary() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(0.0, f32))
  __borrow_migration_out_7 = assert_close(v, cast(0.0, f32), cast(0.00001, f32), "spline_eval at xs[0] returns ys[0]")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_7
}
def test_spline_at_knot_interior() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(2.0, f32))
  __borrow_migration_out_8 = assert_close(v, cast(4.0, f32), cast(0.0001, f32), "spline_eval at interior knot xs[2] returns ys[2]")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_8
}
def test_spline_at_knot_right_boundary() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(4.0, f32))
  __borrow_migration_out_9 = assert_close(v, cast(16.0, f32), cast(0.001, f32), "spline_eval at xs[m-1] returns ys[m-1]")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_9
}
def test_spline_clamp_left() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(-1.0, f32))
  __borrow_migration_out_10 = assert_close(v, cast(0.0, f32), cast(0.000001, f32), "spline_eval x < xs[0] clamps to ys[0]")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_10
}
def test_spline_clamp_right() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(5.0, f32))
  __borrow_migration_out_11 = assert_close(v, cast(16.0, f32), cast(0.000001, f32), "spline_eval x > xs[m-1] clamps to ys[m-1]")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_11
}
def test_spline_quadratic_midpoint() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(4.0, f32), cast(9.0, f32), cast(16.0, f32)])
  v = spline_eval(xs, ys, cast(1.5, f32))
  __borrow_migration_out_12 = assert_close(v, cast(2.25, f32), cast(0.5, f32), "spline_eval on y=x^2 near x=1.5 within natural-BC error")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_12
}
def test_spline_linear_recovers_at_midpoint() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  v = spline_eval(xs, ys, cast(1.5, f32))
  __borrow_migration_out_13 = assert_close(v, cast(1.5, f32), cast(0.00001, f32), "spline_eval recovers y=x exactly between knots")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_13
}
def test_spline_linear_recovers_at_knot() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  v = spline_eval(xs, ys, cast(2.0, f32))
  __borrow_migration_out_14 = assert_close(v, cast(2.0, f32), cast(0.00001, f32), "spline_eval recovers y=x at interior knot")
  _ = drop(v)
  _ = drop(xs)
  _ = drop(ys)
  __borrow_migration_out_14
}
