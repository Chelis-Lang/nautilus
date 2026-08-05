module Nautilus.Tests.LinAlgMatmul
import Std.Test (assert_close, assert_true)
import Nautilus.LinAlg (matvec, inner_product, l2_norm_vec, la_vec_sub, transpose, matmul_wrap, gram, aat, frobenius_norm, frobenius_sq, det_2x2, det_3x3, inv_2x2, inv_3x3, solve_2x2, solve_3x3, eig_2x2_real, cholesky_2x2, svd_n)
def basis2(k: int64) -> tensor[2, f32] = to_tensor(map(fn (i: int64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32), range(cast(0, int64), cast(2, int64))))
def basis3(k: int64) -> tensor[3, f32] = to_tensor(map(fn (i: int64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32), range(cast(0, int64), cast(3, int64))))
def mk_2x2(a: f32, b: f32, c: f32, d: f32) -> tensor[2, 2, f32] = {
  e0 = basis2(cast(0, int64))
  e1 = basis2(cast(1, int64))
  m0 = einsum("i,j->ij", e0, to_tensor([a, b]))
  m1 = einsum("i,j->ij", e1, to_tensor([c, d]))
  add(m0, m1)
}
def mk_3x3(a00: f32, a01: f32, a02: f32, a10: f32, a11: f32, a12: f32, a20: f32, a21: f32, a22: f32) -> tensor[3, 3, f32] = {
  e0 = basis3(cast(0, int64))
  e1 = basis3(cast(1, int64))
  e2 = basis3(cast(2, int64))
  m0 = einsum("i,j->ij", e0, to_tensor([a00, a01, a02]))
  m1 = einsum("i,j->ij", e1, to_tensor([a10, a11, a12]))
  m2 = einsum("i,j->ij", e2, to_tensor([a20, a21, a22]))
  add(add(m0, m1), m2)
}
def eye2() -> tensor[2, 2, f32] = mk_2x2(cast(1.0, f32), cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
def eye3() -> tensor[3, 3, f32] = mk_3x3(cast(1.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(1.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
def test_transpose_swaps_offdiagonal() -> unit ! { Test } = {
  a = mk_2x2(cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32))
  at = transpose(a)
  e0 = basis2(cast(0, int64))
  e1 = basis2(cast(1, int64))
  v10 = inner_product(matvec(at, e0), e1)
  assert_close(v10, cast(2.0, f32), cast(0.00001, f32), "transpose([[1,2],[3,4]])[1,0] = 2")
}
def test_matmul_wrap_diagonal() -> unit ! { Test } = {
  a = mk_2x2(cast(2.0, f32), cast(0.0, f32), cast(0.0, f32), cast(3.0, f32))
  prod = matmul_wrap(eye2(), a)
  e0 = basis2(cast(0, int64))
  v00 = inner_product(matvec(prod, copy(e0)), e0)
  assert_close(v00, cast(2.0, f32), cast(0.00001, f32), "matmul_wrap(I, diag(2,3))[0,0] = 2")
}
def test_gram_identity_is_identity() -> unit ! { Test } = {
  g = gram(eye2())
  e0 = basis2(cast(0, int64))
  e1 = basis2(cast(1, int64))
  v00 = inner_product(matvec(g, copy(e0)), copy(e0))
  assert_close(v00, cast(1.0, f32), cast(0.00001, f32), "gram(I)[0,0] = 1")
}
def test_aat_identity_is_identity() -> unit ! { Test } = {
  ai = aat(eye2())
  e0 = basis2(cast(0, int64))
  v00 = inner_product(matvec(ai, copy(e0)), e0)
  assert_close(v00, cast(1.0, f32), cast(0.00001, f32), "aat(I)[0,0] = 1")
}
def test_frobenius_norm_zero_matrix() -> unit ! { Test } = {
  z = mk_2x2(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32))
  assert_close(frobenius_norm(z), cast(0.0, f32), cast(1e-6, f32), "||0||_F = 0")
}
def test_frobenius_norm_identity_is_sqrt_n() -> unit ! { Test } = assert_close(frobenius_norm(eye3()), cast(1.7320508, f32), cast(0.0001, f32), "||I_3||_F = sqrt(3)")
def test_frobenius_sq_identity_is_n() -> unit ! { Test } = assert_close(frobenius_sq(eye3()), cast(3.0, f32), cast(0.00001, f32), "||I_3||^2 = 3")
def test_det_2x2_identity() -> unit ! { Test } = assert_close(det_2x2(eye2()), cast(1.0, f32), cast(1e-6, f32), "det(I_2) = 1")
def test_det_2x2_known() -> unit ! { Test } = {
  a = mk_2x2(cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32))
  assert_close(det_2x2(a), cast(-2.0, f32), cast(0.00001, f32), "det([[1,2],[3,4]]) = -2")
}
def test_det_3x3_identity() -> unit ! { Test } = assert_close(det_3x3(eye3()), cast(1.0, f32), cast(0.00001, f32), "det(I_3) = 1")
def test_det_3x3_diagonal() -> unit ! { Test } = {
  d = mk_3x3(cast(2.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(3.0, f32), cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), cast(5.0, f32))
  assert_close(det_3x3(d), cast(30.0, f32), cast(0.0001, f32), "det(diag(2,3,5)) = 30")
}
def test_inv_2x2_reconstruction() -> unit ! { Test } = {
  a = mk_2x2(cast(2.0, f32), cast(1.0, f32), cast(1.0, f32), cast(1.0, f32))
  inv = inv_2x2(copy(a))
  prod = matmul_wrap(a, inv)
  err = frobenius_norm(sub(prod, eye2()))
  assert_close(err, cast(0.0, f32), cast(0.0001, f32), "A · inv_2x2(A) = I  (Frobenius)")
}
def test_inv_3x3_reconstruction() -> unit ! { Test } = {
  a = mk_3x3(cast(4.0, f32), cast(2.0, f32), cast(1.0, f32), cast(2.0, f32), cast(5.0, f32), cast(3.0, f32), cast(1.0, f32), cast(3.0, f32), cast(6.0, f32))
  inv = inv_3x3(copy(a))
  prod = matmul_wrap(a, inv)
  err = frobenius_norm(sub(prod, eye3()))
  assert_close(err, cast(0.0, f32), cast(0.001, f32), "A · inv_3x3(A) = I  (Frobenius)")
}
def test_solve_2x2_residual() -> unit ! { Test } = {
  a = mk_2x2(cast(3.0, f32), cast(1.0, f32), cast(1.0, f32), cast(2.0, f32))
  b = to_tensor([cast(5.0, f32), cast(4.0, f32)])
  x = solve_2x2(copy(a), copy(b))
  ax = matvec(a, x)
  err = l2_norm_vec(la_vec_sub(ax, b))
  assert_close(err, cast(0.0, f32), cast(0.00001, f32), "solve_2x2: A x = b residual ≈ 0")
}
def test_solve_3x3_residual() -> unit ! { Test } = {
  a = mk_3x3(cast(4.0, f32), cast(2.0, f32), cast(1.0, f32), cast(2.0, f32), cast(5.0, f32), cast(3.0, f32), cast(1.0, f32), cast(3.0, f32), cast(6.0, f32))
  b = to_tensor([cast(7.0, f32), cast(10.0, f32), cast(10.0, f32)])
  x = solve_3x3(copy(a), copy(b))
  ax = matvec(a, x)
  err = l2_norm_vec(la_vec_sub(ax, b))
  assert_close(err, cast(0.0, f32), cast(0.001, f32), "solve_3x3: A x = b residual ≈ 0")
}
def test_eig_2x2_real_trace_identity() -> unit ! { Test } = {
  a = mk_2x2(cast(3.0, f32), cast(1.0, f32), cast(1.0, f32), cast(3.0, f32))
  pair = eig_2x2_real(a)
  s = add(pair.0, pair.1)
  assert_close(s, cast(6.0, f32), cast(0.00001, f32), "eig_2x2_real: sum of eigenvalues = trace = 6")
}
def test_eig_2x2_real_det_identity() -> unit ! { Test } = {
  a_for_eig = mk_2x2(cast(3.0, f32), cast(1.0, f32), cast(1.0, f32), cast(3.0, f32))
  a_for_det = mk_2x2(cast(3.0, f32), cast(1.0, f32), cast(1.0, f32), cast(3.0, f32))
  pair = eig_2x2_real(a_for_eig)
  p = mul(pair.0, pair.1)
  d = det_2x2(a_for_det)
  assert_close(p, d, cast(0.0001, f32), "eig_2x2_real: prod(eigenvalues) = det(A)")
}
def test_cholesky_2x2_reconstruction() -> unit ! { Test } = {
  a = mk_2x2(cast(4.0, f32), cast(2.0, f32), cast(2.0, f32), cast(3.0, f32))
  l = cholesky_2x2(copy(a))
  l_t = transpose(copy(l))
  prod = matmul_wrap(l, l_t)
  err = frobenius_norm(sub(prod, a))
  assert_close(err, cast(0.0, f32), cast(0.0001, f32), "cholesky_2x2: L L^T = A  (Frobenius)")
}
def test_svd_n_singular_value_sum_diagonal() -> unit ! { Test } = {
  a = mk_2x2(cast(3.0, f32), cast(0.0, f32), cast(0.0, f32), cast(1.0, f32))
  triple = svd_n(a)
  ones2 = to_tensor([cast(1.0, f32), cast(1.0, f32)])
  s = inner_product(triple.1, ones2)
  assert_close(s, cast(4.0, f32), cast(0.001, f32), "svd_n: sum(sigma) for diag(3,1) = 4")
}
def test_inv_2x2_singular_returns_nan() -> unit ! { Test } = {
  singular = mk_2x2(cast(1.0, f32), cast(2.0, f32), cast(2.0, f32), cast(4.0, f32))
  inv = inv_2x2(singular)
  first = inner_product(matvec(inv, basis2(cast(0, int64))), basis2(cast(0, int64)))
  assert_true(neq(first, first), "inv_2x2: singular matrix returns NaN entries")
}
def test_solve_2x2_singular_returns_nan() -> unit ! { Test } = {
  singular = mk_2x2(cast(1.0, f32), cast(2.0, f32), cast(2.0, f32), cast(4.0, f32))
  b = to_tensor([cast(1.0, f32), cast(2.0, f32)])
  x = solve_2x2(singular, b)
  first = inner_product(x, basis2(cast(0, int64)))
  assert_true(neq(first, first), "solve_2x2: singular matrix returns NaN entries")
}
def test_cholesky_2x2_non_spd_returns_nan() -> unit ! { Test } = {
  non_spd = mk_2x2(cast(1.0, f32), cast(2.0, f32), cast(2.0, f32), cast(1.0, f32))
  l = cholesky_2x2(non_spd)
  first = inner_product(matvec(l, basis2(cast(0, int64))), basis2(cast(0, int64)))
  assert_true(neq(first, first), "cholesky_2x2: non-SPD matrix returns NaN entries")
}
