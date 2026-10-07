# Conjugate gradient solver

`cg_solve` implements the conjugate gradient method for solving linear
systems Ax = b where A is symmetric positive-definite (SPD). It works
at any dimension `n`, with recursive iterations controlled by a tolerance
and maximum iteration count.

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

All three tensor arguments are taken by value (no `&`), so pass `copy(t)`
for any of them you still need afterwards.

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

`A^T A` is SPD when `A` has full column rank; otherwise it is only
positive semidefinite. A covariance matrix likewise needs a positive
definiteness check before use here. A Hessian of a strictly convex
quadratic is an SPD example.

## Convergence behavior

CG converges in at most `n` iterations for an exact-arithmetic n x n
SPD system. In f32, round-off means you may need a few more. The
condition number of A controls the practical convergence rate: a
well-conditioned matrix converges quickly, while an ill-conditioned
one may stall.

The solver terminates when the squared residual norm drops below `tol`,
or after `max_iters` iterations, whichever comes first. Check the
returned residual if convergence matters to your calculation.

## Example

A least-squares line fit through the normal equations `A^T A x = A^T b`.
The design matrix has a column of ones and a column of x values; the
observations lie exactly on `y = 1 + 2x`.

```chelis-fragment
import Nautilus.LinAlg (cg_solve, gram, matvec, la_vec_sub, l2_norm_vec)

def solve_normal_eq[m, n](a: &tensor[m, n, f32], b: &tensor[m, f32]) -> tensor[n, f32] = {
  ata = gram(a)
  atb = einsum("ji,j->i", a, b)
  x0 = to_tensor(map(fn (x: f32) -> 0.0f32, to_list(copy(atb))))
  cg_solve(ata, atb, x0, 1.0e-10f32, 200i64)
}
def design() -> tensor[4, 2, f32] = to_tensor([[1.0f32, 0.0f32], [1.0f32, 1.0f32], [1.0f32, 2.0f32], [1.0f32, 3.0f32]])
def obs() -> tensor[4, f32] = to_tensor([1.0f32, 3.0f32, 5.0f32, 7.0f32])
coef = solve_normal_eq(design(), obs())
res_norm = l2_norm_vec(la_vec_sub(obs(), matvec(design(), solve_normal_eq(design(), obs()))))
```

```text
coef = tensor(shape=[2], data=[1.0000002, 1.9999999])
res_norm = 2.3841858e-7
```

`gram(a)` is `A^T A`, here `[[4, 6], [6, 14]]`, which is SPD because the two
columns are independent. The solve recovers intercept 1 and slope 2 to f32
rounding. Forming `A^T A` squares the condition number of `A`, so this route
loses accuracy on nearly collinear columns.

## Edge cases

- **Non-SPD input**: CG does not check for positive-definiteness. If A
  is indefinite or non-symmetric, the iteration may diverge silently or
  return a wrong answer.
- **Tolerance units**: `tol` is compared against the squared L2 norm of
  the residual (`r^T r`), not the norm itself. Use `tol = 1e-10` for
  roughly 1e-5 residual norm.
- **Zero initial guess**: passing a zero vector for `x0` is always safe
  and is the standard choice.
- **No convergence flag**: the result is the last iterate whether or not
  the residual reached `tol`. `max_iters <= 0` returns `x0` unchanged. Compute
  `b - A x` afterwards, as the example does, when the answer matters.
- **NaN**: a NaN in `a_mat`, `b`, or `x0` propagates to the result.
