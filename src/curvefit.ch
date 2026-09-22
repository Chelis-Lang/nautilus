module Nautilus.CurveFit
import Nautilus.LinAlg (inv_2x2, inv_3x3, matvec, l2_norm_vec, la_vec_sub, la_vec_add, scale_vec, la_basis_n_f32, cg_solve, la_zeros_mat_like, inner_product)
export (lm_scalar_1param, lm_scalar_nparam)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-CURVEFIT
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.CurveFit MUST provide the Levenberg-Marquardt fitting surface listed in the module support table.
def cf_zero_f() -> f32 = cast(0.0, f32)
def cf_one_f() -> f32 = cast(1.0, f32)
def cf_nan_f() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def cf_abs(x: f32) -> f32 = if lt(x, cf_zero_f()) then neg(x) else x
def lm1_step[n](model: f32 -> f32 -> f32, dmodel: f32 -> f32 -> f32, xs: &tensor[n, f32], ys: &tensor[n, f32], theta: f32, lambda: f32) -> f32 = {
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
  tiny = cast(1e-30, f32)
  bad = lt(cf_abs(damped), tiny)
  if bad then theta else add(theta, div(jtr, damped))
}
def lm1_rec[n](model: f32 -> f32 -> f32, dmodel: f32 -> f32 -> f32, xs: &tensor[n, f32], ys: &tensor[n, f32], theta: f32, lambda: f32, tol: f32, iters: i64) -> f32 = {
  zero_i = cast(0, i64)
  one_i = cast(1, i64)
  if lte(iters, zero_i) then theta else {
    theta_next = lm1_step(model, dmodel, copy(xs), copy(ys), theta, lambda)
    delta = sub(theta_next, theta)
    abs_delta = cf_abs(delta)
    if eq(theta_next, theta) then theta_next else if lt(abs_delta, tol) then theta_next else lm1_rec(model, dmodel, xs, ys, theta_next, lambda, tol, sub(iters, one_i))
  }
}
def lm_scalar_1param[n](model: f32 -> f32 -> f32, dmodel: f32 -> f32 -> f32, xs: &tensor[n, f32], ys: &tensor[n, f32], theta0: f32, lambda0: f32, tol: f32, max_iters: i64) -> f32 = {
  n_i = numel(copy(xs))
  if lte(n_i, cast(0, i64)) then cf_nan_f() else lm1_rec(model, dmodel, xs, ys, theta0, lambda0, tol, max_iters)
}
-- Finite differences remain necessary while the exact-AD composition residue
-- in docs/UPSTREAM_BUGS.md §Actively blocking is live: isolated generic and
-- concrete Jacobian rows pass, but the attempted full LM replacement loses
-- runtime-extent binder provenance.
def lm_jcol[n, m](model: &tensor[n, f32] -> &tensor[m, f32] -> tensor[m, f32], x: &tensor[m, f32], theta: &tensor[n, f32], base_pred: &tensor[m, f32], tpl_n: &tensor[n, f32], i: i64, eps: f32) -> tensor[m, f32] = {
  eps_vec = la_basis_n_f32(i, eps, tpl_n)
  theta_plus = la_vec_add(theta, eps_vec)
  pred_plus = model(theta_plus, x)
  scale_vec(la_vec_sub(pred_plus, base_pred), div(cast(1.0, f32), eps))
}
def lm_jtr_sum[n, m](model: &tensor[n, f32] -> &tensor[m, f32] -> tensor[m, f32], x: &tensor[m, f32], theta: &tensor[n, f32], base_pred: &tensor[m, f32], r: &tensor[m, f32], tpl_n: &tensor[n, f32], i: i64, n_params: i64, eps: f32) -> tensor[n, f32] =
  if gte(i, n_params) then to_tensor(map(fn (t: f32) -> cast(0.0, f32), to_list(tpl_n))) else {
    j_col = lm_jcol(model, copy(x), copy(theta), copy(base_pred), copy(tpl_n), i, eps)
    jtr_i = inner_product(copy(j_col), copy(r))
    e_i = la_basis_n_f32(i, jtr_i, copy(tpl_n))
    rest = lm_jtr_sum(model, x, theta, base_pred, r, tpl_n, add(i, cast(1, i64)), n_params, eps)
    la_vec_add(e_i, rest)
  }
