# Phase 3j — Nautilus

Source of truth for the Nautilus shell implementation. Extracted verbatim
from `spec/design/chelis_phase3_plan.md` §3j in the
[`Chelis-Lang/chelis`](https://github.com/Chelis-Lang/chelis) monorepo.
Keep this file in sync with the monorepo section — any change to scope,
module list, test plan, or acceptance oracle lands in both places in the
same change set.

---

## 3j: Nautilus — Numerical Methods, Statistics, and Optimization

**Goal:** A reef package providing the numerical methods that sit between raw tensor
primitives and domain applications. The scipy competitor for Chelis — `scipy.stats` +
`scipy.optimize` + `scipy.integrate` + `scipy.linalg` + `scipy.special` under one shell.

**Prerequisite:** 3h (core numeric primitives), 3i (`Std.Time` for time-series stats),
3j-pre (compiler release binary, expanded `Std.Nn`/`Std.Loss`/`Std.Init` surface).

### Implementation Strategy

- **Pure Chelis** for everything in P0: stats, roots, ODE, integration, distributions,
  interpolation, **and linear algebra**. No C FFI, no compiler special-casing.
  Functional composition over existing tensor primitives, scalar math, and collections.
- **AD for free via tensor-op composition.** Because `Nautilus.LinAlg` is built from
  `matmul`, `permute`, `diagonal`, `trace`, `einsum`, and the elementwise/reduction
  primitives, `grad(linalg_op)` flows through composition without any hand-written
  adjoint registry. No upstream Rust/C-ABI/type-env work is required to ship LinAlg as
  a downstream package, and no cross-repo coordination is needed for v0.1.3 P0.
- **Optional nalgebra acceleration** is recorded as a future enhancement, not a P0
  prerequisite. It would require upstream `chelis_svd`/`chelis_cholesky`/etc. C-ABI
  exposure plus hand-written adjoints (Giles 2008, Townsend 2016), and is only worth
  the cross-repo coupling once profiling shows a real bottleneck on a target workload.
- `Nautilus.Signal` ships as a typed API stub (like `Std.IO.Safetensors` was in 3a) —
  correct signatures and documentation, implementation blocked by complex number support
  in Phase 5f.

`grad` through ODE solvers is the highest-value composition test for the pure-Chelis
tier: `grad(solve_ode(f, x0, t), wrt=x0)` must work for neural ODE research. `grad`
through `Nautilus.LinAlg.cg_solve` and through tensor-composed `det` / `gram` is the
highest-value test for the LinAlg tier — and lands automatically because the underlying
RISC primitives already carry adjoints.

### Modules (Priority Tiers)

#### P0 — ship first

| Module | Contents | Key Dependencies |
|---|---|---|
| `Nautilus.Special` | `erf`, `erfinv`, `log_gamma`, `digamma`, `beta`, `lbeta`. Required by Distributions. | scalar math |
| `Nautilus.Distributions` | Normal, LogNormal, Uniform, Student-t, Chi-squared, Exponential, Gamma — PDF, CDF, inverse CDF, sampling. `normal_like` is Box-Muller inside this module. **P4 additions**: Poisson, Binomial, Beta, F, Weibull (PDF/CDF for all, plus Weibull inv_cdf in closed form). Poisson and Binomial CDFs route through the existing `gamma_cdf` and `betai` helpers for numerical stability across the full domain. | `Nautilus.Special`, `Random` effect |
| `Nautilus.LinAlg` | Pure-Chelis tensor-op compositions: `transpose`, `matmul_wrap`, `gram` (AᵀA), `aat` (AAᵀ), `diag`, `trace_mat`, `trace_scalar`, `l2_norm_vec`, `inner_product`, `frobenius_sq`, `frobenius_norm`, `scale_vec`, `matvec`/`vecmat` (einsum-backed), `det_2x2` and `det_3x3` via trace/Cayley-Hamilton identities. **P2.5 additions**: rank-1 vector helpers `la_vec_add`, `la_vec_sub`, `la_vec_saxpy`, and `cg_solve` — iterative PSD linear solver via conjugate gradient. **P3 additions**: Cayley-Hamilton-based closed forms for small fixed sizes: `inv_2x2`, `inv_3x3`, `solve_2x2`, `solve_3x3`, `eig_2x2_real` (via quadratic formula for real eigenvalues; returns NaN tuple if discriminant is negative), `cholesky_2x2` (returns NaN if input is not symmetric-PSD). These use the `range + map + to_tensor` + `einsum("i,j->ij", ...)` outer-product trick to build `2x2` and `3x3` identity matrices at runtime (a pattern previously untested in Chelis — verified clean in the P3 step-zero probes). AD flows through tensor-op composition throughout. **v0.2.0 additions**: `cholesky_n`, `lu_solve`, `qr_decompose`, and `svd_n` ship at general n (alpha stability) — all implemented in pure Chelis via fold/recursion without FFI. General-n `eig` remains deferred. | tensor primitives only — no FFI |

#### P1

| Module | Contents | Key Dependencies |
|---|---|---|
| `Nautilus.Stats` | `mean_vec`, `variance_vec`/`std_vec` with `ddof` parameter, `skewness_vec` / `kurtosis_vec` (scipy-bias / Fisher convention), `median_vec` (via the `sort` builtin), `covariance_scalar` / `correlation_scalar`. **P4 additions**: `min_vec`, `max_vec`, `range_vec`, `quantile_vec` (with linear interpolation between adjacent sorted elements, matching numpy default), `percentile_vec`, `trimmed_mean_vec`. Shrinkage estimators remain deferred. Pure-Chelis fold-over-`to_list` implementations throughout. Runtime numerical verification blocked on `libchelis_runtime.a`; covered by `chelis check` type-level gate via `src/apismoke.ch:smoke_stats` + `smoke_stats_p4`. | `sort`, `numel`, `enumerate` builtins |
| `Nautilus.Optim` | Scalar 1D optimizers: `golden_section_search`, `brent_minimize` (safeguarded parabolic/golden-section alternation), `gradient_descent_1d`, `newton_minimize_1d`. **Shipped in P2.5** with 7 scipy-parity runtime assertions (parabola argmin at 2.0, quartic argmin at √2). Full convex optimization (QP, SOCP, LP, KKT-based differentiable optim) remains deferred — it needs tensor-valued inputs which are gated by the runtime. `Nautilus.LinAlg.cg_solve` (shipped P2.5 below) provides the general-n linear solve they would need once the runtime ships. | scalar math, function-typed parameters, `Nautilus.LinAlg.cg_solve` |
| `Nautilus.Roots` | `bisection`, `newton` (with `df` argument), `brent`. Scalar `f32` surface, recursive helpers bounded by `max_iters`. **P3 upgrade**: `brent` now implements full Brent-Dekker with inverse quadratic interpolation (three-point IQI), secant fallback when IQI is degenerate, and bisection fallback when any of the five Brent safeguards fire (IQI step outside the bracket, step too large relative to previous bracket, previous bracket already small, etc.). Converges on the red-team's multi-root polynomial `(x-3)(x-3.1)(x-3.2)` within 200 iterations (the previous alternating bisect/secant variant took 5000+). **Shipped** with 6 scipy-parity runtime assertions via `tests/run_numeric_tests.py`; public signature unchanged so no consumer churn. | scalar math, user `f: f32 -> f32` function-typed parameters |
| `Nautilus.ODE` | `euler_step`, `euler_solve`, `rk4_step`, `rk4_solve` over scalar `f32` right-hand sides `f: f32 -> f32 -> f32`. Fixed-step; adaptive step deferred to P1.5. **Shipped** with 5 runtime assertions against analytic decay solution (RK4 reaches ~4e-15 error at n=1000, Euler as expected). `grad(rk4_solve)(y0)` type-checks at the Surf level, but v0.1.3's bare-build C backend emits a placeholder `call()` symbol rather than real AD code for `grad` transforms — the neural-ODE finite-difference parity test is deferred until the runtime-capable build path is shipped. | scalar math, host control flow via bounded recursion, `f: f32 -> f32 -> f32` function-typed parameters |

#### P2

| Module | Contents | Key Dependencies |
|---|---|---|
| `Nautilus.SDE` | `euler_maruyama_fixed`, `milstein_fixed` over scalar drift `f: f32 -> f32 -> f32` + diffusion `g: f32 -> f32 -> f32` + caller-supplied N(0,1) noise tensor. Milstein additionally takes `dg_dy` for the second-order correction term. **Shipped in P3** as caller-supplied-noise variants — the `_fixed` suffix reserves the clean `euler_maruyama` / `milstein` names for a future autonomous-sampling version once upstream Chelis exposes a scalar-level `Random` primitive or stable `uniform_like` template plumbing. Implementation uses a `fold` over `to_list(noise)` with a `(y, t)` accumulator (verified that Chelis `fold` closures capture function-typed free variables cleanly — that was an open question before Track 1 shipped). Runtime numerical verification deferred with the other tensor-input modules: caller would need the `libchelis_runtime.a` runtime to construct a noise tensor at bare-build time. Goldens checked in under `tests/goldens/sde/` for future runtime-enabled harness wiring; type-level gate via `src/apismoke.ch:smoke_sde`. | scalar math, function-typed parameters, fold-closure-over-fn, `uniform_like` (at the Chelis level, not the runtime) |
| `Nautilus.Integrate` | `trapezoidal`, `simpsons`, `gauss_legendre_5`, `adaptive_simpson`, `romberg_5`, `gauss_legendre_10`. **P4 additions**: `gauss_hermite_10` for `∫_{-∞}^∞ e^{-x²} f(x) dx` and `gauss_laguerre_10` for `∫_0^∞ e^{-x} f(x) dx` — pre-tabulated 10-point weights and nodes from Abramowitz-Stegun tables. P3 red-team fixes: `adaptive_simpson` now caps `max_depth` at 30 internally (stack-overflow guard) and clamps `tol` below `1e-7` to honor f32 unit roundoff. **Shipped** with 9 original P2 assertions + 12 P3 + 7 new P4 Hermite/Laguerre runtime assertions. | fold, scalar math, function-typed parameters |
| `Nautilus.Interpolation` | `linear_interp_uniform[n]` (clamp-to-edge on uniform grid), `linear_interp_sorted[n]` (clamp-to-edge on an externally-sorted grid via recursive fold-over-enumerate), `cubic_hermite` (closed-form Hermite cubic on a single interval). **Shipped in P2.5.** `cubic_hermite` is scalar and runtime-tested with 5 scipy-parity assertions (7 from the agent's verification); the tensor-input variants are type-checked via `smoke_interpolation` and deferred for runtime verification with the other tensor-path modules until `libchelis_runtime.a` ships. Spline interpolation (cubic spline fit) is deferred — it needs a tridiagonal solve, which `Nautilus.LinAlg.cg_solve` can provide but spline-fit coefficient construction also needs tensor plumbing. | scalar math, fold-over-enumerate, `to_tensor/to_list` |
| `Nautilus.Testing` | `z_statistic`, `z_p_value_two_sided` / `_upper` / `_lower`, `normal_ci_half_width`, `chi_squared_p_value` (P2). **P2.5 additions**: `t_statistic_one_sample`, `t_statistic_two_sample_pooled`, `welch_t_statistic`, `welch_t_df`, `t_p_value_two_sided` / `_upper` / `_lower` routing through `Nautilus.Distributions.student_t_cdf` (new, implemented via regularized incomplete beta via Lentz continued fraction in `Nautilus.Distributions.betai`/`betacf`). **Shipped** with 9 original P2 assertions + 60+ new P2.5 assertions (Student-t CDF at three df × 17 query points, plus t-test cases). | `Nautilus.Distributions.{normal_cdf, normal_inv_cdf, chi_squared_cdf, student_t_cdf}`, `Nautilus.Special.{erf, erfinv}` |
| `Nautilus.Distance` | `squared_euclidean`, `euclidean`, `manhattan`, `chebyshev`, `cosine_similarity` / `cosine_distance`, `mahalanobis` / `mahalanobis_squared`. Fold-over-zip patterns for the elementwise distances; Mahalanobis uses `Nautilus.LinAlg.matvec` + `inner_product`. **Shipped** with type-level gate via `src/apismoke.ch:smoke_distance` (runtime numerical verification deferred same as LinAlg). | `Nautilus.LinAlg` |
| `Nautilus.Signal` | Typed API stubs: `fft_magnitude_stub`, `ifft_magnitude_stub`, `stft_magnitude_stub`, `lowpass_stub`, `highpass_stub`, `bandpass_stub`, `fftfreq`. All return NaN sentinels except `fftfreq` which is a pure-real bin-frequency helper. Real implementations blocked by complex-number support in Phase 5f. **Shipped** as typed stubs per spec. | Phase 5f complex tensors |

### Test Plan

- Each module has at least 3 positive tests comparing against scipy/numpy reference
  values within tolerance
- Negative tests: wrong input shapes, unsupported types, singular matrices for solve,
  non-PSD matrices for Cholesky
- **scipy/numpy parity:** every `Nautilus.LinAlg` operation is tested against
  scipy/numpy on a battery of random + structured matrices via checked-in JSON goldens
  (`tests/goldens/linalg/`)
- **AD through LinAlg:** finite-difference check that `grad` through composed tensor
  ops agrees with numerical differences on `det_2x2`, `det_3x3`, `inner_product`,
  `frobenius_sq`, and `cg_solve` (P0.5)
- **Literal-dim shape-checker gap: FIXED in v0.1.7.** v0.1.3–v0.1.5
  accepted calls like `det_2x2(a: tensor[3, 3, f32])` with score 1.0
  and zero errors. v0.1.7 emits `DimensionMismatch: Lit(2) vs Lit(3)`
  at `chelis check` time (score drops to ~0.86). The "negative tests:
  wrong input shapes" acceptance bullet is now satisfied at compile
  time, not deferred. Tracked upstream as `docs/UPSTREAM_BUGS.md` Bug 2,
  re-verified against v0.1.7.
- **LinAlg / Distance / SDE tensor-path runtime verification: UNBLOCKED in v0.1.7.**
  v0.1.5 shipped `lib/libchelis_runtime.a` in the release tarball
  (fixing the link failure from v0.1.4 — `docs/UPSTREAM_BUGS.md` Bug 3b).
  v0.1.7 fixed the main-entry wrapper emission symptom
  (`docs/UPSTREAM_BUGS.md` Bug 3c) — a minimal
  `def main(x, y: tensor[4, f32]) -> ... = combine(x, y)` now emits
  an entry point with `n_in == 2`, correctly-labeled slots, and a
  full OpenMP elementwise-add loop. Tensor-on-tensor `add`/`sub`/`mul`
  lowering also works (Bug 3a superseded). ~100+ scipy-parity
  assertions on `cg_solve`, `frobenius_*`, `la_vec_*`, `inv_2x2`,
  `inv_3x3`, `solve_*`, `cholesky_2x2`, and the `Nautilus.Distance` /
  `Nautilus.SDE` / `Nautilus.Stats` / `Nautilus.Interpolation`
  tensor-path tests are no longer upstream-blocked. In this shell repo
  they are wired into `tests/run_numeric_tests.py` and counted in the
  `895 / 895` clean-HEAD pass on the pinned toolchain.
- **Unknown-name silent-compile bug: FIXED in v0.1.4 (still fixed in v0.1.7).** v0.1.3's type checker and
  C backend silently accepted unresolved function names in expression position,
  compiling `sub(x, cos(x))` to a no-op that returned `x`. v0.1.4 now emits
  `UnboundVariable: cos` from `chelis check` and halts the build, so any user
  `f: f32 -> f32` supplied to Roots / ODE / Integrate / Optim that references a
  non-builtin scalar function is rejected at check time instead of silently
  producing wrong answers. A legacy workaround (`sin(add(x, π/2))` as a
  cos-equivalent) is preserved in `tests/run_numeric_tests.py::cos_minus_x` for
  regression coverage — it no longer has to be a workaround, just a test case.
- **`Nautilus.Optim.newton_minimize_1d` strong-convexity assumption:** Newton's method
  for minimization can converge toward a stationary point that is a saddle or maximum,
  not a minimum. To detect this, the implementation requires that `ddf(x_final) > 1e-2`
  at termination — a heuristic "strong-convexity floor". This catches classic failure
  cases like `f(x)=x^3` where Newton halves toward the saddle at x=0 (at termination,
  `ddf(x) ≈ 0.006 < 1e-2`, so the routine correctly returns NaN). It will false-positive
  on true minima with very flat Hessians (e.g. `f(x)=x^4` near x=0 where `f''(0)=0`);
  callers targeting very-flat minima should use `brent_minimize` or `golden_section_search`
  instead.
- **AD composition:** `grad` through `Nautilus.ODE.rk4`, `Nautilus.Optim.solve_qp`,
  `Nautilus.Interpolation.cubic`
- **Effect propagation:** `Nautilus.Distributions.sample` propagates `Random`;
  `Nautilus.Signal` stub propagates correct effect annotations
- **Package gate:** `chelis reef build` produces a valid `.chb`, consumer imports and
  type-checks

### Acceptance Oracle

**Repo-local release gate:** `chelis reef build && python tests/run_static_checks.py &&
python scripts/gen_goldens.py --check && CHELIS_BIN=chelis python tests/run_numeric_tests.py &&
CHELIS_BIN=chelis python tests/run_skill_checks.py &&
CHELIS_BIN=chelis python scripts/validate_book_examples.py`

This shell repo does not contain the upstream Cargo workspace, so the monorepo-side
integration oracle is not directly runnable here. The upstream integration gate remains
`cargo test -p chelis-cli phase3j_nautilus_oracle -- --exact` in the Chelis monorepo,
where Nautilus is consumed as a downstream shell package rather than tested in isolation.

### Cross-Repo CI

The `nautilus` shell builds and tests both in its own repo (on the `chelis-lang` org)
and in the Chelis monorepo integration run. A green nautilus CI is a prerequisite for a
green Chelis CI.

**Effort:** large. `Nautilus.LinAlg` (nalgebra bridge + AD adjoints) and `Nautilus.Optim`
(QP solver) are the bulk; stats, distributions, and special functions are straightforward.
