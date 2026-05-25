# Changelog

All notable changes to this project are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.7.16] - 2026-05-25

Formatter follow-up for chelis 0.7.16. Canonicalizes the remaining
`Nautilus.Optim` and `Nautilus.Special` files that the stricter
`chelis check` gate now rejects when they are not exactly formatted.

## [0.7.15] - 2026-05-25

FlukeBall support release. Adds the minimal analytics surface needed by
Whale and downstream football experiments: information metrics,
optimization compatibility, state-space helpers, and time-series
primitives. This release also retargets CI, release, and package pins to
chelis 0.7.16 so downstream shells can consume the new `Std.Index`,
`Std.Scan`, and `Std.Sort` wrappers from the bundled standard library.

## [0.7.14] — 2026-05-24

Compiler-pin alignment for chelis 0.7.15 (skipping the 0.7.11 and
0.7.12 pins at the consumer level: both were nautilus cleanup
releases that intentionally kept the chelis pin at `=0.7.10`, so this
is a single five-version catch-up jump mirroring the 0.7.8 → 0.7.10
release pattern). `compiler = "=0.7.10"` → `"=0.7.15"`; CI/release
workflow env vars updated to track `v0.7.15`. Package version bumped
0.7.13 → 0.7.14 because the `v0.7.13` nautilus GH release artifact
already exists (built against chelis 0.7.10), so the new tag cannot
reuse `0.7.13`.

chelis 0.7.15 is chelis 0.7.13 + chelis#226 hotfix + chelis#230
argmax_reduce output-dtype hotfix. All other behavior identical to
0.7.13; the fix-set below is the chelis 0.7.13 surface preserved
through 0.7.14/0.7.15.

### chelis 0.7.13 / 0.7.14 / 0.7.15 fixes pulled in

- chelis#186 / chelis PR #205: `conv2d` validator was rejecting every
  well-formed call. Not a current nautilus consumer, but unblocks
  future shells that route through nautilus's signal/filtering surface.
- chelis#187 / chelis PR #214: `shrink`, `stride`, and `pad` are now
  callable from Surf. Frees nautilus's signal-processing roadmap from
  hand-rolled slicing helpers.
- chelis#199 Part 1 / chelis PR #211: `BlasMatmul` gradient rule.
  Part 2 (`to_tensor` inside differentiable bodies) deferred to
  chelis#218; nautilus does not currently call `to_tensor` from a
  `grad(...)` body, so Part 2 is non-blocking for this release.
- chelis#206 / chelis PR #213: runtime-dim `reshape` now preserves
  the declared symbolic shape on its output. Tightens type information
  for any nautilus path that reshapes a runtime-dim tensor; no current
  consumer was relying on the prior weakening.
- chelis#209 / chelis PR #210: lint em-dash UTF-8 boundary panic is
  fixed. nautilus's `chelis lint --check .` no longer crashes when
  CHANGELOG.md em-dashes are processed at certain byte boundaries.
- chelis#185 / chelis PR #217: host-runtime arms wired up for 14
  builtins plus an invariant lock. Closes a class of "compiles but
  panics at runtime" gaps in the host backend.
- chelis#226: spurious `UseAfterConsume` in `Std.Nn.Embedding.forward`
  during reef-resolve linearity analysis. Surfaced by a sibling shell's
  cascade attempt and rolled into 0.7.14 as a point hotfix on top of
  0.7.13. Not a current nautilus consumer (no `Std.Nn.Embedding` use
  in src/), included here for completeness of the upstream surface.
- chelis#230: `argmax_reduce` output dtype regression — fixed in
  chelis 0.7.15 as a surgical hotfix on top of 0.7.14. Surfaced by
  the hydronnx PR #2 ArgMax compile-run-parity test. Not a current
  nautilus consumer; included for completeness of the upstream
  surface.
- chelis PR #221: end-to-end Hydronnx H3 acceptance shapes are locked
  in chelis CI. Not nautilus-facing, but the locked oracle is durable
  evidence the 0.7.13/0.7.14 surface is stable end-to-end.

