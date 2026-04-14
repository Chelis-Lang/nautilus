module Nautilus.LinAlg
export (
  transpose, matmul_wrap, gram, aat,
  diag, trace_mat, trace_scalar,
  l2_norm_vec, inner_product, frobenius_sq, frobenius_norm,
  scale_vec,
  matvec, vecmat,
  det_2x2, det_3x3
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
