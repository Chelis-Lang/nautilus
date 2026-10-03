module Nautilus.Rolling
export (rolling_sum, rolling_mean, rolling_var, rolling_std, rolling_min, rolling_max, expanding_sum, expanding_mean, expanding_var, expanding_std, expanding_min, expanding_max, shift, shift_fill, shift_clamped, diff, pct_change, tensor_rolling_sum, tensor_rolling_mean, tensor_rolling_var, tensor_rolling_std, tensor_rolling_min, tensor_rolling_max, tensor_expanding_sum, tensor_expanding_mean, tensor_expanding_var, tensor_expanding_std, tensor_expanding_min, tensor_expanding_max, tensor_shift, tensor_shift_fill, tensor_shift_clamped, tensor_diff, tensor_pct_change)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-ROLLING
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.Rolling MUST provide the rolling-window, expanding-window and lag surface listed in the module support table.
-- Nautilus.Rolling is f64 and list-level. It is the only module in the
-- package that is neither f32 nor `[prec: Float]`, and the only one that
-- answers "no value here" with `Option` rather than a NaN sentinel. Both
-- departures are deliberate and are argued in `spec/scope.md`.
-- Absence lives inside the element. A warm-up position is `None`, never a
-- filler value, so a caller cannot read one by accident and cannot drop the
-- distinction: any sibling channel for validity -- a count, a parallel bool
-- series, a record field, a tuple component -- can be projected away by a
-- caller who only wanted the numbers, and a NaN sentinel is indistinguishable
-- from a NaN this module computed. `None` is neither.
-- Filler occupies warm-up positions inside the private window helpers only.
-- No export can observe it: every public path maps it to `None`.
def roll_min_i(a: i64, b: i64) -> i64 = if lt(a, b) then a else b
def roll_max_i(a: i64, b: i64) -> i64 = if lt(a, b) then b else a
def roll_zero() -> f64 = cast(0.0, f64)
def roll_nan() -> f64 = div(roll_zero(), roll_zero())
def roll_one_i() -> i64 = cast(1, i64)
def roll_zero_i() -> i64 = cast(0, i64)
-- Out-of-domain arguments trap. These are caller bugs with no correct
-- answer, so they `fail` rather than returning an all-`None` series, which
-- would report "not enough data" for a call that was simply wrong.
def roll_require_window(window: i64) -> i64 = if lt(window, roll_one_i()) then fail("Nautilus.Rolling: window must be >= 1") else window
def roll_require_min_periods(min_periods: i64) -> i64 = if lt(min_periods, roll_one_i()) then fail("Nautilus.Rolling: min_periods must be >= 1") else min_periods
def roll_require_min_periods_window(min_periods: i64, window: i64) -> i64 = if lt(window, roll_require_min_periods(min_periods)) then fail("Nautilus.Rolling: min_periods must be <= window") else min_periods
def roll_require_ddof(ddof: i64) -> i64 = if lt(ddof, roll_zero_i()) then fail("Nautilus.Rolling: ddof must be >= 0") else ddof
-- Window reductions. Every window handed to one of these is nonempty:
-- `roll_core` emits a value only at indices where at least `min_periods >= 1`
-- observations are available, so `index(ws, 0)` is always in range.
def roll_sum_list(ws: List[f64]) -> f64 = fold(fn (acc: f64, x: f64) -> add(acc, x), roll_zero(), ws)
def roll_mean_list(ws: List[f64]) -> f64 = div(roll_sum_list(ws), cast(len(ws), f64))
-- `lt` is false for NaN in either operand, so a plain comparison fold would
-- IGNORE a NaN anywhere but the seed position and ABSORB one at the seed --
-- reporting a confident minimum at one index and NaN at the next, which is an
-- artifact of the seed rather than a policy. These propagate instead, so all
-- six reductions agree: this module treats an input NaN as a value, not as a
-- missing observation. pandas treats it as missing and counts only non-NaN
-- observations toward `min_periods`, so the pandas agreement below is stated
-- for NaN-free input. `spec/scope.md` records that divergence.
def roll_min_list(ws: List[f64]) -> f64 = fold(fn (acc: f64, x: f64) -> if eq(x, x) then if lt(x, acc) then x else acc else roll_nan(), index(ws, roll_zero_i()), ws)
def roll_max_list(ws: List[f64]) -> f64 = fold(fn (acc: f64, x: f64) -> if eq(x, x) then if lt(acc, x) then x else acc else roll_nan(), index(ws, roll_zero_i()), ws)
-- Two-pass variance: the window mean, then the sum of squared deviations
-- about it. A running accumulator of x and x^2 would make the whole surface
-- O(n) instead of O(n*w), and is how the hand-written prefix-sum version in
-- the measured demand table is built, but it cancels catastrophically on a
-- series with a large mean relative to its spread. A library whose callers
-- cannot see the accumulation should not make that trade for them.
--
-- A window with no more observations than `ddof` is `Some(NaN)`, which is
-- what pandas returns for every such window. The guard is explicit because
-- the arithmetic alone does not give it: `len(ws) - ddof` is NEGATIVE once
-- `ddof` exceeds the count, and dividing by it yields a finite NEGATIVE
-- number presented as a variance, which `sqrt` would then quietly turn into
-- NaN in `rolling_std` while `rolling_var` kept reporting it.
--
-- It is `Some(NaN)` and deliberately not `None`: the window HAD its
-- `min_periods` observations, so the value is undefined rather than absent,
-- and collapsing the two would make `rolling_var(xs, 1, 1, 1)`
-- indistinguishable from a warm-up.
def roll_var_list(ws: List[f64], ddof: i64) -> f64 =
  if lte(len(ws), ddof) then roll_nan() else {
    mu = roll_mean_list(ws)
    ss = fold(fn (acc: f64, x: f64) -> {
      d = sub(x, mu)
      add(acc, mul(d, d))
    }, roll_zero(), ws)
    div(ss, cast(sub(len(ws), ddof), f64))
  }
