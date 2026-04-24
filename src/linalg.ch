module Nautilus.LinAlg
export (
  transpose, matmul_wrap, gram, aat,
  diag, trace_mat, trace_scalar,
  l2_norm_vec, inner_product, frobenius_sq, frobenius_norm,
  scale_vec,
  matvec, vecmat,
  det_2x2, det_3x3,
  la_vec_add, la_vec_sub, la_vec_saxpy,
  cg_solve,
  inv_2x2, inv_3x3, solve_2x2, solve_3x3,
  eig_2x2_real, cholesky_2x2,
  cholesky_n,
  lu_solve,
  qr_decompose,
  svd_n,
  eig_n
)

def transpose[m, n](a: tensor[m, n, f32]) -> tensor[n, m, f32] = permute(a, 1, 0)

def matmul_wrap[m, k, n](a: tensor[m, k, f32], b: tensor[k, n, f32]) -> tensor[m, n, f32] = matmul(a, b)

def gram[m, n](a: tensor[m, n, f32]) -> tensor[n, n, f32] = {
  at = permute(copy(a), 1, 0)
  matmul(at, a)
}

def aat[m, n](a: tensor[m, n, f32]) -> tensor[m, m, f32] = {
  at = permute(copy(a), 1, 0)
  matmul(a, at)
}

def diag[n](a: tensor[n, n, f32]) -> tensor[n, f32] = diagonal(a, 0, 1)

def trace_mat[n](a: tensor[n, n, f32]) -> tensor[f32] = trace(a, 0, 1)

def trace_scalar[n](a: tensor[n, n, f32]) -> f32 = {
  d = diagonal(a, 0, 1)
  fold(fn (acc: f32, x: f32) -> add(acc, x), cast(0.0, f32), to_list(d))
}

def l2_norm_vec[n](v: tensor[n, f32]) -> f32 = {
  s = fold(fn (acc: f32, x: f32) -> add(acc, mul(x, x)), cast(0.0, f32), to_list(v))
  sqrt(s)
}

def inner_product[n](a: tensor[n, f32], b: tensor[n, f32]) -> f32 = {
  zipped = zip(to_list(a), to_list(b))
  fold(fn (acc: f32, pair: (f32, f32)) -> {
    x = pair.0
    y = pair.1
    add(acc, mul(x, y))
  }, cast(0.0, f32), zipped)
}

def frobenius_sq[m, n](a: tensor[m, n, f32]) -> f32 = {
  rows = to_list(sum(mul(copy(a), a), 1))
  fold(fn (acc: f32, x: f32) -> add(acc, x), cast(0.0, f32), rows)
}

def frobenius_norm[m, n](a: tensor[m, n, f32]) -> f32 = {
  rows = to_list(sum(mul(copy(a), a), 1))
  s = fold(fn (acc: f32, x: f32) -> add(acc, x), cast(0.0, f32), rows)
  sqrt(s)
}

def scale_vec[n](v: tensor[n, f32], s: f32) -> tensor[n, f32] =
  to_tensor(map(fn (x: f32) -> mul(s, x), to_list(v)))

def matvec[m, n](a: tensor[m, n, f32], v: tensor[n, f32]) -> tensor[m, f32] =
  einsum("ij,j->i", a, v)

def vecmat[m, n](v: tensor[m, f32], a: tensor[m, n, f32]) -> tensor[n, f32] =
  einsum("i,ij->j", v, a)

def det_2x2(a: tensor[2, 2, f32]) -> f32 = {
  t = trace_scalar(copy(a))
  a2 = matmul(copy(a), copy(a))
  t2 = trace_scalar(a2)
  half = cast(0.5, f32)
  mul(half, sub(mul(t, t), t2))
}

def la_vec_add[n](a: tensor[n, f32], b: tensor[n, f32]) -> tensor[n, f32] =
  to_tensor(map(fn (pair: (f32, f32)) -> add(pair.0, pair.1),
                  zip(to_list(a), to_list(b))))

def la_vec_sub[n](a: tensor[n, f32], b: tensor[n, f32]) -> tensor[n, f32] =
  to_tensor(map(fn (pair: (f32, f32)) -> sub(pair.0, pair.1),
                  zip(to_list(a), to_list(b))))

def la_vec_saxpy[n](alpha: f32, x: tensor[n, f32], y: tensor[n, f32]) -> tensor[n, f32] =
  to_tensor(map(fn (pair: (f32, f32)) -> add(pair.0, mul(alpha, pair.1)),
                  zip(to_list(x), to_list(y))))

def cg_step_rec[n](
  a_mat: tensor[n, n, f32],
  x: tensor[n, f32],
  r: tensor[n, f32],
  p: tensor[n, f32],
  rs_old: f32,
  tol: f32,
  iters: int64
) -> tensor[n, f32] = {
  zero_i = cast(0, int64)
  one_i = cast(1, int64)
  if lte(iters, zero_i) then x
  else if lt(rs_old, tol) then x
  else {
    ap = matvec(copy(a_mat), copy(p))
    pap = inner_product(copy(p), copy(ap))
    alpha = div(rs_old, pap)
    x_next = la_vec_saxpy(alpha, x, copy(p))
    neg_alpha = neg(alpha)
    r_next = la_vec_saxpy(neg_alpha, r, ap)
    rs_new = inner_product(copy(r_next), copy(r_next))
    beta = div(rs_new, rs_old)
    p_next = la_vec_saxpy(beta, copy(r_next), p)
    cg_step_rec(a_mat, x_next, r_next, p_next, rs_new, tol, sub(iters, one_i))
  }
}

def cg_solve[n](
  a_mat: tensor[n, n, f32],
  b: tensor[n, f32],
  x0: tensor[n, f32],
  tol: f32,
  max_iters: int64
) -> tensor[n, f32] = {
  ax0 = matvec(copy(a_mat), copy(x0))
  r0 = la_vec_sub(b, ax0)
  p0 = la_vec_add(copy(r0), to_tensor(map(fn (x: f32) -> cast(0.0, f32), to_list(copy(r0)))))
  rs0 = inner_product(copy(r0), copy(r0))
  cg_step_rec(a_mat, x0, r0, p0, rs0, tol, max_iters)
}

def la_zeros_mat_like[n](a: tensor[n, n, f32]) -> tensor[n, n, f32] = sub(copy(a), a)

