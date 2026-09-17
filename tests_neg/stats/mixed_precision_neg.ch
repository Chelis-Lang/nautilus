module Nautilus.Tests_Neg.Stats.Mixed_Precision_Neg
import Nautilus.Stats (covariance_scalar)
def mixed(a: tensor[3, f32], b: tensor[3, f64]) -> f32 = covariance_scalar(a, b, 0i64)
