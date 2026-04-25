module Nautilus.Tests.CurveFit

-- Identity / structural tests for Nautilus.CurveFit.
-- All expected values are mathematical identities or noiseless data
-- constructed from a known model + known truth theta. No scipy-derived
-- numerics: the test is "fit recovers the truth used to construct y".
-- Convergence-on-real-data parity tests live under tests/parity/.

import Nautilus.CurveFit (lm_scalar_1param, lm_scalar_nparam)
import Nautilus.LinAlg (inner_product, la_basis_n_f32, scale_vec, la_vec_add, la_vec_sub)
import Std.Test (assert_close, assert_close_tensor, assert_true)

-- ===== 1-PARAM SCALAR MODELS =====

-- y = theta * x  (linear-through-origin, single parameter)
def cf_lin_model(x: f32, theta: f32) -> f32 = mul(theta, x)
def cf_lin_dmodel(x: f32, theta: f32) -> f32 = x

-- y = exp(-theta * x)
def cf_exp_model(x: f32, theta: f32) -> f32 =
  exp(neg(mul(theta, x)))

def cf_exp_dmodel(x: f32, theta: f32) -> f32 = {
  e = exp(neg(mul(theta, x)))
  mul(neg(x), e)
}

-- ===== N-PARAM TENSOR MODELS =====

-- Pull theta[k] out of a tensor[n, f32] by inner product with a basis vector.
def cf_get[n](theta: tensor[n, f32], k: int64) -> f32 = {
  tpl = to_tensor(map(fn (v: f32) -> cast(0.0, f32), to_list(copy(theta))))
  e_k = la_basis_n_f32(k, cast(1.0, f32), tpl)
  inner_product(theta, e_k)
}

-- 2-parameter linear model: y_i = theta[0]*x_i + theta[1]
def cf_nparam_linear2(theta: tensor[2, f32], x_data: tensor[6, f32]) -> tensor[6, f32] = {
  a = cf_get(copy(theta), cast(0, int64))
  b = cf_get(theta, cast(1, int64))
  ones = to_tensor(map(fn (v: f32) -> cast(1.0, f32), to_list(copy(x_data))))
  la_vec_add(scale_vec(x_data, a), scale_vec(ones, b))
}

-- 1-parameter "vector" model: y_i = theta[0]*x_i  (n_param=1 nparam variant)
def cf_nparam_lin1(theta: tensor[1, f32], x_data: tensor[4, f32]) -> tensor[4, f32] = {
  a = cf_get(theta, cast(0, int64))
  scale_vec(x_data, a)
}

-- 2-parameter exponential model: y_i = theta[0] * exp(theta[1] * x_i)
def cf_nparam_exp2(theta: tensor[2, f32], x_data: tensor[6, f32]) -> tensor[6, f32] = {
  a = cf_get(copy(theta), cast(0, int64))
  b = cf_get(theta, cast(1, int64))
  bx = scale_vec(x_data, b)
  exp_bx = to_tensor(map(fn (v: f32) -> exp(v), to_list(bx)))
  scale_vec(exp_bx, a)
}

-- ===== HELPERS =====

-- Sum of squared residuals of y vs model(theta, xs)
def cf_ssr_2param(
  model: tensor[2, f32] -> tensor[6, f32] -> tensor[6, f32],
  theta: tensor[2, f32],
  xs: tensor[6, f32],
  ys: tensor[6, f32]
) -> f32 = {
  pred = model(theta, xs)
  r = la_vec_sub(ys, pred)
  inner_product(copy(r), r)
}

def cf_abs(x: f32) -> f32 =
  if lt(x, cast(0.0, f32)) then neg(x) else x

-- ===== lm_scalar_1param: y = theta * x =====

def test_lm1_linear_recovers_truth() -> unit ! { Test } = {
  -- True theta = 2.0; noiseless ys = 2*xs for xs = [1,2,3,4]
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32), cast(8.0, f32)])
  theta_hat = lm_scalar_1param(cf_lin_model, cf_lin_dmodel, xs, ys,
                                cast(0.5, f32),       -- theta0 (far from truth)
                                cast(0.01, f32),      -- lambda0
                                cast(1.0e-8, f32),    -- tol
                                cast(100, int64))     -- max_iters
  assert_close(theta_hat, cast(2.0, f32), cast(1.0e-4, f32),
               "lm_scalar_1param: y = theta*x recovers theta = 2 from noiseless data")
}

