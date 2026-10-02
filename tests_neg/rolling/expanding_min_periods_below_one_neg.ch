module Nautilus.Tests_Neg.Rolling.Expanding_Min_Periods_Below_One_Neg
import Nautilus.Rolling (expanding_var)
def test_zero_min_periods() -> unit ! { Test } = {
  _ = expanding_var([cast(1.0, f64), cast(2.0, f64)], cast(0, i64), cast(1, i64))
  ()
}
