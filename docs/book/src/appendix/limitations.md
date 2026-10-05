# Known Limitations

This page collects the functional limitations of the current release. The
package's scope, and what is deliberately out of it, is set out in
[`spec/scope.md`](https://github.com/Chelis-Lang/nautilus/blob/main/spec/scope.md#deferrals).

## Precision

**Only `Nautilus.Special` runs at f64.** Its functions are generic over the
`{f32, f64}` dtype set; every other module is f32-only, which gives about seven
significant digits. Calling Special at f64 widens the arithmetic but keeps the
same approximation coefficients, so accuracy gains vary by function; see the
[Precision appendix](precision.md).

**`Nautilus.Special` accepts f32 and f64.** Its dtype-set bound rejects
`f16` and `bf16` at checking because its coefficients do not support them.

## Differentiation

**No blanket `grad` support.** Nautilus claims differentiability only where a
test exercises it. Solvers built on recursion or `fold`, such as `rk4_solve`,
do not lower under `grad` at the pinned compiler. The second spot
derivative of the [Black-Scholes example](../finance/greeks.md) also rejects
during nested `grad` evaluation.

**`lm_scalar_nparam` uses a finite-difference Jacobian.** See the
[Curve Fitting chapter](../other/curvefit.md).

## Linear algebra

**The general-n decompositions are `alpha`.** `lu_solve`, `qr_decompose`,
`cholesky_n`, `svd_n`, and `eig_n` work at any `n` but take square matrices
only. `eig_n` assumes a symmetric input; there is no non-symmetric
eigensolver beyond `eig_2x2_real`. `cg_solve` provides an iterative SPD solve
at any `n`.

**`svd_n` limitations.** It uses a fixed 30n Jacobi sweeps, so poorly
separated singular values may not fully converge; compare singular values with
an absolute tolerance of at least 1e-3. U columns for null-space directions of
a rank-deficient A are zero vectors rather than orthonormalized, so U is
orthogonal only when A has full rank. The reconstruction `U Σ Vt ≈ A` holds
regardless.

**`lu_solve` has no partial pivoting.** It requires every leading principal
submatrix of A to be nonsingular. A well-conditioned matrix that needs a row
swap (for example `[[0,1],[1,0]]`) produces NaN instead of the solution.

## Optimization

**`newton_minimize_1d` curvature check.** The Newton minimizer returns NaN
when the second derivative at the converged point is not above 0.01, which
also rejects genuine but very flat minima (for example f(x) = x^4 near 0). Use
`brent_minimize` or `golden_section_search` for flat targets.

## Sampling

**`gamma_sample` does not produce gamma draws.** For finite shape >= 1
and positive finite scale, its current output is a constant tensor,
`(shape - 1/3) * scale`, independent of the key. It does not cover
shape < 1. `chi_squared_sample` and
`student_t_sample` use this output and do not sample their stated
distributions. See [Sampling](../distributions/sampling.md#sampling-limits).

## Signal processing

**Six Signal functions are placeholders.** The transform and filter functions
named `*_stub` return NaN tensors;
`fftfreq` is a working real-valued utility. See the
[Signal chapter](../other/signal.md).

## Airy function coverage

**`airy_ai` at large negative x.** There is no asymptotic branch for x < -5;
the power series still covers the oscillatory regime at moderate |x| but
degrades at very large negative x.
