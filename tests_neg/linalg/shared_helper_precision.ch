module Nautilus.Tests_Neg.LinAlg.Shared_Helper_Precision
import Nautilus.LinAlg (la_basis_n)
def unsupported_scale(template: tensor[2, f32]) -> tensor[2, f32] = la_basis_n(0i64, 1.0f64, template)
