# Nautilus — Current Status

Prepared for external review. This document reflects the current
repository state on the validated `chelis v0.1.20` toolchain.

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
| `Nautilus.LinAlg` | 30 | runtime-verified |
| `Nautilus.Stats` | 14 | runtime-verified |
| `Nautilus.Distance` | 8 | runtime-verified |
| `Nautilus.Roots` | 3 | runtime-verified |
| `Nautilus.ODE` | 5 | runtime-verified |
| `Nautilus.Integrate` | 8 | runtime-verified |
| `Nautilus.Testing` | 13 | runtime-verified |
| `Nautilus.Optim` | 4 | runtime-verified |
| `Nautilus.Interpolation` | 3 | runtime-verified |
| `Nautilus.SDE` | 2 | runtime-verified |
| `Nautilus.CurveFit` | 2 | runtime-verified |
| `Nautilus.Signal` | 7 | typed stubs only |
| `Nautilus.Core` | 1 | metadata helper |

Totals:

- 150 non-stub exports overall (156 total across all modules, minus 7 Signal stubs = 149 numerical/library, plus 1 Core metadata helper = 150).
- 149 numerical/library exports are covered by the runtime harness.
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
1051 / 1051 numerical assertions passed
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

Nautilus is pinned to `chelis v0.1.20` exactly via `reef.toml`.
Historical compiler/runtime bugs discovered during Nautilus P0-P3 are
documented in `docs/UPSTREAM_BUGS.md`.

For the pinned toolchain:

- the originally tracked Bugs 1-5 remain fixed through `v0.1.20`
- the currently shipped Nautilus surface is fully wired into the current
  harness and no longer upstream-blocked
  (`1051 / 1051` numerical assertions on `v0.1.20`, including the new
  general-`n` Cholesky, LU, QR, SVD, and multi-parameter LM paths)

On newer upstream releases through `v0.1.20`:

- validation against `v0.1.9` through `v0.1.20` found two blockers for
  future Nautilus scope: tensor-valued `grad` on the native path, and
  tensor-valued `if` inside fold bodies
- the generic fold / control-flow blocker is **fully cleared in
  `v0.1.18`** — both sub-(a) (tuple fold with tensor in slot 0) and
  sub-(b) (tensor-valued `if` inside fold body) now lower correctly and
  run correctly at runtime; general-`n` Cholesky is now unblocked at
  the compiler-support level
- `v0.1.20` ships a new `grad(expr, wrt = var)` expression syntax that
  returns `(value, gradient)` tuples and type-checks at score 1.0; it
  also changes multi-arg HOF call syntax so `(A, B) -> C` functions now
  require tuple call `model((a, b))` (curried `A -> B -> C` forms are
  unaffected, and all Nautilus HOF uses are curried). The tensor-valued
  `grad` blocker at the C-backend lowering level persists: `grad(expr,
  wrt = var)` still fails `chelis build`, and the `grad(local,
  wrt=(arg))(arg)` workaround emits a placeholder that drops the
  gradient at runtime. `lm_scalar_nparam` ships in v0.2.0 using a
  finite-difference Jacobian as a workaround; a grad-based Jacobian
  remains blocked.
- those blockers affect next-up work such as gradient-based Jacobian LM,
  not the currently shipped Nautilus surface

## Known Limitations

- Nautilus is `f32` only. Precision is generally in the 6-7 significant
  digit range.
- `lu_solve`, `qr_decompose`, and `svd_n` are `alpha` stability and square-only.
  `lu_solve` requires non-zero leading principal submatrices (no partial pivoting).
  `svd_n` uses a fixed 30n Jacobi sweeps — nearly-equal singular values may not
  fully converge. General-n eigendecomposition beyond `eig_2x2_real` is not yet available.
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

- docs/spec text now reflects the current 150-export surface and
  1051-assertion harness
- the ODE docs now include the shipped adaptive RK45 endpoint solver
- the mdBook example validator enforces a minimum number of full
  compile-checked examples
- the runtime harness includes adversarial negative-matrix cases that
  exercise the NaN-failure paths
