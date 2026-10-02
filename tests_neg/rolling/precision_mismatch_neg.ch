module Nautilus.Tests_Neg.Rolling.Precision_Mismatch_Neg
import Nautilus.Rolling (rolling_sum)
def test_f32_input() -> List[Option[f64]] = rolling_sum([cast(1.0, f32), cast(2.0, f32)], cast(2, i64), cast(2, i64))
