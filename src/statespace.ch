module Nautilus.StateSpace
export (kalman_predict_scalar, kalman_update_scalar, kalman_step_scalar, local_level_predict, local_level_update, local_level_step)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-STATESPACE
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.StateSpace MUST provide the scalar Kalman surface listed in the module support table.
def kalman_predict_scalar(mean: f32, covariance: f32, transition: f32, process_var: f32, control: f32, control_input: f32) -> (f32, f32) = {
  predicted_mean = transition |> mul(mean) |> add(mul(control, control_input))
  predicted_covariance = add(mul(mul(transition, transition), covariance), process_var)
  (predicted_mean, predicted_covariance)
}
def kalman_update_scalar(predicted_mean: f32, predicted_covariance: f32, observation: f32, observation_matrix: f32, observation_var: f32) -> (f32, f32, f32) = {
  innovation = sub(observation, mul(observation_matrix, predicted_mean))
  innovation_covariance = add(mul(mul(observation_matrix, observation_matrix), predicted_covariance), observation_var)
  gain =
    predicted_covariance
    |> mul(observation_matrix)
    |> div(innovation_covariance)
  updated_mean = add(predicted_mean, mul(gain, innovation))
  updated_covariance = mul(sub(cast(1.0, f32), mul(gain, observation_matrix)), predicted_covariance)
  (updated_mean, updated_covariance, gain)
}
def kalman_step_scalar(mean: f32, covariance: f32, observation: f32, transition: f32, process_var: f32, observation_matrix: f32, observation_var: f32) -> (f32, f32, f32) = {
  predicted = kalman_predict_scalar(mean, covariance, transition, process_var, cast(0.0, f32), cast(0.0, f32))
  kalman_update_scalar(predicted.0, predicted.1, observation, observation_matrix, observation_var)
}
def local_level_predict(mean: f32, covariance: f32, process_var: f32) -> (f32, f32) = kalman_predict_scalar(mean, covariance, cast(1.0, f32), process_var, cast(0.0, f32), cast(0.0, f32))
def local_level_update(predicted_mean: f32, predicted_covariance: f32, observation: f32, observation_var: f32) -> (f32, f32, f32) = kalman_update_scalar(predicted_mean, predicted_covariance, observation, cast(1.0, f32), observation_var)
def local_level_step(mean: f32, covariance: f32, observation: f32, process_var: f32, observation_var: f32) -> (f32, f32, f32) = kalman_step_scalar(mean, covariance, observation, cast(1.0, f32), process_var, cast(1.0, f32), observation_var)