### Verified

`chelis reef build` clean; `chelis check` clean on all `src/` files;
`chelis test tests/ --jobs auto` → 441 passed, 0 failed;
`python3 parity/run_parity.py --strict` → 216 passed, 0 failed;
`chelis lint --check .` → 0 errors, advisory warnings unchanged from
0.7.12 (`prefer-pipe-operator` / `redundant-linearity-call` retained
inside plateau-stop-containing functions per the 0.7.12 WS-A
discipline). Local verification was performed against the chelis
0.7.13 binary; chelis 0.7.15 differs only by the chelis#226 and
chelis#230 hotfixes, neither of which is exercised by any nautilus
source file.

## [0.7.12] — 2026-05-22

Cleanup-wave release. No compiler-pin change (still `=0.7.10`).
Closes the warning regression from the 0.7.10 lint-fix that was lost
during pristine-source verification, extends the `Nautilus.Roots`
plateau-stop discipline (shipped in 0.7.11) to three more iterative
modules as defense-in-depth, replaces the 0.7.10 CHANGELOG's
"tracked upstream" placeholder with concrete chelis-repo issue
references for the f32 evaluator/C-backend divergence and the
`doc-filename-convention` design wart, and adds a CI maintenance
schedule for the Node 20 → Node 24 GitHub Actions migration.

### Changed: re-applied lost `chelis lint --fix` cleanup on `optim.ch` / `special.ch`

The 0.7.10 release shipped with the `chelis lint --fix` cleanup applied
across most of `src/`, but during pristine-source verification of the
0.7.10 f32-hardening bug, `src/optim.ch` and `src/special.ch` were
reverted to HEAD and never re-lint-fixed. 0.7.10 therefore carried 85
extra advisory warnings (14 in `optim.ch` + 71 in `special.ch`, all
`prefer-pipe-operator`) on top of the warning floor the 0.7.10 release
notes implied.

Re-applied `chelis lint --fix` to those two files only, under the
strict discipline that **no f32-hardening / NaN-handling / plateau-stop
/ tolerance-floor line may change byte-for-byte**. Where `chelis lint
--fix` semantically rewrote a function containing a plateau-stop site
(per the WS-A do-not-touch inventory: `optim.ch` lines 19, 28–29, 44,
73, 87, 105, 141, 149, 156, 163; `special.ch` lines 556–573, 575–592,
655–656, 672–673), that function was reverted whole and its advisory
warnings retained. The NaN-producing primitives `opt_nan_f32()`,
`pos_inf()`, `neg_inf()`, `nan_f32()` were likewise preserved verbatim.

Final state: `chelis lint --check src/` → **214 advisory warnings**
(down from 273; expected drop ≈80, actual drop 59, the gap being the
26 warnings stuck inside the seven plateau-stop-containing functions
that had to be reverted whole: `opt_gs_rec`, `opt_brent_rec`,
`opt_gd_rec`, `airy_f_rec`, `airy_g_rec`, `ellip_agm_a_rec`,
`ellip_agm_csum_rec`). All 438 tests + 216 parity samples remain
green. The 0.7.10 release notes (line 98 above) overstated the
cleanup state by 1 (273 actual vs 272 claimed) in addition to the
85-warning regression now closed here.

### Changed: structural f32-plateau-stop hardening for three iterative modules

Extends the `Nautilus.Roots` plateau-stop discipline (shipped in 0.7.11)
to the three other recursive numeric kernels surfaced by the WS-B audit:

- `Nautilus.CurveFit` `lm1_rec`: adds `eq(theta_next, theta)` plateau
  check ahead of the existing `lt(abs_delta, tol)` convergence test.
- `Nautilus.Ode` `rk45_adaptive_rec`: adds `eq(y_next, y)` plateau
  check in the accepted-step branch, after the existing
  `lt(|t_end - t_next|, tiny_h)` terminal-step short-circuit.
