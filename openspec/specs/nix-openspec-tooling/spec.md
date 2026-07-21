# nix-openspec-tooling Specification

## Purpose
TBD - created by archiving change adopt-openspec-standard. Update Purpose after archive.
## Requirements
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

### Requirement: CI provisions OpenSpec through an npm lock
The CI guard SHALL pin `actions/setup-node` to an immutable commit and Node 22.17.0. `ci/package.json` SHALL select `@fission-ai/openspec` exactly at 1.6.0, and `ci/package-lock.json` SHALL lock its complete dependency graph with registry integrity hashes. CI SHALL install that graph with `npm ci --prefix ci --ignore-scripts`.

#### Scenario: Locked package is available
- **WHEN** CI prepares the governance gate
- **THEN** npm SHALL install only the dependency graph accepted by the committed lock
- **THEN** the checker SHALL independently verify OpenSpec 1.6.0

#### Scenario: Provisioning fails
- **WHEN** Node setup, npm installation, lock verification, launch, or version verification fails
- **THEN** CI SHALL fail without Nix or ambient-executable fallback

### Requirement: CI invokes the repository-local OpenSpec executable
The CI governance step SHALL set `OPENSPEC_BIN` to the executable under `ci/node_modules/.bin/openspec` before invoking `scripts/check_openspec.py`. It SHALL use the runner's existing Python and Git installations rather than obtaining them through Nix.

#### Scenario: CI gate launches successfully
- **WHEN** the governance step starts after `npm ci`
- **THEN** every OpenSpec command and negative self-test SHALL use the repository-local executable
- **THEN** the checker SHALL inspect the event-specific comparison base

#### Scenario: Repository-local executable is absent or wrong
- **WHEN** the locked executable is missing or does not report exactly 1.6.0
- **THEN** validation SHALL stop before accepting governance evidence

### Requirement: Local and CI gates share checker controls
Optional local Nix invocation and npm-provisioned CI invocation SHALL execute the same dependency-free `scripts/check_openspec.py`. CI MAY provide an event-specific base SHA; local invocation SHALL default to `origin/main`. Both paths SHALL support explicit pre-archive mode and default merge-bound mode.

#### Scenario: Pull request gate runs
- **WHEN** GitHub Actions validates a pull request
- **THEN** it SHALL pass the pull request base SHA
- **THEN** the same completion, self-test, archive-state, branch-scope, symlink, task, and synchronization controls used locally SHALL run

### Requirement: OpenSpec-specific Node and npm scope remains isolated
Node and npm added for OpenSpec SHALL be confined to the governance job and `ci/package.json` plus `ci/package-lock.json`. Nautilus's Chelis build, tests, parity environment, runtime package, and repository-wide development tooling SHALL NOT acquire a Node dependency from this change.

#### Scenario: Workflow and repository are inspected
- **WHEN** the governance integration is reviewed
- **THEN** Node setup and npm installation SHALL occur only before the OpenSpec gate
- **THEN** numerical and parity jobs SHALL remain unchanged

### Requirement: npm installation is integrity checked and script free
CI SHALL use the committed lockfile's integrity metadata and SHALL disable package lifecycle scripts during OpenSpec installation. Cache use MAY improve performance but SHALL NOT replace lock or version verification.

#### Scenario: npm cache supplies package content
- **WHEN** cached content is available
- **THEN** npm SHALL still enforce the committed lock and integrity metadata
- **THEN** the checker SHALL still enforce OpenSpec 1.6.0

#### Scenario: A dependency declares an install script
- **WHEN** `npm ci` processes the locked graph
- **THEN** `--ignore-scripts` SHALL prevent the script from executing
- **THEN** the published OpenSpec CLI SHALL remain runnable from its included distribution
