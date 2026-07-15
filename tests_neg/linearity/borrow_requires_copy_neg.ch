module Nautilus.Tests_Neg.Linearity.Borrow_Requires_Copy_Neg
import Nautilus.LinAlg (l2_norm_vec)
import Std.Test (assert_close)
def linearity_owned_norm_neg[n](v: tensor[n, f32]) -> f32 = l2_norm_vec(v)
def linearity_missing_copy_neg[n](v: &tensor[n, f32]) -> f32 = linearity_owned_norm_neg(v)
def test_negative_linearity_borrow_requires_copy() -> unit ! { Test } = assert_close(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), "should not reach here")
