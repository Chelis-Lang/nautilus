module Nautilus.Tests_Neg.Distributions.ReusedGammaKeyNeg
import Nautilus.Distributions (gamma_sample)
def reuse_gamma(k: key, template: tensor[3, f32]) -> tensor[3, f32] = {
  _ = gamma_sample(k, copy(template), 2.0f32, 1.0f32)
  gamma_sample(k, template, 2.0f32, 1.0f32)
}
