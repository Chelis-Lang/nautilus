module Nautilus.Tests_Blocked.Generic_Dtype.Scalar_Cast_From_Float_Binder
import Std.Test (assert_true)
-- BLOCKED on chelis#2151. [05-OP-6] says `cast_trunc` has identical semantics
-- on scalar and tensor surfaces, but the checker rejects a SCALAR source typed
-- by a `Float`-bounded binder while accepting the tensor form over the same
-- binder.
--
-- Self-contained so it reports on the compiler, not on a Nautilus workaround.
-- The unconverted Nautilus.Stats would need exactly this cast in
-- `quantile_vec` and `trimmed_mean_vec` to go Float-generic (nautilus#69).
-- While this fails, a generic Stats has to route the truncation through a
-- length-1 tensor. When it passes, that detour is removable.
def sc_trunc[prec: Float](x: prec) -> int64 = cast_trunc(x, int64)
def test_blocked_scalar_cast_trunc_from_a_float_binder() -> unit ! { Test } = assert_true(eq(sc_trunc(7.999999999f64), 7i64), "cast_trunc of a Float-bounded scalar truncates toward zero at f64")
