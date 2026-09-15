# Upstream Chelis Bugs

This file tracks upstream Chelis issues discovered during Nautilus development.
The four current-status sections are the operational index; the historical
evidence that follows preserves the original release-by-release probes,
reproductions, workarounds, and status notes.

> **Current release pin: `chelis 0.18.10`.** The published Darwin arm64 asset
> (release SHA-256
> `80c9c5b42a8fbcee6884915df1a4dafb8bcc1cae33199ded060d8b2ebece8bf0`;
> compiler payload SHA-256
> `a6af380886b21761bc2822a814e4fef4232e8b8551922d32bca722cd4e04e1e2`;
> source commit `b9095ccf2c0b76859aa447c6febe699fd287f1d2`, tag `v0.18.10`,
> annotated tag object `e247a5d33cd2df552f57e3efddfd4ea30846b3b8`, release run
> 34966582543) ran the complete local gate on 2026-09-15: 483 positive tests, 4
> negative contracts, 3 blocked probes still blocked, and 216/216 strict SciPy
> parity, with the positive suite finishing in 413s wall time at the default
> 600s suite timeout. The tarball was checked against its release sidecar and
> the installed payload is the `bin/chelis` extracted from it. The Linux
> glibc-2.31 asset for the same tag (SHA-256
> `0843697e0a7783e383df0347ae431ae56f62b5a5ae34a7aa72ac37ee91df1e0b`; compiler
> payload SHA-256
> `6622e40bc786c562b5b66d370a84e46ded551dee70abfc617a71d026c0119b00`) was not
> exercised here; its gate run is CI's, not this one.
>
> **0.18.10 re-probe results.** chelis#676 remains **live**: both
> `tests_blocked/curvefit/` shapes still fail while verifying the backward DAG
> with `mismatched dimension count: 0 vs 1` (`chelis test tests_blocked/
> --expect blocked` -> 3 ok, 0 failing, counting the masked-select probe), so
> the finite-difference Jacobian narrowing stays. chelis#1464 remains **live**:
> `tests_blocked/masked_select/untaken_arm_overflow.ch` still fails at its
> pinned `assert failed: the untaken overflowing arm does not poison the
> selected value`, so both `erf` series clamps stay. No probe source drift this
> cycle: all three probes reach the same pinned diagnostic unmodified, so the
> verdict is a clean OK. Real `Special.erf(1)` remains green at `0.8427007`
> through package-aware `eval --file`, and the strict parity gate is numerically
> unchanged at 216/216.
>
> **Two upstream repairs land in Nautilus this pin.** chelis#2059: the
> interpreter's `admit_execution_profile` re-lowered definitions per closure
> application, which roughly doubled the wall time of Nautilus's tensor and
> Monte-Carlo suite under 0.18.9; 0.18.10 makes the lowering program-scoped. The
> 0.7.44 CI bandaid that raised the `chelis test tests/` step's `--suite-timeout`
> from its 600s default to 2400s is reverted in this release — the suite passes
> 483/483 within the default 600s suite timeout (413s locally), which is the
> proof the raise is no longer needed. `nightly.yml` and `release.yml` never
> carried the raise, since neither runs `chelis test tests/`. chelis#2068: a
> native-C ownership error triggered by `src/special.ch::airy_gg` (the recursive
> Airy `g`-series helper behind exported `airy_ai`/`airy_bi`) is fixed, so the
> helper compiles on the native-C target; the whole-package `chelis reef build`
> and the sealed release-artifact contract exercise it and its numerics, shapes
> and tolerances are unchanged. Neither fix required a Nautilus source edit.
>
> **Nothing is retired at this pin.** Both cited blocked issues (chelis#676,
> chelis#1464) are open upstream, so `conform audit --explain` (row 9,
> staleness) has no closed-issue citation to triage and the audit is conformant.
> chelis#2059 and chelis#2068 carried no shipped Nautilus source workaround to
> revert: #2059's only downstream trace was the CI suite-timeout raise, reverted
> above, and #2068 was an upstream compile error, not a narrowing. `chelis-std`
> stays at 0.4.0, compiler-bound to `=0.18.10` in the regenerated `reef.lock`,
> so there is still **no dependency cascade** into this bump.

