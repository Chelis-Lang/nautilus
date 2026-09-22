# Chelis 0.18.11 Migration

Nautilus 0.7.46 pins Chelis 0.18.11 and refreshes every conform-managed
surface with an explicit `chelis reef conform sync --path .` after the bump.

## Required source changes

- Migrated maintained Surf sources and fixtures from the retired
  `int8`/`int16`/`int32`/`int64` spellings to canonical
  `i8`/`i16`/`i32`/`i64`.
- Renamed the exported distribution helper `cross_entropy` to
  `distribution_cross_entropy`; the old name now collides with a standard
  prelude macro.
- Updated the unsupported-element negative contract to the canonical `i64`
  diagnostic.

## Re-probes and de-narrowing

Four 0.18.10 blocked probes now pass and are ordinary regression tests:

- the generic and concrete CurveFit Jacobian-row witnesses from chelis#676;
- the scalar generic-cast witness from chelis#2151; and
- the untaken masked-select arithmetic witness associated with chelis#1464.

The repaired masked-select behavior permits removal of the scalar and tensor
`erf` series clamps. The wider exact-AD replacement for the complete
Levenberg-Marquardt implementation is not ready: composing the now-working
Jacobian helper exposes the distinct runtime-extent binder-provenance failure
tracked by chelis#2370 under chelis#1277. Nautilus therefore retains its
finite-difference Jacobian for that full path.

The imported-generic C-lowering matrix in chelis#2152 remains manual because it
cannot be exercised by the blocked-test lane. On the official release, the
original direct scalar-cast shape now emits C, while the smaller remaining
function-parameter-plus-cast shape still rejects during downstream C lowering.

## Validation

The release receipt records the official Darwin arm64 asset and payload hashes
in `docs/CHELIS_SURFACE.md`. The required gate is formatting of all maintained
Surf, lint, `chelis reef build`, the complete positive and negative suites,
strict SciPy parity, `chelis reef conform audit --explain`, and
`chelis reef conform bump-check --base origin/main`.
