module Nautilus.Tests_Neg.Rolling.Negative_Ddof_Neg
import Nautilus.Rolling (rolling_std)
def test_negative_ddof() -> unit ! { Test } = {
  _ = rolling_std([cast(1.0, f64), cast(2.0, f64)], cast(2, i64), cast(2, i64), cast(-1, i64))
  ()
}
