module Nautilus.Tests_Neg.Distributions.KeylessSampleNeg
import Nautilus.Distributions (uniform_sample)
def keyless(template: tensor[3, f32]) -> tensor[3, f32] = uniform_sample(template, 0.0f32, 1.0f32)
