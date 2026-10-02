module Nautilus.Tests_Neg.Rolling.Min_Periods_Above_Window_Neg
import Nautilus.Rolling (rolling_sum)
def test_min_periods_exceeds_window() -> unit ! { Test } = {
  _ = rolling_sum([cast(1.0, f64), cast(2.0, f64), cast(3.0, f64)], cast(2, i64), cast(3, i64))
  ()
}
