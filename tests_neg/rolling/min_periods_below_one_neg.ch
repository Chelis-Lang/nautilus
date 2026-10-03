module Nautilus.Tests_Neg.Rolling.Min_Periods_Below_One_Neg
import Nautilus.Rolling (rolling_mean)
def test_zero_min_periods() -> unit ! { Test } = {
  _ = rolling_mean([cast(1.0, f64), cast(2.0, f64)], cast(2, i64), cast(0, i64))
  ()
}