> **Previous pin: `chelis 0.18.9`.** The published Darwin arm64 asset
> (release SHA-256
> `44e12cf187b37cb6d2a617e1573832a1bdcaa0e1564f59c4029e24081a84905d`;
> compiler payload SHA-256
> `68e460df6e796891fb30c42904b0309b4d5e83d187944222faaaae63241101c7`;
> source commit `abff07b47eadc8d2be633e3a7d21220089befb6f`, tag `v0.18.9`,
> release run 34843914490) ran the complete local gate on 2026-09-14:
> 483 positive tests, 4 negative contracts, 3 blocked probes still
> blocked, and 216/216 strict SciPy parity. The tarball was checked against its
> release sidecar and the installed payload is the `bin/chelis` extracted from
> it. The Linux glibc-2.31 asset for the same tag (SHA-256
> `9aed0afbfc93a96a6804b4c82664869d74815bd27ca824dfeab02088b00ddb63`; compiler
> payload SHA-256
> `efe99c09f5d7d7372065206a332a2fd86b8aee77412262b0028cfbdbc98a19f2`) and the
> Linux x86_64 asset (SHA-256
> `bb292ca8246381b5e98df5cd029565ec9cfee78820fca9d48bdbb16033c315b2`) were not
> exercised here; their gate run is CI's, not this one. The pin advances from
> 0.18.6 directly to 0.18.9: 0.18.7 was published but never pinned here, and
> 0.18.8 was never published, so this record covers the whole 0.18.7 through
> 0.18.9 span.
>
> **0.18.9 re-probe results.** chelis#676 remains **live**: both
> `tests_blocked/curvefit/` shapes still fail while verifying the backward DAG
> with `mismatched dimension count: 0 vs 1` (seven binary-op nodes are
> reported: nodes 5, 7 and 11 as `0 vs 1`, nodes 13, 19, 24 and 29 as
> `1 vs 0`), so the finite-difference Jacobian narrowing stays. chelis#1464
> remains **live**: `tests_blocked/masked_select/untaken_arm_overflow.ch`
> still fails at its pinned `assert failed: the untaken overflowing arm does
> not poison the selected value`, so both `erf` series clamps stay
> (`chelis test tests_blocked/ --expect blocked` -> 3 ok, 0 failing). All
> three probes carry one source edit this cycle: their scalar lifts are
> rewritten from `expand(scalar_to_tensor(c), 0, extent)` to
> `insert(scalar_to_tensor(c), 0, extent)`, because `expand` now operates on
> an existing axis only. That is migration drift in the probe, of the same
> kind as the 0.18.3 int64 extent widening, not movement on either issue:
> each probe reaches the same layer and the same pinned diagnostic after the
> rewrite. Real `Special.erf(1)` remains green at `0.8427007` through
> package-aware `eval --file`, and the strict parity gate is numerically
> unchanged at 216/216.
>
> **Nothing is retired at this pin.** Both cited issues are open upstream, so
> `conform audit --explain` (row 9, staleness) has no closed-issue citation to
> triage and the audit is conformant. 0.18.9's compiler fixes (chelis#1541, a
> dtype-generic tensor through `if`; chelis#2013, caller-supplied tensor
> arguments for selected host evaluation entries; host gradients that directly
> name a checked declaration now read free tensors from the declaration
> environment) touch surfaces Nautilus never had to work around. The
> host-gradient repair is adjacent to chelis#676's class, but both wrapper
> probes still fail at the same backward-DAG verifier, so no de-narrowing
> follows from it.
>
> **0.18.7 through 0.18.9 breaking changes, and where Nautilus was exposed.**
> Two breaks reached Nautilus source, and both are repaired in this release
> (`docs/chelis-0.18.9-migration.md`): explicit in-package export enforcement,
> which required LinAlg to export `la_basis_n_f32`, `la_zeros_mat_like` and
> `la_tridiag_solve` for their existing consumers and Interpolation to import
> the four LinAlg bindings it uses (nautilus#61); and the scalar-lift axis
> rule, under which `expand` operates on an existing axis only and a new axis
> is introduced through `insert`, which rewrote the three `*_lift_t` helpers
> in `src/` and the three blocked probes above. Values, shapes and tolerances
> are unchanged, which the suite and the 216/216 parity gate confirm. Every
> other break lands on a surface Nautilus does not touch: the reserved
> `normalize` builtin is removed and `conv2d` is replaced by `conv` (neither
> name appears under `src/`, `tests/`, `tests_neg/` or `tests_blocked/`);
> compiler execution JSON advances to v3 and WireDag to v9 with exact numeric
> carriers, and the Python evaluation lane and compiled-context worker
> handoffs move with them (Nautilus drives no wire, proof or Python-binding
> lane; parity reads the `eval --file` text results, which still match all
> 216 goldens); `chelis check <dir>` emits one typed envelope and its error
> objects change shape (Nautilus calls `chelis check` on single files only, in
> CI's rotating smoke and import mutation gate, whose verdict belongs to this
> release's CI run); nominal type applications enforce their parameter counts
> and deep nominal arguments use the recursive type grammar (the whole-package
> `chelis reef build` type-checks every module unchanged); HIP and Metal
> device ownership and ReLU's dedicated identity are backend and builtin
> surfaces Nautilus does not target or call. `chelis-std` stays at 0.4.0,
> compiler-bound to `=0.18.9` in the regenerated `reef.lock`, so there is
> still **no dependency cascade** into this bump.
>
> **One gate repair this pin forced.** `chelis lint --check .` rejects a
> kebab-case narrative filename under `docs/` through `doc-filename-convention`
> (the chelis#190 behavior recorded in the historical evidence below), so the
> migration document for this bump is named `docs/chelis-0.18.9-migration.md`
> rather than the kebab-case spelling the branch first used.

> **Previous pin: `chelis 0.18.6`.** The published Darwin arm64 asset
> (release SHA-256
> `08580435570c6fd44716f4d5c64117e973e379808cefeaaa97c8faefa2588f6c`;
> compiler payload SHA-256
> `1c88c737d7d3740eb4adbe7b50ea31d29ee64498b9d74b35664255ca16aea8d4`;
> source commit `cf49f85bf0d1bca2c87c88a3e459c446912189c0`) ran the complete
> local gate on 2026-08-29: 472 positive tests, 3 negative contracts, 2 blocked
> probes still blocked, and 216/216 strict SciPy parity. The tarball was
> checked against its release sidecar and the installed payload is
> byte-identical to the `bin/chelis` inside it. The Linux glibc-2.31 asset for
> the same tag (SHA-256
> `fb9ef6701fbf0ef2532bcbafb213ca80c21d7b13da0b341b55c64ba89aa8e8fa`) and the
> Linux x86_64 asset (SHA-256
> `c9ed1239ea51a02899a9c6d6cfac0580b8708602d72e9a2b7618037c31720b1a`) were not
> exercised here; their gate run is CI's, not this one.
>
> **0.18.6 re-probe results.** chelis#676 remains **live**: both
> `tests_blocked/curvefit/` shapes still fail while verifying the backward DAG
> (`chelis test tests_blocked/ --expect blocked` -> 2 ok, 0 failing), so the
> finite-difference Jacobian narrowing stays. No probe source drift this cycle;
> both probes reached their pinned diagnostics unmodified. Real `Special.erf(1)`
> remains green and the strict parity gate is numerically unchanged at 216/216.
>
> **Nothing is retired at this pin.** 0.18.6 is a large release, but every one
> of its user-visible breaks lands on a surface Nautilus does not touch. It
> carries no fix for chelis#676, which is the only live narrowing here.
>
> **0.18.6 breaking changes, and why Nautilus is unexposed.** The published C
> numeric ABI is replaced with exact tagged carriers and `bool` narrows to one
> byte (Nautilus links no C runtime and ships no native code); package schema
> and CHB advance to v2 and WireDag to exact-only v6 with a schema-2 Beacon
> envelope (Nautilus republishes its own artifacts as part of this bump and
> drives no proof/Beacon lane); the exported stdlib drops the duplicate prelude
> JSON representation, the legacy JSON and assertion builtin aliases, and
> `init/xavier::sample`. Those aliases are **compiler builtins**, distinct from
> the `Std.Test` module functions Nautilus imports: `Std.Test` still exports
> `assert_true`, `assert_false`, `assert_eq`, `assert_close`,
> `assert_close_tensor`, `assert_eq_tensor`, `assert_shape`, and `fail`
> unchanged, and Nautilus uses no removed name (verified by grep over `src/`
> and `tests/`, and by the suite passing). `Std.Test.assert_close_tensor` now
> requires one shared active-float dtype across both tensors and the tolerance;
> its two callers, `tests/curvefit.ch` and `tests/ode.ch`, already pass f32
> tensors with an f32 tolerance, so both type-check unchanged.
> `JsonBigInt(string)` joins the `Json` ADT (Nautilus has no `Json` reference
> at all). HIP rejects materialized bool tensors (Nautilus does not target
> HIP). And `diagonal`/`trace` are repaired for every axis pair except
> `(rank-2, rank-1)` (chelis#1349). Nautilus reaches both builtins, in
> `src/linalg.ch`: `diag` and `trace_mat`/`trace_scalar` call
> `diagonal(a, 0, 1)` and `trace(a, 0, 1)` on `tensor[n, n, f32]`. At rank 2,
> `(0, 1)` **is** `(rank-2, rank-1)` -- the single pair that was already
> correct -- so every Nautilus result is unchanged, which `tests/linalg.ch`
> confirms still green. A future Nautilus verb taking a non-default axis pair
> would have been silently wrong before this release and is correct now. The
> whole-package
> `chelis reef build` type-checks every module and the full suite passes
> unchanged, which is the construction proof for the source-level items.
>
> Nautilus also carries **no dependency cascade**: its only dependency is the
> compiler-bundled `chelis-std 0.4.0`, so unlike coral and shoals this bump is
> not blocked on a sibling release.
>
> **One conformance repair this pin forced.** chelis#1270 (shipped in chelis PR
> #1279) widened the §4 narrowing-citation grammar so that `<sibling>#NNN`, not
> only `chelis#NNN`, counts as a citation needing coverage. Nautilus used
> `nautilus#45` / `nautilus#47` in four `src/` comments as **provenance notes
> for its own feature PRs**, not as narrowings against anything, and the widened
> grammar read them as uncovered citations -- `conform audit` row 9 fails at
> the new pin. The four notes are rewritten to the non-citation form
> `nautilus PR 45` / `nautilus PR 47`, which preserves the provenance without
> claiming a blocked upstream probe that does not exist. Recording the shape
> because it will recur for any shell that references its own issues in source:
> the widened grammar does not exempt a repo's self-reference.

## Actively blocking

**Re-probe cadence:** at every compiler pin bump and before every Nautilus
release.

- **Concrete arbitrary-model wrapper emits a malformed backward DAG** —
  `chelis#676`
  ([Chelis-Lang/chelis#676](https://github.com/Chelis-Lang/chelis/issues/676)).
  Filed as a function-valued-model-capture witness on `chelis#676` (the same
  backward-DAG verifier class as that issue's tensor-capture reproducer).
    - **Minimal reproducer:** `tests_blocked/curvefit/lm_jacobian_model_wrapper.ch`,
      a concrete `n=2`, `m=6` linear model with expected first Jacobian row
      `[1, 1]`.
    - **0.18.10 release result per surface:** unchanged. Both probes still
      fail while verifying the backward DAG with
      `mismatched dimension count: 0 vs 1` (`chelis test tests_blocked/
      --expect blocked` -> 3 ok, 0 failing, counting the masked-select
      probe, run twice: once by `chelis reef conform bump 0.18.10` and once
      standalone). No probe source drift this cycle -- both reach the same
      verifier layer and the same pinned diagnostic unmodified, so this is a
      clean OK. 0.18.10 is a targeted repair (chelis#2059 interpreter perf and
      chelis#2068 native-C airy ownership); neither touches this backward-DAG
      layer, so no de-narrowing follows. chelis#676 is open upstream.
    - **0.18.9 release result per surface:** unchanged. Both probes still
      fail while verifying the backward DAG with
      `mismatched dimension count: 0 vs 1` (`chelis test tests_blocked/
      --expect blocked` -> 3 ok, 0 failing, counting the masked-select
      probe). Both probes carry a migration edit this cycle: their scalar
      lifts are rewritten from `expand` to `insert` under the 0.18.x axis
      rule, and each still reaches the same verifier layer and the same
      pinned diagnostic, so this is probe drift of the 0.18.3 kind rather
      than movement on chelis#676. The 0.18.9 host-gradient
      declaration-environment repair does not reach this layer. chelis#676
      is open upstream.
    - **0.18.5 release result per surface:** unchanged. Both probes still
      fail while verifying the backward DAG with
      `mismatched dimension count: 0 vs 1` (`chelis test tests_blocked/
      --expect blocked` → 2 ok, 0 failing, run twice: once by
      `chelis reef conform bump 0.18.5` and once standalone). Neither probe
      needed a source edit to reach that layer, so this is a clean OK with no
      drift. No movement on chelis#676.
    - **0.18.4 release result per surface:** unchanged. Both probes still
      fail while verifying the backward DAG with
      `mismatched dimension count: 0 vs 1` (the conform blocked runner
      matched both `.expect` pins at the 0.18.4 bump: 2 ok, 0 failing).
      No probe source drift this cycle -- the canonical Surf v0.19
      migration rewrote both probes and they still reach the same
      verifier layer. No movement on chelis#676.
    - **0.18.3 release result per surface:** both
      `tests_blocked/curvefit/lm_jacobian_generic_dims.ch` and the concrete
      wrapper fail while verifying the backward DAG with
      `mismatched dimension count: 0 vs 1`; the blocked runner pins both
      shapes to this one live class. Both separately type-check at score 1 and
      fail the C build at that diagnostic. The generic shape formerly stopped
      at chelis#847's outer checker error. A direct
      capture-free tensor objective evaluates, C-builds, and compiles
      correctly. At 0.18.3 both probes needed their `expand` extents widened to
      int64 ([05-DIM-1], chelis#1130) before they reached this layer again; the
      intervening `expand expects an int64 size` diagnostic is source drift in
      the probe, not movement on chelis#676.
    - **Affected Nautilus surface:** same AD replacement for `lm_scalar_nparam`;
      this layer remains after concretizing away the generic checker failure.
    - **Workaround:** the cited finite-difference Jacobian (`eps=1e-5`), with its
      documented f32 scaling/cancellation limit.
    - **Re-probe trigger:** every pin bump and the release resolving chelis#676.
      On pass, re-run the generic probe and compare full LM recovery
      trajectories before de-narrowing.

- **An untaken scalar-`if` arm is evaluated under `vmap`** — `chelis#1464`
  ([Chelis-Lang/chelis#1464](https://github.com/Chelis-Lang/chelis/issues/1464)).
  `spec/06` §2.10.1 says an untaken branch is not evaluated. Under `vmap` a
  scalar `if` is lowered to a masked select that evaluates BOTH arms, so an
  untaken arm which overflows poisons the selected value.
    - **Where this sits in chelis#1464:** that issue's title and reproducer
      are a **taken `fail`** arm replaced by a zero `Const`; ours is the
      sibling case, an **untaken arithmetic** arm that overflows. Its
      acceptance criteria already cover us — the second bullet of "Owning
      class and fix shape" reads *"untaken branch: forward value and
      gradient remain unchanged across lanes"*, which is exactly this
      symptom, `grad` included. So the fix as specified should resolve it;
      what the issue lacked was a reproducer exercising that bullet. The
      probe below supplies one, and it is recorded upstream in
      [a comment on chelis#1464](https://github.com/Chelis-Lang/chelis/issues/1464#issuecomment-5575529219)
      and its [correction](https://github.com/Chelis-Lang/chelis/issues/1464#issuecomment-5575722689),
      which withdraws that comment's claim of a scope gap.
    - **Minimal reproducer:** `tests_blocked/masked_select/untaken_arm_overflow.ch`,
      self-contained (it does not call `Nautilus.Special.erf`, so it reports
      on the compiler rather than on our workaround).
    - **0.18.10 result:** unchanged. The probe still fails at `assert failed:
      the untaken overflowing arm does not poison the selected value` with no
      source drift (`chelis test tests_blocked/ --expect blocked` -> 3 ok, 0
      failing), and
      `tests/special.ch::test_erf_series_arm_survives_a_vmapped_huge_input`
      stays green with the clamps in place. chelis#1464 is open upstream.
    - **0.18.9 result:** unchanged. The probe still fails at `assert failed:
      the untaken overflowing arm does not poison the selected value` after
      its scalar lift is rewritten from `expand` to `insert` (`chelis test
      tests_blocked/ --expect blocked` -> 3 ok, 0 failing), and
      `tests/special.ch::test_erf_series_arm_survives_a_vmapped_huge_input`
      stays green with the clamps in place. chelis#1464 is open upstream.
    - **0.18.6 result:** fails at `assert failed: the untaken overflowing arm
      does not poison the selected value` (`chelis test tests_blocked/
      --expect blocked` → 3 ok, 0 failing).
    - **Affected Nautilus surface:** `Nautilus.Special.erf`, whose small-|x|
      arm is a Maclaurin series carrying an `x^7` term that overflows f32 for
      |x| > ~5.5e5. Measured: `erf` on a scalar reduced from a batched tensor
      inside `vmap`, series arm unclamped, evaluates to NaN for a 1e6 input.
      `grad(erf)(1e30)` is NaN under the same mutation.
    - **Distinct from tensor `where`:** a discarded `where` arm holding NaN or
      inf does NOT poison the selected value (probed directly, both cases).
      Deleting `erf_t`'s clamp changes no measured output over a 3771-point
      sweep; it is kept only for lane symmetry with the scalar `erf`.
    - **Workaround:** `erf` clamps its series input to the branch domain, so
      the unselected arm stays bounded on the finite domain.
    - **Pin:** `tests/special.ch::test_erf_series_arm_survives_a_vmapped_huge_input`,
      verified by mutation — removing the scalar clamp turns that value into
      NaN. That test passes both with and without the workaround once the
      compiler is fixed, which is why the blocked probe above, not this test,
      is what orders de-narrowing.
    - **Re-probe trigger:** every pin bump and the release resolving
      chelis#1464. On pass, drop both clamps and archive this entry.

## Tracking

**Re-probe cadence:** at every compiler pin bump.

- **No separately tracked limitation remains.** The active finite-difference
  narrowing and the masked-select narrowing are both blocking and stay above;
  chelis#848 is archived below after its 0.17.5 release-asset re-probe passed
  all 15 shapes.

## Parked

**Re-probe cadence:** at every pin bump and whenever a stated filing condition
is met.

- **No inactive limitation is parked.** The remaining filed issues are
  chelis#676 (backward-DAG wrapper shapes). Chelis#847, chelis#848,
  chelis#970, and chelis#972 are archived below.

## Archived

**Re-probe cadence:** no routine re-probe; revisit only when a regression is
reported or a current narrowing still cites the old behavior.

### chelis#848 — import-only package eval no longer leaks a symbolic input

- **Resolution in the 0.17.5 release:** all 15 import-only shapes in
  `scripts/bench_eval_startup.py` execute through
  `chelis eval --file <path> bench`; none reports the former
  `missing required input 'a' for symbolic dimension 'k'` diagnostic.
- **Downstream de-narrowing:** the benchmark now records import timings instead
  of treating every scenario as blocked. The strict parity route remains green
  and continues to cover real imported calls separately.
- **Regression trigger:** reopen the downstream narrowing only if an
  import-only module or all-module shape again fails. The upstream issue was
  still open when this release-asset verification was recorded.

### chelis#972 — canonical Reef artifact validation is compiler-owned

- **Resolution in the 0.17.4 release:** the public
  `chelis reef verify-artifact --archive ... --shell ... --json` command fully
  consumes the CHB, enforces canonical encoding and metadata order, and checks
  the archive digest embedded in the shell. Reef installation uses the same
  verifier.
- **Downstream de-narrowing:** `scripts/check_release_artifacts.py` now calls
  that command as its canonical pair oracle. Its executable negative gates
  require an archive byte mutation and an appended CHB byte to fail for the
  expected reason.
- **Retained boundary:** the independently transported SHA-256 manifest remains
  because canonical parsing does not authenticate a publisher that can replace
  both payloads and their manifest.
- **Official-asset gate:** the downloaded Linux glibc-2.31 v0.17.5 asset passed
  the same checks on 2026-07-31.

### chelis#970 — unchanged Reef builds are byte-reproducible

- **Resolution in the 0.17.4 release:** Reef canonicalizes
  archive member order, paths, regular-file metadata, and timestamps; the CHB
  embeds the canonical archive digest. Two consecutive Nautilus builds from
  the unchanged checkout produced byte-identical `.tar.zst` and `.chb` files.
- **Downstream de-narrowing:** Linux release CI and Linux/Darwin package CI now
  seal the first build, rebuild without source changes, and validate the second
  build against the first build's SHA-256 manifest.
- **Claim boundary:** this proves unchanged-build identity on each executing
  platform. The jobs do not compare Linux output directly with Darwin output,
  so no separate measured cross-platform identity claim is made.
- **Official-asset gate:** the downloaded Linux glibc-2.31 v0.17.5 asset passed
  the two-build comparison on 2026-07-31.

### chelis#847 — generic vector-model wrapper no longer collapses `n` and `m`

- **Resolution at 0.17.2:** the exact generic
  `&tensor[n] -> &tensor[m] -> tensor[m]` Jacobian wrapper no longer stops at
  `distinct declared dim parameters ... were unified`; it progresses into AD
  lowering.
- **Remaining residue:** the same wrapper now reaches chelis#676's malformed
  backward-DAG verifier failure, identical to the concrete `n=2`, `m=6`
  wrapper. The finite-difference Jacobian therefore remains, cited only to
  chelis#676.
- **Regression coverage:** `lm_jacobian_generic_dims.ch` stays in
  `tests_blocked/curvefit/` as a second shape for chelis#676. Its expected
  diagnostic is the backward-DAG mismatch, so a return of the checker collapse
  is a loud DRIFTED failure.

### `redundant-linearity-call` no longer flags required `copy()`

- **Resolution at 0.16.1:** the historical owned-from-borrowed reproducer's
  required `copy(a)` is not flagged; it checks, C-builds, and package-builds.
  Removing it fails all three surfaces with the expected owned-versus-borrowed
  `TypeMismatch`.
- **Downstream de-narrowing:** the rule identified 131 genuinely redundant
  calls in `src/linalg.ch`; its autofix removed exactly those calls, left 11
  required copies, and the post-fix file check and `chelis reef build` passed.
- **Promoted regression coverage:**
  `tests/linalg.ch::test_linearity_required_owned_from_borrowed_copy` proves
  the required `copy()` remains accepted and numerically live;
  `tests_neg/linearity/borrow_requires_copy_neg.{ch,expect}` proves removing
  it remains a compile-time ownership error. Full-repo lint covers the
  positive source site and must not report the required copy as redundant.
- **Affected surface:** LinAlg source clarity only; no upstream workaround
  remains.
- **Regression trigger:** reopen only if the rule again flags the minimal
  required copy or its advertised fix removes code that fails package build.

### chelis#189 — scalar-f32 evaluator/C-backend constant divergence

- **Resolution:** fixed by chelis PR #243 and consumed by Nautilus PR #5 with
  Chelis 0.7.19.
- **Minimal reproducer:** declare
  `small_val = cast(0.000000123456789, f32)`, compare `chelis eval --file`
  with a C-backend build, and inspect the emitted/runtime value. The broken C
  path printed `0.00000012f` while the evaluator retained `1.23456789e-7`.
- **Affected Nautilus surface:** numeric parity and iterative code in
  `Nautilus.Optim`, `Nautilus.Special`, and `Nautilus.Roots`.
- **Workaround taken:** plateau stops and tolerance floors made those routines
  robust to the old path divergence; no upstream-specific workaround remains.
- **Re-probe trigger:** reopen or reproduce if evaluator and C-backend f32
  constants cease to have the same bit pattern.

### chelis#190 — `doc-filename-convention` classification footgun

- **Resolution:** fixed by chelis PR #244 and consumed by Nautilus PR #5 with
  Chelis 0.7.19.
- **Minimal reproducer:** lint the same narrative filename in two trees that
  differ only by an ancestor `book.toml`; the old classifier switched between
  §8.3 snake_case and §8.5 kebab-case solely because of that marker.
- **Affected Nautilus surface:** documentation linting and mdBook layout.
- **Workaround taken:** Nautilus moved mdBook content under `docs/book/src/`;
  remaining top-level filename cleanup is downstream issue nautilus#7, not an
  upstream compiler blocker.
- **Re-probe trigger:** reopen or reproduce if adding/removing unrelated mdBook
  scaffolding again changes the lint classification of an existing document.

### Pre-contract historical bugs

The historical record below includes the original Bugs 1–7, which were reported
as fixed by Chelis 0.1.21, plus later release-validation observations.
Pre-contract prose-only bug labels are retained as dated evidence but must not
be used as current narrowing citations.

## Historical evidence

### v0.9.0 validation (2026-06-23)

Compiler-pin alignment release from `0.8.0` to `0.9.0`; package
version advanced from `0.7.27` to `0.7.28`. No Nautilus source/API
changes were needed. `chelis-std` stays `0.4.0`. `chelis reef build`
is clean and produces `dist/nautilus-0.7.28.{chb,tar.zst}`; per-file
`chelis check` over `src/*.ch` returns score 1 with no errors;
`chelis fmt --check` is clean across `src/`, `tests/`, and `parity/`;
`chelis test tests/ --timeout 600 --jobs auto` passed **459/459**
native tests; and `parity/run_parity.py --strict` passed **216/216**
scipy-parity samples. Validation was run with the released
`chelis 0.9.0` toolchain first on `PATH`, with `chelis --version`
verified as `chelis 0.9.0` immediately before each Chelis gate.

The 0.9.0 bump has one observable consequence for Nautilus, and it is
in `chelis lint --check .` only (a command Nautilus does **not** gate
on in CI — the gate is `chelis reef build` + `chelis check` score=1 +
`chelis test` + scipy parity):

- **`doc-filename-convention` (§8.3) now flags the kebab-case
  `docs/*.md` filenames (chelis#190 fixed).** 0.9.0 reworked the rule
  from `book.toml`-ancestor detection to path-based detection: the
  §8.5 (kebab-case) mdBook slot now applies only to paths whose
  components include the `book/src` layout, so `docs/*.md` files
  outside `docs/book/src/` are now classified §8.3 (`Slot::Docs`,
  snake_case required) instead of §8.5. This is the exact behavior
  Nautilus filed as chelis#190. `chelis lint --check .` now exits 1 with seven
  `doc-filename-convention` blocking errors over the pre-existing
  kebab-case docs (`benchmark_findings.md`, `eval_startup_findings.md`,
  `maintenance_schedule.md`, `nautilus_status.md`, `upstream-bugs.md`,
  and the two since-removed issue bodies filed as chelis#189 and
  chelis#190). These are
  filename-only lints on documents that long predate this bump; none
  affect `chelis check`, `chelis reef build`, the test suite, or the
  parity gate, all of which are green. Renaming the docs is deferred as
  a separate documentation-hygiene change so the toolchain bump stays a
  mechanical pin alignment; tracked against chelis#190.

### v0.8.0 validation (2026-06-19)

Compiler-pin alignment release from `0.7.27` to `0.8.0`; package
version advanced from `0.7.26` to `0.7.27`. No Nautilus source/API
changes were needed. `chelis reef build` is clean and produces
`dist/nautilus-0.7.27.{chb,tar.zst}`; rotating `chelis check` selected
`src/special.ch` and returned score 1 with no errors; `chelis test
tests/ --timeout 600 --jobs auto` passed **459/459** native tests; and
`parity/run_parity.py --strict` passed **216/216** scipy-parity
samples.

Validation was run with
`/home/jeff/Documents/scratch/chelis-prove-pipeline/target/release`
first on `PATH`, with `chelis --version` verified as `chelis 0.8.0`
immediately before each Chelis gate. No new upstream blockers were
found for the shipped Nautilus surface.

### v0.7.8 validation (2026-05-13)

Compiler-pin alignment release from `0.7.7` to `0.7.8`. No new lint
rules and no new errors: `chelis lint --list` returns the same 16
rules as `0.7.7`, `chelis fmt --check` is clean across `src/` and
`tests/`, `chelis reef build` is clean (`dist/nautilus-0.7.9.{chb,
tar.zst}` produced), **438/438** native tests pass, **216/216**
scipy-parity samples pass.

The `redundant-linearity-call` over-flag on `copy()` (documented
below for `0.7.7`) **still reproduces in `0.7.8`** — `chelis check
src/linalg.ch` emits 319 `redundant-linearity-call` warnings and 194
`prefer-pipe-operator` warnings (`chelis lint src/linalg.ch` emits
319 / 165 — pipe is type-aware and only `chelis check` runs the
inference that surfaces all 194 sites). The workaround posture from
`0.7.7` carries forward unchanged for `0.7.8`.

### v0.7.7 lint regression — `redundant-linearity-call` over-flags `copy()` (2026-05-13)

The new `redundant-linearity-call` warning-severity rule (advertised
under the `implicit-linearity` tag) advertises that source-level
`copy()` is redundant under implicit linearity, but in `0.7.7` the
compiler does **not** auto-insert `copy()` when an owned `tensor[…]`
is required from a borrowed `&tensor[…]` argument. The rule has no
working `--fix` (the CLI accepts `chelis lint --fix --rule
redundant-linearity-call` and exits 0, but produces zero edits).
Stripping the flagged `copy()` calls in bulk across `src/linalg.ch`
causes `chelis reef build` to fail with cascading
`TypeMismatch: tensor[…] vs &tensor[…]` errors.

**Minimal repro** (a user-defined callee that requires owned form):

```chelis
def needs_owned[m, n](a: tensor[m, n, f32]) -> tensor[n, m, f32] =
  permute(a, 1, 0)

def caller[m, n](a: &tensor[m, n, f32]) -> tensor[n, m, f32] = {
  -- chelis lint flags `copy(a)` as redundant-linearity-call,
  -- but removing it produces TypeMismatch in `chelis reef build`.
  needs_owned(copy(a))
}
```

Note: the stdlib `permute(&tensor, …)` actually accepts a borrow, so
`permute(copy(a), 1, 0)` → `permute(a, 1, 0)` builds fine on its own.
The breakage shows up on callees that take owned tensors — e.g. when
`copy()` feeds a downstream call site that consumes the result.

**Workaround applied in nautilus 0.7.8:** retain every `copy()` call
as written. The companion `_ = drop(<expr>)` half of the same
migration scaffolding (902 occurrences across `src/` + `tests/`) **is**
safe to strip — drop statements have unit-typed RHS, ignore the
result, and removing them does not change borrow/owned typing.
`chelis reef build` stays clean and all 438 tests + 216 parity samples
still pass after the strip. The `__borrow_migration_out_N = expr;
__borrow_migration_out_N` orphan binding pairs left behind by the
strip (462 occurrences in `src/` + `tests/`) are also collapsed in
the same change-set.

The `prefer-pipe-operator` warning is also new in 0.7.7 and similarly
ships without a working `--fix`. Hand-mechanical rewrites of the form
`f(g(x), …)` → `g(x) |> f(…)` build and test clean for the subset of
sites where the rest arguments are simple names/literals (red-team
confirmed 2026-05-13 that the rule does NOT trigger recursively on the
rewritten form, contrary to a fear documented in an earlier draft of
this entry). A first pass at mechanical rewriting in the 0.7.8 release
applied the conservative subset across `src/{distance,integrate,
testing}.ch`. Mechanical rewrites in other modules surfaced cross-
module `ArityMismatch` / `CastNonTensor` failures at `chelis reef build`
time that did not surface at single-file `chelis check` time; those
sites were reverted and the remaining advisory warnings are left for a
follow-up refactor that lifts inner calls to named bindings.

### v0.7.6 validation (2026-05-11)

Pin bump plus testing cutover. `reef.toml` advanced to `chelis 0.7.6`
and the native test CI gate now uses released Chelis binaries with
`chelis test tests/ --jobs auto` instead of GitHub Actions sharding.

**Nautilus impact: positive.** The release fixes the v0.7.4 compiled
context lowering regression seen in `tests/curvefit.ch`; no source
module changes were required.

Validation captured at the time of pin:

* `chelis reef build` — clean.
* `chelis test tests/ --jobs auto` — **438 / 438** native tests pass
  in **0:40.06**.
* `chelis test tests/ --jobs 1` — **438 / 438** native tests pass
  in **1:12.96**.
* `parity/run_parity.py --strict` — **216 / 216** scipy-parity
  samples pass.
* Machine-readable timing record:
  `docs/testing_cutover_0.7.6.json`.

### v0.5.0 validation (2026-05-05)

Pin bump only — `reef.toml` advanced from `chelis 0.4.0` to `chelis 0.5.0`
in commit `d80e51c` (Nautilus 0.5.0 release; `ef73bd2` re-bumped after a
chelis registry republish). Upstream `0.5.0` is documented as a
maintenance / registry release; no changes to the public Chelis surface
that Nautilus depends on, no API breaks.

**Nautilus impact: zero.** No `src/` or `tests/` edits were required to
consume the bump. The CI guard fix in `fcb8eee` (sed mutation for the
import-gate matcher) is a Nautilus-internal CI fix triggered by an
unrelated rename of the apismoke imports, not a 0.5.0-induced
regression.

Validation captured at the time of pin:

* `parity/run_parity.py --strict` — **216 / 216** scipy samples pass
  (verified 2026-05-05).
* No fresh red-team probes were run for this pin. Bug 9
  (`chelis eval --file` hang on Nautilus reef imports) was last
  open against `v0.1.21` and is **not retested** for `0.5.0`. Tensor-
  valued `grad` at the C-backend lowering level is similarly carried
  forward as "blocker last verified on `v0.1.21`, not retested for
  `0.5.0`."

This entry is a release-pin acknowledgement, not a re-validation. If
you need a fresh signal on a specific historical bug, re-run the
documented repro at the bottom of that bug's section against the
current toolchain.

### v0.4.0 validation (2026-04-29)

v0.4.0 ships **Phase M — Metal Apple Silicon GPU backend**
(`chelis build --target metal`). Pure Objective-C++ string emission with
embedded MSL kernel strings; no metal-rs Rust dep. Two correctness
bugs caught and locked by the M6 oracle on real hardware (duplicate
`[[thread_position_in_threadgroup]]` and a non-power-of-2 tree-reduction
miscompile). Plus macOS CI hardening (Accelerate framework linking,
`chelis_math.h` include propagation in C codegen).

**Nautilus impact: zero.** The Metal backend is opt-in via
`--target metal`; we ship Linux x86_64 only. No API breaks. No
test/src changes needed. v0.3.2 → v0.4.0 is the workspace's
own version bump; it doesn't change anything Nautilus depends on.

All gates clean on first run after the toolchain pin update:
* chelis check src/*.ch — 21/21 score 1.0
* chelis reef build — clean (`dist/nautilus-0.3.4.{chb,tar.zst}`)
* chelis test tests/ — 438/438
* parity --strict — 205/205
* legacy harness — 1096/1096

### v0.3.2 validation (2026-04-29)

v0.3.2 is a small type-system bug fix: `gt(scalar, tensor)` and other
comparison ops with a leading-scalar arg now correctly return
`tensor[D, bool]` instead of `Prim(Bool)`. Bug introduced in v0.3.1's
broadcast-rewrite block (post-unify override at infer.rs:4441 only
inspected `arg_tys[0]`); v0.3.2 walks all args for the dim source.

Nautilus impact: **none**. We don't write `gt(scalar, tensor)` anywhere
in src or tests. All 438 native + 205 parity + 1096 legacy assertions
pass on first run. Reef build clean. The pin bump is purely a
maintenance keep-current.

### v0.2.7 `chelis check` 1000× slower on GitHub Actions runners (2026-04-26)

Local timing of `chelis check src/<file>.ch` on representative Nautilus
src files (5 sampled): **20-21 ms each**. CI timing of the same command
on `ubuntu-latest`: **~25,000 ms each (25 s)**. Per-file chelis check
across 21 src files takes ~8m22s on CI, dominating wall-clock for the
PR gate.

The cost is in `chelis check` itself — not in our wrapping. Probed by
running the SAME bash heredoc loop locally: completes in ~2 s for 21
files (~95 ms each), so the bash subshell capture / json-parse pipeline
isn't the bottleneck. Whatever expensive work `chelis check` does on
startup (dependency-graph re-resolution? registry index re-validation?
chelis-std re-extraction?) doesn't show up locally on a hot disk cache,
but does on a fresh GHA runner.

**Workaround:** `.github/workflows/ci.yml` now runs `chelis reef build`
(whole-package type-check) on the PR gate plus a single rotating
`chelis check` smoke. The exhaustive per-file score-1 enforcement
moves to `.github/workflows/nightly.yml` where 8 min is acceptable.

**Upstream ask:** profile `chelis check` startup on a cold cache and
identify what's amortizing badly. Likely candidates: chelis-std
tarball re-extraction, registry index walk, OMP runtime init.

### v0.3.0 validation (2026-04-28)

Major upstream release: Compiled Artifact Caching. Headline upstream
numbers: Coral `chelis test` 6m40s → 29.4s cold (13.6×), 11.1s warm
(36×). Nautilus impact is more modest because chelis check stays on
the legacy fitness emitter (no cache benefit) and our matrix-per-file
CI already worked around per-test recompile.

Local timing under v0.3.0 (single thread):

| Operation | v0.2.7 | v0.3.0 cold | v0.3.0 warm | speedup |
|---|---|---|---|---|
| `chelis check src/special.ch` | ~21 ms | 11.7 s | 12.4 s | **regressed** |
| `chelis test tests/distributions.ch` | 41 s | 17.9 s | 17.9 s | 2.3× |
| `chelis test tests/` (full) | ~22 min | 3m 49s | n/a | **5.7×** |
| `chelis reef build` | ~10 s | 11 s | n/a | unchanged |

Two unexpected results:

1. **`chelis check` regressed locally.** v0.2.7 was 21 ms, v0.3.0 is
   12 s — a 600× slowdown. Per the release notes, chelis check stays
   on the legacy emitter; the regression is presumably an unintended
   side effect of the annotate-pass / linearity-checker rewiring.
   The CI cost we documented under v0.2.7 (1000× slower on GHA
   runners) is now likely wash-or-better since local matches CI.
   Workaround unchanged: PR gate stays on `chelis reef build` +
   1-file rotating smoke; full per-file score=1 enforcement stays
   on `nightly.yml`.

2. **`chelis test` cache miss.** v0.3.0 ships disk cache for warm
   re-invocation, but a second `chelis test` on the same file under
   our setup gives the same wall-clock as cold. Either the cache
   path isn't where we expect, or cache key sensitivity to env we
   haven't pinned (HOME? cwd? umask?). Worth investigating but the
   cold-only 5.7× win is already substantial.

#### v0.3.0 linearity tightening (consumer-visible)

Per release notes: "the old monolithic check_linearity was silently
lenient on expressions whose types were unresolved (Cons/Nil etc).
With the annotate fix, real use-after-consume violations surface."

**Hit one site in Nautilus:** `tests/sde.ch::test_milstein_zero_diff_zero_noise_matches_em`
reused `noise` after `euler_maruyama_fixed` consumed it, then passed
the same binding to `milstein_fixed`. Fixed by adding `copy(noise)`
on the first call. v0.2.7 silently accepted the bug; v0.3.0 correctly
rejects. No other Nautilus tests/src files affected.

#### v0.3.0 chelis reef install — chelis-std bootstrap properly resolved

v0.3.0 ships `chelis reef install --from-monorepo <path> [<name>=<version>]`,
the upstream-sanctioned way to populate the local registry from the
chelis monorepo's prebuilt artifacts. `scripts/install_chelis_std.py`
now delegates the file copy + index.json write to this command instead
of doing both by hand. The "v0.2.4 chelis-std bootstrap" entry in this
doc is **resolved** as of v0.3.0.

### v0.2.7 validation (2026-04-26)

- `chelis check src/*.ch` — all 21 modules score 1.0, zero errors.
- `chelis reef build` — clean (`dist/nautilus-0.3.1.{chb,tar.zst}`).
- `chelis test tests/` — **438 / 438 native assertions pass** (411 from
  cutover + 19 LinAlg matmul/permute/sum + 8 Stats higher-moments).
- `parity/run_parity.py --strict` — 205 / 205 scipy samples pass.
- The then-current Python numerical harness — 1096 / 1096 still passing
  during the dual-run window (later retired; preserved in Git history).
- `chelis-std v0.1.0` re-installed from the v0.2.7 monorepo tag.
  The compiler pin embedded in `~/.chelis/reef/index.json` for
  chelis-std jumps from `=0.2.5` → `=0.2.7` (chelis enforces this).
  `scripts/install_chelis_std.py` now reads the pin from the
  installed package's `reef.toml` instead of hardcoding `=0.2.4` —
  the prior hardcode masked this gap until v0.2.7 tightened the
  enforcement.

### v0.2.4 validation (2026-04-25)

- `chelis check src/*.ch` — all 21 modules score 1.0, zero errors.
- `chelis reef build` — produces `dist/nautilus-0.2.2.chb` cleanly.
- `chelis 0.2.4 python tests/run_numeric_tests.py` — **1096 / 1096
  numerical assertions pass** (no regressions vs the v0.2.3 baseline).
- `chelis test --help` — present, documents `--filter`, `--json`,
  `--timeout`. CLI subcommand surface as advertised in the cutover spec.
- **`Std.Test` strict-load probe:** wrote a one-test fixture
  (`/tmp/std-test-probe/tests/probe.ch`) that does
  `import Std.Test (assert_close, assert_true)` and runs `chelis test
  tests/`. Passed cleanly:
  ```
  test_id_close ................. PASS
  test_true ..................... PASS
  ```
  The v0.2.3 strict-load gripe documented in `pseudo_nautilus/tests/
  special.ch` (lines 5–13) is **resolved in v0.2.4**. Nautilus tests
  written during the cutover use `import Std.Test` directly — no
  fallback to raw `test_assert*` builtins is required.

### v0.2.4 chelis-std bootstrap on a fresh Reef registry (2026-04-25)

**Affects:** every CI run on a fresh runner (no pre-existing
`~/.chelis/reef/` cache).

Symptom: every `chelis check` / `chelis test` / `chelis eval` against
a package with `chelis-std` in its `[dependencies]` fails with

```
error: package `chelis-std` version `0.1.0` missing from local
registry index — run `chelis reef build` first to populate the cache
```

But `chelis reef build` itself fails with the **same** error — it
needs the dep to already be in the registry to build. Circular.

`chelis reef --help` lists only `init`, `build`, and `publish`. There
is no `install` / `add` / `fetch` subcommand. `chelis reef publish
<path>` requires a buildable source tree, and the chelis monorepo's
`packages/chelis-std/src/` does not type-check standalone (`unbound
variable: test_assert_eq_tensor_int64`) — only the prebuilt artifact
under `packages/chelis-std/dist/` works.

**Workaround:** `scripts/install_chelis_std.py` clones the chelis
monorepo at the matching tag, copies the prebuilt
`chelis-std-0.1.0.{chb,tar.zst}` into
`~/.chelis/reef/packages/chelis-std/0.1.0/`, and writes
`~/.chelis/reef/index.json` by hand. CI runs this once per job after
the toolchain download.

**Upstream ask:** ship chelis-std as its own release artifact (or
publish to a hosted registry) so downstream packages can fetch it
declaratively. Until then, every shell repo that depends on chelis-std
must replicate the manual-bootstrap dance.

### v0.2.4 chelis test host runtime is missing tensor reductions — FIXED in v0.2.5 (2026-04-25)

**Status as of v0.2.5:** **fixed**. `matmul`, `permute`, and `sum` are
now in the chelis test host runtime. Probed locally with five
representative tests (`inv_2x2`, `transpose`, `frobenius_norm`,
`svd_n` singular-value sum, `matmul_wrap`) — all pass under
`chelis test --timeout 120`. The deferred LinAlg surface is covered
natively in `tests/linalg_matmul.ch` (19 tests).

**Affects (v0.2.4 only):** native `chelis test` coverage of any
`Nautilus.LinAlg` symbol that internally calls `matmul`, `permute`,
or `sum`.

The `chelis test` runtime under v0.2.4 reports `unsupported builtin
'matmul'`, `unsupported builtin 'permute'`, and `unsupported builtin 'sum'`
when those primitives appear in the dependency graph of a test function.
The then-current Python numerical harness did not hit this because it built a
real C binary and linked the chelis runtime
archive — the C backend supports all three.

**Testable from chelis test under v0.2.4:** `lu_solve`, `cholesky_n`,
`qr_decompose` (only via per-element extraction — `Q^T Q` etc. needs
`matmul`/`sum`), `eig_n` (via trace identity, no Frobenius), `cg_solve`,
the bulk vector/matvec surface.

**NOT testable from chelis test (covered only by legacy harness):**
`svd_n` (uses `permute`), `transpose`, `matmul`, `gram`, `aat`,
`matmul_wrap`, `det_2x2`, `det_3x3`, `inv_2x2`, `inv_3x3`, `solve_2x2`,
`solve_3x3`, `eig_2x2_real`, `cholesky_2x2`. The 2x2 surface is in this
list because **`det_2x2` is implemented via the Cayley–Hamilton trick
`(trace² - trace(A²)) / 2` which uses `matmul(A, A)`**. Every downstream
2x2 op (`inv_2x2` → `det_2x2`, `solve_2x2` → `inv_2x2`, `eig_2x2_real`
→ `det_2x2`) inherits the host-runtime gap. `cholesky_2x2` similarly
uses `matmul`. They have native scipy-derived golden coverage in the
legacy harness; until the chelis test host runtime ships these
primitives, the legacy harness must stay in CI.

**Phase 3 deletion gate:** ~~when chelis ships `matmul`/`permute`/`sum`
in the test host runtime, port the deferred coverage to a new
`tests/linalg_matmul.ch` file before deleting `tests_legacy/`.~~
**Resolved in v0.2.5.** `tests/linalg_matmul.ch` shipped with 19
identity tests covering the previously-deferred LinAlg surface.
Red-team round 3 HIGH-2 is closed.

### v0.2.4 upstream observations from cutover red-team (2026-04-25)

These are not bugs but observations worth raising upstream because they
shaped how the Nautilus tests/ files had to be written:

- **`chelis test` recompiles per test function and `--filter` does not
  amortize this cost.** Empirically (red-team CRITICAL-2):
  - `chelis test tests/special.ch` (51 tests) — 31.96 s wall-clock
  - `chelis test --filter test_erf_zero tests/special.ch` (1 test) — 30.17 s
  Filter saves ~6 % — virtually nothing. Per-file compile dominates;
  the `chelis __test_file` worker re-walks the dependency graph for
  every test function. For Nautilus this means the test surface is
  bounded by per-test compile cost, not by the number of small
  assertions. Concretely: `tests/linalg.ch` was originally written as
  4 packed mega-tests (200+ assertions in 4 functions) but timed out
  at >10 min because each per-test compile pulled in the heavy
  factorization graph. The shipped form splits cheap vector ops
  (`tests/linalg.ch`, 29 small tests) from heavy factorizations
  (`tests/linalg_factor.ch`, 6 small tests, ~10 min wall-clock).
- **`chelis eval --file` pays the same per-call compile cost** (~35 s
  with `Nautilus.Special` imported). The Nautilus parity script
  (`parity/run_parity.py`) batches all samples for a domain into one
  probe (`result_0 = ...`, `result_1 = ...`, ...) so total wall-clock
  is ~70 s for 205 samples instead of ~2 hours.
- These compile costs would benefit from a session-cached eval daemon
  or per-build artifact reuse. Recording for future upstream design.

Summary as of **v0.2.0** (Nautilus) / **v0.1.21** (Chelis):

- Historical Bugs 1–5 below are fixed in the released compiler line through
  `v0.1.7`, and the pinned Nautilus surface remains fully wired into the
  current runtime harness on the validated `v0.1.20` toolchain
  (`1051 / 1051` numerical assertions pass as of Nautilus v0.2.0).
- Re-validation against `v0.1.9`–`v0.1.20` on the post-v0.1.7 blockers:
  - **generic fold/control-flow lowering on tensor accumulators is
    FULLY FIXED (since `v0.1.18`).** Both sub-blockers cleared: (a) tuple
    fold with a tensor in slot 0, and (b) tensor-valued `if` inside the
    fold body. General-`n` Cholesky shipped in Nautilus v0.1.3.
  - tensor-valued `grad` at the C-backend lowering level remains blocked
    through `v0.1.20`. `v0.1.19` introduced a new `grad(expr, wrt = var)`
    expression syntax returning `(value, gradient)` tuples (type-checks at
    score 1.0). Despite the syntax improvement, `grad(expr, wrt = var)`
    still fails `chelis build` in v0.1.20 with the error: "can't lower
    these defs — their body applies/binds `grad` (or `vmap`) in a position
    the host lane can't resolve". The workaround path `grad(local,
    wrt=(arg))(arg)` is the only form that builds. Probe also confirms
    `grad` inside a fold body fails build (the error explicitly states
    "`grad` through host-lane `fold`/`map` is not currently supported").
    Multi-parameter LM stays blocked on the grad path; `lm_scalar_nparam`
    ships in Nautilus v0.2.0 using a finite-difference Jacobian workaround.
    Status as of v0.1.21: **still blocked** (not addressed in this release).
  - Recursive inliner bugs (Bug 6, Bug 7 below): **FIXED in v0.1.21**.
    The recursive `lm_jtr_sum` / `lm_jtj_sum` / `lm_jtj_row_sum` formulation
    compiles, builds, and produces correct results. `lm_scalar_nparam` in
    Nautilus v0.2.0 reverts to the cleaner recursive formulation on v0.1.21.

  **New bugs found during Nautilus v0.2.0 / `lm_scalar_nparam` development
  (2026-04-23, against v0.1.20):**

  **Bug 6 — Recursive inliner: NULL shadow on tensor accumulator**
  When the compiler inlines a recursive call that passes a named
  tensor-accumulator variable, the inlined body re-declares the same C
  intermediate name in the inner scope, shadowing the correctly-allocated
  outer variable. The inner shadow is uninitialized (NULL), and the
  explicit NULL-validation stub the harness injects catches it, producing
  `SIGABRT`. Affects any recursive function where the accumulator is a
  tensor passed as a regular argument (not the return value). Status
  as of v0.1.20: **open**. Status as of v0.1.21: **FIXED** — the
  recursive `lm_jtr_sum` / `lm_jtj_sum` formulation compiles and runs
  correctly; `lm_scalar_nparam` reverts to recursive Jacobian assembly.
  Workaround (v0.1.20 only): restructure recursive tensor accumulation as
  top-level folds with the accumulator in the fold's built-in accumulator
  position; never pass intermediate tensor accumulators as explicit
  recursive call arguments.

  **Bug 7 — Recursive inliner: increment propagation to constant arguments**
  When the compiler inlines a recursive call whose counter argument is
  `add(i, cast(1, int64))`, it incorrectly applies the same `+1` increment
  to **all** integer constants inside the inlined body, including
  `cast(0, int64)` literals passed to other called functions. For example,
  `lm_jtj_sum` (which recurses with `add(i, cast(1,int64))`) calls
  `lm_jtj_row_sum(... cast(0, int64) ...)` inside its body; after inlining,
  the `cast(0, int64)` becomes `cast(1, int64)`, causing the row accumulator
  to start at column 1 instead of column 0. Produces wrong numeric results
  (and eventually a `to_list expects a rank-1 tensor` runtime crash when the
  wrong index propagates to a rank-2 value). Status as of v0.1.20: **open**.
  Status as of v0.1.21: **FIXED** — confirmed by the recursive
  `lm_jtj_sum(... cast(0, int64) ...)` call chain producing correct JTJ
  matrices in all test cases (1051/1051 pass with the recursive formulation).
  Workaround (v0.1.20 only): avoid recursive functions for n-parameter Jacobian
  assembly; use flat `fold` over `range(0, n_sq)` with integer `div` and `sub`
  to decode `(i, j)` from a flat index `k`.

  **Bug 8 — Fold closure captures by-move; sequential folds sharing
  tensors need explicit named copies**
  Chelis fold closures capture tensor variables from the enclosing scope
  by-move (consuming them). Two sequential folds in the same function scope
  cannot capture the same tensor — the second fold's closure creation fails
  type-checking with "copy requires tensor input, got ?NNN" because the
  tensor was consumed by the first fold's closure. Scalars (`f32`, `int64`)
  and function types are non-affine and can be captured freely by multiple
  closures. Status as of v0.1.20: **by-design** (affine semantics) but the
  error message is confusing because the failure surfaces at a `copy` call
  downstream of the actual capture site. Workaround: before the first fold,
  create explicit named copies for each fold that needs the variable (e.g.
  `x_c1 = copy(x)` for the JTR fold, `x_c2 = copy(x)` for the JTJ fold),
  and reference the named copies inside the respective fold bodies.

  **v0.1.20 validation findings (2026-04-22):**
  - `chelis check` all 21 `src/*.ch` modules: all score 1.0, zero errors.
  - `chelis reef build`: produces `dist/nautilus-0.1.4.chb` cleanly.
  - `tests/run_numeric_tests.py`: `994 / 994` numerical assertions passed.
  - Grad probe (`grad(loss, wrt = theta)` where `loss = einsum("i,i->", v,
    v)`): `chelis check` passes score 1.0; `chelis build` fails with
    "can't lower" diagnostic. Blocker persists unchanged from v0.1.19.
  - Fold-grad probe (`grad` used inside fold body via `jacobian_col`):
    `chelis check` passes score 1.0; `chelis build` fails with same
    "can't lower" diagnostic, additionally noting "`grad` through
    host-lane `fold`/`map` is not currently supported". Both the direct
    and fold-wrapped grad paths remain blocked.

  **Bug 9 — `chelis eval --file` hangs indefinitely in v0.1.21**
  `chelis eval --file <path> <expr>` blocks without producing output or
  exiting when the file contains a Nautilus reef import (e.g.
  `import Nautilus.Special (erf)`). Inline `chelis eval <expr>` (no
  `--file`) continues to work. Affects `scripts/bench_eval_startup.py`
  which probes all Nautilus import scenarios via `--file`; the script now
  applies a 5-second probe timeout and marks all file-backed scenarios as
  "blocked" on affected toolchains. Status as of v0.1.21: **open**.
  Workaround: use inline `chelis eval <expr>` for expressions that don't
  require file-based reef imports; or set `_PROBE_TIMEOUT_S` in the
  benchmark script to bound the hang.

  **v0.2.1 validation findings (2026-04-23):**
  - `chelis check src/*.ch`: all 21 files score 1.0, no errors.
  - `chelis reef build`: produces `dist/nautilus-0.2.1.chb` cleanly.
  - `tests/run_numeric_tests.py`: 1051 / 1051 numerical assertions passed.
  - Bug 9 (`chelis eval --file` hang): still open in v0.2.1 — `timeout 3 chelis eval --file probe.ch bench` exits 124. Benchmark probe timeouts remain necessary.
  - Tensor-valued `grad` blocker: not retested; `lm_scalar_nparam` continues to use FD Jacobian.
  - No new bugs observed.

  **v0.2.0 validation findings (2026-04-23):**
  - Skipped — upgraded directly to v0.2.1 (same-day release, supersedes v0.2.0).

  **v0.1.21 validation findings (2026-04-23):**
  - `chelis check src/curvefit.ch`: score 1.0 with recursive Jacobian
    formulation (`lm_jtr_sum`, `lm_jtj_sum`, `lm_jtj_row_sum`).
  - `chelis reef build`: produces `dist/nautilus-0.2.0.chb` cleanly.
  - `tests/run_numeric_tests.py`: `1051 / 1051` numerical assertions passed
    with the recursive formulation — confirms Bug 6 and Bug 7 both fixed.
  - Tensor-valued `grad` blocker: not retested (migration guide confirms it
    remains open in v0.1.21; `lm_scalar_nparam` continues to use FD Jacobian).
  - `chelis eval --file` hangs (Bug 9); `bench_eval_startup.py` patched
    with probe timeout; all import scenarios reported as "blocked".

Original historical summary as of **v0.1.6** — original six bugs all fixed, one
new bug found:

| # | Title | v0.1.3 | v0.1.4 | v0.1.5 | v0.1.6 | v0.1.7 |
|---|---|---|---|---|---|---|
| 1 | Unknown-name silent compile | open | **FIXED** | fixed | fixed | fixed |
| 2 | Shape-checker gap for literal-dim tensor params | open | open | open | **FIXED** | fixed |
| 3a | — emitted C was raw pointer arithmetic (original v0.1.3 symptom) | open | likely superseded | superseded | **FIXED** (proper elementwise loop emitted) | fixed |
| 3b | — `chelis build` requires `libchelis_runtime.a` not shipped in tarball | n/a | **NEW in v0.1.4** | **FIXED** | fixed | fixed |
| 3c | — main-entry C emission drops parameters / confuses function names | n/a | **NEW in v0.1.4** | open | **FIXED** | fixed |
| 4 | Nested `exp(neg(mul(x,x)))` int-temp | open | **FIXED** | fixed | fixed | fixed |
| 5 | Fused tensor op `n_in` assertion mismatch | n/a | n/a | n/a | **NEW in v0.1.6** | **FIXED** |

**What v0.1.5 unblocked downstream:**
- `tests/run_numeric_tests.py` dropped the hand-vendored `RUNTIME_STUBS`
  block and now links against the real `libchelis_runtime.a` that
  v0.1.5 copies into the build output dir. 632 / 632 assertions
  still pass.
- The then-current benchmark shared-library builder dropped the hand-vendored
  `RUNTIME_STUBS` for the same reason. The P5 Track 1 LTO +
  visibility workaround (`-flto -fuse-linker-plugin -fvisibility=hidden
  -Wl,-Bsymbolic`) **remains load-bearing in v0.1.5** — v0.1.5's
  C backend still emits cross-TU helpers as extern, so `-shared -fPIC`
  still forces PLT indirection and blocks inlining. Measured regression
  from dropping the flags: 6.7 → 18.9 ns/el (3×) on
  `normal_cdf(x)*exp(-x²)` at n=100k. Flags restored with an updated
  comment citing the v0.1.5 measurement.

**What v0.1.5 did NOT unblock:**
- LinAlg / Distance / SDE / Stats tensor-path runtime verification is
  still gated on Bug 3c. A multi-tensor-input main entry point still
  emits `n_in == 1`, slot 0 labeled by the helper function name, and
  a body that drops the second operand. ~100+ scipy-parity assertions
  in `tests/goldens/linalg/`, `tests/goldens/distance/`, and the
  tensor-path `Nautilus.Stats`/`Nautilus.Sde`/`Nautilus.Interpolation`
  paths remain deferred.

This section is historical. Those tensor-path issues were later fixed
upstream and are now exercised by Nautilus's current `994 / 994`
runtime-harness pass on the pinned `v0.1.19` toolchain.

Original repros below were run against `chelis v0.1.3-linux-x86_64`.
Re-verifications against subsequent releases are noted inline.

---

### 1. Unknown-name silent compile (CRITICAL) — **FIXED in v0.1.4**

**Severity:** critical (silent wrong answers on user-provided function
arguments).

**v0.1.4 status: FIXED.** Re-running the minimal repro against
`chelis v0.1.4-linux-x86_64` now produces a structured error:
```
"unresolved_names": ["cos"],
"errors": [{"kind":"UnboundVariable","message":"unbound variable: cos","severity":0.6}]
```
and fitness score drops to 0.78, failing the CI gate. The
Nautilus-side workaround (`sin(add(x, π/2))` in
`tests/run_numeric_tests.py::cos_minus_x`) is preserved as a passing
identity test since `cos` is still not a Chelis scalar builtin — the
bug fix is "unknown names now error loudly," not "cos is provided."

**Symptom.** Any unresolved function name in expression position is
accepted by the type checker and lowered by the C backend as the identity
function. For example, `cos(x)` — which is not a Chelis builtin — type-
checks cleanly and compiles to a no-op that returns `x`.

**Minimal repro.**

```chelis
def probe(x: f32) -> f32 = sub(x, cos(x))
def main() -> f32 = probe(cast(1.0, f32))
```

```shell
$ chelis check /tmp/probe.ch
{"score": 1, "components": {...}, "errors": []}    # silently passes
$ chelis build /tmp/probe.ch -o /tmp/out
$ grep -c 'cos' /tmp/out/probe.c                   # zero references
0
```

The generated C never references `cos` at all; the whole `sub(x, cos(x))`
expression reduces to `x`.

**Expected behavior.** `chelis check` should emit
`unresolved name: cos` (or similar) as a structured error. Instead
`unresolved_names: []`.

**Where it lives in chelis.** Name resolution / type-env lookup path
(`crates/chelis-types` or `crates/chelis-effects`, whichever handles the
pre-resolution pass for `(app {} (var {} cos) ...)` nodes). The symptom
suggests that unknown names are being threaded through the type
environment as polymorphic identity rather than flagged as errors.

**Downstream impact.** Any user `f: f32 -> f32` argument supplied to
`Nautilus.Roots.{bisection,newton,brent}`,
`Nautilus.Ode.{euler_*,rk4_*}`, `Nautilus.Integrate.{trapezoidal,
simpsons,gauss_legendre_5,adaptive_simpson,romberg_5,gauss_legendre_10}`,
or `Nautilus.Optim.{golden_section_search,brent_minimize,
gradient_descent_1d,newton_minimize_1d}` that references a non-builtin
scalar function (`cos`, `tan`, `atan`, `cosh`, `abs`, `floor`, `ceil`, …)
silently returns wrong answers with no diagnostic.

**Downstream workaround.** Nautilus test code expresses `cos` as
`sin(add(x, π/2))`, `abs` as `if lt(x, 0) then neg(x) else x`, etc. All
module-internal helper functions are documented and audited; users are
warned in `spec/phase3j.md`'s known-limitations section that only the
builtins listed at the top of that doc are safe to call from user
functions.

**Suggested fix sketch.** In the type environment lookup path, when an
`(app {} (var {} NAME) ...)` node's `NAME` is not found, emit a hard
`UnresolvedName` error instead of defaulting to an inferred polymorphic
type. The downstream code path that accepts this silently should have a
diagnostic added (probably a `TODO` or `unimplemented!`) that currently
returns success.

---

### 2. Shape-checker gap for literal-dim tensor parameters (CRITICAL) — **still open in v0.1.4**

**Severity:** critical for negative-test parity claims; medium in
practice (users don't routinely pass wrong-shape inputs, but the spec
promises shape enforcement).

**v0.1.4 status: NOT FIXED.** Re-running the `bad_consumer[m, n]`
repro against v0.1.4:
```
{"score": 1, "unresolved_names": [], "errors": []}
```
`det_2x2(a: tensor[2, 2, f32])` still accepts `tensor[m, n, f32]`
with no error. The suggested fix (`d-lit` parameters requiring exact
match in tensor unification) has not landed. Remains the blocker on
the "negative tests: wrong input shapes" acceptance bullet in
`spec/phase3j.md`.

**v0.1.5 status: NOT FIXED.** Re-running the same repro against
`chelis v0.1.5-linux-x86_64` returns identical output (score 1,
zero errors, empty unresolved_names). Still the blocker on the
negative-test acceptance bullet.

**v0.1.6 status: FIXED.** Re-running the repros against
`chelis v0.1.6-linux-x86_64`:

- `bad_consumer[m, n](a) = det_2x2(a)` — score drops to 0.88, emits
  two `DimensionMismatch: polymorphic dim variable forced to
  concrete Lit(2) by function body — declared dim parameters must
  remain polymorphic` errors.
- `def main(a: tensor[3, 3, f32]) -> f32 = det_2x2(a)` — score
  drops to 0.86, emits `DimensionMismatch: dimension mismatch:
  Lit(2) vs Lit(3)`.

Both wrong-shape and polymorphism-violation angles are now caught
at `chelis check` time. The "negative tests: wrong input shapes"
acceptance bullet in `spec/phase3j.md` §Test Plan is now satisfied
at compile time rather than deferred to runtime.

**Symptom.** `chelis check` does not enforce tensor dimension equality
for literal-size parameters. A function declared `def f(a: tensor[2, 2,
f32])` accepts calls with `tensor[3, 3, f32]`, `tensor[7, 9, f32]`,
`tensor[2, 2, int32]`, or even `f32` (scalar) arguments without any
error.

**Minimal repro.**

```chelis
def want_2x2(a: tensor[2, 2, f32]) -> f32 = trace(a, 0, 1)
def main() -> f32 = want_2x2(uniform_like(cast(0.0, f32), 0.0, 1.0))  # bare f32
```

Or more realistically:

```chelis
def bad_consumer[m, n](a: tensor[m, n, f32]) -> f32 =
  det_2x2(a)   # det_2x2 declares tensor[2, 2, f32]; passes with any (m, n)

def main() -> f32 = cast(0.0, f32)
```

Both type-check at score 1.0 with zero errors.

**Expected behavior.** Each literal-dim parameter should unify
dimension-by-dimension at the call site; mismatch → `DimensionMismatch`
error. Polymorphic dim variables should unify only with other polymorphic
dim variables or concrete matches.

**Where it lives in chelis.** Likely `crates/chelis-types` tensor
unification path for `d-lit` nodes. The symptom is that `d-lit` in a
parameter type is being treated as a polymorphic `d-var` during call-
site unification.

**Downstream impact.** Spec test plan (`spec/phase3j.md` §Test Plan)
requires "negative tests: wrong input shapes, unsupported types". These
cannot be satisfied via `chelis check` alone under v0.1.3. Nautilus
documents this gap in the Known Limitations section of the spec and
defers shape enforcement to runtime (which is itself upstream-blocked on
`libchelis_runtime.a`).

**Suggested fix sketch.** During tensor type unification, treat `d-lit
N` parameters as requiring exact match against the argument's dim at
that position. Only `d-var` / `d-name` should allow polymorphic
unification. If this was intentional for phase-early checker leniency,
add a CLI flag (`chelis check --strict-dims`) to opt in.

---

### 3a. C backend emits raw pointer arithmetic for tensor-on-tensor `add`/`mul` (HIGH) — original v0.1.3 symptom

**Severity:** high — any Nautilus function that combines two rank-2
tensors via `add` or `mul` fails to link as a standalone C binary even
when the math is correct.

**v0.1.4 status: likely superseded.** The pointer-arithmetic
emission path observed in v0.1.3 appears to have been rewritten in
v0.1.4 — `chelis build` now unconditionally routes through the
runtime path (see Bug 3b) rather than emitting inline `tensor* +
tensor*`. We could not directly re-verify the original symptom
against v0.1.4 because the runtime-link step fails before C
inspection is possible, and the few emission paths we did inspect
(via partial builds) exhibit the distinct Bug 3c symptom instead.
Treat 3a as "probably fixed or replaced by 3b/3c" rather than
independently confirmed.

---

### 3b. `chelis build` unconditionally requires `libchelis_runtime.a` not shipped in the release tarball (CRITICAL) — **NEW in v0.1.4**

**Severity:** critical — every `chelis build` invocation, including
scalar-only programs, fails at the link step out of the box after
downloading the v0.1.4 release tarball.

**Symptom.** The v0.1.4 `chelis` binary emits `chelis_runtime.h` and
C source on every build and then attempts to link against a runtime
archive that the release tarball does not contain:

```shell
$ tar tzf chelis-v0.1.4-linux-x86_64.tar.gz
chelis-v0.1.4-linux-x86_64/
chelis-v0.1.4-linux-x86_64/README.md
chelis-v0.1.4-linux-x86_64/LICENSE
chelis-v0.1.4-linux-x86_64/chelis

$ cat > /tmp/scalar.ch <<'EOF'
def main() -> f32 = cast(1.5, f32)
EOF
$ chelis build /tmp/scalar.ch -o /tmp/out
error: cannot find libchelis_runtime.a; set CHELIS_RUNTIME_DIR or
install chelis so libchelis_runtime.a is available relative to the
chelis executable
$ ls /tmp/out
chelis_runtime.h  scalar.c  scalar.h
```

The C emission succeeds (files are on disk), but the automatic
link step fails because there is no `.a` to link against and no
`CHELIS_RUNTIME_DIR` default.

**Expected behavior.** Either (a) the release tarball ships
`libchelis_runtime.a` alongside the binary, or (b) `chelis build`
supports a `--no-link` / `--emit-c-only` mode so callers that
compile the emitted C with their own toolchain (as Nautilus does)
can bypass the link step cleanly.

**Where it lives in chelis.** Release-packaging infrastructure
(CI tarball assembly) plus possibly `crates/chelis-cli` build
command orchestration.

**Downstream impact.** Nautilus's `tests/run_numeric_tests.py`
passes 526/526 only because it compiles emitted C manually with
gcc against its own `RUNTIME_STUBS` set, bypassing the
chelis-builtin link step. Any user who downloads v0.1.4, reads
the README, and runs `chelis build hello.ch` will hit the link
failure on their first program. First-run experience is broken.

**Suggested fix.** Ship `libchelis_runtime.a` in the release
tarball. The symbol surface is already defined by
`chelis_runtime.h` (260 lines, ~60 entry points as of v0.1.4) and
the Rust runtime crate already exists at `crates/chelis-runtime/`
in the monorepo — this is a CI packaging task, not a code change.

**v0.1.5 status: FIXED.** The v0.1.5 release tarball now contains
`bin/chelis`, `lib/libchelis_runtime.a`, and
`include/chelis_runtime.h`, and `chelis build` copies both the
archive and header into its output directory alongside the
generated `.c` / `.h` files. `chelis build hello.ch` on a scalar
program now runs to completion without a link error.
Nautilus's then-current numerical and benchmark harnesses both dropped their
hand-vendored `RUNTIME_STUBS` blocks and now link against the real
archive. 632 / 632 numerical assertions still pass.

---

### 3c. C-backend main-entry emission drops parameters / confuses function names (HIGH) — **NEW in v0.1.4**

**Severity:** high — when a program's entry-point signature
includes more than one tensor parameter, the emitted C silently
drops all but the first and mislabels it using the name of an
inlined helper function.

**Symptom.** Minimal repro:

```chelis
def combine(a: tensor[4, f32], b: tensor[4, f32]) -> tensor[4, f32] =
  add(a, b)

def main(x: tensor[4, f32], y: tensor[4, f32]) -> tensor[4, f32] =
  combine(x, y)
```

Emitted C entry point (`chelis v0.1.4-linux-x86_64`):

```c
void bug3f(chelis_tensor **inputs, int n_in,
           chelis_tensor **outputs, int n_out) {
    if (n_in != 1) {                                   // BUG: expected 2
        fprintf(stderr, "bug3f: expected %d inputs, got %d\n", 1, n_in);
        abort();
    }
    /* ... */
    if (inputs[0] == NULL) {
        fprintf(stderr, "bug3f: input `combine` at slot 0 is NULL\n");
        //                                     ^^^^^^^
        //   BUG: "combine" is the name of the HELPER function, not a parameter
        abort();
    }
    if (inputs[0]->ndim != 1) { /* ... */ }
    chelis_tensor *t0 = inputs[0];
    outputs[0] = chelis_contiguous(t0);   // BUG: no add, no second operand
    if (outputs[0] != t0) chelis_free(t0);
}
```

Three things are wrong:

1. `n_in == 1` instead of 2 — one of the two `main` parameters has
   been silently dropped.
2. The diagnostic label for `inputs[0]` is `"combine"` — the name of
   the helper function `main` calls, not either of `main`'s two
   actual parameter names (`x` or `y`). This suggests the emitter
   is walking the AST of `combine`'s body for parameter names instead
   of `main`'s signature, then stopping after the first match.
3. The body is `chelis_contiguous(inputs[0])` — there is no `add`
   call, no second operand, no elementwise loop. The actual
   computation is gone.

**Expected behavior.** The entry-point wrapper should have
`n_in == 2`, slot-0 labeled `"x"`, slot-1 labeled `"y"`, and a body
that routes both inputs through `combine` (or inlines `add(x, y)`
explicitly with both operands).

**Where it lives in chelis.** C backend, main-signature synthesis
path that generates the `chelis_tensor **inputs` wrapper around the
user's `main` function. Probably `crates/chelis-backend-c/src/emit.rs`
(or wherever main-entry wrapping is emitted), in whatever loop walks
the entry-point parameter list. A plausible root cause is that the
loop stops at the first parameter, and the "combine" label comes
from reusing a helper-function-name variable that should have been
reset per-parameter.

**Downstream impact.** Bug 3b prevents us from running Bug 3c
through a full link + execution, so we cannot confirm the
end-to-end runtime effect. But the emitted C is structurally wrong
enough that no caller with a multi-tensor-input entry point will
get correct results from `chelis build` in v0.1.4. The original
Bug 3 blocker on `Nautilus.LinAlg` runtime verification is
therefore still in place, just via a different failure mode.

**Suggested fix.** Audit the main-entry wrapper emitter for two
bugs: (a) the per-parameter loop that builds the `inputs[]`
validation block is terminating early, and (b) the diagnostic-label
string is being pulled from the wrong scope (the inlined helper
function rather than the entry-point parameter list). Both are
localized to the main-wrapping codegen and should not require
touching the type checker or IR.

**v0.1.5 status: NOT FIXED.** Re-running the same two-input
`main(x, y: tensor[4, f32]) = combine(x, y)` minimal repro against
`chelis v0.1.5-linux-x86_64` produces identical broken output:
`n_in != 1` check (should be 2), slot 0 labeled `"combine"` (the
helper function name, not `x` or `y`), body of
`chelis_contiguous(inputs[0])` with no `add` call and no second
operand. v0.1.5 fixed the runtime-packaging half of Bug 3 (now
shipped as Bug 3b → FIXED) but the main-entry emission symptom is
independent and unchanged. LinAlg / Distance / SDE / Stats
tensor-path runtime verification remains blocked.

---

### 3 (rollup). Downstream impact and unblocking path

All tensor-on-tensor ops in `Nautilus.LinAlg` (`cg_solve`,
`frobenius_sq`, `frobenius_norm`, `la_vec_add`, `la_vec_sub`,
`la_vec_saxpy`, `inv_2x2`, `inv_3x3`, `solve_*`, `cholesky_2x2`)
remain runtime-unverified. Nautilus type-checks them via
`src/apismoke.ch` at package build time. The ~100 deferred
scipy-parity assertions from `tests/goldens/linalg/*.json` stay
deferred until **both** Bug 3b (ship `libchelis_runtime.a`) and
Bug 3c (fix main-entry parameter emission) land upstream.

A minimal unblocking path would be: ship the runtime archive (3b),
fix main-entry emission (3c), and expose rank-1 f32 elementwise
`add`/`sub`/`mul`/`div` entry points in `libchelis_runtime.a`.
That alone lights up `la_vec_*`, `cg_solve`, `frobenius_*`, and
`Nautilus.Distance` — roughly half of the deferred assertions by
count. Nautilus does not plan to invest further downstream effort
trying to work around this; the fix has to come from the compiler
and runtime.

**Symptom.** The chelis v0.1.3 C backend lowers `add(t1, t2)` and
`mul(t1, t2)` where `t1` and `t2` are tensor-typed operands as raw C
pointer arithmetic (`tensor* + tensor*`, `tensor* * tensor*`) instead of
emitting calls to a runtime elementwise-op dispatcher. The generated C
is syntactically valid but semantically meaningless (pointer math, not
elementwise math), and fails to run correctly even when linked against
working runtime stubs.

**Minimal repro.**

```chelis
def combine[n](a: tensor[n, f32], b: tensor[n, f32]) -> tensor[n, f32] =
  add(a, b)

def main() -> f32 = cast(0.0, f32)
```

```shell
$ chelis build /tmp/combine.ch -o /tmp/out
$ grep -n 'chelis_tensor' /tmp/out/combine.c | head
# Generated C references tensor* in signatures but uses + directly on them
$ gcc -c /tmp/out/combine.c
# Warning: arithmetic on pointer to incomplete type
```

**Expected behavior.** The C backend should either (a) emit calls to a
runtime `chelis_tensor_add(chelis_tensor*, chelis_tensor*)` dispatcher,
or (b) unroll the elementwise op as a loop over the backing buffers with
shape/stride checks. Either way, raw pointer arithmetic on
`chelis_tensor*` is never correct.

**Where it lives in chelis.** C backend lowering path for tensor-typed
`(app {} (var {} add) ...)` / `(app {} (var {} mul) ...)` nodes. Likely
`crates/chelis-backend-c/src/emit.rs` or similar, in the elementwise-op
dispatch that currently falls through to the scalar emission path when
the operands' types are `(t-tensor {} ...)`.

**Downstream impact.** This is the reason Nautilus.LinAlg's runtime
numerical verification is deferred — `cg_solve`, `frobenius_sq`,
`frobenius_norm`, `la_vec_add`, `la_vec_sub`, `la_vec_saxpy`, and the
new P3 `inv_2x2` / `inv_3x3` / `solve_*` / `cholesky_2x2` helpers all use
tensor-on-tensor `add`/`mul` / `sub` at some point in their bodies, and
cannot be runtime-tested via the bare-build harness even with a full
runtime-stub shim. Nautilus type-checks them at package build time via
`src/apismoke.ch` and documents the deferral in `spec/phase3j.md`.

**Suggested fix sketch.** In the C backend's op-dispatch table, route
tensor-on-tensor `add` / `sub` / `mul` / `div` to either a runtime
dispatcher or an inline loop emission. For rank-1 f32 tensors the inline
loop is trivial; for higher ranks the runtime dispatcher is the
standard path used by `matmul` / `einsum` / `reduction ops`.

---

### 4. C backend treats `int __arg = exp(...)` nested-call return as int (MEDIUM, worked around) — **FIXED in v0.1.4**

**Severity:** medium — triggered a silent numerical error in
`Nautilus.Special.erf` during P0, worked around via let-binding
extraction.

**v0.1.4 status: FIXED.** The minimal repro
`def bad(x: f32) -> f32 = exp(neg(mul(x, x)))` now emits
```c
double __arg0_0;
double __arg0_1;
double __arg0_2;
__arg0_2 = x;
double __arg1_3 = x;
__arg0_1 = __arg0_2 * __arg1_3;
__arg0_0 = -(__arg0_1);
__result = exp(__arg0_0);
```
— all intermediate temporaries are `double`, not `int`. The downstream
let-binding workaround pattern in `src/special.ch` is preserved as-is
(it's stable code with no comment marker distinguishing it from
stylistic choice) — no source edits required to benefit from the fix.

**Symptom.** When a unary math builtin (`exp`, `log`, `sin`, `sqrt`,
`neg`) is applied to a nested function-call expression in the Chelis
source, the C backend sometimes emits a generated temporary typed `int`
instead of `double`, truncating the float result to the nearest integer
(usually 0 or 1). Extracting the nested call to a let binding first
avoids the bug.

**Minimal repro.**

```chelis
def bad(x: f32) -> f32 = exp(neg(mul(x, x)))         # BUG: int temp
def good(x: f32) -> f32 = {                          # OK: double temp
  s = mul(x, x)
  ns = neg(s)
  exp(ns)
}
def main() -> f32 = bad(cast(1.5, f32))
```

The generated C for `bad` has
```c
int __arg1_37;
__arg1_37 = exp(__arg0_38);
__arg1_35 = __arg0_36 * __arg1_37;   // double * int → 0 for x > 0
```
while `good` produces `double __arg1_37 = exp(__arg0_38)` correctly.

**Expected behavior.** The type of `exp`'s result in the generated C
should match the Chelis source type (`f32` → `double`) regardless of
whether the argument is a let-bound variable or a nested expression.

**Where it lives in chelis.** C backend argument-temporary emission path
when the argument to a scalar math builtin is itself a nested call.
Likely a missing type propagation case in
`crates/chelis-backend-c/src/emit.rs` for the intermediate-temp
declaration.

**Downstream workaround.** Nautilus code defensively extracts any
nested-call argument to a let binding before passing it to `exp`/`log`/
`sin`/`sqrt`/`neg`. See `src/special.ch:erf` for the canonical pattern.
All P0-P3 source has been audited for this pattern.

**Suggested fix sketch.** In the C backend's temporary-typing logic,
propagate the return type of the builtin from the type environment
rather than inferring from the argument expression's shape. One-line
fix likely, though the call-site audit across the backend takes some
care.

---

### 5. Fused tensor op `n_in` assertion mismatch (MEDIUM) — **NEW in v0.1.6**

**Severity:** medium — causes a runtime abort when the call-site
passes more inputs than the fused tensor op wrapper expects. Worked
around in-harness via `_patch_tensor_nin_asserts()`.

**Symptom.** When the C backend fuses a tensor op whose source-level
call passes the same tensor via `copy()` — e.g.
`gram(a) = matmul(transpose(copy(a)), copy(a))` or
`frobenius_sq(a) = trace(matmul(transpose(copy(a)), copy(a)))` — the
backend detects that both operands originate from the same input and
emits a **single-input** fused tensor op wrapper with `n_in == 1`.
However, the *call-site* that invokes this wrapper still passes
**two** input tensors (one per `copy(a)` expansion). The wrapper's
`if (n_in != 1) { abort(); }` assertion fires and the program crashes.

**Minimal repro.**

```chelis
def gram[m, n](a: tensor[m, n, f32]) -> tensor[n, n, f32] = {
  at = permute(a, 1, 0)
  matmul(at, a)
}
def main(a: tensor[2, 3, f32]) -> tensor[3, 3, f32] = gram(a)
```

The emitted C contains a `gram__tensor_0` wrapper with:
```c
if (n_in != 1) {            // fused: expects 1 (de-duped input)
    fprintf(stderr, "gram__tensor_0: expected %d inputs, got %d\n", 1, n_in);
    abort();
}
```

But the call-site in the `gram()` function body passes 2 inputs:
```c
chelis_tensor *__inputs_2[2];
__inputs_2[0] = at;         // transpose(a)
__inputs_2[1] = a;          // same tensor
gram__tensor_0(__inputs_2, 2, __outputs_3, 1);   // n_in == 2 → abort
```

**Expected behavior.** Either (a) the fused op wrapper should accept
2 inputs (matching the call-site), or (b) the call-site should be
lowered to pass 1 input (matching the fused wrapper's expectation).
The fusion and the call-site emission need to agree.

**Where it lives in chelis.** C backend tensor-op fusion path,
likely `crates/chelis-backend-c/src/emit.rs` or similar. The fusion
pass de-duplicates inputs (recognizing that both operands of the
matmul are views of the same tensor), but the call-site emission
doesn't apply the same de-duplication to the `__inputs_N[]` array.

**Downstream impact.** Any `Nautilus.LinAlg` function that involves
`matmul(transpose(copy(a)), copy(a))` or similar self-matmul patterns
— `gram`, `aat`, `frobenius_sq`, `frobenius_norm` — hits this at
runtime. Nautilus works around it via
`_patch_tensor_nin_asserts()` in `tests/run_numeric_tests.py`, which
regex-strips all `n_in` assertion blocks from the emitted C before
compilation. This is a safe patch because the `n_in` check is a
debug guard, not a correctness gate — the actual tensor data flow is
correct once the assertion is bypassed.

**Downstream workaround.** `tests/run_numeric_tests.py::_patch_tensor_nin_asserts()`
replaces every `if (n_in != K) { ... abort(); }` block with
`(void)n_in;` in the emitted C text before gcc compilation. The
workaround is isolated to the linalg test-binary build path.

**Suggested fix.** In the tensor-op fusion emitter, when
de-duplicating inputs, also rewrite the call-site's `__inputs_N[]`
array construction to match the fused wrapper's input count. Or
alternatively, don't de-duplicate in the wrapper — accept all inputs
as passed and internally alias them. Either direction is a small
change confined to the fusion/call-site emission code.

---

### Status and tracking

**v0.1.4 unlocked:** Bugs 1 and 4 shipped upstream fixes. Nautilus
consumed them by bumping the pin from v0.1.3 to v0.1.4 and
re-verifying `chelis check` + `chelis reef build` +
`tests/run_numeric_tests.py` (526/526) — no source-code changes to
`src/*.ch` were required, because the workarounds (`sin(add(x, π/2))`
cos identity and let-binding extraction before `exp`) are either
still needed for a different reason or are stylistically indistinct
from normal code. Paper trail preserved via this file + the
`spec/phase3j.md` Known Limitations section.

**v0.1.4 still blocking:** Bugs 2 and 3 remain open and continue to
gate the same acceptance criteria:

- **Bug 2** blocks the "negative tests: wrong input shapes"
  acceptance bullet in `spec/phase3j.md` §Test Plan.
- **Bug 3** is the most severe for shipping a usable LinAlg surface.
  The v0.1.4 symptom is actually worse than v0.1.3: `chelis build`
  now unconditionally requires `libchelis_runtime.a` (which does not
  ship in the release tarball) even for scalar-only programs, and
  the emitted C for tensor-on-tensor `add` exhibits a new
  parameter-confusion symptom (see §3 above). `tests/run_numeric_tests.py`
  continues to work because it compiles emitted C manually with its
  own stub set, bypassing `chelis build`'s built-in link step.
  Tensor-path runtime verification for LinAlg / SDE / Stats /
  Distance / Interpolation remains deferred; ~100+ scipy-parity
  assertions are still gated on fixing this.

**v0.1.5 unlocked:** Bug 3b shipped upstream — the release tarball
now contains `bin/chelis`, `lib/libchelis_runtime.a`, and
`include/chelis_runtime.h`, and `chelis build` copies the archive and
header into its output directory. Nautilus consumed this by:

- Dropping the hand-vendored `RUNTIME_STUBS` block from
  `tests/run_numeric_tests.py` (~30 lines deleted) and linking
  against the real archive via `-L $outdir -lchelis_runtime`.
- Dropping the same stubs block from the then-current benchmark harness in
  favor of the
  real runtime link.
- Bumping `reef.toml`, CI, README, AGENTS.md, spec/phase3j.md, and
  the test / bench module docstrings from `v0.1.4` to `v0.1.5`.

526 + 106 = 632 / 632 numerical assertions still pass. The P5 Track 1
LTO workaround in the bench script (`-flto -fvisibility=hidden
-Wl,-Bsymbolic`) remains load-bearing: v0.1.5's C backend still emits
cross-TU helpers as extern, so `-shared -fPIC` still forces PLT
indirection. Measured regression from dropping the flags on v0.1.5:
6.7 → 18.9 ns/el (3×) on `normal_cdf(x)*exp(-x²)` at n=100k. Flags
restored with an updated comment.

**v0.1.7 — ALL BUGS FIXED.** Bug 2 (shape-checker) and Bug 3c
(main-entry emission) both shipped upstream fixes. Re-verified:

- Bug 2: `det_2x2(a: tensor[3, 3, f32])` now emits
  `DimensionMismatch: Lit(2) vs Lit(3)` with score < 1.0.
- Bug 3c: `def main(x, y: tensor[4, f32]) = combine(x, y)` now
  emits an entry point with `n_in == 2`, correctly-labeled slots `a`
  and `b`, rank/dim validation for each input, and a full OpenMP
  parallel-for elementwise-add loop:
  `t2->data[i] = t0->data[idx_a] + t1->data[idx_b]`.

**Impact:** All seven tracked upstream bugs are resolved. The deferred
scipy-parity assertions for LinAlg / Distance / SDE / Stats /
Interpolation tensor-path runtime verification are no longer
upstream-blocked and are wired into `tests/run_numeric_tests.py` in
this repo.

When upstream Chelis lands a release with either of these fixed,
Nautilus can re-enable runtime verification paths and tighten the
spec's known-limitations section accordingly. A minimal win would be
shipping `libchelis_runtime.a` with rank-1 f32 elementwise `add` /
`sub` / `mul` / `div` entry points — that alone unblocks `la_vec_*`,
`cg_solve`, `frobenius_*`, and the `Nautilus.Distance` module, worth
roughly half of the deferred assertions by count.
