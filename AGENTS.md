# Nautilus Agent Contract

Canonical agent instructions for this repository. `CLAUDE.md` is a symlink
to this file so Claude-style and Codex-style entry points do not drift.

## Repo Identity

- Nautilus is a downstream **shell repo** for the
  [Chelis](https://github.com/Chelis-Lang/chelis) language, scoped to
  numerical methods, statistics, and optimization.
- Upstream of truth: `Chelis-Lang/chelis`. The Chelis monorepo's
  `AGENTS.md` rules apply here **verbatim** unless explicitly overridden
  below. That contract covers spec-first development, negative-test
  parity, red-team protocol, documentation hierarchy, example-corpus
  policy, scripting-language policy (Python, never shell), and the
  shared local skill set.

## Toolchain Policy

- Nautilus should track the latest **published and validation-clean**
  Chelis release by default. Treat stale pins as drift, not as a reason
  to stay on an older compiler.
- `reef.toml` should pin the currently validated release exactly. As of
  this repo state, that is `chelis 0.11.1`.
- If the latest published Chelis release fails Nautilus validation,
  document the blocker clearly and pin the newest known-good release
  until the blocker is resolved.
- Do not vendor or build the Chelis compiler from source inside this
  repo. Consume the released tarball from the private
  `Chelis-Lang/chelis` releases. CI authenticates via the repo secret
  `CHELIS_RELEASE_TOKEN`, which must hold a PAT with `contents: read`
  on `Chelis-Lang/chelis`. Rotate with
  `gh secret set CHELIS_RELEASE_TOKEN --repo Chelis-Lang/nautilus`.

## Phase Spec

The owning spec section for this shell is checked in at
`spec/phase3j.md`, extracted verbatim from the Chelis monorepo's
`spec/design/chelis_phase3_plan.md`. That file is the source of truth
for module scope, test plan, and acceptance oracle. Update this repo's
copy in the same change set as any monorepo-side changes to the
original section.

## Shared Local Skills

Project-local skills live in `agent-skills/`. `.claude/skills` and
`.codex/skills` are symlinks to that directory so both tool surfaces
load the same skill library. `.claude/commands/` and `.codex/commands/`
mirror each other. The shared skill set (`redteam-exec`, `spec-sync`,
`phase-gate`, `backend-numerics`, `example-corpus`, `cli-surface`) and
the `red-team` alias wired to `redteam-exec` are copied from the
monorepo and should stay behaviorally aligned with it. If a skill
diverges upstream, update this repo in the same change set.

## Upstream Chelis Bugs

Upstream bugs tracked in [`upstream-bugs.md`](docs/upstream-bugs.md) —
originally found against v0.1.3, with per-bug status notes for each
subsequent release. The historically tracked bugs that blocked the
shipped Nautilus surface have all been fixed in releases up through
`v0.1.21`. `v0.1.7` closed the last two original open issues — Bug 2
(literal-dim shape-checker gap) now emits `DimensionMismatch` at
`chelis check` time, and Bug 3c (main-entry wrapper emission) now
produces correct multi-tensor-input entry points with a proper OpenMP
elementwise-add loop for tensor-on-tensor operations. LinAlg /
Distance / SDE / Stats / Interpolation tensor-path runtime
verification is no longer upstream-blocked. The remaining open
blocker — tensor-valued `grad` at the C-backend lowering level
(multi-parameter LM) — was last verified against `v0.1.21` and has
not been re-probed specifically against the current `0.11.1` pin; see
`docs/upstream-bugs.md` for details.

## Authorship Policy

No commit may carry a `Co-Authored-By:` trailer attributing authorship to an
AI tool (Claude, Codex, or similar). This is enforced by a commit-msg hook
and by CI on every push and pull request.

After cloning, install the hook:

    cp hooks/commit-msg .git/hooks/commit-msg && chmod +x .git/hooks/commit-msg

## Scaffolding Drift Rule

All Chelis shell repos share the same scaffolding shape by design. Any
structural change to this repo (layout, CI workflow, agent surface,
reef manifest format) should be mirrored into the other shell repos in
the same change set, or explicitly flagged as a per-repo divergence
with a recorded reason.
