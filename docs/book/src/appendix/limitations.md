# Known Limitations

This page collects the functional limitations of the current release. The
package's scope, and what is deliberately out of it, is set out in
[`spec/scope.md`](https://github.com/Chelis-Lang/nautilus/blob/main/spec/scope.md#deferrals).

## Precision

**Only `Nautilus.Special` runs at f64.** Its functions are generic over the
`Float` dtype family; every other module is f32-only, which gives about seven
significant digits. Calling Special at f64 widens the arithmetic but keeps the
same approximation coefficients, so accuracy gains vary by function; see the
[Precision appendix](precision.md).

**`f16` and `bf16` are not reliable for `Nautilus.Special`.** Its `Float`
signatures admit these dtypes, but f32-tuned constants can produce
incorrect values without a diagnostic. Use f32 or f64.

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
when the second derivative at the point it stops on is not above 0.01, which
also rejects genuine but very flat minima (for example f(x) = x^4 near 0). Use
`brent_minimize` or `golden_section_search` for flat targets.

**A non-positive or NaN `tol` now reaches that check, where it used to bypass
it.** `|df(x)| < tol` is false for every gradient at `tol <= 0` or a NaN `tol`,
so those tolerances used to leave the iteration no exit but the stall, which
returned its point uncertified. A zero gradient now counts as converged at any
tolerance, so the curvature check runs. Four families of call therefore return
NaN where they previously returned a number, and in each the number came from
skipping a check that `tol > 0` already applied: a `-inf` second derivative at
the minimiser, one that becomes `-inf` only at the point reached, a curvature
below the 0.01 floor (`0.001*(x-3)^2` from `x0 = 5`, `tol = 0`), and Newton on a
concave objective, which previously returned the maximiser.

**`newton_minimize_1d` trusts `ddf` to be the derivative of `df`.** It never
checks the two against each other, so an inconsistent pair is not diagnosed. A
`ddf` large enough relative to `df` underflows the Newton step to nothing at a
point that is not stationary; the iteration stalls there with everything finite,
the curvature check passes on that large positive value, and the point is
returned as a minimiser. Measured: `(x-3)^2` with the correct `df` and a constant
`ddf = 1e30` returns the starting point. A `-1e30` is rejected instead, but by
the sign test rather than by anything detecting the inconsistency, and a
non-finite `ddf` or a runaway iterate are rejected by the stall's finiteness
requirement. Nothing in a single-point evaluation distinguishes a huge positive
curvature from a genuinely sharp minimum.

**`newton_minimize_1d` trusts `ddf` to be the derivative of `df`.** It never
checks the two against each other, so an inconsistent pair is not diagnosed. A
`ddf` large enough relative to `df` underflows the Newton step to nothing at a
point that is not stationary; the iteration stalls there, the curvature check
passes on that large positive value, and the point is returned as a minimiser.
Measured: `(x-3)^2` with the correct `df` and a constant `ddf = 1e30` returns
the starting point. A non-finite `ddf`, a `-1e30`, or a runaway iterate are all
rejected; this case is not, because nothing in a single-point evaluation
distinguishes it from a genuinely sharp minimum.

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
