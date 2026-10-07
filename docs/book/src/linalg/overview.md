# Linear algebra

The `Nautilus.LinAlg` module provides linear algebra primitives built
entirely from Chelis tensor operations.

## Solvers and utilities

- **Fixed-size closed-form solvers** for 2x2 and 3x3 systems: inversion,
  determinant, solve, eigenvalues, Cholesky (see [Small-N](small-n.md)).
- **General-n iterative solver**: conjugate gradient for symmetric
  positive-definite systems (see [CG Solve](cg-solve.md)).
- **General-n decompositions**: `lu_solve` (Doolittle LU, no pivoting),
  `qr_decompose` (Householder QR, square), `cholesky_n` (column Cholesky, SPD),
  `svd_n` (Jacobi SVD, square, 30n sweeps), and `eig_n` (symmetric
  Jacobi eigendecomposition).
- **Shared helpers**: `la_basis_n_f32`, `la_zeros_mat_like`, and
  `la_tridiag_solve`, used by CurveFit, Ode, and spline interpolation
  (signatures below).
- **Matrix utilities**: `transpose`, `matmul_wrap`, `gram` (A^T A),
  `aat` (A A^T), `diag`, `trace_mat`, `trace_scalar`.
- **Vector utilities**: `l2_norm_vec`, `inner_product`, `scale_vec`,
  `la_vec_add`, `la_vec_sub`, `la_vec_saxpy`.
- **Norms**: `frobenius_norm`, `frobenius_sq`.
- **Contractions**: `matvec` and `vecmat` via `einsum`.

## Import pattern

```chelis-fragment
import Nautilus.LinAlg (
  solve_2x2, inv_2x2, det_2x2, cg_solve,
  matvec, l2_norm_vec, inner_product
)
```

## Example: solve and check the residual

```chelis-fragment
import Nautilus.LinAlg (matvec, la_vec_sub, l2_norm_vec, solve_2x2)

def residual_norm[n](a: &tensor[n, n, f32], x: &tensor[n, f32], b: &tensor[n, f32]) -> f32 = {
  ax = matvec(a, x)
  r = la_vec_sub(b, ax)
  l2_norm_vec(r)
}
def a2() -> tensor[2, 2, f32] = to_tensor([[4.0f32, 1.0f32], [1.0f32, 3.0f32]])
def b2() -> tensor[2, f32] = to_tensor([1.0f32, 2.0f32])
x2 = solve_2x2(a2(), b2())
res2 = residual_norm(a2(), solve_2x2(a2(), b2()), b2())
```

```text
x2 = tensor(shape=[2], data=[0.09090909, 0.6363636])
res2 = 0.0
```

The exact solution is `[1/11, 7/11]`, and `||b - A x||` is zero at f32
precision. `to_tensor` builds a matrix from a list of rows.

## Shared helpers

| Function | Signature | Returns |
|---|---|---|
| `la_basis_n_f32` | `[n](k: i64, s: f32, template: &tensor[n, f32]) -> tensor[n, f32]` | `s` at index `k`, zero elsewhere; all zeros when `k` is outside `0..n-1` |
| `la_zeros_mat_like` | `[n](a: &tensor[n, n, f32]) -> tensor[n, n, f32]` | an n x n zero matrix, computed as `a - a` (NaN where `a` has NaN or inf) |
| `la_tridiag_solve` | `[n](lower: tensor[n, f32], diag: tensor[n, f32], upper: tensor[n, f32], b: tensor[n, f32]) -> tensor[n, f32]` | the solution of a tridiagonal system by the Thomas algorithm |

In `la_tridiag_solve`, row `i` of the matrix is `lower[i]`, `diag[i]`,
`upper[i]` in columns `i-1`, `i`, `i+1`; `lower[0]` and `upper[n-1]` are
ignored. It does not pivot. A pivot with magnitude below 1e-30 is replaced by
1.0, which avoids a division by zero and returns a wrong answer instead, so
use it on diagonally dominant systems such as spline fits.

## Notes

- All inputs and outputs are `f32` tensors. Do not pass `f64`.
- Most LinAlg functions borrow their tensor arguments (`&tensor` in the
  signature), so one tensor can feed several calls without `copy`.
  `cg_solve`, `lu_solve`, and `la_tridiag_solve` take ownership. If the
  argument is a borrowed `&tensor`, use `copy(t)` to supply an owned value.
- The closed-form inverses use the Cayley-Hamilton theorem, not Cramer's
  rule. They return NaN-filled matrices when the determinant is near zero
  (threshold: 1e-30).
- `matvec` and `vecmat` use `einsum` internally, so they work at any
  dimension `n`.
