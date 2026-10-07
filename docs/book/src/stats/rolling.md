# Rolling and expanding windows

`Nautilus.Rolling` provides rolling and expanding reductions and lag functions
over `List[f64]`, with warm-up and `min_periods` behaving as in pandas. It
differs from the rest of Nautilus in two ways: it is `f64`, and a position with
no value is `None` rather than a NaN sentinel. `Some(NaN)` remains a numerical
result.

## Rolling reductions

| Function | Signature |
|---|---|
| `rolling_sum`, `rolling_mean`, `rolling_min`, `rolling_max` | `(xs: List[f64], window: i64, min_periods: i64) -> List[Option[f64]]` |
| `rolling_var`, `rolling_std` | `(xs: List[f64], window: i64, min_periods: i64, ddof: i64) -> List[Option[f64]]` |

Position `i` reduces the values from `max(0, i - window + 1)` through `i`. It
is `None` while fewer than `min_periods` values have been seen, so the warm-up
is `min_periods - 1` entries long. The result has one entry per input value.

```chelis-fragment
import Nautilus.Rolling (rolling_mean, rolling_std)

def prices() -> List[f64] = [5.0f64, 2.0f64, 7.0f64, 3.0f64, 9.0f64, 1.0f64]
three_day_mean = rolling_mean(prices(), 3i64, 3i64)
three_day_mean_mp1 = rolling_mean(prices(), 3i64, 1i64)
three_day_sample_sd = rolling_std(prices(), 3i64, 3i64, 1i64)
```

```text
three_day_mean = [None, None, Some(4.666666666666667), Some(4.0), Some(6.333333333333333), Some(4.333333333333333)]
three_day_mean_mp1 = [Some(5.0), Some(3.5), Some(4.666666666666667), Some(4.0), Some(6.333333333333333), Some(4.333333333333333)]
three_day_sample_sd = [None, None, Some(2.516611478423583), Some(2.6457513110645907), Some(3.055050463303893), Some(4.163331998932266)]
```

With `min_periods = 1` the leading positions are not absent: position 0
averages one value and position 1 averages two. A `window` wider than the
series is allowed and reduces whatever is available.

`ddof` selects the variance divisor `count - ddof`: `1` is the sample variance
that pandas' `std()` uses by default, `0` the population variance. A window
whose count is not greater than `ddof` gives `Some(NaN)`, as in pandas. The
variance is computed about each window's own mean, so it stays accurate for a
series with a large mean and small spread; the cost is O(`window`) per
position.

### Argument contract

Arguments with no meaningful answer stop evaluation with an error instead of
returning a series:

| Argument | Requirement | Error message |
|---|---|---|
| `window` | `>= 1` | `Nautilus.Rolling: window must be >= 1` |
| `min_periods` | `>= 1` | `Nautilus.Rolling: min_periods must be >= 1` |
| `min_periods` (rolling) | `<= window` | `Nautilus.Rolling: min_periods must be <= window` |
| `ddof` | `>= 0` | `Nautilus.Rolling: ddof must be >= 0` |

For example, `rolling_mean([1.0f64, 2.0f64], 0i64, 1i64)` fails with
`error: Nautilus.Rolling: window must be >= 1`. Unlike pandas, `min_periods = 0`
is rejected: no reduction is defined on an empty window. An empty series
returns an empty list from every function.

## Expanding reductions

`expanding_sum`, `expanding_mean`, `expanding_min`, and `expanding_max` take
`(xs: List[f64], min_periods: i64)`; `expanding_var` and `expanding_std` add
`ddof: i64`. All return `List[Option[f64]]`. Position `i` reduces every value
from the start through `i`. `min_periods` must be at least 1 but may exceed
the series length, which gives an all-`None` result.

```chelis-fragment
import Nautilus.Rolling (expanding_mean)
running_mean = expanding_mean(prices(), 2i64)
```

```text
running_mean = [None, Some(3.5), Some(4.666666666666667), Some(4.25), Some(5.2), Some(4.5)]
```

## Lag functions

