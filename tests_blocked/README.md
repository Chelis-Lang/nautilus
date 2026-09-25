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

None at the `chelis 0.18.11` pin. Every live blocker fails in a lane that
`chelis test` does not exercise, so each is listed below and re-probed by hand.

## §cannot-be-probed

- **`chelis#2370`**: exact-AD Levenberg-Marquardt composition loses
  runtime-extent binder provenance (under the tracking issue `chelis#1277`).
  The failure appears only when the shipped finite-difference Jacobian in
  `src/curvefit.ch` is replaced by its exact-AD form and the six
  multi-parameter recovery tests in `tests/curvefit.ch` run. The Jacobian-row
  witnesses and a smaller recursive composition pass on their own, so pinning
  either as a probe would test the wrong boundary; the upstream issue records
  the exact mutation and diagnostic. The narrowing site in `src/curvefit.ch`
  points here instead of spelling the issue number, because the 0.18.11
  conformance audit treats any issue citation in `src/` as requiring an
  executable probe and does not consult this list. **Re-probe trigger:** every
  pin bump and the release resolving chelis#2370.

- **`chelis#2520`**: `match` does not release a branch arm's owner when only a
  sibling arm consumed it. The failure occurs during C host lowering, which
  `chelis test` never enters, and `src/` contains no `match`, ADT or `Option`
  to reproduce it. At this pin the `if` half (`chelis#2477`, fixed upstream
  after 0.18.11) is also unfixed. Reproducers are in the upstream issue.
  **Re-probe trigger:** every pin bump, and before merging any change that
  introduces a `match` over an owned value consumed on one arm, whatever its
  dtype.

- **`chelis#2152`**: a downstream `chelis build` rejects a cast to a
  `Float`-bounded binder. The failure occurs during C host lowering of a
  consumer package, which `chelis test` does not enter. Use the manual recipe
  below.

## Manual probe: `chelis#2152`

The reproducer needs two packages: a library installed into a temporary
`CHELIS_REEF_HOME`, and a consumer package that runs `chelis build`. The exact
steps and variant table are in chelis#2152.

- **Expected while blocked:** the consumer's `chelis build` exits nonzero with
  ``unsupported: dtype `prec` on a `cast` target in host lowering``.
- **Control:** the same consumer built against the f32-only `Nautilus.Stats`
  on `main` builds and links.
- **On pass:** only when every shape in the pass condition of the chelis#2152
  entry in `docs/UPSTREAM_BUGS.md` builds, compiles and links at f32 and at
  f64, including the Stats consumer from nautilus#69. The upstream headline
  reproducer passing on its own is not enough. nautilus#69's Float-generic
  Stats then becomes mergeable, subject to its own gates.
- **Re-probe trigger:** every pin bump, and before any `[prec: Float]`
  conversion under nautilus#70 merges.
