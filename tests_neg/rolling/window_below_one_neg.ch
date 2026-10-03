module Nautilus.Tests_Neg.Rolling.Window_Below_One_Neg
import Nautilus.Rolling (rolling_sum)
def test_zero_window() -> unit ! { Test } = {
  _ = rolling_sum([cast(1.0, f64), cast(2.0, f64)], cast(0, i64), cast(1, i64))
  ()
}
