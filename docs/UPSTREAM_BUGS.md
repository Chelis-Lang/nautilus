# Upstream Chelis Bugs

This file records the upstream Chelis compiler issues that currently shape
Nautilus: what each one blocks, how Nautilus works around it, and when to check
it again. It describes the state at the current **pin**, the exact compiler
release that `reef.toml` requires. This Nautilus 0.7.48 source candidate pins
published `chelis 0.18.13` (`compiler = "=0.18.13"`); its release identity and
asset hashes are recorded in [`docs/CHELIS_SURFACE.md`](CHELIS_SURFACE.md).
The last published Nautilus package, v0.7.47, predates this source pin. Earlier
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
blocked probes at the 0.18.13 pin. The remaining live entries require manual
probes in C host lowering or a full algorithm replacement;
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
    - **0.18.13 re-probe:** both isolated row witnesses and the shipped
      finite-difference recovery suite pass. A task-local exact-AD replacement
      differentiated one seeded output at a time and failed all six
      multi-parameter recoveries with `[05-HOST-1]`: the reached model's
      `to_list` has no numeric IR lowering. The other five CurveFit tests
      passed. The earlier provenance boundary was not reached, so this result
      does not establish whether that error persists. The finite-difference
      source was restored after the probe.
    - **Re-probe trigger:** every pin bump and the release resolving
      chelis#2370. On pass, compare the full LM recovery trajectories before
      removing the finite-difference implementation.

- **A function-typed parameter cannot cross the C host boundary** —
  `chelis#909`
  ([Chelis-Lang/chelis#909](https://github.com/Chelis-Lang/chelis/issues/909)),
  with `chelis#867` recording that no issue owns that ABI, so the rejection
  cites the plan rather than a defect.
    - **Symptom:** `chelis build` fails with ``unsupported: verified
      user-function call site has no direct-call authority on verified C host
      ownership emission (codegen:c) ... [04-TOT-2]``. Package-level gates are
      green.
    - **Affected Nautilus surface:** none as shipped, and this entry is
      recorded for the reader who reverts the tag, not because the shipped
      module depends on the ABI landing.
    - **Workaround — and this one is the design, not a narrowing to retire.**
      `roll_core` selects its reduction with the closed `Reducer` tag and a
      `match`, instead of taking `red: List[f64] -> f64`. A tag is as
      expressive as the function value here, since the reducer set is closed
      and internal, so there is nothing to de-narrow when the ABI lands.
    - **The exact condition is NOT characterised here, deliberately.** Three
      successive attempts to state it were each refuted by measurement: "no
      statically resolvable callee", "cannot be called at all", and
      "specialised from a concrete nullary root". The last failed because the
      mere presence of *any* nullary entry in the module -- including a def or
      binding that never reaches the function value -- is enough to make the
      reproducer build. Whatever the rule is, it is not reachability, and this
      entry does not guess a fourth time. What is established is below.
    - **Reproducer** (fails at this pin, as the only content of a module):

      ```text
      def probe_sum(ws: List[f64]) -> f64 =
        fold(fn (a: f64, x: f64) -> add(a, x), cast(0.0, f64), ws)
      def probe(xs: List[f64], red: List[f64] -> f64) -> f64 = red(xs)
      def probe_use(xs: List[f64]) -> f64 = probe(xs, probe_sum)
      ```

      Variants that fail the same way in that module: the parameter called
      inside a `map` lambda, the argument supplied as an immediate lambda, and
      the def left with no caller. Each BUILDS once any nullary def or binding
      is added, whether or not it reaches the call. An `if`-selected or
      returned function value is a distinct sub-shape failing with `no target
      ABI representation` rather than `[04-TOT-2]`.
    - **0.18.13 re-probe:** the isolated `probe_sum` / `probe` / `probe_use`
      module above still fails `chelis build` with `[04-TOT-2]`. The shipped
      closed-tag Rolling implementation builds in and across packages.
    - **The load-bearing fact, and the actual justification for the tag.**
      At the earlier pin, reverting `roll_core` to
      `red: List[f64] -> f64` while keeping the hoisted `Option` defs failed
      with `[05-UNS-1]`, the now-fixed chelis#2599 class rather than
      `[04-TOT-2]`. The closed reducer tag remains a deliberate API design.
      `scripts/check_rolling_c_lane.py` guards the shipped C consumers.
    - **Re-probe trigger:** none required. Revisit only if a future reducer
      set has to be open, which would make the function value necessary rather
      than convenient.

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
    - **Affected Nautilus surface:** the existing `Reducer` match and
      `Option` paths build successfully. The specific block-bound owner shape
      in the upstream reproducers is absent; adding that shape requires its
      own C build.
    - **Trigger shape:** the owner must be bound from a block expression, so
      that `consume` moves it rather than copies it inside the arm (a plain
      binding copies and owes no release), and the consuming arm must be the
      first one; the mirror image passes because the desugared pattern chain
      puts later arms one scope deeper. The upstream reproducers use concrete
      `i64` with no dtype binder, so the risk is not limited to
      `[prec: Float]` conversions, and no particular mechanism should be
      inferred from them.
    - **Workaround:** none needed for the shipped match shapes.
    - **0.18.13 re-probe:** the upstream Option and ADT `match` reproducers
      each fail `chelis build` with `inconsistent live owners`; the same
      block-bound owner in an `if` emits and compiles. Manual only because
      `chelis test` never enters C host lowering. The source is in chelis#2520.
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
    - **0.18.13 re-probe:** a library exporting
      `apply_cast[prec: Float](g: prec -> prec, x: prec)` was built and
      installed into an isolated Reef store. Separate f32 and f64 consumers
      each built and linked with `chelis build`; both executables printed
      `probe = 1.5`. The full generic Stats, Roots, and LinAlg consumer matrix
      remains unmeasured, so their existing f32-only bounds remain.
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
  (`chelis#2370`, `chelis#2520`, `chelis#2152`) is listed under
  Actively blocking.

## Archived

**Re-probe cadence:** none. Revisit an entry only when a regression is
reported or a live narrowing cites the old behavior.

- **`chelis#2599`**, bare `None` in a lambda arm could leave an unresolved host
  inference variable in C lowering. At 0.18.13 the exact `map` reproducer
  from this entry checks and emits C. The four named `Option` helper bodies in
  `src/rolling.ch` are inlined into their callers; `scripts/check_rolling_c_lane.py`
  builds all 34 Rolling exports in package and in a separate package, including
  C compilation and linking.
- **`chelis#3156` / `chelis#2443`**, the 0.18.12 syntax block on dtype-set
  binders. At 0.18.13 `src/special.ch` checks and builds with all 67 binders
  narrowed to `{f32, f64}`. Negative tests reject `gamma(5.5bf16)` and
  `bessel_j0(5.0f16)` at the call site; the full positive suite keeps f32/f64
  behavior green. The remaining ecosystem republish sequence tracked by
  chelis#3156 does not narrow Nautilus after this bump. nautilus#75 is fixed
  by the Special change; the 35 large literal suffixes remain nautilus#83.

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
