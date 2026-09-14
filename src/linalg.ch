module Nautilus.LinAlg
export (transpose, matmul_wrap, gram, aat, diag, trace_mat, trace_scalar, l2_norm_vec, inner_product, frobenius_sq, frobenius_norm, scale_vec, matvec, vecmat, det_2x2, det_3x3, la_vec_add, la_vec_sub, la_vec_saxpy, cg_solve, inv_2x2, inv_3x3, solve_2x2, solve_3x3, eig_2x2_real, cholesky_2x2, cholesky_n, lu_solve, qr_decompose, svd_n, eig_n, la_basis_n, la_zeros_mat_like)
-- chelis:provenance/v1 authority
-- id = NAUT-MOD-LINALG
-- kind = behavioral
-- scopes = nautilus
-- statement = Nautilus.LinAlg MUST provide the linear-algebra surface listed in the module support table.
def transpose[m, n, prec: Float](a: &tensor[m, n, prec]) -> tensor[n, m, prec] = permute(a, 1, 0)
-- chelis:provenance/v1 binding
-- record = blake3-256:7930634eace4246ffd2bd35fdaf7020a39b5e0d7f50259a607d877a668d06596
def matmul_wrap[m, k, n, prec: Float](a: &tensor[m, k, prec], b: &tensor[k, n, prec]) -> tensor[m, n, prec] = matmul(a, b)
def gram[m, n, prec: Float](a: &tensor[m, n, prec]) -> tensor[n, n, prec] = {
  at = permute(a, 1, 0)
  matmul(at, a)
}
def aat[m, n, prec: Float](a: &tensor[m, n, prec]) -> tensor[m, m, prec] = {
  at = permute(a, 1, 0)
  matmul(a, at)
}
def diag[n, prec: Float](a: &tensor[n, n, prec]) -> tensor[n, prec] = diagonal(a, 0, 1)
def trace_mat[n, prec: Float](a: &tensor[n, n, prec]) -> tensor[prec] = trace(a, 0, 1)
def trace_scalar[n, prec: Float](a: &tensor[n, n, prec]) -> prec = {
  d = diagonal(a, 0, 1)
  fold(fn (acc: prec, x: prec) -> add(acc, x), cast(0.0, prec), to_list(d))
}
def l2_norm_vec[n, prec: Float](v: &tensor[n, prec]) -> prec = {
  s = fold(fn (acc: prec, x: prec) -> add(acc, mul(x, x)), cast(0.0, prec), to_list(v))
  sqrt(s)
}
def inner_product[n, prec: Float](a: &tensor[n, prec], b: &tensor[n, prec]) -> prec = {
  zipped = a |> to_list |> zip(to_list(b))
  fold(fn (acc: prec, pair: (prec, prec)) -> {
    x = pair.0
    y = pair.1
    add(acc, mul(x, y))
  }, cast(0.0, prec), zipped)
}
def frobenius_sq[m, n, prec: Float](a: &tensor[m, n, prec]) -> prec = {
  rows = to_list(sum(mul(a, a), 1))
  fold(fn (acc: prec, x: prec) -> add(acc, x), cast(0.0, prec), rows)
}
def frobenius_norm[m, n, prec: Float](a: &tensor[m, n, prec]) -> prec = {
  rows = to_list(sum(mul(a, a), 1))
  s = fold(fn (acc: prec, x: prec) -> add(acc, x), cast(0.0, prec), rows)
  sqrt(s)
}
-- nautilus PR 47: lift a scalar to rank `n` so an elementwise tensor op can
-- take it. Chelis has no implicit tensor-scalar broadcasting; `expand`
-- lowers to a stride-0 view, so this costs no per-element storage.
def la_lift_t[n, prec: Float](template: &tensor[n, prec], c: prec) -> tensor[n, prec] = c |> scalar_to_tensor |> expand(0, shape(template, cast(0, int32)))
def scale_vec[n, prec: Float](v: &tensor[n, prec], s: prec) -> tensor[n, prec] = v |> la_lift_t(s) |> mul(v)
def matvec[m, n, prec: Float](a: &tensor[m, n, prec], v: &tensor[n, prec]) -> tensor[m, prec] = einsum("ij,j->i", a, v)
def vecmat[m, n, prec: Float](v: &tensor[m, prec], a: &tensor[m, n, prec]) -> tensor[n, prec] = einsum("i,ij->j", v, a)
def det_2x2[prec: Float](a: &tensor[2, 2, prec]) -> prec = {
  t = trace_scalar(a)
  a2 = matmul(a, a)
  t2 = trace_scalar(a2)
  half = cast(0.5, prec)
  mul(half, t |> mul(t) |> sub(t2))
}
def la_vec_add[n, prec: Float](a: &tensor[n, prec], b: &tensor[n, prec]) -> tensor[n, prec] = add(a, b)
def la_vec_sub[n, prec: Float](a: &tensor[n, prec], b: &tensor[n, prec]) -> tensor[n, prec] = sub(a, b)
def la_vec_saxpy[n, prec: Float](alpha: prec, x: &tensor[n, prec], y: &tensor[n, prec]) -> tensor[n, prec] = add(x, y |> la_lift_t(alpha) |> mul(y))
def cg_step_rec[n, prec: Float](a_mat: tensor[n, n, prec], x: tensor[n, prec], r: tensor[n, prec], p: tensor[n, prec], rs_old: prec, tol: prec, iters: int64) -> tensor[n, prec] = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then x else if lt(rs_old, tol) then x else {
    ap = matvec(a_mat, p)
    pap = inner_product(p, ap)
    alpha = div(rs_old, pap)
    x_next = la_vec_saxpy(alpha, x, p)
    neg_alpha = neg(alpha)
    r_next = la_vec_saxpy(neg_alpha, r, ap)
    rs_new = inner_product(r_next, r_next)
    beta = div(rs_new, rs_old)
    p_next = la_vec_saxpy(beta, r_next, p)
    cg_step_rec(a_mat, x_next, r_next, p_next, rs_new, tol, sub(iters, one_i))
  }
}
def cg_solve[n, prec: Float](a_mat: tensor[n, n, prec], b: tensor[n, prec], x0: tensor[n, prec], tol: prec, max_iters: int64) -> tensor[n, prec] = {
  ax0 = matvec(a_mat, x0)
  r0 = la_vec_sub(b, ax0)
  p0 = la_vec_add(r0, to_tensor(map(fn (x: prec) -> cast(0.0, prec), to_list(r0))))
  rs0 = inner_product(r0, r0)
  cg_step_rec(a_mat, x0, r0, p0, rs0, tol, max_iters)
}
def la_zeros_mat_like[n, prec: Float](a: &tensor[n, n, prec]) -> tensor[n, n, prec] = sub(a, a)
def la_basis_n[n, prec: Float](k: int64, s: prec, template: &tensor[n, prec]) -> tensor[n, prec] = {
  items_len = template |> to_list |> len
  idxs = cast(0, int64) |> range(items_len)
  to_tensor(map(fn (i: int64) -> if eq(i, k) then s else cast(0.0, prec), idxs))
}
def la_mask_ge_j[n, prec: Float](j: int64, template: &tensor[n, prec]) -> tensor[n, prec] = {
  items_len = template |> to_list |> len
  idxs = cast(0, int64) |> range(items_len)
  to_tensor(map(fn (i: int64) -> if gte(i, j) then cast(1.0, prec) else cast(0.0, prec), idxs))
}
def la_mask_gt_j[n, prec: Float](j: int64, template: &tensor[n, prec]) -> tensor[n, prec] = {
  items_len = template |> to_list |> len
  idxs = cast(0, int64) |> range(items_len)
  to_tensor(map(fn (i: int64) -> if gt(i, j) then cast(1.0, prec) else cast(0.0, prec), idxs))
}
def la_elementwise_mul_vec[n, prec: Float](a: &tensor[n, prec], b: &tensor[n, prec]) -> tensor[n, prec] = mul(a, b)
def la_identity_n[n, prec: Float](template: &tensor[n, prec]) -> tensor[n, n, prec] = {
  n_len = template |> to_list |> len
  outer = einsum("i,j->ij", template, template)
  zero_mat = la_zeros_mat_like(outer)
  fold(fn (acc, i) -> {
    e_i = la_basis_n(i, cast(1.0, prec), template)
    outer_diag = einsum("i,j->ij", e_i, e_i)
    add(acc, outer_diag)
  }, zero_mat, cast(0, int64) |> range(n_len))
}
def la_qr_hh_step_r[n, prec: Float](a_curr: tensor[n, n, prec], j: int64) -> tensor[n, n, prec] = {
  template = diag(a_curr)
  e_j = la_basis_n(j, cast(1.0, prec), template)
  col_j = matvec(a_curr, e_j)
  masked_col = la_elementwise_mul_vec(col_j, la_mask_ge_j(j, template))
  norm_x = l2_norm_vec(masked_col)
  x_j = inner_product(masked_col, e_j)
  sign_xj = if gte(x_j, cast(0.0, prec)) then cast(1.0, prec) else cast(-1.0, prec)
  shift = la_basis_n(j, mul(sign_xj, norm_x), template)
  v = la_vec_add(masked_col, shift)
  norm_v = l2_norm_vec(v)
  safe_norm_v = if lt(norm_v, cast(1e-30, prec)) then cast(1.0, prec) else norm_v
  v_hat = scale_vec(v, cast(1.0, prec) |> div(safe_norm_v))
  vt_A = vecmat(v_hat, a_curr)
  rank1 = einsum("i,j->ij", scale_vec(v_hat, cast(2.0, prec)), vt_A)
  sub(a_curr, rank1)
}
def la_qr_apply_steps_rec[n, prec: Float](a: tensor[n, n, prec], k: int64, target: int64) -> tensor[n, n, prec] = if gte(k, target) then a else a |> la_qr_hh_step_r(k) |> la_qr_apply_steps_rec(add(k, cast(1, int64)), target)
def la_qr_hh_step_q[n, prec: Float](a_orig: tensor[n, n, prec], q_curr: tensor[n, n, prec], j: int64) -> tensor[n, n, prec] = {
  a_j = la_qr_apply_steps_rec(a_orig, cast(0, int64), j)
  template = diag(a_j)
  e_j = la_basis_n(j, cast(1.0, prec), template)
  col_j = matvec(a_j, e_j)
  masked_col = la_elementwise_mul_vec(col_j, la_mask_ge_j(j, template))
  norm_x = l2_norm_vec(masked_col)
  x_j = inner_product(masked_col, e_j)
  sign_xj = if gte(x_j, cast(0.0, prec)) then cast(1.0, prec) else cast(-1.0, prec)
  shift = la_basis_n(j, mul(sign_xj, norm_x), template)
  v = la_vec_add(masked_col, shift)
  norm_v = l2_norm_vec(v)
  safe_norm_v = if lt(norm_v, cast(1e-30, prec)) then cast(1.0, prec) else norm_v
  v_hat = scale_vec(v, cast(1.0, prec) |> div(safe_norm_v))
  qv = matvec(q_curr, v_hat)
  qv2 = scale_vec(qv, cast(2.0, prec))
  rank1_q = einsum("i,j->ij", qv2, v_hat)
  sub(q_curr, rank1_q)
}
def la_qr_build_r[n, prec: Float](a: tensor[n, n, prec], n_len: int64) -> tensor[n, n, prec] = fold(fn (a_acc, j) -> la_qr_hh_step_r(a_acc, j), a, cast(0, int64) |> range(n_len))
def la_qr_build_q[n, prec: Float](a: &tensor[n, n, prec], n_len: int64) -> tensor[n, n, prec] = {
  template = diag(a)
  q_init = la_identity_n(template)
  fold(fn (q_acc, j) -> la_qr_hh_step_q(copy(a), q_acc, j), q_init, cast(0, int64) |> range(n_len))
}
def qr_decompose[n, prec: Float](a: &tensor[n, n, prec]) -> (tensor[n, n, prec], tensor[n, n, prec]) = {
  n_len = len(to_list(diag(a)))
  r_mat = la_qr_build_r(copy(a), n_len)
  q_mat = la_qr_build_q(a, n_len)
  (q_mat, r_mat)
}
def la_lu_compact_step[n, prec: Float](lu: tensor[n, n, prec], j: int64) -> tensor[n, n, prec] = {
  template = diag(lu)
  e_j = la_basis_n(j, cast(1.0, prec), template)
  u_col_j = matvec(lu, e_j)
  u_jj = inner_product(u_col_j, e_j)
  inv_ujj = cast(1.0, prec) |> div(u_jj)
  m_col = scale_vec(u_col_j, inv_ujj)
  m_gt = la_elementwise_mul_vec(m_col, la_mask_gt_j(j, template))
  u_row_j_raw = vecmat(e_j, lu)
  u_row_j = la_elementwise_mul_vec(u_row_j_raw, la_mask_ge_j(j, template))
  rank1_u = einsum("i,j->ij", m_gt, u_row_j)
  lu_u = sub(lu, rank1_u)
  m_l = la_elementwise_mul_vec(m_col, la_mask_gt_j(j, template))
  col_update = einsum("i,j->ij", m_l, e_j)
  add(lu_u, col_update)
}
def la_lu_fwd_step[n, prec: Float](lu: tensor[n, n, prec], y_acc: tensor[n, prec], i: int64) -> tensor[n, prec] = {
  template = diag(lu)
  e_i = la_basis_n(i, cast(1.0, prec), template)
  l_row_i = vecmat(e_i, lu)
  ones = cast(0, int64) |> la_mask_ge_j(template)
  mask_ge_i = la_mask_ge_j(i, template)
  mask_lt_i = la_vec_sub(ones, mask_ge_i)
  l_left = la_elementwise_mul_vec(l_row_i, mask_lt_i)
  dot_val = inner_product(l_left, y_acc)
  dot_val |> neg |> la_vec_saxpy(y_acc, e_i)
}
def la_lu_bwd_step[n, prec: Float](lu: tensor[n, n, prec], x_acc: tensor[n, prec], i: int64, n_len_m1: int64) -> tensor[n, prec] = {
  template = diag(lu)
  i_rev = sub(n_len_m1, i)
  e_ir = la_basis_n(i_rev, cast(1.0, prec), template)
  u_row_ir = vecmat(e_ir, lu)
  mask_gt_ir = la_mask_gt_j(i_rev, template)
  u_right = la_elementwise_mul_vec(u_row_ir, mask_gt_ir)
  dot_off = inner_product(u_right, x_acc)
  u_ii = inner_product(u_row_ir, e_ir)
  x_ir = inner_product(x_acc, e_ir)
  x_new = x_ir |> sub(dot_off) |> div(u_ii)
  correction = sub(x_new, x_ir)
  la_vec_saxpy(correction, x_acc, e_ir)
}
def la_tridiag_fwd_diag[n, prec: Float](lower: tensor[n, prec], diag_in: tensor[n, prec], upper: tensor[n, prec], n_len: int64) -> tensor[n, prec] = {
  tpl = to_tensor(map(fn (v: prec) -> cast(0.0, prec), to_list(diag_in)))
  fold(fn (dacc, i) -> {
    e_i = la_basis_n(i, cast(1.0, prec), tpl)
    e_im1_diag = i |> sub(cast(1, int64)) |> la_basis_n(cast(1.0, prec), tpl)
    e_im1_upper = i |> sub(cast(1, int64)) |> la_basis_n(cast(1.0, prec), tpl)
    lower_i = inner_product(lower, e_i)
    diag_im1 = inner_product(dacc, e_im1_diag)
    upper_im1 = inner_product(upper, e_im1_upper)
    diag_i = inner_product(dacc, e_i)
    abs_d = if lt(diag_im1, cast(0.0, prec)) then neg(diag_im1) else diag_im1
    safe_d = if lt(abs_d, cast(1e-30, prec)) then cast(1.0, prec) else diag_im1
    w = div(lower_i, safe_d)
    new_diag_i = sub(diag_i, mul(w, upper_im1))
    corr_d = sub(new_diag_i, diag_i)
    la_vec_saxpy(corr_d, dacc, e_i)
  }, diag_in, cast(1, int64) |> range(n_len))
}
def la_tridiag_fwd_b[n, prec: Float](lower: tensor[n, prec], diag_f: tensor[n, prec], upper: tensor[n, prec], b_in: tensor[n, prec], n_len: int64) -> tensor[n, prec] = {
  tpl = to_tensor(map(fn (v: prec) -> cast(0.0, prec), to_list(b_in)))
  fold(fn (bacc, i) -> {
    e_i = la_basis_n(i, cast(1.0, prec), tpl)
    e_im1_diag = i |> sub(cast(1, int64)) |> la_basis_n(cast(1.0, prec), tpl)
    e_im1_b = i |> sub(cast(1, int64)) |> la_basis_n(cast(1.0, prec), tpl)
    lower_i = inner_product(lower, e_i)
    diag_im1 = inner_product(diag_f, e_im1_diag)
    b_im1 = inner_product(bacc, e_im1_b)
    b_i = inner_product(bacc, e_i)
    abs_d = if lt(diag_im1, cast(0.0, prec)) then neg(diag_im1) else diag_im1
    safe_d = if lt(abs_d, cast(1e-30, prec)) then cast(1.0, prec) else diag_im1
    w = div(lower_i, safe_d)
    new_b_i = sub(b_i, mul(w, b_im1))
    corr_b = sub(new_b_i, b_i)
    la_vec_saxpy(corr_b, bacc, e_i)
  }, b_in, cast(1, int64) |> range(n_len))
}
def la_tridiag_bwd[n, prec: Float](upper: tensor[n, prec], diag_f: tensor[n, prec], b_f: tensor[n, prec], n_len: int64, n_len_m1: int64) -> tensor[n, prec] = {
  tpl = to_tensor(map(fn (v: prec) -> cast(0.0, prec), to_list(diag_f)))
  x_init = tpl
  fold(fn (x_acc, j) -> {
    i = sub(n_len_m1, j)
    e_i = la_basis_n(i, cast(1.0, prec), tpl)
    b_i = inner_product(b_f, e_i)
    diag_i = inner_product(diag_f, e_i)
    upper_i = inner_product(upper, e_i)
    x_ip1 = inner_product(x_acc, i |> add(cast(1, int64)) |> la_basis_n(cast(1.0, prec), tpl))
    abs_di = if lt(diag_i, cast(0.0, prec)) then neg(diag_i) else diag_i
    safe_di = if lt(abs_di, cast(1e-30, prec)) then cast(1.0, prec) else diag_i
    is_last = eq(i, n_len_m1)
    rhs = if is_last then b_i else sub(b_i, mul(upper_i, x_ip1))
    x_i = div(rhs, safe_di)
    x_prev = inner_product(x_acc, e_i)
    corr = sub(x_i, x_prev)
    la_vec_saxpy(corr, x_acc, e_i)
  }, x_init, cast(0, int64) |> range(n_len))
}
def la_tridiag_solve[n, prec: Float](lower: tensor[n, prec], diag: tensor[n, prec], upper: tensor[n, prec], b: tensor[n, prec]) -> tensor[n, prec] = {
  tpl0 = diag
  n_len = tpl0 |> to_list |> len
  n_len_m1 = sub(n_len, cast(1, int64))
  diag_f = la_tridiag_fwd_diag(lower, diag, upper, n_len)
  b_f = la_tridiag_fwd_b(lower, diag_f, upper, b, n_len)
  la_tridiag_bwd(upper, diag_f, b_f, n_len, n_len_m1)
}
def lu_solve[n, prec: Float](a: tensor[n, n, prec], b: tensor[n, prec]) -> tensor[n, prec] = {
  template = diag(a)
  n_len = template |> to_list |> len
  n_len_m1 = sub(n_len, cast(1, int64))
  lu = fold(fn (lu_acc, j) -> la_lu_compact_step(lu_acc, j), a, cast(0, int64) |> range(n_len))
  lu_fwd = lu
  y = fold(fn (y_acc, i) -> la_lu_fwd_step(lu_fwd, y_acc, i), b, cast(0, int64) |> range(n_len))
  fold(fn (x_acc, i) -> la_lu_bwd_step(lu, x_acc, i, n_len_m1), y, cast(0, int64) |> range(n_len))
}
def la_svd_rot_g[n, prec: Float](g: tensor[n, n, prec], p: int64, q: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] = {
  ep = la_basis_n(p, cast(1.0, prec), tpl)
  eq = la_basis_n(q, cast(1.0, prec), tpl)
  gcp = matvec(g, ep)
  gcq = matvec(g, eq)
  gpp = inner_product(gcp, ep)
  gqq = inner_product(gcq, eq)
  gpq = inner_product(gcp, eq)
  absgpq = if lt(gpq, cast(0.0, prec)) then neg(gpq) else gpq
  safegpq = if lt(absgpq, cast(1e-30, prec)) then cast(1.0, prec) else gpq
  tauraw = div(sub(gpp, gqq), mul(cast(2.0, prec), safegpq))
  abstau = if lt(tauraw, cast(0.0, prec)) then neg(tauraw) else tauraw
  signtau = if lt(tauraw, cast(0.0, prec)) then cast(-1.0, prec) else cast(1.0, prec)
  traw = div(signtau, add(abstau, sqrt(add(cast(1.0, prec), mul(tauraw, tauraw)))))
  t = if lt(absgpq, cast(1e-30, prec)) then cast(0.0, prec) else traw
  c = div(cast(1.0, prec), sqrt(add(cast(1.0, prec), mul(t, t))))
  s = mul(t, c)
  cm1 = sub(c, cast(1.0, prec))
  dcp = la_vec_add(scale_vec(gcp, cm1), scale_vec(gcq, s))
  dcq = la_vec_add(scale_vec(gcp, neg(s)), scale_vec(gcq, cm1))
  gr = add(add(g, einsum("i,j->ij", dcp, ep)), einsum("i,j->ij", dcq, eq))
  rp = vecmat(ep, gr)
  rq = vecmat(eq, gr)
  drp = la_vec_add(scale_vec(rp, cm1), scale_vec(rq, s))
  drq = la_vec_add(scale_vec(rp, neg(s)), scale_vec(rq, cm1))
  add(add(gr, einsum("i,j->ij", ep, drp)), einsum("i,j->ij", eq, drq))
}
def la_svd_rot_v[n, prec: Float](v: tensor[n, n, prec], g: tensor[n, n, prec], p: int64, q: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] = {
  ep = la_basis_n(p, cast(1.0, prec), tpl)
  eq = la_basis_n(q, cast(1.0, prec), tpl)
  gcp = matvec(g, ep)
  gcq = matvec(g, eq)
  gpp = inner_product(gcp, ep)
  gqq = inner_product(gcq, eq)
  gpq = inner_product(gcp, eq)
  absgpq = if lt(gpq, cast(0.0, prec)) then neg(gpq) else gpq
  safegpq = if lt(absgpq, cast(1e-30, prec)) then cast(1.0, prec) else gpq
  tauraw = div(sub(gpp, gqq), mul(cast(2.0, prec), safegpq))
  abstau = if lt(tauraw, cast(0.0, prec)) then neg(tauraw) else tauraw
  signtau = if lt(tauraw, cast(0.0, prec)) then cast(-1.0, prec) else cast(1.0, prec)
  traw = div(signtau, add(abstau, sqrt(add(cast(1.0, prec), mul(tauraw, tauraw)))))
  t = if lt(absgpq, cast(1e-30, prec)) then cast(0.0, prec) else traw
  c = div(cast(1.0, prec), sqrt(add(cast(1.0, prec), mul(t, t))))
  s = mul(t, c)
  cm1 = sub(c, cast(1.0, prec))
  vcp = matvec(v, ep)
  vcq = matvec(v, eq)
  dvp = la_vec_add(scale_vec(vcp, cm1), scale_vec(vcq, s))
  dvq = la_vec_add(scale_vec(vcp, neg(s)), scale_vec(vcq, cm1))
  add(add(v, einsum("i,j->ij", dvp, ep)), einsum("i,j->ij", dvq, eq))
}
def la_svd_g_iq[n, prec: Float](g: tensor[n, n, prec], p: int64, q: int64, nlen: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] = if gte(q, nlen) then g else la_svd_g_iq(la_svd_rot_g(g, p, q, tpl), p, add(q, cast(1, int64)), nlen, tpl)
def la_svd_g_ip[n, prec: Float](g: tensor[n, n, prec], p: int64, nlen: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] = if gte(p, sub(nlen, cast(1, int64))) then g else la_svd_g_ip(la_svd_g_iq(g, p, add(p, cast(1, int64)), nlen, tpl), add(p, cast(1, int64)), nlen, tpl)
def la_svd_g_sw[n, prec: Float](g: tensor[n, n, prec], sw: int64, nsw: int64, nlen: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] = if gte(sw, nsw) then g else la_svd_g_sw(la_svd_g_ip(g, cast(0, int64), nlen, tpl), add(sw, cast(1, int64)), nsw, nlen, tpl)
def la_svd_g_replay_q[n, prec: Float](g: tensor[n, n, prec], p: int64, q: int64, qtarget: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] = if gte(q, qtarget) then g else la_svd_g_replay_q(la_svd_rot_g(g, p, q, tpl), p, add(q, cast(1, int64)), qtarget, tpl)
def la_svd_g_replay_p[n, prec: Float](g: tensor[n, n, prec], p: int64, ptarget: int64, nlen: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] = if gte(p, ptarget) then g else la_svd_g_replay_p(la_svd_g_iq(g, p, add(p, cast(1, int64)), nlen, tpl), add(p, cast(1, int64)), ptarget, nlen, tpl)
def la_svd_v_iq[n, prec: Float](v: tensor[n, n, prec], g_sw_init: tensor[n, n, prec], p: int64, q: int64, nlen: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] =
  if gte(q, nlen) then v else {
    g_at_pq = la_svd_g_replay_q(la_svd_g_replay_p(g_sw_init, cast(0, int64), p, nlen, tpl), p, add(p, cast(1, int64)), q, tpl)
    v2 = la_svd_rot_v(v, g_at_pq, p, q, tpl)
    la_svd_v_iq(v2, g_sw_init, p, add(q, cast(1, int64)), nlen, tpl)
  }
