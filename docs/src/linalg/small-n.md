# Small-N Linear Algebra

Fixed-size closed-form routines for 2x2 and 3x3 matrices. These use the
Cayley-Hamilton theorem for inversion and determinants, avoiding
pivoting or iteration entirely. AD flows through all of them.

## Determinants

| Function | Signature |
|---|---|
| `det_2x2` | `(a: tensor[2, 2, f32]) -> f32` |
| `det_3x3` | `(a: tensor[3, 3, f32]) -> f32` |

Both compute the determinant from traces of matrix powers (Newton's
identities), not cofactor expansion.

## Inversion

| Function | Signature |
|---|---|
| `inv_2x2` | `(a: tensor[2, 2, f32]) -> tensor[2, 2, f32]` |
| `inv_3x3` | `(a: tensor[3, 3, f32]) -> tensor[3, 3, f32]` |

Returns a NaN-filled matrix when `|det| < 1e-30` (singular or
near-singular).

## Linear solve

| Function | Signature |
|---|---|
| `solve_2x2` | `(a: tensor[2, 2, f32], b: tensor[2, f32]) -> tensor[2, f32]` |
| `solve_3x3` | `(a: tensor[3, 3, f32], b: tensor[3, f32]) -> tensor[3, f32]` |

Each delegates to the corresponding inverse followed by `matvec`.

## Eigenvalues

| Function | Signature |
|---|---|
| `eig_2x2_real` | `(a: tensor[2, 2, f32]) -> (f32, f32)` |

Returns the two real eigenvalues as a tuple using the trace/determinant
formula. If the discriminant is negative (complex eigenvalues), both
entries are NaN.

## Cholesky

| Function | Signature | Stability |
|---|---|---|
| `cholesky_2x2` | `(a: tensor[2, 2, f32]) -> tensor[2, 2, f32]` | `stable` |
| `cholesky_n` | `[n](a: tensor[n, n, f32]) -> tensor[n, n, f32]` | `alpha` |

Returns the lower-triangular Cholesky factor L such that A = L L^T.

`cholesky_2x2` is the closed-form 2×2 variant — returns NaN if the
matrix is not symmetric positive-definite (symmetry tolerance: 1e-6).

`cholesky_n` is the general-`n` column-by-column variant (Banachiewicz
form). It assumes the input is SPD and does not emit NaN markers; on a
non-SPD matrix the output is undefined.

## General-N Decompositions

`alpha` stability. Square matrices only unless noted.

| Function | Signature | Stability |
|---|---|---|
| `lu_solve` | `[n](a: tensor[n, n, f32], b: tensor[n, f32]) -> tensor[n, f32]` | `alpha` |
| `qr_decompose` | `[n, m](a: tensor[n, m, f32]) -> (tensor[n, n, f32], tensor[n, m, f32])` | `alpha` |
| `svd_n` | `[n](a: tensor[n, n, f32]) -> (tensor[n, n, f32], tensor[n, f32], tensor[n, n, f32])` | `alpha` |

**`lu_solve`** solves `A x = b` via Doolittle LU factorization (no partial
pivoting). Requires all leading principal submatrices of A to be nonsingular —
well-conditioned matrices that need row swaps (e.g. `[[0,1],[1,0]]`) will
produce wrong results, not an error.

**`qr_decompose`** applies Householder reflections and returns `(Q, R)` where
Q is n×n orthogonal and R is n×m upper triangular, so `A = Q R`. Piecewise-smooth
AD (Householder sign choices are not globally smooth).

**`svd_n`** returns `(U, sigma, Vt)` where sigma is the vector of singular
values in descending order and `A ≈ U diag(sigma) Vt`. Uses a fixed 30n Jacobi
sweeps; poorly separated singular values may not fully converge (use abs
tolerance ≥ 1e-3 for sigma comparisons). U is orthogonal only for full-rank A.

## Example

```chelis-fragment
import Nautilus.LinAlg (solve_2x2, l2_norm_vec)

def demo_solve(a: tensor[2, 2, f32], b: tensor[2, f32]) -> f32 =
  l2_norm_vec(solve_2x2(a, b))
```

## Edge cases

- Singular matrices in the fixed-size routines produce NaN results, not exceptions.
- The dimension is enforced at compile time: passing a 3x3 tensor to
  `inv_2x2` is a type error caught by `chelis check`.
- For general-n linear solve use `lu_solve` (Doolittle, no partial pivoting)
  or `cg_solve` (iterative, SPD only). For decompositions use `qr_decompose`
  (Householder QR) or `svd_n` (Jacobi SVD). All three are `alpha` stability.
