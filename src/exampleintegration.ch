module Nautilus.ExampleIntegration
import Nautilus.Integrate (trapezoidal, simpsons, gauss_legendre_5, adaptive_simpson, romberg_5, gauss_legendre_10)
export (example_pi_over_4_trap, example_pi_over_4_simpson, example_pi_over_4_romberg, example_pi_over_4_adaptive, example_pi_over_4_gl10)
def ei_inv_1_x2(x: f32) -> f32 = {
  x2 = mul(x, x)
  div(cast(1.0, f32), add(cast(1.0, f32), x2))
}
def example_pi_over_4_trap() -> f32 = trapezoidal(ei_inv_1_x2, cast(0.0, f32), cast(1.0, f32), cast(100, i64))
def example_pi_over_4_simpson() -> f32 = simpsons(ei_inv_1_x2, cast(0.0, f32), cast(1.0, f32), cast(100, i64))
def example_pi_over_4_romberg() -> f32 = romberg_5(ei_inv_1_x2, cast(0.0, f32), cast(1.0, f32))
def example_pi_over_4_adaptive() -> f32 = adaptive_simpson(ei_inv_1_x2, cast(0.0, f32), cast(1.0, f32), cast(1e-10, f32), cast(20, i64))
def example_pi_over_4_gl10() -> f32 = gauss_legendre_10(ei_inv_1_x2, cast(0.0, f32), cast(1.0, f32))