def la_svd_v_ip[n, prec: Float](v: tensor[n, n, prec], g_sw_init: tensor[n, n, prec], p: int64, nlen: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] = if gte(p, sub(nlen, cast(1, int64))) then v else la_svd_v_ip(la_svd_v_iq(v, g_sw_init, p, add(p, cast(1, int64)), nlen, tpl), g_sw_init, add(p, cast(1, int64)), nlen, tpl)
def la_svd_v_sw[n, prec: Float](v: tensor[n, n, prec], g0: tensor[n, n, prec], sw: int64, nsw: int64, nlen: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] =
  if gte(sw, nsw) then v else {
    g_sw_init = la_svd_g_sw(g0, cast(0, int64), sw, nlen, tpl)
    v2 = la_svd_v_ip(v, g_sw_init, cast(0, int64), nlen, tpl)
    la_svd_v_sw(v2, g0, add(sw, cast(1, int64)), nsw, nlen, tpl)
  }
def svd_n[n, prec: Float](a: &tensor[n, n, prec]) -> (tensor[n, n, prec], tensor[n, prec], tensor[n, n, prec]) = {
  svd_tpl = diag(a)
  svd_nlen = len(to_list(svd_tpl))
  svd_nsw = mul(cast(30, int64), svd_nlen)
  svd_g0 = gram(a)
  svd_gf = la_svd_g_sw(svd_g0, cast(0, int64), svd_nsw, svd_nlen, copy(svd_tpl))
  svd_gf2 = svd_gf
  svd_v0 = la_identity_n(svd_tpl)
  svd_vf = la_svd_v_sw(svd_v0, svd_g0, cast(0, int64), svd_nsw, svd_nlen, copy(svd_tpl))
  svd_tpl2 = svd_tpl
  svd_zsig = to_tensor(map(fn (x: prec) -> cast(0.0, prec), to_list(svd_tpl2)))
  sigma = fold(fn (acc, i) -> {
    svd_ei = la_basis_n(i, cast(1.0, prec), svd_tpl2)
    svd_gii = inner_product(matvec(svd_gf, svd_ei), svd_ei)
    svd_si = sqrt(if lt(svd_gii, cast(0.0, prec)) then cast(0.0, prec) else svd_gii)
    la_vec_saxpy(svd_si, acc, svd_ei)
  }, svd_zsig, range(cast(0, int64), svd_nlen))
  svd_vf2 = svd_vf
  svd_zu = la_zeros_mat_like(svd_gf2)
  u = fold(fn (acc, i) -> {
    svd_ei = la_basis_n(i, cast(1.0, prec), svd_tpl)
    svd_gii = inner_product(matvec(svd_gf2, svd_ei), svd_ei)
    svd_si = sqrt(if lt(svd_gii, cast(0.0, prec)) then cast(0.0, prec) else svd_gii)
    svd_safe = if lt(svd_si, cast(1e-30, prec)) then cast(1.0, prec) else svd_si
    svd_vi = matvec(svd_vf2, svd_ei)
    svd_avc = matvec(a, svd_vi)
    svd_uc = scale_vec(svd_avc, div(cast(1.0, prec), svd_safe))
    svd_oui = einsum("i,j->ij", svd_uc, svd_ei)
    add(acc, svd_oui)
  }, svd_zu, range(cast(0, int64), svd_nlen))
  vt = transpose(svd_vf)
  (u, sigma, vt)
}
def la_eig_rot_a[n, prec: Float](a: &tensor[n, n, prec], p: int64, q: int64, tpl: &tensor[n, prec]) -> tensor[n, n, prec] = {
  ep = la_basis_n(p, cast(1.0, prec), tpl)
  eq = la_basis_n(q, cast(1.0, prec), tpl)
  acp = matvec(a, ep)
  acq = matvec(a, eq)
  app = inner_product(acp, ep)
  aqq = inner_product(acq, eq)
  apq = inner_product(acp, eq)
  absapq = if lt(apq, cast(0.0, prec)) then neg(apq) else apq
  safeapq = if lt(absapq, cast(1e-30, prec)) then cast(1.0, prec) else apq
  tauraw = div(sub(app, aqq), mul(cast(2.0, prec), safeapq))
  abstau = if lt(tauraw, cast(0.0, prec)) then neg(tauraw) else tauraw
  signtau = if lt(tauraw, cast(0.0, prec)) then cast(-1.0, prec) else cast(1.0, prec)
  traw = div(signtau, add(abstau, sqrt(add(cast(1.0, prec), mul(tauraw, tauraw)))))
  t = if lt(absapq, cast(1e-30, prec)) then cast(0.0, prec) else traw
  c = div(cast(1.0, prec), sqrt(add(cast(1.0, prec), mul(t, t))))
  s = mul(t, c)
  cm1 = sub(c, cast(1.0, prec))
  dcp = la_vec_add(scale_vec(acp, cm1), scale_vec(acq, s))
  dcq = la_vec_add(scale_vec(acp, neg(s)), scale_vec(acq, cm1))
  ar = add(add(a, einsum("i,j->ij", dcp, ep)), einsum("i,j->ij", dcq, eq))
  rp = vecmat(ep, ar)
  rq = vecmat(eq, ar)
  drp = la_vec_add(scale_vec(rp, cm1), scale_vec(rq, s))
  drq = la_vec_add(scale_vec(rp, neg(s)), scale_vec(rq, cm1))
  add(add(ar, einsum("i,j->ij", ep, drp)), einsum("i,j->ij", eq, drq))
}
def la_eig_rot_q[n, prec: Float](q: &tensor[n, n, prec], a: &tensor[n, n, prec], p: int64, q_idx: int64, tpl: &tensor[n, prec]) -> tensor[n, n, prec] = {
  ep = la_basis_n(p, cast(1.0, prec), tpl)
  eq = la_basis_n(q_idx, cast(1.0, prec), tpl)
  acp = matvec(a, ep)
  acq = matvec(a, eq)
  app = inner_product(acp, ep)
  aqq = inner_product(acq, eq)
  apq = inner_product(acp, eq)
  absapq = if lt(apq, cast(0.0, prec)) then neg(apq) else apq
  safeapq = if lt(absapq, cast(1e-30, prec)) then cast(1.0, prec) else apq
  tauraw = div(sub(app, aqq), mul(cast(2.0, prec), safeapq))
  abstau = if lt(tauraw, cast(0.0, prec)) then neg(tauraw) else tauraw
  signtau = if lt(tauraw, cast(0.0, prec)) then cast(-1.0, prec) else cast(1.0, prec)
  traw = div(signtau, add(abstau, sqrt(add(cast(1.0, prec), mul(tauraw, tauraw)))))
  t = if lt(absapq, cast(1e-30, prec)) then cast(0.0, prec) else traw
  c = div(cast(1.0, prec), sqrt(add(cast(1.0, prec), mul(t, t))))
  s = mul(t, c)
  cm1 = sub(c, cast(1.0, prec))
  qcp = matvec(q, ep)
  qcq = matvec(q, eq)
  dvp = la_vec_add(scale_vec(qcp, cm1), scale_vec(qcq, s))
  dvq = la_vec_add(scale_vec(qcp, neg(s)), scale_vec(qcq, cm1))
  add(add(q, einsum("i,j->ij", dvp, ep)), einsum("i,j->ij", dvq, eq))
}
def la_eig_a_iq[n, prec: Float](a: tensor[n, n, prec], p: int64, q: int64, nlen: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] = if gte(q, nlen) then a else la_eig_a_iq(la_eig_rot_a(a, p, q, tpl), p, add(q, cast(1, int64)), nlen, tpl)
def la_eig_a_ip[n, prec: Float](a: tensor[n, n, prec], p: int64, nlen: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] = if gte(p, sub(nlen, cast(1, int64))) then a else la_eig_a_ip(la_eig_a_iq(a, p, add(p, cast(1, int64)), nlen, tpl), add(p, cast(1, int64)), nlen, tpl)
def la_eig_a_sw[n, prec: Float](a: tensor[n, n, prec], sw: int64, nsw: int64, nlen: int64, tpl: tensor[n, prec]) -> tensor[n, n, prec] = if gte(sw, nsw) then a else la_eig_a_sw(la_eig_a_ip(a, cast(0, int64), nlen, tpl), add(sw, cast(1, int64)), nsw, nlen, tpl)
def la_eig_aq_iq[n, prec: Float](a: &tensor[n, n, prec], q: tensor[n, n, prec], p: int64, q_idx: int64, nlen: int64, tpl: &tensor[n, prec]) -> tensor[n, n, prec] =
  if gte(q_idx, nlen) then q else {
    q2 = la_eig_rot_q(q, a, p, q_idx, tpl)
    a2 = la_eig_rot_a(a, p, q_idx, tpl)
    la_eig_aq_iq(a2, q2, p, add(q_idx, cast(1, int64)), nlen, tpl)
  }
