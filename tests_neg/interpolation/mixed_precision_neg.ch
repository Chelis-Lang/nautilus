module Nautilus.Tests_Neg.Interpolation.Mixed_Precision_Neg
import Nautilus.Interpolation (linear_interp_sorted)
import Std.Test (assert_close)
-- Negative (nautilus#67): one binder governs the grid and the query, so an f64
-- grid queried at an f32 point must be refused rather than implicitly
-- promoted.
def mixed_query(xs: tensor[3, f64], ys: tensor[3, f64], q: f32) -> f64 = linear_interp_sorted(xs, ys, q)
def test_negative_interpolation_mixed_precision() -> unit ! { Test } = assert_close(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), "should not reach here")
