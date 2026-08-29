## MODIFIED Requirements

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

## ADDED Requirements

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
