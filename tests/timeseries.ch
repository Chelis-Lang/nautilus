module Nautilus.Tests.TimeSeries
import Nautilus.TimeSeries (ts_ewma_next, ts_ewma_series, exponential_smoothing_next, ar1_predict_next, arma11_predict_next, arima110_predict_next)
import Std.Test (assert_close)
def test_ewma_next_half_alpha() -> unit ! { Test } = {
  xs = to_tensor([cast(2.0, f32), cast(4.0, f32)])
  assert_close(ts_ewma_next(xs, cast(0.5, f32), cast(0.0, f32)), cast(2.5, f32), cast(1e-6, f32), "EWMA final value")
}
def test_ewma_series_matches_final() -> unit ! { Test } = {
  xs = to_tensor([cast(2.0, f32), cast(4.0, f32)])
  series = ts_ewma_series(copy(xs), cast(0.5, f32), cast(0.0, f32))
  assert_close(ts_ewma_next(xs, cast(0.5, f32), cast(0.0, f32)), index(to_list(series), cast(1, int64)), cast(1e-6, f32), "EWMA series final equals EWMA next")
}
def test_exponential_smoothing_alias() -> unit ! { Test } = {
  xs = to_tensor([cast(2.0, f32), cast(4.0, f32)])
  assert_close(exponential_smoothing_next(xs, cast(0.5, f32), cast(0.0, f32)), cast(2.5, f32), cast(1e-6, f32), "exponential smoothing aliases EWMA")
}
def test_arma_helpers() -> unit ! { Test } = {
  xs = to_tensor([cast(10.0, f32), cast(12.0, f32)])
  ar = ar1_predict_next(copy(xs), cast(1.0, f32), cast(0.5, f32))
  arma = arma11_predict_next(copy(xs), cast(1.0, f32), cast(0.5, f32), cast(0.25, f32), cast(4.0, f32))
  arima = arima110_predict_next(xs, cast(1.0, f32), cast(0.5, f32), cast(0.25, f32), cast(4.0, f32))
  _ = assert_close(ar, cast(7.0, f32), cast(1e-6, f32), "AR(1) one-step prediction")
  _ = assert_close(arma, cast(8.0, f32), cast(1e-6, f32), "ARMA(1,1) one-step prediction")
  assert_close(arima, cast(15.0, f32), cast(1e-6, f32), "ARIMA(1,1,0) helper predicts next level")
}
