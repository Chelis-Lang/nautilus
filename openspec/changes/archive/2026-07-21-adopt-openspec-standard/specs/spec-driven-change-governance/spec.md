## ADDED Requirements

### Requirement: Significant changes use OpenSpec
The repository workflow SHALL require an OpenSpec change before implementation begins when proposed work changes externally observable numerical behavior, architecture, a public or machine-facing contract, an algorithm or supported domain, dependency strategy, data or interchange formats, assurance or security posture, or operational behavior. Typo fixes, formatting, and behavior-preserving maintenance MAY proceed without a lifecycle only when they add exactly one immutable regular non-symlink `openspec/exemptions/YYYY-MM-DD-<kebab-case-id>.toml` manifest containing `kind = "maintenance"`, a non-empty reason, and every changed non-governance repository path other than the manifest itself.

#### Scenario: Significant work is proposed
- **WHEN** proposed work changes any governed significant-change category
- **THEN** the contributor SHALL use a dedicated branch or isolated worktree
- **THEN** the contributor SHALL create an OpenSpec change before implementation begins

#### Scenario: Maintenance remains behavior-preserving
- **WHEN** work is limited to editorial or behavior-preserving maintenance
- **THEN** a full lifecycle SHALL NOT be required
- **THEN** one exact-path maintenance exemption SHALL classify the complete branch diff

#### Scenario: Branch has no governance evidence
- **WHEN** a non-empty branch diff adds neither a lifecycle nor an exemption
- **THEN** the governance gate SHALL fail

#### Scenario: Exempt work expands in scope
- **WHEN** exempt work grows to alter a governed category
- **THEN** implementation SHALL stop before further significant edits
- **THEN** the exemption SHALL leave the final branch diff
- **THEN** a change SHALL become apply-ready before implementation resumes

### Requirement: Changes become apply-ready through ordered artifacts
Each significant change SHALL use a unique lowercase kebab-case identifier other than the reserved archive-container name `archive` and SHALL contain a proposal, one delta specification for each proposed capability, a design, and an implementation task list. Every lifecycle marker SHALL select the built-in `spec-driven` schema, and `openspec/schemas/` SHALL NOT exist. Contributors SHALL obtain current CLI instructions and read completed dependencies before writing a dependent artifact.

#### Scenario: A new significant change is planned
- **WHEN** a contributor creates a change
- **THEN** the proposal SHALL identify every new or modified capability
- **THEN** one specification delta SHALL exist for each identified capability
- **THEN** design and tasks SHALL follow the dependency order reported by `openspec status`

#### Scenario: Lifecycle schema is weakened locally
- **WHEN** metadata selects another schema or a project-local schema directory exists
- **THEN** the governance gate SHALL fail before accepting schema-dependent completion

#### Scenario: Required artifact is absent
- **WHEN** proposal, specs, design, or tasks do not report complete
- **THEN** implementation and archival SHALL remain blocked

### Requirement: Change branches remain isolated and reviewable
Every non-empty branch diff SHALL add exactly one governance record: one lifecycle for significant work or one maintenance exemption. Significant branches SHALL exclude unrelated work. Branch naming SHALL remain non-normative. CI SHALL inspect additions, modifications, deletions, and type changes; classify malformed and dot-prefixed active or archived lifecycle paths; require a newly added lifecycle marker; reject modifications to existing lifecycle paths; allow one complete active lifecycle only in explicit pre-archive mode; and require zero active lifecycles plus archived evidence in merge-bound mode. Branches opened before policy adoption SHALL comply before their next merge-bound validation.

#### Scenario: Significant branch is reviewed
- **WHEN** CI compares a significant branch with its base
- **THEN** exactly one newly added lifecycle marker SHALL be present
- **THEN** compliance SHALL NOT depend on the branch name

#### Scenario: Branch changes multiple lifecycles
- **WHEN** diff paths belong to more than one lifecycle under any status
- **THEN** the gate SHALL fail

#### Scenario: Existing lifecycle is changed
- **WHEN** a branch modifies, deletes, or type-changes existing lifecycle evidence
- **THEN** that evidence SHALL NOT satisfy the new branch lifecycle requirement
- **THEN** the gate SHALL fail

#### Scenario: Active lifecycle reaches merge validation
- **WHEN** merge-bound validation finds any active lifecycle
- **THEN** the gate SHALL fail even if artifacts and tasks are complete

#### Scenario: Lifecycle and exemption are combined
- **WHEN** a diff contains both lifecycle and exemption changes
- **THEN** the gate SHALL fail

#### Scenario: Additional independent scope is discovered
- **WHEN** implementation reveals unrelated or independently reviewable work
- **THEN** that work SHALL move to another change and branch

### Requirement: OpenSpec artifacts are immutable repository files
The `openspec/` root and every file or directory beneath it SHALL be ordinary non-symlink repository content. Validation and archive replay SHALL reject symbolic links before reading, copying, or invoking OpenSpec so historical lifecycle evidence cannot mutate through another path.

#### Scenario: Lifecycle artifact is a symlink
- **WHEN** proposal, design, tasks, metadata, or a delta specification is a symbolic link
- **THEN** governance validation SHALL fail before following the link

#### Scenario: Baseline or configuration is a symlink
- **WHEN** configuration, a baseline specification, or a governance directory is a symbolic link
- **THEN** governance validation SHALL fail

