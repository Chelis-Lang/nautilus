# Rolling and Expanding Windows

`Nautilus.Rolling` provides rolling and expanding reductions and the lag
family — `shift`, `diff` and `pct_change` — over `List[f64]`. Warm-up and
`min_periods` behave as pandas does.

Two things about this module differ from the rest of Nautilus, and both are
deliberate. It is **f64**, not `f32` and not generic over the `Float` family.
And it reports a position with no value as **`None`**, where every other module
returns a NaN sentinel. The reasons are at the end of this chapter.

The pandas agreement below is for input that contains no NaN and no infinity.
An input NaN is a **value** here, not a missing observation; pandas treats it
as missing and counts only non-NaN observations toward `min_periods`. See
"Non-finite input" below.

## Rolling reductions

Each reduction takes the series, a `window`, and a `min_periods`.

```chelis
module Nautilus.BookRollingBasics
import Nautilus.Rolling (rolling_mean, rolling_std)
def prices() -> List[f64] = [cast(5.0, f64), cast(2.0, f64), cast(7.0, f64), cast(3.0, f64), cast(9.0, f64), cast(1.0, f64)]
def three_day_mean() -> List[Option[f64]] = rolling_mean(prices(), cast(3, i64), cast(3, i64))
def three_day_sample_sd() -> List[Option[f64]] = rolling_std(prices(), cast(3, i64), cast(3, i64), cast(1, i64))
```

`three_day_mean()` is

```text
[None, None, Some(4.666666666666667), Some(4.0), Some(6.333333333333333), Some(4.333333333333333)]
```

The first two positions are `None` because fewer than `min_periods`
observations had been seen. `ddof` is explicit: `1` is the sample variance,
which is what pandas' `.std()` computes by default, and `0` is the population
variance.

### `min_periods` below the window

This is the part that is easy to get wrong by hand. With
`min_periods < window`, the leading positions are **not** absent. They reduce
over a *shorter* window:

```chelis
module Nautilus.BookRollingMinPeriods
import Nautilus.Rolling (rolling_sum)
def prices() -> List[f64] = [cast(5.0, f64), cast(2.0, f64), cast(7.0, f64), cast(3.0, f64), cast(9.0, f64), cast(1.0, f64)]
def partial_windows() -> List[Option[f64]] = rolling_sum(prices(), cast(3, i64), cast(1, i64))
```

gives `[Some(5.0), Some(7.0), Some(14.0), Some(12.0), Some(19.0), Some(13.0)]`.
Position 0 sums one observation and position 1 sums two; only from position 2
onward is the window full.

The warm-up is therefore exactly `min_periods - 1` entries long and does not
depend on the window. A `window` wider than the series is allowed: it reduces
whatever is available.

## Expanding windows

An expanding window is a rolling window as wide as the series, so on a
nonempty series `expanding_sum(xs, m)` and `rolling_sum(xs, len(xs), m)` agree.
(On an empty series only the expanding form answers: a `window` of `len(xs)` is
then zero, which the rolling form rejects.) The expanding
family takes no `window` argument, and unlike the rolling family it does not
require `min_periods <= len(xs)`: a `min_periods` beyond the series length
gives an all-absent result, as it does in pandas.

## The lag family

