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

None at the `chelis 0.19.1` pin. `chelis test tests_blocked/ --expect blocked`
exits nonzero on this empty directory by design; the manual probes below own
the current verdicts.

## §cannot-be-probed

- **`chelis#909`**: a function-typed parameter has no C host ABI, so a
  consumer's `chelis build` rejects the call site ([04-TOT-2]). The test
  harness does not enter C host lowering. `Nautilus.Rolling`
  selects its reduction with a closed tag instead, which is the permanent
  design rather than a narrowing awaiting a fix, so there is nothing to
  de-narrow. `chelis#867` records that no issue owns that ABI.

- **`chelis#2370`**: exact-AD Levenberg-Marquardt composition loses
  runtime-extent binder provenance (under the tracking issue `chelis#1277`).
  Replacing the finite-difference Jacobian in `src/curvefit.ch` with exact AD
  must pass the six multi-parameter recovery tests in `tests/curvefit.ch`.
  The isolated Jacobian-row witnesses pass, so they test a smaller
  boundary. With Chelis 0.19.1, a seeded-output exact-AD replacement fails
  all six recoveries at host `to_list` lowering, before the provenance
  boundary. The provenance condition remains unverified.
  The narrowing site in `src/curvefit.ch` points here instead of spelling
  the issue number, because the conformance audit treats any issue citation
  in `src/` as requiring an executable probe and does not consult this
  list. **Re-probe trigger:** every pin bump and the release resolving
  chelis#2370.

- **`chelis#2471`**: the `chelis eval` lane performs no tail-call elimination,
  and its frame budget shrinks as the recursive body grows. This one cannot be
  probed for a reason the other entries do not share: the failure is a process
  abort (`fatal runtime error: stack overflow`, exit 134), so it kills the
  harness that would record the verdict. `chelis test` cannot see it either,
  because its worker thread holds about 500 frames and the same input returns a
  value there. The incomplete-beta continued fraction in `src/distributions.ch`
  spends its budget through three levels of chunking so peak depth is about 48
  frames; that narrowing site points here rather than spelling the issue
  number, for the same reason the `chelis#2370` entry above does. Manual
  probe: flatten `betacf_chunk`/`betacf_block`/`betacf_drive` into a single
  recursion and run `beta_cdf(cast(0.5, f32), cast(100000.0, f32),
  cast(100000.0, f32))` under `chelis eval --file`; it needs 162 iterations and
  must abort with exit 134 while the chunked form returns 0.49999997.
  **Re-probe trigger:** every pin bump and the release resolving chelis#2471.
  On pass, collapse the chunking and compare values bit-for-bit.

- **`chelis#2520`**: `match` does not release a branch arm's owner when only a
  sibling arm consumed it. The failure occurs during C host lowering, which
  `chelis test` never enters. The shipped `Reducer` match and `Option` paths
  build, but they do not bind the block-owned value that reproduces this
  defect. At this pin the `if` half (`chelis#2477`) emits C, while
  both `Option` and ADT `match` forms still fail with inconsistent live
  owners. Reproducers are in the upstream issue.
  **Re-probe trigger:** every pin bump, and before merging any change that
  introduces a `match` over an owned value consumed on one arm, whatever its
  dtype.

- **`chelis#2152`**: the minimal downstream cast
  consumer builds at both f32 and f64, but a complete Float-generic
  Nautilus consumer matrix is still needed. `chelis test` does not exercise
  that C lane. Use the manual recipe below.

- **`chelis#2471`** (narrowing `nautilus#140`): **cannot be probed here.** The limitation is that
  `chelis eval --file` aborts the process at about 135 frames of a let-heavy
  recursion. `chelis test` runs each file on a `chelis-test-worker` thread that
  holds about 500 frames of the same shape, so the 200-frame recursion this
  entry is about completes in the test lane and returns a value. A blocked
  probe here would pass and prove nothing. The observing gate is the CI step
  that runs `chelis eval --file` over `src/example*.ch`, where
  `example_gamma_cdf_degenerate_arguments` prints `11111.0` with the chunked
  recursions and exits 134 without them.
  **Re-probe trigger:** every pin bump, and any release touching eval-lane
  stack sizing or tail calls.

## Manual probe: `chelis#2152`

The reproducer needs two packages: a library installed into a temporary
`CHELIS_REEF_HOME`, and a consumer package that runs `chelis build`. The exact
steps and variant table are in chelis#2152.

- **Pinned result:** the function-parameter-plus-cast consumer builds,
  links, and runs at f32 and f64, printing 1.5 at both. The broader Stats,
  Roots, and LinAlg consumer matrix has no complete verdict.
- **On full pass:** only when every affected generic Nautilus consumer in
  the chelis#2152 entry of `docs/UPSTREAM_BUGS.md` builds, compiles, links,
  and runs at f32 and f64 may a module de-narrow under its own gates.
  The minimal reproducer passing does not establish that full result.
- **Re-probe trigger:** every pin bump, and before any `[prec: Float]`
  conversion under nautilus#70 merges.
