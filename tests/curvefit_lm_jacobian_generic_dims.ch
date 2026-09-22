module Nautilus.Tests_Blocked.Curvefit.Lm_Jacobian_Generic_Dims
import Std.Test (assert_close_tensor)
def lm_generic_linear_model(theta: &tensor[2, f32], x_data: &tensor[6, f32]) -> tensor[6, f32] = {
  a_basis = to_tensor([cast(1.0, f32), cast(0.0, f32)])
  b_basis = to_tensor([cast(0.0, f32), cast(1.0, f32)])
  a = tensor_to_scalar(sum(mul(theta, a_basis), cast(0, i32)))
  b = tensor_to_scalar(sum(mul(theta, b_basis), cast(0, i32)))
  a_vec = insert(scalar_to_tensor(a), cast(0, i32), cast(6, i64))
  b_vec = insert(scalar_to_tensor(b), cast(0, i32), cast(6, i64))
  add(mul(x_data, a_vec), b_vec)
}
def lm_generic_jacobian_row[n, m](model: &tensor[n, f32] -> &tensor[m, f32] -> tensor[m, f32], theta: tensor[n, f32], x_data: tensor[m, f32], output_seed: tensor[m, f32]) -> tensor[n, f32] = {
  target = fn (theta_local: tensor[n, f32], x_local: tensor[m, f32], seed_local: tensor[m, f32]) -> {
    prediction = model(theta_local, x_local)
    tensor_to_scalar(sum(mul(prediction, seed_local), cast(0, i32)))
  }
  grad(target, wrt=theta_local)(theta, x_data, output_seed)
}
def test_blocked_lm_jacobian_generic_dims() -> unit ! { Test } = {
  theta = to_tensor([cast(2.0, f32), cast(0.5, f32)])
  x_data = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])
  seed = to_tensor([cast(1.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32)])
  row = lm_generic_jacobian_row(lm_generic_linear_model, theta, x_data, seed)
  assert_close_tensor(row, to_tensor([cast(1.0, f32), cast(1.0, f32)]), cast(0.00001, f32), "first LM Jacobian row")
}
