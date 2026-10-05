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
blocked probes at the 0.18.12 pin. All six live entries below require manual
probes: five sit in lanes `chelis test` does not enter (C host lowering, C host
ABI, linearity, or a full algorithm replacement), and one is a syntax-level
blocker whose probe file would not parse;
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

- **A bare `None` fixed only by its sibling arm does not lower to C** —
  `chelis#2599`
  ([Chelis-Lang/chelis#2599](https://github.com/Chelis-Lang/chelis/issues/2599)),
  **fixed upstream by chelis#2888 and NOT in this pin.**
    - **Symptom:** `chelis build` fails with ``host type did not resolve
      before the code-generation boundary: unresolved host inference variable
      `N` ([05-UNS-1]; chelis#730)``. `chelis check`, `chelis eval`,
      `chelis test` and `chelis reef build` are all green, and `chelis reef
      build` cannot see it because it does not enter host lowering.
    - **Why it is live here:** chelis#2888 merged 2026-10-02; v0.18.12 was
      published 2026-09-30. Both of chelis#2599's own verbatim reproducers
      still fail at this pin, measured, and so does the same shape at `f64`.
    - **Affected Nautilus surface:** every `Nautilus.Rolling` export that can
      report absence, which is 15 of its 17 list exports and their `tensor_`
      twins.
    - **Workaround:** each `Option`-producing body is a named def with an
      explicit `-> Option[f64]`, rather than a bare `None` in a lambda arm:
      `roll_entry`, `roll_diff_at`, `roll_pct_at` and `roll_at` in
      `src/rolling.ch`. An annotated named def fixes the type locally, which
      is what lowering needs.
    - **Reproducer** (fails at this pin, in a scratch module under `src/`):

      ```text
      def probe(n: i64) -> List[Option[f64]] =
        map(fn (i: i64) -> if lt(i, n) then None else Some(cast(1.0, f64)),
            range(cast(0, i64), cast(4, i64)))
      ```

      `chelis build -o <dir> src/<probe>.ch`. Not expressible as a
      `tests_blocked/` probe: the failure is in the build lane, and
      `chelis test` never invokes `chelis build`. See
      `tests_blocked/README.md` §cannot-be-probed.
    - **Re-probe trigger:** the next pin bump past v0.18.12. On pass, inline
      those four helpers back into their lambdas, delete this entry, and keep
      `scripts/check_rolling_c_lane.py` green.

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
    - **The load-bearing fact, and the actual justification for the tag.**
      Reverting `roll_core` to `red: List[f64] -> f64` while keeping the
      hoisted `Option` defs fails with `[05-UNS-1]` *"unresolved host
      inference variable"* — **not** `[04-TOT-2]`. So the blocker that
      governs this module is the host-inference class above, and the
      function-value ABI is a separate limitation that this module simply does
      not depend on. Hoisting the `Option` bodies alone does not fix the
      higher-order shape, which is the measured reason the function value had
      to go, and `scripts/check_rolling_c_lane.py` is what keeps it gone.
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

- **A dtype binder cannot be bounded narrower than a family, so `Float`
  admits f16/bf16 to `Nautilus.Special`** — `chelis#3156`
  ([Chelis-Lang/chelis#3156](https://github.com/Chelis-Lang/chelis/issues/3156)),
  **the expressiveness itself was fixed upstream by chelis#2443 and is NOT in
  this pin.**
    - **Symptom:** `[prec: {f32, f64}]` is a parse error at this pin
      (`expected identifier or type identifier, found LBrace`), so a generic
      declaration can be bounded only by `Float`, `Int` or `Numeric`
      (spec/04-type-system.md §5.9). `Float` has four members and
      `Nautilus.Special` supports two of them.
    - **Why it is live here:** chelis#2443 was resolved by chelis#2827,
      squashed as `a762596b8`, on chelis `main` 2026-10-02. v0.18.12 was
      published 2026-09-30, so no release carries the form. The release that
      would carry it also moves `SHELL_FORMAT_VERSION` 5 → 6 and
      `PACKAGE_SCHEMA_FORMAT_VERSION` 3 → 4 in the same commit, so it cannot
      read any currently published shell and forces a re-publish wave in
      dependency order (nautilus, then coral, then shoals). That release
      blocker is chelis#3156 and is the citation here; chelis#2443 is closed.
    - **Affected Nautilus surface:** all 23 `Nautilus.Special` exports, via 67
      `[prec: Float]` binders in `src/special.ch`. Measured at this pin
      through the built package: `gamma(5.5bf16)` = 58.0 against a true
      52.34277778455352 (10.8% off, far outside bf16's own resolution),
      `bessel_y1(2.2bf16)` = 0.0059814453125 against 0.0014877892897632759
      (4.0x), and `bessel_j0(5.0f16)`, `bessel_j1(1.5f16)`,
      `bessel_y0(1.5f16)` all NaN. The same calls at `f32` and `f64` are
      correct: `gamma(5.5f32)` = 52.342891693115234, `gamma(5.5f64)` =
      52.342777784553576 (8 ulp above the correctly rounded
      52.34277778455352, which is this module's own f64 accuracy and not a
      finding of this entry).
    - **Workaround:** none in the type system; the hazard is disclosed in
      `docs/CHELIS_SURFACE.md`, `CHANGELOG.md`, `SKILL.md` §5 and the book's
      `appendix/limitations.md`, `appendix/precision.md` and
      `special/overview.md`. Note that the module checks at all only because
      the 35 coefficients outside f16's range carry an explicit `f64` suffix
      (`cast(57568490574.0f64, prec)`), which satisfies `[04-LIT-2]`
      (chelis#2123) and moves the f16 overflow from compile time to run time.
      Removing those suffixes is nautilus#83, not this entry.
    - **Reproducer** (fails at this pin, in a scratch module):

      ```text
      def admits_two_precisions[prec: {f32, f64}](x: prec) -> prec = x
      ```

      `chelis check <file>` gives ``surf-parses (§12.5): cannot be parsed as
      Surf: expected identifier or type identifier, found LBrace``. The
      f16/bf16 values above reproduce by calling any `Nautilus.Special` export
      at `f16` or `bf16` from a module in this package and evaluating it.
      Not expressible as a `tests_blocked/` probe: the blocker is at the
      syntax level, so the probe file does not parse, and
      `chelis lint --check .` has no per-path exclusion and rejects it as a
      blocking `surf-parses` error. Both halves of that were measured — as a
      probe it reports OK at this pin and FIX-DETECTED against a source build
      of chelis `main` @ `b5b59d958`, and it also adds two blocking lint
      errors. See `tests_blocked/README.md` §cannot-be-probed.
    - **Re-probe trigger:** the next pin bump past v0.18.12. On pass, narrow
      the 67 binders in `src/special.ch` to `[prec: {f32, f64}]`, hand the 35
      `f64` suffixes to nautilus#83, drop the hazard rows from
      `docs/CHELIS_SURFACE.md` and the three book pages, and archive this
      entry. Closing nautilus#75 needs the narrowing on merged `main`, not the
      pin bump alone.

## Tracking

**Re-probe cadence:** at every compiler pin bump.

- **None at this pin.** Every filed issue that affects Nautilus
  (`chelis#2370`, `chelis#2520`, `chelis#2152`, `chelis#3156`) is listed under
  Actively blocking.

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
