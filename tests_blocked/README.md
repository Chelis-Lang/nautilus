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

| Probe | Current blocker | Re-probe trigger |
|---|---|---|
| `curvefit/lm_jacobian_generic_dims.ch` | Generic vector-model wrapper reaches malformed backward-DAG verification after chelis#847's checker fix; `chelis#676` | Every pin bump and the release resolving chelis#676 |
| `curvefit/lm_jacobian_model_wrapper.ch` | Concrete arbitrary-model wrapper emits a malformed backward DAG; `chelis#676` (function-valued-capture witness, same verifier class) | Every pin bump and the release resolving the issue |
| `masked_select/untaken_arm_overflow.ch` | An untaken scalar-`if` arm is evaluated under `vmap`, so an overflowing arm poisons the select; `chelis#1464` (untaken-arithmetic sibling of that issue's taken-`fail` reproducer) | Every pin bump and the release resolving chelis#1464 |
| `generic_dtype/scalar_cast_from_float_binder.ch` | `cast`/`cast_trunc` reject a scalar source typed by a `Float`-bounded binder while the tensor form is accepted; `chelis#2151` | Every pin bump and the release resolving chelis#2151 |

## Cannot be probed from this repo

- **`shoals#61`** — cited in `src/special.ch`'s `erf` error-bound note. It is
  the sibling shoals repo's instance of the same duplicated-approximation
  class, not a Chelis limitation and not reachable from Nautilus sources, so
  there is nothing here to reproduce. The citation exists so that an author
  widening `erf` to f64 sees the constants are copied elsewhere too. Re-probe
  trigger: none; drop the citation when shoals#61 closes.

## Manual-only current probes

- **A downstream `chelis build` rejects a cast to a `Float`-bounded binder** —
  `chelis#2152`. This cannot be a
  `tests_blocked` probe because `chelis test` never runs C host lowering. The
  reproducer needs two packages: a library installed into a temporary
  `CHELIS_REEF_HOME`, and a consumer running `chelis build`. The exact steps and
  expected rejection are in chelis#2152. **Expected while blocked:** the
  consumer's `chelis build` exits nonzero with ``unsupported: dtype `prec` on a
  `cast` target in host lowering``. **Control:** the same consumer against
  nautilus `main`'s f32 `Nautilus.Stats` builds and links. **On pass** (build
  exit 0, clang exit 0, at f32 and at f64): nautilus#69's Float-generic Stats
  branch becomes mergeable subject to its own gates. Re-probe trigger: every
  pin bump, and before any `[prec: Float]` conversion under nautilus#70 merges.

The former unused-Reef-import `eval --file` residue (`chelis#848`) is
archived after its 0.17.5 release-asset re-probe passed all 15 import shapes.
The benchmark remains positive regression coverage, not a current blocker.
