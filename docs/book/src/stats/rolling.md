# Rolling and expanding windows

`Nautilus.Rolling` provides rolling and expanding reductions and lag functions
over `List[f64]`. Results that are undefined at an index use `Option`, so
`None` means no value is available and `Some(NaN)` remains a numerical result.

## Rolling reductions

Each rolling reduction takes a series, a `window`, and `min_periods`:

```chelis
module Nautilus.BookRollingBasics
import Nautilus.Rolling (rolling_mean, rolling_std)
def prices() -> List[f64] = [cast(5.0, f64), cast(2.0, f64), cast(7.0, f64), cast(3.0, f64), cast(9.0, f64), cast(1.0, f64)]
def three_day_mean() -> List[Option[f64]] = rolling_mean(prices(), cast(3, i64), cast(3, i64))
def three_day_sample_sd() -> List[Option[f64]] = rolling_std(prices(), cast(3, i64), cast(3, i64), cast(1, i64))
```

With `window = 3` and `min_periods = 3`, the first two positions are `None`;
later positions contain the reduction over the three most recent values.
When `min_periods` is less than the window, leading positions reduce the
shorter history available so far. Every result has one entry per input value.

`ddof` selects the variance convention: `1` gives the sample variance used by
Pandas `std()` by default, while `0` gives the population variance. An
expanding reduction uses all values from the start of the series through the
current position.

## Lag functions

`shift`, `diff`, and `pct_change` use an integer lag `k`. Positive `k` reads
earlier values; negative `k` reads later values, like a lead. Positions without
a corresponding value are `None`. `shift_fill` uses a caller-provided edge
value, while `shift_clamped` repeats the first or last observation at the edge.

```chelis
module Nautilus.BookRollingLags
import Nautilus.Rolling (shift, shift_fill, shift_clamped, diff, pct_change)
def prices() -> List[f64] = [cast(5.0, f64), cast(2.0, f64), cast(7.0, f64), cast(3.0, f64)]
def yesterday() -> List[Option[f64]] = shift(prices(), cast(1, i64))
def zero_padded() -> List[f64] = shift_fill(prices(), cast(1, i64), cast(0.0, f64))
def edge_clamped() -> List[f64] = shift_clamped(prices(), cast(1, i64))
def daily_change() -> List[Option[f64]] = diff(prices(), cast(1, i64))
def daily_return() -> List[Option[f64]] = pct_change(prices(), cast(1, i64))
```

Negative lags are useful for forward differences and returns. They can expose
future values, so avoid them when computing signals that must not look ahead.

## Missing and non-finite values

An input `NaN` or infinity is treated as a value and propagates through the
reductions. Pandas instead treats `NaN` as missing when counting observations
toward `min_periods`. Drop or impute non-finite inputs first if you need that
missing-data behavior.

The rolling functions use `f64`. Tensor variants are also available for
`&tensor[n, f64]`. Variants whose result may be absent return a list of
`Option[f64]`; `tensor_shift_fill` and `tensor_shift_clamped` return tensors
because they define a value at every position.