def la_basis_n_f32[n](k: int64, s: f32, template: tensor[n, f32]) -> tensor[n, f32] = {
  items_len = len(to_list(copy(template)))
  idxs = range(cast(0, int64), items_len)
  to_tensor(map(fn (i: int64) -> if eq(i, k) then s else cast(0.0, f32), idxs))
}

def la_mask_ge_j_f32[n](j: int64, template: tensor[n, f32]) -> tensor[n, f32] = {
  items_len = len(to_list(copy(template)))
  idxs = range(cast(0, int64), items_len)
  to_tensor(map(fn (i: int64) -> if gte(i, j) then cast(1.0, f32) else cast(0.0, f32), idxs))
}

def la_mask_gt_j_f32[n](j: int64, template: tensor[n, f32]) -> tensor[n, f32] = {
  items_len = len(to_list(copy(template)))
  idxs = range(cast(0, int64), items_len)
  to_tensor(map(fn (i: int64) -> if gt(i, j) then cast(1.0, f32) else cast(0.0, f32), idxs))
}

def la_elementwise_mul_vec[n](a: tensor[n, f32], b: tensor[n, f32]) -> tensor[n, f32] =
  to_tensor(map(fn (pair: (f32, f32)) -> mul(pair.0, pair.1),
                zip(to_list(a), to_list(b))))

def la_identity_n[n](template: tensor[n, f32]) -> tensor[n, n, f32] = {
  n_len = len(to_list(copy(template)))
  outer = einsum("i,j->ij", copy(template), copy(template))
  zero_mat = la_zeros_mat_like(outer)
  fold(
    fn (acc: tensor[n, n, f32], i: int64) -> {
      e_i = la_basis_n_f32(i, cast(1.0, f32), copy(template))
      outer_diag = einsum("i,j->ij", copy(e_i), e_i)
      add(acc, outer_diag)
    },
    zero_mat, range(cast(0, int64), n_len))
}

def la_qr_hh_step_r[n](a_curr: tensor[n, n, f32], j: int64) -> tensor[n, n, f32] = {
  template = diag(copy(a_curr))
  e_j = la_basis_n_f32(j, cast(1.0, f32), copy(template))
  col_j = matvec(copy(a_curr), copy(e_j))
  masked_col = la_elementwise_mul_vec(col_j, la_mask_ge_j_f32(j, copy(template)))
  norm_x = l2_norm_vec(copy(masked_col))
  x_j = inner_product(copy(masked_col), e_j)
  sign_xj = if gte(x_j, cast(0.0, f32)) then cast(1.0, f32) else cast(-1.0, f32)
  shift = la_basis_n_f32(j, mul(sign_xj, norm_x), template)
  v = la_vec_add(masked_col, shift)
  norm_v = l2_norm_vec(copy(v))
  safe_norm_v = if lt(norm_v, cast(1.0e-30, f32)) then cast(1.0, f32) else norm_v
  v_hat = scale_vec(v, div(cast(1.0, f32), safe_norm_v))
  vt_A = vecmat(copy(v_hat), copy(a_curr))
  rank1 = einsum("i,j->ij", scale_vec(copy(v_hat), cast(2.0, f32)), vt_A)
  sub(a_curr, rank1)
}

def la_qr_apply_steps_rec[n](a: tensor[n, n, f32], k: int64, target: int64) -> tensor[n, n, f32] =
  if gte(k, target) then a
  else la_qr_apply_steps_rec(la_qr_hh_step_r(a, k), add(k, cast(1, int64)), target)

def la_qr_hh_step_q[n](a_orig: tensor[n, n, f32], q_curr: tensor[n, n, f32], j: int64) -> tensor[n, n, f32] = {
  a_j = la_qr_apply_steps_rec(a_orig, cast(0, int64), j)
  template = diag(copy(a_j))
  e_j = la_basis_n_f32(j, cast(1.0, f32), copy(template))
  col_j = matvec(a_j, copy(e_j))
  masked_col = la_elementwise_mul_vec(col_j, la_mask_ge_j_f32(j, copy(template)))
  norm_x = l2_norm_vec(copy(masked_col))
  x_j = inner_product(copy(masked_col), e_j)
  sign_xj = if gte(x_j, cast(0.0, f32)) then cast(1.0, f32) else cast(-1.0, f32)
  shift = la_basis_n_f32(j, mul(sign_xj, norm_x), template)
  v = la_vec_add(masked_col, shift)
  norm_v = l2_norm_vec(copy(v))
  safe_norm_v = if lt(norm_v, cast(1.0e-30, f32)) then cast(1.0, f32) else norm_v
  v_hat = scale_vec(v, div(cast(1.0, f32), safe_norm_v))
  qv = matvec(copy(q_curr), copy(v_hat))
  qv2 = scale_vec(qv, cast(2.0, f32))
  rank1_q = einsum("i,j->ij", qv2, v_hat)
  sub(q_curr, rank1_q)
}

def la_qr_build_r[n](a: tensor[n, n, f32], n_len: int64) -> tensor[n, n, f32] =
  fold(
    fn (a_acc: tensor[n, n, f32], j: int64) -> la_qr_hh_step_r(a_acc, j),
    a, range(cast(0, int64), n_len))

def la_qr_build_q[n](a: tensor[n, n, f32], n_len: int64) -> tensor[n, n, f32] = {
  template = diag(copy(a))
  q_init = la_identity_n(template)
  fold(
    fn (q_acc: tensor[n, n, f32], j: int64) -> la_qr_hh_step_q(copy(a), q_acc, j),
    q_init, range(cast(0, int64), n_len))
}

def qr_decompose[n](a: tensor[n, n, f32]) -> (tensor[n, n, f32], tensor[n, n, f32]) = {
  n_len = len(to_list(diag(copy(a))))
  r_mat = la_qr_build_r(copy(a), n_len)
  q_mat = la_qr_build_q(a, n_len)
  (q_mat, r_mat)
}