def roll_std_list(ws: List[f64], ddof: i64) -> f64 = sqrt(roll_var_list(ws, ddof))
-- The window ending at `i`, clipped at the start of the series:
-- xs[max(0, i - window + 1) .. i], so its length is min(i + 1, window).
def roll_window(xs: List[f64], window: i64, i: i64) -> List[f64] = {
  start = roll_max_i(roll_zero_i(), add(sub(i, window), roll_one_i()))
  take(skip(xs, start), sub(add(i, roll_one_i()), start))
}
-- The one rolling kernel. `out[i]` is `None` while fewer than `min_periods`
-- observations have been seen, and `Some(red(window))` after that.
--
-- With `min_periods < window` the first full window has not arrived yet at
-- indices min_periods-1 .. window-2, and those positions reduce over a
-- SHORTER window rather than being absent. That is pandas' behaviour and it
-- is the specific off-by-one the hand-written versions get wrong.
-- The reduction is selected by a closed tag, not by passing the reducer as a
-- function value. A function-typed parameter has no C host ABI, so a
-- consumer's `chelis build` rejects the call site with "no direct-call
-- authority" while `chelis check`, `chelis eval`, `chelis test` and
-- `chelis reef build` are all green; the owning entry is in
-- docs/UPSTREAM_BUGS.md §Actively blocking. The tag keeps one kernel without
-- the function value, and because the reducer set is closed and internal it is
-- the permanent design rather than a narrowing to retire. `ddof` is threaded
-- for every tag and ignored by the four that do not use it, which is cheaper
-- than a second kernel. `scripts/check_rolling_c_lane.py` is the guard.
type Reducer =
  | ReduceSum
  | ReduceMean
  | ReduceVar
  | ReduceStd
  | ReduceMin
  | ReduceMax
