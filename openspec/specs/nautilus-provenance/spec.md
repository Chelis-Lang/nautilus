# nautilus-provenance Specification

## Purpose

Repository-owned provenance governance for the Nautilus module support surface over the pinned Buoy interfaces: exact pinned tooling, a complete governed surface, records on real Chelis declarations, honest carrier verdicts, and a deterministic advisory gate lane.
## Requirements
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
Every provenance record MUST attach to a real top-level declaration node parsed by the pinned Buoy adapter's vendored Chelis Surf grammar. Every bound item digest MUST derive from the parsed declaration node's exact bytes under `chelis-surf-syntax/v2`. Unattached metadata, unsupported record schema versions, malformed records, and sources the grammar rejects MUST produce stable diagnostics and MUST NOT produce an empty successful graph.

#### Scenario: Positive - record on a parsed declaration
- **GIVEN** a `chelis:provenance/v1` record followed by a top-level declaration
- **WHEN** extraction runs
- **THEN** the record materializes against the parsed declaration node with its exact node byte span and node-derived item identity

#### Scenario: Negative - trailing record without a declaration
- **GIVEN** a record block at the end of a file with no following declaration
- **WHEN** extraction runs
- **THEN** the check reports `CHELIS-PROV-UNATTACHED-METADATA`

#### Scenario: Negative - source the grammar rejects
- **GIVEN** a selected `.ch` source the pinned grammar cannot parse
- **WHEN** the static check runs
- **THEN** the check reports `CHELIS-PROV-PARSE-ERROR` with the static exit class and MUST NOT emit an empty successful graph

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

### Requirement: NAUT-PROV-007 Report-derived bindings without helper builds
Atom revisions and object identity digests that Nautilus records bind MUST derive from the pinned command's revision-bearing static report. The repository MUST NOT require an out-of-band helper build to compute revision bindings, and the `chelis-provenance` command MUST come from the upstream consumer package.

#### Scenario: Positive - revisions from the canonical report
- **GIVEN** the pinned `nautilus-provenance static` report
- **WHEN** a maintainer rebinds a surface row, link, or carrier
- **THEN** the required atom revision digests are present in the report bytes

#### Scenario: Negative - fallback package builds are retired
- **GIVEN** the repository's Nix expressions
- **WHEN** the pin check runs
- **THEN** no local fallback derivation builds the `chelis-provenance` command and the binary comes from the upstream consumer package

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

### Requirement: NAUT-PROV-009 Compact content-addressed implementation bindings
Nautilus MUST select BLAKE3-256 for the complete provenance graph.
It MUST store each governed implementation relation as a compact Chelis binding.
The configured binding store MUST lie under one selector root.
The governed links are:

- `NAUT-LINK-LINALG-MATMUL`
- `NAUT-LINK-SIGNAL-STUBS`
- `NAUT-LINK-STATS-HELPERS`

Each governed link MUST resolve through an immutable `buoy/implementation-binding/v1` object.
Conversion and regeneration MUST use reviewed `bind` and `rebind` plans and MUST preserve attached declaration bytes.
Receipt re-execution MUST follow the final static identity change and MUST save the exact static report beside the receipt.

#### Scenario: Positive - all governed links resolve from the store
- **GIVEN** the committed Nautilus sources and content-addressed objects
- **WHEN** the static check and trace command run
- **THEN** all three relations resolve with current requirement, atom-revision, subject, and object-address hops

#### Scenario: Positive - reviewed conversion preserves declarations
- **GIVEN** one current inline implementation link
- **WHEN** its `bind` dry run is reviewed and its write runs
- **THEN** only the record block and object store change while the attached declaration stays byte-identical

#### Scenario: Negative - changed object bytes reject
- **GIVEN** one committed object whose bytes no longer match its source address
- **WHEN** the static check runs
- **THEN** the gate reports `CHELIS-PROV-BINDING-ADDRESS` and materializes no relation from those bytes

#### Scenario: Negative - stale declaration rejects
- **GIVEN** a declaration that changes after compact conversion
- **WHEN** the static check runs
- **THEN** the gate reports `CHELIS-PROV-BINDING-SUBJECT-STALE` with bound and current values

#### Scenario: Negative - stale receipt identity rejects
- **GIVEN** an execution receipt whose saved static report differs from the current static report
- **WHEN** the gate runs
- **THEN** the gate rejects the receipt and requests corpus execution

#### Scenario: Negative - weak digest member cannot resolve compact objects
- **GIVEN** a configuration that selects `xxh3-128` for the compact-binding graph
- **WHEN** the static check runs
- **THEN** the gate reports `CHELIS-PROV-BINDING-ADDRESS` with `algorithm-not-collision-resistant`

