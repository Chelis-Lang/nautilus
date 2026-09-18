module Nautilus.Tests_Neg.Roots.Int_Instantiation_Neg
import Nautilus.Roots (brent)
import Std.Test (assert_close)
-- Negative (nautilus#67): brent is generic over the Float family only. An
-- int64 objective must be refused at compile time, not truncated into a root.
def int_objective(x: int64) -> int64 = sub(mul(x, x), cast(2, int64))
def int_root() -> int64 = brent(int_objective, cast(1, int64), cast(2, int64), cast(0, int64), cast(100, int64))
def test_negative_roots_int_instantiation() -> unit ! { Test } = assert_close(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), "should not reach here")