def la_lu_compact_step[n](
  lu: tensor[n, n, f32],
  j: int64
) -> tensor[n, n, f32] = {
  template = diag(copy(lu))
  e_j = la_basis_n_f32(j, cast(1.0, f32), copy(template))
  u_col_j = matvec(copy(lu), copy(e_j))
  u_jj = inner_product(copy(u_col_j), copy(e_j))
  inv_ujj = div(cast(1.0, f32), u_jj)
  m_col = scale_vec(copy(u_col_j), inv_ujj)
  m_gt = la_elementwise_mul_vec(copy(m_col), la_mask_gt_j_f32(j, copy(template)))
  u_row_j_raw = vecmat(copy(e_j), copy(lu))
  u_row_j = la_elementwise_mul_vec(u_row_j_raw, la_mask_ge_j_f32(j, copy(template)))
  rank1_u = einsum("i,j->ij", copy(m_gt), copy(u_row_j))
  lu_u = sub(lu, rank1_u)
  m_l = la_elementwise_mul_vec(m_col, la_mask_gt_j_f32(j, template))
  col_update = einsum("i,j->ij", m_l, e_j)
  add(lu_u, col_update)
}

def la_lu_fwd_step[n](
  lu: tensor[n, n, f32],
  y_acc: tensor[n, f32],
  i: int64
) -> tensor[n, f32] = {
  template = diag(copy(lu))
  e_i = la_basis_n_f32(i, cast(1.0, f32), copy(template))
  l_row_i = vecmat(copy(e_i), copy(lu))
  ones = la_mask_ge_j_f32(cast(0, int64), copy(template))
  mask_ge_i = la_mask_ge_j_f32(i, template)
  mask_lt_i = la_vec_sub(ones, mask_ge_i)
  l_left = la_elementwise_mul_vec(l_row_i, mask_lt_i)
  dot_val = inner_product(l_left, copy(y_acc))
  la_vec_saxpy(neg(dot_val), y_acc, e_i)
}

def la_lu_bwd_step[n](
  lu: tensor[n, n, f32],
  x_acc: tensor[n, f32],
  i: int64,
  n_len_m1: int64
) -> tensor[n, f32] = {
  template = diag(copy(lu))
  i_rev = sub(n_len_m1, i)
  e_ir = la_basis_n_f32(i_rev, cast(1.0, f32), copy(template))
  u_row_ir = vecmat(copy(e_ir), copy(lu))
  mask_gt_ir = la_mask_gt_j_f32(i_rev, copy(template))
  u_right = la_elementwise_mul_vec(copy(u_row_ir), mask_gt_ir)
  dot_off = inner_product(u_right, copy(x_acc))
  u_ii = inner_product(u_row_ir, copy(e_ir))
  x_ir = inner_product(copy(x_acc), copy(e_ir))
  x_new = div(sub(x_ir, dot_off), u_ii)
  correction = sub(x_new, x_ir)
  la_vec_saxpy(correction, x_acc, e_ir)
}

-- Thomas algorithm O(n) tridiagonal solve (INTERNAL — do not export).
-- Convention: lower[0] unused, upper[n-1] unused.
-- Forward-eliminate the diagonal; captures lower/upper/diag_prev via closure.
def la_tridiag_fwd_diag[n](
  lower: tensor[n, f32],
  diag_in: tensor[n, f32],
  upper: tensor[n, f32],
  n_len: int64
) -> tensor[n, f32] = {
  tpl = to_tensor(map(fn (v: f32) -> cast(0.0, f32), to_list(copy(diag_in))))
  fold(
    fn (dacc: tensor[n, f32], i: int64) -> {
      e_i = la_basis_n_f32(i, cast(1.0, f32), copy(tpl))
      e_im1 = la_basis_n_f32(sub(i, cast(1, int64)), cast(1.0, f32), copy(tpl))
      lower_i = inner_product(copy(lower), copy(e_i))
      diag_im1 = inner_product(copy(dacc), copy(e_im1))
      upper_im1 = inner_product(copy(upper), copy(e_im1))
      diag_i = inner_product(copy(dacc), copy(e_i))
      abs_d = if lt(diag_im1, cast(0.0, f32)) then neg(diag_im1) else diag_im1
      safe_d = if lt(abs_d, cast(1.0e-30, f32)) then cast(1.0, f32) else diag_im1
      w = div(lower_i, safe_d)
      new_diag_i = sub(diag_i, mul(w, upper_im1))
      corr_d = sub(new_diag_i, diag_i)
      la_vec_saxpy(corr_d, dacc, e_i)
    },
    diag_in, range(cast(1, int64), n_len))
}

-- Forward-eliminate the rhs; requires the updated diagonal at each step.
def la_tridiag_fwd_b[n](
  lower: tensor[n, f32],
  diag_f: tensor[n, f32],
  upper: tensor[n, f32],
  b_in: tensor[n, f32],
  n_len: int64
) -> tensor[n, f32] = {
  tpl = to_tensor(map(fn (v: f32) -> cast(0.0, f32), to_list(copy(b_in))))
  fold(
    fn (bacc: tensor[n, f32], i: int64) -> {
      e_i = la_basis_n_f32(i, cast(1.0, f32), copy(tpl))
      e_im1 = la_basis_n_f32(sub(i, cast(1, int64)), cast(1.0, f32), copy(tpl))
      lower_i = inner_product(copy(lower), copy(e_i))
      diag_im1 = inner_product(copy(diag_f), copy(e_im1))
      b_im1 = inner_product(copy(bacc), copy(e_im1))
      b_i = inner_product(copy(bacc), copy(e_i))
      abs_d = if lt(diag_im1, cast(0.0, f32)) then neg(diag_im1) else diag_im1
      safe_d = if lt(abs_d, cast(1.0e-30, f32)) then cast(1.0, f32) else diag_im1
      w = div(lower_i, safe_d)
      new_b_i = sub(b_i, mul(w, b_im1))
      corr_b = sub(new_b_i, b_i)
      la_vec_saxpy(corr_b, bacc, e_i)
    },
    b_in, range(cast(1, int64), n_len))
}

def la_tridiag_bwd[n](
  upper: tensor[n, f32],
  diag_f: tensor[n, f32],
  b_f: tensor[n, f32],
  n_len: int64,
  n_len_m1: int64
) -> tensor[n, f32] = {
  tpl = to_tensor(map(fn (v: f32) -> cast(0.0, f32), to_list(copy(diag_f))))
  x_init = copy(tpl)
  fold(
    fn (x_acc: tensor[n, f32], j: int64) -> {
      i = sub(n_len_m1, j)
      e_i = la_basis_n_f32(i, cast(1.0, f32), copy(tpl))
      b_i = inner_product(copy(b_f), copy(e_i))
      diag_i = inner_product(copy(diag_f), copy(e_i))
      upper_i = inner_product(copy(upper), copy(e_i))
      x_ip1 = inner_product(copy(x_acc), la_basis_n_f32(add(i, cast(1, int64)), cast(1.0, f32), copy(tpl)))
      abs_di = if lt(diag_i, cast(0.0, f32)) then neg(diag_i) else diag_i
      safe_di = if lt(abs_di, cast(1.0e-30, f32)) then cast(1.0, f32) else diag_i
      is_last = eq(i, n_len_m1)
      rhs = if is_last then b_i else sub(b_i, mul(upper_i, x_ip1))
      x_i = div(rhs, safe_di)
      x_prev = inner_product(copy(x_acc), copy(e_i))
      corr = sub(x_i, x_prev)
      la_vec_saxpy(corr, x_acc, e_i)
    },
    x_init, range(cast(0, int64), n_len))
}

