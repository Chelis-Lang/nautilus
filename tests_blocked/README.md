# Upstream-blocker probes

Every `.ch` file here is an isolated reproducer of a current upstream Chelis
limitation and is expected to fail with the diagnostic pinned on line 1 of its
paired `.expect` sidecar.

Run:

```text
chelis test tests_blocked/ --expect blocked
```

Verdicts are fail-closed:

- **OK**: still fails with the pinned diagnostic;
- **FIX-DETECTED**: now passes; execute the sidecar's de-narrowing steps and
  promote the probe in the same pin-bump change;
- **DRIFTED**: still fails differently; investigate before re-citing.

## Current executable probes

None. The four 0.18.10 probes became positive regression tests at the 0.18.11
pin. The wider Levenberg-Marquardt AD replacement remains narrowed by a distinct
runtime-extent failure tracked under `chelis#1277`; its exact Jacobian-row
witness is now positive coverage rather than a failing probe.

## §cannot-be-probed

- **`shoals#61`** — cited in `src/special.ch`'s `erf` error-bound note. It is
  the sibling shoals repo's instance of the same duplicated-approximation
  class, not a Chelis limitation and not reachable from Nautilus sources, so
  there is nothing here to reproduce. The citation exists so that an author
  widening `erf` to f64 sees the constants are copied elsewhere too. Re-probe
  trigger: none; drop the citation when shoals#61 closes.

- **`chelis#2152`** — the failure occurs only during C host lowering of an
  imported generic definition across two packages. `chelis test --expect
  blocked` does not enter that lane; use the manual recipe below.

- **`chelis#2370`** — the failure is exposed by replacing the shipped
  finite-difference Levenberg-Marquardt Jacobian with its exact-AD
  implementation and then running the six complete multi-parameter recovery
  paths. The fixed Jacobian-row witnesses pass in isolation, and a smaller
  recursive composition also passes, so pinning either as a blocked probe
  would test the wrong boundary. The issue body preserves the exact mutation
  and diagnostic until a bounded standalone witness exists. The narrowing site
  therefore links this inventory rather than spelling an issue token: the
  0.18.11 conformance auditor treats every source token as proof that an
  executable blocked probe must exist and does not consult this
  `§cannot-be-probed` disposition.

## Manual-only current probes

- **A downstream `chelis build` rejects a cast to a `Float`-bounded binder** —
  `chelis#2152`. This cannot be a
  `tests_blocked` probe because `chelis test` never runs C host lowering. The
  reproducer needs two packages: a library installed into a temporary
  `CHELIS_REEF_HOME`, and a consumer running `chelis build`. The exact steps and
  expected rejection are in chelis#2152. **Expected while blocked:** the
  consumer's `chelis build` exits nonzero with ``unsupported: dtype `prec` on a
  `cast` target in host lowering``. **Control:** the same consumer against
  nautilus `main`'s f32 `Nautilus.Stats` builds and links. **On pass:** only when
  every shape in the pass condition of the chelis#2152 entry in
  `docs/UPSTREAM_BUGS.md` builds, compiles and links at f32 and at f64,
  including the #69 Stats consumer. chelis#2152's headline reproducer passing
  on its own is not enough. Then nautilus#69's Float-generic Stats branch
  becomes mergeable, subject to its own gates. Re-probe trigger: every
  pin bump, and before any `[prec: Float]` conversion under nautilus#70 merges.

The former unused-Reef-import `eval --file` residue (`chelis#848`) is
archived after its 0.17.5 release-asset re-probe passed all 15 import shapes.
The benchmark remains positive regression coverage, not a current blocker.
