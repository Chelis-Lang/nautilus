module Nautilus.Tests_Neg.LinAlg.Unsupported_Element_Type_Neg
import Nautilus.LinAlg (det_2x2)
import Std.Test (assert_close)
def unsupported_int_matrix(a: tensor[2, 2, int64]) -> f32 = det_2x2(a)
def test_negative_linalg_unsupported_element_type() -> unit ! { Test } = assert_close(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), "should not reach here")
