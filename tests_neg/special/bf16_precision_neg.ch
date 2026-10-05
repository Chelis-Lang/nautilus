module Nautilus.Tests_Neg.Special.Bf16_Precision_Neg
import Nautilus.Special (gamma)
def rejected_bf16() -> bf16 = gamma(5.5bf16)
