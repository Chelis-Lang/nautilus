module Nautilus.Tests_Neg.Rolling.Tensor_Precision_Mismatch_Neg
import Nautilus.Rolling (tensor_rolling_mean)
def test_f32_tensor(xs: &tensor[4, f32]) -> List[Option[f64]] = tensor_rolling_mean(xs, cast(2, i64), cast(2, i64))
