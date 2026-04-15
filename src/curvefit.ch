module Nautilus.CurveFit
import Nautilus.LinAlg (inv_2x2, inv_3x3, matvec)
export (lm_scalar_1param)

def cf_zero_f() -> f32 = cast(0.0, f32)
def cf_one_f() -> f32 = cast(1.0, f32)
def cf_nan_f() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def cf_abs(x: f32) -> f32 = if lt(x, cf_zero_f()) then neg(x) else x

def lm1_step[n](
  model: f32 -> f32 -> f32,
  dmodel: f32 -> f32 -> f32,
  xs: tensor[n, f32],
  ys: tensor[n, f32],
  theta: f32,
  lambda: f32
) -> f32 = {
  zipped = zip(to_list(xs), to_list(ys))
  sums = fold(fn (acc: (f32, f32), pair: (f32, f32)) -> {
    x = pair.0
    y = pair.1
    y_hat = model(x, theta)
    j = dmodel(x, theta)
    r = sub(y, y_hat)
    jj_next = add(acc.0, mul(j, j))
    jr_next = add(acc.1, mul(j, r))
    (jj_next, jr_next)
  }, (cf_zero_f(), cf_zero_f()), zipped)
  jtj = sums.0
  jtr = sums.1
  damped = mul(jtj, add(cf_one_f(), lambda))
  tiny = cast(1.0e-30, f32)
  bad = lt(cf_abs(damped), tiny)
  if bad then theta
  else add(theta, div(jtr, damped))
}

def lm1_rec[n](
  model: f32 -> f32 -> f32,
  dmodel: f32 -> f32 -> f32,
  xs: tensor[n, f32],
  ys: tensor[n, f32],
  theta: f32,
  lambda: f32,
  tol: f32,
  iters: int64
) -> f32 = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then theta
  else {
    theta_next = lm1_step(model, dmodel, copy(xs), copy(ys), theta, lambda)
    delta = sub(theta_next, theta)
    abs_delta = cf_abs(delta)
    if lt(abs_delta, tol) then theta_next
    else lm1_rec(model, dmodel, xs, ys, theta_next, lambda, tol, sub(iters, one_i))
  }
}

def lm_scalar_1param[n](
  model: f32 -> f32 -> f32,
  dmodel: f32 -> f32 -> f32,
  xs: tensor[n, f32],
  ys: tensor[n, f32],
  theta0: f32,
  lambda0: f32,
  tol: f32,
  max_iters: int64
) -> f32 = {
  n_i = numel(copy(xs))
  if lte(n_i, cast(0, int64)) then cf_nan_f()
  else lm1_rec(model, dmodel, xs, ys, theta0, lambda0, tol, max_iters)
}
