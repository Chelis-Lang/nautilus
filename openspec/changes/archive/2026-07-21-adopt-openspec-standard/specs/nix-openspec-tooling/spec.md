## ADDED Requirements

### Requirement: Scoped CI flake exposes optional local OpenSpec apps
Nautilus SHALL maintain `ci/flake.nix` and `ci/flake.lock` as an optional local entry point for OpenSpec tooling. The flake SHALL expose `openspec` for direct CLI work and `openspec-gate` for complete governance validation on supported Linux and macOS systems. GitHub Actions SHALL NOT require Nix to run OpenSpec governance.

#### Scenario: Developer invokes direct OpenSpec through Nix
- **WHEN** a developer runs `nix run ./ci#openspec -- <args>`
- **THEN** Nix SHALL execute the lock-pinned package
- **THEN** `--version` SHALL report 1.6.0

#### Scenario: Developer invokes local governance through Nix
- **WHEN** a developer runs `nix run ./ci#openspec-gate`
- **THEN** the app SHALL run merge-bound completion and negative self-tests against `origin/main`
- **THEN** active lifecycle evidence SHALL be rejected

### Requirement: CI uses an immutable central OpenSpec action
After full-history checkout, the CI guard SHALL invoke `Chelis-Lang/ci/actions/openspec-governance@8b240a2d0ea55f161e69b44b2ee42733ee197230`. Nautilus SHALL NOT duplicate the action's Node setup, npm package metadata, npm lock, or event-base launcher.

#### Scenario: Reviewed central action is available
- **WHEN** GitHub Actions prepares the governance gate
- **THEN** it SHALL fetch the exact full central commit
- **THEN** the action SHALL provide OpenSpec 1.6.0 and run Nautilus's checker

#### Scenario: Central action is inaccessible or fails
- **WHEN** private action access, Node setup, npm integrity, exact version validation, launch, or governance validation fails
- **THEN** CI SHALL fail without Nix or ambient-executable fallback

### Requirement: Central action invocation remains bounded
The pinned central action SHALL accept no caller commands, checker paths, executable paths, modes, bases, secrets, or permissions. It SHALL derive a bounded event comparison base and invoke exactly the regular non-symlink `scripts/check_openspec.py` from the checked-out Nautilus workspace with self-test and merge-bound arguments.

#### Scenario: Pull request gate launches
- **WHEN** the checked-out repository has full history and the fixed checker path is valid
- **THEN** the action SHALL pass the pull request base SHA to the checker
- **THEN** every OpenSpec command and negative self-test SHALL use the action-local executable

#### Scenario: Consumer prerequisite is invalid
- **WHEN** the event payload, comparison SHA, Python version, Git executable, workspace, or fixed checker path is absent or malformed
- **THEN** validation SHALL stop before accepting governance evidence

### Requirement: Local and CI gates share checker controls
Optional local Nix invocation and central-action CI invocation SHALL execute the same dependency-free `scripts/check_openspec.py`. CI SHALL use its event-specific base SHA; local invocation SHALL default to `origin/main`. Both paths SHALL execute completion, self-test, archive-state, branch-scope, symlink, task, and synchronization controls, and the checker SHALL independently enforce OpenSpec 1.6.0.

#### Scenario: Equivalent merge-bound evidence is evaluated
- **WHEN** the local gate and CI gate validate the same repository state and comparison commit
- **THEN** both SHALL apply the same Nautilus-owned governance checks
- **THEN** provisioning differences SHALL NOT change acceptance semantics

### Requirement: Shared mechanics do not move Nautilus authority
Nautilus SHALL retain workflow triggers, checkout depth, job dependencies, permissions, `scripts/check_openspec.py`, lifecycle artifacts, compiler pins, numerical gates, parity evidence, and downstream contracts. The central action SHALL own only OpenSpec CI provisioning and bounded launch mechanics.

#### Scenario: Workflow and repository are inspected
- **WHEN** the governance integration is reviewed
- **THEN** Nautilus SHALL contain one immutable action pointer instead of Node/npm implementation steps
- **THEN** numerical, parity, compiler, and credential behavior SHALL remain unchanged

### Requirement: Hosted consumer evidence gates pointer acceptance
The central action's deterministic and hosted self-tests SHALL pass on commit `8b240a2d0ea55f161e69b44b2ee42733ee197230`, and Nautilus's complete hosted suite SHALL pass through that exact pointer before the migration is accepted. The prior local npm implementation SHALL remain available in Git history for rollback.

#### Scenario: Nautilus pointer is reviewed
- **WHEN** PR CI runs with the central action pointer
- **THEN** private cross-repository access and repository-specific governance SHALL be proven by the hosted run
- **THEN** a green local simulation alone SHALL NOT satisfy acceptance

#### Scenario: Pointer migration fails
- **WHEN** private access or any required Nautilus job fails because of the central pointer
- **THEN** the PR SHALL restore the prior local provisioning or select a separately reviewed known-good central SHA
- **THEN** rollback SHALL NOT change OpenSpec policy, numerical behavior, compiler pins, permissions, or credentials
