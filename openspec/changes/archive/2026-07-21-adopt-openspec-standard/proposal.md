## Why

Nautilus changes combine numerical API semantics, supported domains, tolerances, AD behavior, external parity evidence, compiler compatibility, and downstream shell impact. The repository has strong technical specifications and executable gates, but it lacks one governed lifecycle connecting proposed intent to scenarios, implementation evidence, synchronized requirements, and archival.

The governance gate itself must use a reproducible OpenSpec 1.6.0 executable. A scoped Nix flake can supply optional local tooling without changing Nautilus's Chelis development environment, while CI can delegate shared Node/npm provisioning and event-base launch mechanics to an immutable `Chelis-Lang/ci` action without moving Nautilus policy out of this repository.

## What Changes

- Establish OpenSpec as the required planning and requirements workflow for significant Nautilus changes.
- Require each non-empty branch diff to add exactly one governed lifecycle or one exact-path maintenance exemption.
- Require significant changes to be apply-ready and strictly valid before implementation, with a bounded incident exception.
- Preserve Nautilus's numerical specifications, SciPy parity suite, negative tests, shell-conformance checks, and owning acceptance oracles as implementation authority.
- Require complete tasks, immutable non-symlink lifecycle artifacts, unsynchronized active baselines, synchronized archive output, and strict post-archive validation.
- Add a scoped `ci/` flake locking OpenSpec 1.6.0 and expose optional local `openspec` plus `openspec-gate` apps.
- Pin the GitHub Actions gate to reviewed central action commit `8b240a2d0ea55f161e69b44b2ee42733ee197230`, which owns exact OpenSpec 1.6.0 npm provisioning and bounded event-base launch mechanics.
- Keep `scripts/check_openspec.py`, lifecycle artifacts, workflow ordering, and numerical evidence authority in Nautilus while running the same checker controls locally and in CI.
- Record this initial Nautilus pilot as an explicit shell-scaffolding divergence rather than silently changing sibling shell structure.

## Capabilities

### New Capabilities

- `spec-driven-change-governance`: Classification, artifact ordering, one-change branch isolation, numerical evidence traceability, task completion, immutable lifecycle evidence, synchronization, and archival rules.
- `nix-openspec-tooling`: Reproducible OpenSpec 1.6.0 provisioning through optional local Nix apps and an immutable pointer to centralized CI execution mechanics.

### Modified Capabilities

None.

## Impact

- Adds `openspec/`, a dependency-free governance checker, and optional scoped `ci/` Nix apps.
- Adds one immutable `Chelis-Lang/ci/actions/openspec-governance` pointer to the existing CI guard chain; Node setup and npm lock ownership remain central, with no Nix dependency in CI.
- Adds an unmanaged OpenSpec section and a recorded pilot divergence to `AGENTS.md` without editing Chelis-managed blocks.
- Does not change numerical APIs, algorithms, tolerances, AD semantics, the exact Chelis pin, parity goldens, or downstream runtime behavior.
