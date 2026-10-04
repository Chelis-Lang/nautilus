module Nautilus.Tests_Neg.Integrate.Gauss_Legendre_5_N_Points_Neg
import Nautilus.Integrate (gauss_legendre_5)
def gl5_neg_identity(x: f32) -> f32 = x
def test_unsupported_n_points_traps() -> unit ! { Test } = {
  _ = gauss_legendre_5(gl5_neg_identity, cast(0.0, f32), cast(1.0, f32), cast(20, i64))
  ()
}
