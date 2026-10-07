# Small-matrix linear algebra

Fixed-size closed-form routines for 2x2 and 3x3 matrices. These use the
Cayley-Hamilton theorem for inversion and determinants, avoiding
pivoting or iteration entirely. Every input matrix is a read-only borrow
(`&tensor`).

## Determinants

| Function | Signature |
|---|---|
| `det_2x2` | `(a: &tensor[2, 2, f32]) -> f32` |
| `det_3x3` | `(a: &tensor[3, 3, f32]) -> f32` |

Both compute the determinant from traces of matrix powers (Newton's
identities), not cofactor expansion.

## Inversion

| Function | Signature |
|---|---|
| `inv_2x2` | `(a: &tensor[2, 2, f32]) -> tensor[2, 2, f32]` |
| `inv_3x3` | `(a: &tensor[3, 3, f32]) -> tensor[3, 3, f32]` |

Returns a NaN-filled matrix when `|det| < 1e-30` (singular or
near-singular).

## Linear solve

| Function | Signature |
|---|---|
| `solve_2x2` | `(a: &tensor[2, 2, f32], b: &tensor[2, f32]) -> tensor[2, f32]` |
| `solve_3x3` | `(a: &tensor[3, 3, f32], b: &tensor[3, f32]) -> tensor[3, f32]` |

Each delegates to the corresponding inverse followed by `matvec`.

## Eigenvalues

| Function | Signature |
|---|---|
| `eig_2x2_real` | `(a: &tensor[2, 2, f32]) -> (f32, f32)` |

Returns the two real eigenvalues as a tuple using the trace/determinant
formula. If the discriminant is negative (complex eigenvalues), both
entries are NaN.

## Cholesky

| Function | Signature |
|---|---|
| `cholesky_2x2` | `(a: &tensor[2, 2, f32]) -> tensor[2, 2, f32]` |
| `cholesky_n` | `[n](a: &tensor[n, n, f32]) -> tensor[n, n, f32]` |

Returns the lower-triangular Cholesky factor L such that A = L L^T.

`cholesky_2x2` is the closed-form 2×2 variant. It returns NaN if the
matrix is not symmetric positive-definite (symmetry tolerance: 1e-6).

`cholesky_n` is the general-`n` column-by-column variant (Banachiewicz
form). It assumes the input is SPD and does not emit NaN markers; on a
non-SPD matrix the output is undefined.

## General-dimension decompositions

These general-dimension decompositions accept square matrices only.

| Function | Signature |
|---|---|
| `lu_solve` | `[n](a: tensor[n, n, f32], b: tensor[n, f32]) -> tensor[n, f32]` |
| `qr_decompose` | `[n](a: &tensor[n, n, f32]) -> (tensor[n, n, f32], tensor[n, n, f32])` |
| `svd_n` | `[n](a: &tensor[n, n, f32]) -> (tensor[n, n, f32], tensor[n, f32], tensor[n, n, f32])` |
| `eig_n` | `[n](a: &tensor[n, n, f32]) -> (tensor[n, f32], tensor[n, n, f32])` |

**`lu_solve`** solves `A x = b` via Doolittle LU factorization (no partial
pivoting). It takes `a` and `b` by value; pass `copy(t)` for a tensor you
still need. Requires all leading principal submatrices of A to be
nonsingular. A matrix that needs a row swap gets no error: the permutation
`[[0,1],[1,0]]` with `b = [2, 3]` returns `[NaN, NaN]`, and a small nonzero
pivot returns an inaccurate solution instead of NaN. Use `cg_solve` for a
symmetric positive-definite system.

**`qr_decompose`** applies Householder reflections and returns `(Q, R)` where
Q is orthogonal and R is upper triangular, so `A = Q R`. Householder sign
choices make the factors piecewise-smooth functions of A, not globally smooth
ones.

**`svd_n`** returns `(U, sigma, Vt)` where sigma is the vector of singular
values, in the order the Jacobi sweeps leave them rather than sorted, and `A ≈ U diag(sigma) Vt`. Uses a fixed 30n Jacobi
sweeps; poorly separated singular values may not fully converge (use abs
tolerance ≥ 1e-3 for sigma comparisons). U is orthogonal only for full-rank A.

**`eig_n`** is a symmetric Jacobi eigendecomposition returning
`(eigenvalues, Q)`, where column i of Q is the eigenvector for eigenvalue i.
It uses a fixed 30n sweeps, silently gives wrong results for a non-symmetric
input, and does not guarantee eigenvalue order.

## Example

```chelis-fragment
import Nautilus.LinAlg (solve_2x2, solve_3x3, det_2x2, inv_2x2, eig_2x2_real)

def a2() -> tensor[2, 2, f32] = to_tensor([[4.0f32, 1.0f32], [1.0f32, 3.0f32]])
x2 = solve_2x2(a2(), to_tensor([1.0f32, 2.0f32]))
det = det_2x2(a2())
eigs = eig_2x2_real(a2())
singular_inv = inv_2x2(to_tensor([[1.0f32, 2.0f32], [2.0f32, 4.0f32]]))
x3 = solve_3x3(to_tensor([[2.0f32, 0.0f32, 1.0f32], [0.0f32, 3.0f32, 0.0f32], [1.0f32, 0.0f32, 2.0f32]]), to_tensor([3.0f32, 3.0f32, 3.0f32]))
```

```text
x2 = tensor(shape=[2], data=[0.09090909, 0.6363636])
det = 11.0
eigs.0 = 4.618034
eigs.1 = 2.381966
singular_inv = tensor(shape=[2, 2], data=[NaN, NaN, NaN, NaN])
x3 = tensor(shape=[3], data=[1.0, 1.0, 1.0])
```

`eig_2x2_real` returns the larger eigenvalue first, `(5 + sqrt(5)) / 2` and
`(5 - sqrt(5)) / 2` here. The second matrix has determinant 0, so its
inverse is all NaN.

## Edge cases

- Singular matrices in the fixed-size routines produce NaN results, not exceptions.
- The dimension is enforced at compile time: passing a 3x3 tensor to
  `inv_2x2` is a type error caught by `chelis check`.
- For general-n linear solve use `lu_solve` (Doolittle, no partial pivoting)
  or `cg_solve` (iterative, SPD only). For decompositions use `qr_decompose`
  (Householder QR), `svd_n` (Jacobi SVD), or `eig_n` (symmetric
  eigendecomposition).
