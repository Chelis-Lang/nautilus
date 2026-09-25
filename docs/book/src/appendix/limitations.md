# Known Limitations

This page collects the functional limitations of the current release. The
package's scope, and what is deliberately out of it, is set out in
[`spec/scope.md`](https://github.com/Chelis-Lang/nautilus/blob/main/spec/scope.md#deferrals).

## Precision

**Only `Nautilus.Special` runs at f64.** Its functions are generic over the
`Float` dtype family; every other module is f32-only, which gives about seven
significant digits against SciPy's f64. Widening the other modules is tracked
in nautilus#70. Calling Special at f64 widens the arithmetic but keeps the
same approximation coefficients, so several functions gain little; see the
[Precision appendix](precision.md).

**`f16` and `bf16` type-check but give wrong answers.** `Float` is the
narrowest bound Chelis offers, so Special's signatures also admit the 16-bit
dtypes, where its f32-tuned constants break down without a diagnostic
(nautilus#75).

## Differentiation

**No blanket `grad` support.** Nautilus claims differentiability only where a
test exercises it. Solvers built on recursion or `fold`, such as `rk4_solve`,
do not lower under `grad` at the pinned compiler.

**`lm_scalar_nparam` uses a finite-difference Jacobian.** Exact AD through the
full Levenberg-Marquardt solver fails upstream (chelis#2370). See the
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

**`gamma_sample` assumes shape >= 1.** It implements Marsaglia-Tsang without
the boost for shape < 1, and no other sampler covers that range.

## Signal processing

**Six Signal functions are placeholders.** The transform and filter functions
named `*_stub` return NaN tensors until Chelis supports complex numbers;
`fftfreq` is a working real-valued utility. See the
[Signal chapter](../other/signal.md).

## Airy function coverage

**`airy_ai` at large negative x.** There is no asymptotic branch for x < -5;
the power series still covers the oscillatory regime at moderate |x| but
degrades at very large negative x.
