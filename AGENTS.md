# Nautilus Agent Contract

Canonical agent instructions for this repository. `CLAUDE.md` is a symlink
to this file so Claude-style and Codex-style entry points do not drift.

## Repo Identity

<!-- BEGIN CHELIS MANAGED BLOCK: agents-inheritance chelis@0.18.12 (sha256:7a29d33c9cfe7d57) -->
# Chelis Agent Contract

Keep this file concise and relevant to every agent working in this repository.
Each added token is read tens of thousands of times. State a rule once, link the
document that owns the detail, and put the explanation in that document, not here.

`CLAUDE.md` is a symlink to this file so Claude-style and Codex-style entry points do
not drift.

## What Chelis Is

Chelis is a functional language for AI research, built for a workflow where a coding
agent is the primary author and a human is the supervisor, and where the programs are
themselves AI systems: models, training loops, search spaces, learned functions. The
bet is that a type system, representation, and compilation model designed around AI
primitives from the start beat ones bolted onto Python or a systems language later. It
is not a general-purpose language, a systems language, a web framework, or a Python
replacement. `spec/00-context.md` and `spec/design/chelis_canonical_reference.md` own
the full statement; their specifics may lag, their intent does not. When a tradeoff
appears, apply these in order:

1. **Unambiguity over ergonomics.** The author is an agent. The friction a human feels
   spelling out every type, effect, dtype, and dimension is not worth a reading the
   compiler has to guess at.
2. **Composition over special cases.** A new capability composes existing primitives
   before it earns a new one.
3. **Inference over annotation.** Where the checker determines something uniquely, the
   author does not repeat it; intermediates carry no ascription.
4. **Machine generation first.** A convenience that exists only for a human typist is
   not a reason to add syntax, a default, or a fallback.
5. **Additive sugar only.** Every surface form desugars to the core; nothing in the
   surface has semantics the core lacks.
6. **Explicit over implicit.** No implicit broadcasting (`expand` only), no implicit
   precision promotion, no implicit currying or partial application, no silent
   narrowing at ingress, no hidden effects. Where intent cannot be determined uniquely,
   the compiler rejects.
7. **Small language, big library.** The compiler knows only the closed RISC primitive
   set and its derived built-ins; everything else is a library. The canonical reference
   §8.5 has the core/standard-library/external-library taxonomy.
8. **Future-proof without over-building.** Decide the rule fully now, implement what
   the phase needs, and never narrow a rule to what a lane implements today.

Two corollaries govern how the compiler itself is changed. Chelis is pre-compatibility
unless a controlling contract says otherwise, so prefer the structural design that
makes a defect class impossible over a smaller-blast-radius patch, a legacy default, a
versionless compatibility fallback, or phase deferral; close the class, not the
instance. And determinism is part of the contract: for fixed program text, compiler
build, target, and declared inputs, every check, evaluation, and build result is a
function of those inputs, and feedback that varies between identical runs is a defect.

## Quality Standards

### Spec-First Development

- Before writing implementation, write test stubs derived from the owning spec.
- Every spec requirement should have a corresponding test before the code exists.
- If the spec says "X is a type error," write the failing test before implementing
  the checker.

### Negative Test Parity

- For every test that checks something works, add the corresponding failure test.
- If you cannot name the failure case, the spec understanding is still weak.

### Do Not Trust Green

- Passing tests prove alignment with the tests, not necessarily with the spec.
- After green CI, check what active requirements still lack tests.
- Audit silent fallbacks, default values, empty error vectors, and `unwrap_or` paths.

## Review And Merge

## Environment And Tooling

## Subagents

[`docs/investigations/agent_contract_rationale.md`](docs/investigations/agent_contract_rationale.md)
holds the measurements behind these rules.

- Every subagent prompt names the delivery mechanism and the complete expected report.
  A report that is not sent through the platform's final-report channel has not been
  delivered. A subagent never ends its turn merely to wait for a background build or
  notification that cannot wake it: keep ownership through a synchronous wait, or return
  an honest partial result. A reviewer that has delivered its round report is not
  waiting; it stays available for the orchestrator to resume with the fix.
