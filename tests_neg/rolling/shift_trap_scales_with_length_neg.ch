module Nautilus.Tests_Neg.Rolling.Shift_Trap_Scales_With_Length_Neg
import Nautilus.Rolling (shift)
def test_three_elements_trap_one_offset_earlier() -> unit ! { Test } = {
  _ = shift([cast(1.0, f64), cast(2.0, f64), cast(3.0, f64)], cast(-9223372036854775806, i64))
  ()
}
