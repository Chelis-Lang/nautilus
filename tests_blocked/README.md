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
| `curvefit/lm_jacobian_generic_dims.ch` | Generic vector-model grad wrapper collapses rigid `n` and `m`; `chelis#847` | Every pin bump and the release carrying its upstream resolution |
| `curvefit/lm_jacobian_model_wrapper.ch` | Concrete arbitrary-model wrapper emits a malformed backward DAG; `chelis#676` (function-valued-capture witness, same verifier class) | Every pin bump and the release resolving the issue |

## Manual-only current probe

The unused-Reef-import `eval --file` residue (`chelis#848`) is CLI-context
only and cannot be represented by the `chelis test` expected-failure harness.
Re-run the exact temporary-file command in `docs/UPSTREAM_BUGS.md` at every pin
bump. Real imported calls used by parity are positive and must remain green.
