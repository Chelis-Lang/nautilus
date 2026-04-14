# Nautilus Agent Contract

Canonical agent instructions for this repository. `CLAUDE.md` is a symlink
to this file so Claude-style and Codex-style entry points do not drift.

## Repo Identity

- Nautilus is a downstream **shell repo** for the Chelis language, owned by
  Chelis phase 3j. Scope: numerical methods, statistics, and optimization.
- Upstream of truth: <https://github.com/Chelis-Lang/chelis>. The Chelis
  monorepo's `AGENTS.md` rules apply here **verbatim** unless explicitly
  overridden below.
- The monorepo contract covers: spec-first development, negative-test
  parity, red-team protocol, documentation hierarchy, example-corpus
  policy, scripting-language policy (Python, never shell), Surf style
  guide, and the shared local skill set.

## Toolchain Pin

- `chelis v0.1.2` is the single supported compiler binary. `reef.toml`
  currently pins `compiler = "=0.1.0"` because the released v0.1.2 binary
  still enforces the old string (hard-coded `CURRENT_COMPILER_VERSION` in
  `chelis-reef`). This is a monorepo bug to fix upstream; once fixed,
  Nautilus, Coral, and Shoals must all bump the pin together in a single
  change set. Do not bump unilaterally.
- Do not vendor or build the Chelis compiler from source inside this repo.
  Always consume the released tarball from `Chelis-Lang/chelis`.

## Phase Status

- **Current state:** scaffolding-only. No `Nautilus.*` modules are
  implemented yet. The owning acceptance oracle is
  `phase3j_nautilus_oracle` in the Chelis monorepo and is **not** live.
- Library development against this repo is gated on Chelis phase 3j
  officially starting. Until then, changes to this repo should be limited
  to scaffolding refinements that also land in Coral and Shoals for
  consistency.

## Shared Local Skills

Project-local skills live in `agent-skills/`. `.claude/skills` and
`.codex/skills` are symlinks to that directory so both tool surfaces load
the same skill library. `.claude/commands/` and `.codex/commands/` mirror
each other. The shared skill set (`redteam-exec`, `spec-sync`,
`phase-gate`, `backend-numerics`, `example-corpus`, `cli-surface`) and
the `red-team` alias wired to `redteam-exec` are copied from the
monorepo and should stay behaviorally aligned with it. If a skill
diverges upstream, update this repo in the same change set.

## Scaffolding Drift Rule

Nautilus, Coral, and Shoals share the same scaffolding shape by design.
Any structural change to this repo (layout, CI workflow, agent surface,
reef manifest format) should be mirrored into Coral and Shoals in the
same change set, or explicitly flagged as a Nautilus-only divergence
with a recorded reason.
