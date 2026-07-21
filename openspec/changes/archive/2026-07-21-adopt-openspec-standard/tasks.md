## 1. Planning Contract

- [x] 1.1 Refresh the existing adoption branch onto current Nautilus `origin/main` without changing numerical behavior or the Chelis pin.
- [x] 1.2 Update the proposal and design for Nautilus-specific numerical, AD, parity, conformance, and shell-scaffolding boundaries.
- [x] 1.3 Add complete delta specifications for `spec-driven-change-governance` and `nix-openspec-tooling`.
- [x] 1.4 Revalidate the central-action CI design strictly and confirm every apply-required artifact reports complete.

## 2. Locked Tooling

- [x] 2.1 Add a scoped `ci/flake.nix` and transitive lock exposing optional local `openspec` and `openspec-gate` apps on supported systems.
- [x] 2.2 Add a shell-free local launcher that injects Nix-store Python, Git, and OpenSpec executables and defaults to merge-bound self-testing against `origin/main`.
- [x] 2.3 Verify the optional local app reports OpenSpec 1.6.0 and that missing or wrong-version executables fail closed.
- [x] 2.4 Remove Nautilus-owned npm package metadata, lock, and ignored install directory because CI provisioning now lives in `Chelis-Lang/ci`.
- [x] 2.5 Replace local setup-node/npm/checker workflow steps with the immutable central action pointer `8b240a2d0ea55f161e69b44b2ee42733ee197230`.
- [x] 2.6 Run the exact central launcher against the Nautilus worktree and prove it applies the same checker, merge-bound arguments, event base, and OpenSpec 1.6.0 contract as local validation.

## 3. Governance Checker

- [x] 3.1 Port the dependency-free checker for lifecycle discovery, built-in schema enforcement, one-change branch scope, maintenance exemptions, task completion, archive validation, and baseline synchronization replay.
- [x] 3.2 Reject every symbolic link under `openspec/` before validation or archive copying.
- [x] 3.3 Reject any active-lifecycle branch diff that changes `openspec/specs/` before archive synchronization.
- [x] 3.4 Parse task files from raw UTF-8 LF-delimited content so mixed LF/CRLF unchecked and undescribed tasks fail.
- [x] 3.5 Add diagnostic-specific negative controls for symlink artifacts, active pre-sync, mixed-line-ending tasks, malformed names/specs, incomplete work, schema overrides, and synchronization drift.
- [x] 3.6 Run Python compilation and focused positive/negative checker controls.

## 4. Nautilus Integration

- [x] 4.1 Add an unmanaged `OpenSpec Change Governance` section to `AGENTS.md` without editing Chelis-managed blocks.
- [x] 4.2 Record the OpenSpec pilot as a deliberate shell-local scaffolding divergence with a later-cascade decision boundary.
- [x] 4.3 Document significant-change classification, exact maintenance exemptions, apply readiness, numerical evidence authority, emergency handling, and controlled archive sequencing.
- [x] 4.4 Run the central OpenSpec governance action in the existing `hard-rule-guard` after full-history checkout and before numerical jobs.
- [x] 4.5 Preserve existing pin, conformance, oracle-isolation, Chelis-native test, blocked-probe, SciPy parity, permissions, and credential gates unchanged.

## 5. Acceptance

- [x] 5.1 Run the complete checker positive/negative self-test in active mode against `origin/main` before enabling task-complete pre-archive enforcement.
- [x] 5.2 Run `nix flake check ./ci --all-systems` and verify the optional local app surfaces evaluate.
- [x] 5.3 Run the central-action simulation, Nautilus Python automation tests, workflow pin checks, oracle isolation, and action workflow linting.
- [x] 5.4 Run `chelis reef conform audit --explain` and verify the managed agent/skill surfaces remain untouched.
- [x] 5.5 Run `git diff --check` and inspect the final scope against the two capability contracts.
- [x] 5.6 Perform a fresh adversarial review of governance parity, immutable central provenance, private-access non-claims, CI dependency ordering, rollback, and Nautilus-specific authority boundaries; resolve valid findings.

## 6. Archive Readiness

- [x] 6.1 Verify every implementation and acceptance task above is checked only after its command, diff, test, or review evidence has been observed.
- [x] 6.2 Confirm the archive handoff will synchronize both capability deltas exactly once, retain the archived lifecycle, and leave zero active changes.

After every task is complete, the controlled closeout workflow MUST run the local pre-archive gate, synchronize and archive once, and rerun merge-bound governance through the central launcher before requesting fresh approval for the final archive commit. After push, Nautilus's complete hosted suite MUST pass through the exact central pointer before either PR is merged; hosted private access is not claimed by local archive evidence.
