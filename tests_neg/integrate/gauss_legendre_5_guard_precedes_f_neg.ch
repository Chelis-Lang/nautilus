module Nautilus.Tests_Neg.Integrate.Gauss_Legendre_5_Guard_Precedes_F_Neg
import Nautilus.Integrate (gauss_legendre_5)
def gl5_neg_trapping_integrand(x: f32) -> f32 = fail("gl5: the integrand was evaluated before the n_points guard")
def test_guard_fires_before_the_integrand() -> unit ! { Test } = {
  _ = gauss_legendre_5(gl5_neg_trapping_integrand, cast(0.0, f32), cast(1.0, f32), cast(20, i64))
  ()
}
