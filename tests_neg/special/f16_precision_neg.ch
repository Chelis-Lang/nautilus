module Nautilus.Tests_Neg.Special.F16_Precision_Neg
import Nautilus.Special (bessel_j0)
def rejected_f16() -> f16 = bessel_j0(5.0f16)
