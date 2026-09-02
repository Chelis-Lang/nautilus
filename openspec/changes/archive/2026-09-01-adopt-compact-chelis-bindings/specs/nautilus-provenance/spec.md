## ADDED Requirements

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
