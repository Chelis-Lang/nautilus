# Nautilus — Current Status

Prepared for external review. This document reflects the current
repository state on the pinned `chelis v0.1.7` toolchain.

## Scope

Nautilus is a downstream reef package for Chelis, focused on numerical
methods, statistics, and optimization. The implementation is pure
Chelis throughout: no C FFI, no vendored runtime extensions, and no
hand-written adjoints.

## Module Surface

| Module | Exports | Runtime status |
|---|---|---|
| `Nautilus.Special` | 19 | runtime-verified |
| `Nautilus.Distributions` | 38 | runtime-verified except 3 heavy sampling variants |
| `Nautilus.LinAlg` | 26 | runtime-verified |
| `Nautilus.Stats` | 14 | runtime-verified |
| `Nautilus.Distance` | 8 | runtime-verified |
| `Nautilus.Roots` | 3 | runtime-verified |
| `Nautilus.ODE` | 5 | runtime-verified |
| `Nautilus.Integrate` | 8 | runtime-verified |
| `Nautilus.Testing` | 13 | runtime-verified |
| `Nautilus.Optim` | 4 | runtime-verified |
| `Nautilus.Interpolation` | 3 | runtime-verified |
| `Nautilus.SDE` | 2 | runtime-verified |
| `Nautilus.CurveFit` | 1 | runtime-verified |
| `Nautilus.Signal` | 7 | typed stubs only |
| `Nautilus.Core` | 1 | metadata helper |

Totals:

- 145 non-stub exports overall.
- 144 numerical/library exports are covered by the runtime harness.
- `Nautilus.Core.version` is package metadata and is not part of the
  numerical harness.
- `Nautilus.Signal` remains a stub surface pending upstream complex
  number support.

## Verification Gates

Clean `HEAD` is expected to pass these repo-local gates:

```sh
chelis reef build
python tests/run_static_checks.py
python scripts/gen_goldens.py --check
CHELIS_BIN=chelis python tests/run_numeric_tests.py
CHELIS_BIN=chelis python tests/run_skill_checks.py
CHELIS_BIN=chelis python scripts/validate_book_examples.py
mdbook build docs
```

Expected runtime-harness result:

```text
895 / 895 numerical assertions passed
```

What those gates cover:

- `chelis reef build`: reef packaging and import surface
- `tests/run_static_checks.py`: export/import consistency
- `scripts/gen_goldens.py --check`: checked-in scipy/numpy fixtures
- `tests/run_numeric_tests.py`: scalar, solver, tensor-path, sampling,
  and negative-matrix runtime parity
- `tests/run_skill_checks.py`: full `chelis` examples in `SKILL.md`
- `scripts/validate_book_examples.py`: full `chelis` blocks in the
  mdBook, with a minimum-block sanity check
- `mdbook build docs`: rendered docs stay buildable

## Harness Notes

The numerical harness now covers:

- scalar special functions and distributions
- solver modules (`Roots`, `ODE`, `Integrate`, `Testing`, `Optim`)
- tensor-path `LinAlg`, `Stats`, `Distance`, `SDE`, `Interpolation`,
  and `CurveFit`
- deterministic sampling checks for `uniform_sample`,
  `normal_sample`, `exponential_sample`, and `lognormal_sample`
- negative matrix cases for singular `solve_2x2` / `solve_3x3` and
  non-PSD `cholesky_2x2`

The mdBook validator intentionally checks only full ` ```chelis `
blocks, not illustrative `chelis-fragment` snippets.

## Upstream State

Nautilus is pinned to `chelis v0.1.7` exactly via `reef.toml`.
Historical compiler/runtime bugs discovered during Nautilus P0-P3 are
documented in `docs/UPSTREAM_BUGS.md`.

For the pinned toolchain:

- the originally tracked Bugs 1-5 are fixed through `v0.1.7`
- the currently shipped Nautilus surface is fully wired into the current
  harness and no longer upstream-blocked

For later upstream releases:

- validation against `v0.1.9` through `v0.1.13` found two new blockers
  for future Nautilus scope: tensor-valued `grad` on the native path,
  and generic fold/control-flow lowering on tensor accumulators
- those blockers affect next-up work such as richer LM and general-n
  Cholesky, not the currently shipped Nautilus surface

## Known Limitations

- Nautilus is `f32` only. Precision is generally in the 6-7 significant
  digit range.
- Chelis still lacks scalar builtins such as `cos`, `tan`, `atan`,
  `abs`, `floor`, and `ceil`; users must express them from existing
  primitives.
- General-n SVD, LU, QR, and eigendecomposition are not yet available.
  Nautilus ships fixed-size closed-form helpers plus general-n
  `cg_solve` for SPD systems.
- `rk45_adaptive_solve` provides adaptive endpoint integration, but the
  ODE surface still returns only the final state rather than a saved
  trajectory.
- `newton_minimize_1d` can reject very flat true minima because of its
  curvature floor.
- `Signal` is still mostly a stub API; `fftfreq` is the only
  real-valued utility that ships today.
- `airy_ai` does not yet have a dedicated large-negative-x asymptotic
  branch.

## Recent Review Outcome

The latest repo sweep closed the remaining documentation and harness
drift:

- docs/spec text now reflects the current 145-export surface and
  895-assertion harness
- the ODE docs now include the shipped adaptive RK45 endpoint solver
- the mdBook example validator enforces a minimum number of full
  compile-checked examples
- the runtime harness includes adversarial negative-matrix cases that
  exercise the NaN-failure paths