def la_tridiag_solve[n](
  lower: tensor[n, f32],
  diag: tensor[n, f32],
  upper: tensor[n, f32],
  b: tensor[n, f32]
) -> tensor[n, f32] = {
  tpl0 = copy(diag)
  n_len = len(to_list(tpl0))
  n_len_m1 = sub(n_len, cast(1, int64))
  diag_f = la_tridiag_fwd_diag(copy(lower), diag, copy(upper), n_len)
  b_f = la_tridiag_fwd_b(lower, copy(diag_f), copy(upper), b, n_len)
  la_tridiag_bwd(upper, diag_f, b_f, n_len, n_len_m1)
}

def lu_solve[n](a: tensor[n, n, f32], b: tensor[n, f32]) -> tensor[n, f32] = {
  template = diag(copy(a))
  n_len = len(to_list(copy(template)))
  n_len_m1 = sub(n_len, cast(1, int64))
  lu = fold(
    fn (lu_acc: tensor[n, n, f32], j: int64) -> la_lu_compact_step(lu_acc, j),
    a,
    range(cast(0, int64), n_len))
  lu_fwd = copy(lu)
  y = fold(
    fn (y_acc: tensor[n, f32], i: int64) -> la_lu_fwd_step(copy(lu_fwd), y_acc, i),
    b, range(cast(0, int64), n_len))
  fold(
    fn (x_acc: tensor[n, f32], i: int64) -> la_lu_bwd_step(copy(lu), x_acc, i, n_len_m1),
    y, range(cast(0, int64), n_len))
}

def la_svd_rot_g[n](g: tensor[n, n, f32], p: int64, q: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] = {
  ep = la_basis_n_f32(p, cast(1.0, f32), copy(tpl))
  eq = la_basis_n_f32(q, cast(1.0, f32), tpl)
  gcp = matvec(copy(g), copy(ep))
  gcq = matvec(copy(g), copy(eq))
  gpp = inner_product(copy(gcp), copy(ep))
  gqq = inner_product(copy(gcq), copy(eq))
  gpq = inner_product(copy(gcp), copy(eq))
  absgpq = if lt(gpq, cast(0.0, f32)) then neg(gpq) else gpq
  safegpq = if lt(absgpq, cast(1.0e-30, f32)) then cast(1.0, f32) else gpq
  tauraw = div(sub(gpp, gqq), mul(cast(2.0, f32), safegpq))
  abstau = if lt(tauraw, cast(0.0, f32)) then neg(tauraw) else tauraw
  signtau = if lt(tauraw, cast(0.0, f32)) then cast(-1.0, f32) else cast(1.0, f32)
  traw = div(signtau, add(abstau, sqrt(add(cast(1.0, f32), mul(tauraw, tauraw)))))
  t = if lt(absgpq, cast(1.0e-30, f32)) then cast(0.0, f32) else traw
  c = div(cast(1.0, f32), sqrt(add(cast(1.0, f32), mul(t, t))))
  s = mul(t, c)
  cm1 = sub(c, cast(1.0, f32))
  dcp = la_vec_add(scale_vec(copy(gcp), cm1), scale_vec(copy(gcq), s))
  dcq = la_vec_add(scale_vec(copy(gcp), neg(s)), scale_vec(copy(gcq), cm1))
  gr = add(add(copy(g), einsum("i,j->ij", copy(dcp), copy(ep))),
                         einsum("i,j->ij", copy(dcq), copy(eq)))
  rp = vecmat(copy(ep), copy(gr))
  rq = vecmat(copy(eq), copy(gr))
  drp = la_vec_add(scale_vec(copy(rp), cm1), scale_vec(copy(rq), s))
  drq = la_vec_add(scale_vec(copy(rp), neg(s)), scale_vec(copy(rq), cm1))
  add(add(gr, einsum("i,j->ij", copy(ep), drp)),
              einsum("i,j->ij", copy(eq), drq))
}

def la_svd_rot_v[n](v: tensor[n, n, f32], g: tensor[n, n, f32], p: int64, q: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] = {
  ep = la_basis_n_f32(p, cast(1.0, f32), copy(tpl))
  eq = la_basis_n_f32(q, cast(1.0, f32), tpl)
  gcp = matvec(copy(g), copy(ep))
  gcq = matvec(copy(g), copy(eq))
  gpp = inner_product(copy(gcp), copy(ep))
  gqq = inner_product(copy(gcq), copy(eq))
  gpq = inner_product(copy(gcp), copy(eq))
  absgpq = if lt(gpq, cast(0.0, f32)) then neg(gpq) else gpq
  safegpq = if lt(absgpq, cast(1.0e-30, f32)) then cast(1.0, f32) else gpq
  tauraw = div(sub(gpp, gqq), mul(cast(2.0, f32), safegpq))
  abstau = if lt(tauraw, cast(0.0, f32)) then neg(tauraw) else tauraw
  signtau = if lt(tauraw, cast(0.0, f32)) then cast(-1.0, f32) else cast(1.0, f32)
  traw = div(signtau, add(abstau, sqrt(add(cast(1.0, f32), mul(tauraw, tauraw)))))
  t = if lt(absgpq, cast(1.0e-30, f32)) then cast(0.0, f32) else traw
  c = div(cast(1.0, f32), sqrt(add(cast(1.0, f32), mul(t, t))))
  s = mul(t, c)
  cm1 = sub(c, cast(1.0, f32))
  vcp = matvec(copy(v), copy(ep))
  vcq = matvec(copy(v), copy(eq))
  dvp = la_vec_add(scale_vec(copy(vcp), cm1), scale_vec(copy(vcq), s))
  dvq = la_vec_add(scale_vec(copy(vcp), neg(s)), scale_vec(vcq, cm1))
  add(add(v, einsum("i,j->ij", dvp, copy(ep))),
             einsum("i,j->ij", dvq, eq))
}