def lm_jtj_row_sum[n, m](model: &tensor[n, f32] -> &tensor[m, f32] -> tensor[m, f32], x: &tensor[m, f32], theta: &tensor[n, f32], base_pred: &tensor[m, f32], tpl_n: &tensor[n, f32], j_col_i: &tensor[m, f32], e_i: &tensor[n, f32], j: i64, n_params: i64, eps: f32) -> tensor[n, n, f32] =
  if gte(j, n_params) then {
    ztj = scale_vec(copy(tpl_n), cast(0.0, f32))
    einsum("i,j->ij", copy(ztj), ztj)
  } else {
    j_col_j = lm_jcol(model, copy(x), copy(theta), copy(base_pred), copy(tpl_n), j, eps)
    dot_ij = inner_product(copy(j_col_i), j_col_j)
    e_j = la_basis_n_f32(j, cast(1.0, f32), copy(tpl_n))
    this_entry = einsum("i,j->ij", scale_vec(copy(e_i), dot_ij), e_j)
    rest = lm_jtj_row_sum(model, x, theta, base_pred, tpl_n, j_col_i, e_i, add(j, cast(1, i64)), n_params, eps)
    add(this_entry, rest)
  }
def lm_jtj_sum[n, m](model: &tensor[n, f32] -> &tensor[m, f32] -> tensor[m, f32], x: &tensor[m, f32], theta: &tensor[n, f32], base_pred: &tensor[m, f32], tpl_n: &tensor[n, f32], i: i64, n_params: i64, eps: f32) -> tensor[n, n, f32] =
  if gte(i, n_params) then {
    ztj = scale_vec(copy(tpl_n), cast(0.0, f32))
    einsum("i,j->ij", copy(ztj), ztj)
  } else {
    j_col_i = lm_jcol(model, copy(x), copy(theta), copy(base_pred), copy(tpl_n), i, eps)
    e_i = la_basis_n_f32(i, cast(1.0, f32), copy(tpl_n))
    row_i = lm_jtj_row_sum(model, copy(x), copy(theta), copy(base_pred), copy(tpl_n), j_col_i, e_i, cast(0, i64), n_params, eps)
    rest = lm_jtj_sum(model, x, theta, base_pred, tpl_n, add(i, cast(1, i64)), n_params, eps)
    add(row_i, rest)
  }
def lm_nparam_step[n, m](model: &tensor[n, f32] -> &tensor[m, f32] -> tensor[m, f32], x: &tensor[m, f32], y: &tensor[m, f32], theta: tensor[n, f32], lambda: f32, eps: f32) -> tensor[n, f32] = {
  tpl_n = to_tensor(map(fn (t: f32) -> cast(0.0, f32), to_list(copy(theta))))
  n_params = len(to_list(copy(tpl_n)))
  base_pred = model(copy(theta), copy(x))
  r = la_vec_sub(copy(y), copy(base_pred))
  zero_n = to_tensor(map(fn (t: f32) -> cast(0.0, f32), to_list(copy(tpl_n))))
  jtr = lm_jtr_sum(model, copy(x), copy(theta), copy(base_pred), copy(r), copy(tpl_n), cast(0, i64), n_params, eps)
  jtj = lm_jtj_sum(model, copy(x), copy(theta), copy(base_pred), copy(tpl_n), cast(0, i64), n_params, eps)
  lamb_i = fold(fn (acc: tensor[n, n, f32], i: i64) -> {
    le_i = la_basis_n_f32(i, lambda, copy(tpl_n))
    ue_i = la_basis_n_f32(i, cast(1.0, f32), copy(tpl_n))
    add(acc, einsum("i,j->ij", le_i, ue_i))
  }, la_zeros_mat_like(copy(jtj)), range(cast(0, i64), n_params))
  h = add(jtj, lamb_i)
  delta = cg_solve(h, jtr, zero_n, cast(1e-6, f32), cast(50, i64))
  la_vec_add(theta, delta)
}
def lm_scalar_nparam[n, m](model: &tensor[n, f32] -> &tensor[m, f32] -> tensor[m, f32], x: &tensor[m, f32], y: &tensor[m, f32], theta0: tensor[n, f32], tol: f32, max_iters: i64) -> tensor[n, f32] = fold(fn (th: tensor[n, f32], iter_idx: i64) -> lm_nparam_step(model, x, y, th, cast(0.01, f32), cast(0.00001, f32)), theta0, range(cast(0, i64), max_iters))
