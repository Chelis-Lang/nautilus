module Nautilus.Tests_Neg.Integrate.Gauss_Legendre_5_Midpoint_Node_Neg
import Nautilus.Integrate (gauss_legendre_5)
def gl5_neg_midpoint_only(x: f32) -> f32 = if eq(x, cast(0.5, f32)) then fail("gl5: the integrand was evaluated at the midpoint node") else cast(0.0, f32)
def test_guard_precedes_the_midpoint_node() -> unit ! { Test } = {
  _ = gauss_legendre_5(gl5_neg_midpoint_only, cast(0.0, f32), cast(1.0, f32), cast(20, i64))
  ()
}