def la_svd_g_iq[n](g: tensor[n, n, f32], p: int64, q: int64, nlen: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] =
  if gte(q, nlen) then g
  else la_svd_g_iq(la_svd_rot_g(g, p, q, copy(tpl)), p, add(q, cast(1, int64)), nlen, tpl)

def la_svd_g_ip[n](g: tensor[n, n, f32], p: int64, nlen: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] =
  if gte(p, sub(nlen, cast(1, int64))) then g
  else la_svd_g_ip(la_svd_g_iq(g, p, add(p, cast(1, int64)), nlen, copy(tpl)), add(p, cast(1, int64)), nlen, tpl)

def la_svd_g_sw[n](g: tensor[n, n, f32], sw: int64, nsw: int64, nlen: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] =
  if gte(sw, nsw) then g
  else la_svd_g_sw(la_svd_g_ip(g, cast(0, int64), nlen, copy(tpl)), add(sw, cast(1, int64)), nsw, nlen, tpl)

def la_svd_g_replay_q[n](g: tensor[n, n, f32], p: int64, q: int64, qtarget: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] =
  if gte(q, qtarget) then g
  else la_svd_g_replay_q(la_svd_rot_g(g, p, q, copy(tpl)), p, add(q, cast(1, int64)), qtarget, tpl)

def la_svd_g_replay_p[n](g: tensor[n, n, f32], p: int64, ptarget: int64, nlen: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] =
  if gte(p, ptarget) then g
  else la_svd_g_replay_p(la_svd_g_iq(g, p, add(p, cast(1, int64)), nlen, copy(tpl)), add(p, cast(1, int64)), ptarget, nlen, tpl)

def la_svd_v_iq[n](v: tensor[n, n, f32], g_sw_init: tensor[n, n, f32], p: int64, q: int64, nlen: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] =
  if gte(q, nlen) then v
  else {
    g_at_pq = la_svd_g_replay_q(la_svd_g_replay_p(copy(g_sw_init), cast(0, int64), p, nlen, copy(tpl)), p, add(p, cast(1, int64)), q, copy(tpl))
    v2 = la_svd_rot_v(v, g_at_pq, p, q, copy(tpl))
    la_svd_v_iq(v2, g_sw_init, p, add(q, cast(1, int64)), nlen, tpl)
  }

def la_svd_v_ip[n](v: tensor[n, n, f32], g_sw_init: tensor[n, n, f32], p: int64, nlen: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] =
  if gte(p, sub(nlen, cast(1, int64))) then v
  else la_svd_v_ip(la_svd_v_iq(v, copy(g_sw_init), p, add(p, cast(1, int64)), nlen, copy(tpl)), g_sw_init, add(p, cast(1, int64)), nlen, tpl)

def la_svd_v_sw[n](v: tensor[n, n, f32], g0: tensor[n, n, f32], sw: int64, nsw: int64, nlen: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] =
  if gte(sw, nsw) then v
  else {
    g_sw_init = la_svd_g_sw(copy(g0), cast(0, int64), sw, nlen, copy(tpl))
    v2 = la_svd_v_ip(v, g_sw_init, cast(0, int64), nlen, copy(tpl))
    la_svd_v_sw(v2, g0, add(sw, cast(1, int64)), nsw, nlen, tpl)
  }

def svd_n[n](a: tensor[n, n, f32]) -> (tensor[n, n, f32], tensor[n, f32], tensor[n, n, f32]) = {
  svd_tpl = diag(copy(a))
  svd_nlen = len(to_list(copy(svd_tpl)))
  svd_nsw = mul(cast(30, int64), svd_nlen)
  svd_g0 = gram(copy(a))
  svd_gf = la_svd_g_sw(copy(svd_g0), cast(0, int64), svd_nsw, svd_nlen, copy(svd_tpl))
  svd_gf2 = copy(svd_gf)
  svd_v0 = la_identity_n(copy(svd_tpl))
  svd_vf = la_svd_v_sw(svd_v0, svd_g0, cast(0, int64), svd_nsw, svd_nlen, copy(svd_tpl))
  svd_tpl2 = copy(svd_tpl)
  svd_zsig = to_tensor(map(fn (x: f32) -> cast(0.0, f32), to_list(copy(svd_tpl2))))
  sigma = fold(
    fn (acc: tensor[n, f32], i: int64) -> {
      svd_ei = la_basis_n_f32(i, cast(1.0, f32), copy(svd_tpl2))
      svd_gii = inner_product(matvec(copy(svd_gf), copy(svd_ei)), copy(svd_ei))
      svd_si = sqrt(if lt(svd_gii, cast(0.0, f32)) then cast(0.0, f32) else svd_gii)
      la_vec_saxpy(svd_si, acc, svd_ei)
    },
    svd_zsig, range(cast(0, int64), svd_nlen))
  svd_vf2 = copy(svd_vf)
  svd_zu = la_zeros_mat_like(copy(svd_gf2))
  u = fold(
    fn (acc: tensor[n, n, f32], i: int64) -> {
      svd_ei = la_basis_n_f32(i, cast(1.0, f32), copy(svd_tpl))
      svd_gii = inner_product(matvec(copy(svd_gf2), copy(svd_ei)), copy(svd_ei))
      svd_si = sqrt(if lt(svd_gii, cast(0.0, f32)) then cast(0.0, f32) else svd_gii)
      svd_safe = if lt(svd_si, cast(1.0e-30, f32)) then cast(1.0, f32) else svd_si
      svd_vi = matvec(copy(svd_vf2), copy(svd_ei))
      svd_avc = matvec(copy(a), svd_vi)
      svd_uc = scale_vec(svd_avc, div(cast(1.0, f32), svd_safe))
      svd_oui = einsum("i,j->ij", svd_uc, svd_ei)
      add(acc, svd_oui)
    },
    svd_zu, range(cast(0, int64), svd_nlen))
  vt = transpose(svd_vf)
  (u, sigma, vt)
}

