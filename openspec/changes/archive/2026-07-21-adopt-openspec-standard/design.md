## Context

Nautilus already has an owning phase specification, public-surface documentation, strict shell-conformance rules, negative tests, blocked probes, reviewed SciPy parity goldens, and executable CI gates. Those artifacts remain authoritative for numerical correctness, but they do not provide one uniform lifecycle for proposing a change, reviewing normative scenarios, sequencing implementation, and retiring superseded intent.

OpenSpec 1.6.0 provides that lifecycle. A scoped Nix flake can lock optional local OpenSpec tooling from `numtide/llm-agents.nix`, while CI can install the official `@fission-ai/openspec` package through a repository-scoped npm lock. Both paths leave Nautilus's existing Chelis and parity environments unchanged.

## Goals / Non-Goals

**Goals:**

- Give every significant Nautilus change a reviewable requirements contract before implementation.
- Preserve numerical domain, tolerance, stability, AD, parity, compiler-pin, and downstream compatibility boundaries.
- Keep each branch to one coherent governed outcome without making branch names compliance evidence.
- Make implementation evidence, task completion, baseline synchronization, and lifecycle closure explicit.
- Expose one governance checker using OpenSpec 1.6.0 through lock-backed optional local Nix tooling and lock-backed npm provisioning in CI.
- Close the pre-sync, symlink-mutation, and mixed-line-ending task bypasses identified during the Beacon prototype review.

**Non-Goals:**

- Retroactively migrate historical Nautilus plans or releases.
- Replace `AGENTS.md`, `spec/phase3j.md`, `docs/CHELIS_SURFACE.md`, parity goldens, issue tracking, or executable tests.
- Infer numerical correctness from planning validity.
- Change Nautilus runtime behavior, public APIs, algorithms, tolerances, AD behavior, or compiler pins.
- Add a repository-wide development flake or migrate Chelis/SciPy tooling to Nix.
- Immediately impose this shell-local pilot's layout on sibling repositories.

## Decisions

### 1. Use the built-in spec-driven lifecycle

`openspec/` is the canonical planning root. Every lifecycle marker explicitly selects OpenSpec's built-in `spec-driven` schema. Project-local schemas under `openspec/schemas/` are forbidden because they resolve ahead of built-ins and could weaken the proposal, specs, design, and tasks graph. Initialization keeps the core profile with no generated tool-specific instruction trees; existing repository guidance remains authoritative.

### 2. Classify every non-empty branch

Significant work includes observable numerical behavior, APIs, architecture, algorithms or supported domains, dependency strategy, data formats, assurance or security posture, or operations. Editorial and behavior-preserving maintenance may use one immutable TOML exemption under `openspec/exemptions/`, listing every non-governance path in the branch diff. A branch cannot combine an exemption with a lifecycle. Work that expands beyond maintenance stops until a change is apply-ready.

Branches already open when this policy lands are not silently grandfathered. Their next merge-bound validation must add the record matching final scope. This keeps one mechanically enforceable rule rather than relying on branch creation dates.

### 3. Govern scope through artifacts, not branch names

Significant work uses a dedicated branch or isolated worktree and adds exactly one lifecycle marker. Branch naming remains conventional rather than normative. The gate reads all Git diff statuses, counts malformed and dot-prefixed lifecycle paths, rejects edits to existing lifecycle evidence, and excludes unrelated scope. Multiple capability deltas may share one change only when they are necessary for one merge-ready outcome.

### 4. Require apply readiness before implementation

Contributors create proposal, specs, design, and tasks in the dependency order reported by OpenSpec. Before normal implementation, every `apply.requires` artifact reports complete and strict non-interactive validation passes. An active production or security incident may begin early only with a recorded incident, reason, bounded scope, and artifact owner; normal evidence remains mandatory before merge.

### 5. Preserve numerical evidence authority

Normative requirements use SHALL/MUST language and scenarios covering applicable nominal, boundary, invalid-domain, unsupported-path, tolerance, AD, and parity behavior. Tasks name positive and negative coverage, documentation effects, and one authoritative oracle. OpenSpec records intent and traceability; Nautilus's reviewed parity goldens, Chelis-native tests, blocked probes, conformance checks, and owning specs decide correctness.

### 6. Use one controlled archive workflow

Explicit pre-archive mode requires complete artifacts and tasks while allowing one active lifecycle. It also requires the branch baseline under `openspec/specs/` to remain unchanged from the comparison base; synchronization belongs to the archive operation. Merge-bound mode requires zero active lifecycles and archived branch evidence.