- `Nautilus.Integrate` `adaptive_simpson_rec`: adds
  `plateau = eq(sum_lr, whole)` to the existing
  `or(converged, exhausted)` exit condition. The pre-existing
  `tol_floor = cast(0.0000001, f32)` (L88) on the recursed half-tol is
  retained.

Unlike `Nautilus.Roots`'s iter-exhaustion which returns `r_nan_f32()`
(making the plateau-stop a true correctness fix under sub-ULP tol),
these three modules' iter/depth-exhaustion fallbacks already return
the current iterate (`theta` for lm1, `y` for rk45, `sum_lr +
correction` for adaptive Simpson). Because the iterate at the f32
fixed point is stable, exhaustion returns the same value the plateau
short-circuit would. The hardening is therefore structural
defense-in-depth: it aligns these modules with the `roots.ch` style,
short-circuits unnecessary iterations once the iterate plateaus at
f32 resolution, and provides a regression hook against future
weakening of the iter-exhaust semantics.

Per-module sub-ULP regression tests added (passing) that exercise
the hardened path under adversarial (NaN/zero) tolerances:

- `tests/curvefit.ch::test_lm1_sub_ulp_tol_plateau_locks_fixed_point`
- `tests/ode.ch::test_rk45_sub_ulp_step_plateau_locks_iterate`
- `tests/integrate.ch::test_adapt_sub_ulp_tol_plateau_terminates_sum`

These tests pass with the hardening in place; they also pass without
it, because in these three modules iter/depth-exhaustion already
returns the f32-plateau iterate. They function as regression
guards rather than differential-failure tests. See the WS-B report
for the full analysis.

`tol_floor` literal source: `src/roots.ch:62-63`,
`tol_floor = cast(0.000001, f32)` / `tol_eff = if lt(tol, tol_floor)
then tol_floor else tol`. Not introduced into curvefit or ode this
wave (their convergence checks compare iterate-deltas, which the
plateau check subsumes for positive tol); integrate.ch retains its
pre-existing distinct `tol_floor = cast(0.0000001, f32)` at L88,
which guards the recursed half-tol rather than the top-level
convergence check.

### Verified

`chelis test tests/ --jobs auto` → 441 passed (was 438; +3 new
sub-ULP tests), 0 failed; `python3 parity/run_parity.py --strict` →
216 passed, 0 failed; `chelis lint --check .` → 274 advisory
warnings (unchanged from main; all `prefer-pipe-operator`, none
introduced by this wave).

## [0.7.11] — 2026-05-22

f32-plateau hardening for `Nautilus.Roots` — the structurally-identical
robustness fix the 0.7.10 cleanup applied to `Nautilus.Optim` and
`Nautilus.Special` but missed for `Nautilus.Roots`. No compiler-pin
change (still `=0.7.10`).

### Fixed — `bisection`/`newton`/`brent` could return `NaN` on valid brackets under sub-ULP tolerances

`Nautilus.Roots`'s three root-finders previously had only
`lt(width, tol)` / `lt(afx, tol)` convergence checks plus an
iters-exhausted `r_nan_f32()` fallback. With a tolerance below the
f32 ULP near the root (e.g. `tol = 1e-8` near √2, where the f32
gap is ~1.2e-7), neither convergence check can ever fire — the
iteration plateaus above `tol`, exhausts its iteration budget, and
returns `NaN`. A correct bisection should never `NaN` on a valid
bracket; this is a real robustness bug. Hardened:

- `bisection_rec`: stops when the midpoint coincides with either
  bracket endpoint in f32 (`eq(mid, lo)` or `eq(mid, hi)`) — the
  f32-plateau signal that no further bisection is possible — and
  returns `mid` as the best estimate.
- `newton_rec`: stops when the Newton step produces no change in
  f32 (`eq(x_next, x)`), returning `x_next`.