def la_eig_rot_a[n](a: tensor[n, n, f32], p: int64, q: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] = {
  ep = la_basis_n_f32(p, cast(1.0, f32), copy(tpl))
  eq = la_basis_n_f32(q, cast(1.0, f32), tpl)
  acp = matvec(copy(a), copy(ep))
  acq = matvec(copy(a), copy(eq))
  app = inner_product(copy(acp), copy(ep))
  aqq = inner_product(copy(acq), copy(eq))
  apq = inner_product(copy(acp), copy(eq))
  absapq = if lt(apq, cast(0.0, f32)) then neg(apq) else apq
  safeapq = if lt(absapq, cast(1.0e-30, f32)) then cast(1.0, f32) else apq
  tauraw = div(sub(app, aqq), mul(cast(2.0, f32), safeapq))
  abstau = if lt(tauraw, cast(0.0, f32)) then neg(tauraw) else tauraw
  signtau = if lt(tauraw, cast(0.0, f32)) then cast(-1.0, f32) else cast(1.0, f32)
  traw = div(signtau, add(abstau, sqrt(add(cast(1.0, f32), mul(tauraw, tauraw)))))
  t = if lt(absapq, cast(1.0e-30, f32)) then cast(0.0, f32) else traw
  c = div(cast(1.0, f32), sqrt(add(cast(1.0, f32), mul(t, t))))
  s = mul(t, c)
  cm1 = sub(c, cast(1.0, f32))
  dcp = la_vec_add(scale_vec(copy(acp), cm1), scale_vec(copy(acq), s))
  dcq = la_vec_add(scale_vec(copy(acp), neg(s)), scale_vec(copy(acq), cm1))
  ar = add(add(copy(a), einsum("i,j->ij", copy(dcp), copy(ep))),
                        einsum("i,j->ij", copy(dcq), copy(eq)))
  rp = vecmat(copy(ep), copy(ar))
  rq = vecmat(copy(eq), copy(ar))
  drp = la_vec_add(scale_vec(copy(rp), cm1), scale_vec(copy(rq), s))
  drq = la_vec_add(scale_vec(copy(rp), neg(s)), scale_vec(copy(rq), cm1))
  add(add(ar, einsum("i,j->ij", copy(ep), drp)),
              einsum("i,j->ij", copy(eq), drq))
}

def la_eig_rot_q[n](q: tensor[n, n, f32], a: tensor[n, n, f32], p: int64, q_idx: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] = {
  ep = la_basis_n_f32(p, cast(1.0, f32), copy(tpl))
  eq = la_basis_n_f32(q_idx, cast(1.0, f32), tpl)
  acp = matvec(copy(a), copy(ep))
  acq = matvec(copy(a), copy(eq))
  app = inner_product(copy(acp), copy(ep))
  aqq = inner_product(copy(acq), copy(eq))
  apq = inner_product(copy(acp), copy(eq))
  absapq = if lt(apq, cast(0.0, f32)) then neg(apq) else apq
  safeapq = if lt(absapq, cast(1.0e-30, f32)) then cast(1.0, f32) else apq
  tauraw = div(sub(app, aqq), mul(cast(2.0, f32), safeapq))
  abstau = if lt(tauraw, cast(0.0, f32)) then neg(tauraw) else tauraw
  signtau = if lt(tauraw, cast(0.0, f32)) then cast(-1.0, f32) else cast(1.0, f32)
  traw = div(signtau, add(abstau, sqrt(add(cast(1.0, f32), mul(tauraw, tauraw)))))
  t = if lt(absapq, cast(1.0e-30, f32)) then cast(0.0, f32) else traw
  c = div(cast(1.0, f32), sqrt(add(cast(1.0, f32), mul(t, t))))
  s = mul(t, c)
  cm1 = sub(c, cast(1.0, f32))
  qcp = matvec(copy(q), copy(ep))
  qcq = matvec(copy(q), copy(eq))
  dvp = la_vec_add(scale_vec(copy(qcp), cm1), scale_vec(copy(qcq), s))
  dvq = la_vec_add(scale_vec(copy(qcp), neg(s)), scale_vec(qcq, cm1))
  add(add(q, einsum("i,j->ij", dvp, copy(ep))),
             einsum("i,j->ij", dvq, eq))
}

def la_eig_a_iq[n](a: tensor[n, n, f32], p: int64, q: int64, nlen: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] =
  if gte(q, nlen) then a
  else la_eig_a_iq(la_eig_rot_a(a, p, q, copy(tpl)), p, add(q, cast(1, int64)), nlen, tpl)

def la_eig_a_ip[n](a: tensor[n, n, f32], p: int64, nlen: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] =
  if gte(p, sub(nlen, cast(1, int64))) then a
  else la_eig_a_ip(la_eig_a_iq(a, p, add(p, cast(1, int64)), nlen, copy(tpl)), add(p, cast(1, int64)), nlen, tpl)

def la_eig_a_sw[n](a: tensor[n, n, f32], sw: int64, nsw: int64, nlen: int64, tpl: tensor[n, f32]) -> tensor[n, n, f32] =
  if gte(sw, nsw) then a
  else la_eig_a_sw(la_eig_a_ip(a, cast(0, int64), nlen, copy(tpl)), add(sw, cast(1, int64)), nsw, nlen, tpl)

-- Q-only inner q-loop: accumulate Q by mirroring every Jacobi rotation
-- applied to A.  A is threaded in lockstep so the angle for each
-- rotation is computed from the current (pre-rotation) A, then A is
-- advanced with la_eig_rot_a.  Returns Q only; caller updates A
-- separately using the existing la_eig_a_* functions.
def la_eig_aq_iq[n](
  a: tensor[n, n, f32],
  q: tensor[n, n, f32],
  p: int64,
  q_idx: int64,
  nlen: int64,
  tpl: tensor[n, f32]
) -> tensor[n, n, f32] =
  if gte(q_idx, nlen) then {
    ignore_a = a
    q
  }
  else {
    q2 = la_eig_rot_q(q, copy(a), p, q_idx, copy(tpl))
    a2 = la_eig_rot_a(a, p, q_idx, copy(tpl))
    la_eig_aq_iq(a2, q2, p, add(q_idx, cast(1, int64)), nlen, tpl)
  }

-- Q-only inner p-loop.  A is advanced in lockstep via la_eig_a_iq so
-- that la_eig_aq_iq receives the correct pre-sweep A for each p.
def la_eig_aq_ip[n](
  a: tensor[n, n, f32],
  q: tensor[n, n, f32],
  p: int64,
  nlen: int64,
  tpl: tensor[n, f32]
) -> tensor[n, n, f32] =
  if gte(p, sub(nlen, cast(1, int64))) then {
    ignore_a = a
    q
  }
  else {
    q2 = la_eig_aq_iq(copy(a), q, p, add(p, cast(1, int64)), nlen, copy(tpl))
    a2 = la_eig_a_iq(a, p, add(p, cast(1, int64)), nlen, copy(tpl))
    la_eig_aq_ip(a2, q2, add(p, cast(1, int64)), nlen, tpl)
  }