Post-archive validation reconstructs expected baseline requirements by applying the archived delta to branch-base specs through locked OpenSpec 1.6.0, then compares requirement names, text, and scenarios with the checked-in baseline. Invalid archive names, missing artifacts, unchecked or undescribed tasks, and unsynchronized requirements fail closed.

All files and directories under `openspec/` must be non-symlink repository artifacts. Without that rule an archived proposal, task list, or delta could mutate through an ordinary-path target while Git reports no lifecycle change.

Task parsing splits on LF without normalizing bytes, mirrors OpenSpec's ECMAScript whitespace and case-insensitive completion mark, accepts Nautilus's stricter indented lists, strips only a trailing CR from each LF-delimited line, and requires a non-whitespace description. This catches incomplete CRLF tasks in otherwise LF files.

### 7. Pin optional local tooling and CI provisioning separately

`ci/flake.nix` exposes optional `openspec` and `openspec-gate` apps on supported Linux and macOS systems. `ci/flake.lock` transitively pins `numtide/llm-agents.nix` revision `5cefe9e186d79d89abd38b3a225d8eb3b6d64ae3`, whose package reports OpenSpec 1.6.0. The flake launcher injects absolute Nix-store Python, Git, and OpenSpec executables for developers who choose Nix.

GitHub Actions does not install or invoke Nix for OpenSpec. `ci/package.json` pins `@fission-ai/openspec` exactly at 1.6.0, and `ci/package-lock.json` locks the complete npm dependency graph with registry integrity hashes. CI pins `actions/setup-node` to an immutable revision and Node 22.17.0, runs `npm ci --prefix ci --ignore-scripts`, and passes the repository-local OpenSpec executable to the checker. Installation, version validation, checker execution, or governance validation failure has no ambient-executable fallback.

### 8. Share checker behavior across local and CI paths

Developers may run `nix run ./ci#openspec -- <args>` for direct CLI work and `nix run ./ci#openspec-gate` for merge-bound governance. `--pre-archive` is explicit. CI invokes the same `scripts/check_openspec.py` with the npm-locked executable and its event-specific base SHA. Both paths run completion, branch-scope, archive, and negative self-test controls; the checker independently enforces OpenSpec 1.6.0.

### 9. Record the shell-scaffolding pilot

Adding `openspec/`, `ci/`, and one governance step is a deliberate Nautilus pilot. `AGENTS.md` records the divergence and the reason: numerical changes have unusually coupled domain, tolerance, AD, and parity contracts, and Nautilus is the chosen first shell for validating governance before any sibling cascade. No managed Chelis block or shared skill tree is edited.

## Risks / Trade-offs

- **Extra ceremony for small work** → Use exact-path maintenance exemptions.
- **False confidence from valid prose** → Keep executable numerical and conformance gates authoritative.
- **Optional local Nix latency** → Keep Nix outside the CI critical path and retain its transitive lock.
- **npm registry or action supply failure** → Commit integrity-checked npm resolution, pin the Node action and runtime, ignore package scripts, and fail without ambient fallback.
- **Shell scaffolding drift** → Record this pilot explicitly and defer sibling adoption to a separately governed decision.
- **Archive sequencing errors** → Reject baseline edits while lifecycle evidence is active.
- **Mutable historical evidence** → Reject every symlink under `openspec/`.
- **Parser drift** → Lock mixed LF/CRLF and OpenSpec whitespace parity in negative fixtures.

## Migration Plan

1. Refresh this existing change on current Nautilus `origin/main` and complete both capability contracts.
2. Add optional locked Nix apps, CI-only npm locking, and the dependency-free checker with targeted positive and negative controls.
3. Add the npm-provisioned governance step to the existing guard dependency chain and document the optional local Nix workflow.
4. Record the pilot divergence without editing managed agent or skill content.
5. Run strict OpenSpec validation, focused checker fixtures, workflow tests, conformance audit, diff checks, and a fresh adversarial review.
6. Run the complete pre-archive gate, synchronize both capabilities once, archive the lifecycle, and rerun merge-bound validation.

Rollback removes the process, CI, and scoped tooling additions before dependent governed changes land. Numerical behavior remains unchanged.

## Open Questions

None. A sibling-shell rollout requires a separate decision after Nautilus demonstrates the workflow.
