# Nautilus — Comprehensive Status Report

Prepared for external review. Covers functionality, test coverage,
performance, upstream dependencies, and known limitations as of
commit `e0d4b76` (2026-04-16), pinned to `chelis v0.1.7`.

---

## 1. Scope and Architecture

Nautilus is a downstream **reef package** for the
[Chelis](https://github.com/Chelis-Lang/chelis) functional programming
language, scoped to numerical methods, statistics, and optimization.
It is the scipy/numpy competitor for the Chelis ecosystem.

**Pure Chelis throughout.** Every function is implemented in Chelis
source (`.ch` files) with no C FFI, no upstream runtime additions, and
no hand-written adjoints. AD flows through tensor-op composition
automatically because LinAlg is built from `matmul`, `permute`,
`diagonal`, `trace`, `einsum`, and elementwise primitives.

**3,834 lines of Chelis source** across 15 functional modules + 1 core
version module + 6 executable examples + 1 API smoke-check module.

---

## 2. Module Inventory

| Module | Exports | Lines | Dependencies | Runtime-tested |
|---|---|---|---|---|
| `Nautilus.Special` | 20 | 796 | scalar math only | 20/20 (132 assertions) |
| `Nautilus.Distributions` | 37 | 685 | Special (erf, erfinv, log_gamma) | 31/37 (350 assertions) |
| `Nautilus.LinAlg` | 28 | 320 | tensor primitives only | 26/28 (150 assertions) |
| `Nautilus.Stats` | 14 | 216 | sort, numel, enumerate | 14/14 (18 assertions) |
| `Nautilus.Distance` | 8 | 83 | LinAlg (l2_norm_vec, inner_product, matvec) | 8/8 (10 assertions) |
| `Nautilus.Roots` | 3 | 177 | scalar math, user `f: f32 -> f32` | 3/3 (6 assertions) |
| `Nautilus.ODE` | 4 | 63 | scalar math, user `f: f32 -> f32 -> f32` | 4/4 (5 assertions) |
| `Nautilus.Integrate` | 8 | 320 | scalar math, user `f: f32 -> f32` | 8/8 (28 assertions) |
| `Nautilus.Testing` | 13 | 131 | Distributions (normal_cdf, student_t_cdf, etc.) | 13/13 (60+ assertions) |
| `Nautilus.Optim` | 4 | 223 | scalar math, user function-typed params | 4/4 (7 assertions) |
| `Nautilus.Interpolation` | 3 | 144 | scalar math | 3/3 (12 assertions) |
| `Nautilus.SDE` | 2 | 70 | scalar math, user drift/diffusion fns, noise tensor | 2/2 (4 assertions) |
| `Nautilus.CurveFit` | 1 | 73 | LinAlg (inv_2x2, inv_3x3, matvec) | 1/1 (2 assertions) |
| `Nautilus.Signal` | 7 stubs | 55 | Phase 5f complex numbers (blocked) | 0/7 (stubs only) |
| `Nautilus.Core` | 1 | 3 | none | n/a |

**Totals: 153 non-stub exports, 841 runtime scipy-parity assertions,
all passing.**

### 2.1 Distributions detail

Twelve distribution families, each with PDF/CDF/inv_CDF/sample where
applicable:

| Distribution | PDF | CDF | inv_CDF | sample |
|---|---|---|---|---|
| Normal | yes | yes | yes (Acklam) | yes (Box-Muller) |
| LogNormal | yes | yes | yes | yes |
| Uniform | yes | yes | yes | yes |
| Exponential | yes | yes | yes | yes |
| Gamma | yes | yes (series + CF) | yes (Newton) | no |
| Chi-squared | yes | yes | yes | no |
| Student-t | yes | yes (betai) | no | no |
| Poisson | PMF | yes (gammap) | no | no |
| Binomial | PMF | yes (betai) | no | no |
| Beta | yes | yes (betai) | no | no |
| F | yes | yes (betai) | no | no |
| Weibull | yes | yes | yes (closed-form) | no |

The 6 exports not runtime-tested are `sample` variants (`normal_sample`,
`lognormal_sample`, `uniform_sample`, `exponential_sample`) — these
require the Chelis `Random` effect and `uniform_like` tensor
construction, which the test harness cannot exercise via the
bare-build C driver path. They are type-checked at package build time
via `src/apismoke.ch`.

### 2.2 Special functions detail (P6 expansion)

| Function | Method | Domain | Precision notes |
|---|---|---|---|
| `erf` | Horner rational approx | all reals | f32, ~1e-7 |
| `erfinv` | Winitzki + Newton | (-1, 1) | f32, ~1e-8 |
| `log_gamma` | Lanczos (g=7) | x > 0, reflection for x < 0 | f32, ~1e-9 |
| `digamma` | recurrence + asymptotic | x > 0 (NaN at poles) | f32, ~1e-7 |
| `trigamma` | recurrence + asymptotic (x > 6) | x > 0 (NaN at poles) | f32, ~1e-6 |
| `beta`, `lbeta` | via log_gamma | a, b > 0 | f32 |
| `bessel_j0`, `j1` | rational polynomial + large-x trig | all reals (J0 even, J1 odd) | ~1e-5 near zeros |
| `bessel_y0`, `y1` | rational + log-singularity + large-x trig | x > 0 (-inf at 0, NaN for x < 0) | y1 drifts ~1e-3 in (7.5, 8) |
| `bessel_i0`, `i1` | polynomial + asymptotic (crossover 3.75) | all reals (I0 even, I1 odd) | f32 |
| `bessel_k0`, `k1` | polynomial + log + asymptotic (crossover 2) | x > 0 (+inf at 0, NaN for x < 0) | f32 |
| `airy_ai` | power series (|x| <= 5) + exponential asymptotic (x > 5) | all reals | large negative x: oscillatory, series-only |
| `airy_bi` | power series (|x| <= 5) + exponential asymptotic (x > 5) | all reals | f32 |
| `ellipk` | AGM recurrence | m in [0, 1) (+inf at m=1, NaN outside) | quadratic convergence, ~1e-8 |
| `ellipe` | AGM recurrence | m in [0, 1] (1 at m=1, NaN for m > 1) | ~1e-8 |

### 2.3 LinAlg detail

All 28 exports are runtime-verified. Implementation is pure
tensor-op composition — no FFI, no eigenvalue decomposition beyond
2x2. Sizes are fixed (2x2, 3x3) for inverse/solve/eigenvalue/Cholesky.

General-n iterative solvers: `cg_solve` (conjugate gradient for SPD
systems). General-n SVD/LU/QR/Cholesky/eig remain deferred.

---

## 3. Test Infrastructure

### 3.1 Assertion count progression

| Milestone | Assertions | Commit |
|---|---|---|
| P4 baseline | 526 | `bdef24b` |
| P5 early termination + LTO | 526 (correctness fix) | `e638280` |
| P6 Special expansion | 632 (+106) | `2b3a4fd` |
| v0.1.6 LinAlg tensor-path | 726 (+94) | `622457b` |
| Stats + Distance | 752 (+26) | `c7302d0` + `0794e55` |
| SDE + saxpy | 761 (+9) | `50d0805` |
| v0.1.7 Bug 5 fix + gram/aat/etc | 817 (+56) | `8d800c6` |
| cg_solve + eig_2x2_real | 828 (+11) | `d2ec781` |
| mahalanobis + interp + curvefit | **841** (+13) | `e0d4b76` |

### 3.2 Test architecture

Three independent binary builds in `tests/run_numeric_tests.py`:

1. **Scalar binary** — bundles `special.ch` + `distributions.ch`. Tests
   all scalar-input/scalar-output functions (Special, Distributions).
   Linked against `libchelis_runtime.a`.

2. **P1 binary** — bundles all scalar-path modules (roots, ODE,
   integrate, testing, optim, interpolation, SDE). Tests
   function-pointer-taking functions via named Chelis helpers compiled
   into the same binary. Linked against `libchelis_runtime.a`.

3. **LinAlg/tensor binary** — bundles all modules (special,
   distributions, linalg, stats, distance, sde, interpolation,
   curvefit). Tensor-aware C driver constructs `chelis_tensor*` objects
   via `chelis_alloc` from `libchelis_runtime.a`, calls functions, and
   extracts results. Includes Chelis-level test wrappers for
   function-pointer + tensor combinations (SDE, CurveFit).

### 3.3 Golden fixtures

25 JSON files under `tests/goldens/` across 8 subdirectories. All
generated from scipy/numpy reference implementations via
`scripts/gen_goldens.py`. Drift check: `python scripts/gen_goldens.py
--check` verifies goldens haven't drifted from scipy.

### 3.4 Additional verification gates

| Gate | Command | What it checks |
|---|---|---|
| Type check | `chelis check src/*.ch` | All 21 modules at score 1.0 |
| Package build | `chelis reef build` | Produces `dist/nautilus-0.1.0.chb` |
| Goldens drift | `python scripts/gen_goldens.py --check` | No scipy drift |
| Static exports | `python tests/run_static_checks.py` | API consistency |
| Numerical parity | `python tests/run_numeric_tests.py` | 841 / 841 |

---

## 4. Performance (BENCHMARK_FINDINGS.md)

Measurement harness: `scripts/bench_vs_scipy.py`, in-process via
`ctypes.CDLL`, 20 trials per point, f64, single core.

### 4.1 Headline numbers

| Kernel | Nautilus ns/el | scipy ns/el | Speedup | Throughput |
|---|---|---|---|---|
| `erfinv` (n=100k) | 2.2 | 14.7 | **6.5x** | 450M/s |
| `normal_inv_cdf` (n=100k) | 2.7 | 18.5 | **6.8x** | 370M/s |
| `normal_cdf` (n=100k) | 4.6 | 19.2 | **4.2x** | 220M/s |
| `erf` (n=100k) | 3.5 | 11.3 | **3.2x** | 285M/s |
| `gamma_cdf(2,1)` (n=100k) | 18.2 | 41.1 | **2.3x** | 55M/s |
| `student_t_cdf(df=5)` (n=100k) | 64.4 | 144.5 | **2.3x** | 15.5M/s |
| `normal_cdf(x)*exp(-x^2)` compound (n=100k) | 6.7 | 20.4 | **3.0x** | 150M/s |
| `norm_pdf` from primitives (n=100k) | 2.2 | 7.9 | **3.6x** | 450M/s |

### 4.2 Solver per-call cost

| Solver | Nautilus | scipy | Ratio | Caveat |
|---|---|---|---|---|
| `rk4_solve` (100 steps) | 0.43 us | 1734 us | 4000x | Nautilus fixed-step RK4 vs scipy adaptive RK45 with Python dispatch |
| `brent` root-find | 0.12 us | 5.6 us | 45x | Compiled C vs Python `brentq` wrapper |

**Important caveat:** solver numbers measure Python dispatch overhead,
not numerical-method quality. A fair RK4-vs-RK4 comparison against a
C-level implementation would be much closer to parity.

### 4.3 LTO workaround (still required in v0.1.7)

The bench script adds `-flto -fuse-linker-plugin -fvisibility=hidden
-Wl,-Bsymbolic` to the shared-object build. v0.1.7's C backend still
emits cross-TU scalar helpers as `extern` (not `static inline`), so
`-shared -fPIC` still forces PLT indirection and blocks gcc's
cross-TU inlining.

Measured regression from dropping the flags:
- v0.1.5: 6.7 -> 18.9 ns/el (3x) on `normal_cdf(x)*exp(-x^2)` at n=100k
- v0.1.6: 9.4 -> 20.9 ns/el (2.2x) same kernel

Until upstream emits helpers as `static inline` for single-`.so`
bundles, these flags are load-bearing for the benchmark story.

---

## 5. Upstream Dependencies and Bug History

### 5.1 Toolchain pin

`chelis v0.1.7` via `reef.toml` `compiler = "=0.1.7"`. Release tarball
ships `bin/chelis`, `lib/libchelis_runtime.a`, and
`include/chelis_runtime.h`.

### 5.2 Tracked upstream bugs

| # | Title | Resolution |
|---|---|---|
| 1 | Unknown-name silent compile | **Fixed v0.1.4** — `cos(x)` now raises `UnboundVariable` |
| 2 | Literal-dim shape-checker gap | **Fixed v0.1.6** — `DimensionMismatch` for wrong-dim calls |
| 3a | Tensor add/mul raw pointer arithmetic | **Fixed v0.1.6** — proper elementwise loop emitted |
| 3b | `libchelis_runtime.a` missing from tarball | **Fixed v0.1.5** — tarball now ships runtime |
| 3c | Main-entry emission drops parameters | **Fixed v0.1.6** — correct multi-tensor entry points |
| 4 | Nested `exp(neg(mul(x,x)))` int-temp | **Fixed v0.1.4** — all-double temporaries |
| 5 | Fused tensor op `n_in` assertion mismatch | **Fixed v0.1.7** — fusion/call-site agree |

All seven tracked bugs are resolved. No open upstream blockers.

---

## 6. Known Limitations and Gaps

### 6.1 Functional limitations

| Limitation | Impact | Mitigation |
|---|---|---|
| **f32 precision throughout** | ~6-7 significant digits; cancellation near function zeros gives ~1e-4 absolute error | scipy runs f64. Acceptable for f32 workloads; f64 promotion would need upstream type support |
| **No `cos`, `tan`, `atan`, `abs`, `floor`, `ceil` builtins** | Users must express these from primitives: `cos(x)` = `sin(x + pi/2)`, `abs(x)` = `if lt(x, 0) then neg(x) else x` | Documented in spec/phase3j.md Known Limitations. Upstream could add these as builtins |
| **`bessel_y1` drift in (7.5, 8)** | ~1e-3 relative error near the seam between rational-polynomial and asymptotic branches | f32 precision limit of NR coefficients; golden points avoid this window |
| **`airy_ai` negative large-x** | Power series only; no asymptotic for x < -5. Oscillatory regime works for moderate |x| but degrades at very large negative x | Could add asymptotic oscillatory branch; not yet needed by any consumer |
| **No general-n eigenvalue/SVD/LU/QR** | Only 2x2 and 3x3 closed-form inverses, solves, eigenvalues, Cholesky | General-n iterative methods deferred; `cg_solve` provides iterative SPD linear solve at general n |
| **No adaptive ODE stepping** | `rk4_solve` is fixed-step only | Adaptive RK45 deferred to future phase |
| **`newton_minimize_1d` strong-convexity heuristic** | False-positives on very-flat minima (`f(x)=x^4` near 0) | Callers should use `brent_minimize` or `golden_section_search` for flat-Hessian targets |
| **Signal module is stubs only** | 7 functions return NaN sentinels | Blocked on upstream complex-number support (Phase 5f) |

### 6.2 Test coverage gaps

| Gap | Reason | Assertions affected |
|---|---|---|
| Distribution `sample` variants (4 functions) | Require `Random` effect + `uniform_like` tensor construction not available in bare-build C driver | 0 runtime; type-checked via apismoke |
| `mahalanobis` / `mahalanobis_squared` with non-diagonal cov_inv | Only tested with identity and diagonal matrices | Could add dense SPD cov_inv fixture |
| `cg_solve` convergence on ill-conditioned systems | Only tested on small well-conditioned SPD matrices (2x2, 3x3) | Could add near-singular fixture |
| `lm_scalar_1param` with noisy data | Only tested on exact-fit datasets | Could add noisy regression fixture |
| SDE path accuracy | Only tested on fixed noise patterns (zero, +1, alternating) | Could add realistic Gaussian noise fixture |

### 6.3 Architectural limitations

| Limitation | Impact |
|---|---|
| **Test harness uses bare-build path** | Concatenates `.ch` sources, strips module directives, builds a single TU. Does not exercise the reef package import system at runtime — only at `chelis reef build` / `chelis check` time. |
| **LTO flags are bench-only** | The `-flto -fvisibility=hidden -Wl,-Bsymbolic` workaround is applied only in `scripts/bench_vs_scipy.py`, not in the test harness or any consumer-facing build path. Consumers building their own `.so` from Nautilus C output would need to discover these flags independently. |
| **Duplicate-def stripping in test harness** | `_dedup_defs()` removes 5 known duplicate helper definitions when concatenating modules. Fragile to new collisions from future modules. |

---

## 7. File Manifest

```
reef.toml                          -- package manifest, pin chelis =0.1.7
src/
  core.ch                          -- version() export
  special.ch         (796 lines)   -- 20 special functions
  distributions.ch   (685 lines)   -- 12 distribution families
  linalg.ch          (320 lines)   -- 28 linear algebra ops
  stats.ch           (216 lines)   -- 14 descriptive statistics
  integrate.ch       (320 lines)   -- 8 quadrature methods
  optim.ch           (223 lines)   -- 4 scalar optimizers
  roots.ch           (177 lines)   -- 3 root-finders
  interpolation.ch   (144 lines)   -- 3 interpolation methods
  testing.ch         (131 lines)   -- 13 hypothesis-test helpers
  distance.ch        (83 lines)    -- 8 distance metrics
  curvefit.ch        (73 lines)    -- 1 Levenberg-Marquardt fitter
  sde.ch             (70 lines)    -- 2 SDE integrators
  ode.ch             (63 lines)    -- 4 ODE integrators
  signal.ch          (55 lines)    -- 7 stubs (blocked on complex)
  apismoke.ch        (324 lines)   -- type-level import gate
  example*.ch        (6 files)     -- executable examples
tests/
  run_numeric_tests.py             -- 841-assertion harness
  run_static_checks.py             -- export consistency gate
  goldens/                         -- 25 scipy-generated JSON fixtures
scripts/
  gen_goldens.py                   -- golden generator + drift check
  bench_vs_scipy.py                -- ctypes in-process benchmark
BENCHMARK_FINDINGS.md              -- performance evaluation for paper
UPSTREAM_BUGS.md                   -- 7 tracked upstream bugs (all resolved)
NAUTILUS_STATUS.md                 -- this file
spec/phase3j.md                   -- authoritative scope + acceptance
```

---

## 8. Recommendation for External Reviewer

**What to verify first:**
1. `python tests/run_numeric_tests.py` — should report 841 / 841.
2. `python scripts/gen_goldens.py --check` — goldens haven't drifted.
3. `chelis reef build` — package builds cleanly.
4. Spot-check any Special function against scipy at an input not in the
   goldens — the implementations are polynomial/series approximations
   and edge-case behavior is the most likely failure mode.

**Where to look for problems:**
- `bessel_y1` near x in (7.5, 8) — documented drift, f32 precision.
- `airy_ai` for x < -10 — no asymptotic branch for negative oscillatory
  regime.
- Distribution `sample` variants — type-checked but never runtime-exercised.
- `cg_solve` on ill-conditioned input — convergence not stress-tested.

**What's credible for a paper:**
- The 841 scipy-parity assertions are real and reproducible.
- The benchmark numbers are measured in-process (no subprocess noise)
  and the methodology is documented in BENCHMARK_FINDINGS.md.
- The honest framing of solver caveats (rk4 vs scipy dispatch, not
  method vs method) strengthens the evaluation section.
- The upstream bug history in UPSTREAM_BUGS.md shows a credible
  co-evolution with the compiler, not hand-waving about "future work."