- `brent_rec`: adds a `tol_floor = 1e-6` (the smallest realistic
  f32 tolerance) so the existing `lt(awidth, tol_eff)` /
  `lt(afb1, tol_eff)` checks always reach a representable bound,
  plus an `eq(s, b1)` plateau check after candidate selection.

The 0.7.10 release shipped with these unhardened. The new
`Nautilus.Roots` returns f32-plateau-best estimates accurate to
~1 ULP (≈ 1e-7 near typical roots) — well within any realistic
test tolerance.

### Verified

Pinned still at chelis `=0.7.10`. `chelis reef build` clean;
`chelis check src/roots.ch` → score 1, 0 errors; `chelis test
tests/roots.ch` → 13 passed, 0 failed (unchanged from 0.7.10);
`chelis test tests/ --jobs auto` → 438 passed, 0 failed (full
suite); `python3 parity/run_parity.py --strict` → 216 passed, 0
failed.

## [0.7.10] — 2026-05-15

Compiler-pin alignment for chelis 0.7.10 (skipping the 0.7.9 pin at
the consumer level — chelis 0.7.9 shipped a `chelis test` lowering
blocker that 0.7.10 fixed). `compiler = "=0.7.8"` → `"=0.7.10"`,
CI/release workflow env vars updated to track v0.7.10. This release
also pays down the latent unsoundness that chelis 0.7.9's tightened
checks surfaced, plus f32 numeric hardening exposed by 0.7.10's
evaluator.

### Fixed — dim-parameter rigidity violation (chelis 0.7.9 `check_declared_dvars_rigid`)

`apismoke.ch`'s `smoke_linalg[m, k, n]` fed `at: tensor[k, m, f32]`
(a rectangular transpose) into `trace_scalar[n](&tensor[n, n, f32])`,
which unified the declared-distinct dims `k` and `m`. chelis 0.7.9
made declared dim parameters rigid within a def body and correctly
rejects this. Routed the trace through the square
`aat_mat: tensor[m, m, f32]`; `at` still exercises `transpose`. No
test depended on the unsound path.

### Fixed — linearity violations in linalg SVD/eig (chelis 0.7.9 stricter linearity)

`linalg.ch`'s `la_svd_rot_g`, `la_svd_rot_v`, `svd_n`,
`la_eig_rot_a`, `la_eig_rot_q`, and `eig_n` had 17 `UseAfterConsume`
errors under chelis 0.7.9 — values consumed by closure capture or by
the by-value `tpl` parameters of `la_svd_g_sw` / `la_eig_a_sw`, then
reused. These six functions are reverted to their pristine pre-0.7.8
form, which carries the explicit `copy()` calls the consume sites
require. (Those `copy()` calls now show as advisory
`redundant-linearity-call` warnings — see lint note below.)

### Fixed — f32 optimizer and elliptic-integral recurrences (chelis 0.7.10 evaluator)

chelis 0.7.10's f32-preserving evaluator exposed unit-roundoff stalls
in scalar numeric code that the prior double-promoting evaluator
masked. `optim.ch`: golden-section and Brent now stop on equal
objective samples; gradient descent and Newton stop when the iterate
no longer changes. `special.ch`: the elliptic AGM helpers stop when
`a`/`b` plateau before the weight term can explode. With these,
`newton_minimize_1d` converges (it was reaching `NaN`) and
`golden_section_search` lands inside tolerance.

### Changed — lint cleanup + doc renames

`chelis lint --fix` auto-fixes (`redundant-linearity-call`,
`prefer-pipe-operator`) applied across `src/` and `tests/`. Final
state under chelis 0.7.10: `chelis lint --check .` → **0 errors, 272
advisory warnings** (all `redundant-linearity-call` /
`prefer-pipe-operator`, concentrated in the six reverted linalg
functions and in `optim.ch` / `special.ch`, where the f32 hardening
took priority over cosmetic pipe rewrites). Five `docs/` files
renamed from SCREAMING_SNAKE_CASE to kebab-case to satisfy
`doc-filename-convention §8.5`; em-dash fixes in `scripts/`.

### Verified