def la_eig_aq_ip[n, prec: Float](a: &tensor[n, n, prec], q: tensor[n, n, prec], p: int64, nlen: int64, tpl: &tensor[n, prec]) -> tensor[n, n, prec] =
  if gte(p, sub(nlen, cast(1, int64))) then q else {
    q2 = la_eig_aq_iq(a, q, p, add(p, cast(1, int64)), nlen, tpl)
    a2 = la_eig_a_iq(copy(a), p, add(p, cast(1, int64)), nlen, copy(tpl))
    la_eig_aq_ip(a2, q2, add(p, cast(1, int64)), nlen, tpl)
  }
def la_eig_aq_sw[n, prec: Float](a: &tensor[n, n, prec], q: tensor[n, n, prec], sw: int64, nsw: int64, nlen: int64, tpl: &tensor[n, prec]) -> tensor[n, n, prec] =
  if gte(sw, nsw) then q else {
    q2 = la_eig_aq_ip(a, q, cast(0, int64), nlen, tpl)
    a2 = la_eig_a_ip(copy(a), cast(0, int64), nlen, copy(tpl))
    la_eig_aq_sw(a2, q2, add(sw, cast(1, int64)), nsw, nlen, tpl)
  }
def eig_n[n, prec: Float](a: &tensor[n, n, prec]) -> (tensor[n, prec], tensor[n, n, prec]) = {
  eig_tpl = diag(a)
  eig_nlen = len(to_list(eig_tpl))
  eig_nsw = mul(cast(30, int64), eig_nlen)
  eig_q0 = la_identity_n(eig_tpl)
  eig_af = la_eig_a_sw(copy(a), cast(0, int64), eig_nsw, eig_nlen, copy(eig_tpl))
  eig_qf = la_eig_aq_sw(a, eig_q0, cast(0, int64), eig_nsw, eig_nlen, eig_tpl)
  eig_tpl2 = eig_tpl
  eig_zlam = to_tensor(map(fn (x: prec) -> cast(0.0, prec), to_list(eig_tpl2)))
  eigenvalues = fold(fn (acc, i) -> {
    eig_ei = la_basis_n(i, cast(1.0, prec), eig_tpl2)
    eig_aii = inner_product(matvec(eig_af, eig_ei), eig_ei)
    la_vec_saxpy(eig_aii, acc, eig_ei)
  }, eig_zlam, range(cast(0, int64), eig_nlen))
  (eigenvalues, eig_qf)
}
def la_chol_col_update[n, prec: Float](a_mat: tensor[n, n, prec], l_prev: tensor[n, n, prec], j: int64) -> tensor[n, n, prec] = {
  diag_of_l = diag(l_prev)
  e_j = la_basis_n(j, cast(1.0, prec), diag_of_l)
  col_a = matvec(a_mat, e_j)
  row_j_of_l = vecmat(e_j, l_prev)
  partial = matvec(l_prev, row_j_of_l)
  c = la_vec_sub(col_a, partial)
  c_j = inner_product(c, e_j)
  d = sqrt(c_j)
  inv_d = cast(1.0, prec) |> div(d)
  scaled = scale_vec(c, inv_d)
  mask = la_mask_ge_j(j, c)
  new_col = la_elementwise_mul_vec(scaled, mask)
  outer_add = einsum("i,j->ij", new_col, e_j)
  add(l_prev, outer_add)
}
def cholesky_n[n, prec: Float](a: &tensor[n, n, prec]) -> tensor[n, n, prec] = {
  l_init = la_zeros_mat_like(a)
  n_len = len(to_list(diag(a)))
  idxs = cast(0, int64) |> range(n_len)
  fold(fn (l, j) -> la_chol_col_update(copy(a), l, j), l_init, idxs)
}
def det_3x3[prec: Float](a: &tensor[3, 3, prec]) -> prec = {
  t = trace_scalar(a)
  a2 = matmul(a, a)
  t2 = trace_scalar(a2)
  a3 = matmul(a2, a)
  t3 = trace_scalar(a3)
  three = cast(3.0, prec)
  two = cast(2.0, prec)
  six = cast(6.0, prec)
  t_cubed = mul(t, mul(t, t))
  term1 = t_cubed
  term2 = mul(three, mul(t, t2))
  term3 = mul(two, t3)
  div(add(sub(term1, term2), term3), six)
}
def la_nan_val[prec: Float]() -> prec = cast(0.0, prec) |> div(cast(0.0, prec))
def la_basis2[prec: Float](k: int64, s: prec) -> tensor[2, prec] = to_tensor(map(fn (i: int64) -> if eq(i, k) then s else cast(0.0, prec), range(cast(0, int64), cast(2, int64))))
def la_basis3[prec: Float](k: int64, s: prec) -> tensor[3, prec] = to_tensor(map(fn (i: int64) -> if eq(i, k) then s else cast(0.0, prec), range(cast(0, int64), cast(3, int64))))
def la_scaled_eye_2[prec: Float](s: prec) -> tensor[2, 2, prec] = {
  e1 = cast(0, int64) |> la_basis2(s)
  e1b = cast(0, int64) |> la_basis2(cast(1.0, prec))
  e2 = cast(1, int64) |> la_basis2(s)
  e2b = cast(1, int64) |> la_basis2(cast(1.0, prec))
  o1 = einsum("i,j->ij", e1, e1b)
  o2 = einsum("i,j->ij", e2, e2b)
  add(o1, o2)
}
def la_scaled_eye_3[prec: Float](s: prec) -> tensor[3, 3, prec] = {
  e1 = cast(0, int64) |> la_basis3(s)
  e1b = cast(0, int64) |> la_basis3(cast(1.0, prec))
  e2 = cast(1, int64) |> la_basis3(s)
  e2b = cast(1, int64) |> la_basis3(cast(1.0, prec))
  e3 = cast(2, int64) |> la_basis3(s)
  e3b = cast(2, int64) |> la_basis3(cast(1.0, prec))
  o1 = einsum("i,j->ij", e1, e1b)
  o2 = einsum("i,j->ij", e2, e2b)
  o3 = einsum("i,j->ij", e3, e3b)
  o1 |> add(o2) |> add(o3)
}
def la_scale_mat_2x2[prec: Float](s: prec, m: &tensor[2, 2, prec]) -> tensor[2, 2, prec] = {
  diag_s = la_scaled_eye_2(s)
  matmul(diag_s, m)
}
def la_scale_mat_3x3[prec: Float](s: prec, m: &tensor[3, 3, prec]) -> tensor[3, 3, prec] = {
  diag_s = la_scaled_eye_3(s)
  matmul(diag_s, m)
}
def la_mat_sub_2x2[prec: Float](a: &tensor[2, 2, prec], b: &tensor[2, 2, prec]) -> tensor[2, 2, prec] = {
  neg_one = cast(-1.0, prec) |> la_scaled_eye_2
  nb = matmul(neg_one, b)
  add(a, nb)
}
def la_mat_sub_3x3[prec: Float](a: &tensor[3, 3, prec], b: &tensor[3, 3, prec]) -> tensor[3, 3, prec] = {
  neg_one = cast(-1.0, prec) |> la_scaled_eye_3
  nb = matmul(neg_one, b)
  add(a, nb)
}
def inv_2x2[prec: Float](a: &tensor[2, 2, prec]) -> tensor[2, 2, prec] = {
  t = trace_scalar(a)
  det = det_2x2(a)
  zero_f = cast(0.0, prec)
  one_f = cast(1.0, prec)
  abs_det = if lt(det, zero_f) then neg(det) else det
  eps = cast(1e-30, prec)
  bad = lt(abs_det, eps)
  nan_v = la_nan_val()
  det_safe = if bad then one_f else det
  inv_det = div(one_f, det_safe)
  tI = la_scaled_eye_2(t)
  core = la_mat_sub_2x2(tI, a)
  result = la_scale_mat_2x2(inv_det, core)
  if bad then la_scaled_eye_2(nan_v) else result
}
def inv_3x3[prec: Float](a: &tensor[3, 3, prec]) -> tensor[3, 3, prec] = {
  t = trace_scalar(a)
  a2 = matmul(a, a)
  t2 = trace_scalar(a2)
  det = det_3x3(a)
  half = cast(0.5, prec)
  zero_f = cast(0.0, prec)
  one_f = cast(1.0, prec)
  abs_det = if lt(det, zero_f) then neg(det) else det
  eps = cast(1e-30, prec)
  bad = lt(abs_det, eps)
  nan_v = la_nan_val()
  det_safe = if bad then one_f else det
  c1 = mul(half, t |> mul(t) |> sub(t2))
  tA = la_scale_mat_3x3(t, a)
  c1I = la_scaled_eye_3(c1)
  step1 = la_mat_sub_3x3(a2, tA)
  step2 = add(step1, c1I)
  inv_det = div(one_f, det_safe)
  result = la_scale_mat_3x3(inv_det, step2)
  if bad then la_scaled_eye_3(nan_v) else result
}
def solve_2x2[prec: Float](a: &tensor[2, 2, prec], b: &tensor[2, prec]) -> tensor[2, prec] = {
  ai = inv_2x2(a)
  matvec(ai, b)
}
def solve_3x3[prec: Float](a: &tensor[3, 3, prec], b: &tensor[3, prec]) -> tensor[3, prec] = {
  ai = inv_3x3(a)
  matvec(ai, b)
}
def eig_2x2_real[prec: Float](a: &tensor[2, 2, prec]) -> (prec, prec) = {
  t = trace_scalar(a)
  det = det_2x2(a)
  half = cast(0.5, prec)
  t_half = mul(half, t)
  disc = t_half |> mul(t_half) |> sub(det)
  neg_one = cast(-1.0, prec)
  disc_safe = if lt(disc, cast(0.0, prec)) then neg_one else disc
  rt = sqrt(disc_safe)
  lam1 = add(t_half, rt)
  lam2 = sub(t_half, rt)
  nan_v = la_nan_val()
  if lt(disc, cast(0.0, prec)) then (nan_v, nan_v) else (lam1, lam2)
}
def la_mat_entry_2[prec: Float](a: &tensor[2, 2, prec], i: int64, j: int64) -> prec = {
  e_j = la_basis2(j, cast(1.0, prec))
  col = matvec(a, e_j)
  e_i = la_basis2(i, cast(1.0, prec))
  inner_product(col, e_i)
}
def la_mat_entry_3[prec: Float](a: &tensor[3, 3, prec], i: int64, j: int64) -> prec = {
  e_j = la_basis3(j, cast(1.0, prec))
  col = matvec(a, e_j)
  e_i = la_basis3(i, cast(1.0, prec))
  inner_product(col, e_i)
}
def cholesky_2x2[prec: Float](a: &tensor[2, 2, prec]) -> tensor[2, 2, prec] = {
  a00 = la_mat_entry_2(a, cast(0, int64), cast(0, int64))
  a01 = la_mat_entry_2(a, cast(0, int64), cast(1, int64))
  a10 = la_mat_entry_2(a, cast(1, int64), cast(0, int64))
  a11 = la_mat_entry_2(a, cast(1, int64), cast(1, int64))
  zero_f = cast(0.0, prec)
  one_f = cast(1.0, prec)
  asym_diff = sub(a01, a10)
  asym_abs = if lt(asym_diff, zero_f) then neg(asym_diff) else asym_diff
  sym_eps = cast(1e-6, prec)
  not_sym = gt(asym_abs, sym_eps)
  bad_a00 = lte(a00, zero_f)
  a00_safe = if bad_a00 then one_f else a00
  l00 = sqrt(a00_safe)
  l10 = div(a10, l00)
  rem = sub(a11, mul(l10, l10))
  bad = bad_a00 |> or(lte(rem, zero_f)) |> or(not_sym)
  rem_safe = if bad then one_f else rem
  l11 = sqrt(rem_safe)
  nan_v = la_nan_val()
  r00 = if bad then nan_v else l00
  r01 = if bad then nan_v else zero_f
  r10 = if bad then nan_v else l10
  r11 = if bad then nan_v else l11
  b0 = cast(0, int64) |> la_basis2(cast(1.0, prec))
  b0b = cast(0, int64) |> la_basis2(cast(1.0, prec))
  b1 = cast(1, int64) |> la_basis2(cast(1.0, prec))
  b1b = cast(1, int64) |> la_basis2(cast(1.0, prec))
  row0 = cast(0, int64) |> la_basis2(r00)
  row0_p1 = cast(1, int64) |> la_basis2(r01)
  row1 = cast(0, int64) |> la_basis2(r10)
  row1_p1 = cast(1, int64) |> la_basis2(r11)
  m00 = einsum("i,j->ij", b0, row0)
  m01 = einsum("i,j->ij", b0b, row0_p1)
  m10 = einsum("i,j->ij", b1, row1)
  m11 = einsum("i,j->ij", b1b, row1_p1)
  m00 |> add(m01) |> add(add(m10, m11))
}
