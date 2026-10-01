module Nautilus.Tests.SpecialLiteralWidth
import Nautilus.Special (bessel_j0, bessel_j1, bessel_y0, bessel_y1)
import Std.Test (assert_close)
-- The small-argument rational coefficients exceed f16's literal range.
-- Their explicit source width must preserve both supported accuracy lanes.
def test_bessel_small_coefficients_at_f64() -> unit ! { Test } = {
  _ = assert_close(bessel_j0(5.0f64), -0.1775967713143383f64, 2e-8f64, "J0 small branch at f64")
  _ = assert_close(bessel_j1(1.5f64), 0.5579365079100996f64, 5e-10f64, "J1 small branch at f64")
  _ = assert_close(bessel_y0(1.5f64), 0.38244892379775886f64, 5e-9f64, "Y0 small branch at f64")
  assert_close(bessel_y1(2.2f64), 0.0014877892897632759f64, 2e-9f64, "Y1 small branch at f64")
}
def test_bessel_small_coefficients_at_f32() -> unit ! { Test } = {
  _ = assert_close(cast(bessel_j0(5.0f32), f64), bessel_j0(5.0f64), 0.00002f64, "J0 small branch agrees across widths")
  _ = assert_close(cast(bessel_j1(1.5f32), f64), bessel_j1(1.5f64), 0.00002f64, "J1 small branch agrees across widths")
  _ = assert_close(cast(bessel_y0(1.5f32), f64), bessel_y0(1.5f64), 0.00002f64, "Y0 small branch agrees across widths")
  assert_close(cast(bessel_y1(2.2f32), f64), bessel_y1(2.2f64), 0.00002f64, "Y1 small branch agrees across widths")
}
