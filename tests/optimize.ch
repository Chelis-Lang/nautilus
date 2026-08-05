module Nautilus.Tests.Optimize
import Nautilus.Optimize (minimize, root, optimize_ad_smoke)
import Std.Test (assert_close)
def opt_wrap_parab(x: f32) -> f32 = {
  d = sub(x, cast(2.0, f32))
  mul(d, d)
}
def opt_wrap_root_fn(x: f32) -> f32 = sub(mul(x, x), cast(2.0, f32))
def test_minimize_wraps_brent() -> unit ! { Test } = {
  xmin = minimize(opt_wrap_parab, cast(0.0, f32), cast(5.0, f32), cast(1e-7, f32), cast(200, int64))
  assert_close(xmin, cast(2.0, f32), cast(0.0001, f32), "Optimize.minimize wraps scalar Brent minimization")
}
def test_root_wraps_brent() -> unit ! { Test } = {
  r = root(opt_wrap_root_fn, cast(1.0, f32), cast(2.0, f32), cast(1e-7, f32), cast(100, int64))
  assert_close(r, cast(1.4142135, f32), cast(0.0001, f32), "Optimize.root wraps scalar Brent root finding")
}
def test_optimize_ad_smoke_is_smooth_scalar() -> unit ! { Test } = assert_close(optimize_ad_smoke(cast(2.5, f32)), cast(0.25, f32), cast(1e-6, f32), "Optimize AD smoke helper is a smooth scalar loss")
