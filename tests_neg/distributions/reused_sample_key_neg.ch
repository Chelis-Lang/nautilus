module Nautilus.Tests_Neg.Distributions.ReusedSampleKeyNeg
import Nautilus.Distributions (uniform_sample)
def reuse_key(k: key, template: tensor[3, f32]) -> tensor[3, f32] = {
  _ = uniform_sample(k, copy(template), 0.0f32, 1.0f32)
  uniform_sample(k, template, 0.0f32, 1.0f32)
}
