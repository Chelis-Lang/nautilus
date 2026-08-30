# Nautilus provenance trust boundaries

This document records the trust boundaries of the advisory Buoy provenance
adoption. The frozen machine records are `provenance/buoy-pin.toml`, the
adapter configuration, the fixture pack, and the `chelis:provenance/v1`
records in the saved sources.

## Pinned tooling

- Buoy resolves only through the pinned consumer-package path at revision
  `92e60f5b419eea5601989cd96b45dff181fe7ce2`. The pin check rejects floating
  references and vendored copies.
- The `chelis-provenance` command comes from the upstream consumer package,
  which builds the `buoy` and `chelis-provenance` binaries with exact
  per-package digest features. The pin record owns the Nautilus-reviewed
  clean-tree source content hash; realization fails closed on any
  difference. Remaining upstream note: the upstream committed constant still
  covers a development worktree, so this repository keeps its own reviewed
  clean-tree value.

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
- The gate lane blocks on a nonempty `rebind` dry-run plan and on a failed
  `trace` smoke over `NAUT-MOD-LINALG`, in addition to the pin, fixture, and
  static checks.

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

Run `nautilus-provenance rebind` after any reviewed edit that moves a bound
value. The dry run prints the exact field-level plan with bound and current
values; review it, apply with `--write`, re-execute the corpus so the
receipts bind the new static identity, and commit. The command rewrites
only record comment fields, never declarations, and refuses when the
grammar rejects a source. Every staleness diagnostic also carries
`bound=...;current=...`, so no out-of-band recomputation build exists
anywhere in this workflow. The static check fails closed on any drift
either way.

## Rollback

Rollback removes the records, `provenance/`, `nix/buoy-consumer.nix`, the
gate lane task, and the two devenv scripts. The source normalization to
grammar-accepted forms is semantics-neutral and needs no rollback. No other
runtime code changes anywhere in this adoption.
