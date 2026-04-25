module Nautilus.Tests.LinAlgFactor

-- Minimal identity / structural tests for the heavy LinAlg
-- factorizations: lu_solve, qr_decompose, cholesky_n, svd_n, eig_n,
-- cg_solve. Each factorization gets ONE small test (n=2 or n=3) — the
-- chelis test runner re-compiles the module + helper graph per test
-- function, and these factorization graphs are large, so per-test
-- compile is ~60-120 s. With one test per factorization this file
-- runs in ~5-10 min wall-clock.
--
-- Why split from tests/linalg.ch: keeping these heavy compiles in a
-- separate file localizes the timeout risk; tests/linalg.ch (cheap
-- vector ops) stays fast.
--
-- Documented fix for red-team HIGH-1 (LinAlg coverage 32%): this file
-- adds native-Chelis identity coverage for the recently-landed
-- decomposition surface so the legacy harness can be retired in
-- Phase 3.

import Std.Test (assert_close)
import Nautilus.LinAlg (matvec, l2_norm_vec, la_vec_sub, inner_product,
                        lu_solve, cholesky_n, qr_decompose,
                        eig_n, cg_solve)

-- ===== Helpers =====

def basis2(k: int64) -> tensor[2, f32] =
  to_tensor(map(fn (i: int64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32),
                  range(cast(0, int64), cast(2, int64))))

def basis3(k: int64) -> tensor[3, f32] =
  to_tensor(map(fn (i: int64) -> if eq(i, k) then cast(1.0, f32) else cast(0.0, f32),
                  range(cast(0, int64), cast(3, int64))))

def mk_2x2(a: f32, b: f32, c: f32, d: f32) -> tensor[2, 2, f32] = {
  e0 = basis2(cast(0, int64))
  e1 = basis2(cast(1, int64))
  m0 = einsum("i,j->ij", e0, to_tensor([a, b]))
  m1 = einsum("i,j->ij", e1, to_tensor([c, d]))
  add(m0, m1)
}

def mk_3x3(a00: f32, a01: f32, a02: f32,
           a10: f32, a11: f32, a12: f32,
           a20: f32, a21: f32, a22: f32) -> tensor[3, 3, f32] = {
  e0 = basis3(cast(0, int64))
  e1 = basis3(cast(1, int64))
  e2 = basis3(cast(2, int64))
  m0 = einsum("i,j->ij", e0, to_tensor([a00, a01, a02]))
  m1 = einsum("i,j->ij", e1, to_tensor([a10, a11, a12]))
  m2 = einsum("i,j->ij", e2, to_tensor([a20, a21, a22]))
  add(add(m0, m1), m2)
}

-- ===== lu_solve =====
-- A · lu_solve(A, b) ≈ b  (residual norm ≈ 0)

def test_lu_solve_residual_2x2() -> unit ! { Test } = {
  -- A = [[2, 1], [1, 3]], b = [3, 4]; solve and check A · x ≈ b
  a = mk_2x2(cast(2.0, f32), cast(1.0, f32),
             cast(1.0, f32), cast(3.0, f32))
  b = to_tensor([cast(3.0, f32), cast(4.0, f32)])
  x = lu_solve(copy(a), copy(b))
  ax = matvec(a, x)
  err = l2_norm_vec(la_vec_sub(ax, b))
  assert_close(err, cast(0.0, f32), cast(1.0e-4, f32),
               "lu_solve: A * x = b residual ~ 0")
}

-- ===== cholesky_n =====
-- For SPD A, L = cholesky(A), L · L^T ≈ A. The chelis test host runtime
-- doesn't support `sum` (used by frobenius_norm), so we extract specific
-- elements of L L^T and compare to the corresponding A entries via
-- inner_product(matvec(M, e_b), e_a) which only uses supported primitives.

