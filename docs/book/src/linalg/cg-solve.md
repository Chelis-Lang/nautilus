# Conjugate Gradient Solver

`cg_solve` implements the conjugate gradient method for solving linear
systems Ax = b where A is symmetric positive-definite (SPD). It works
at any dimension `n` and AD flows through the entire solve.

## Signature

```chelis-fragment
def cg_solve[n](
  a_mat: tensor[n, n, f32],
  b: tensor[n, f32],
  x0: tensor[n, f32],
  tol: f32,
  max_iters: i64
) -> tensor[n, f32]
```

**Parameters:**
- `a_mat` -- the SPD coefficient matrix.
- `b` -- the right-hand side vector.
- `x0` -- initial guess (a zero vector is a safe default).
- `tol` -- squared-residual norm threshold for early termination.
- `max_iters` -- upper bound on iteration count.

**Returns:** the approximate solution vector `x`.

## What SPD means

A matrix A is symmetric positive-definite when:
1. A = A^T (symmetric).
2. For every nonzero vector v, v^T A v > 0 (positive-definite).

Common sources of SPD matrices: Gram matrices (A^T A), covariance
matrices, Hessians of strictly convex functions, stiffness matrices in
FEM.

## Convergence behavior

CG converges in at most `n` iterations for an exact-arithmetic n x n
SPD system. In f32, round-off means you may need a few more. The
condition number of A controls the practical convergence rate: a
well-conditioned matrix converges quickly, while an ill-conditioned
one may stall.

The solver terminates when the squared residual norm drops below `tol`,
or after `max_iters` iterations, whichever comes first.

## Example

```chelis-fragment
import Nautilus.LinAlg (cg_solve, gram, matvec, la_vec_sub, l2_norm_vec)

def solve_normal_eq[m, n](a: tensor[m, n, f32],
                          b: tensor[m, f32]) -> tensor[n, f32] = {
  ata = gram(copy(a))
  atb = einsum("ji,j->i", a, b)
  x0 = to_tensor(map(fn (x: f32) -> cast(0.0, f32), to_list(copy(atb))))
  cg_solve(ata, atb, x0, cast(1.0e-10, f32), cast(200, i64))
}
```

## Edge cases

- **Non-SPD input**: CG does not check for positive-definiteness. If A
  is indefinite or non-symmetric, the iteration may diverge silently or
  return a wrong answer.
- **Tolerance units**: `tol` is compared against the squared L2 norm of
  the residual (`r^T r`), not the norm itself. Use `tol = 1e-10` for
  roughly 1e-5 residual norm.
- **Zero initial guess**: passing a zero vector for `x0` is always safe
  and is the standard choice.
