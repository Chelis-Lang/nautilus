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
| `Nautilus.Distributions` | Normal, LogNormal, Uniform, Student-t, Chi-squared, Exponential, Gamma — PDF, CDF, inverse CDF, sampling. `normal_like` is Box-Muller inside this module. | `Nautilus.Special`, `Random` effect |
| `Nautilus.LinAlg` | Pure-Chelis tensor-op compositions: `transpose`, `matmul_wrap`, `gram` (AᵀA), `aat` (AAᵀ), `diag`, `trace_mat`, `trace_scalar`, `l2_norm_vec`, `inner_product`, `frobenius_sq`, `frobenius_norm`, `scale_vec`, `matvec`/`vecmat` (einsum-backed), `det_2x2` and `det_3x3` via trace/Cayley-Hamilton identities. AD flows through tensor-op composition — no hand-written adjoints required. General-n iterative SVD / LU / QR / Cholesky / eig and the Cayley-Hamilton-based `inv_2x2`/`inv_3x3` are tracked as P0.5 follow-ups (need general elementwise tensor construction, currently expressible only via verbose list/fold rewrites). | tensor primitives only — no FFI |

#### P1

| Module | Contents | Key Dependencies |
|---|---|---|
| `Nautilus.Stats` | `mean_vec`, `variance_vec`/`std_vec` with `ddof` parameter, `skewness_vec` / `kurtosis_vec` (scipy-bias / Fisher convention), `median_vec` (via the `sort` builtin), `covariance_scalar` / `correlation_scalar`. Shrinkage estimators deferred (need eigendecomposition). Pure-Chelis fold-over-`to_list` implementations. **Shipped.** Runtime numerical verification blocked on `libchelis_runtime.a` (same as `Distributions.sample`); covered by `chelis check` type-level gate via `src/apismoke.ch:smoke_stats`. | `sort`, `numel`, `enumerate` builtins |
| `Nautilus.Optim` | Convex optimization solvers (QP, SOCP, LP). Differentiable optimization via implicit differentiation through KKT conditions. NOT neural network optimizers (those are `Std.Optim`). **Deferred to P1.5** — requires a general-n linear solver. Candidate path: `cg_solve` added to `Nautilus.LinAlg` as a rank-1 iterative method. | `Nautilus.LinAlg.cg_solve` (planned) |
| `Nautilus.Roots` | `bisection`, `newton` (with `df` argument), `brent` (safeguarded-secant + bisection fallback). Scalar `f32` surface, recursive helpers bounded by `max_iters`. **Shipped** with 6 scipy-parity runtime assertions via `tests/run_numeric_tests.py`. | scalar math, user `f: f32 -> f32` function-typed parameters |
| `Nautilus.ODE` | `euler_step`, `euler_solve`, `rk4_step`, `rk4_solve` over scalar `f32` right-hand sides `f: f32 -> f32 -> f32`. Fixed-step; adaptive step deferred to P1.5. **Shipped** with 5 runtime assertions against analytic decay solution (RK4 reaches ~4e-15 error at n=1000, Euler as expected). `grad(rk4_solve)(y0)` type-checks at the Surf level, but v0.1.3's bare-build C backend emits a placeholder `call()` symbol rather than real AD code for `grad` transforms — the neural-ODE finite-difference parity test is deferred until the runtime-capable build path is shipped. | scalar math, host control flow via bounded recursion, `f: f32 -> f32 -> f32` function-typed parameters |

#### P2

| Module | Contents | Key Dependencies |
|---|---|---|
| `Nautilus.SDE` | SDE solvers (Euler-Maruyama, Milstein). Uses `Random` effect. **Deferred to P2.5** — needs scalar-normal-draw plumbing from a rank-1 `uniform_like` template, same gating as `Distributions.sample` runtime verification. | `Nautilus.ODE`, `Random`, cumsum |
| `Nautilus.Integrate` | `trapezoidal`, `simpsons`, `gauss_legendre_5` (pre-tabulated 5-point Gauss-Legendre quadrature) over `f: f32 -> f32`. Scalar API with recursive helpers. **Shipped** with 9 numerical assertions against analytic integrals (x², exp(-x), sin over [0,π]). | fold, scalar math, function-typed parameters |
| `Nautilus.Interpolation` | Linear, cubic, spline interpolation. **Deferred to P2.5** — needs `sort` + `gather` tensor plumbing that requires the shipped runtime. | sort, gather |
| `Nautilus.Testing` | `z_statistic`, `z_p_value_two_sided` / `_upper` / `_lower`, `normal_ci_half_width`, `chi_squared_p_value`. Scalar ABI routing through `Nautilus.Distributions.{normal_cdf, normal_inv_cdf, chi_squared_cdf}` and `Nautilus.Special.{erf, erfinv}`. **Shipped** with 9 numerical assertions. t-test p-values require regularized incomplete beta (Student-t CDF), deferred to P2.5. | `Nautilus.Distributions`, `Nautilus.Special` |
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
- **Known v0.1.3 shape-checker gap:** `chelis check` does not enforce literal tensor
  dimensions (`tensor[2, 2, f32]`) or element types on call sites — wrong-rank,
  wrong-dim, and wrong-dtype calls into `det_2x2`/`det_3x3`/`matvec`/`gram`/etc. type-
  check cleanly. The "negative tests: wrong input shapes" acceptance bullet is
  therefore deferred to runtime (which is not shipped in v0.1.3) and to a future
  compiler release that tightens dim-literal unification. Tracked as an upstream
  Chelis issue, not a Nautilus bug.
- **Known v0.1.3 unknown-name-silent-compile bug:** the type checker and C backend
  silently accept unresolved function names in expression position, compiling
  expressions like `sub(x, cos(x))` to a no-op that returns `x` (because `cos` is
  not a Chelis builtin and silently resolves to an identity lower). Any user
  `f: f32 -> f32` supplied to `Nautilus.Roots.{bisection,newton,brent}` or
  `Nautilus.ODE.{euler_*,rk4_*}` that references a non-builtin scalar function
  (`cos`, `tan`, `atan`, `cosh`, ...) will silently produce wrong answers. Workaround:
  express cosine via the `sin` builtin as `sin(add(x, π/2))`. The shipped numerical
  harness (`tests/run_numeric_tests.py`) uses that workaround for its `cos_minus_x`
  test case. Tracked as an upstream Chelis issue, not a Nautilus bug.
- **AD composition:** `grad` through `Nautilus.ODE.rk4`, `Nautilus.Optim.solve_qp`,
  `Nautilus.Interpolation.cubic`
- **Effect propagation:** `Nautilus.Distributions.sample` propagates `Random`;
  `Nautilus.Signal` stub propagates correct effect annotations
- **Package gate:** `chelis reef build` produces a valid `.chb`, consumer imports and
  type-checks

### Acceptance Oracle

`cargo test -p chelis-cli phase3j_nautilus_oracle -- --exact` — builds `nautilus` from
source, imports it in a consumer, runs a pipeline that (1) samples data from a
distribution, (2) computes an SVD and verifies reconstruction, (3) fits an ODE,
(4) computes a confidence interval, and (5) checks `grad` through a LinAlg op matches
finite differences.

### Cross-Repo CI

The `nautilus` shell builds and tests both in its own repo (on the `chelis-lang` org)
and in the Chelis monorepo integration run. A green nautilus CI is a prerequisite for a
green Chelis CI.

**Effort:** large. `Nautilus.LinAlg` (nalgebra bridge + AD adjoints) and `Nautilus.Optim`
(QP solver) are the bulk; stats, distributions, and special functions are straightforward.
