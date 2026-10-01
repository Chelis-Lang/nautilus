# Upstream Chelis Bugs

This file records the upstream Chelis compiler issues that currently shape
Nautilus: what each one blocks, how Nautilus works around it, and when to check
it again. It describes the state at the current **pin**, the exact compiler
release that `reef.toml` requires. This Nautilus 0.7.47 source candidate pins
published `chelis 0.18.12` (`compiler = "=0.18.12"`); its release identity and
asset hashes are recorded in [`docs/CHELIS_SURFACE.md`](CHELIS_SURFACE.md).
The last published Nautilus package, v0.7.46, predates this source pin. Earlier
re-probe records are in git history and [`CHANGELOG.md`](../CHANGELOG.md).

## How this file works

Every limitation Nautilus works around is filed upstream and cited by number,
as `chelis#NNN` for the compiler or as `<repo>#NNN` for a sibling Chelis
package (written without a space, for example `nautilus#69`). A limitation that
is not yet filed is cited by the path of its draft under `docs/issue_drafts/`.
The same citation appears at the **narrowing site**, the place in Nautilus
where a feature is restricted or replaced because of the limitation, so that
`chelis reef conform audit` can match the two mechanically.

Entries live in one of four sections, each with its own re-probe cadence. To
**re-probe** an entry is to rerun its reproducer against the pinned toolchain
and record whether the limitation is still present.

| Section | Holds | Re-probe cadence |
|---|---|---|
| Actively blocking | Limitations that narrow, or would narrow, a Nautilus surface | Every compiler pin bump and before every Nautilus release |
| Tracking | Filed limitations that Nautilus follows without being narrowed by them | Every compiler pin bump |
| Parked | Unfiled or inactive limitations awaiting a stated condition | Every pin bump and whenever a stated filing condition is met |
| Archived | Fixed limitations kept for regression context | None; revisit only on a reported regression |

Each live entry states its minimal reproducer (or where to find it), the
affected Nautilus surface, the workaround taken, and an explicit re-probe
trigger.

### Re-probing

Reproducers the test harness can express are **blocked probes** under
`tests_blocked/`: tests that are expected to fail, each paired with a sidecar
file pinning the expected diagnostic. `chelis test tests_blocked/ --expect
blocked` reports each probe as OK (still fails as pinned), FIX-DETECTED (now
passes, so the upstream fix has landed and the workaround should be removed),
or DRIFTED (fails with a different diagnostic, so the failure mode moved and
needs investigation before the citation is reused). There are no executable
blocked probes at the 0.18.12 pin. The three live entries below require manual
probes in lanes `chelis test` does not enter (C host lowering, or a full
algorithm replacement);
[`tests_blocked/README.md`](../tests_blocked/README.md) lists them and gives the
recipes.

At a pin bump, the checklist in `AGENTS.md` governs the order: run the blocked
probes, run `chelis reef conform audit --explain` and triage any closed
upstream issue still cited by a workaround, re-probe every entry here per verb
and per surface, then move entries between sections to match the results. A
changelog claim is not a re-probe.

## Actively blocking

**Re-probe cadence:** at every compiler pin bump and before every Nautilus
release.

