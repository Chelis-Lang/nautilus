## 1. Pin and wire Buoy consumption

- [x] 1.1 Record the exact Buoy revision `f41fd501`, the consumer-package contract path, and the Chelis 0.18.1 version-skew boundary in a repository-owned pin record.
- [x] 1.2 Add the pinned Buoy consumer-package input to `devenv.nix` and verify that the `chelis-provenance` command resolves offline; if the package does not expose it, record the pinned source-build fallback and open the upstream package-contract follow-up.
- [x] 1.3 Add a pin check that rejects floating references and validates the recorded revision against the resolved input.

## 2. Freeze configuration and fixtures

- [x] 2.1 Freeze the `chelis-adapter-config/v1` configuration with selectors for `src/`, `tests/`, and `tests_neg/`, and reject selector overlap.
- [x] 2.2 Add positive and negative record fixtures for every NAUT-PROV requirement, including an omitted surface row, an unattached record, an unsupported schema version, and a malformed record.
- [x] 2.3 Freeze one golden canonical static report and one golden advisory report for the fixture repository, with the delete-rerun-review regeneration policy.

## 3. Atomize the support surface

- [x] 3.1 Add authority records for the module support claims, each attached to the governed module's top-level declaration with an exact normative statement.
- [x] 3.2 Add the surface record that dispositions every `Nautilus.*` module exactly once, with `deferred` rows for the `Nautilus.Signal` Phase 5f stubs bound to their controlling authority.
- [x] 3.3 Run the static check and confirm surface completeness; confirm the omitted-row fixture still rejects.

## 4. Attach links, carriers, and the oracle

- [x] 4.1 Declare the gate oracle record with the exact Nautilus gate command, runner identity, and scope.
- [x] 4.2 Attach implementation-link records to the first-tranche module declarations, each bound to its authority atom revisions.
- [x] 4.3 Attach carrier records to the Chelis-native test corpus with role `positive` and to `tests_neg/` with role `negative`, each with exact atoms, oracle, and scope; every carrier starts `not-run`.

## 5. Gate lane and validation

- [x] 5.1 Add the advisory gate lane: `chelis-provenance static` plus the advisory report; malformed and unattached records fail the lane, coverage gaps stay advisory.
- [x] 5.2 Add a cross-root determinism check that asserts byte-identical canonical report output from two distinct absolute roots.
- [x] 5.3 Execute the corpus once through `chelis-provenance execute` with the gate oracle; record real verdicts through receipts and confirm the static identity is unchanged.
- [x] 5.4 Document the trust boundaries: advisory-only policy, honest verdict states, the README table as a visible untracked copy, and the rollback path.
- [x] 5.5 Run the full Nautilus gate as the final oracle and require the blocking lanes green while the advisory report stays visible.
