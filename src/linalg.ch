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
  cholesky_n
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

def la_elementwise_mul_vec[n](a: tensor[n, f32], b: tensor[n, f32]) -> tensor[n, f32] =
  to_tensor(map(fn (pair: (f32, f32)) -> mul(pair.0, pair.1),
                zip(to_list(a), to_list(b))))

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
