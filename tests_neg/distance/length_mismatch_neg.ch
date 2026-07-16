module Nautilus.Tests_Neg.Distance.Length_Mismatch_Neg
import Nautilus.Distance (euclidean)
import Std.Test (assert_close)
def test_negative_euclidean_length_mismatch() -> unit ! { Test } = {
  a = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  b = to_tensor([cast(1.0, f32), cast(2.0, f32)])
  _ = euclidean(a, b)
  assert_close(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), "should not reach here")
}
