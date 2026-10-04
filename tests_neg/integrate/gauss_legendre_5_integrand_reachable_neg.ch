module Nautilus.Tests_Neg.Integrate.Gauss_Legendre_5_Integrand_Reachable_Neg
import Nautilus.Integrate (gauss_legendre_5)
def gl5_neg_trapping_integrand(x: f32) -> f32 = fail("gl5: the integrand was evaluated before the n_points guard")
def test_the_integrand_is_reachable_at_a_supported_order() -> unit ! { Test } = {
  _ = gauss_legendre_5(gl5_neg_trapping_integrand, cast(0.0, f32), cast(1.0, f32), cast(5, i64))
  ()
}
