# nix-openspec-tooling Specification

## Purpose
TBD - created by archiving change adopt-openspec-standard. Update Purpose after archive.
## Requirements
### Requirement: Scoped CI flake exposes stable OpenSpec apps
Nautilus SHALL maintain `ci/flake.nix` and `ci/flake.lock` as the repository-scoped entry point for OpenSpec tooling. The flake SHALL expose `openspec` for direct CLI work and `openspec-gate` for complete governance validation on supported Linux and macOS systems.

#### Scenario: Developer invokes direct OpenSpec
- **WHEN** a developer runs `nix run ./ci#openspec -- <args>`
- **THEN** Nix SHALL execute the lock-pinned package
- **THEN** `--version` SHALL report 1.6.0

#### Scenario: Developer invokes merge-bound governance
- **WHEN** a developer runs `nix run ./ci#openspec-gate`
- **THEN** the app SHALL run merge-bound completion and negative self-tests against `origin/main`
- **THEN** active lifecycle evidence SHALL be rejected

#### Scenario: Developer invokes pre-archive governance
- **WHEN** a developer runs `nix run ./ci#openspec-gate -- --pre-archive`
- **THEN** one complete active lifecycle MAY be validated
- **THEN** baseline spec changes SHALL still be rejected

### Requirement: CI provisions OpenSpec through pinned Nix inputs
The CI guard SHALL install Nix through an immutable action revision. `ci/flake.lock` SHALL lock `numtide/llm-agents.nix` at revision `5cefe9e186d79d89abd38b3a225d8eb3b6d64ae3`, and the resulting executable SHALL report OpenSpec 1.6.0.

#### Scenario: Pinned package is available
- **WHEN** CI runs the governance app
- **THEN** Nix SHALL build or substitute the package from locked inputs
- **THEN** the checker SHALL independently verify version 1.6.0

#### Scenario: Provisioning fails
- **WHEN** installation, evaluation, realization, substitution, launch, or version verification fails
- **THEN** CI SHALL fail without npm or ambient-executable fallback

### Requirement: Gate app injects immutable store executables
The `openspec-gate` app SHALL inject exact Nix-store Python, Git, and OpenSpec executable paths before invoking `scripts/check_openspec.py`.

#### Scenario: Gate launches successfully
- **WHEN** the app starts
- **THEN** repository discovery SHALL use the store Git executable
- **THEN** every OpenSpec command and self-test SHALL use the store OpenSpec executable

#### Scenario: OpenSpec version differs
- **WHEN** the injected executable does not report exactly 1.6.0
- **THEN** validation SHALL stop before governance checks

### Requirement: Local and CI gates share one command surface
Repository guidance and GitHub Actions SHALL invoke the default merge-bound `nix run ./ci#openspec-gate`. CI MAY provide an event-specific base SHA; local invocation SHALL default to `origin/main`. The same app SHALL expose explicit `--pre-archive` mode.

#### Scenario: Pull request gate runs
- **WHEN** GitHub Actions validates a pull request
- **THEN** it SHALL pass the pull request base SHA
- **THEN** the same completion, self-test, archive-state, branch-scope, symlink, task, and synchronization controls used locally SHALL run

### Requirement: OpenSpec-specific Node and npm bootstrap is absent
Nautilus CI SHALL NOT provision Node or invoke npm solely for OpenSpec. The scoped Nix flake SHALL be the supported provisioning path.

#### Scenario: Workflow is inspected
- **WHEN** the governance steps are reviewed
- **THEN** no OpenSpec-specific Node setup or npm installation SHALL exist
- **THEN** CI SHALL invoke `ci#openspec-gate`

### Requirement: Numtide cache trust is explicit
The Nix installer action SHALL configure `https://cache.numtide.com` and trusted public key `niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=` explicitly. Cache use SHALL NOT replace lock or version checks.

#### Scenario: Cached package is substituted
- **WHEN** Numtide serves the locked package
- **THEN** Nix SHALL verify the configured key
- **THEN** the checker SHALL still enforce OpenSpec 1.6.0