| Function | Signature | `out[i]` |
|---|---|---|
| `shift` | `(xs: List[f64], k: i64) -> List[Option[f64]]` | `xs[i - k]` |
| `shift_fill` | `(xs: List[f64], k: i64, fill: f64) -> List[f64]` | `xs[i - k]`, or `fill` off either end |
| `shift_clamped` | `(xs: List[f64], k: i64) -> List[f64]` | `xs[i - k]` with the index clamped to the series |
| `diff` | `(xs: List[f64], k: i64) -> List[Option[f64]]` | `xs[i] - xs[i - k]` |
| `pct_change` | `(xs: List[f64], k: i64) -> List[Option[f64]]` | `(xs[i] - xs[i - k]) / xs[i - k]`, a fraction, not a percentage |

A position whose `i - k` falls outside the series is `None`. Positive `k`
reads earlier values, negative `k` reads later values (a lead), `k = 0` is
the identity, and `|k| >= len(xs)` gives all `None`.

```chelis-fragment
import Nautilus.Rolling (shift, shift_fill, shift_clamped, diff, pct_change)

def prices() -> List[f64] = [5.0f64, 2.0f64, 7.0f64, 3.0f64, 9.0f64, 1.0f64]
yesterday = shift(prices(), 1i64)
zero_padded = shift_fill(prices(), 1i64, 0.0f64)
edge_clamped = shift_clamped(prices(), 1i64)
daily_change = diff(prices(), 1i64)
daily_return = pct_change(prices(), 1i64)
lead_return = pct_change(prices(), -1i64)
```

```text
yesterday = [None, Some(5.0), Some(2.0), Some(7.0), Some(3.0), Some(9.0)]
zero_padded = [0.0, 5.0, 2.0, 7.0, 3.0, 9.0]
edge_clamped = [5.0, 5.0, 2.0, 7.0, 3.0, 9.0]
daily_change = [None, Some(-3.0), Some(5.0), Some(-4.0), Some(6.0), Some(-8.0)]
daily_return = [None, Some(-0.6), Some(2.5), Some(-0.5714285714285714), Some(2.0), Some(-0.8888888888888888)]
lead_return = [Some(1.5), Some(-0.7142857142857143), Some(1.3333333333333333), Some(-0.6666666666666666), Some(8.0), None]
```

A negative lag reads future values; avoid it when a signal must not look
ahead. `pct_change` over a zero base is `Some(inf)` or `Some(NaN)`: the earlier
value exists and the ratio does not.

The lag functions fail for the `len(xs)` most negative values of `k`, where
`i - k` overflows i64; evaluation stops with
`numeric trap: overflow in sub at i64`. On a two-element series both
`i64::MIN` and `i64::MIN + 1` fail. Every other `k` is defined.

## Tensor versions

Every function has a `tensor_` twin that takes `xs: &tensor[n, f64]` in place
of the list and otherwise has the same arguments, for example
`tensor_rolling_mean[n](xs: &tensor[n, f64], window: i64, min_periods: i64)`
and `tensor_shift[n](xs: &tensor[n, f64], k: i64)`. Each converts with
`to_list` and calls the list function. Results with possibly absent positions
are still `List[Option[f64]]`, because a tensor element cannot be absent.
`tensor_shift_fill` and `tensor_shift_clamped` define every position and
return `tensor[n, f64]`.

```chelis-fragment
import Nautilus.Rolling (tensor_rolling_mean, tensor_shift_fill)

tensor_mean = tensor_rolling_mean(to_tensor([5.0f64, 2.0f64, 7.0f64, 3.0f64]), 2i64, 2i64)
tensor_lag = tensor_shift_fill(to_tensor([5.0f64, 2.0f64, 7.0f64, 3.0f64]), 1i64, 0.0f64)
```

```text
tensor_mean = [None, Some(3.5), Some(4.5), Some(5.0)]
tensor_lag = tensor(shape=[4], data=[0.0, 5.0, 2.0, 7.0])
```

## Missing and non-finite values

An input NaN or infinity is a value and propagates through every reduction,
including `rolling_min` and `rolling_max`. pandas instead treats NaN as
missing and counts only non-NaN values toward `min_periods`: `rolling_min`
over `[5, NaN, 7, 3]` with `window = 3, min_periods = 1` is
`[Some(5), Some(NaN), Some(NaN), Some(NaN)]` here and `[5, 5, 5, 3]` in pandas.
Drop or impute non-finite inputs first if you need pandas' behavior.

The module is `f64` only. Passing an `f32` list or tensor is a type error.