def test_lm1_linear_trivial_fit() -> unit ! { Test } = {
  -- theta0 == theta_true: solver must not move (delta below tol immediately).
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32), cast(8.0, f32)])
  theta_hat = lm_scalar_1param(cf_lin_model, cf_lin_dmodel, xs, ys,
                                cast(2.0, f32),       -- theta0 == truth
                                cast(0.01, f32), cast(1.0e-8, f32), cast(50, int64))
  assert_close(theta_hat, cast(2.0, f32), cast(1.0e-6, f32),
               "lm_scalar_1param: trivial fit (theta0 = truth) does not move")
}

def test_lm1_linear_residual_zero() -> unit ! { Test } = {
  -- After convergence on noiseless data, sum of squared residuals ~ 0.
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys = to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32), cast(8.0, f32)])
  theta_hat = lm_scalar_1param(cf_lin_model, cf_lin_dmodel, copy(xs), copy(ys),
                                cast(0.5, f32),
                                cast(0.01, f32), cast(1.0e-8, f32), cast(100, int64))
  -- Compute SSR by hand on the recovered theta.
  pred = to_tensor(map(fn (x: f32) -> cf_lin_model(x, theta_hat), to_list(xs)))
  r = la_vec_sub(ys, pred)
  ssr = inner_product(copy(r), r)
  assert_close(ssr, cast(0.0, f32), cast(1.0e-4, f32),
               "lm_scalar_1param: SSR at recovered theta ~ 0 on noiseless linear data")
}

def test_lm1_exp_recovers_truth() -> unit ! { Test } = {
  -- y = exp(-theta*x); true theta = 0.5 over xs=[0,1,2,3].
  -- Closed-form ys: [1, e^{-0.5}, e^{-1}, e^{-1.5}]
  -- 0.6065307 = e^{-0.5}; 0.3678794 = e^{-1}; 0.2231302 = e^{-1.5}
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  ys = to_tensor([cast(1.0, f32), cast(0.6065307, f32),
                  cast(0.3678794, f32), cast(0.2231302, f32)])
  theta_hat = lm_scalar_1param(cf_exp_model, cf_exp_dmodel, xs, ys,
                                cast(1.0, f32),       -- theta0
                                cast(0.01, f32),
                                cast(1.0e-6, f32),
                                cast(200, int64))
  assert_close(theta_hat, cast(0.5, f32), cast(1.0e-3, f32),
               "lm_scalar_1param: y = exp(-theta*x) recovers theta = 0.5")
}

-- ===== lm_scalar_nparam: linear y = a*x + b =====

def test_lm_nparam_linear_recovers_truth() -> unit ! { Test } = {
  -- True theta = [2, 0.5]; noiseless ys = 2*xs + 0.5 for xs = 1..6
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32),
                  cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])
  ys = to_tensor([cast(2.5, f32), cast(4.5, f32), cast(6.5, f32),
                  cast(8.5, f32), cast(10.5, f32), cast(12.5, f32)])
  theta0 = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  theta_hat = lm_scalar_nparam(cf_nparam_linear2, xs, ys, theta0,
                                cast(1.0e-5, f32), cast(100, int64))
  expected = to_tensor([cast(2.0, f32), cast(0.5, f32)])
  assert_close_tensor(theta_hat, expected, cast(1.0e-2, f32),
                      "lm_scalar_nparam (2-param linear) recovers theta = [2, 0.5]")
}

def test_lm_nparam_linear_trivial_fit() -> unit ! { Test } = {
  -- theta0 = theta_true; iterating must keep us essentially at the truth.
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32),
                  cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])
  ys = to_tensor([cast(2.5, f32), cast(4.5, f32), cast(6.5, f32),
                  cast(8.5, f32), cast(10.5, f32), cast(12.5, f32)])
  theta0 = to_tensor([cast(2.0, f32), cast(0.5, f32)])
  theta_hat = lm_scalar_nparam(cf_nparam_linear2, xs, ys, theta0,
                                cast(1.0e-5, f32), cast(50, int64))
  expected = to_tensor([cast(2.0, f32), cast(0.5, f32)])
  assert_close_tensor(theta_hat, expected, cast(1.0e-2, f32),
                      "lm_scalar_nparam: trivial fit (theta0 = truth) stays at truth")
}

def test_lm_nparam_linear_residual_zero() -> unit ! { Test } = {
  -- SSR at recovered theta on noiseless data ~ 0.
  xs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32),
                  cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])
  ys = to_tensor([cast(2.5, f32), cast(4.5, f32), cast(6.5, f32),
                  cast(8.5, f32), cast(10.5, f32), cast(12.5, f32)])
  theta0 = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  theta_hat = lm_scalar_nparam(cf_nparam_linear2, copy(xs), copy(ys), theta0,
                                cast(1.0e-5, f32), cast(100, int64))
  ssr = cf_ssr_2param(cf_nparam_linear2, theta_hat, xs, ys)
  assert_true(lt(ssr, cast(1.0e-2, f32)),
              "lm_scalar_nparam: SSR at recovered theta < 1e-2 on noiseless linear data")
}

