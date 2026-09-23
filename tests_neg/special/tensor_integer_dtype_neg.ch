module Nautilus.Tests_Neg.Special.Tensor_Integer_Dtype_Neg
import Nautilus.Special (erf_t)
def integer_erf_t(x: tensor[3, i64]) -> tensor[3, i64] = erf_t(x)
