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

## Manual-only current probes

None. The former unused-Reef-import `eval --file` residue (`chelis#848`) is
archived after its 0.17.5 release-asset re-probe passed all 15 import shapes.
The benchmark remains positive regression coverage, not a current blocker.
