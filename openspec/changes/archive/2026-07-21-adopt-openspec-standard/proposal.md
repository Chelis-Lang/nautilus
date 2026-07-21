## Why

Nautilus changes combine numerical API semantics, supported domains, tolerances, AD behavior, external parity evidence, compiler compatibility, and downstream shell impact. The repository has strong technical specifications and executable gates, but it lacks one governed lifecycle connecting proposed intent to scenarios, implementation evidence, synchronized requirements, and archival.

The governance gate itself must use a reproducible OpenSpec 1.6.0 executable. A scoped Nix flake can supply that tool without adding a Node/npm bootstrap or changing Nautilus's Chelis development environment.

## What Changes

- Establish OpenSpec as the required planning and requirements workflow for significant Nautilus changes.
- Require each non-empty branch diff to add exactly one governed lifecycle or one exact-path maintenance exemption.
- Require significant changes to be apply-ready and strictly valid before implementation, with a bounded incident exception.
- Preserve Nautilus's numerical specifications, SciPy parity suite, negative tests, shell-conformance checks, and owning acceptance oracles as implementation authority.
- Require complete tasks, immutable non-symlink lifecycle artifacts, unsynchronized active baselines, synchronized archive output, and strict post-archive validation.
- Add a scoped `ci/` flake locking OpenSpec 1.6.0 and expose `openspec` plus `openspec-gate` apps.
- Run the same `nix run ./ci#openspec-gate` command locally and in GitHub Actions.
- Record this initial Nautilus pilot as an explicit shell-scaffolding divergence rather than silently changing sibling shell structure.

## Capabilities

### New Capabilities

- `spec-driven-change-governance`: Classification, artifact ordering, one-change branch isolation, numerical evidence traceability, task completion, immutable lifecycle evidence, synchronization, and archival rules.
- `nix-openspec-tooling`: Reproducible OpenSpec 1.6.0 provisioning and one local/CI governance command surface.

### Modified Capabilities

None.

## Impact

- Adds `openspec/`, a dependency-free governance checker, and a scoped `ci/` Nix flake.
- Adds one pinned Nix installer step and governance gate to the existing CI guard chain.
- Adds an unmanaged OpenSpec section and a recorded pilot divergence to `AGENTS.md` without editing Chelis-managed blocks.
- Does not change numerical APIs, algorithms, tolerances, AD semantics, the exact Chelis pin, parity goldens, or downstream runtime behavior.
