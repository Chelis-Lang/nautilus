## Context

Nautilus pins Buoy with the `xxh3-128` change-detection member. Its three implementation links remain inline records beside Chelis declarations.

Compact object addresses require a collision-resistant digest member. The migration therefore moves the complete provenance graph to BLAKE3-256 before link conversion.

## Goals / Non-Goals

**Goals:**

- Pin the merged compact-binding implementation.
- Move every provenance digest to BLAKE3-256.
- Convert exactly three inline links through sanctioned commands.
- Preserve every attached declaration byte.
- Re-execute receipts after static identity changes.

**Non-Goals:**

- No advisory-to-blocking promotion.
- No new authority, surface row, carrier, or oracle.
- No manual object construction or digest computation.
- No reverse conversion command.

## Decisions

### Migrate the digest member before conversion

The consumer package and pin record select `blake3-256`. `rebind --write` regenerates current inline records under that member before `bind` runs.

This order prevents compact objects from mixing BLAKE3 addresses with XXH3 graph identities. All prior receipts become stale and require execution again.

### Put the store under the provenance selector

The configuration adds a `provenance/bindings` selector and sets `binding-store = "provenance/bindings"`. Objects then reside under `provenance/bindings/buoy/objects/v1/blake3-256/`.

This location keeps object bytes repository-owned and selector-reachable. It also avoids source-module directories and preserves the frozen upstream layout.

### Convert one reviewed relation at a time

The migration dry-runs and writes these relations in order:

- `NAUT-LINK-LINALG-MATMUL`
- `NAUT-LINK-SIGNAL-STUBS`
- `NAUT-LINK-STATS-HELPERS`

Each dry run must name one object write and one source replacement. A byte comparison must prove that each declaration remains unchanged.

Git supplies rollback because conversion is one-way. No command reconstructs an inline record from an object.

### Keep freshness checks in the gate

The existing static, `trace`, and empty `rebind` checks remain authoritative.
The fixture pack adds compact-address tamper, stale-subject, and digest-feature drift coverage.

The gate must reject missing, altered, or stale objects.
The corpus writer saves the exact static report beside each receipt. The gate rejects a receipt if its saved report becomes stale.
A successful compact resolution remains a navigation fact, not a correctness claim.

## Risks / Trade-offs

- **Graph-wide digest churn** → Use `rebind`, regenerate fixtures, and execute receipts again.
- **Object loss** → Commit immutable objects and reject absent addresses during static checks.
- **Accidental declaration edits** → Compare declaration bytes before and after each write.
- **Store path drift** → Enforce the configured selector boundary and exact object path.

## Migration Plan

1. Pin Buoy and select BLAKE3-256.
2. Add the store configuration and selector.
3. Rebind all current records under BLAKE3-256.
4. Convert each inline relation after dry-run review.
5. Verify static output, trace expansion, and an empty rebind plan.
6. Regenerate fixtures and execute receipts.
7. Run the full Nautilus acceptance oracle.

A Git revert restores the old pin, inline records, XXH3 identities, receipts, and configuration.

## Open Questions

None.