def roll_reduce(ws: List[f64], kind: Reducer, ddof: i64) -> f64 =
  match kind with {
    | ReduceSum => roll_sum_list(ws)
    | ReduceMean => roll_mean_list(ws)
    | ReduceVar => roll_var_list(ws, ddof)
    | ReduceStd => roll_std_list(ws, ddof)
    | ReduceMin => roll_min_list(ws)
    | ReduceMax => roll_max_list(ws)
  }
-- Every `Option`-producing body is a named def with an explicit return type.
-- A bare `None` whose type is fixed only by its sibling arm does not lower:
-- `chelis build` fails with "unresolved host inference variable" ([05-UNS-1])
-- where eval is fine, and an annotated named def fixes the type locally. That
-- limitation is fixed upstream in a release later than this pin, so it is the
-- one narrowing here that expires: docs/UPSTREAM_BUGS.md §Actively blocking
-- carries the reproducer and the de-narrowing step, which is to inline these
-- bodies back into their lambdas at the next pin bump.
def roll_entry(xs: List[f64], window: i64, min_periods: i64, kind: Reducer, ddof: i64, i: i64) -> Option[f64] = if lt(add(i, roll_one_i()), min_periods) then None else Some(roll_reduce(roll_window(xs, window, i), kind, ddof))
def roll_core(xs: List[f64], window: i64, min_periods: i64, kind: Reducer, ddof: i64) -> List[Option[f64]] = map(fn (i: i64) -> roll_entry(xs, window, min_periods, kind, ddof, i), range(roll_zero_i(), len(xs)))
-- An expanding window is a rolling window as wide as the series. `len(xs)`
-- is raised to 1 so an empty input does not trip `roll_require_window`:
-- the result is the empty list either way, and an empty series is not a
-- caller bug.
def roll_expanding_window(xs: List[f64]) -> i64 = roll_max_i(len(xs), roll_one_i())
-- Positional reads for the lag family. `j` outside the series is absent, so
-- `shift`, `diff` and `pct_change` are defined at every `k` the index
-- arithmetic can represent: a negative `k` reads later values (pandas' lead),
-- `k = 0` is the identity, and any `|k| >= len(xs)` is all-`None`. None of
-- those is a trap, because `Option` can say "no value" without inventing one.
--
-- The exception, and it is not absence: `i - k` overflows i64 at `k` equal to
-- `i64::MIN`, so the whole family traps there with `numeric trap: overflow in
-- sub at i64` rather than returning a series. That is loud, and it is the one
-- `k` at which "defined everywhere" would be false.
--
-- A lead is a look-ahead when the series is a trading signal. Nautilus is a
-- numerical library, not a signal library, and forward differences and
-- forward returns are ordinary uses, so the direction is the caller's to
-- choose. `Shoals.Indicators.ind_shift` deliberately traps it instead.
def roll_in_range(j: i64, m: i64) -> bool = if lt(j, roll_zero_i()) then false else lt(j, m)
def roll_at(xs: List[f64], j: i64) -> Option[f64] = if roll_in_range(j, len(xs)) then Some(index(xs, j)) else None
def rolling_sum(xs: List[f64], window: i64, min_periods: i64) -> List[Option[f64]] = {
  w = roll_require_window(window)
  roll_core(xs, w, roll_require_min_periods_window(min_periods, w), ReduceSum, roll_zero_i())
}
def rolling_mean(xs: List[f64], window: i64, min_periods: i64) -> List[Option[f64]] = {
  w = roll_require_window(window)
  roll_core(xs, w, roll_require_min_periods_window(min_periods, w), ReduceMean, roll_zero_i())
}
def rolling_var(xs: List[f64], window: i64, min_periods: i64, ddof: i64) -> List[Option[f64]] = {
  w = roll_require_window(window)
  mp = roll_require_min_periods_window(min_periods, w)
  dd = roll_require_ddof(ddof)
  roll_core(xs, w, mp, ReduceVar, dd)
}
def rolling_std(xs: List[f64], window: i64, min_periods: i64, ddof: i64) -> List[Option[f64]] = {
  w = roll_require_window(window)
  mp = roll_require_min_periods_window(min_periods, w)
  dd = roll_require_ddof(ddof)
  roll_core(xs, w, mp, ReduceStd, dd)
}
def rolling_min(xs: List[f64], window: i64, min_periods: i64) -> List[Option[f64]] = {
  w = roll_require_window(window)
  roll_core(xs, w, roll_require_min_periods_window(min_periods, w), ReduceMin, roll_zero_i())
}
def rolling_max(xs: List[f64], window: i64, min_periods: i64) -> List[Option[f64]] = {
  w = roll_require_window(window)
  roll_core(xs, w, roll_require_min_periods_window(min_periods, w), ReduceMax, roll_zero_i())
}
def expanding_sum(xs: List[f64], min_periods: i64) -> List[Option[f64]] = roll_core(xs, roll_expanding_window(xs), roll_require_min_periods(min_periods), ReduceSum, roll_zero_i())
def expanding_mean(xs: List[f64], min_periods: i64) -> List[Option[f64]] = roll_core(xs, roll_expanding_window(xs), roll_require_min_periods(min_periods), ReduceMean, roll_zero_i())
def expanding_var(xs: List[f64], min_periods: i64, ddof: i64) -> List[Option[f64]] = {
  dd = roll_require_ddof(ddof)
  roll_core(xs, roll_expanding_window(xs), roll_require_min_periods(min_periods), ReduceVar, dd)
}
def expanding_std(xs: List[f64], min_periods: i64, ddof: i64) -> List[Option[f64]] = {
  dd = roll_require_ddof(ddof)
  roll_core(xs, roll_expanding_window(xs), roll_require_min_periods(min_periods), ReduceStd, dd)
}
def expanding_min(xs: List[f64], min_periods: i64) -> List[Option[f64]] = roll_core(xs, roll_expanding_window(xs), roll_require_min_periods(min_periods), ReduceMin, roll_zero_i())
def expanding_max(xs: List[f64], min_periods: i64) -> List[Option[f64]] = roll_core(xs, roll_expanding_window(xs), roll_require_min_periods(min_periods), ReduceMax, roll_zero_i())
-- out[i] = xs[i - k], absent where that index is off either end.
def shift(xs: List[f64], k: i64) -> List[Option[f64]] = map(fn (i: i64) -> roll_at(xs, sub(i, k)), range(roll_zero_i(), len(xs)))
-- out[i] = xs[i - k], or `fill` off the end. The caller supplying a fill has
-- said what absence means, so the result carries no `Option`: this is the
-- `at_z` zero-padding shape the demand table counts, with the pad value
-- named instead of assumed.
def shift_fill(xs: List[f64], k: i64, fill: f64) -> List[f64] =
  map(fn (i: i64) -> {
    j = sub(i, k)
    if roll_in_range(j, len(xs)) then index(xs, j) else fill
  }, range(roll_zero_i(), len(xs)))
-- out[i] = xs[clamp(i - k, 0, len - 1)]: the `at_c` edge-clamp shape.
-- `Option`-free on a nonempty series for the same reason as `shift_fill`, and
-- subject to the same `i64::MIN` overflow as the rest of the family.
def shift_clamped(xs: List[f64], k: i64) -> List[f64] = {
  last = sub(len(xs), roll_one_i())
  map(fn (i: i64) -> index(xs, roll_min_i(roll_max_i(sub(i, k), roll_zero_i()), last)), range(roll_zero_i(), len(xs)))
}
-- out[i] = xs[i] - xs[i - k].
def roll_diff_at(xs: List[f64], k: i64, i: i64) -> Option[f64] =
  match roll_at(xs, sub(i, k)) with {
    | None => None
    | Some(prev) => Some(sub(index(xs, i), prev))
  }
def diff(xs: List[f64], k: i64) -> List[Option[f64]] = map(fn (i: i64) -> roll_diff_at(xs, k, i), range(roll_zero_i(), len(xs)))
-- out[i] = (xs[i] - xs[i - k]) / xs[i - k]. A zero base is `Some` of an
-- infinity or NaN, not `None`: the observation exists and the ratio does
-- not, which is a different fact from the series not reaching back that far.
def roll_pct_at(xs: List[f64], k: i64, i: i64) -> Option[f64] =
  match roll_at(xs, sub(i, k)) with {
    | None => None
    | Some(prev) => Some(div(sub(index(xs, i), prev), prev))
  }
def pct_change(xs: List[f64], k: i64) -> List[Option[f64]] = map(fn (i: i64) -> roll_pct_at(xs, k, i), range(roll_zero_i(), len(xs)))
-- Tensor entry points. Each converts and delegates; none has semantics of
-- its own, and `scripts/check_rolling_tensor_parity.py` proves that
-- mechanically rather than by assertion.
--
-- The `Option`-returning forms cannot return a tensor: a tensor element is a
-- precision type, so it has no inhabitant for "absent" that is not also a
-- number a caller could read. `shift_fill` and `shift_clamped` are total, so
-- those two -- and only those two -- round-trip to `tensor[n, f64]`.
def tensor_rolling_sum[n](xs: &tensor[n, f64], window: i64, min_periods: i64) -> List[Option[f64]] = rolling_sum(to_list(xs), window, min_periods)
def tensor_rolling_mean[n](xs: &tensor[n, f64], window: i64, min_periods: i64) -> List[Option[f64]] = rolling_mean(to_list(xs), window, min_periods)
def tensor_rolling_var[n](xs: &tensor[n, f64], window: i64, min_periods: i64, ddof: i64) -> List[Option[f64]] = rolling_var(to_list(xs), window, min_periods, ddof)
def tensor_rolling_std[n](xs: &tensor[n, f64], window: i64, min_periods: i64, ddof: i64) -> List[Option[f64]] = rolling_std(to_list(xs), window, min_periods, ddof)
def tensor_rolling_min[n](xs: &tensor[n, f64], window: i64, min_periods: i64) -> List[Option[f64]] = rolling_min(to_list(xs), window, min_periods)
def tensor_rolling_max[n](xs: &tensor[n, f64], window: i64, min_periods: i64) -> List[Option[f64]] = rolling_max(to_list(xs), window, min_periods)
def tensor_expanding_sum[n](xs: &tensor[n, f64], min_periods: i64) -> List[Option[f64]] = expanding_sum(to_list(xs), min_periods)
def tensor_expanding_mean[n](xs: &tensor[n, f64], min_periods: i64) -> List[Option[f64]] = expanding_mean(to_list(xs), min_periods)
def tensor_expanding_var[n](xs: &tensor[n, f64], min_periods: i64, ddof: i64) -> List[Option[f64]] = expanding_var(to_list(xs), min_periods, ddof)
def tensor_expanding_std[n](xs: &tensor[n, f64], min_periods: i64, ddof: i64) -> List[Option[f64]] = expanding_std(to_list(xs), min_periods, ddof)
def tensor_expanding_min[n](xs: &tensor[n, f64], min_periods: i64) -> List[Option[f64]] = expanding_min(to_list(xs), min_periods)
def tensor_expanding_max[n](xs: &tensor[n, f64], min_periods: i64) -> List[Option[f64]] = expanding_max(to_list(xs), min_periods)
def tensor_shift[n](xs: &tensor[n, f64], k: i64) -> List[Option[f64]] = shift(to_list(xs), k)
def tensor_shift_fill[n](xs: &tensor[n, f64], k: i64, fill: f64) -> tensor[n, f64] = to_tensor(shift_fill(to_list(xs), k, fill))
def tensor_shift_clamped[n](xs: &tensor[n, f64], k: i64) -> tensor[n, f64] = to_tensor(shift_clamped(to_list(xs), k))
def tensor_diff[n](xs: &tensor[n, f64], k: i64) -> List[Option[f64]] = diff(to_list(xs), k)
def tensor_pct_change[n](xs: &tensor[n, f64], k: i64) -> List[Option[f64]] = pct_change(to_list(xs), k)