### Requirement: Strict planning validation gates implementation
A significant change SHALL pass `openspec validate <change> --strict --no-interactive` and every artifact required by `apply.requires` SHALL report `done` before implementation begins. Planning validity SHALL NOT replace Nautilus's executable numerical, parity, negative-test, blocked-probe, or conformance evidence.

#### Scenario: Planning is apply-ready
- **WHEN** strict validation succeeds and every apply-required artifact is done
- **THEN** normal implementation MAY begin

#### Scenario: Executable evidence fails
- **WHEN** planning passes but an owning repository oracle fails
- **THEN** the change SHALL remain incomplete

### Requirement: Requirements trace to numerical acceptance evidence
Every normative requirement SHALL contain at least one WHEN/THEN scenario. Applicable numerical requirements SHALL identify supported domains, tolerances, stability, AD behavior, unsupported outcomes, and parity evidence. Tasks SHALL identify positive and negative coverage, documentation impact, and one authoritative completion oracle, and SHALL be checked only after observing their evidence.

#### Scenario: Numerical tasks are derived
- **WHEN** tasks are written from completed design and specs
- **THEN** they SHALL cover applicable nominal, boundary, invalid-domain, unsupported-path, tolerance, AD, and parity behavior
- **THEN** they SHALL name an authoritative repository oracle

#### Scenario: Existing authority owns details
- **WHEN** `spec/phase3j.md`, surface documentation, a reviewed golden, or another owning artifact already specifies behavior
- **THEN** the change SHALL link that authority rather than copy a conflicting contract

### Requirement: Emergency exceptions remain explicit and bounded
Implementation MAY begin before apply readiness only for an active security or production incident where delay would materially increase harm. The branch SHALL record the incident reference, reason, bounded scope, and artifact owner. All normal artifacts, strict validation, and repository acceptance evidence SHALL pass before merge.

#### Scenario: Emergency implementation begins
- **WHEN** an active incident makes normal planning delay unsafe
- **THEN** the branch SHALL record the incident, justification, scope, and owner

#### Scenario: Emergency work reaches merge
- **WHEN** emergency implementation is ready to merge
- **THEN** every normal planning and executable acceptance requirement SHALL be satisfied

### Requirement: Active changes do not pre-synchronize baseline specs
While branch lifecycle evidence is active, the branch diff SHALL NOT add, modify, delete, or type-change any path under `openspec/specs/`. Explicit pre-archive validation SHALL compare against its selected base and fail when baseline specification paths changed. Synchronization SHALL occur only in the single archive workflow.

#### Scenario: Baseline is edited before archive
- **WHEN** an active lifecycle branch changes any baseline specification path
- **THEN** pre-archive validation SHALL fail
- **THEN** the contributor SHALL restore the base baseline before archival

#### Scenario: Direct archive follows a green pre-archive gate
- **WHEN** pre-archive validation succeeds
- **THEN** applying an ADDED delta SHALL NOT collide with a requirement already copied into the baseline

### Requirement: Completed changes use one controlled archive workflow
A change SHALL be complete only after every planning artifact reports complete, implementation evidence is accepted, every task is checked from observed evidence, strict planning and repository gates pass, and one archive workflow synchronizes delta specifications and moves the lifecycle. Contributors SHALL NOT approve incomplete-task warnings. Merge-bound validation SHALL require archived evidence, strictly validate every archived lifecycle, reconstruct expected requirements from branch-base specs and the locked delta, compare requirement names, text, and scenarios with the checked-in baseline, reject invalid calendar dates, and reject unchecked or undescribed tasks.

#### Scenario: All implementation work is accepted
- **WHEN** every task and authoritative oracle has accepted evidence
- **THEN** explicit pre-archive validation SHALL pass with unchanged baseline specs
- **THEN** one workflow SHALL synchronize and archive the change
- **THEN** merge-bound validation SHALL pass after the move

#### Scenario: Archived delta is absent or divergent
- **WHEN** replaying the archived delta against branch-base specs differs from the checked-in baseline
- **THEN** the gate SHALL fail

#### Scenario: Some scope remains incomplete
- **WHEN** any requirement, artifact, task, or oracle lacks accepted evidence
- **THEN** the change SHALL remain active or move residual scope to another change

### Requirement: Task completion parsing fails closed across supported syntax
Completion checks SHALL recognize dash and asterisk markers, OpenSpec 1.6's non-LF ECMAScript whitespace, case-insensitive `x`, and indented task lists. Parsing SHALL split raw UTF-8 content on LF without universal-newline normalization, remove at most one trailing CR for description analysis, require non-whitespace task text, and reject every recognized unchecked task.

#### Scenario: Mixed line endings contain unfinished work
- **WHEN** an otherwise LF task file contains a CRLF-terminated unchecked task
- **THEN** the completion check SHALL count it as unchecked and fail

#### Scenario: CRLF checkbox has no description
- **WHEN** a CRLF-terminated completed checkbox has no non-whitespace description
- **THEN** the completion check SHALL fail

#### Scenario: OpenSpec whitespace or uppercase completion is used
- **WHEN** a task uses OpenSpec-recognized Unicode whitespace or uppercase `X`
- **THEN** the checker SHALL classify it consistently with OpenSpec while retaining Nautilus's stricter description and indentation rules
