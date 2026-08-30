## 1. Pin and enforcement

- [x] 1.1 Re-pin `provenance/buoy-pin.toml` to `92e60f5b419eea5601989cd96b45dff181fe7ce2` with the newly reviewed clean-tree hash and Chelis `0.18.6`; install the matching toolchain.
- [x] 1.2 Add the `.github` artifact selector and declare `runner-config-paths = .github/workflows/ci.yml` on the gate oracle; verify the static check reports `CHELIS-PROV-ORACLE-RUNNER-STALE` for the stale digests before rebinding.
- [x] 1.3 Rebind through the sanctioned workflow: review the dry-run plan, apply `rebind --write`, confirm idempotence, and verify the static check and the `trace` smoke both accept.

## 2. Gate lane and fixtures

- [x] 2.1 Block the gate lane on a nonempty `rebind` dry-run plan (printing each stale field with bound and current values) and on a failed `trace` smoke over `NAUT-MOD-LINALG`.
- [x] 2.2 Add the `reject-runner` fixture asserting `CHELIS-PROV-ORACLE-RUNNER-STALE`; the pack reports 10 cases with both goldens frozen.
- [x] 2.3 Re-execute the corpus under Chelis 0.18.6 and commit the receipt bound to the new static identity.

## 3. Documentation and final oracle

- [x] 3.1 Update `provenance/TRUST.md`: enforced runner bindings, the rebind workflow as the only regeneration path, and the recorded reef reachability follow-up.
- [x] 3.2 Full `devenv test` exits 0 with the advisory lane green; negative corpus stays green.
