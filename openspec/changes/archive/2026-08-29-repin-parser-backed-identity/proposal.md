## Why

Upstream Buoy landed parser-backed Chelis Surf identity (`Chelis-Lang/buoy@30b61f5`). Records now anchor to parsed declaration nodes from the vendored Chelis `v0.18.5` grammar, item identity derives from node bytes under `chelis-surf-syntax/v2`, the static report exposes atom revisions and object digests, and the consumer package exposes the `chelis-provenance` binary. Nautilus still pins the lexical revision (`f41fd50`), builds the command through a local fallback derivation, and binds item digests computed from single declaration lines. The upstream protocol requires source reingestion for the new identities; two of the three follow-ups recorded in `provenance/TRUST.md` are now closed upstream and must be retired here.

## What Changes

- Re-pin `provenance/buoy-pin.toml` to `30b61f5e397bbf957b30ffd6eee47ee781d81bbe` with a newly reviewed clean-tree source content hash and an updated version-skew note covering the `chelis-surf-syntax/v2` reingestion.
- Consume the `chelis-provenance` binary from the upstream consumer package and delete the local fallback derivation `nix/chelis-provenance.nix`.
- Reingest the record corpus under parser-canonical identity: recompute every bound item digest from the parsed declaration node bytes and every atom revision from the revision-bearing v2 static report.
- Regenerate fixture goldens and receipts for the `chelis-static-report/v2` schema; extend the fixture pack with a parse-error rejection case.
- Update `provenance/TRUST.md`: record the parser boundary and reingestion, retire the closed follow-ups (consumer-package exposure, helper-crate bootstrap), and keep the remaining upstream note only if still open.
- **Non-goals:** new governed surfaces or carriers, blocking policy, README module-table derivation, and any Buoy-side edit.

## Impact

- `provenance/` (pin record, adapter config if identities are named there, fixtures, goldens, receipts, TRUST.md), `nix/buoy-consumer.nix`, deleted `nix/chelis-provenance.nix`, gate scripts that parse the static report, and the `chelis:provenance/v1` records in `src/`, `tests/`, and `tests_neg/`.
- The final oracle stays `devenv test` with the advisory provenance lane green and the corpus re-executed against the new static identity.
