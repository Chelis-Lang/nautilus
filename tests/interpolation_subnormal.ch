module Nautilus.Tests.InterpolationSubnormal
import Std.Test (assert_close, assert_true)
import Nautilus.Interpolation (spline_eval, spline_fit)
def test_spline_eval_with_subnormal_knots() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1e-39, f32), cast(2e-39, f32), cast(3e-39, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1e-39, f32), cast(4e-39, f32), cast(9e-39, f32)])
  moments = to_list(spline_fit(copy(xs), copy(ys)))
  interior_moment = index(moments, cast(1, i64))
  _ = assert_true(not(eq(sub(interior_moment, interior_moment), cast(0.0, f32))), "the public f32 moment exceeds its representable range")
  actual = spline_eval(xs, ys, cast(1.5e-39, f32))
  assert_close(actual, cast(2.2e-39, f32), cast(2e-42, f32), "subnormal spline result is representable")
}
def test_spline_one_knot_keeps_natural_boundary() -> unit ! { Test } = {
  xs = to_tensor([cast(1e-39, f32)])
  ys = to_tensor([cast(4e-39, f32)])
  moment = index(to_list(spline_fit(copy(xs), copy(ys))), cast(0, i64))
  _ = assert_close(moment, cast(0.0, f32), cast(0.0, f32), "one knot has zero natural-spline curvature")
  actual = spline_eval(xs, ys, cast(2e-39, f32))
  assert_close(actual, cast(4e-39, f32), cast(0.0, f32), "one-knot spline is constant")
}
def test_spline_eval_rejects_duplicate_subnormal_knots() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1e-39, f32), cast(1e-39, f32), cast(3e-39, f32)])
  ys = to_tensor([cast(0.0, f32), cast(1e-39, f32), cast(4e-39, f32), cast(9e-39, f32)])
  actual = spline_eval(xs, ys, cast(1.5e-39, f32))
  assert_true(not(eq(actual, actual)), "duplicate subnormal knots have no natural spline")
}