def test_cholesky_2x2_diagonal_reconstruction() -> unit ! { Test } = {
  -- A = [[4, 2], [2, 3]] is SPD (det = 8 > 0, trace > 0).
  -- Check (L L^T)[0,0] = A[0,0] = 4 elementwise.
  a = mk_2x2(cast(4.0, f32), cast(2.0, f32),
             cast(2.0, f32), cast(3.0, f32))
  l = cholesky_n(a)
  ll_t = einsum("ij,kj->ik", copy(l), l)
  -- (L L^T)[0,0] = e_0^T (L L^T) e_0 = inner_product(matvec(LL^T, e_0), e_0)
  e0 = basis2(cast(0, int64))
  v = matvec(ll_t, copy(e0))
  v00 = inner_product(v, e0)
  assert_close(v00, cast(4.0, f32), cast(1.0e-3, f32),
               "cholesky: (L L^T)[0,0] = A[0,0] = 4")
}

-- ===== qr_decompose =====
-- Q^T · Q ≈ I  (orthogonality of Q). Element-wise check at the diagonal:
-- (Q^T Q)[0,0] = ||column 0 of Q||^2 = 1.

def test_qr_orthogonality_diagonal_2x2() -> unit ! { Test } = {
  a = mk_2x2(cast(1.0, f32), cast(2.0, f32),
             cast(3.0, f32), cast(4.0, f32))
  q_pair = qr_decompose(a)
  q = q_pair.0
  -- column 0 of Q = Q · e_0
  e0 = basis2(cast(0, int64))
  q_col0 = matvec(q, copy(e0))
  -- ||q_col0||^2 = q_col0 · q_col0 = 1 (Q is orthogonal)
  norm_sq = inner_product(copy(q_col0), q_col0)
  assert_close(norm_sq, cast(1.0, f32), cast(1.0e-3, f32),
               "QR: ||column 0 of Q||^2 = 1")
}

-- NOTE: svd_n is not testable under `chelis test` in v0.2.4 because
-- the SVD implementation uses `permute` internally, and `permute` is
-- not in the chelis test host runtime. svd_n identity coverage stays
-- in `tests_legacy/run_numeric_tests.py` (compiled-binary path) until
-- the host runtime adds `permute`.

-- ===== eig_n =====
-- For symmetric A, sum of eigenvalues = trace(A).

def test_eig_n_trace_identity() -> unit ! { Test } = {
  -- Symmetric A = [[4, 1], [1, 4]]; eigenvalues are {3, 5}.
  -- sum(eigenvalues) = trace(A) = 8 by Newton's identity (exact).
  a = mk_2x2(cast(4.0, f32), cast(1.0, f32),
             cast(1.0, f32), cast(4.0, f32))
  pair = eig_n(a)
  evals = pair.0
  ones2 = to_tensor([cast(1.0, f32), cast(1.0, f32)])
  sum_evals = inner_product(evals, ones2)
  assert_close(sum_evals, cast(8.0, f32), cast(1.0e-3, f32),
               "eig: sum(eigenvalues) = trace(A) = 8")
}

-- ===== cg_solve =====
-- For SPD A, A · cg_solve(A, b) ≈ b  (residual norm ≈ 0)

def test_cg_solve_residual_2x2() -> unit ! { Test } = {
  -- A = [[4, 1], [1, 3]] is SPD (positive eigenvalues 3.38 and 3.62 -- both > 0)
  -- cg_solve signature: (A, b, x0, tol, max_iters)
  a = mk_2x2(cast(4.0, f32), cast(1.0, f32),
             cast(1.0, f32), cast(3.0, f32))
  b = to_tensor([cast(1.0, f32), cast(2.0, f32)])
  x0 = to_tensor([cast(0.0, f32), cast(0.0, f32)])
  x = cg_solve(copy(a), copy(b), x0,
               cast(1.0e-7, f32), cast(50, int64))
  ax = matvec(a, x)
  err = l2_norm_vec(la_vec_sub(ax, b))
  assert_close(err, cast(0.0, f32), cast(1.0e-4, f32),
               "cg_solve: A * x = b residual ~ 0")
}
