module Nautilus.Tests_Neg.Rolling.Shift_I64_Min_Plus_One_Overflow_Neg
import Nautilus.Rolling (diff)
def test_diff_by_i64_min_plus_one() -> unit ! { Test } = {
  _ = diff([cast(1.0, f64), cast(2.0, f64)], cast(-9223372036854775807, i64))
  ()
}
