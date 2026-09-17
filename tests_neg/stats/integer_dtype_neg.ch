module Nautilus.Tests_Neg.Stats.Integer_Dtype_Neg
import Nautilus.Stats (mean_vec)
def integer_mean(v: tensor[3, int64]) -> int64 = mean_vec(v)
