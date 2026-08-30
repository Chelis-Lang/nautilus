## Why

Upstream Buoy (`Chelis-Lang/buoy@92e60f5`) completed the Chelis verifier: item and runner digests are enforced at static time, staleness diagnostics carry bound and current values, `trace` audits one ID's full chain in one command, and `rebind` regenerates mechanical bindings behind a reviewed dry-run diff. Nautilus still pins the prior revision, and the value showed immediately: an intervening Chelis 0.18.6 bump left the gate oracle's runner digest silently stale because nothing enforced it. This change adopts the completed verifier and retires the last manual digest surgery.

## What Changes

- Re-pin `provenance/buoy-pin.toml` to `92e60f5b419eea5601989cd96b45dff181fe7ce2` with a newly reviewed clean-tree source content hash; record Chelis `0.18.6`.
- Declare `runner-config-paths = .github/workflows/ci.yml` on the gate oracle (with a `.github` artifact selector) so the runner digest verifies against saved workflow bytes on every static check; rebind the stale runner and oracle digests through the new `rebind --write` workflow.
- Block the gate lane on a nonempty `rebind` dry-run plan and on a failed `trace` smoke over `NAUT-MOD-LINALG`.
- Add the `reject-runner` fixture asserting `CHELIS-PROV-ORACLE-RUNNER-STALE` (10 cases).
- Re-execute the corpus under Chelis 0.18.6 and commit the receipt bound to the new static identity.
- Update `provenance/TRUST.md`: enforced runner bindings, the rebind workflow as the only regeneration path, and the remaining upstream note (root-level artifact reachability for the `reef.toml` binding).
- **Non-goals:** blocking policy promotion, new records or surfaces, and Buoy-side edits.

## Impact

- `provenance/` (pin, adapter config, fixtures, TRUST.md, receipts), `tests/linalg.ch` and the carrier records rebound by `rebind --write`, `scripts/provenance_gate.py`, `scripts/check_provenance_fixtures.py`.
- Final oracle stays `devenv test` with the advisory lane green and both corpora green under Chelis 0.18.6.