-- Q-only outer sweep loop.  A advances via la_eig_a_ip in lockstep.
def la_eig_aq_sw[n](
  a: tensor[n, n, f32],
  q: tensor[n, n, f32],
  sw: int64,
  nsw: int64,
  nlen: int64,
  tpl: tensor[n, f32]
) -> tensor[n, n, f32] =
  if gte(sw, nsw) then {
    ignore_a = a
    q
  }
  else {
    q2 = la_eig_aq_ip(copy(a), q, cast(0, int64), nlen, copy(tpl))
    a2 = la_eig_a_ip(a, cast(0, int64), nlen, copy(tpl))
    la_eig_aq_sw(a2, q2, add(sw, cast(1, int64)), nsw, nlen, tpl)
  }

def eig_n[n](a: tensor[n, n, f32]) -> (tensor[n, f32], tensor[n, n, f32]) = {
  eig_tpl = diag(copy(a))
  eig_nlen = len(to_list(copy(eig_tpl)))
  eig_nsw = mul(cast(30, int64), eig_nlen)
  eig_q0 = la_identity_n(copy(eig_tpl))
  eig_af = la_eig_a_sw(copy(a), cast(0, int64), eig_nsw, eig_nlen, copy(eig_tpl))
  eig_qf = la_eig_aq_sw(copy(a), eig_q0, cast(0, int64), eig_nsw, eig_nlen, copy(eig_tpl))
  eig_tpl2 = copy(eig_tpl)
  eig_zlam = to_tensor(map(fn (x: f32) -> cast(0.0, f32), to_list(copy(eig_tpl2))))
  eigenvalues = fold(
    fn (acc: tensor[n, f32], i: int64) -> {
      eig_ei = la_basis_n_f32(i, cast(1.0, f32), copy(eig_tpl2))
      eig_aii = inner_product(matvec(copy(eig_af), copy(eig_ei)), copy(eig_ei))
      la_vec_saxpy(eig_aii, acc, eig_ei)
    },
    eig_zlam, range(cast(0, int64), eig_nlen))
  (eigenvalues, eig_qf)
}

def la_chol_col_update[n](
  a_mat: tensor[n, n, f32],
  l_prev: tensor[n, n, f32],
  j: int64
) -> tensor[n, n, f32] = {
  diag_of_l = diag(copy(l_prev))
  e_j = la_basis_n_f32(j, cast(1.0, f32), diag_of_l)
  col_a = matvec(copy(a_mat), copy(e_j))
  row_j_of_l = vecmat(copy(e_j), copy(l_prev))
  partial = matvec(copy(l_prev), row_j_of_l)
  c = la_vec_sub(col_a, partial)
  c_j = inner_product(copy(c), copy(e_j))
  d = sqrt(c_j)
  inv_d = div(cast(1.0, f32), d)
  scaled = scale_vec(copy(c), inv_d)
  mask = la_mask_ge_j_f32(j, copy(c))
  new_col = la_elementwise_mul_vec(scaled, mask)
  outer_add = einsum("i,j->ij", new_col, e_j)
  add(copy(l_prev), outer_add)
}

def cholesky_n[n](a: tensor[n, n, f32]) -> tensor[n, n, f32] = {
  l_init = la_zeros_mat_like(copy(a))
  n_len = len(to_list(diag(copy(a))))
  idxs = range(cast(0, int64), n_len)
  fold(fn (l: tensor[n, n, f32], j: int64) -> la_chol_col_update(copy(a), l, j),
       l_init, idxs)
}

def det_3x3(a: tensor[3, 3, f32]) -> f32 = {
  t = trace_scalar(copy(a))
  a2 = matmul(copy(a), copy(a))
  t2 = trace_scalar(copy(a2))
  a3 = matmul(a2, a)
  t3 = trace_scalar(a3)
  three = cast(3.0, f32)
  two = cast(2.0, f32)
  six = cast(6.0, f32)
  t_cubed = mul(t, mul(t, t))
  term1 = t_cubed
  term2 = mul(three, mul(t, t2))
  term3 = mul(two, t3)
  div(add(sub(term1, term2), term3), six)
}

def la_nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))

def la_basis2(k: int64, s: f32) -> tensor[2, f32] =
  to_tensor(map(fn (i: int64) -> if eq(i, k) then s else cast(0.0, f32),
                  range(cast(0, int64), cast(2, int64))))

def la_basis3(k: int64, s: f32) -> tensor[3, f32] =
  to_tensor(map(fn (i: int64) -> if eq(i, k) then s else cast(0.0, f32),
                  range(cast(0, int64), cast(3, int64))))

def la_scaled_eye_2(s: f32) -> tensor[2, 2, f32] = {
  e1 = la_basis2(cast(0, int64), s)
  e1b = la_basis2(cast(0, int64), cast(1.0, f32))
  e2 = la_basis2(cast(1, int64), s)
  e2b = la_basis2(cast(1, int64), cast(1.0, f32))
  o1 = einsum("i,j->ij", e1, e1b)
  o2 = einsum("i,j->ij", e2, e2b)
  add(o1, o2)
}

def la_scaled_eye_3(s: f32) -> tensor[3, 3, f32] = {
  e1 = la_basis3(cast(0, int64), s)
  e1b = la_basis3(cast(0, int64), cast(1.0, f32))
  e2 = la_basis3(cast(1, int64), s)
  e2b = la_basis3(cast(1, int64), cast(1.0, f32))
  e3 = la_basis3(cast(2, int64), s)
  e3b = la_basis3(cast(2, int64), cast(1.0, f32))
  o1 = einsum("i,j->ij", e1, e1b)
  o2 = einsum("i,j->ij", e2, e2b)
  o3 = einsum("i,j->ij", e3, e3b)
  add(add(o1, o2), o3)
}

def la_scale_mat_2x2(s: f32, m: tensor[2, 2, f32]) -> tensor[2, 2, f32] = {
  diag_s = la_scaled_eye_2(s)
  matmul(diag_s, m)
}

