## Context

The completed upstream verifier enforces item and runner digests, enriches staleness contexts with bound and current values, and ships `trace` plus `rebind`. Nautilus proved the gap live: the upstream Chelis 0.18.6 bump changed `reef.toml` and `ci.yml` after the oracle digests were recorded, and nothing noticed. The pin file also still names the prior Buoy revision.

## Goals / Non-Goals

**Goals:** adopt enforcement where artifacts are reachable, make `rebind` the only regeneration path, and prove bindings current on every gate run.

**Non-Goals:** blocking policy promotion, new governed records, Buoy edits.

## Decisions

### Bind the workflow, record the reef gap

`runner-config-paths` can only reference artifacts inside selector roots. A `.github` selector (artifacts only; no Surf sources live there) makes `ci.yml` reachable, and the workflow is the honest runner definition: it installs and invokes the pinned `chelis test`. `reef.toml` sits at the repository root, unreachable by any non-overlapping selector, so `runner-configuration-digest` binds its bytes manually with the gap recorded in the trust document as an upstream follow-up. The reef-to-toolchain agreement stays enforced by the devenv status shim and the upstream pin-consistency-guard.

### The gate proves bindings current, not just accepted

The static check already fails on stale enforced bindings; the lane additionally runs the `rebind` dry run and blocks on a nonempty plan. This closes the class of stale-but-unenforced fields (today: the manually bound reef digest, atom revisions in as-yet-unenforced positions) and prints the exact field diff plus the sanctioned instruction. The `trace` smoke over `NAUT-MOD-LINALG` recomputes one full chain each run as a canary.

### Rebind is the workflow, demonstrated in this change

The stale runner digest left by the 0.18.6 bump was repaired exactly through the new path: dry run (4-entry plan: the runner digest plus three carrier oracle-digest references), review, `--write`, idempotence check, corpus re-execution. The trust document records this as the only regeneration procedure.

## Risks / Trade-offs

- **Partial reef binding** → visible in the trust document, enforced transitively by two independent guards, and closed upstream when selectors reach root artifacts.
- **Trace smoke costs one extra static pass per gate run** → seconds; acceptable for a per-run full-chain canary.

## Migration Plan

Single change: pin bump, selector, oracle field, rebind, gate steps, fixture, receipts, trust document. Rollback is one revert; the prior pin and workflow return intact.

## Open Questions

None.
