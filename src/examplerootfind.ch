module Nautilus.ExampleRootFind
import Nautilus.Roots (bisection, newton, brent)
export (example_sqrt2, example_cos_minus_x, example_projectile_angle)
def erf_poly1(x: f32) -> f32 = {
  x2 = mul(x, x)
  sub(x2, cast(2.0, f32))
}
def erf_dpoly1(x: f32) -> f32 = mul(cast(2.0, f32), x)
def erf_cosmx(x: f32) -> f32 = {
  half_pi = cast(1.5707963267948966, f32)
  c = sin(add(x, half_pi))
  sub(c, x)
}
def erf_dcosmx(x: f32) -> f32 = {
  s = sin(x)
  sub(neg(s), cast(1.0, f32))
}
def erf_projectile(theta: f32) -> f32 = {
  two_theta = mul(cast(2.0, f32), theta)
  s = sin(two_theta)
  g = cast(9.81, f32)
  v_sq = mul(cast(20.0, f32), cast(20.0, f32))
  d = cast(30.0, f32)
  sub(mul(div(v_sq, g), s), d)
}
def example_sqrt2() -> f32 = brent(erf_poly1, cast(1.0, f32), cast(2.0, f32), cast(1e-10, f32), cast(100, int64))
def example_cos_minus_x() -> f32 = newton(erf_cosmx, erf_dcosmx, cast(0.5, f32), cast(1e-10, f32), cast(50, int64))
def example_projectile_angle() -> f32 = bisection(erf_projectile, cast(0.1, f32), cast(0.7, f32), cast(1e-8, f32), cast(100, int64))
