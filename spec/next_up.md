# Nautilus — Next-Up Work

Source of truth for post-v0.1.0 Nautilus development. Complements
`spec/phase3j.md` (the shipped v0.1.0 scope) and tracks work driven by
(a) cross-cutting decisions landed in the main
[`Chelis-Lang/chelis`](https://github.com/Chelis-Lang/chelis) repo and
(b) residual limitations carried forward from v0.1.0.

Priorities below are ordered **P0 → P2** by leverage on downstream
consumers (Shoals, School, Octant) and on the Phase 4 AI training
pipeline. Nothing in here is a toolchain regression; v0.1.0 ships.

**Status snapshot (2026-04-19).**

- Completed in Nautilus: P0 per-row stability column, P1 fast-`chelis eval`
  benchmark, P2 adaptive-step ODE integrator, P2 `bessel_y1` precision/stability
  fix.
- Remaining unblocked Nautilus-only work: none.
- Remaining work that now depends on upstream Chelis fixes: multi-parameter
  Levenberg-Marquardt (Jacobian/autodiff surface) and general-`n` LinAlg
  decompositions (generic fold/control-flow lowering on the build path).

---

## Completed: P0 Per-Row Stability Column in SKILL.md

Landed in commit `084f0ed`. `SKILL.md` now carries a per-row `Stability`
column, `tests/run_static_checks.py` validates the tables, and
`scripts/extract_stability.py` emits `dist/stability.json` for downstream
consumers.

Original planning note:

**Driven by:** `chelis/spec/design/chelis_canonical_reference.md` §
Cross-Cutting Design Decisions — "stability labels on exported APIs."

**Problem.** `SKILL.md` § 6 currently documents a module-level
stability default (commit `4576c38`): everything in `Special`,
`Distributions` PDF/CDF/inv_CDF, `LinAlg` fixed-size, and `Stats`
descriptive defaults to `stable`; `CurveFit`, `SDE`, `_sample`, and
`Signal` default to `alpha`. That is enough to describe the
*convention* but not enough to drive Phase 4a corpus curation, which
needs per-function labels so the training pipeline can filter the
exact rows it ingests.

**Deliverable.** Add a `Stability` column to every API surface table
in `SKILL.md` § 6 (14 tables, ~150 rows). Each row carries exactly one
of `stable` or `alpha`. Remove the module-level defaults paragraph and
replace it with a one-line pointer ("see the `Stability` column
below") plus the cross-cutting rationale.

**Row-level rules (override the module default only when clearly
different):**

- `Nautilus.Special` — all 19 exports `stable` **except**
  `bessel_y1` (documented ~1e-3 drift in (7.5, 8); mark `alpha` until
  a better approximation lands) and `airy_ai` for large negative `x`
  (oscillatory regime is power-series-only; mark `alpha`).
- `Nautilus.Distributions` — all 38 exports `stable` **except** the
  seven `_sample` variants (`uniform_sample`, `exponential_sample`,
  `normal_sample`, `lognormal_sample`, `gamma_sample`,
  `chi_squared_sample`, `student_t_sample`) which stay `alpha` until
  the `Random` effect's batched-sampling API is frozen.
- `Nautilus.LinAlg` — all 26 exports `stable`. Fixed-size solvers are
  API-frozen; `cg_solve` is stable too (tolerance parameter is
  well-defined).
- `Nautilus.Stats` — all 14 exports `stable`.
- `Nautilus.Distance` — all 8 exports `stable`.
- `Nautilus.Roots` — all 3 exports `stable`.
- `Nautilus.ODE` — all four fixed-step exports (`euler_step`,
  `euler_solve`, `rk4_step`, `rk4_solve`) are `stable`; adaptive-step
  variants stay `alpha` (API not yet designed).
- `Nautilus.Integrate` — all 8 exports `stable`.
- `Nautilus.Testing` — all 13 exports `stable`.
- `Nautilus.Optim` — `golden_section_search`, `brent_minimize`, and
  `gradient_descent_1d` are `stable`; `newton_minimize_1d` is `alpha`
  (documented heuristic false-positive on flat minima);
  `lm_scalar_1param` moves to the `CurveFit` column — mark `alpha`
  until multi-parameter LM lands.
- `Nautilus.Interpolation` — all 3 exports `stable`.
- `Nautilus.SDE` — `euler_maruyama_fixed` and `milstein_fixed`
  `alpha` (APIs may shift when autonomous `Random` sampling lands).
- `Nautilus.CurveFit` — `lm_scalar_1param` `alpha`.
- `Nautilus.Signal` — all 7 stubs `alpha` (blocked on Phase 5f
  complex numbers).

**Validation.**

1. `python tests/run_skill_checks.py` continues to pass — existing
   check only parses `chelis` / `deep` fenced blocks; the table edit
   does not touch those.
2. Add a new gate in `tests/run_static_checks.py` that parses each
   API surface table and asserts (a) every row has a `Stability`
   cell, (b) the value is exactly `stable` or `alpha`, (c) the set
   of documented functions in the tables matches the set of exports
   from `chelis reef build`'s manifest (this also catches
   documentation drift generally).
3. Emit a `stability.json` artifact (`scripts/extract_stability.py`,
   new) that flattens the tables into
   `{"Nautilus.Special": {"erf": "stable", ...}, ...}`. Downstream
   consumers (`chelis-lang/chelis-skill`, the Phase 4a corpus
   curator) read this JSON rather than re-parsing markdown. Run the
   extractor as part of `chelis reef build` CI.

**Size:** Small. Pure documentation edit + one new test gate + one
Python script. No Chelis source changes.

**Acceptance oracle:** `python tests/run_static_checks.py` passes
with the new stability-column gate enabled, `stability.json` is
generated and committed to `dist/`, and `wc -l SKILL.md` stays within
~10% of current (1241 lines) — the column is wide but the tables are
not.

---

## Completed: P1 Upstream the Fast-`chelis eval` Dependency Surface

Landed in commit `084f0ed`. `scripts/bench_eval_startup.py` measures the
startup path, and `docs/EVAL_STARTUP_FINDINGS.md` records the actionable
compiler-side recommendations. The findings doc is the handoff: Nautilus
measures, Chelis core owns the fix.

Original planning note:

**Driven by:** `chelis/spec/design/chelis_project_plan.md` § Pre-Phase
4 Investments — "fast `chelis eval` with package-aware imports,
target 200ms with Nautilus imported."

**Problem.** The Phase 4 target is `chelis eval myfile.ch --expr
"erf(0.5)"` under 200ms with `Nautilus.Special` imported. That number
is a claim, not a measurement. Nautilus owns the largest single
reef package anyone has built and is the obvious first test subject.

**Deliverable.** A benchmark script in Nautilus that measures
`chelis eval` startup time with every Nautilus module imported, under
several scenarios:

1. Cold cache (fresh `chelis eval` process).
2. Warm cache (second `chelis eval` in the same process/session if
   the evaluator supports it; otherwise skip).
3. Per-module isolation (import only `Nautilus.Special`, measure;
   then only `Distributions`, etc.) to identify which module
   dominates startup.

**Implementation.** New file `scripts/bench_eval_startup.py`. Uses
`subprocess.run` with wall-clock timing, 20 trials per scenario, f32
target. Output is a markdown table dumped to stdout and written to
`docs/EVAL_STARTUP_FINDINGS.md`. If the target is already met, the
finding becomes evidence in the main chelis repo that no pre-Phase 4
work is needed. If missed, the per-module breakdown tells the chelis
compiler team where the seconds are going.

**Important.** Nautilus does not fix the problem — the fix, if
needed, lives in `chelis-lang/chelis` (reef-package resolver, parser,
typechecker startup). Nautilus only measures and reports.

**Size:** Small. ~100 lines of Python, one new markdown report.

**Acceptance oracle:** `python scripts/bench_eval_startup.py`
completes, emits the findings report, and the report either (a)
confirms the 200ms target is met with current chelis v0.1.7, or (b)
identifies at least one specific dominating cost (e.g., parser,
typechecker, specific module) the upstream team can target.

---

## Blocked: P1 Multi-Parameter Levenberg-Marquardt

**Current blocker (2026-04-19, re-checked on `chelis v0.1.9`).** The blocker is
now narrower but still real. `v0.1.9` accepts richer `grad` shapes at the type
surface, and scalar `grad` builds cleanly, but tensor-parameter gradient probes
still emit invalid C on the native path (`chelis_tensor*` / `chelis_list*`
temporaries lowered as `int`). That means Nautilus still cannot rely on
tensor-valued gradients at runtime for a real LM implementation.

**Driven by:** residual v0.1.0 limitation
(`docs/NAUTILUS_STATUS.md` § 6.1) — `Nautilus.CurveFit` currently
only exposes `lm_scalar_1param`. Every real curve-fitting workload
(Shoals SABR calibration, Octant LaTeX→Chelis calibration paths) needs
≥ 2-parameter fitting.

**Deliverable.** Add `lm_scalar_nparam` with a general-n parameter
vector. Signature:

```chelis
def lm_scalar_nparam[n, m](
  model: tensor[n, f32] -> tensor[m, f32] -> tensor[m, f32],
  x: tensor[m, f32],
  y: tensor[m, f32],
  theta0: tensor[n, f32],
  tol: f32,
  max_iters: int64,
) -> tensor[n, f32]
```

Where `n` is the parameter count, `m` is the data-point count, and
`model(theta, x)` predicts `y`. Jacobian via `grad(model, wrt=theta)`.
Uses existing `Nautilus.LinAlg` solvers — `cg_solve` for SPD
`J^T J + lambda I`, `inv_2x2`/`inv_3x3` for small `n`.

**Do not do instead.** Do not replace the missing Jacobian path with
finite-difference columns and then present that as the permanent Nautilus API.
If the core surface cannot provide the Jacobian cleanly on the native path, keep
this item blocked and hand the requirement back upstream.

**Stability.** Ship as `stable` in the SKILL.md Stability column once
runtime-tested; demote the existing `lm_scalar_1param` to `alpha` and
document it as a convenience wrapper over `lm_scalar_nparam`.

**Test coverage.** Golden: fit a 3-parameter exponential model
`y = a * exp(b * x) + c` to noisy data, verify `theta` recovers true
values within 5%. Add `tests/goldens/curvefit/lm_nparam_expfit.json`
generated from scipy `curve_fit`.

**Size:** Medium. ~100 lines of Chelis + one golden fixture + one
new runtime-test block.

**Acceptance oracle:** `python tests/run_numeric_tests.py` reports
881 + N assertions (probably +5 to +10 for multi-parameter LM), all
passing.

---

## Completed: P2 Adaptive-Step ODE Integrator

Landed in commit `ce613f7`. `Nautilus.ODE.rk45_adaptive_solve` now ships as an
`alpha` endpoint solver, is wired into `src/apismoke.ch`, and is runtime-tested
in `tests/run_numeric_tests.py` against the decay golden in
`tests/goldens/ode/scalar.json`.

Original planning note:

**Driven by:** residual v0.1.0 limitation
(`docs/NAUTILUS_STATUS.md` § 6.1) — `Nautilus.ODE` ships fixed-step
only. Scipy's `solve_ivp(method="RK45")` is the workhorse; real
consumers (Shoals SDE discretization with adaptive time steps) need
it.

**Deliverable.** Add `rk45_adaptive_solve` with standard
Dormand-Prince embedded pair. Signature:

```chelis
def rk45_adaptive_solve(
  f: f32 -> f32 -> f32,
  t0: f32,
  y0: f32,
  t_end: f32,
  rtol: f32,
  atol: f32,
) -> f32
```

Returns `y(t_end)`. Error estimate drives step-size control via
standard PI controller.

**Stability.** Ship as `alpha` initially — the return-type story
(point at `t_end` vs full trajectory vs user-supplied output grid) may
shift once more consumers land.

**Test coverage.** Golden: solve `dy/dt = -2*y` with `y(0) = 1` to
`t = 2`, verify `y(2)` matches `exp(-4)` within rtol=1e-6. Compare
against fixed-step `rk4_solve` to show adaptive wins when
step-size-sensitive (e.g., stiff regions, sharp transitions).

**Size:** Medium. ~150 lines of Chelis (step-size controller is
non-trivial) + one golden.

**Acceptance oracle:** `python tests/run_numeric_tests.py` passes
with added `rk45_adaptive` assertions; benchmark table in
`BENCHMARK_FINDINGS.md` updated to show adaptive vs fixed on a stiff
test case.

---

## Completed: P2 Bessel Y1 Precision Fix

Landed in commit `ce613f7`. The seam moved from `x = 8.0` to `x = 7.5`,
new `(7.5, 8)` goldens were added, and the `bessel_y1` stability row in
`SKILL.md` is now `stable`.

Original planning note:

**Driven by:** residual v0.1.0 limitation
(`docs/NAUTILUS_STATUS.md` § 6.1) — `bessel_y1` has ~1e-3 relative
error in `(7.5, 8)` near the rational/asymptotic seam. Currently
tagged as a known limitation and avoided in golden test points.

**Deliverable.** Replace the f32 NR rational-polynomial coefficients
in the `(x_cutoff, 8)` window with higher-precision coefficients
derived from scipy reference. Either fit a new polynomial minimax or
compute from the asymptotic series with more terms. Target: < 1e-5
relative across the full domain.

**Test coverage.** Add golden points at `x = 7.6, 7.7, 7.8, 7.9` that
currently trip the ~1e-3 window; verify they pass at the new < 1e-5
tolerance.

**Stability promotion.** Once fixed, promote `bessel_y1` from `alpha`
to `stable` in the SKILL.md Stability column (P0 work item above).

**Size:** Small. ~30 lines of Chelis (new coefficients) + 4 new
golden points.

**Acceptance oracle:** `python tests/run_numeric_tests.py` passes
with `bessel_y1` at < 1e-5 across `(7.5, 8)`; row in SKILL.md Stability
column flips `alpha` → `stable`.

---

## Blocked: P2 General-n LinAlg (LU, QR, SVD)

**Current blocker (2026-04-19, re-checked on `chelis v0.1.9`).** A first
Nautilus-side attempt to add general-`n` `cholesky[n]` still fails on the build
path in two core-owned ways:

1. Tuple fold accumulators with a tensor in slot 0 mis-lower in emitted C
   (`l_inner` becomes an `int` instead of `chelis_tensor*`).
2. Rewriting around that hit a second core limit: control flow inside the
   generic fold reaches lowering as `` `if` is not representable in the Phase 0e
   RISC DAG ``.

Those two failures were both reproduced again against the `v0.1.9` darwin
release artifact:

- the original tuple-accumulator implementation still reaches emitted C with
  `l_inner` lowered as `int`, producing clang pointer/integer mismatches;
- a tensor-only sentinel rewrite gets past that point but still panics in
  lowering with `` `if` is not representable in the Phase 0e RISC DAG ``.

Until those core issues are fixed, do not treat even general-`n` Cholesky as
Nautilus-unblocked. LU / QR / SVD remain further behind it.

**Driven by:** residual v0.1.0 limitation — fixed-size 2x2/3x3 only
for inverse/solve/eigenvalue/Cholesky. General-n is deferred but is
the largest outstanding gap versus scipy.linalg.

**Deliverable.** Four additions to `Nautilus.LinAlg`:

- `lu_solve[n, m](A: tensor[n, n, f32], b: tensor[n, m, f32])
  -> tensor[n, m, f32]` — LU with partial pivoting.
- `qr_decompose[n, m](A: tensor[n, m, f32])
  -> (tensor[n, m, f32], tensor[m, m, f32])` — Householder QR.
- `svd[n, m](A: tensor[n, m, f32])
  -> (tensor[n, n, f32], tensor[min(n,m), f32], tensor[m, m, f32])` —
  Jacobi SVD (n ≤ ~100 regime where Jacobi is competitive).
- `cholesky[n](A: tensor[n, n, f32]) -> tensor[n, n, f32]` — Standard
  Cholesky, SPD assumed.

**AD story.** LU and QR have known adjoints; Jacobi SVD's backward is
the standard Giles formula. Test AD through each via finite
differences on 4x4 inputs.

**Documented AD caveats (required, not optional).**

- `lu_solve`: gradients treat pivot choices as fixed. This is correct for most
  inputs away from pivot boundaries and discontinuous exactly at pivot changes.
- `qr_decompose`: Householder sign choices are piecewise-smooth, not globally
  smooth across sign-flip boundaries.
- `svd`: singular-value ordering and singular-vector bases are discontinuous at
  repeated or nearly repeated singular values.

**Stability.** All four ship as `alpha` initially — the return-tuple
shape conventions are likely to shift when named-dim output
conventions mature.

**Size:** Large. ~400 lines of Chelis + several goldens + AD
verification. Probably a dedicated sub-release (v0.2.0).

**Acceptance oracle:** `python tests/run_numeric_tests.py` passes
with ≥ 40 new assertions across the four additions; `scripts/bench_vs_scipy.py`
updated with a general-n LinAlg benchmark table.

---

## Out of Scope (for now)

- **Sparse matrix support** — blocked on core sparse-tensor types
  (Phase 5).
- **Complex-number functions** (FFT, STFT, `erfi`, complex Bessel) —
  blocked on Phase 5f complex numbers in chelis core.
- **GPU benchmark** — requires ROCm-enabled bench harness; deferred
  until the chelis HIP backend's Nautilus codegen is validated
  end-to-end.
- **Random effect batched sampling redesign** — waits for the
  `Random` effect API to freeze in chelis core (post-LaCaDiLE).

---

## Remaining Execution Order

1. **Upstream Chelis Jacobian surface for multi-parameter LM.**
   Nautilus should resume `lm_scalar_nparam` only after the Jacobian path is
   available without inventing a second derivative API.
2. **Upstream Chelis generic-fold/control-flow lowering for general-`n`
   linalg.** Cholesky is the first credible downstream proving ground.
3. **Then resume Nautilus post-v0.1.0 scope in this order:** multi-parameter LM,
   then general-`n` Cholesky, then LU / QR / SVD with the documented AD caveats.