`chelis reef build` clean; `chelis check` clean across all 21
`src/*.ch`; `chelis test tests/ --jobs auto` → 438 passed, 0 failed;
`python3 parity/run_parity.py --strict` → 216 passed, 0 failed.

### Tracked upstream (not blocking)

chelis 0.7.10's scalar-f32 evaluator preserves the source f64 value
verbatim (its internal `TensorValue.data` is `Vec<f64>`), while the C
backend quantizes scalar-f32 constants via an `as f32` cast composed
with a `%.8` format string in `emit_const`, dropping precision before
the C compiler ever sees the literal. The two paths therefore disagree
on small-magnitude f32 constants (e.g., `1.23456789e-7` becomes
`1.19999996e-7` on the C side, a ~3% drift). The f32 hardening above
makes nautilus robust either way, but the divergence is a chelis
soundness item filed at
[Chelis-Lang/chelis#189](https://github.com/Chelis-Lang/chelis/issues/189).

Separately, the `doc-filename-convention` lint rule's §8.3 vs §8.5
dichotomy retroactively flips every `docs/*.md` correctness verdict
when a `book.toml` is added or removed in any ancestor directory.
nautilus's 0.7.10 SCREAMING_SNAKE→kebab rename was a direct
consequence of this footgun. Filed for design discussion at
[Chelis-Lang/chelis#190](https://github.com/Chelis-Lang/chelis/issues/190).

Drafts and full reasoning for both filings live under
`docs/upstream-issues-drafts/`.

## [0.7.9] — 2026-05-13

Compiler-pin alignment release for chelis 0.7.8. No source changes
from 0.7.8 — only the `compiler = "=0.7.7"` → `"=0.7.8"` pin bump,
package version bump to 0.7.9, and CI/release workflow env vars
updated to track v0.7.8. Required because chelis 0.7.8's reef
validator rejects any package whose `package.compiler` is not exactly
`=0.7.8`. The 0.7.8 source cleanup re-verified under 0.7.8 with
zero failures (438/438 native tests, 216/216 scipy-parity samples).

## [0.7.8] — 2026-05-13

Source cleanup pass against the chelis 0.7.7 toolchain pin. No
behavioral change — `chelis reef build`, all 438 native tests, and
all 216 scipy-parity samples remain green. The change set strips
migration scaffolding that the chelis 0.7.6 → 0.7.7 bump made
formally redundant:

- **Drop strip:** 902 `_ = drop(<expr>)` statement lines removed
  across `src/` and `tests/`. Under chelis 0.7.7 implicit linearity
  the compiler inserts the corresponding IR drop node, so the source
  call is redundant (flagged by `chelis lint --rule
  redundant-linearity-call`). Drop statements have unit-typed RHS
  and ignore the result, so removing them is type-preserving.
- **Borrow-orphan collapse:** 462 `__borrow_migration_out_N = <expr>`
  / `__borrow_migration_out_N` bind-then-reference pairs collapsed
  to bare `<expr>`. With the drop statements gone these pairs were
  pure scaffolding.
- **Pipe-operator rewrites (conservative subset):** mechanical
  `f(g(x), …)` → `g(x) |> f(…)` rewrites applied to 21 sites across
  `src/{distance,integrate,testing}.ch` where every non-first
  argument is a simple name/literal AND the rewrite survives a
  whole-package `chelis reef build`. Sites in other modules were
  attempted by the same rewriter and reverted because they failed
  `reef build` cross-module type-check; lifting those to named
  bindings is a separate refactor and left for follow-up. See
  `docs/upstream-bugs.md` for the reasoning.
- **`chelis fmt --inplace`** on `src/{curvefit,distributions,integrate,
  interpolation,linalg,ode}.ch`, which were not canonically formatted
  under 0.7.7's stricter `fmt --check` gate.
- **`copy()` calls retained as-is.** The `redundant-linearity-call`
  rule also flags source-level `copy()` calls but the chelis 0.7.7
  compiler does not auto-insert the borrow→owned conversion they
  perform; stripping them breaks the type-check. Documented as an
  upstream issue.

## [0.7.7] — 2026-05-12

Compiler-pin alignment release for chelis 0.7.7. No source changes —
only the package version and the `compiler = "=0.7.6"` → `"=0.7.7"`
pin bump, plus CI/release workflow env updates to track the new
chelis tag. Required because chelis 0.7.7's reef validator rejects
any package whose `package.compiler` field is not exactly `=0.7.7`.

chelis 0.7.7 itself closes the implicit-copy fan-out gap (Item 1
v2), the deep-user-symbol-charset CLOSED_TAGS gap (Item 3), the
module-pascal-components ecosystem allowlist (Item 4), and the
Linearity-F3 module-wrapped linearity skip. nautilus's existing
source passes `chelis check` and `chelis lint --check src/` with
zero error-severity findings under 0.7.7.

## [0.6.1] — 2026-05-06

Compiler-pin alignment release. Tracks chelis 0.6.0 → 0.6.1
(bootstrap-list patch). No source changes — only the package
version bump and the `compiler = "=0.6.0"` → `"=0.6.1"` pin.
Required because chelis 0.6.0's source tree shipped pre-rename
chelis-std-0.1.0 artifacts; chelis 0.6.1 ships the post-rename
chelis-std-0.2.0 artifacts that downstream consumers need.

## [0.6.0] — 2026-05-06

Naming-convention release. Aligns nautilus with the recorded style
guide in `chelis/spec/01-nomenclature.md`. Track-forward for chelis
0.6.0 / chelis-std 0.2.0.

### Changed (breaking) — module renames per §6.3 PascalCase per component

Six example modules renamed from lowercase-after-first compounds to
proper PascalCase:

| Old                              | New                              |
|----------------------------------|----------------------------------|
| `Nautilus.Examplerootfind`       | `Nautilus.ExampleRootFind`       |
| `Nautilus.Exampleodedemo`        | `Nautilus.ExampleOdeDemo`        |
| `Nautilus.Exampledistributions`  | `Nautilus.ExampleDistributions`  |
| `Nautilus.Exampleintegration`    | `Nautilus.ExampleIntegration`    |
| `Nautilus.Exampleoptim`          | `Nautilus.ExampleOptim`          |
| `Nautilus.Apismoke`              | `Nautilus.ApiSmoke`              |

On-disk filenames are unchanged (forced lowercase by §1.2 module-path
mapping). Downstream `import Nautilus.Examplerootfind ...` etc. must
update to the new names.

### Changed (breaking) — module renames per §6.2 Title-case compounds

Two ALL-CAPS abbreviation modules renamed to Title-case:

| Old              | New              |
|------------------|------------------|
| `Nautilus.ODE`   | `Nautilus.Ode`   |
| `Nautilus.SDE`   | `Nautilus.Sde`   |

Plus `Nautilus.Tests.{ODE,SDE}` → `Nautilus.Tests.{Ode,Sde}`.
Downstream callers must update their imports.

### Changed — `install_chelis_std.sh` ported to Python

Per §2.9 (no shell scripts; Python only). The script is now
`scripts/install_chelis_std.py`, invoked as
`python3 scripts/install_chelis_std.py` from CI.

### Changed — compiler pin bumped to `=0.6.0`

`reef.toml` now requires chelis 0.6.0 and chelis-std 0.2.0.
Downstream consumers must bump their pins to match.

### Style guide

Adheres to `chelis/spec/01-nomenclature.md` (the recorded style
guide). The local `STYLE.md` is a one-line pointer at the central
guide. The `la_*` private-helper prefix in `Nautilus.LinAlg`
remains, recognized as the module's domain shorthand under §7.1
(`la` = initials of `LinAlg`).

The math/algorithm prefixes `airy_/beta_/chi_/cg_/det_/eig_/inv_/
lm_/erf_` are recognized as §7.1.1 model/algorithm sub-namespaces.