-- ===== lm_scalar_nparam: exponential y = A*exp(B*x) =====

def test_lm_nparam_exp_recovers_truth() -> unit ! { Test } = {
  -- True theta = [3.0, -1.0]; noiseless ys = 3*exp(-x) over xs = 0..5
  -- Closed-form ys precomputed:
  --   3*exp(0) = 3
  --   3*exp(-1) = 1.1036383   (3 * 0.3678794)
  --   3*exp(-2) = 0.4060058
  --   3*exp(-3) = 0.1493612
  --   3*exp(-4) = 0.0549363
  --   3*exp(-5) = 0.0202101
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32),
                  cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  ys = to_tensor([cast(3.0, f32),       cast(1.1036383, f32),
                  cast(0.4060058, f32), cast(0.1493612, f32),
                  cast(0.0549363, f32), cast(0.0202101, f32)])
  -- LM is harder for nonlinear models -> start near the truth.
  theta0 = to_tensor([cast(2.5, f32), cast(-0.5, f32)])
  theta_hat = lm_scalar_nparam(cf_nparam_exp2, xs, ys, theta0,
                                cast(1.0e-6, f32), cast(200, int64))
  expected = to_tensor([cast(3.0, f32), cast(-1.0, f32)])
  assert_close_tensor(theta_hat, expected, cast(5.0e-2, f32),
                      "lm_scalar_nparam (2-param exp) recovers theta = [3, -1]")
}

def test_lm_nparam_exp_trivial_fit() -> unit ! { Test } = {
  -- theta0 = theta_true: must stay at truth (no spurious motion).
  xs = to_tensor([cast(0.0, f32), cast(1.0, f32), cast(2.0, f32),
                  cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  ys = to_tensor([cast(3.0, f32),       cast(1.1036383, f32),
                  cast(0.4060058, f32), cast(0.1493612, f32),
                  cast(0.0549363, f32), cast(0.0202101, f32)])
  theta0 = to_tensor([cast(3.0, f32), cast(-1.0, f32)])
  theta_hat = lm_scalar_nparam(cf_nparam_exp2, xs, ys, theta0,
                                cast(1.0e-6, f32), cast(50, int64))
  expected = to_tensor([cast(3.0, f32), cast(-1.0, f32)])
  assert_close_tensor(theta_hat, expected, cast(1.0e-2, f32),
                      "lm_scalar_nparam (exp): trivial fit stays at truth")
}

-- ===== Cross-check: nparam with n=1 vs scalar 1-param =====

def test_lm_nparam_n1_matches_scalar() -> unit ! { Test } = {
  -- Same data fit by lm_scalar_1param (theta scalar) and by lm_scalar_nparam
  -- with n_param = 1 (theta as tensor[1,f32]) should agree on the recovered
  -- parameter for the y = theta*x model.
  xs_s = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  ys_s = to_tensor([cast(3.0, f32), cast(6.0, f32), cast(9.0, f32), cast(12.0, f32)])
  scalar_hat = lm_scalar_1param(cf_lin_model, cf_lin_dmodel,
                                 copy(xs_s), copy(ys_s),
                                 cast(0.5, f32),
                                 cast(0.01, f32),
                                 cast(1.0e-8, f32),
                                 cast(100, int64))
  theta0_v = to_tensor([cast(0.5, f32)])
  vec_hat = lm_scalar_nparam(cf_nparam_lin1, xs_s, ys_s, theta0_v,
                              cast(1.0e-6, f32), cast(100, int64))
  -- Both should land near 3.0 (true slope).
  vec_expected = to_tensor([cast(3.0, f32)])
  vec_scalar = inner_product(copy(vec_hat), to_tensor([cast(1.0, f32)]))
  diff = cf_abs(sub(vec_scalar, scalar_hat))
  _ = assert_close(scalar_hat, cast(3.0, f32), cast(1.0e-3, f32),
                    "lm_scalar_1param recovers theta = 3 on y = 3x")
  _ = assert_close_tensor(vec_hat, vec_expected, cast(1.0e-2, f32),
                           "lm_scalar_nparam (n=1) recovers theta = [3] on y = 3x")
  -- And they should match each other to within solver tolerance.
  assert_true(lt(diff, cast(1.0e-2, f32)),
              "lm_scalar_nparam (n=1) and lm_scalar_1param agree within 1e-2")
}
