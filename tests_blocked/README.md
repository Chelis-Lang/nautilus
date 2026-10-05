# Upstream-blocker probes

This directory holds **blocked probes**: minimal reproducers of live upstream
Chelis limitations, written as tests that are expected to fail. Each probe is a
`.ch` file paired with a `.expect` sidecar whose first line is the diagnostic
the probe must fail with; the remaining lines cite the upstream issue and say
what to change in Nautilus once the probe passes (the **de-narrowing** steps,
which remove the workaround). The blocker inventory itself lives in
[`docs/UPSTREAM_BUGS.md`](../docs/UPSTREAM_BUGS.md).

Run:

```text
chelis test tests_blocked/ --expect blocked
```

Verdicts are fail-closed:

- **OK**: the probe still fails with the pinned diagnostic, so the limitation
  is still present.
- **FIX-DETECTED**: the probe now passes. Execute the sidecar's de-narrowing
  steps, promote the probe to `tests/`, and archive its `UPSTREAM_BUGS` entry
  in the same pin-bump change.
- **DRIFTED**: the probe fails with a different diagnostic. Investigate
  before citing the issue again.

## Current executable probes

None at the `chelis 0.18.12` pin. `chelis test tests_blocked/ --expect blocked`
exits nonzero on this empty directory by design; the manual probes below own
the current verdicts.

## §cannot-be-probed

- **`chelis#3156`** (the release blocker; the expressiveness itself is
  `chelis#2443`, fixed upstream): an explicit dtype-set bound,
  `[prec: {f32, f64}]`, does not parse at this pin, so `Nautilus.Special`'s 67
  generic binders can only say `Float` and therefore admit `f16` and `bf16`
  (nautilus#75). A probe for this blocker **cannot live here**, for a
  different reason than the build-lane entries below: the blocker is at the
  **syntax** level, so the probe file does not parse, and
  `chelis lint --check .` lints every `.ch` in the tree with no per-path
  exclusion. A probe placed here fails `surf-parses` (§12.5) as a blocking
  lint error, which breaks the local gate for every unrelated change. Measured
  at this pin: the probe reports OK and `chelis test tests_blocked/ --expect
  blocked` exits 0, while `chelis lint --check .` gains two blocking errors.
  The manual recipe and the de-narrowing steps are in
  [`docs/UPSTREAM_BUGS.md`](../docs/UPSTREAM_BUGS.md).

- **`chelis#2599`**: a bare `None` whose type is fixed only by its sibling arm
  fails `chelis build` with an unresolved host inference variable
  ([05-UNS-1]). The failure is in the **build** lane, and `chelis test` never
  invokes `chelis build`, so a probe placed here would evaluate cleanly and be
  reported FIX-DETECTED while the limitation was still present -- the opposite
  of fail-closed. Fixed upstream by chelis#2888, which landed after v0.18.12
  was cut, so it is live at this pin only.
  `scripts/check_rolling_c_lane.py` is the executable guard, and
  [`docs/UPSTREAM_BUGS.md`](../docs/UPSTREAM_BUGS.md) carries the reproducer
  and the de-narrowing steps for the next pin bump.
- **`chelis#909`**: a function-typed parameter has no C host ABI, so a
  consumer's `chelis build` rejects the call site ([04-TOT-2]). Build-lane
  again, so not expressible here for the same reason. `Nautilus.Rolling`
  selects its reduction with a closed tag instead, which is the permanent
  design rather than a narrowing awaiting a fix, so there is nothing to
  de-narrow. `chelis#867` records that no issue owns that ABI.

- **`chelis#2370`**: exact-AD Levenberg-Marquardt composition loses
  runtime-extent binder provenance (under the tracking issue `chelis#1277`).
  The old provenance failure appeared only when the shipped
  finite-difference Jacobian in `src/curvefit.ch` was replaced by exact AD
  and the six multi-parameter recovery tests in `tests/curvefit.ch` ran.
  The isolated Jacobian-row witnesses pass, so they test a smaller
  boundary. At 0.18.12, a seeded-output exact-AD replacement still failed
  all six recoveries, but at host `to_list` lowering before the old
  provenance boundary; it does not prove the old diagnostic persists.
  The narrowing site in `src/curvefit.ch` points here instead of spelling
  the issue number, because the conformance audit treats any issue citation
  in `src/` as requiring an executable probe and does not consult this
  list. **Re-probe trigger:** every pin bump and the release resolving
  chelis#2370.

- **`chelis#2520`**: `match` does not release a branch arm's owner when only a
  sibling arm consumed it. The failure occurs during C host lowering, which
  `chelis test` never enters, and `src/` contains no `match`, ADT or `Option`
  to reproduce it. At this pin the `if` half (`chelis#2477`) emits C, while
  both `Option` and ADT `match` forms still fail with inconsistent live
  owners. Reproducers are in the upstream issue.
  **Re-probe trigger:** every pin bump, and before merging any change that
  introduces a `match` over an owned value consumed on one arm, whatever its
  dtype.

- **`chelis#2152`**: the previously rejecting minimal downstream cast
  consumer now builds at both f32 and f64, but a complete Float-generic
  Nautilus consumer matrix is still needed. `chelis test` does not exercise
  that C lane. Use the manual recipe below.

## Manual probe: `chelis#2152`

The reproducer needs two packages: a library installed into a temporary
`CHELIS_REEF_HOME`, and a consumer package that runs `chelis build`. The exact
steps and variant table are in chelis#2152.

- **0.18.12 result:** the function-parameter-plus-cast consumer builds,
  links, and runs at f32 and f64. A generic `Nautilus.Stats.mean_vec`
  consumer also does so. The broader Stats and Roots consumer matrix has
  no complete verdict at this pin.
- **On full pass:** only when every affected generic Nautilus consumer in
  the chelis#2152 entry of `docs/UPSTREAM_BUGS.md` builds, compiles, links,
  and runs at f32 and f64 may a module de-narrow under its own gates.
  The minimal reproducer passing does not establish that full result.
- **Re-probe trigger:** every pin bump, and before any `[prec: Float]`
  conversion under nautilus#70 merges.