- CI is watched by at most one background waiter whose exit wakes the session, or by
  nobody. Never watch CI from a foreground sleep or poll loop.
- If an agent returns "waiting" or goes idle without the deliverable, resume it
  immediately with the exact missing items. Prefer a labelled partial report over
  silence or an overstated completion claim, and deduplicate repeated reports that
  race with a resume nudge.
- More than five subagents live at once under one orchestrator needs the user's
  explicit approval and a stated reason. Five is the widest fan-out measured working
  here, not a certified safe width, and it is a separate budget from the CPU one above.
- Every spawn names its model tier and says in one clause why that tier fits: the
  expensive tier for judgement whose errors are costly to detect, the cheap tier for
  mechanical work such as waiting on CI, polling, or transcribing a result. The
  orchestrator states its own context size in the message that announces a spawn.
- Every brief states a numeric report-length budget, and a numeric context budget except
  for red-team rounds. An agent that will exceed its context budget says so and returns
  what it has.
- A brief says which facts the orchestrator has already verified, against what head, and
  that the agent must not re-derive them, and it names what the agent still has to
  establish itself.
- A brief longer than a few paragraphs is a file passed by absolute path, stored where
  it outlives both the agent and the session, never in a per-session scratchpad.
  Inter-agent messages truncate silently near four kilobytes. "Inline" means
  self-contained, the opposite of "read `AGENTS.md`", not pasted into the spawn message.
- Reports come back the same way: the agent writes the report to a file and replies with
  the absolute path and a one-line summary. That reply is the delivery.
- A subagent that reuses a worktree restores its temporary probes and reports the final
  worktree status unless asked to retain them. Before a heavyweight cargo command it
  reports the exact command and expected weight to the orchestrator.

## Writing Chelis Source

Load the [`example-corpus` skill](agent-skills/example-corpus/SKILL.md) before writing
any `.ch`; it carries the Surf style rules, the parse-breaking spellings, and the Deep
AST contract. `spec/02-surf-syntax.md` §0.1 is the authority.

- `chelis build`, `check`, `validate`, and `eval --file` run `chelis fmt --check` and the
  blocking `chelis lint` rules before the front end; style failures block the build.
  `--allow-style-violations` is for emergency local builds only, never CI, and
  `CHELIS_STYLE_GATE_DISABLE=1` is reserved for the integration-test corpus. Run
  `chelis fmt --inplace <file>` and `chelis lint --check` before pushing.
- Type system: no implicit precision promotion, named tensor dimensions match by name,
  no implicit broadcasting (explicit `expand` only), integer literals default to `i32`
  and float literals to `f32`.
- `chelis build` emits C, a header, runtime artifacts, and compile flags; `--target hip`
  emits host code with embedded kernel strings. Neither invokes the native compiler.

<!-- END CHELIS MANAGED BLOCK: agents-inheritance -->

