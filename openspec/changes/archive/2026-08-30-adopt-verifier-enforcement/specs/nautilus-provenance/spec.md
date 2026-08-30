## ADDED Requirements

### Requirement: NAUT-PROV-008 Enforced bindings with sanctioned regeneration
The gate oracle MUST declare `runner-config-paths` for every runner configuration artifact reachable inside a selector root, so the recorded runner digests verify against saved bytes on every static check. The gate lane MUST block when the `rebind` dry run reports a nonempty plan and when the `trace` smoke over a bound atom rejects. Regeneration of record-carried digests MUST go through `rebind`: review the dry-run field diff, apply with `--write`, re-execute the corpus, and commit. No out-of-band digest computation may exist in the workflow.

#### Scenario: Positive - runner drift is caught and rebound
- **GIVEN** a toolchain bump that changes the saved runner configuration bytes
- **WHEN** the static check runs
- **THEN** the check reports `CHELIS-PROV-ORACLE-RUNNER-STALE` with bound and current values, and `rebind --write` followed by corpus re-execution restores acceptance

#### Scenario: Positive - gate lane proves bindings current
- **GIVEN** the committed tree
- **WHEN** the gate lane runs
- **THEN** the `rebind` dry run reports an empty plan and the `trace` smoke over `NAUT-MOD-LINALG` accepts with every hop recomputed

#### Scenario: Negative - stale plan blocks the lane
- **GIVEN** a record whose bound digest no longer matches the current saved bytes
- **WHEN** the gate lane runs
- **THEN** the lane fails loudly, printing each stale field with its bound and current values and the sanctioned rebind instruction