`shift`, `diff` and `pct_change` are defined at **every `k` the index
arithmetic can represent**. A positive `k` reaches backward, a negative `k`
reaches forward (pandas' lead), `k = 0` is the identity, and any `|k|` at or
beyond the series length absents every entry. None of those traps, because
`Option` can report "no value" without inventing one.

The one exception is `k = i64::MIN`: `out[i] = xs[i - k]`, and `i - k`
overflows there, so the whole family traps with `numeric trap: overflow in sub
at i64` rather than returning a series. That is loud, and
`tests_neg/rolling/shift_i64_min_overflow_neg.ch` pins it.

```chelis
module Nautilus.BookRollingLags
import Nautilus.Rolling (shift, shift_fill, shift_clamped, diff, pct_change)
def prices() -> List[f64] = [cast(5.0, f64), cast(2.0, f64), cast(7.0, f64), cast(3.0, f64)]
def yesterday() -> List[Option[f64]] = shift(prices(), cast(1, i64))
def zero_padded() -> List[f64] = shift_fill(prices(), cast(1, i64), cast(0.0, f64))
def edge_clamped() -> List[f64] = shift_clamped(prices(), cast(1, i64))
def daily_change() -> List[Option[f64]] = diff(prices(), cast(1, i64))
def daily_return() -> List[Option[f64]] = pct_change(prices(), cast(1, i64))
def tomorrow() -> List[Option[f64]] = shift(prices(), cast(-1, i64))
```

`shift_fill` and `shift_clamped` are the two boundary conventions that are
otherwise written by hand at every call site: a named pad value, and a clamp
to the first or last observation. Because the caller has said what the edge
means, both return a plain `List[f64]` with no `Option`.

A negative `k` reads later values. In a trading-signal context that is
look-ahead, and a signal library is right to forbid it —
`Shoals.Indicators.ind_shift` does. Nautilus is a numerical library, where a
forward difference and a forward return are ordinary, so the direction is the
caller's to choose.

## Undefined is not absent

Three results are a **present** value that happens not to be finite, rather
than `None`:

| call | result | why |
|---|---|---|
| `pct_change` over a zero base | `Some(inf)` or `Some(NaN)` | the earlier observation exists; the ratio does not |
| a window with `ddof` at or above its observation count | `Some(NaN)` | the window had its observations; the variance does not exist |
| a one-wide window at `ddof` 1 | `Some(NaN)` | the same case, at the smallest window |

The variance rule is pandas': NaN whenever the window's observation count is
not greater than `ddof`. It is a guard rather than a consequence of the
arithmetic, because `count - ddof` is *negative* once `ddof` exceeds the count,
and dividing by it would yield a finite **negative number presented as a
variance** — which `rolling_std` would then turn into NaN with a `sqrt` while
`rolling_var` went on reporting it.

Collapsing any of these into `None` would make them indistinguishable from a
warm-up, which is a different fact about the data. Arguments that cannot be
satisfied at all — a window below 1, a `min_periods` below 1, a `min_periods`
above the window, a negative `ddof` — trap instead.

## Defined cases and input limits

- The result always has exactly one entry per input observation.
- An empty series gives an empty result, from every export, without trapping.
- Reductions re-reduce each window about its own mean rather than carrying a
  running accumulator. That costs O(`window`) per position instead of O(1),
  and it is why `rolling_var` is exact on a series with a large mean and a
  small spread, where a sum-and-sum-of-squares accumulator loses most of its
  significant digits. `rolling_min` and `rolling_max` are O(`window`) per
  position for the same reason of simplicity; neither uses a monotonic deque.
- pandas accepts `min_periods=0`. Nautilus does not: there is no reduction
  defined on an empty window, and naming the argument is better than inventing
  a different identity element for each reducer.

## Non-finite input

This module has one rule for a non-finite input value: it is a value, and it
propagates. All six reductions agree on that, including `rolling_min` and
`rolling_max`, which need an explicit check to do it because `lt` is false for
NaN in either operand — without one they would ignore a NaN anywhere but the
first window position and absorb one there, reporting a confident minimum at
one index and NaN at the next.

pandas has a different and also-reasonable rule: NaN means *missing*, it does
not propagate, and only non-NaN observations count toward `min_periods`. So
`rolling_min` over `[5, NaN, 7, 3]` at `window = 3, min_periods = 1` is
`[Some(5), Some(NaN), Some(NaN), Some(NaN)]` here and `[5, 5, 5, 3]` in pandas.
An infinity diverges in the other direction: `rolling_sum([inf, 2, 7], 2, 2)`
is `Some(inf)` here, where pandas' incremental accumulator gives NaN.

Neither behaviour is in the pandas golden set, and
`tests/rolling.ch`'s `test_input_nan_propagates_through_every_reduction` pins
this module's. If you need pandas' missing-data semantics, drop or impute the
non-finite values before calling in.

## Tensor entry points

Every export has a `tensor_` twin taking `&tensor[n, f64]`. Each one converts
with `to_list` and delegates; none has semantics of its own, and
`scripts/check_rolling_tensor_parity.py` proves that by reading the source
rather than by assertion.

Fifteen of the seventeen return a list, not a tensor. A tensor element is a
precision type, so it has no inhabitant for "absent" that is not also a number
a caller could read. Only `tensor_shift_fill` and `tensor_shift_clamped`,
whose results have no absent position, return `tensor[n, f64]`.

```chelis
module Nautilus.BookRollingTensor
import Nautilus.Rolling (tensor_rolling_mean, tensor_shift_clamped)
def prices() -> tensor[4, f64] = to_tensor([cast(5.0, f64), cast(2.0, f64), cast(7.0, f64), cast(3.0, f64)])
def windowed() -> List[Option[f64]] = tensor_rolling_mean(prices(), cast(2, i64), cast(2, i64))
def clamped() -> tensor[4, f64] = tensor_shift_clamped(prices(), cast(1, i64))
```

## Why f64, and why `Option`

**Why f64.** nautilus#70 tracks the package being `f32`-only, and its shared
policy is to convert existing surface to `[prec: Float]` rather than add `_f64`
twins. That policy governs *conversion*, where an existing `f32` caller has to
keep working. This module is new, so it has no `f32` caller to preserve, and
two live hazards attach to the generic form: `Float` is the narrowest
dtype-family bound the language offers, so a generic signature silently admits
`f16` and `bf16` (nautilus#75), and a generic library can pass `chelis check`,
`chelis test` and `reef build` while a downstream consumer's `chelis build`
fails on a scalar cast to the binder — which `rolling_mean` needs for its
observation count. Concrete f64 also matches what the measured demand actually
writes. Widening f64 to generic later breaks no existing call site; narrowing
a generic signature back to f64 would.

nautilus#70's own 2026-09-17 comment is more directive than the policy
sentence: "Until that leg passes, no instance here should merge a
`[prec: Float]` conversion". And nautilus#85's "Suggested API" asks for "All
f64" outright.

**Why `Option`.** Every other Nautilus module answers "absent or undefined"
with a NaN sentinel. This one does not, because absence here has to survive
composition. Any sibling channel for validity — a count, a parallel `bool`
series, a record field, a tuple component — can be projected away by a caller
who only wanted the numbers, and a NaN sentinel is indistinguishable from a
NaN the module computed, which is exactly the distinction the table above
turns on. `None` is neither. The cost is an unwrap at the call site;
`tests_neg/rolling/option_result_is_not_a_list_neg.ch` pins the type error a
caller gets instead of silent propagation.

## Checking the pandas contract

The pandas conformance set is checked in at `parity/goldens/rolling.json` and
replayed by `scripts/check_rolling_parity.py`, which needs the pinned compiler
but not pandas:

```sh
uv run --no-project --python 3.12 python scripts/check_rolling_parity.py
```

Success is exit 0 with a final `ROLLING PARITY: PASS` line. Regenerating the
goldens is a manual gate that does need pandas, and every changed number is
reviewed before it is committed:

```sh
uv run --with 'pandas==2.3.3' --no-project python parity/rolling_goldens.py --write
```

The parity set deliberately contains no non-finite expectation, no
cancellation fixture, and no non-finite input. pandas accumulates a window
incrementally where this module re-reduces it, so a parity gate cannot tell
the two algorithms apart on well-scaled data; `tests/rolling.ch` carries that
case, and the degenerate-`ddof` and NaN-input cases with it.

The C lane has its own oracle, because `chelis reef build` does not enter host
lowering and so cannot see whether a consumer can compile against this module:

```sh
uv run --no-project --python 3.12 python scripts/check_rolling_c_lane.py
```

It builds a consumer calling all 34 exports and then runs the clang line
`chelis build` emits. Success is exit 0 with `ROLLING C LANE: PASS`.
