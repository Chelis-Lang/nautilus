module Nautilus.Tests.StateSpace
import Nautilus.StateSpace (kalman_predict_scalar, kalman_update_scalar, kalman_step_scalar, local_level_step)
import Std.Test (assert_close, assert_true)
def test_kalman_predict_scalar_covariance_output() -> unit ! { Test } = {
  pred = kalman_predict_scalar(cast(10.0, f32), cast(4.0, f32), cast(1.0, f32), cast(1.0, f32), cast(0.0, f32), cast(0.0, f32))
  assert_close(pred.1, cast(5.0, f32), cast(0.000001, f32), "predict covariance adds process variance")
}
def test_kalman_update_scalar_reduces_covariance() -> unit ! { Test } = {
  upd = kalman_update_scalar(cast(10.0, f32), cast(5.0, f32), cast(12.0, f32), cast(1.0, f32), cast(3.0, f32))
  assert_true(lt(upd.1, cast(5.0, f32)), "Kalman update covariance is smaller than predicted covariance")
}
def test_local_level_step_matches_general_step() -> unit ! { Test } = {
  a = local_level_step(cast(10.0, f32), cast(4.0, f32), cast(12.0, f32), cast(1.0, f32), cast(3.0, f32))
  b = kalman_step_scalar(cast(10.0, f32), cast(4.0, f32), cast(12.0, f32), cast(1.0, f32), cast(1.0, f32), cast(1.0, f32), cast(3.0, f32))
  assert_close(a.0, b.0, cast(0.000001, f32), "local-level step is general scalar step with identity transition/observation")
}
