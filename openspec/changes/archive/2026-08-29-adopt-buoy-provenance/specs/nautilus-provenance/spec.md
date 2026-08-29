## ADDED Requirements

### Requirement: NAUT-PROV-001 Pinned Buoy consumption
Nautilus MUST consume Buoy through the published consumer-package path at one exact recorded revision. The repository MUST NOT vendor Buoy sources or follow a floating reference.

#### Scenario: Positive - exact pin resolves offline
- **GIVEN** the recorded Buoy revision and the pinned consumer-package input
- **WHEN** the development environment builds
- **THEN** the provenance commands resolve from the pinned package without network access at check time

#### Scenario: Negative - floating reference is rejected
- **GIVEN** a configuration that references a branch instead of an exact revision
- **WHEN** the pin check runs
- **THEN** the gate fails with a deterministic pin diagnostic

### Requirement: NAUT-PROV-002 Governed module support surface
The Nautilus module support matrix MUST be one governed finite surface. Every module MUST carry exactly one explicit disposition, and deferred rows, including the `Nautilus.Signal` Phase 5f deferral, MUST stay visible with their controlling authority.

#### Scenario: Positive - complete dispositioned surface
- **GIVEN** a surface record that dispositions every Nautilus module
- **WHEN** the static check runs
- **THEN** surface completeness succeeds and deferred rows remain visible

#### Scenario: Negative - module row is omitted
- **GIVEN** a surface record that omits one module
- **WHEN** the static check runs
- **THEN** the check reports the incomplete surface and MUST NOT infer a disposition from implementation presence

### Requirement: NAUT-PROV-003 Records attach to real declarations
Every provenance record MUST attach to a real declaration in a saved `.ch` source. Unattached metadata, unsupported record schema versions, and malformed records MUST produce stable diagnostics and MUST NOT produce an empty successful graph.

#### Scenario: Positive - record on a real declaration
- **GIVEN** a `chelis:provenance/v1` record followed by a top-level declaration
- **WHEN** extraction runs
- **THEN** the record materializes against that declaration with its exact byte span

#### Scenario: Negative - trailing record without a declaration
- **GIVEN** a record block at the end of a file with no following declaration
- **WHEN** extraction runs
- **THEN** the check reports `CHELIS-PROV-UNATTACHED-METADATA`

### Requirement: NAUT-PROV-004 Exact carriers with honest verdicts
Every registered carrier MUST bind an exact declaration, an explicit role, its atom revisions, the real gate oracle, and an exact scope. Verdicts MUST retain actual `not-run`, `pass`, `fail`, `error`, or `timeout` states, and no registration, waiver, or review may synthesize a passing verdict.

#### Scenario: Positive - executed carrier retains its real verdict
- **GIVEN** a registered carrier and one gate execution
- **WHEN** verdicts are recorded from receipts
- **THEN** the carrier reports the exact execution verdict and nothing else

#### Scenario: Negative - unexecuted carrier stays not-run
- **GIVEN** a registered carrier that the gate has not executed
- **WHEN** the advisory report renders
- **THEN** the carrier stays `not-run` and no assurance claim appears for it

### Requirement: NAUT-PROV-005 Deterministic advisory gate lane
The static check and the advisory report MUST run inside the Nautilus gate as an advisory lane with byte-identical canonical output for identical saved inputs. Advisory findings MUST NOT block the gate; extraction failures and malformed records MUST fail loudly.

#### Scenario: Positive - identical bytes across roots
- **GIVEN** identical saved sources under two distinct absolute roots
- **WHEN** the static check runs in both
- **THEN** the canonical report bytes are identical

#### Scenario: Negative - malformed record fails the lane
- **GIVEN** a malformed provenance record in a selected source
- **WHEN** the gate lane runs
- **THEN** the lane fails with the stable malformed-record diagnostic instead of reporting an empty success

### Requirement: NAUT-PROV-006 Execution cannot mutate static identity
Effectful corpus execution MUST consume the static identity as an input and return it unchanged. Canonical reports MUST exclude raw logs, timing, and process details.

#### Scenario: Positive - verdicts change, identity does not
- **GIVEN** one static identity and one corpus execution
- **WHEN** the execution report renders
- **THEN** verdicts update through receipts while the static identity is byte-identical

#### Scenario: Negative - crashed runner is not a pass
- **GIVEN** a gate run that terminates without a valid semantic result
- **WHEN** the verdict is normalized
- **THEN** the carrier records `error` and the lane MUST NOT invent `pass`
