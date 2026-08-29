module Nautilus.TimeSeries
export (ts_ewma_next, ts_ewma_series, exponential_smoothing_next, exponential_smoothing_series, ar1_predict_next, arma11_predict_next, arima110_predict_next)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-TIMESERIES
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.TimeSeries MUST provide the smoothing and forecasting surface listed in the module support table.
def ts_ewma_next[n](values: &tensor[n, f32], alpha: f32, initial: f32) -> f32 = {
  one = cast(1.0, f32)
  one_minus_alpha = sub(one, alpha)
  fold(fn (acc: f32, x: f32) -> alpha |> mul(x) |> add(mul(one_minus_alpha, acc)), initial, to_list(values))
}
def ts_ewma_series[n](values: &tensor[n, f32], alpha: f32, initial: f32) -> tensor[n, f32] = {
  one = cast(1.0, f32)
  one_minus_alpha = sub(one, alpha)
  to_tensor(scan(fn (acc: f32, x: f32) -> add(mul(alpha, x), mul(one_minus_alpha, acc)), initial, to_list(values)))
}
def exponential_smoothing_next[n](values: &tensor[n, f32], alpha: f32, initial_level: f32) -> f32 = ts_ewma_next(values, alpha, initial_level)
def exponential_smoothing_series[n](values: &tensor[n, f32], alpha: f32, initial_level: f32) -> tensor[n, f32] = ts_ewma_series(values, alpha, initial_level)
def ts_last[n](values: &tensor[n, f32]) -> f32 = {
  last_idx = values |> numel |> sub(cast(1, int64))
  fold(fn (acc: f32, pair: (int64, f32)) -> if eq(pair.0, last_idx) then pair.1 else acc, cast(0.0, f32), values |> to_list |> enumerate)
}
def ts_prev[n](values: &tensor[n, f32]) -> f32 = {
  prev_idx = values |> numel |> sub(cast(2, int64))
  fold(fn (acc: f32, pair: (int64, f32)) -> if eq(pair.0, prev_idx) then pair.1 else acc, cast(0.0, f32), values |> to_list |> enumerate)
}
def ar1_predict_next[n](values: &tensor[n, f32], intercept: f32, phi: f32) -> f32 = add(intercept, mul(phi, ts_last(values)))
def arma11_predict_next[n](values: &tensor[n, f32], intercept: f32, phi: f32, theta: f32, last_error: f32) -> f32 = {
  ar_part = mul(phi, ts_last(values))
  ma_part = mul(theta, last_error)
  intercept |> add(ar_part) |> add(ma_part)
}
def arima110_predict_next[n](values: &tensor[n, f32], drift: f32, phi: f32, theta: f32, last_error: f32) -> f32 = {
  last = ts_last(values)
  prev = ts_prev(values)
  diff = sub(last, prev)
  delta_hat = drift |> add(mul(phi, diff)) |> add(mul(theta, last_error))
  add(last, delta_hat)
}
