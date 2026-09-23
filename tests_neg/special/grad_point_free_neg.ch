module Nautilus.Tests_Neg.Special.Grad_Point_Free_Neg
import Nautilus.Special (erf)
def point_free_grad() -> f32 = grad(erf)(0.5f32)
