# Upstream Chelis Bugs

This file records the upstream Chelis compiler issues that currently shape
Nautilus: what each one blocks, how Nautilus works around it, and when to check
it again. It describes the state at the current **pin**, the exact compiler
release that `reef.toml` requires. Nautilus pins `chelis 0.19.1`
(`compiler = "=0.19.1"`).

## How this file works

Every limitation Nautilus works around is filed upstream and cited by number,
as `chelis#NNN` for the compiler or as `<repo>#NNN` for a sibling Chelis
package (written without a space, for example `nautilus#69`). A limitation that
is not yet filed is cited by the path of its draft under `docs/issue_drafts/`.
The same citation appears at the **narrowing site**, the place in Nautilus
where a feature is restricted or replaced because of the limitation, so that
`chelis reef conform audit` can match the two mechanically.

Entries live in one of three sections, each with its own re-probe cadence. To
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
blocked probes at the 0.19.1 pin. The remaining live entries require manual
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

- **The `chelis eval` lane has no tail-call elimination, and its depth limit
  scales inversely with the recursive body's size** — `chelis#2471`
  ([Chelis-Lang/chelis#2471](https://github.com/Chelis-Lang/chelis/issues/2471)).
    - **Symptom:** a self-recursive function that is syntactically a tail call
      still consumes a stack frame per step under `chelis eval --file`, and the
      process dies with `fatal runtime error: stack overflow, aborting` and exit
      134 rather than raising anything a Chelis caller can observe. The frame
      budget depends on how large the recursive body is: a sixteen-binding body
      aborts at about 136 frames where a single-expression body passes 1020.
      The `chelis test` worker thread holds about 500 frames of the same shape,
      so the same input can return a value under `chelis test` and kill the
      process under `chelis eval`.
    - **Affected Nautilus surface:** none as shipped. Every iterative
      numerical kernel whose budget exceeds roughly a hundred steps is
      constrained in how it may spend that budget.
    - **Workaround:** the incomplete-beta continued fraction in
      `src/distributions.ch` spends its 4096-iteration budget through three
      levels of chunking — 16 single steps per chunk, 16 chunks per block, 16
      blocks per driver call — so peak depth is about 48 frames rather than
      4096. The chunking changes no arithmetic: the iteration sequence, the
      convergence test and the result are the flat form's. Without it the
      budget nautilus#143 requires could not be spent in this lane at all.
    - **Reproducer:** on the *inlined* flat recursion that preceded the
      chunking, `beta_cdf(cast(0.5, f32), cast(100000.0, f32),
      cast(100000.0, f32))` needed 162 f32 iterations and aborted. **That
      spelling no longer reproduces anything**: against the current f64 code a
      flattened recursion returns at 1e5 and at 1e6, because delegating each
      step to `betacf_step` leaves a thin frame. Use `a = 1e7` (726 f64
      iterations), and see `tests_blocked/README.md`, which owns the recipe.
      No blocked probe exists, because a probe of this cannot fail as a test —
      it kills the process that would report the failure, which is the defect.
      `tests_blocked/README.md` records it among the manual probes.
    - **Pinned result:** at Chelis 0.19.1 the absent tail-call elimination and
      the body-size-dependent limit both reproduce. With the chunking in place
      every f32 parameter *evaluates* rather than killing the process, including
      `beta_cdf(0.5, 3e38, 3e38)` — which returns a confident `1.0` against a
      true 0.5, so this entry claims only that the process survives, not that the
      answer is usable. The accuracy range is in
      `docs/book/src/appendix/precision.md`.
    - **Re-probe trigger:** every pin bump and the release resolving
      chelis#2471. On pass, the chunking may be collapsed back to a flat
      recursion, which would simplify `src/distributions.ch` substantially;
      compare values bit-for-bit before doing so.

- **Composed generic gradient helper loses runtime-extent binder provenance** —
  `chelis#2370`
  ([Chelis-Lang/chelis#2370](https://github.com/Chelis-Lang/chelis/issues/2370)),
  filed under the runtime-extent tracking issue `chelis#1277`.
    - **Symptom:** composing exact-AD Jacobian rows into the complete
      Levenberg-Marquardt (LM) solver does not pass its recovery tests.
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
    - **Pinned result:** both isolated row witnesses and the shipped
      finite-difference recovery suite pass. At Chelis 0.19.1, replacing
      `lm_jcol` with seeded-output gradients leaves five scalar-path
      tests passing and fails all six multi-parameter recoveries with
      `[05-HOST-1]`: the reached model's `to_list` has no numeric IR lowering.
      This failure occurs before the runtime-extent provenance boundary,
      so that boundary remains unverified.
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
    - **Affected Nautilus surface:** none as shipped; `Nautilus.Rolling` uses
      a closed reducer tag and does not require a function-valued C ABI.
    - **Design:**
      `roll_core` selects its reduction with the closed `Reducer` tag and a
      `match`, instead of taking `red: List[f64] -> f64`. A tag is as
      expressive as the function value here, since the reducer set is closed
      and internal, so there is nothing to de-narrow when the ABI lands.
    - **Condition:** the exact failing condition is uncharacterised. The
      presence of any nullary def or binding makes the minimal reproducer
      build, even when that entry does not reach the function value.
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
    - **Pinned result:** the isolated `probe_sum` / `probe` / `probe_use`
      module above still fails `chelis build` with `[04-TOT-2]`. The shipped
      closed-tag Rolling implementation builds in and across packages.
    - **C consumer gate:** `scripts/check_rolling_c_lane.py` builds the
      shipped closed-tag implementation in and across packages.
    - **Re-probe trigger:** none required. Revisit only if a future reducer
      set has to be open, which would make the function value necessary rather
      than convenient.

- **`match` does not release a branch arm's owner when only a sibling arm
  consumed it** — `chelis#2520`
  ([Chelis-Lang/chelis#2520](https://github.com/Chelis-Lang/chelis/issues/2520)).
    - **Symptom:** ``block bN in `f` is reached with inconsistent live owners``
      during C host lowering. `chelis check`, `chelis test`, `chelis lint` and
      `chelis reef build` all pass; only `chelis build` enters the failing lane.
    - **Scope:** a concrete block-bound-owner `if` probe emits C. The same owner shape
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
    - **Pinned result:** at Chelis 0.19.1, the upstream Option and ADT
      `match` reproducers each fail `chelis build` with `inconsistent live
      owners`; the same block-bound owner in an `if` emits and compiles.
      Manual only because `chelis test` never enters C host lowering. The
      source is in chelis#2520.
    - **Re-probe trigger:** every pin bump, and before merging any change that
      adds a `match` over an owned value consumed on one arm.

- **Float-generic downstream C consumers still require full verification** —
  `chelis#2152`
  ([Chelis-Lang/chelis#2152](https://github.com/Chelis-Lang/chelis/issues/2152)).
    - **Pinned result:** at Chelis 0.19.1, a library exporting
      `apply_cast[prec: Float](g: prec -> prec, x: prec)` was built and
      installed into an isolated Reef store. Separate f32 and f64 consumers
      each built and linked with `chelis build`; both executables printed
      `probe = 1.5`. The full generic Stats, Roots, and LinAlg consumer matrix
      remains unmeasured, so their f32-only bounds remain. The upstream issue
      remains open for its separate IR-lane residue.
    - **Affected Nautilus surface:** `Nautilus.Stats` remains f32-only under
      `nautilus#69`; its full f32/f64 consumer gate is not complete.
      Generic Roots (`nautilus#67`) and LinAlg (`nautilus#12`) need their own
      measured consumers rather than inheriting a verdict from this probe.
    - **Special control:** `Nautilus.Special` uses `{f32, f64}`. The package
      build and its positive/parity suites pass. Separate-package C consumers
      of `erfinv` and `gamma` build, link, and run at f32 and f64; the
      remaining exports have no complete C consumer matrix.
    - **Why no automated gate catches it:** the dependent compile in
      `scripts/check_release_artifacts.py` runs `chelis reef build`, never
      `chelis build`.
    - **Narrowing:** modules other than `Nautilus.Special` and concrete-f64
      `Nautilus.Rolling` remain f32-only. Promote a generic module only after its own downstream C
      consumers build, compile, link, and run at both widths.
    - **Reproducer:** manual only; see
      [`tests_blocked/README.md`](../tests_blocked/README.md). The two-package
      reproducer and its variant table are in chelis#2152.
    - **Re-probe trigger:** every pin bump, and before any `[prec: Float]`
      conversion under nautilus#70 merges.
    - **Pass condition for de-narrowing:** every affected Float-generic
      Nautilus consumer builds, compiles, links, and runs at f32 and f64.
      The minimal reproducer passing does not establish that full result.

- **`chelis eval --file` aborts the process after about 135 frames of a
  let-heavy recursion** — `chelis#2471`
  ([Chelis-Lang/chelis#2471](https://github.com/Chelis-Lang/chelis/issues/2471)).
    - **Symptom:** `chelis eval --file` evaluates on the `main` thread, does no
      tail-call elimination, and overflows its stack at a depth set by how many
      bindings the recursive body holds: 136 frames for a sixteen-binding body,
      past 1020 for a bare single-expression body with no bindings at all. The process dies with `fatal runtime
      error: stack overflow` and exit 134, with no diagnostic a caller can
      catch. Values do not matter: the same body at depth 135 returns whether
      its arguments are finite or not. `chelis test` runs the same
      sixteen-binding body to depth 500 on its `chelis-test-worker` thread and
      reports an overflow there as a test failure rather than killing the
      harness, so the two lanes disagree about whether a program runs. The
      upstream issue's own round-1 comment also reports the absent tail-call
      elimination, the inverse scaling with body size, and the lane difference,
      though that comment states it is relaying one peer measurement rather
      than offering independent corroboration.
    - **Affected Nautilus surface, as narrowed here:** the two incomplete-gamma
      recursions, now `gammainc_series_*` and `gammaq_cf_*` in
      `src/distributions.ch`, and so `Nautilus.Distributions.gamma_cdf`,
      `gamma_sf`, `gamma_pdf`, `chi_squared_cdf`, `chi_squared_sf`,
      `chi_squared_pdf`, `gamma_inv_cdf`, `chi_squared_inv_cdf` and
      `poisson_cdf`, and through them `Nautilus.Testing.chi_squared_p_value`
      and `Nautilus.Stats.likelihood_ratio_p_value`. Each recursion carries a
      65536-iteration budget, which as a flat recursion would cost 65536 frames
      and so could not be spent in that lane at all.
    - **Not covered, and still aborting:** `betacf_rec` in the same module
      carries its own iteration budget with a fatter body. The rest of this
      bullet predates the incomplete beta's move to f64 and its four named
      probes no longer abort; it is corrected separately rather than here,
      because nothing in this change touches that recursion. `chelis eval --file` on
      `beta_cdf(0.5, 1e6, 1e6)`, `beta_cdf(0.5, 1e8, 1e8)`,
      `f_cdf(1.0, 1e7, 1e7)` and `f_cdf(1.0, 1e8, 1e8)` each exit 134 at this
      pin. `student_t_cdf`, `beta_cdf`, `f_cdf` and `binomial_cdf` all reach
      it. This entry does not claim that surface is fixed.
    - **Workaround:** both recursions spend their budget through four levels of
      16-way chunking, so 65536 iterations cost about 64 frames. The chunking
      exists only for the frame cost: it changes no arithmetic, and the
      iteration sequence, the convergence test and the returned value are the
      flat form's bit for bit at the same precision and tolerance. It is no
      longer true that those match the ORIGINAL flat form -- the arithmetic
      moved to f64 and the series' convergence test changed from a 1e-7 test
      floored against 1.0 to a relative 1e-13, so the values differ from the
      pre-f64 lane by design. The non-converged base case still returns the
      partial sum.
    - **Reproducer:** the upstream issue's. The Nautilus-level form is
      `chelis eval --file` over a module binding
      `gamma_cdf(2000.0f32, 2000.0f32, 1.0f32)`, which wants 330 series terms
      at the current f64 tolerance. It wanted 187 under the former f32 lane, so
      a reader comparing against an older copy of this entry should expect the
      count to have risen rather than suspect a miscount.
    - **Why `chelis test` cannot probe it:** the test lane holds about 500
      frames of the same shape, so the chunked form's ~64 frames fit in either
      lane and report a value. See [`tests_blocked/README.md`](../tests_blocked/README.md).
    - **Pinned result:** at Chelis 0.19.0 and 0.19.1 the depth boundaries are
      identical and deterministic over three repeats. With the chunked form,
      `chelis eval --file src/exampledistributions.ch` prints
      `example_gamma_cdf_degenerate_arguments = 11111.0`; against the flat form
      the same command exits 134. That example is evaluated by the CI step that
      runs `chelis eval --file` over `src/example*.ch`, which is the only gate
      that observes the abort.
    - **Re-probe trigger:** every pin bump, and any release touching eval-lane
      stack sizing or tail calls. On a fix, the de-narrowing step is to replace
      the four chunk levels with a single flat recursion over the same
      arithmetic and confirm the example still prints `11111.0`. Note that a
      flat form now needs 65536 frames rather than the 200 this entry was
      written against, so a fix that merely raises the eval stack a little is
      not enough to de-narrow it.

## Tracking

## Archived

**Re-probe cadence:** none. Revisit an entry only when a regression is
reported or a live narrowing cites the archived behavior.

- **`chelis#676`**, backward-DAG verification failure for `grad` through a
  model-capturing Jacobian wrapper. The generic and concrete witnesses pass at
  the pinned compiler as regression tests (`tests/curvefit_lm_jacobian_*.ch`); the
  full LM replacement is still blocked by chelis#2370 above.
- **`chelis#1464`** (Nautilus's untaken-arm witness), an untaken scalar-`if`
  arm evaluated under `vmap` so that an overflowing arm poisoned the selected
  value. The `tests/masked_select/untaken_arm_overflow.ch` regression passes.
  The upstream issue remains
  open for its headline case, a taken `fail` arm masked as zero.
- **`chelis#2151`**, `cast`/`cast_trunc` rejecting a scalar source typed by a
  `Float`-bounded binder. Covered by regression test
  `tests/generic_dtype/scalar_cast_from_float_binder.ch`. The shipped
  `Nautilus.Special` depends on the fix: `is_nonpositive_integer` performs
  exactly this cast, and `gamma`, `log_gamma`, `digamma`, `beta` and `lbeta`
  reach it.
- **`chelis#847`**, generic vector-model Jacobian wrapper unifying distinct
  dimension parameters `n` and `m`. No active Nautilus narrowing cites it.
- **`chelis#848`**, `chelis eval --file` on an import-only file demanding an
  unrelated symbolic input. All 15 import-only shapes in
  `scripts/bench_eval_startup.py` execute.
- **`chelis#972`**, Reef artifact validation.
  `chelis reef verify-artifact` validates the archive and shell pair, and
  `scripts/check_release_artifacts.py` uses it as its canonical oracle. The
  separately transported SHA-256 manifest stays, because canonical parsing
  cannot authenticate a publisher who replaces both payloads and the manifest.
- **`chelis#970`**, non-reproducible Reef builds. Unchanged
  builds are byte-identical on each platform, and CI seals the first build and
  checks a rebuild against it. Linux and Darwin outputs are not compared with
  each other.
- **`redundant-linearity-call` lint over-flagging a required `copy()`**
  (reported before issues were cited by number). Covered by
  `tests/linalg.ch::test_linearity_required_owned_from_borrowed_copy` and
  `tests_neg/linearity/borrow_requires_copy_neg.ch`.
- **`chelis#189`**, f32 constants diverging between the evaluator and the C
  backend. Reopen if evaluator and C-backend f32 constants
  stop sharing a bit pattern.
- **`chelis#190`**, `doc-filename-convention` lint classification changing
  with an unrelated `book.toml`. mdBook pages live under
  `docs/book/src/`.
