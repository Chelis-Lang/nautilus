module Nautilus.Tests.Rolling
import Nautilus.Rolling (rolling_sum, rolling_mean, rolling_var, rolling_std, rolling_min, rolling_max, expanding_sum, expanding_mean, expanding_var, expanding_std, expanding_min, expanding_max, shift, shift_fill, shift_clamped, diff, pct_change, tensor_rolling_sum, tensor_rolling_mean, tensor_rolling_var, tensor_rolling_std, tensor_rolling_min, tensor_rolling_max, tensor_expanding_sum, tensor_expanding_mean, tensor_expanding_var, tensor_expanding_std, tensor_expanding_min, tensor_expanding_max, tensor_shift, tensor_shift_fill, tensor_shift_clamped, tensor_diff, tensor_pct_change)
import Std.Test (assert_close, assert_true)
-- The fixture is 5, 2, 7, 3, 9, 1: non-monotonic, with a distinct minimum
-- and maximum inside most windows, so no two exports below produce the same
-- vector. A geometric fixture would make `diff` and `shift` agree, and a
-- sorted one would make every rolling minimum the first window element.
--
-- The expected values are pandas 2.3.3 output, not hand arithmetic. The full
-- pandas conformance set lives in `parity/goldens/rolling.json` and is
-- replayed by `scripts/check_rolling_parity.py`; this suite pins a
-- representative pair of configurations per export plus the structural and
-- degenerate-domain behaviour that the parity goldens deliberately exclude.
def ns() -> List[f64] = [cast(5.0, f64), cast(2.0, f64), cast(7.0, f64), cast(3.0, f64), cast(9.0, f64), cast(1.0, f64)]
def nt() -> tensor[6, f64] = to_tensor(ns())
def present(o: Option[f64]) -> bool =
  match o with {
    | None => false
    | Some(_v) => true
  }
def value_or(o: Option[f64], fallback: f64) -> f64 =
  match o with {
    | None => fallback
    | Some(v) => v
  }
