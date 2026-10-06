# Known Limitations

This page collects Nautilus's functional limitations. The
package's scope, and what is deliberately out of it, is set out in
[`spec/scope.md`](https://github.com/Chelis-Lang/nautilus/blob/main/spec/scope.md#deferrals).

## Precision

**`Nautilus.Special` accepts f32 and f64; `Nautilus.Rolling` uses f64.**
The other numerical modules use f32, which gives about seven significant
digits. Calling Special at f64 widens the arithmetic but keeps the
same approximation coefficients, so accuracy gains vary by function; see the
[Precision appendix](precision.md).

Special's dtype-set bound rejects
`f16` and `bf16` at checking because its coefficients do not support them.

## Differentiation

**No blanket `grad` support.** Nautilus claims differentiability only where a
test exercises it. Solvers built on recursion or `fold`, such as `rk4_solve`,
do not lower under `grad` at the pinned compiler.

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

**A non-positive or NaN `tol` does not certify a minimum.** A zero gradient
reaches the curvature check at any tolerance. The function returns NaN when
the second derivative is infinite, non-positive, or below the 0.01 curvature
floor, including at a stalled iteration.

**An overflowing `ddf` near a minimiser returns NaN, and a positive `tol` does not
always recover it.** When the Newton step underflows at a point whose gradient is
not exactly zero, the point is accepted if its curvature is finite and rejected if
it is infinite. Finiteness is the only discriminator available at a stall, and the
two cases that must work force the asymmetry: rejecting every non-stationary stall
breaks a real convergence (the quartic `(x^2-2)^2` from `x0 = 1.2` stalls exactly
*at* `sqrt(2.0f32)` with a gradient of `-6.74e-7`), and accepting every stall
returns `x0` whenever `ddf` is infinite, which is the defect this behaviour exists
to fix.

An overflowing curvature near a minimiser can be accepted through the convergence
test when `tol` exceeds `|df(x)|` at that point. Whether such a tolerance is useful
depends on the objective's scale. One ulp above the minimiser of
`(x-3)^2` the gradient is `4.8e-7`: `tol = 1e-6` returns `3.0000002` and
`tol = 1e-9` returns NaN. For `2e38*(x-3)^2`, with both derivatives written
correctly from that same objective, `ddf = 4e38` overflows f32 to `+inf` while
`df = 9.5e31` there stays finite, so no usable tolerance recovers it and the
method returns NaN at `tol = 1e-6` and at `tol = 1.0` alike. A finite
`ddf = 1e30` at the same point returns `3.0000002` at any tolerance, and a `-inf`
curvature is never recoverable at all, because the sign test rejects it at the
converged exit too. Scale the objective so its second derivative is representable
in f32, or use `brent_minimize`.

**A curvature below the 0.01 floor is rejected at a stall.**
`3.1e-4*(x^2-2)^2`, with both derivatives written correctly from it, stalls at
`sqrt(2.0f32)` with a curvature of `0.00496` and a gradient of `-2.09e-10`, so
`tol = 1e-10` and `tol = 0` return NaN. No tolerance recovers this point:
raising `tol` past the gradient routes it to the converged exit, which applies
the same floor.

A `-0.0` start is returned as `-0.0` for `x^2`. Both signs of zero are minimisers,
and `assert_close` cannot tell
them apart; only the sign of a reciprocal can.

**`newton_minimize_1d` trusts `ddf` to be the derivative of `df`.** It never
checks the two against each other, so an inconsistent pair is not diagnosed. A
`ddf` large enough relative to `df` underflows the Newton step to nothing at a
point that is not stationary; the iteration stalls there with everything finite,
the curvature check passes on that large positive value, and the point is
returned as a minimiser. Measured: `(x-3)^2` with the correct `df` and a constant
`ddf = 1e30` returns the starting point. A `-1e30` is rejected instead, but by
the sign test rather than by anything detecting the inconsistency, and a
non-finite `ddf` is rejected by the stall's finiteness requirement, and a
non-finite point by the certification at either exit. Nothing in a single-point evaluation distinguishes a huge positive
curvature from a genuinely sharp minimum.

## Sampling

**Gamma-family samplers have a bounded rejection search.** `gamma_sample`
supports finite shape >= 1 and positive finite scale. Each element tries
at most 64 keyed candidates; it returns NaN if all reject. It does not
cover shape < 1. `chi_squared_sample` and `student_t_sample` use this
sampler and require df >= 2. See
[Sampling](../distributions/sampling.md#sampling-limits).

## Signal processing

**Six Signal functions are placeholders.** The transform and filter functions
named `*_stub` return NaN tensors;
`fftfreq` is a working real-valued utility. See the
[Signal chapter](../other/signal.md).

## Airy function coverage

**`airy_ai` at large negative x.** There is no asymptotic branch for x < -5;
the power series still covers the oscillatory regime at moderate |x| but
degrades at very large negative x.
