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

| Function | Signature |
|---|---|
| `cholesky_2x2` | `(a: tensor[2, 2, f32]) -> tensor[2, 2, f32]` |

Returns the lower-triangular Cholesky factor L such that A = L L^T.
Returns NaN if the matrix is not symmetric positive-definite (symmetry
tolerance: 1e-6).

## Example

```chelis-fragment
import Nautilus.LinAlg (solve_2x2, l2_norm_vec)

def demo_solve(a: tensor[2, 2, f32], b: tensor[2, f32]) -> f32 =
  l2_norm_vec(solve_2x2(a, b))
```

## Edge cases

- Singular matrices produce NaN results, not exceptions.
- The dimension is enforced at compile time: passing a 3x3 tensor to
  `inv_2x2` is a type error caught by `chelis check`.
- For systems larger than 3x3, use `cg_solve` instead.
