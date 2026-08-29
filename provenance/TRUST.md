# Nautilus provenance trust boundaries

This document records the trust boundaries of the advisory Buoy provenance
adoption. The frozen machine records are `provenance/buoy-pin.toml`, the
adapter configuration, the fixture pack, and the `chelis:provenance/v1`
records in the saved sources.

## Pinned tooling

- Buoy resolves only through the pinned consumer-package path at revision
  `f41fd5015a11ab4791f5e8363afb4e9a156a49fe`. The pin check rejects floating
  references and vendored copies.
- The `chelis-provenance` command comes from a pinned source build
  (`nix/chelis-provenance.nix`) with the same fail-closed reviewed-content
  verification, because the upstream consumer package at this revision builds
  only the root `buoy` package. Upstream follow-ups: expose the command in
  the consumer package, and derive the committed reviewed source-content
  constant from a clean tree instead of a development worktree.

## What the records claim

- Nineteen authority atoms state the module support claims. The governed
  surface dispositions every module exactly once; `Nautilus.Signal` stays a
  visible `deferred` row under the Phase 5f authority.
- Implementation links and carriers attach to real declarations in saved
  `.ch` sources with exact byte spans. Registration is never execution
  evidence.
- Carrier verdicts come only from `chelis-provenance execute` receipts over
  the declared gate oracle (`chelis test tests/ --timeout 600 --jobs auto`
  through `scripts/provenance_oracle.sh`, which applies the declared
  exit-status normalization). Without receipts a carrier reports `not-run`.
  Raw test output stays noncanonical and is not retained in canonical bytes.
- Execution cannot mutate static identity: the corpus runner fails if the
  static report bytes change across an execution.

## What stays advisory and deferred

- Enforcement is advisory only. The gate lane blocks on extraction failures,
  malformed records, pin drift, fixture drift, and golden drift; coverage
  gaps (uncovered atoms, `not-run` carriers) print without blocking.
- The `README.md` module table stays hand-maintained and appears in every
  advisory summary as a visible untracked copy until a later change derives
  or retires it.
- Only the first tranche (`signal`, `linalg`, `stats`) carries implementation
  links; the remaining modules carry authority atoms and surface rows only.
- No formal proof claim exists anywhere in this adoption.

## Digest regeneration

Atom revisions and record digests bind to the pinned Buoy algorithms. When a
statement or record changes, recompute its digests with the pinned Buoy
toolchain (a helper crate over `chelis-provenance` at the pinned revision)
and re-run the gate lane; the static check fails closed on any drift either
way. Upstream follow-up: expose atom revisions in the canonical static
report so regeneration needs no helper build.

## Rollback

Rollback removes the records, `provenance/`, `nix/buoy-consumer.nix`,
`nix/chelis-provenance.nix`, the gate lane task, and the two devenv scripts.
No runtime code changes anywhere in this adoption.
