module Nautilus.Tests.CurveFit
import Nautilus.CurveFit (lm_scalar_1param, lm_scalar_nparam)
import Nautilus.LinAlg (inner_product, la_basis_n, scale_vec, la_vec_add, la_vec_sub)
import Std.Test (assert_close, assert_close_tensor, assert_true)
def cf_lin_model(x: f32, theta: f32) -> f32 = mul(theta, x)
def cf_lin_dmodel(x: f32, theta: f32) -> f32 = x
def cf_exp_model(x: f32, theta: f32) -> f32 = exp(neg(mul(theta, x)))
def cf_exp_dmodel(x: f32, theta: f32) -> f32 = {
  e = exp(neg(mul(theta, x)))
  mul(neg(x), e)
}
def cf_get[n](theta: &tensor[n, f32], k: i64) -> f32 = {
  tpl = to_tensor(map(fn (v: f32) -> cast(0.0, f32), to_list(copy(theta))))
  e_k = la_basis_n(k, cast(1.0, f32), tpl)
  inner_product(theta, e_k)
}
def cf_nparam_linear2(theta: &tensor[2, f32], x_data: &tensor[6, f32]) -> tensor[6, f32] = {
  a = cf_get(copy(theta), cast(0, i64))
  b = cf_get(theta, cast(1, i64))
  ones = to_tensor(map(fn (v: f32) -> cast(1.0, f32), to_list(copy(x_data))))
  la_vec_add(scale_vec(x_data, a), scale_vec(ones, b))
}
def cf_nparam_lin1(theta: &tensor[1, f32], x_data: &tensor[4, f32]) -> tensor[4, f32] = {
  a = cf_get(theta, cast(0, i64))
  scale_vec(x_data, a)
}
def cf_nparam_exp2(theta: &tensor[2, f32], x_data: &tensor[6, f32]) -> tensor[6, f32] = {
  a = cf_get(copy(theta), cast(0, i64))
  b = cf_get(theta, cast(1, i64))
  bx = scale_vec(x_data, b)
  exp_bx = to_tensor(map(fn (v: f32) -> exp(v), to_list(bx)))
  scale_vec(exp_bx, a)
}
def cf_ssr_2param(model: &tensor[2, f32] -> &tensor[6, f32] -> tensor[6, f32], theta: &tensor[2, f32], xs: &tensor[6, f32], ys: &tensor[6, f32]) -> f32 = {
  pred = model(theta, xs)
  r = la_vec_sub(ys, pred)
  inner_product(copy(r), r)
}
def cf_abs(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x
def test_lm1_linear_recovers_truth() -> unit ! { Test } = {
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32), cast(8.0, f32)])
  theta_hat = lm_scalar_1param(cf_lin_model, cf_lin_dmodel, xs, ys, cast(0.5, f32), cast(0.01, f32), cast(1e-8, f32), cast(100, i64))
  assert_close(theta_hat, cast(2.0, f32), cast(0.0001, f32), "lm_scalar_1param: y = theta*x recovers theta = 2 from noiseless data")
}
def test_lm1_linear_trivial_fit() -> unit ! { Test } = {
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32), cast(8.0, f32)])
  theta_hat = lm_scalar_1param(cf_lin_model, cf_lin_dmodel, xs, ys, cast(2.0, f32), cast(0.01, f32), cast(1e-8, f32), cast(50, i64))
  assert_close(theta_hat, cast(2.0, f32), cast(1e-6, f32), "lm_scalar_1param: trivial fit (theta0 = truth) does not move")
}
def test_lm1_linear_residual_zero() -> unit ! { Test } = {
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32), cast(8.0, f32)])
  theta_hat = lm_scalar_1param(cf_lin_model, cf_lin_dmodel, copy(xs), copy(ys), cast(0.5, f32), cast(0.01, f32), cast(1e-8, f32), cast(100, i64))
  pred = to_tensor(map(fn (x: f32) -> cf_lin_model(x, theta_hat), to_list(xs)))
  r = la_vec_sub(ys, pred)
  ssr = inner_product(copy(r), r)
  assert_close(ssr, cast(0.0, f32), cast(0.0001, f32), "lm_scalar_1param: SSR at recovered theta ~ 0 on noiseless linear data")
}
def test_lm1_exp_recovers_truth() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(1.0, f32), cast(0.6065307, f32), cast(0.3678794, f32), cast(0.2231302, f32)])
  theta_hat = lm_scalar_1param(cf_exp_model, cf_exp_dmodel, xs, ys, cast(1.0, f32), cast(0.01, f32), cast(1e-6, f32), cast(200, i64))
  assert_close(theta_hat, cast(0.5, f32), cast(0.001, f32), "lm_scalar_1param: y = exp(-theta*x) recovers theta = 0.5")
}
def test_lm_nparam_linear_recovers_truth() -> unit ! { Test } = {
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])
  ys = to_tensor([cast(2.5, f32), cast(4.5, f32), cast(6.5, f32), cast(8.5, f32), cast(10.5, f32), cast(12.5, f32)])
  theta0 = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  theta_hat = lm_scalar_nparam(cf_nparam_linear2, xs, ys, theta0, cast(0.00001, f32), cast(100, i64))
  expected = to_tensor([cast(2.0, f32), cast(0.5, f32)])
  assert_close_tensor(theta_hat, expected, cast(0.01, f32), "lm_scalar_nparam (2-param linear) recovers theta = [2, 0.5]")
}
def test_lm_nparam_linear_trivial_fit() -> unit ! { Test } = {
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])
  ys = to_tensor([cast(2.5, f32), cast(4.5, f32), cast(6.5, f32), cast(8.5, f32), cast(10.5, f32), cast(12.5, f32)])
  theta0 = to_tensor([cast(2.0, f32), cast(0.5, f32)])
  theta_hat = lm_scalar_nparam(cf_nparam_linear2, xs, ys, theta0, cast(0.00001, f32), cast(50, i64))
  expected = to_tensor([cast(2.0, f32), cast(0.5, f32)])
  assert_close_tensor(theta_hat, expected, cast(0.01, f32), "lm_scalar_nparam: trivial fit (theta0 = truth) stays at truth")
}
def test_lm_nparam_linear_residual_zero() -> unit ! { Test } = {
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])
  ys = to_tensor([cast(2.5, f32), cast(4.5, f32), cast(6.5, f32), cast(8.5, f32), cast(10.5, f32), cast(12.5, f32)])
  theta0 = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  theta_hat = lm_scalar_nparam(cf_nparam_linear2, copy(xs), copy(ys), theta0, cast(0.00001, f32), cast(100, i64))
  ssr = cf_ssr_2param(cf_nparam_linear2, theta_hat, xs, ys)
  assert_true(lt(ssr, cast(0.01, f32)), "lm_scalar_nparam: SSR at recovered theta < 1e-2 on noiseless linear data")
}
def test_lm_nparam_exp_recovers_truth() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  ys = to_tensor([cast(3.0, f32), cast(1.1036383, f32), cast(0.4060058, f32), cast(0.1493612, f32), cast(0.0549363, f32), cast(0.0202101, f32)])
  theta0 = to_tensor([cast(2.5, f32), cast(-0.5, f32)])
  theta_hat = lm_scalar_nparam(cf_nparam_exp2, xs, ys, theta0, cast(1e-6, f32), cast(200, i64))
  expected = to_tensor([cast(3.0, f32), cast(-1.0, f32)])
  assert_close_tensor(theta_hat, expected, cast(0.05, f32), "lm_scalar_nparam (2-param exp) recovers theta = [3, -1]")
}
def test_lm_nparam_exp_trivial_fit() -> unit ! { Test } = {
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  ys = to_tensor([cast(3.0, f32), cast(1.1036383, f32), cast(0.4060058, f32), cast(0.1493612, f32), cast(0.0549363, f32), cast(0.0202101, f32)])
  theta0 = to_tensor([cast(3.0, f32), cast(-1.0, f32)])
  theta_hat = lm_scalar_nparam(cf_nparam_exp2, xs, ys, theta0, cast(1e-6, f32), cast(50, i64))
  expected = to_tensor([cast(3.0, f32), cast(-1.0, f32)])
  assert_close_tensor(theta_hat, expected, cast(0.01, f32), "lm_scalar_nparam (exp): trivial fit stays at truth")
}
def test_lm_nparam_n1_matches_scalar() -> unit ! { Test } = {
  xs_s = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys_s = to_tensor([cast(3.0, f32), cast(6.0, f32), cast(9.0, f32), cast(12.0, f32)])
  scalar_hat = lm_scalar_1param(cf_lin_model, cf_lin_dmodel, copy(xs_s), copy(ys_s), cast(0.5, f32), cast(0.01, f32), cast(1e-8, f32), cast(100, i64))
  theta0_v = to_tensor([cast(0.5, f32)])
  vec_hat = lm_scalar_nparam(cf_nparam_lin1, xs_s, ys_s, theta0_v, cast(1e-6, f32), cast(100, i64))
  vec_expected = to_tensor([cast(3.0, f32)])
  vec_scalar = inner_product(copy(vec_hat), to_tensor([cast(1.0, f32)]))
  diff = cf_abs(sub(vec_scalar, scalar_hat))
  _ = assert_close(scalar_hat, cast(3.0, f32), cast(0.001, f32), "lm_scalar_1param recovers theta = 3 on y = 3x")
  _ = assert_close_tensor(vec_hat, vec_expected, cast(0.01, f32), "lm_scalar_nparam (n=1) recovers theta = [3] on y = 3x")
  assert_true(lt(diff, cast(0.01, f32)), "lm_scalar_nparam (n=1) and lm_scalar_1param agree within 1e-2")
}
def test_lm1_sub_ulp_tol_plateau_locks_fixed_point() -> unit ! { Test } = {
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32), cast(8.0, f32)])
  nan_tol = div(cast(0.0, f32), cast(0.0, f32))
  theta_hat = lm_scalar_1param(cf_lin_model, cf_lin_dmodel, xs, ys, cast(0.5, f32), cast(0.01, f32), nan_tol, cast(50, i64))
  assert_close(theta_hat, cast(2.0, f32), cast(0.0001, f32), "lm_scalar_1param: plateau-stop locks bit-exact fixed point under NaN tol (sub-f32-ULP regime)")
}