- **Composed generic gradient helper loses runtime-extent binder provenance** —
  `chelis#2370`
  ([Chelis-Lang/chelis#2370](https://github.com/Chelis-Lang/chelis/issues/2370)),
  filed under the runtime-extent tracking issue `chelis#1277`.
    - **Earlier symptom:** at 0.18.11 the individual Jacobian-row helpers
      worked, but composing them into the complete Levenberg-Marquardt (LM)
      solver failed during evaluation with a missing runtime-extent binder
      once `grad` crossed the helper.
    - **Affected Nautilus surface:** `Nautilus.CurveFit.lm_scalar_nparam`,
      whose Jacobian cannot yet be computed by exact automatic differentiation.
    - **Workaround:** `lm_jcol` in `src/curvefit.ch` builds the Jacobian by
      forward finite differences (`eps = 1e-5`), with the usual f32 scaling
      and cancellation limits.
    - **Reproducer:** replace the finite-difference Jacobian with its exact-AD
      form and run the six multi-parameter recovery tests in
      `tests/curvefit.ch`. The exact mutation and diagnostic are preserved in
      the upstream issue. Smaller shapes do not reproduce it: the generic and
      concrete Jacobian-row witnesses pass as
      `tests/curvefit_lm_jacobian_generic_dims.ch` and
      `tests/curvefit_lm_jacobian_model_wrapper.ch`, so no bounded blocked
      probe exists yet.
    - **0.18.12 re-probe:** both isolated row witnesses and the shipped
      finite-difference recovery suite pass. A task-local exact-AD replacement
      that differentiated one seeded output at a time failed all six
      multi-parameter recoveries before reaching the earlier provenance
      boundary: `grad` rejected the models' host `to_list` with
      `[05-HOST-1]`. This distinct failure does not establish whether the
      original provenance error persists. No valid full-LM exact-AD
      replacement has passed.
    - **Re-probe trigger:** every pin bump and the release resolving
      chelis#2370. On pass, compare the full LM recovery trajectories before
      removing the finite-difference implementation.

- **`match` does not release a branch arm's owner when only a sibling arm
  consumed it** — `chelis#2520`
  ([Chelis-Lang/chelis#2520](https://github.com/Chelis-Lang/chelis/issues/2520)).
    - **Symptom:** ``block bN in `f` is reached with inconsistent live owners``
      during C host lowering. `chelis check`, `chelis test`, `chelis lint` and
      `chelis reef build` all pass; only `chelis build` enters the failing lane.
    - **Scope at the pin:** the `if` half, `chelis#2477`, is fixed in 0.18.12.
      A concrete block-bound-owner `if` probe emits C. The same owner shape
      with `Option` and ADT `match` still rejects in `chelis build` with
      `inconsistent live owners`, so `lower_match_option` and
      `lower_match_adt` remain blocked.
    - **Affected Nautilus surface:** none today. `src/` contains no `match`,
      no ADT and no `Option`. The entry becomes live for any change that
      introduces a `match` over an owned value consumed on one arm, and such a
      change must probe its own C build.
    - **Trigger shape:** the owner must be bound from a block expression, so
      that `consume` moves it rather than copies it inside the arm (a plain
      binding copies and owes no release), and the consuming arm must be the
      first one; the mirror image passes because the desugared pattern chain
      puts later arms one scope deeper. The upstream reproducers use concrete
      `i64` with no dtype binder, so the risk is not limited to
      `[prec: Float]` conversions, and no particular mechanism should be
      inferred from them.
    - **Workaround:** none needed while no `src/` code uses `match`.
    - **Reproducer:** manual only, because `chelis test` never enters C host
      lowering. The reproducers are in chelis#2520.
    - **Re-probe trigger:** every pin bump, and before merging any change that
      adds a `match` over an owned value consumed on one arm.

- **Float-generic downstream C consumers still require full verification** —
  `chelis#2152`
  ([Chelis-Lang/chelis#2152](https://github.com/Chelis-Lang/chelis/issues/2152)).
    - **Earlier symptom:** at 0.18.11 the issue's headline shape, an imported
      `cast(numel(v), prec)`, emits C from a concrete f32 consumer. The
      remaining minimal shape combines a function-typed parameter with a
      scalar cast, `apply_cast[prec: Float](g: prec -> prec, x: prec)`: both
      packages pass `chelis reef build`, then the consumer's `chelis build`
      rejects with ``unsupported: dtype `prec` on a `cast` target in host
      lowering``, at f32 and at f64.
    - **0.18.12 re-probe:** that function-parameter-plus-cast shape, installed
      as a separate library in an isolated Reef home, passed consumer
      `chelis build`, clang link, and execution at both f32 and f64; outputs
      were 1.5. A copy of the work-in-progress generic Stats branch built
      after Surf migration, and its `mean_vec` consumer emitted C, linked,
      and returned 2.0 at both widths. A broader Stats consumer covering
      mean, standard deviation, quantile, trimmed mean, and correlation had
      no C verdict after roughly 80 seconds and was stopped. These successes
      narrow the blocker; they do not certify every generic Stats or Roots
      consumer. The upstream issue remains open for its separate IR-lane
      residue.
    - **Related issues:** `chelis#1418` reported the same diagnostic and is
      closed; its fixes first shipped in 0.18.7. The checker-side mirror,
      `chelis#2151`, is fixed at this pin (see Archived).
    - **Affected Nautilus surface:** `Nautilus.Stats` remains f32-only under
      `nautilus#69`. The old C failure blocked its generic branch at 0.18.11;
      this pin has not completed that branch's full f32/f64 consumer gate.
      Generic Roots (`nautilus#67`) and LinAlg (`nautilus#12`) need their own
      measured consumers rather than inheriting a verdict from this probe.
    - **Prior Special control:** the Float-generic `Nautilus.Special`
      (`nautilus#59`) did not hit this defect at 0.18.11.
      A two-package probe at 0.18.11 built a consumer calling `erf`, `erfc`,
      `gamma`, `log_gamma` and `ellipk` at f32 and f64; `chelis build`
      emitted C, `clang` compiled and linked it, and the f32 results were
      bit-identical to the same consumer built against the f32-only module.
      Its source remains generic in this pin; the official full package
      build and positive/parity suites pass. A fresh separate-package C
      control is still needed before claiming that exact lane.
    - **Why no automated gate catches it:** the dependent compile in
      `scripts/check_release_artifacts.py` runs `chelis reef build`, never
      `chelis build`.
    - **Current narrowing:** modules other than `Nautilus.Special` remain
      f32-only. Promote a generic module only after its own downstream C
      consumers build, compile, link, and run at both widths.
    - **Reproducer:** manual only; see
      [`tests_blocked/README.md`](../tests_blocked/README.md). The two-package
      reproducer and its variant table are in chelis#2152.
    - **Re-probe trigger:** every pin bump, and before any `[prec: Float]`
      conversion under nautilus#70 merges.
    - **Pass condition for de-narrowing:** every affected Float-generic
      Nautilus consumer builds, compiles, links, and runs at f32 and f64.
      The minimal reproducer and one `mean_vec` consumer passing do not
      establish that full result.

## Tracking

**Re-probe cadence:** at every compiler pin bump.

- **None at this pin.** Every filed issue that affects Nautilus
  (`chelis#2370`, `chelis#2520`, `chelis#2152`) is listed under Actively
  blocking.

## Parked

**Re-probe cadence:** at every pin bump and whenever a stated filing condition
is met.

- **None at this pin.** No limitation is parked and no draft is pending; the
  drafting convention is in
  [`docs/issue_drafts/README.md`](issue_drafts/README.md).

## Archived

**Re-probe cadence:** none. Revisit an entry only when a regression is
reported or a live narrowing cites the old behavior.

- **`chelis#676`**, backward-DAG verification failure for `grad` through a
  model-capturing Jacobian wrapper. The generic and concrete witnesses pass at
  0.18.11 and are regression tests (`tests/curvefit_lm_jacobian_*.ch`); the
  full LM replacement is still blocked by chelis#2370 above.
- **`chelis#1464`** (Nautilus's untaken-arm witness), an untaken scalar-`if`
  arm evaluated under `vmap` so that an overflowing arm poisoned the selected
  value. Passes at 0.18.11 as `tests/masked_select/untaken_arm_overflow.ch`,
  and the `erf` series-input clamps are removed. The upstream issue remains
  open for its headline case, a taken `fail` arm masked as zero.
- **`chelis#2151`**, `cast`/`cast_trunc` rejecting a scalar source typed by a
  `Float`-bounded binder. Fixed at 0.18.11, with regression test
  `tests/generic_dtype/scalar_cast_from_float_binder.ch`. The shipped
  `Nautilus.Special` depends on the fix: `is_nonpositive_integer` performs
  exactly this cast, and `gamma`, `log_gamma`, `digamma`, `beta` and `lbeta`
  reach it.
- **`chelis#847`**, generic vector-model Jacobian wrapper unifying distinct
  dimension parameters `n` and `m`. Fixed at 0.17.2.
- **`chelis#848`**, `chelis eval --file` on an import-only file demanding an
  unrelated symbolic input. Fixed at 0.17.5; all 15 import-only shapes in
  `scripts/bench_eval_startup.py` execute.
- **`chelis#972`**, Reef artifact validation. Since 0.17.4,
  `chelis reef verify-artifact` validates the archive and shell pair, and
  `scripts/check_release_artifacts.py` uses it as its canonical oracle. The
  separately transported SHA-256 manifest stays, because canonical parsing
  cannot authenticate a publisher who replaces both payloads and the manifest.
- **`chelis#970`**, non-reproducible Reef builds. Since 0.17.4, unchanged
  builds are byte-identical on each platform, and CI seals the first build and
  checks a rebuild against it. Linux and Darwin outputs are not compared with
  each other.
- **`redundant-linearity-call` lint over-flagging a required `copy()`**
  (reported before issues were cited by number). Fixed at 0.16.1. Covered by
  `tests/linalg.ch::test_linearity_required_owned_from_borrowed_copy` and
  `tests_neg/linearity/borrow_requires_copy_neg.ch`.
- **`chelis#189`**, f32 constants diverging between the evaluator and the C
  backend. Fixed at 0.7.19. Reopen if evaluator and C-backend f32 constants
  stop sharing a bit pattern.
- **`chelis#190`**, `doc-filename-convention` lint classification changing
  with an unrelated `book.toml`. Fixed at 0.7.19; mdBook pages live under
  `docs/book/src/`.
