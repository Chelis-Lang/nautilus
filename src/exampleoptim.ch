module Nautilus.ExampleOptim
import Nautilus.Optim (golden_section_search, brent_minimize, newton_minimize_1d)
export (example_min_parabola_gss, example_min_parabola_brent, example_min_rosenbrock_1d_newton)
def eop_parabola(x: f32) -> f32 = {
  d = sub(x, cast(3.0, f32))
  d2 = mul(d, d)
  __borrow_migration_out_0 = add(d2, cast(7.0, f32))
  _ = drop(d)
  __borrow_migration_out_0
}
def eop_dparabola(x: f32) -> f32 = mul(cast(2.0, f32), sub(x, cast(3.0, f32)))
def eop_ddparabola(x: f32) -> f32 = cast(2.0, f32)
def eop_quartic(x: f32) -> f32 = {
  x2 = mul(x, x)
  x4 = mul(x2, x2)
  add(sub(x4, mul(cast(4.0, f32), x2)), cast(5.0, f32))
}
def example_min_parabola_gss() -> f32 = golden_section_search(eop_parabola, cast(0.0, f32), cast(10.0, f32), cast(0.00000001, f32), cast(200, int64))
def example_min_parabola_brent() -> f32 = brent_minimize(eop_quartic, cast(0.5, f32), cast(3.0, f32), cast(0.00000001, f32), cast(200, int64))
def example_min_rosenbrock_1d_newton() -> f32 = newton_minimize_1d(eop_parabola, eop_dparabola, eop_ddparabola, cast(0.0, f32), cast(0.0000000001, f32), cast(50, int64))
