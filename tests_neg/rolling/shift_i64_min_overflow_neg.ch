module Nautilus.Tests_Neg.Rolling.Shift_I64_Min_Overflow_Neg
import Nautilus.Rolling (shift)
def test_shift_by_i64_min() -> unit ! { Test } = {
  _ = shift([cast(1.0, f64), cast(2.0, f64)], cast(-9223372036854775808, i64))
  ()
}
