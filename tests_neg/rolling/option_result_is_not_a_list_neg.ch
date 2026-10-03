module Nautilus.Tests_Neg.Rolling.Option_Result_Is_Not_A_List_Neg
import Nautilus.Rolling (rolling_mean, diff)
def test_warmup_cannot_be_dropped(xs: List[f64]) -> List[Option[f64]] = diff(rolling_mean(xs, cast(3, i64), cast(3, i64)), cast(1, i64))
