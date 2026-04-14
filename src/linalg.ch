module Nautilus.LinAlg
export (
  transpose, matmul_wrap, gram, aat,
  diag, trace_mat, trace_scalar,
  l2_norm_vec, inner_product, frobenius_sq, frobenius_norm,
  scale_vec,
  matvec, vecmat,
  det_2x2, det_3x3,
  la_vec_add, la_vec_sub, la_vec_saxpy,
  cg_solve
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
