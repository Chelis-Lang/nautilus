module Nautilus.Tests_Neg.Rolling.Option_Form_Has_No_Tensor_Return_Neg
import Nautilus.Rolling (tensor_rolling_sum)
def test_tensor_return(xs: &tensor[4, f64]) -> tensor[4, f64] = tensor_rolling_sum(xs, cast(2, i64), cast(2, i64))
