# Known Limitations

This page summarizes the functional limitations of Nautilus as documented
in `nautilus_status.md` Section 6.1.

## Precision

**f32 precision throughout.** All Nautilus functions operate in f32,
providing approximately 6-7 significant digits. scipy runs f64.
Acceptable for f32 workloads; f64 promotion would need upstream Chelis
type support. See the [Precision appendix](precision.md) for per-function
details.

## Missing builtins

**No `cos`, `tan`, `atan`, `abs`, `floor`, `ceil` builtins** in the
Chelis language. Users must express these from primitives:

```chelis-fragment
// cos(x) via sin
cos_x = sin(add(x, cast(1.5707963267948966, f32)))

// abs(x) via conditional
abs_x = if lt(x, cast(0.0, f32)) then neg(x) else x
```

This is a Chelis language limitation, not a Nautilus limitation. Upstream
could add these as builtins.

## Linear algebra

**No general-n eigenvalue.** `lu_solve`, `qr_decompose`, `cholesky_n`, and `svd_n`
are now available at general n (alpha stability). Only 2x2 and 3x3 closed-form
inverses, solves, and eigenvalues remain fixed-size. `cg_solve` provides
iterative SPD linear solve at general n.

**`svd_n` known limitations (alpha):** (a) Uses fixed 30n Jacobi sweeps — poorly
separated singular values may not fully converge; use absolute-error tolerance
≥ 1e-3 for sigma. (b) U columns for null-space directions of rank-deficient A
are zero vectors (not orthonormalized); U is orthogonal only when A has full rank.
Reconstruction `U Σ Vt ≈ A` is correct regardless.

**`lu_solve` has no partial pivoting.** Requires all leading submatrices of A
to be nonsingular. Well-conditioned matrices that need row swaps (e.g.,
`[[0,1],[1,0]]`) produce NaN instead of correct results. Partial pivoting is
planned.

## Optimization

**`newton_minimize_1d` strong-convexity heuristic.** The Newton minimizer
includes a curvature check that can false-positive on very flat minima
(e.g., f(x) = x^4 near x = 0). Use `brent_minimize` or
`golden_section_search` for flat-Hessian targets.

## Signal processing

**Signal module retains six stubs.** The transform/filter helpers return NaN
sentinels under the dated
[Phase 3j explicit deferral](https://github.com/Chelis-Lang/nautilus/blob/main/spec/phase3j.md#explicit-deferrals);
`fftfreq` is a real-valued utility that ships today. The deferred pieces still
depend on upstream complex-number support (Phase 5f). See the
[Signal chapter](../other/signal.md).

## Airy function coverage

**`airy_ai` large negative x.** Power series only; no asymptotic branch
for x < -5. The oscillatory regime works for moderate |x| but degrades
at very large negative x.

## Test harness architecture

**Bare-build path only.** The test harness concatenates `.ch` sources,
strips module directives, and builds a single C translation unit. It does
not exercise the reef package import system at runtime -- only at
`chelis reef build` / `chelis check` time.

**LTO flags are bench-only.** The `-flto -fvisibility=hidden
-Wl,-Bsymbolic` workaround for cross-TU inlining is applied only in
the benchmark script, not in the test harness or any consumer build path.
