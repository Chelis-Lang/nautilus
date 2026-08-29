## Context

Nautilus pins Buoy at `f41fd50` (lexical Surf anchoring) and builds the `chelis-provenance` command from a local fallback derivation because the old consumer package built only the root `buoy` package. Upstream `30b61f5` ships parser-backed identity over the vendored Chelis `v0.18.5` grammar, a revision-bearing `chelis-static-report/v2`, an `advisory` subcommand, and a consumer package that exposes both binaries. The upstream protocol declares no legacy reader: identities recorded under `chelis-surf-syntax/v1` require source reingestion.

## Goals / Non-Goals

**Goals:** one reviewed pin bump, reingested item digests from parsed node bytes, report-derived atom revisions, the upstream package as the only command source, and regenerated goldens plus receipts under report v2.

**Non-Goals:** new records, blocking policy, README-table derivation, Deep dialect concerns, Buoy-side edits.

## Decisions

### Reingestion recomputes digests; records stay in place
The record grammar and anchoring layout are unchanged, so no record moves. Only the bound values change: item digests become digests of the parsed declaration node bytes (multi-line bodies now participate), and atom revisions re-derive after the recompute. A one-shot uncommitted helper against the pinned crate performs the digest recompute; revisions come from the v2 report, which is the report's new purpose. The helper is not committed and the trust document stops referencing helper builds as a standing need.

### Upstream package for both binaries
`nix/buoy-consumer.nix` keeps the verified-source pattern with a newly reviewed clean-tree hash and now provides `chelis-provenance` from the same realized package. `nix/chelis-provenance.nix` is deleted, and the pin record's `provenance_command_source` names the upstream package.

### Fixture pack tracks the v2 contract
Goldens regenerate under `chelis-static-report/v2`. A new rejected-parse fixture asserts `CHELIS-PROV-PARSE-ERROR` on a non-canonical source. Gate scripts that read report object lists adjust to the `{id, digest, revision}` row shape.

## Risks / Trade-offs

- **Multi-line identity widens staleness**: a body edit now invalidates bindings on that declaration. Accepted; this matches upstream Rust-adapter semantics and is the point of the change.
- **Grammar strictness**: any non-canonical saved Surf fails the static check loudly. Nautilus is canonically formatted; the negative fixture keeps the behavior visible.
- **Hash review**: the reviewed source-content hash for the clean fetched tree is derived once from the fetch mismatch report and recorded in the pin file, as before.

## Migration Plan

1. Bump the pin, derive and review the clean-tree hash, switch the package source, delete the fallback.
2. Reingest digests and revisions; update records in place.
3. Regenerate fixtures, goldens, and receipts; adjust gate scripts; re-run the corpus.
4. Update `TRUST.md`; run `devenv test` to green.

Rollback is one revert of the pin commit; the prior pin and fallback derivation return intact.

## Open Questions

None.