- Nautilus is a downstream **shell repo** for the
  [Chelis](https://github.com/Chelis-Lang/chelis) language, scoped to
  numerical methods, statistics, and optimization.
- Upstream of truth: `Chelis-Lang/chelis`. The retained sections of its
  pinned `AGENTS.md` are generated above. Chelis's numbered specs govern
  language semantics; [`spec/scope.md`](spec/scope.md) and the local sections
  below govern Nautilus's library, pin, and gate.

## Inherited Contract Scope

The selectors below omit Chelis compiler-only review commands, PR, spec,
release, issue, worktree cleanup, and build machinery. Nautilus's review and
worktree rules below, Pin Bump Checklist, `CONTRIBUTING.md`, and
`spec/scope.md` own those local procedures. The pointer selector removes
links and edit routes for compiler files absent from Nautilus.

<!-- shell-local:exclude:begin -->
<!-- ### Red Team Rounds -->
<!-- ### Pull Request Lifecycle -->
<!-- ## Spec Authority And Design Discipline -->
<!-- ## Change Hygiene -->
<!-- ## Issue Tracking -->
<!-- ### Worktree And Branch Discipline -->
<!-- ### Python And Scripts -->
<!-- ### Build And Gate Commands -->
<!-- ## Pointers -->
<!-- ## The Chelis-Lang Repositories -->
<!-- shell-local:exclude:end -->

## Nautilus Review And Worktrees

- Every PR receives a red-team round before merge. Keep the reporting reviewer
  through local repair verification and push the repair only after that reviewer
  is satisfied. The retained `redteam-exec` skill owns the round protocol; its
  shell-local block owns the Nautilus handoff.
- Keep the primary checkout read-only. Create a dedicated task worktree with its
  own `.venv` before writing, and never use the shared stash or repurpose an
  unrelated worktree. Do not write or build in a worktree while a reviewer
  reads it.
- Before handing off a worktree, record its exact head and
  `git status --porcelain --untracked-files=all`, list worktrees, and scan
  the worktree, its separate Git directory, and Git's shared common
  directory for open handles. From any
  directory in that worktree, set
  `review_worktree="$(realpath "$(git rev-parse --show-toplevel)")"` and
  `review_git_dir="$(realpath "$(git rev-parse --path-format=absolute --git-dir)")"`,
  and `review_git_common_dir="$(realpath "$(git rev-parse --path-format=absolute --git-common-dir)")"`.
  From outside those paths, scan each with `lsof -nP -x f +D <path>`;
  `-x f` crosses mounts. Resolve tracked symlinks and shared targets
  separately; check both Git directories for remaining locks. An unscanned
  external target, open handle, or Git lock
  makes the worktree unavailable. The
  `redteam-exec` skill gives the full handoff procedure. Treat unclear
  ownership as busy and use a separate worktree and target.
- After a PR merges, remove only its clean, idle task worktree with
  `git worktree remove <path>`. Preserve uncertain artifacts; decide branch
  deletion separately.

## Toolchain Policy

- Nautilus should track the latest **published and validation-clean**
  Chelis release by default. Treat stale pins as drift, not as a reason
  to stay on an older compiler.
- `reef.toml` should pin the currently validated published release exactly.
  Validate the binary selected by that pin before advancing it.
- If the latest published Chelis release fails Nautilus validation,
  document the blocker clearly and pin the newest known-good release
  until the blocker is resolved.
- Do not vendor or build the Chelis compiler from source inside this
  repo. Consume the released tarball from the private
  `Chelis-Lang/chelis` releases. CI authenticates via the repo secret
  `CHELIS_RELEASE_TOKEN`, which must hold a PAT with `contents: read`
  on `Chelis-Lang/chelis`. Rotate with
  `gh secret set CHELIS_RELEASE_TOKEN --repo Chelis-Lang/nautilus`.

## Pin Bump Checklist

A pin bump is a **de-narrowing event**, not a version edit. Complete all of
these steps in one change set and land the bump through a pull request, never
by editing the pin directly on `main`.

1. Run `chelis reef conform bump <version>`. Confirm that `reef.toml` and every
   toolchain-installing workflow's `CHELIS_TAG` / `CHELIS_VERSION` pair agree,
   and that the offline pin-consistency guard passes.
2. Run the blocked-probe suite when `tests_blocked/` is populated. A
   **FIX-detected** probe means the upstream limitation is gone: execute its
   de-narrowing instructions, promote it to a real test, remove the workaround,
   and archive the corresponding `UPSTREAM_BUGS` entry. A **DRIFTED** diagnostic
   must be investigated before it is re-cited.
3. Run `chelis reef conform audit --explain` and triage every closed-upstream
   issue still cited by a downstream workaround. Retire the workaround or cite
   the live residue issue; never carry it silently.
4. Re-probe every `docs/UPSTREAM_BUGS.md` entry due under its section cadence,
   **per verb and per surface**. A changelog claim is not verification. Re-probe
   manually when the blocked-probe suite cannot express the reproducer.
5. Refresh `docs/CHELIS_SURFACE.md`: pinned and upstream versions plus every
   `@pin` / `@upstream` marker.
6. Reclassify `UPSTREAM_BUGS` entries from the re-probe results: archive fixed
   behavior, retain live limitations under Tracking or Actively blocking, and
   record any remaining residue and its next trigger.
7. Run the complete local gate before pushing: formatting over all Chelis
   sources, `chelis lint --check .`, `chelis reef build`, the positive suite,
   `chelis test tests_neg/ --expect neg`, blocked probes when present, and the
   strict SciPy parity gate through its isolated Python environment. Finish with
   `chelis reef conform audit` and
   `chelis reef conform bump-check --base origin/main`.

Large or behaviorally significant bumps should also record the expected
unlocks and per-surface re-probe results as a migration note in the bump pull
request description. Do not check in per-version migration documents: the
repository describes the current pin, and history lives in `CHANGELOG.md`, pull
requests, and git.

## Scope and Acceptance

[`spec/scope.md`](spec/scope.md) owns Nautilus's intent, architecture,
acceptance rules, known limitations, and dated deferrals. `SKILL.md` §6 is the
function-level API inventory with per-export stability labels.
[`CONTRIBUTING.md`](CONTRIBUTING.md) lists the local gate commands. Deferral
citations in source (for example `Nautilus.Signal`) point at
`spec/scope.md` § Deferrals.

## Shared Local Skills

Project-local skills live in `agent-skills/`. `.claude/skills` and
`.codex/skills` are symlinks to that directory so both tool surfaces
load the same skill library. `.claude/commands/` and `.codex/commands/`
mirror each other. The complete shared set (`redteam-exec`, `spec-sync`,
`phase-gate`, `backend-numerics`, `example-corpus`, `cli-surface`,
`packaging-install`, and `issue-resolution`) is toolchain-owned material,
regenerated by `chelis reef conform sync`, and stamped in
`agent-skills/UPSTREAM.toml`; do not edit its managed content as a copied
fork. Repo-local domain skills must be declared through `[conform]
local_skills`, and shared-skill overrides use the sanctioned trailing
`shell-local` block. Keep the `red-team` alias wired to `redteam-exec`.

## Upstream Chelis Bugs

Upstream limitations are tracked in
[`docs/UPSTREAM_BUGS.md`](docs/UPSTREAM_BUGS.md), with executable reproducers
under `tests_blocked/` where the harness can express them and manual recipes in
[`tests_blocked/README.md`](tests_blocked/README.md) where it cannot. Cite every
narrowing by issue number at its site; never describe a limitation by prose
name alone.

## Authorship Policy

Use conventional commits with the configured human author. No commit may
carry a `Co-Authored-By:` trailer attributing authorship to an AI tool
(Claude, Codex, or similar). This is enforced by a commit-msg hook and by CI
on every push and pull request. Add a `changelog.d/` fragment for behavior
changes, document manual gates with their command and success condition,
and report validation at the exact tested head. Close issues only after
their behavior is confirmed on merged `main`.

After cloning, install the hook:

    cp hooks/commit-msg .git/hooks/commit-msg && chmod +x .git/hooks/commit-msg

## Scaffolding Drift Rule

All Chelis shell repos share the same scaffolding shape by design. Any
structural change to this repo (layout, CI workflow, agent surface,
reef manifest format) MUST be mirrored into the other shell repos in
the same change set, or explicitly flagged as a per-repo divergence
with a recorded reason.

### Recorded shell-local divergence: CI pin-guard ordering

As accepted on 2026-07-14, Nautilus's numerical CI chain transitively depends
on `pin-consistency-guard`; sibling School currently runs its conformance and
numerical jobs as siblings. This stricter ordering is intentional here because
a red pin audit or bump-check must prevent Nautilus's numerical jobs from
independently reporting green. It adds no workflow, layout, manifest shape, or
GitHub ruleset, and should be revisited when pin-guard ordering is standardized
across all shells.
