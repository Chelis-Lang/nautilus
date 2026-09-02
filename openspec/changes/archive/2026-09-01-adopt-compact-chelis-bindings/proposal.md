## Why

Nautilus carries three verbose inline implementation links that duplicate stable relation data beside Chelis declarations.
Buoy now supports compact content-addressed Chelis bindings. It supplies deterministic conversion, freshness checks, trace expansion, and sanctioned regeneration.

## What Changes

- Pin Buoy to `a88fd2efce0f2aef20538abdc7f265696600e408` with a reviewed clean-tree source hash.
- Change the active Buoy digest feature from `xxh3-128` to `blake3-256` because compact addresses require collision resistance.
- Regenerate all provenance digests and re-execute receipts under the new digest member.
- Select a repository-owned binding store that lies inside one adapter selector root.
- Convert the inline links in `src/linalg.ch`, `src/signal.ch`, and `src/stats.ch` through reviewed `bind` plans.
- Require compact bindings to pass static checks, trace expansion, and an empty `rebind` dry run.
- Re-execute the provenance corpus after the static identity changes.
- Save the exact static report beside each execution receipt and reject stale receipt identity.
- Add positive, object-tamper, stale-subject, and pin-digest fixtures.
- Document object immutability, declaration preservation, and Git-based rollback.
- Keep advisory enforcement and the governed module surface unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `nautilus-provenance`: Require content-addressed implementation bindings for the three governed module links.

## Impact

The change affects the Buoy pin, digest feature, adapter configuration, records, three Chelis source files, binding store, fixtures, receipts, scripts, and documentation.
It does not vendor Buoy or promote advisory policy.
