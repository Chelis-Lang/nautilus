# Changelog

All notable changes to this project are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed — re-applied lost `chelis lint --fix` cleanup on `optim.ch` / `special.ch`

The 0.7.10 release shipped with the `chelis lint --fix` cleanup applied
across most of `src/`, but during pristine-source verification of the
0.7.10 f32-hardening bug, `src/optim.ch` and `src/special.ch` were
reverted to HEAD and never re-lint-fixed. 0.7.10 therefore carried 85
extra advisory warnings (14 in `optim.ch` + 71 in `special.ch`, all
`prefer-pipe-operator`) on top of the warning floor the 0.7.10 release
notes implied.

Re-applied `chelis lint --fix` to those two files only — under the
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
that had to be reverted whole — `opt_gs_rec`, `opt_brent_rec`,
`opt_gd_rec`, `airy_f_rec`, `airy_g_rec`, `ellip_agm_a_rec`,
`ellip_agm_csum_rec`). All 438 tests + 216 parity samples remain
green. The 0.7.10 release notes (line 98 above) overstated the
cleanup state by 1 (273 actual vs 272 claimed) in addition to the
85-warning regression now closed here.

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

chelis 0.7.10's scalar-f32 evaluator behavior now differs from the C
host backend, which still emits host scalar floats as `double`. The
f32 hardening above makes nautilus robust either way, but the
evaluator/backend divergence is a chelis soundness item worth
tracking upstream.

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
