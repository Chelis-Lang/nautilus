# Nautilus provenance trust boundaries

This document records the trust boundaries of the advisory Buoy provenance
adoption. The frozen machine records are `provenance/buoy-pin.toml`, the
adapter configuration, the fixture pack, and the `chelis:provenance/v1`
records in the saved sources.

## Pinned tooling

- Buoy resolves only through the pinned consumer package at revision
  `a88fd2efce0f2aef20538abdc7f265696600e408`. The pin check rejects floating references and vendored copies.
- The upstream consumer package supplies the `chelis-provenance` command.
  It builds the `buoy` and `chelis-provenance` binaries with exact digest features for each package.
- Nautilus selects BLAKE3-256 for all new graph identities and compact addresses.
  The pin check rejects another member or a different Nix default.
  The pin record contains the reviewed clean-tree source hash. Realization fails closed if the source differs.
- The upstream constant covers a development worktree. Nautilus therefore owns the reviewed clean-tree value.

## Parser boundary

- The pinned adapter parses saved Surf sources with the vendored
  tree-sitter grammar from Chelis `v0.18.5`. A source outside the canonical
  surface fails the static check with `CHELIS-PROV-PARSE-ERROR`; the
  `reject-parse` fixture keeps that behavior visible.
- Item identities were reingested under `chelis-surf-syntax/v2`: every bound
  item digest derives from the parsed declaration node's exact bytes, so a
  body edit on a bound declaration now invalidates its bindings.
- Known upstream Chelis grammar-parity gaps: the compiler accepts untyped
  lambda parameters (`fn (p) -> ...`) and bare tuple expressions as lambda
  block tails, but the grammar rejects both. The saved sources were
  normalized to the grammar-accepted forms (`cast(x, t)` instead of the
  cast-pipe lambda; named tuple binding before the block tail) with
  unchanged semantics; the compiler corpus verifies the rewrite.

## Compact implementation bindings

Three source markers reference compact objects in `provenance/bindings`.
Each marker contains only a BLAKE3-256 object address and stays attached to its parsed declaration.

The adapter configuration declares `provenance/bindings` as the binding store and as an artifact selector root.
Objects use `<binding-store>/buoy/objects/v1/<algorithm>/<hex>.toml`.
The static check verifies the address, object content, subject, requirement, and atom revision.

The `bind` command converts one reviewed inline relation and does not change declaration bytes.
The `rebind` command writes a successor object, updates its source address, and removes the old object.
Compact resolution fails closed under the legacy XXH3-128 configuration.

## Enforced runner bindings

- The gate oracle declares `runner-config-paths = .github/workflows/ci.yml`,
  so its `runner-digest` verifies against the saved workflow bytes on every
  static check (`CHELIS-PROV-ORACLE-RUNNER-STALE` on drift). The workflow is
  the runner definition: it installs and invokes the pinned `chelis test`.
- `runner-configuration-digest` binds the `reef.toml` compiler-pin bytes but
  stays manually recomputed: `reef.toml` sits at the repository root, outside
  every Buoy selector root. Upstream follow-up: reach root-level artifacts
  from oracle bindings. Until then the reef-to-toolchain agreement stays
  enforced by the devenv status shim and the upstream pin-consistency-guard.
- The gate lane blocks on a nonempty `rebind` dry-run plan.
  It also blocks if an expanded trace fails for any of the three compact relations.

## What the records claim

- Nineteen authority atoms state the module support claims. The governed
  surface dispositions every module exactly once; `Nautilus.Signal` stays a
  visible `deferred` row under the Phase 5f authority.
- Compact implementation bindings and carriers attach to real declarations in saved `.ch` sources with exact byte spans.
  Registration is never execution evidence.
- Carrier verdicts come only from `chelis-provenance execute` receipts over
  the declared gate oracle (`chelis test tests/ --timeout 600 --jobs auto`
  through `scripts/provenance_oracle.sh`, which applies the declared
  exit-status normalization). Without receipts a carrier reports `not-run`.
  Raw test output stays noncanonical and is not retained in canonical bytes.
- Execution cannot mutate static identity. The corpus runner fails if static report bytes change during execution.
- The corpus runner saves the exact static report beside the execution receipt.
  The gate rejects a receipt if that report differs from the current static report.

## What stays advisory and deferred

- Enforcement is advisory only. The gate lane blocks on extraction failures,
  malformed records, pin drift, fixture drift, and golden drift; coverage
  gaps (uncovered atoms, `not-run` carriers) print without blocking.
- The `README.md` module table stays hand-maintained and appears in every
  advisory summary as a visible untracked copy until a later change derives
  or retires it.
- Only the first tranche (`signal`, `linalg`, `stats`) carries compact implementation bindings.
  The remaining modules carry authority atoms and surface rows only.
- No formal proof claim exists anywhere in this adoption.

## Digest regeneration procedure

1. Run `nautilus-provenance rebind` after a reviewed edit changes a bound value.
2. Review each field, object, and source-address change in the dry-run plan.
3. Run `nautilus-provenance rebind --write`.
4. Verify that the command did not change declaration bytes.
5. Run the corpus again to bind receipts to the new static identity.
6. Commit the reviewed changes.

## Regeneration behavior

The command changes record comments and compact objects. It never changes declarations.
It rejects a source if the grammar cannot parse that source.
Each stale diagnostic contains `bound=...;current=...`. The static check fails closed on all detected drift.

## Compact conversion rollback procedure

1. Use Git to revert a reviewed `bind` conversion.
2. Verify that Git restores the inline record and removes the compact object.
3. Run the static check and the corpus again.

## Adoption rollback

A full rollback removes the records, `provenance/`, `nix/buoy-consumer.nix`, the gate lane task, and the two devenv scripts.
The source normalization to grammar-accepted forms is semantics-neutral and needs no rollback.
No other runtime code changes exist in this adoption.
