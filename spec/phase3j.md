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

- **Pure Chelis** where it's natural: stats, roots, ODE, integration, distributions,
  interpolation. No C FFI, no compiler special-casing. Functional composition over
  existing tensor primitives, scalar math, and collections.
- **nalgebra** as the linear algebra backend. The Rust runtime exposes
  `chelis_svd`, `chelis_cholesky`, `chelis_qr`, `chelis_lu`, `chelis_solve`, `chelis_eig`,
  `chelis_inv`, `chelis_det` backed by the nalgebra crate. Same pattern as BLAS-for-matmul.
  nalgebra is pure Rust, links against BLAS/LAPACK when present, and falls back to a
  pure-Rust implementation otherwise — no Fortran dependency.
- **AD through LinAlg:** nalgebra calls are opaque to the Chelis AD system, so we ship
  hand-written adjoint rules for `svd`, `cholesky`, `solve`, `qr`, `eig`, registered
  alongside the RISC primitive adjoints. Same pattern PyTorch uses for `torch.linalg`.
  References: Giles 2008 (*An extended collection of matrix derivative results for
  forward and reverse mode AD*), Townsend 2016 (*Differentiating the Singular Value
  Decomposition*).
- `Nautilus.Signal` ships as a typed API stub (like `Std.IO.Safetensors` was in 3a) —
  correct signatures and documentation, implementation blocked by complex number support
  in Phase 5f.

`grad` through ODE solvers is the highest-value composition test for the pure-Chelis
tier: `grad(solve_ode(f, x0, t), wrt=x0)` must work for neural ODE research. `grad`
through `svd` via finite differences is the highest-value test for the hand-written
adjoint tier.

### Modules (Priority Tiers)

#### P0 — ship first

| Module | Contents | Key Dependencies |
|---|---|---|
| `Nautilus.Special` | `erf`, `erfinv`, `log_gamma`, `digamma`, `beta`, `lbeta`. Required by Distributions. | scalar math |
| `Nautilus.Distributions` | Normal, LogNormal, Uniform, Student-t, Chi-squared, Exponential, Gamma — PDF, CDF, inverse CDF, sampling. `normal_like` is Box-Muller inside this module. | `Nautilus.Special`, `Random` effect |
| `Nautilus.LinAlg` | SVD, PCA, eigendecomposition, Cholesky, QR, LU, solve, inverse, determinant. nalgebra-backed with hand-written adjoint rules for AD. | runtime nalgebra FFI, adjoint registry |

#### P1

| Module | Contents | Key Dependencies |
|---|---|---|
| `Nautilus.Stats` | Descriptive statistics (variance, skew, kurtosis, median), correlation, covariance, shrinkage estimators | 3h: sort, quantile, einsum |
| `Nautilus.Optim` | Convex optimization solvers (QP, SOCP, LP). Differentiable optimization via implicit differentiation through KKT conditions. NOT neural network optimizers (those are `Std.Optim`). | `Nautilus.LinAlg`, einsum |
| `Nautilus.Roots` | Root finding (Newton-Raphson, bisection, Brent) | scalar math, host control flow |
| `Nautilus.ODE` | ODE solvers (Euler, RK4, adaptive step). Composes with `grad` for neural ODE support. | cumsum, host control flow |

#### P2

| Module | Contents | Key Dependencies |
|---|---|---|
| `Nautilus.SDE` | SDE solvers (Euler-Maruyama, Milstein). Uses `Random` effect. | `Nautilus.ODE`, `Random`, cumsum |
| `Nautilus.Integrate` | Numerical integration (trapezoidal, Simpson's, Gaussian quadrature) | fold, scalar math |
| `Nautilus.Interpolation` | Linear, cubic, spline interpolation | sort, gather |
| `Nautilus.Testing` | Hypothesis testing, confidence intervals, p-values | `Nautilus.Distributions`, `Nautilus.Stats` |
| `Nautilus.Distance` | Euclidean, cosine, Mahalanobis, Manhattan distances over tensor rows | einsum, `Nautilus.LinAlg` |
| `Nautilus.Signal` | Signal processing (FFT, STFT, filtering). **Blocked by complex numbers (Phase 5f) — stub in 3j.** | Phase 5f complex tensors |

### Test Plan

- Each module has at least 3 positive tests comparing against scipy/numpy reference
  values within tolerance
- Negative tests: wrong input shapes, unsupported types, singular matrices for solve,
  non-PSD matrices for Cholesky
- **nalgebra parity:** every `Nautilus.LinAlg` operation is tested against scipy on a
  battery of random + structured matrices
- **AD through LinAlg:** finite-difference check of hand-written adjoints for `svd`,
  `cholesky`, `solve`, `qr`, `eig` on non-degenerate inputs
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
