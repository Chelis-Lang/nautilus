# LinAlg Module Overview

The `Nautilus.LinAlg` module provides linear algebra primitives built
entirely from pure Chelis tensor operations. Because nothing goes
through FFI or opaque intrinsics, AD (automatic differentiation) via
`grad` flows through every function automatically.

## What is included

- **Fixed-size closed-form solvers** for 2x2 and 3x3 systems: inversion,
  determinant, solve, eigenvalues, Cholesky (see [Small-N](small-n.md)).
- **General-n iterative solver**: conjugate gradient for symmetric
  positive-definite systems (see [CG Solve](cg-solve.md)).
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

## Example: matrix-vector product and norm

```chelis-fragment
def residual_norm[n](a: tensor[n, n, f32], x: tensor[n, f32],
                     b: tensor[n, f32]) -> f32 = {
  ax = matvec(a, x)
  r = la_vec_sub(b, ax)
  l2_norm_vec(r)
}
```

## Notes

- All inputs and outputs are `f32` tensors. Do not pass `f64`.
- Tensor arguments follow linear-use discipline. Use `copy(t)` when a
  tensor is consumed more than once.
- The closed-form inverses use the Cayley-Hamilton theorem, not Cramer's
  rule. They return NaN-filled matrices when the determinant is near zero
  (threshold: 1e-30).
- `matvec` and `vecmat` use `einsum` internally, so they work at any
  dimension `n`.