def roll_abs(x: f64) -> f64 = if lt(x, cast(0.0, f64)) then neg(x) else x
-- Presence is compared before value, and the `value_or` fallback is only
-- reachable once both sides are known present. `test_helper_*` below pins
-- that this returns false for a wrong length, a wrong presence and a wrong
-- value, so a vacuous comparison cannot carry the suite.
def agrees(a: Option[f64], b: Option[f64], tol_value: f64) -> bool = {
  pa = present(a)
  pb = present(b)
  if pa then if pb then lte(roll_abs(sub(value_or(a, cast(0.0, f64)), value_or(b, cast(0.0, f64)))), tol_value) else false else if pb then false else true
}
def series_agrees(actual: List[Option[f64]], expected: List[Option[f64]], tol_value: f64) -> bool = if eq(len(actual), len(expected)) then fold(fn (acc: bool, pair: (Option[f64], Option[f64])) -> if acc then agrees(pair.0, pair.1, tol_value) else false, true, zip(actual, expected)) else false
def dense_agrees(actual: List[f64], expected: List[f64], tol_value: f64) -> bool = if eq(len(actual), len(expected)) then fold(fn (acc: bool, pair: (f64, f64)) -> if acc then lte(roll_abs(sub(pair.0, pair.1)), tol_value) else false, true, zip(actual, expected)) else false
def present_count(xs: List[Option[f64]]) -> i64 = fold(fn (acc: i64, o: Option[f64]) -> if present(o) then add(acc, cast(1, i64)) else acc, cast(0, i64), xs)
def leading_absent(xs: List[Option[f64]]) -> i64 = fold(fn (acc: (i64, bool), o: Option[f64]) -> if acc.1 then if present(o) then (acc.0, false) else (add(acc.0, cast(1, i64)), true) else acc, (cast(0, i64), true), xs).0
def tol() -> f64 = cast(1e-12, f64)
def test_rolling_sum_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(rolling_sum(ns(), cast(2, i64), cast(2, i64)), [None, Some(cast(7.0, f64)), Some(cast(9.0, f64)), Some(cast(10.0, f64)), Some(cast(12.0, f64)), Some(cast(10.0, f64))], tol()), "rolling_sum: window 2, min_periods 2")
  assert_true(series_agrees(rolling_sum(ns(), cast(3, i64), cast(1, i64)), [Some(cast(5.0, f64)), Some(cast(7.0, f64)), Some(cast(14.0, f64)), Some(cast(12.0, f64)), Some(cast(19.0, f64)), Some(cast(13.0, f64))], tol()), "rolling_sum: window 3, min_periods 1")
}
def test_rolling_mean_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(rolling_mean(ns(), cast(2, i64), cast(2, i64)), [None, Some(cast(3.5, f64)), Some(cast(4.5, f64)), Some(cast(5.0, f64)), Some(cast(6.0, f64)), Some(cast(5.0, f64))], tol()), "rolling_mean: window 2, min_periods 2")
  assert_true(series_agrees(rolling_mean(ns(), cast(3, i64), cast(1, i64)), [Some(cast(5.0, f64)), Some(cast(3.5, f64)), Some(cast(4.666666666666667, f64)), Some(cast(4.0, f64)), Some(cast(6.333333333333333, f64)), Some(cast(4.333333333333333, f64))], tol()), "rolling_mean: window 3, min_periods 1")
}
def test_rolling_min_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(rolling_min(ns(), cast(2, i64), cast(2, i64)), [None, Some(cast(2.0, f64)), Some(cast(2.0, f64)), Some(cast(3.0, f64)), Some(cast(3.0, f64)), Some(cast(1.0, f64))], tol()), "rolling_min: window 2, min_periods 2")
  assert_true(series_agrees(rolling_min(ns(), cast(3, i64), cast(1, i64)), [Some(cast(5.0, f64)), Some(cast(2.0, f64)), Some(cast(2.0, f64)), Some(cast(2.0, f64)), Some(cast(3.0, f64)), Some(cast(1.0, f64))], tol()), "rolling_min: window 3, min_periods 1")
}
def test_rolling_max_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(rolling_max(ns(), cast(2, i64), cast(2, i64)), [None, Some(cast(5.0, f64)), Some(cast(7.0, f64)), Some(cast(7.0, f64)), Some(cast(9.0, f64)), Some(cast(9.0, f64))], tol()), "rolling_max: window 2, min_periods 2")
  assert_true(series_agrees(rolling_max(ns(), cast(3, i64), cast(1, i64)), [Some(cast(5.0, f64)), Some(cast(5.0, f64)), Some(cast(7.0, f64)), Some(cast(7.0, f64)), Some(cast(9.0, f64)), Some(cast(9.0, f64))], tol()), "rolling_max: window 3, min_periods 1")
}
def test_rolling_var_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(rolling_var(ns(), cast(2, i64), cast(2, i64), cast(1, i64)), [None, Some(cast(4.5, f64)), Some(cast(12.5, f64)), Some(cast(8.0, f64)), Some(cast(18.0, f64)), Some(cast(32.0, f64))], tol()), "rolling_var: window 2, min_periods 2, ddof 1 (pandas default)")
  _ = assert_true(series_agrees(rolling_var(ns(), cast(2, i64), cast(2, i64), cast(0, i64)), [None, Some(cast(2.25, f64)), Some(cast(6.25, f64)), Some(cast(4.0, f64)), Some(cast(9.0, f64)), Some(cast(16.0, f64))], tol()), "rolling_var: window 2, min_periods 2, ddof 0")
  assert_true(series_agrees(rolling_var(ns(), cast(3, i64), cast(2, i64), cast(1, i64)), [None, Some(cast(4.5, f64)), Some(cast(6.333333333333333, f64)), Some(cast(7.0, f64)), Some(cast(9.333333333333334, f64)), Some(cast(17.333333333333332, f64))], tol()), "rolling_var: window 3, min_periods 2, ddof 1")
}
def test_rolling_std_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(rolling_std(ns(), cast(2, i64), cast(2, i64), cast(1, i64)), [None, Some(cast(2.1213203435596424, f64)), Some(cast(3.5355339059327378, f64)), Some(cast(2.8284271247461903, f64)), Some(cast(4.242640687119285, f64)), Some(cast(5.656854249492381, f64))], tol()), "rolling_std: window 2, min_periods 2, ddof 1 (pandas default)")
  _ = assert_true(series_agrees(rolling_std(ns(), cast(2, i64), cast(2, i64), cast(0, i64)), [None, Some(cast(1.5, f64)), Some(cast(2.5, f64)), Some(cast(2.0, f64)), Some(cast(3.0, f64)), Some(cast(4.0, f64))], tol()), "rolling_std: window 2, min_periods 2, ddof 0")
  assert_true(series_agrees(rolling_std(ns(), cast(3, i64), cast(2, i64), cast(1, i64)), [None, Some(cast(2.1213203435596424, f64)), Some(cast(2.516611478423583, f64)), Some(cast(2.6457513110645907, f64)), Some(cast(3.0550504633038935, f64)), Some(cast(4.163331998932265, f64))], tol()), "rolling_std: window 3, min_periods 2, ddof 1")
}
def test_expanding_sum_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(expanding_sum(ns(), cast(1, i64)), [Some(cast(5.0, f64)), Some(cast(7.0, f64)), Some(cast(14.0, f64)), Some(cast(17.0, f64)), Some(cast(26.0, f64)), Some(cast(27.0, f64))], tol()), "expanding_sum: min_periods 1")
  assert_true(series_agrees(expanding_sum(ns(), cast(3, i64)), [None, None, Some(cast(14.0, f64)), Some(cast(17.0, f64)), Some(cast(26.0, f64)), Some(cast(27.0, f64))], tol()), "expanding_sum: min_periods 3")
}
def test_expanding_mean_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(expanding_mean(ns(), cast(1, i64)), [Some(cast(5.0, f64)), Some(cast(3.5, f64)), Some(cast(4.666666666666667, f64)), Some(cast(4.25, f64)), Some(cast(5.2, f64)), Some(cast(4.5, f64))], tol()), "expanding_mean: min_periods 1")
  assert_true(series_agrees(expanding_mean(ns(), cast(3, i64)), [None, None, Some(cast(4.666666666666667, f64)), Some(cast(4.25, f64)), Some(cast(5.2, f64)), Some(cast(4.5, f64))], tol()), "expanding_mean: min_periods 3")
}
def test_expanding_min_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(expanding_min(ns(), cast(1, i64)), [Some(cast(5.0, f64)), Some(cast(2.0, f64)), Some(cast(2.0, f64)), Some(cast(2.0, f64)), Some(cast(2.0, f64)), Some(cast(1.0, f64))], tol()), "expanding_min: min_periods 1")
  assert_true(series_agrees(expanding_min(ns(), cast(3, i64)), [None, None, Some(cast(2.0, f64)), Some(cast(2.0, f64)), Some(cast(2.0, f64)), Some(cast(1.0, f64))], tol()), "expanding_min: min_periods 3")
}
def test_expanding_max_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(expanding_max(ns(), cast(1, i64)), [Some(cast(5.0, f64)), Some(cast(5.0, f64)), Some(cast(7.0, f64)), Some(cast(7.0, f64)), Some(cast(9.0, f64)), Some(cast(9.0, f64))], tol()), "expanding_max: min_periods 1")
  assert_true(series_agrees(expanding_max(ns(), cast(3, i64)), [None, None, Some(cast(7.0, f64)), Some(cast(7.0, f64)), Some(cast(9.0, f64)), Some(cast(9.0, f64))], tol()), "expanding_max: min_periods 3")
}
def test_expanding_var_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(expanding_var(ns(), cast(2, i64), cast(1, i64)), [None, Some(cast(4.5, f64)), Some(cast(6.333333333333333, f64)), Some(cast(4.916666666666667, f64)), Some(cast(8.2, f64)), Some(cast(9.5, f64))], tol()), "expanding_var: min_periods 2, ddof 1")
  assert_true(series_agrees(expanding_var(ns(), cast(2, i64), cast(0, i64)), [None, Some(cast(2.25, f64)), Some(cast(4.222222222222222, f64)), Some(cast(3.6875, f64)), Some(cast(6.56, f64)), Some(cast(7.916666666666667, f64))], tol()), "expanding_var: min_periods 2, ddof 0")
}
def test_expanding_std_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(expanding_std(ns(), cast(2, i64), cast(1, i64)), [None, Some(cast(2.1213203435596424, f64)), Some(cast(2.516611478423583, f64)), Some(cast(2.217355782608345, f64)), Some(cast(2.8635642126552705, f64)), Some(cast(3.082207001484488, f64))], tol()), "expanding_std: min_periods 2, ddof 1")
  assert_true(series_agrees(expanding_std(ns(), cast(2, i64), cast(0, i64)), [None, Some(cast(1.5, f64)), Some(cast(2.0548046676563256, f64)), Some(cast(1.920286436967152, f64)), Some(cast(2.5612496949731396, f64)), Some(cast(2.8136571693556887, f64))], tol()), "expanding_std: min_periods 2, ddof 0")
}
def test_shift_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(shift(ns(), cast(1, i64)), [None, Some(cast(5.0, f64)), Some(cast(2.0, f64)), Some(cast(7.0, f64)), Some(cast(3.0, f64)), Some(cast(9.0, f64))], tol()), "shift: lag 1")
  _ = assert_true(series_agrees(shift(ns(), cast(2, i64)), [None, None, Some(cast(5.0, f64)), Some(cast(2.0, f64)), Some(cast(7.0, f64)), Some(cast(3.0, f64))], tol()), "shift: lag 2")
  assert_true(series_agrees(shift(ns(), cast(-1, i64)), [Some(cast(2.0, f64)), Some(cast(7.0, f64)), Some(cast(3.0, f64)), Some(cast(9.0, f64)), Some(cast(1.0, f64)), None], tol()), "shift: lead 1 (pandas negative periods)")
}
def test_diff_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(diff(ns(), cast(1, i64)), [None, Some(cast(-3.0, f64)), Some(cast(5.0, f64)), Some(cast(-4.0, f64)), Some(cast(6.0, f64)), Some(cast(-8.0, f64))], tol()), "diff: backward difference")
  _ = assert_true(series_agrees(diff(ns(), cast(2, i64)), [None, None, Some(cast(2.0, f64)), Some(cast(1.0, f64)), Some(cast(2.0, f64)), Some(cast(-2.0, f64))], tol()), "diff: lag 2")
  assert_true(series_agrees(diff(ns(), cast(-1, i64)), [Some(cast(3.0, f64)), Some(cast(-5.0, f64)), Some(cast(4.0, f64)), Some(cast(-6.0, f64)), Some(cast(8.0, f64)), None], tol()), "diff: forward difference")
}
def test_pct_change_values() -> unit ! { Test } = {
  _ = assert_true(series_agrees(pct_change(ns(), cast(1, i64)), [None, Some(cast(-0.6, f64)), Some(cast(2.5, f64)), Some(cast(-0.5714285714285714, f64)), Some(cast(2.0, f64)), Some(cast(-0.8888888888888888, f64))], tol()), "pct_change: lag 1")
  _ = assert_true(series_agrees(pct_change(ns(), cast(2, i64)), [None, None, Some(cast(0.3999999999999999, f64)), Some(cast(0.5, f64)), Some(cast(0.2857142857142858, f64)), Some(cast(-0.6666666666666667, f64))], tol()), "pct_change: lag 2")
  assert_true(series_agrees(pct_change(ns(), cast(-1, i64)), [Some(cast(1.5, f64)), Some(cast(-0.7142857142857143, f64)), Some(cast(1.3333333333333335, f64)), Some(cast(-0.6666666666666667, f64)), Some(cast(8.0, f64)), None], tol()), "pct_change: lead 1")
}
def test_shift_fill_values() -> unit ! { Test } = {
  _ = assert_true(dense_agrees(shift_fill(ns(), cast(1, i64), cast(0.0, f64)), [cast(0.0, f64), cast(5.0, f64), cast(2.0, f64), cast(7.0, f64), cast(3.0, f64), cast(9.0, f64)], tol()), "shift_fill: lag 1 with a zero pad")
  assert_true(dense_agrees(shift_fill(ns(), cast(-1, i64), cast(-4.0, f64)), [cast(2.0, f64), cast(7.0, f64), cast(3.0, f64), cast(9.0, f64), cast(1.0, f64), cast(-4.0, f64)], tol()), "shift_fill: lead 1 with a negative pad")
}
def test_shift_clamped_values() -> unit ! { Test } = {
  _ = assert_true(dense_agrees(shift_clamped(ns(), cast(1, i64)), [cast(5.0, f64), cast(5.0, f64), cast(2.0, f64), cast(7.0, f64), cast(3.0, f64), cast(9.0, f64)], tol()), "shift_clamped: lag 1 clamps to the first observation")
  assert_true(dense_agrees(shift_clamped(ns(), cast(-2, i64)), [cast(7.0, f64), cast(3.0, f64), cast(9.0, f64), cast(1.0, f64), cast(1.0, f64), cast(1.0, f64)], tol()), "shift_clamped: lead 2 clamps to the last observation")
}
-- Tensor entry points. Each is asserted against its list twin on the same
-- data at two configurations, which is the whole of their contract: they
-- convert and delegate, and `scripts/check_rolling_tensor_parity.py` proves
-- the delegation is literal rather than re-derived.
def test_tensor_rolling_delegates() -> unit ! { Test } = {
  _ = assert_true(series_agrees(tensor_rolling_sum(nt(), cast(2, i64), cast(2, i64)), rolling_sum(ns(), cast(2, i64), cast(2, i64)), tol()), "tensor_rolling_sum: window 2, min_periods 2")
  _ = assert_true(series_agrees(tensor_rolling_sum(nt(), cast(3, i64), cast(1, i64)), rolling_sum(ns(), cast(3, i64), cast(1, i64)), tol()), "tensor_rolling_sum: window 3, min_periods 1")
  _ = assert_true(series_agrees(tensor_rolling_mean(nt(), cast(2, i64), cast(2, i64)), rolling_mean(ns(), cast(2, i64), cast(2, i64)), tol()), "tensor_rolling_mean: window 2, min_periods 2")
  _ = assert_true(series_agrees(tensor_rolling_mean(nt(), cast(4, i64), cast(2, i64)), rolling_mean(ns(), cast(4, i64), cast(2, i64)), tol()), "tensor_rolling_mean: window 4, min_periods 2")
  _ = assert_true(series_agrees(tensor_rolling_min(nt(), cast(2, i64), cast(2, i64)), rolling_min(ns(), cast(2, i64), cast(2, i64)), tol()), "tensor_rolling_min: window 2, min_periods 2")
  _ = assert_true(series_agrees(tensor_rolling_min(nt(), cast(3, i64), cast(1, i64)), rolling_min(ns(), cast(3, i64), cast(1, i64)), tol()), "tensor_rolling_min: window 3, min_periods 1")
  _ = assert_true(series_agrees(tensor_rolling_max(nt(), cast(2, i64), cast(2, i64)), rolling_max(ns(), cast(2, i64), cast(2, i64)), tol()), "tensor_rolling_max: window 2, min_periods 2")
  _ = assert_true(series_agrees(tensor_rolling_max(nt(), cast(3, i64), cast(1, i64)), rolling_max(ns(), cast(3, i64), cast(1, i64)), tol()), "tensor_rolling_max: window 3, min_periods 1")
  _ = assert_true(series_agrees(tensor_rolling_var(nt(), cast(2, i64), cast(2, i64), cast(1, i64)), rolling_var(ns(), cast(2, i64), cast(2, i64), cast(1, i64)), tol()), "tensor_rolling_var: ddof 1")
  _ = assert_true(series_agrees(tensor_rolling_var(nt(), cast(3, i64), cast(2, i64), cast(0, i64)), rolling_var(ns(), cast(3, i64), cast(2, i64), cast(0, i64)), tol()), "tensor_rolling_var: ddof 0")
  _ = assert_true(series_agrees(tensor_rolling_std(nt(), cast(2, i64), cast(2, i64), cast(1, i64)), rolling_std(ns(), cast(2, i64), cast(2, i64), cast(1, i64)), tol()), "tensor_rolling_std: ddof 1")
  assert_true(series_agrees(tensor_rolling_std(nt(), cast(3, i64), cast(2, i64), cast(0, i64)), rolling_std(ns(), cast(3, i64), cast(2, i64), cast(0, i64)), tol()), "tensor_rolling_std: ddof 0")
}
def test_tensor_expanding_delegates() -> unit ! { Test } = {
  _ = assert_true(series_agrees(tensor_expanding_sum(nt(), cast(1, i64)), expanding_sum(ns(), cast(1, i64)), tol()), "tensor_expanding_sum: min_periods 1")
  _ = assert_true(series_agrees(tensor_expanding_sum(nt(), cast(3, i64)), expanding_sum(ns(), cast(3, i64)), tol()), "tensor_expanding_sum: min_periods 3")
  _ = assert_true(series_agrees(tensor_expanding_mean(nt(), cast(1, i64)), expanding_mean(ns(), cast(1, i64)), tol()), "tensor_expanding_mean: min_periods 1")
  _ = assert_true(series_agrees(tensor_expanding_mean(nt(), cast(3, i64)), expanding_mean(ns(), cast(3, i64)), tol()), "tensor_expanding_mean: min_periods 3")
  _ = assert_true(series_agrees(tensor_expanding_min(nt(), cast(1, i64)), expanding_min(ns(), cast(1, i64)), tol()), "tensor_expanding_min: min_periods 1")
  _ = assert_true(series_agrees(tensor_expanding_min(nt(), cast(4, i64)), expanding_min(ns(), cast(4, i64)), tol()), "tensor_expanding_min: min_periods 4")
  _ = assert_true(series_agrees(tensor_expanding_max(nt(), cast(1, i64)), expanding_max(ns(), cast(1, i64)), tol()), "tensor_expanding_max: min_periods 1")
  _ = assert_true(series_agrees(tensor_expanding_max(nt(), cast(4, i64)), expanding_max(ns(), cast(4, i64)), tol()), "tensor_expanding_max: min_periods 4")
  _ = assert_true(series_agrees(tensor_expanding_var(nt(), cast(2, i64), cast(1, i64)), expanding_var(ns(), cast(2, i64), cast(1, i64)), tol()), "tensor_expanding_var: ddof 1")
  _ = assert_true(series_agrees(tensor_expanding_var(nt(), cast(2, i64), cast(0, i64)), expanding_var(ns(), cast(2, i64), cast(0, i64)), tol()), "tensor_expanding_var: ddof 0")
  _ = assert_true(series_agrees(tensor_expanding_std(nt(), cast(2, i64), cast(1, i64)), expanding_std(ns(), cast(2, i64), cast(1, i64)), tol()), "tensor_expanding_std: ddof 1")
  assert_true(series_agrees(tensor_expanding_std(nt(), cast(2, i64), cast(0, i64)), expanding_std(ns(), cast(2, i64), cast(0, i64)), tol()), "tensor_expanding_std: ddof 0")
}
-- `tensor_shift_fill` and `tensor_shift_clamped` are the only two tensor
-- forms that return a tensor, because they are the only two whose result has
-- no absent position. The other fifteen return a list for the reason
-- `src/rolling.ch` gives: a tensor element is a precision type and has no
-- inhabitant for "absent" that is not also a number a caller could read.
def test_tensor_lag_delegates() -> unit ! { Test } = {
  _ = assert_true(series_agrees(tensor_shift(nt(), cast(1, i64)), shift(ns(), cast(1, i64)), tol()), "tensor_shift: lag 1")
  _ = assert_true(series_agrees(tensor_shift(nt(), cast(-2, i64)), shift(ns(), cast(-2, i64)), tol()), "tensor_shift: lead 2")
  _ = assert_true(series_agrees(tensor_diff(nt(), cast(1, i64)), diff(ns(), cast(1, i64)), tol()), "tensor_diff: lag 1")
  _ = assert_true(series_agrees(tensor_diff(nt(), cast(-1, i64)), diff(ns(), cast(-1, i64)), tol()), "tensor_diff: forward difference")
  _ = assert_true(series_agrees(tensor_pct_change(nt(), cast(1, i64)), pct_change(ns(), cast(1, i64)), tol()), "tensor_pct_change: lag 1")
  _ = assert_true(series_agrees(tensor_pct_change(nt(), cast(2, i64)), pct_change(ns(), cast(2, i64)), tol()), "tensor_pct_change: lag 2")
  _ = assert_true(dense_agrees(to_list(tensor_shift_fill(nt(), cast(1, i64), cast(0.0, f64))), shift_fill(ns(), cast(1, i64), cast(0.0, f64)), tol()), "tensor_shift_fill: lag 1, zero pad")
  _ = assert_true(dense_agrees(to_list(tensor_shift_fill(nt(), cast(-1, i64), cast(-4.0, f64))), shift_fill(ns(), cast(-1, i64), cast(-4.0, f64)), tol()), "tensor_shift_fill: lead 1, negative pad")
  _ = assert_true(dense_agrees(to_list(tensor_shift_clamped(nt(), cast(1, i64))), shift_clamped(ns(), cast(1, i64)), tol()), "tensor_shift_clamped: lag 1")
  assert_true(dense_agrees(to_list(tensor_shift_clamped(nt(), cast(-2, i64))), shift_clamped(ns(), cast(-2, i64)), tol()), "tensor_shift_clamped: lead 2")
}
-- Structural invariants. These hold for every argument, so they are stated
-- once over several configurations rather than restated per export.
def test_output_length_equals_input_length() -> unit ! { Test } = {
  n = len(ns())
  _ = assert_true(eq(len(rolling_sum(ns(), cast(4, i64), cast(2, i64))), n), "rolling_sum returns one entry per observation")
  _ = assert_true(eq(len(expanding_mean(ns(), cast(3, i64))), n), "expanding_mean returns one entry per observation")
  _ = assert_true(eq(len(shift(ns(), cast(3, i64))), n), "shift returns one entry per observation")
  _ = assert_true(eq(len(shift_fill(ns(), cast(3, i64), cast(0.0, f64))), n), "shift_fill returns one entry per observation")
  _ = assert_true(eq(len(shift_clamped(ns(), cast(3, i64))), n), "shift_clamped returns one entry per observation")
  _ = assert_true(eq(len(diff(ns(), cast(2, i64))), n), "diff returns one entry per observation")
  _ = assert_true(eq(len(pct_change(ns(), cast(2, i64))), n), "pct_change returns one entry per observation")
  assert_true(eq(len(rolling_std(ns(), cast(6, i64), cast(6, i64), cast(1, i64))), n), "a full-length window still returns one entry per observation")
}
-- The warm-up is exactly min_periods - 1 entries long and does not depend on
-- the window. That is the whole of the `min_periods` contract, and it is the
-- part a hand-written version gets wrong by tying absence to the window.
def test_warmup_length_is_min_periods_minus_one() -> unit ! { Test } = {
  _ = assert_true(eq(leading_absent(rolling_sum(ns(), cast(2, i64), cast(2, i64))), cast(1, i64)), "rolling_sum: window 2, min_periods 2 has one absent entry")
  _ = assert_true(eq(leading_absent(rolling_sum(ns(), cast(3, i64), cast(1, i64))), cast(0, i64)), "rolling_sum: min_periods 1 has no absent entry even at window 3")
  _ = assert_true(eq(leading_absent(rolling_sum(ns(), cast(4, i64), cast(3, i64))), cast(2, i64)), "rolling_sum: window 4, min_periods 3 has two absent entries")
  _ = assert_true(eq(leading_absent(rolling_sum(ns(), cast(6, i64), cast(6, i64))), cast(5, i64)), "rolling_sum: a full-length window absents all but the last entry")
  _ = assert_true(eq(leading_absent(expanding_sum(ns(), cast(1, i64))), cast(0, i64)), "expanding_sum: min_periods 1 has no absent entry")
  _ = assert_true(eq(leading_absent(expanding_sum(ns(), cast(4, i64))), cast(3, i64)), "expanding_sum: min_periods 4 has three absent entries")
  _ = assert_true(eq(present_count(rolling_mean(ns(), cast(3, i64), cast(3, i64))), cast(4, i64)), "rolling_mean: six observations at min_periods 3 give four values")
  assert_true(eq(present_count(expanding_var(ns(), cast(2, i64), cast(1, i64))), cast(5, i64)), "expanding_var: six observations at min_periods 2 give five values")
}
-- min_periods below the window reduces over a SHORTER window rather than
-- reporting absence, so the first entry is the first observation itself.
def test_short_leading_windows() -> unit ! { Test } = {
  short = rolling_sum(ns(), cast(3, i64), cast(1, i64))
  _ = assert_close(value_or(index(short, cast(0, i64)), cast(0.0, f64)), cast(5.0, f64), tol(), "rolling_sum at index 0 reduces one observation, not three")
  _ = assert_close(value_or(index(short, cast(1, i64)), cast(0.0, f64)), cast(7.0, f64), tol(), "rolling_sum at index 1 reduces two observations")
  full = rolling_sum(ns(), cast(6, i64), cast(1, i64))
  assert_true(series_agrees(full, expanding_sum(ns(), cast(1, i64)), tol()), "a window as wide as the series is the expanding window")
}
-- No look-ahead: changing an observation cannot change any earlier output.
-- The perturbation is large, and the prefix is compared entry by entry.
def test_no_look_ahead() -> unit ! { Test } = {
  tampered = [cast(5.0, f64), cast(2.0, f64), cast(7.0, f64), cast(3.0, f64), cast(9.0, f64), cast(1000.0, f64)]
  base = rolling_mean(ns(), cast(2, i64), cast(1, i64))
  moved = rolling_mean(tampered, cast(2, i64), cast(1, i64))
  prefix = cast(5, i64)
  _ = assert_true(series_agrees(take(base, prefix), take(moved, prefix), tol()), "rolling_mean: the last observation does not reach earlier outputs")
  _ = assert_true(if series_agrees(base, moved, tol()) then false else true, "rolling_mean: the last observation does reach the last output")
  base_diff = diff(ns(), cast(1, i64))
  moved_diff = diff(tampered, cast(1, i64))
  assert_true(series_agrees(take(base_diff, prefix), take(moved_diff, prefix), tol()), "diff: the last observation does not reach earlier outputs")
}
-- Degenerate domain. These are the inputs the pandas goldens deliberately
-- leave out: an empty series, a window wider than the data, a lag past
-- either end, and the two results that are undefined rather than absent.
def empty_series() -> List[f64] = []
def test_empty_series_returns_empty() -> unit ! { Test } = {
  _ = assert_true(eq(len(rolling_sum(empty_series(), cast(3, i64), cast(3, i64))), cast(0, i64)), "rolling_sum of an empty series is empty")
  _ = assert_true(eq(len(rolling_std(empty_series(), cast(1, i64), cast(1, i64), cast(0, i64))), cast(0, i64)), "rolling_std of an empty series is empty")
  _ = assert_true(eq(len(expanding_mean(empty_series(), cast(1, i64))), cast(0, i64)), "expanding_mean of an empty series is empty, and the expanding window does not trip the window check")
  _ = assert_true(eq(len(expanding_var(empty_series(), cast(2, i64), cast(1, i64))), cast(0, i64)), "expanding_var of an empty series is empty")
  _ = assert_true(eq(len(shift(empty_series(), cast(1, i64))), cast(0, i64)), "shift of an empty series is empty")
  _ = assert_true(eq(len(shift_fill(empty_series(), cast(1, i64), cast(0.0, f64))), cast(0, i64)), "shift_fill of an empty series is empty")
  _ = assert_true(eq(len(shift_clamped(empty_series(), cast(1, i64))), cast(0, i64)), "shift_clamped of an empty series is empty and never indexes a last element")
  _ = assert_true(eq(len(diff(empty_series(), cast(1, i64))), cast(0, i64)), "diff of an empty series is empty")
  assert_true(eq(len(pct_change(empty_series(), cast(1, i64))), cast(0, i64)), "pct_change of an empty series is empty")
}
def test_window_wider_than_series() -> unit ! { Test } = {
  reaching = rolling_sum(ns(), cast(10, i64), cast(6, i64))
  _ = assert_true(eq(present_count(reaching), cast(1, i64)), "a window of 10 at min_periods 6 yields one value on six observations")
  _ = assert_close(value_or(index(reaching, cast(5, i64)), cast(0.0, f64)), cast(27.0, f64), tol(), "that value reduces every observation, not ten of them")
  unreachable = rolling_mean(ns(), cast(10, i64), cast(8, i64))
  _ = assert_true(eq(present_count(unreachable), cast(0, i64)), "min_periods beyond the series length yields no value at all")
  assert_true(eq(len(unreachable), cast(6, i64)), "and still returns one entry per observation")
}
def test_lag_past_either_end() -> unit ! { Test } = {
  _ = assert_true(eq(present_count(shift(ns(), cast(6, i64))), cast(0, i64)), "a lag of the series length absents every entry")
  _ = assert_true(eq(present_count(shift(ns(), cast(-9, i64))), cast(0, i64)), "a lead past the end absents every entry")
  _ = assert_true(eq(present_count(diff(ns(), cast(99, i64))), cast(0, i64)), "diff past either end absents every entry")
  _ = assert_true(eq(present_count(shift(ns(), cast(0, i64))), cast(6, i64)), "a zero shift is the identity and absents nothing")
  _ = assert_true(series_agrees(diff(ns(), cast(0, i64)), [Some(cast(0.0, f64)), Some(cast(0.0, f64)), Some(cast(0.0, f64)), Some(cast(0.0, f64)), Some(cast(0.0, f64)), Some(cast(0.0, f64))], tol()), "a zero diff is zero everywhere")
  -- A fill is supplied, so an out-of-range lag pads rather than absenting.
  _ = assert_true(dense_agrees(shift_fill(ns(), cast(6, i64), cast(-1.0, f64)), [cast(-1.0, f64), cast(-1.0, f64), cast(-1.0, f64), cast(-1.0, f64), cast(-1.0, f64), cast(-1.0, f64)], tol()), "shift_fill past the end is all pad")
  assert_true(dense_agrees(shift_clamped(ns(), cast(6, i64)), [cast(5.0, f64), cast(5.0, f64), cast(5.0, f64), cast(5.0, f64), cast(5.0, f64), cast(5.0, f64)], tol()), "shift_clamped past the end clamps to the first observation")
}
-- The lag family traps only where `i - k` overflows, which is the `len(xs)`
-- most negative values of `k` because the largest index overflows first. The
-- two negative tests pin the trapping side at `i64::MIN` and `i64::MIN + 1`;
-- this pins the first `k` that does NOT trap, so the boundary is fixed from
-- both directions and the set cannot silently widen.
def test_lag_trapping_set_scales_with_length() -> unit ! { Test } = {
  pair = [cast(1.0, f64), cast(2.0, f64)]
  almost = cast(-9223372036854775806, i64)
  _ = assert_true(eq(present_count(shift(pair, almost)), cast(0, i64)), "shift at i64::MIN + 2 on a two-element series is all absent, not a trap")
  _ = assert_true(eq(len(shift(pair, almost)), cast(2, i64)), "and still returns one entry per observation")
  _ = assert_true(eq(present_count(diff(pair, almost)), cast(0, i64)), "diff at i64::MIN + 2 is all absent too")
  assert_true(eq(present_count(pct_change(pair, almost)), cast(0, i64)), "and so is pct_change")
}
-- The warm-up is `min_periods - 1` entries CLIPPED at the length of the
-- series, because the result always has exactly one entry per observation.
def test_warmup_is_clipped_to_the_series() -> unit ! { Test } = {
  one = [cast(5.0, f64)]
  short = rolling_sum(one, cast(3, i64), cast(3, i64))
  _ = assert_true(eq(len(short), cast(1, i64)), "a min_periods above the length still returns one entry per observation")
  _ = assert_true(eq(leading_absent(short), cast(1, i64)), "and its warm-up is the whole series, not min_periods - 1")
  empty_expanding = expanding_mean(empty_series(), cast(5, i64))
  assert_true(eq(len(empty_expanding), cast(0, i64)), "an empty series clips the warm-up to nothing")
}
-- Undefined is not absent. A zero base and a ddof at or above the window
-- count both produce a value: the observations were there, the quotient was
-- not. Collapsing either into `None` would make them indistinguishable from
-- a warm-up, which is a different fact about the data.
def zero_base() -> List[f64] = [cast(0.0, f64), cast(4.0, f64), cast(0.0, f64)]
def is_nan_f(x: f64) -> bool = if eq(x, x) then false else true
def all_nan(xs: List[Option[f64]]) -> bool = fold(fn (acc: bool, o: Option[f64]) -> if acc then if present(o) then is_nan_f(value_or(o, cast(0.0, f64))) else true else false, true, xs)
def test_undefined_is_present_not_absent() -> unit ! { Test } = {
  ratios = pct_change(zero_base(), cast(1, i64))
  _ = assert_true(eq(present_count(ratios), cast(2, i64)), "pct_change over a zero base still reports a value")
  _ = assert_true(lt(cast(1e300, f64), value_or(index(ratios, cast(1, i64)), cast(0.0, f64))), "a positive change from a zero base is an infinity, not an absence")
  single = rolling_var(ns(), cast(1, i64), cast(1, i64), cast(1, i64))
  _ = assert_true(eq(present_count(single), cast(6, i64)), "a one-wide window at ddof 1 reports a value at every position")
  assert_true(is_nan_f(value_or(index(single, cast(0, i64)), cast(0.0, f64))), "and that value is NaN, not an absence")
}
-- A window with no more observations than `ddof` is `Some(NaN)` at every
-- position, which is what pandas returns. Before the guard existed the
-- arithmetic divided by a NEGATIVE denominator once `ddof` exceeded the count
-- and produced a finite negative number presented as a variance, with
-- `rolling_std` hiding it behind a `sqrt`. These pin all three regions:
-- `ddof` below, equal to, and above the observation count.
def test_ddof_at_or_above_the_count_is_nan() -> unit ! { Test } = {
  _ = assert_true(all_nan(rolling_var(ns(), cast(2, i64), cast(2, i64), cast(2, i64))), "rolling_var: ddof equal to the window count is NaN")
  _ = assert_true(all_nan(rolling_var(ns(), cast(2, i64), cast(2, i64), cast(3, i64))), "rolling_var: ddof above the window count is NaN, not a negative variance")
  _ = assert_true(all_nan(rolling_var(ns(), cast(2, i64), cast(2, i64), cast(9223372036854775807, i64))), "rolling_var: a huge ddof is NaN, not a tiny negative number")
  _ = assert_true(all_nan(rolling_std(ns(), cast(2, i64), cast(2, i64), cast(3, i64))), "rolling_std: the same, rather than a sqrt of a negative variance")
  _ = assert_true(all_nan(rolling_var(ns(), cast(1, i64), cast(1, i64), cast(1, i64))), "rolling_var: a one-wide window at ddof 1 is NaN")
  -- Only the short leading windows are degenerate here: at window 4 and ddof 2
  -- the first two positions have 1 and 2 observations, the rest have 3 and 4.
  partial = rolling_var(ns(), cast(4, i64), cast(1, i64), cast(2, i64))
  _ = assert_true(is_nan_f(value_or(index(partial, cast(0, i64)), cast(0.0, f64))), "a window of one observation at ddof 2 is NaN")
  _ = assert_true(is_nan_f(value_or(index(partial, cast(1, i64)), cast(0.0, f64))), "a window of two observations at ddof 2 is NaN")
  _ = assert_close(value_or(index(partial, cast(2, i64)), cast(0.0, f64)), cast(12.666666666666666, f64), cast(1e-12, f64), "and a window of three observations at ddof 2 is a real variance")
  expand = expanding_var(ns(), cast(1, i64), cast(2, i64))
  _ = assert_true(is_nan_f(value_or(index(expand, cast(0, i64)), cast(0.0, f64))), "expanding_var: the same guard applies before the count passes ddof")
  assert_close(value_or(index(expand, cast(2, i64)), cast(0.0, f64)), cast(12.666666666666666, f64), cast(1e-12, f64), "expanding_var: and it clears once the count does")
}
-- An input NaN is a value here, not a missing observation, and all six
-- reductions agree on that. `lt` is false for NaN in either operand, so a
-- plain comparison fold would ignore a NaN anywhere but the seed position and
-- absorb one at the seed -- a confident minimum at one index and NaN at the
-- next, from the seed rather than from a policy. pandas instead treats NaN as
-- missing and counts only non-NaN observations toward min_periods, so this
-- family is outside the pandas agreement and `spec/scope.md` says so.
def nan_series() -> List[f64] = [cast(5.0, f64), div(cast(0.0, f64), cast(0.0, f64)), cast(7.0, f64), cast(3.0, f64)]
def test_input_nan_propagates_through_every_reduction() -> unit ! { Test } = {
  w = cast(3, i64)
  mp = cast(1, i64)
  _ = assert_true(is_nan_f(value_or(index(rolling_min(nan_series(), w, mp), cast(1, i64)), cast(0.0, f64))), "rolling_min: a NaN at window position 1 propagates")
  _ = assert_true(is_nan_f(value_or(index(rolling_min(nan_series(), w, mp), cast(3, i64)), cast(0.0, f64))), "rolling_min: and so does a NaN at the seed position")
  _ = assert_true(is_nan_f(value_or(index(rolling_max(nan_series(), w, mp), cast(1, i64)), cast(0.0, f64))), "rolling_max: a NaN at window position 1 propagates")
  _ = assert_true(is_nan_f(value_or(index(rolling_max(nan_series(), w, mp), cast(3, i64)), cast(0.0, f64))), "rolling_max: and so does a NaN at the seed position")
  _ = assert_true(is_nan_f(value_or(index(rolling_sum(nan_series(), w, mp), cast(1, i64)), cast(0.0, f64))), "rolling_sum: propagates too")
  _ = assert_true(is_nan_f(value_or(index(rolling_mean(nan_series(), w, mp), cast(1, i64)), cast(0.0, f64))), "rolling_mean: propagates too")
  _ = assert_true(is_nan_f(value_or(index(rolling_var(nan_series(), w, cast(2, i64), cast(1, i64)), cast(1, i64)), cast(0.0, f64))), "rolling_var: propagates too")
  _ = assert_true(is_nan_f(value_or(index(rolling_std(nan_series(), w, cast(2, i64), cast(1, i64)), cast(1, i64)), cast(0.0, f64))), "rolling_std: propagates too")
  -- The first position reduces a one-element window holding the only non-NaN
  -- value before the NaN, so it is a real number and pins that propagation is
  -- positional rather than whole-series.
  assert_close(value_or(index(rolling_min(nan_series(), w, mp), cast(0, i64)), cast(0.0, f64)), cast(5.0, f64), tol(), "a window that does not reach the NaN is unaffected")
}
-- Every divergence from pandas that the docs claim is pinned here, so a
-- sentence in the book cannot drift from the behaviour. Two rounds of review
-- ended on prose claims no executable artifact checked; these are the
-- remaining ones.
def inf_pair() -> List[f64] = [div(cast(1.0, f64), cast(0.0, f64)), div(cast(-1.0, f64), cast(0.0, f64))]
def signed_zero_pair() -> List[f64] = [cast(0.0, f64), neg(cast(0.0, f64))]
def test_documented_divergences_from_pandas() -> unit ! { Test } = {
  -- An infinity is a value and propagates, where pandas gives NaN for both.
  sums = rolling_sum(inf_pair(), cast(2, i64), cast(1, i64))
  _ = assert_true(lt(cast(1e300, f64), value_or(index(sums, cast(0, i64)), cast(0.0, f64))), "rolling_sum of [inf, -inf]: the first window is inf, where pandas gives NaN")
  _ = assert_true(is_nan_f(value_or(index(sums, cast(1, i64)), cast(0.0, f64))), "and the second is NaN because inf + -inf is")
  -- Signed zero is not preserved: the comparison folds keep the first of two
  -- values that compare equal, so a caller cannot observe this by comparison.
  mins = rolling_min(signed_zero_pair(), cast(2, i64), cast(1, i64))
  both = value_or(index(mins, cast(1, i64)), cast(1.0, f64))
  -- `eq` cannot tell the two zeros apart, so asserting it twice pins nothing.
  -- `1 / x` can: +inf for +0.0 and -inf for -0.0. That is what makes this an
  -- actual pin on WHICH zero is returned, rather than a restatement that the
  -- two compare equal.
  _ = assert_true(eq(both, cast(0.0, f64)), "rolling_min over [0.0, -0.0] is a zero")
  _ = assert_true(lt(cast(1e300, f64), div(cast(1.0, f64), both)), "and it is +0.0, where pandas returns -0.0: 1/x is +inf")
  reversed_pair = rolling_min([neg(cast(0.0, f64)), cast(0.0, f64)], cast(2, i64), cast(1, i64))
  _ = assert_true(lt(div(cast(1.0, f64), value_or(index(reversed_pair, cast(1, i64)), cast(1.0, f64))), neg(cast(1e300, f64))), "reversing the input returns -0.0, so the fold keeps the first of two equal values rather than a fixed sign")
  -- The claim that is easy to get backwards: a NaN-free finite series has NO
  -- divergence, so the scoping sentence is not vacuous.
  clean = rolling_min([cast(5.0, f64), cast(2.0, f64), cast(7.0, f64)], cast(2, i64), cast(2, i64))
  assert_true(series_agrees(clean, [None, Some(cast(2.0, f64)), Some(cast(2.0, f64))], tol()), "a finite NaN-free series matches pandas exactly")
}
-- Two-pass variance. The exact sample variance of 4, 7, 13, 16 is 30, and
-- shifting all four by 1e8 does not change it. An implementation that
-- accumulated the sum and the sum of squares and subtracted would lose
-- almost every significant digit here, which is why `roll_var_list`
-- re-reduces the window about its own mean.
def cancelling() -> List[f64] = [cast(100000004.0, f64), cast(100000007.0, f64), cast(100000013.0, f64), cast(100000016.0, f64)]
def test_variance_resists_cancellation() -> unit ! { Test } = {
  shifted = rolling_var(cancelling(), cast(4, i64), cast(4, i64), cast(1, i64))
  _ = assert_close(value_or(index(shifted, cast(3, i64)), cast(0.0, f64)), cast(30.0, f64), cast(1e-9, f64), "rolling_var is exact on a large mean with a small spread")
  centred = rolling_var([cast(4.0, f64), cast(7.0, f64), cast(13.0, f64), cast(16.0, f64)], cast(4, i64), cast(4, i64), cast(1, i64))
  _ = assert_close(value_or(index(centred, cast(3, i64)), cast(0.0, f64)), cast(30.0, f64), cast(1e-12, f64), "and agrees with the same spread about zero")
  sd = rolling_std(cancelling(), cast(4, i64), cast(4, i64), cast(1, i64))
  assert_close(value_or(index(sd, cast(3, i64)), cast(0.0, f64)), cast(5.477225575051661, f64), cast(1e-9, f64), "rolling_std is the square root of that variance")
}
-- The comparison helpers this suite leans on. Without these, a helper that
-- returned `true` unconditionally would carry every assertion above.
def test_helper_series_agrees_rejects_wrong_length() -> unit ! { Test } = assert_true(if series_agrees([Some(cast(1.0, f64))], [Some(cast(1.0, f64)), Some(cast(2.0, f64))], tol()) then false else true, "series_agrees rejects a length mismatch")
def test_helper_series_agrees_rejects_wrong_presence() -> unit ! { Test } = {
  _ = assert_true(if series_agrees([None, Some(cast(1.0, f64))], [Some(cast(1.0, f64)), Some(cast(1.0, f64))], tol()) then false else true, "series_agrees rejects an absence where a value was expected")
  assert_true(if series_agrees([Some(cast(1.0, f64)), Some(cast(1.0, f64))], [None, Some(cast(1.0, f64))], tol()) then false else true, "series_agrees rejects a value where an absence was expected")
}
def test_helper_series_agrees_rejects_wrong_value() -> unit ! { Test } = {
  _ = assert_true(if series_agrees([Some(cast(1.0, f64))], [Some(cast(1.001, f64))], tol()) then false else true, "series_agrees rejects a value outside the tolerance")
  _ = assert_true(series_agrees([Some(cast(1.0, f64))], [Some(cast(1.0, f64))], tol()), "series_agrees accepts an exact match")
  _ = assert_true(if dense_agrees([cast(1.0, f64)], [cast(1.0, f64), cast(2.0, f64)], tol()) then false else true, "dense_agrees rejects a length mismatch")
  assert_true(if dense_agrees([cast(1.0, f64)], [cast(1.001, f64)], tol()) then false else true, "dense_agrees rejects a value outside the tolerance")
}
def test_helper_counts_are_positional() -> unit ! { Test } = {
  _ = assert_true(eq(leading_absent([Some(cast(1.0, f64)), None, None]), cast(0, i64)), "leading_absent counts only a leading run")
  _ = assert_true(eq(leading_absent([None, None, Some(cast(1.0, f64)), None]), cast(2, i64)), "leading_absent stops at the first value")
  assert_true(eq(present_count([None, Some(cast(1.0, f64)), None, Some(cast(2.0, f64))]), cast(2, i64)), "present_count counts every value, wherever it sits")
}
