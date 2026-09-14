module Nautilus.Blocked.NullaryReturnOnlyBinder
import Std.Test (assert_close)
-- chelis#2056: a bounded dtype binder that occurs only in a nullary def's
-- return type is never instantiated. `chelis check` reports score 1.0 with
-- zero errors; every lane that must produce a value then fails.
--
-- This is the exact shape `Nautilus.LinAlg.la_nan_val` had before it was
-- narrowed to take a `prec`-typed witness.
export (nan_val, test_nullary_return_only_binder_runs)
def nan_val[prec: Float]() -> prec = cast(0.0, prec) |> div(cast(0.0, prec))
def test_nullary_return_only_binder_runs() -> unit ! { Test } = {
  bad = nan_val()
  assert_close(add(bad, cast(1.0, f32)), cast(1.0, f32), cast(1e-6, f32), "a nullary return-only bounded binder produces a value")
}
