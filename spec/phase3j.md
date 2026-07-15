# Phase 3j — Nautilus

Source of truth for the Nautilus shell implementation. Extracted verbatim
from `spec/design/chelis_phase3_plan.md` §3j in the
[`Chelis-Lang/chelis`](https://github.com/Chelis-Lang/chelis) monorepo.
Keep this file in sync with the monorepo section — any change to scope,
module list, test plan, or acceptance oracle lands in both places in the
same change set.

---

## 3j: Nautilus — Numerical Methods, Statistics, and Optimization

**Status:** shipped in the downstream Nautilus repo. `Nautilus v0.7.33` is the
current published shell release as of 2026-07-14; the downstream `reef.toml` and
release gate remain authoritative for its compiler pin and validation state.

**Goal:** A Reef package providing the numerical methods between raw tensor
primitives and domain applications: statistics, distributions, optimization,
integration, linear algebra, differential equations, interpolation, special
functions, and related time-series methods under the `Nautilus` prefix.

**Prerequisite:** 3h (core numeric primitives), 3i (`Std.Time` for time-series
stats), and 3j-pre (compiler release and package infrastructure).

### Accepted Implementation Strategy

- **Pure Chelis throughout.** The shipped package has no C/Rust FFI, no
  compiler special-casing, and no nalgebra backend. Scalar routines, tensor
  algorithms, decompositions, and iterative solvers compose Chelis primitives,
  collections, recursion, and folds.
- **LinAlg is downstream composition.** Fixed-size formulas and general square
  LU, QR, Cholesky, Jacobi SVD/eigendecomposition, and conjugate-gradient
  routines are implemented in Chelis. The general decompositions remain
  `alpha` where their shape, convergence, pivoting, or symmetry assumptions are
  narrower than a full LAPACK-style surface.
- **Differentiability is claimed only where executable coverage proves it.**
  Pure composition makes existing primitive adjoints available, but does not by
  itself prove gradients through every recursive/fold solver or decomposition.
  Nautilus ships no hand-written adjoint registry. New public AD claims require
  a `grad` test against an exact or finite-difference reference.
- **External oracles are a reviewed subset, not the implementation.** Native
  Chelis tests own identities, invariants, edge behavior, and package
  callability. Checked-in SciPy/NumPy goldens cover selected semantics where an
  external reference adds value; CI validates and never regenerates them.
- **Signal remains an explicit deferral.** `Nautilus.Signal` reserves typed
  transform/filter names with NaN-returning stubs until Phase 5f complex-number
  support. The real-valued `fftfreq` helper is functional.

### Shipped Module Surface

| Module family | Shipped contents |
|---|---|
| `Nautilus.Special` | Error, gamma/beta, Bessel, Airy, and elliptic functions. |
| `Nautilus.Distributions` | Continuous and discrete PDF/CDF/inverse-CDF operations plus the supported sampling forms. |
| `Nautilus.LinAlg` | Vector/matrix helpers; fixed 2x2/3x3 determinant, inverse, solve, eig, and Cholesky; general square CG, LU, QR, Cholesky, SVD, and symmetric eig. |
| `Nautilus.Stats`, `Nautilus.Info`, `Nautilus.Testing` | Descriptive and inferential statistics, multiple-testing adjustments, information measures, and confidence/hypothesis helpers. |
| `Nautilus.Distance` | Euclidean, Manhattan, Chebyshev, cosine, and Mahalanobis distances. |
| `Nautilus.Roots`, `Nautilus.Optim`, `Nautilus.Optimize` | Scalar root finding and minimization plus stable wrapper entry points; QP/SOCP/LP are not part of the shipped 3j surface. |
| `Nautilus.Ode`, `Nautilus.Sde` | Fixed/adaptive ODE solvers and caller-noise Euler-Maruyama/Milstein SDE solvers. |
| `Nautilus.Integrate`, `Nautilus.Interpolation` | Newton-Cotes, Gaussian, adaptive, and Romberg integration; linear, Hermite, and natural-cubic interpolation. |
| `Nautilus.CurveFit` | One- and multi-parameter Levenberg-Marquardt. Multi-parameter LM retains a cited finite-difference Jacobian while its exact AD wrapper probes remain blocked. |
| `Nautilus.StateSpace`, `Nautilus.TimeSeries` | Scalar Kalman/local-level routines, EWMA/exponential smoothing, and AR/ARMA/ARIMA point forecasts. |
| `Nautilus.Signal` | Six explicit NaN-returning stubs plus functional `fftfreq`, deferred to Phase 5f complex numbers. |
| `Nautilus.Core` | Package-version metadata; excluded from numerical acceptance counts. |

The downstream `SKILL.md` stability tables are the function-level API inventory.
This phase section owns architecture and acceptance, not a duplicate export list.

### Acceptance Contract

- **Native correctness:** `chelis test tests/` is the primary executable suite.
  It covers mathematical identities, structural invariants, solver recovery,
  tensor paths, edge cases, and public callability without importing an
  external oracle.
- **New public surface:** every new public numerical verb has at least two
  distinct shapes or configurations. One fixture is a smoke test, not
  acceptance.
- **External parity:** each active parity label has at least two distinct
  configurations. The parity project is uv-locked, goldens are reviewed, and
  normal CI cannot regenerate them. Phase 3j does not require a SciPy golden for
  every module or every LinAlg helper.
- **Linear algebra:** identities such as reconstruction, orthogonality,
  residual, and trace/eigenvalue relations are the primary oracle. External
  matrix cases are added when Nautilus intentionally promises SciPy/NumPy
  semantics, not to imply a nonexistent nalgebra bridge.
- **Negative and edge contracts:** compile-time shape/type rejections live in
  `tests_neg/` with diagnostic sidecars. Numerical domain failures represented
  by the API as NaN/Inf (for example singular fixed-size inverse/solve or
  non-SPD fixed-size Cholesky) are positive runtime edge tests, not compiler
  rejection tests.
- **AD:** an advertised differentiable verb has an executable gradient oracle.
  Broad AD-through-LinAlg/ODE/interpolation coverage is an explicit follow-up,
  not retroactive evidence for 3j completion. Current upstream blockers remain
  executable under `tests_blocked/` and are re-probed at every pin bump.
- **Package and documentation:** `chelis reef build` emits non-empty package
  artifacts; API-smoke imports, stability metadata, SKILL examples, mdBook
  examples, and the mdBook build all pass.

### Explicit Deferrals

The following are not hidden 3j completion requirements:

- a nalgebra/LAPACK FFI acceleration layer and hand-written decomposition
  adjoints;
- QP, SOCP, LP, and KKT-based differentiable convex optimization;
- blanket AD support through every recursive/fold numerical solver;
- full external-oracle duplication of the native test corpus;
- complex FFT/STFT/filter implementations before Phase 5f.

Each may be proposed as later scope with its own acceptance oracle. Until then,
downstream docs must not describe it as shipped.

### Acceptance Oracle

The authoritative completion oracle is the **Nautilus release gate**, a named
downstream suite defined by Nautilus's `AGENTS.md` Pin Bump Checklist and
current-status documentation. A release/pin migration runs, against the exact
pin, formatting over all active Chelis sources, `chelis lint --check .`,
`chelis reef build`, positive tests in normal and required serial/debug modes,
negative contracts, conditional blocked probes, the frozen strict parity
project, oracle isolation, surface/stability/example/documentation validators,
`chelis reef conform audit --explain`, and
`chelis reef conform bump-check --base <target>`.

The downstream CI jobs are the merge enforcement for that named suite; the
one-off full local run is retained as pin/release evidence. An old release tag
or an unwired monorepo placeholder is not a substitute for the current gate.

### Cross-Repo CI

Nautilus validates in its own repository and release process. Chelis changes
that affect shell-facing compiler behavior must revalidate the downstream
Nautilus release gate before a compiler release. The monorepo does not claim a
separate `phase3j_nautilus_oracle` that it cannot execute.

---
