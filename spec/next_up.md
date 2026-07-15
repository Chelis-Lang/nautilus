# Nautilus — Next-Up Work

Source of truth for post-v0.1.0 Nautilus development. Complements
`spec/phase3j.md` (the shipped v0.1.0 scope) and tracks work driven by
(a) cross-cutting decisions landed in the main
[`Chelis-Lang/chelis`](https://github.com/Chelis-Lang/chelis) repo and
(b) residual limitations carried forward from v0.1.0.

Priorities below are ordered **P0 → P2** by leverage on downstream
consumers (Shoals, School, Octant) and on the Phase 4 AI training
pipeline. Nothing in here is a toolchain regression; v0.1.0 ships.

**Status snapshot (2026-07-14, `chelis 0.16.1`).**

- Current pin is `chelis 0.16.1` (Nautilus `0.7.33`). The current acceptance
  gate passes 463 native tests in parallel and serial modes, 3 negative
  contracts, 2 expected-failure blocker probes, and 216/216 reviewed scipy
  parity samples.
- The canonical Phase 3j architecture now describes the shipped package:
  pure-Chelis composition throughout, including LinAlg, with no nalgebra FFI or
  hand-written adjoint registry. Broad solver AD and QP/SOCP/LP remain explicit
  later scope rather than hidden completion requirements.
- Multi-parameter Levenberg-Marquardt's exact AD replacement was re-probed on
  0.16.1 and narrowed to two live layers: generic `n`/`m` dimension collapse
  and malformed backward-DAG lowering for the arbitrary vector-model wrapper.
  Both are pinned under `tests_blocked/curvefit/`; tensor-wrt and direct
  capture-free multi-argument grad controls pass.

Historical snapshot (2026-04-22, `chelis v0.1.18`):

- Completed in Nautilus: P0 per-row stability column, P1 fast-`chelis eval`
  benchmark, P2 adaptive-step ODE integrator, P2 `bessel_y1` precision/stability
  fix, **P2 general-`n` Cholesky (`cholesky_n`)** — shipped as `alpha` on the
  `v0.1.18` toolchain with a scipy-parity golden.
- Remaining Nautilus work unblocked on `v0.1.18`: LU / QR / SVD (same
  compiler-surface now available) — shipped subsequently in Nautilus `v0.2.0`.
- Remaining work still dependent on upstream Chelis fixes: multi-parameter
  Levenberg-Marquardt (tensor-valued `grad` on the native path still emitted a
  placeholder helper instead of a real gradient as of v0.1.18).

---

## Completed: P0 Per-Row Stability Column in SKILL.md

Landed in commit `084f0ed`. `SKILL.md` now carries a per-row `Stability`
column, `scripts/validate_surface.py` validates the tables, and
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
- `Nautilus.Ode` — all four fixed-step exports (`euler_step`,
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
- `Nautilus.Sde` — `euler_maruyama_fixed` and `milstein_fixed`
  `alpha` (APIs may shift when autonomous `Random` sampling lands).
- `Nautilus.CurveFit` — `lm_scalar_1param` `alpha`.
- `Nautilus.Signal` — all 7 exports `alpha`: six NaN-returning stubs remain
  under the dated `spec/phase3j.md` § Explicit Deferrals citation pending Phase
  5f complex numbers, while `fftfreq` is functional.

**Validation.**

1. `python scripts/validate_skill_examples.py` continues to pass — existing
   check only parses `chelis` / `deep` fenced blocks; the table edit
   does not touch those.
2. Add a new gate in `scripts/validate_surface.py` that parses each
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

**Acceptance oracle:** `python scripts/validate_surface.py` passes
with the new stability-column gate enabled, `stability.json` is
generated and committed to `dist/`, and `wc -l SKILL.md` stays within
~10% of current (1241 lines) — the column is wide but the tables are
not.

---

## Completed: P1 Upstream the Fast-`chelis eval` Dependency Surface

Landed in commit `084f0ed`. `scripts/bench_eval_startup.py` measures the
startup path, and `docs/eval_startup_findings.md` records the actionable
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
`docs/eval_startup_findings.md`. If the target is already met, the
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

## Tracking: replace the multi-parameter LM finite-difference Jacobian

`Nautilus.CurveFit.lm_scalar_nparam` is shipped and runtime-tested for general
parameter length `n` and observation length `m`:

```chelis
def lm_scalar_nparam[n, m](
  model: &tensor[n, f32] -> &tensor[m, f32] -> tensor[m, f32],
  x: &tensor[m, f32],
  y: &tensor[m, f32],
  theta0: tensor[n, f32],
  tol: f32,
  max_iters: int64,
) -> tensor[n, f32]
```

The implementation currently assembles Jacobian columns with forward finite
differences (`eps=1e-5`) and solves the damped normal equations with
`cg_solve`. This is an `alpha` implementation, not the permanent AD design:
`tol` is accepted but the current routine executes exactly `max_iters`, and
lambda is fixed at `0.01`.

**Current 0.16.1 blocker chain, re-probed 2026-07-14:**

1. The exact generic wrapper collapses independently declared `n` and `m` at
   check time. Citation and reproducer:
   `docs/issue_drafts/grad_generic_vector_model_dims.md` and
   `tests_blocked/curvefit/lm_jacobian_generic_dims.ch`.
2. With dimensions concretized to `n=2`, `m=6`, the same arbitrary-model
   wrapper checks at score 1 but eval and C build reject its malformed backward
   DAG (`mismatched dimension count: 0 vs 1`). Citation and reproducer:
   `docs/issue_drafts/grad_vector_model_wrapper_backward_dag.md` and
   `tests_blocked/curvefit/lm_jacobian_model_wrapper.ch`; this is the same
   verifier class as chelis#676 pending upstream scope confirmation.

A capture-free direct multi-argument tensor objective is the positive control:
it checks, evaluates to the correct gradient, C-builds, and compiles. The
narrowing is therefore the function-valued vector-model Jacobian boundary, not
a claim that tensor-wrt grad is generally unavailable.

**De-narrowing instructions.** When both probes clear, promote their exact-value
witnesses, replace `lm_jcol` with AD Jacobian assembly, compare linear and
exponential recovery trajectories against the current implementation, remove
the finite-difference scaling caveat, and archive both upstream entries in the
same pin-bump change. Do not remove the workaround on a checker-only fix that
merely exposes the backend layer.

**Acceptance oracle:** `chelis test tests/curvefit.ch` retains the scalar and
multi-parameter recovery cases; the promoted Jacobian tests prove exact rows;
and any external-reference expansion adds at least two reviewed configurations
under `parity/goldens/`.

---

## Completed: P2 Adaptive-Step ODE Integrator

Landed in commit `ce613f7`. `Nautilus.Ode.rk45_adaptive_solve` now ships as an
`alpha` endpoint solver, is wired into `src/apismoke.ch`, and is covered by the
native decay and convergence cases in `tests/ode.ch`. The retired Python golden
and harness remain available in Git history.

Original planning note:

**Driven by:** residual v0.1.0 limitation
(`docs/nautilus_status.md` § 6.1) — `Nautilus.Ode` ships fixed-step
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

**Acceptance oracle:** `chelis test tests/ode.ch` passes the adaptive decay,
convergence, and fixed-step comparison cases. Any external SciPy comparison is
added to the reviewed `parity/goldens/` corpus rather than a second harness.

---

## Completed: P2 Bessel Y1 Precision Fix

Landed in commit `ce613f7`. The seam moved from `x = 8.0` to `x = 7.5`,
new `(7.5, 8)` goldens were added, and the `bessel_y1` stability row in
`SKILL.md` is now `stable`.

Original planning note:

**Driven by:** residual v0.1.0 limitation
(`docs/nautilus_status.md` § 6.1) — `bessel_y1` has ~1e-3 relative
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

**Acceptance oracle:** `chelis test tests/special.ch` covers the corrected
`bessel_y1` behavior; reviewed seam values belong in `parity/goldens/special.json`
with at least two configurations before the stability row flips `alpha` →
`stable`.

---

## Completed: P2 General-n Cholesky; next up LU / QR / SVD

**Status (2026-04-22, `chelis v0.1.18`).** Both originally-documented
core-owned blockers are fixed upstream, and `cholesky_n` has shipped in
Nautilus on top of them.

1. **FIXED in `v0.1.15`, remains fixed in `v0.1.18`.** Tuple fold
   accumulators with a tensor in slot 0 lower correctly.
2. **FIXED in `v0.1.18`.** Control flow inside the generic fold body
   over tensor-valued results now lowers correctly (`chelis_tensor*
   new_t` + `chelis_value_from_tensor` in both branches, runtime-verified).

`Nautilus.LinAlg.cholesky_n` is implemented as a column-by-column
Cholesky-Banachiewicz iteration that folds over `range(0, n)` with a
full `tensor[n, n, f32]` accumulator. Each step computes column `j` as
`(A[:,j] - L L[j,:]^T) / sqrt(c[j])` with an index-masking step to keep
the output lower triangular, and accumulates the new column into `L`
via `einsum("i,j->ij", new_col, e_j) + L`. No scatter needed; everything
runs through `matvec` / `vecmat` / `einsum`. Shipped as `alpha` — assumes
SPD input and emits no NaN markers on non-SPD inputs. Scipy-parity
golden at `tests/goldens/linalg/cholesky_n.json` covers n=2..6 plus one
hand-checked 3x3.

LU / QR / SVD are the next unblocked items and remain planned for a
dedicated sub-release; they share the same fold+control-flow compiler
surface that Cholesky validated.

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

**Acceptance oracle:** the native LinAlg suite gains at least 40 assertions
across the four additions, and the checked-golden `parity/` corpus gains at
least two structured matrix configurations for each promoted public verb.

---

## Out of Scope (for now)

- **Sparse matrix support** — blocked on core sparse-tensor types
  (Phase 5).
- **Complex-number functions** (FFT, STFT, `erfi`, complex Bessel) —
  deferred by `spec/phase3j.md` § Explicit Deferrals until Phase 5f complex
  numbers land in Chelis core.
- **GPU benchmark** — requires ROCm-enabled bench harness; deferred
  until the chelis HIP backend's Nautilus codegen is validated
  end-to-end.
- **Random effect batched sampling redesign** — waits for the
  `Random` effect API to freeze in chelis core (post-LaCaDiLE).

---

## Remaining Execution Order

1. **Upstream Chelis:** clear or deduplicate the two exact vector-model
   Jacobian blockers pinned under `tests_blocked/curvefit/`.
2. **Nautilus-side de-narrowing:** replace finite differences only after both
   generic and concrete probes pass, then promote exact Jacobian-row and LM
   trajectory coverage in the same pin-bump change.
3. **LinAlg follow-through:** retain the shipped pure-Chelis LU / QR / SVD /
   symmetric-eig implementations as `alpha` while expanding distinct-shape
   identity/oracle coverage under the accepted Phase 3j contract.