def la_scale_mat_3x3(s: f32, m: tensor[3, 3, f32]) -> tensor[3, 3, f32] = {
  diag_s = la_scaled_eye_3(s)
  matmul(diag_s, m)
}

def la_mat_sub_2x2(a: tensor[2, 2, f32], b: tensor[2, 2, f32]) -> tensor[2, 2, f32] = {
  neg_one = la_scaled_eye_2(cast(-1.0, f32))
  nb = matmul(neg_one, b)
  add(a, nb)
}

def la_mat_sub_3x3(a: tensor[3, 3, f32], b: tensor[3, 3, f32]) -> tensor[3, 3, f32] = {
  neg_one = la_scaled_eye_3(cast(-1.0, f32))
  nb = matmul(neg_one, b)
  add(a, nb)
}

def inv_2x2(a: tensor[2, 2, f32]) -> tensor[2, 2, f32] = {
  t = trace_scalar(copy(a))
  det = det_2x2(copy(a))
  zero_f = cast(0.0, f32)
  one_f = cast(1.0, f32)
  abs_det = if lt(det, zero_f) then neg(det) else det
  eps = cast(1.0e-30, f32)
  bad = lt(abs_det, eps)
  nan_v = la_nan_f32()
  det_safe = if bad then one_f else det
  inv_det = div(one_f, det_safe)
  tI = la_scaled_eye_2(t)
  core = la_mat_sub_2x2(tI, a)
  result = la_scale_mat_2x2(inv_det, core)
  if bad then la_scaled_eye_2(nan_v) else result
}

def inv_3x3(a: tensor[3, 3, f32]) -> tensor[3, 3, f32] = {
  t = trace_scalar(copy(a))
  a2 = matmul(copy(a), copy(a))
  t2 = trace_scalar(copy(a2))
  det = det_3x3(copy(a))
  half = cast(0.5, f32)
  zero_f = cast(0.0, f32)
  one_f = cast(1.0, f32)
  abs_det = if lt(det, zero_f) then neg(det) else det
  eps = cast(1.0e-30, f32)
  bad = lt(abs_det, eps)
  nan_v = la_nan_f32()
  det_safe = if bad then one_f else det
  c1 = mul(half, sub(mul(t, t), t2))
  tA = la_scale_mat_3x3(t, copy(a))
  c1I = la_scaled_eye_3(c1)
  step1 = la_mat_sub_3x3(a2, tA)
  step2 = add(step1, c1I)
  inv_det = div(one_f, det_safe)
  result = la_scale_mat_3x3(inv_det, step2)
  if bad then la_scaled_eye_3(nan_v) else result
}

def solve_2x2(a: tensor[2, 2, f32], b: tensor[2, f32]) -> tensor[2, f32] = {
  ai = inv_2x2(a)
  matvec(ai, b)
}

def solve_3x3(a: tensor[3, 3, f32], b: tensor[3, f32]) -> tensor[3, f32] = {
  ai = inv_3x3(a)
  matvec(ai, b)
}

def eig_2x2_real(a: tensor[2, 2, f32]) -> (f32, f32) = {
  t = trace_scalar(copy(a))
  det = det_2x2(a)
  half = cast(0.5, f32)
  t_half = mul(half, t)
  disc = sub(mul(t_half, t_half), det)
  neg_one = cast(-1.0, f32)
  disc_safe = if lt(disc, cast(0.0, f32)) then neg_one else disc
  rt = sqrt(disc_safe)
  lam1 = add(t_half, rt)
  lam2 = sub(t_half, rt)
  nan_v = la_nan_f32()
  if lt(disc, cast(0.0, f32)) then (nan_v, nan_v) else (lam1, lam2)
}

def la_mat_entry_2(a: tensor[2, 2, f32], i: int64, j: int64) -> f32 = {
  e_j = la_basis2(j, cast(1.0, f32))
  col = matvec(a, e_j)
  e_i = la_basis2(i, cast(1.0, f32))
  inner_product(col, e_i)
}

def la_mat_entry_3(a: tensor[3, 3, f32], i: int64, j: int64) -> f32 = {
  e_j = la_basis3(j, cast(1.0, f32))
  col = matvec(a, e_j)
  e_i = la_basis3(i, cast(1.0, f32))
  inner_product(col, e_i)
}

def cholesky_2x2(a: tensor[2, 2, f32]) -> tensor[2, 2, f32] = {
  a00 = la_mat_entry_2(copy(a), cast(0, int64), cast(0, int64))
  a01 = la_mat_entry_2(copy(a), cast(0, int64), cast(1, int64))
  a10 = la_mat_entry_2(copy(a), cast(1, int64), cast(0, int64))
  a11 = la_mat_entry_2(a, cast(1, int64), cast(1, int64))
  zero_f = cast(0.0, f32)
  one_f = cast(1.0, f32)
  asym_diff = sub(a01, a10)
  asym_abs = if lt(asym_diff, zero_f) then neg(asym_diff) else asym_diff
  sym_eps = cast(1.0e-6, f32)
  not_sym = gt(asym_abs, sym_eps)
  bad_a00 = lte(a00, zero_f)
  a00_safe = if bad_a00 then one_f else a00
  l00 = sqrt(a00_safe)
  l10 = div(a10, l00)
  rem = sub(a11, mul(l10, l10))
  bad = or(or(bad_a00, lte(rem, zero_f)), not_sym)
  rem_safe = if bad then one_f else rem
  l11 = sqrt(rem_safe)
  nan_v = la_nan_f32()
  r00 = if bad then nan_v else l00
  r01 = if bad then nan_v else zero_f
  r10 = if bad then nan_v else l10
  r11 = if bad then nan_v else l11
  b0 = la_basis2(cast(0, int64), cast(1.0, f32))
  b0b = la_basis2(cast(0, int64), cast(1.0, f32))
  b1 = la_basis2(cast(1, int64), cast(1.0, f32))
  b1b = la_basis2(cast(1, int64), cast(1.0, f32))
  row0 = la_basis2(cast(0, int64), r00)
  row0_p1 = la_basis2(cast(1, int64), r01)
  row1 = la_basis2(cast(0, int64), r10)
  row1_p1 = la_basis2(cast(1, int64), r11)
  m00 = einsum("i,j->ij", b0, row0)
  m01 = einsum("i,j->ij", b0b, row0_p1)
  m10 = einsum("i,j->ij", b1, row1)
  m11 = einsum("i,j->ij", b1b, row1_p1)
  add(add(m00, m01), add(m10, m11))
}
