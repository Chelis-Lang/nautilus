module Nautilus.Tests.LinAlgFactor
import Std.Test (assert_close)
import Nautilus.LinAlg (matvec, l2_norm_vec, la_vec_sub, inner_product, lu_solve, cholesky_n, qr_decompose, eig_n, cg_solve)
def basis2(k: int64) -> tensor[2, f32] = to_tensor(map(fn (i: int64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32), range(cast(0, int64), cast(2, int64))))
def basis3(k: int64) -> tensor[3, f32] = to_tensor(map(fn (i: int64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32), range(cast(0, int64), cast(3, int64))))
def mk_2x2(a: f32, b: f32, c: f32, d: f32) -> tensor[2, 2, f32] = {
  e0 = basis2(cast(0, int64))
  e1 = basis2(cast(1, int64))
  m0 = einsum("i,j->ij", e0, to_tensor([a, b]))
  m1 = einsum("i,j->ij", e1, to_tensor([c, d]))
  __borrow_migration_out_0 = add(m0, m1)
  _ = drop(e1)
  _ = drop(e0)
  __borrow_migration_out_0
}
def mk_3x3(a00: f32, a01: f32, a02: f32, a10: f32, a11: f32, a12: f32, a20: f32, a21: f32, a22: f32) -> tensor[3, 3, f32] = {
  e0 = basis3(cast(0, int64))
  e1 = basis3(cast(1, int64))
  e2 = basis3(cast(2, int64))
  m0 = einsum("i,j->ij", e0, to_tensor([a00, a01, a02]))
  m1 = einsum("i,j->ij", e1, to_tensor([a10, a11, a12]))
  m2 = einsum("i,j->ij", e2, to_tensor([a20, a21, a22]))
  __borrow_migration_out_1 = add(add(m0, m1), m2)
  _ = drop(e1)
  _ = drop(e2)
  _ = drop(e0)
  __borrow_migration_out_1
}
def test_lu_solve_residual_2x2() -> unit ! { Test } = {
  a = mk_2x2(cast(2.0, f32), cast(1.0, f32), cast(1.0, f32), cast(3.0, f32))
  b = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  x = lu_solve(copy(a), copy(b))
  ax = matvec(a, x)
  err = l2_norm_vec(la_vec_sub(ax, b))
  __borrow_migration_out_0 = assert_close(err, cast(0.0, f32), cast(0.0001, f32), "lu_solve: A * x = b residual ~ 0")
  _ = drop(x)
  _ = drop(a)
  _ = drop(b)
  _ = drop(ax)
  __borrow_migration_out_0
}
def test_cholesky_2x2_diagonal_reconstruction() -> unit ! { Test } = {
  a = mk_2x2(cast(4.0, f32), cast(2.0, f32), cast(2.0, f32), cast(3.0, f32))
  l = cholesky_n(a)
  ll_t = einsum("ij,kj->ik", copy(l), l)
  e0 = basis2(cast(0, int64))
  v = matvec(ll_t, copy(e0))
  v00 = inner_product(v, e0)
  __borrow_migration_out_1 = assert_close(v00, cast(4.0, f32), cast(0.001, f32), "cholesky: (L L^T)[0,0] = A[0,0] = 4")
  _ = drop(v)
  _ = drop(a)
  _ = drop(l)
  _ = drop(e0)
  __borrow_migration_out_1
}
def test_qr_orthogonality_diagonal_2x2() -> unit ! { Test } = {
  a = mk_2x2(cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32))
  q_pair = qr_decompose(a)
  q = q_pair.0
  e0 = basis2(cast(0, int64))
  q_col0 = matvec(q, copy(e0))
  norm_sq = inner_product(copy(q_col0), q_col0)
  __borrow_migration_out_0 = assert_close(norm_sq, cast(1.0, f32), cast(0.001, f32), "QR: ||column 0 of Q||^2 = 1")
  _ = drop(a)
  _ = drop(e0)
  __borrow_migration_out_0
}
def test_eig_n_trace_identity() -> unit ! { Test } = {
  a = mk_2x2(cast(4.0, f32), cast(1.0, f32), cast(1.0, f32), cast(4.0, f32))
  pair = eig_n(a)
  evals = pair.0
  ones2 = to_tensor([cast(1.0, f32), cast(1.0, f32)])
  sum_evals = inner_product(evals, ones2)
  __borrow_migration_out_1 = assert_close(sum_evals, cast(8.0, f32), cast(0.001, f32), "eig: sum(eigenvalues) = trace(A) = 8")
  _ = drop(a)
  _ = drop(ones2)
  __borrow_migration_out_1
}
def test_cg_solve_residual_2x2() -> unit ! { Test } = {
  a = mk_2x2(cast(4.0, f32), cast(1.0, f32), cast(1.0, f32), cast(3.0, f32))
  b = to_tensor([cast(1.0, f32), cast(2.0, f32)])
  x0 = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  x = cg_solve(copy(a), copy(b), x0, cast(0.0000001, f32), cast(50, int64))
  ax = matvec(a, x)
  err = l2_norm_vec(la_vec_sub(ax, b))
  __borrow_migration_out_2 = assert_close(err, cast(0.0, f32), cast(0.0001, f32), "cg_solve: A * x = b residual ~ 0")
  _ = drop(x)
  _ = drop(a)
  _ = drop(b)
  _ = drop(ax)
  __borrow_migration_out_2
}
