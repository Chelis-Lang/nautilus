# Nautilus — Current Status

Prepared for external review. This document reflects the current
repository state on the validated `chelis 0.11.1` toolchain
(Nautilus `0.7.30`).

## Scope

Nautilus is a downstream reef package for Chelis, focused on numerical
methods, statistics, and optimization. The implementation is pure
Chelis throughout: no C FFI, no vendored runtime extensions, and no
hand-written adjoints.

## Module Surface

| Module | Exports | Runtime status |
|---|---|---|
| `Nautilus.Special` | 21 | runtime-verified |
| `Nautilus.Distributions` | 38 | runtime-verified except 3 heavy sampling variants |
| `Nautilus.LinAlg` | 31 | runtime-verified |
| `Nautilus.Stats` | 14 | runtime-verified |
| `Nautilus.Distance` | 8 | runtime-verified |
| `Nautilus.Roots` | 3 | runtime-verified |
| `Nautilus.Ode` | 6 | runtime-verified |
| `Nautilus.Integrate` | 8 | runtime-verified |
| `Nautilus.Testing` | 13 | runtime-verified |
| `Nautilus.Optim` | 4 | runtime-verified |
| `Nautilus.Interpolation` | 5 | runtime-verified |
| `Nautilus.Sde` | 2 | runtime-verified |
| `Nautilus.CurveFit` | 2 | runtime-verified |
| `Nautilus.Signal` | 7 | typed stubs only |
| `Nautilus.Core` | 1 | metadata helper |

Totals:

- Library surface: 163 total exports across all modules. Minus 7
  `Nautilus.Signal` stubs = 156 non-stub exports. Of those, 155 are
  numerical/library entries and 1 is the `Nautilus.Core.version`
  metadata helper.
- All 155 numerical/library exports are covered by the native Chelis
  test gate (`chelis test tests/`) and by `parity/run_parity.py`.
- `Nautilus.Core.version` is package metadata and is not part of the
  numerical harness.
- `Nautilus.Signal` remains a stub surface pending upstream complex
  number support.

## Verification Gates

Clean `HEAD` is expected to pass these repo-local gates:

```sh
chelis reef build
chelis test tests/ --jobs auto
chelis test tests/ --jobs 1
python parity/run_parity.py --strict
python scripts/gen_goldens.py --check
python scripts/extract_stability.py --check
python scripts/validate_book_examples.py
mdbook build docs
```

Expected results on a clean run:

```text
chelis test tests/ --jobs auto -> 459 passed, 0 failed
chelis test tests/ --jobs 1    -> 459 passed, 0 failed
parity/run_parity.py           -> parity totals: 216 passed, 0 failed
```

The v0.7.6 node-local test timing record remains archived at
`docs/testing_cutover_0.7.6.json`; it is not the current pin record.

What those gates cover:

- `chelis reef build`: reef packaging and import surface
- `chelis test tests/ --jobs auto`: native identity / structural
  assertions across `tests/*.ch` with node-local parallelism. This is
  the internal-correctness gate.
- `parity/run_parity.py --strict`: scipy/numpy oracle for the
  Nautilus surface (special functions and distributions). External
  drift detector.
- `scripts/gen_goldens.py --check`: checked-in scipy/numpy fixtures
  for the legacy harness still match scipy
- `scripts/extract_stability.py --check`: SKILL.md stability tables
  parse cleanly and round-trip to `dist/stability.json`
- `scripts/validate_book_examples.py`: full `chelis` blocks in the
  mdBook, with a minimum-block sanity check
- `mdbook build docs`: rendered docs stay buildable

The legacy Python harness (`tests_legacy/run_numeric_tests.py`) still
runs in the scheduled `nightly.yml` workflow as a dual-run safety net;
it is not part of the PR gate.

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

Nautilus is pinned to `chelis 0.11.1` exactly via `reef.toml`. Historical
compiler/runtime bugs discovered during Nautilus P0-P3 are documented in
`docs/upstream-bugs.md`.

For the pinned toolchain:

- The shipped Nautilus surface is no longer upstream-blocked. The
  native `chelis test tests/` gate runs `459 / 459` clean on
  `chelis 0.11.1`, and `parity/run_parity.py --strict` is `216 / 216`
  against scipy.
- The post-`v0.1.21` toolchain bumps (`v0.2.x` → `0.9.0`) were
  consumed as maintenance / pin-tracking releases. None changed the
  Nautilus blocker set materially.
- Tensor-valued `grad` at the C-backend lowering level was last
  verified blocked on `v0.1.21` and has not been re-probed against
  `0.9.0`. Multi-parameter Levenberg-Marquardt (`lm_scalar_nparam`)
  ships using a finite-difference Jacobian as a workaround.

### Historical upstream blocker analysis through v0.1.21

The summary below is preserved as historical context for the
post-`v0.1.7` blocker work. It is not a fresh restatement of the
`0.9.0` state; for that, see the section above.

For the v0.1.21 toolchain (the last pin against which the historical
analysis was captured):

- the originally tracked Bugs 1-5 remained fixed
- Bugs 6 and 7 (recursive inliner NULL-shadow and increment-propagation
  defects discovered during `lm_scalar_nparam` development) were both
  **fixed in v0.1.21** — `lm_scalar_nparam` uses the cleaner recursive
  Jacobian formulation on v0.1.21
- the shipped Nautilus surface ran the legacy `1051 / 1051` numerical
  assertions on `v0.1.21`, including the general-`n` Cholesky, LU, QR,
  SVD, and multi-parameter LM paths

On upstream releases through `v0.1.21`:

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
  `grad` blocker at the C-backend lowering level persists through
  `v0.1.21`: `grad(expr, wrt = var)` still fails `chelis build`.
  `lm_scalar_nparam` ships in v0.2.0 using a finite-difference Jacobian
  as a workaround; a grad-based Jacobian remains blocked.
- those blockers affect next-up work such as gradient-based Jacobian LM,
  not the currently shipped Nautilus surface

## Known Limitations

- Nautilus is `f32` only. Precision is generally in the 6-7 significant
  digit range.
- `lu_solve`, `qr_decompose`, `svd_n`, and `eig_n` are `alpha` stability and
  square-only.  `lu_solve` requires non-zero leading principal submatrices (no
  partial pivoting).  `svd_n` and `eig_n` use a fixed 30n classical Jacobi
  sweeps with no convergence early-exit; nearly-equal singular/eigen values may
  require more sweeps on pathological inputs.  `eig_n` assumes symmetric input;
  results for non-symmetric matrices are undefined (no crash, but eigenvector
  equation may not hold).  OMP nested-parallelism deadlock: callers must set
  `OMP_NUM_THREADS=1` when invoking the compiled binary directly; the test
  harness sets this automatically.
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

The most recent repo sweep (2026-06-25, against `chelis 0.11.1`) refreshed
the release and documentation surface to the current pin state:

- docs/spec text now reflects the 163-export library surface (155
  numerical/library + 1 metadata helper + 7 Signal stubs), the
  216/216 scipy-parity gate, and the native `chelis test tests/`
  harness as the internal-correctness gate.
- README, mdBook, and SKILL.md list the v0.4.0 additions (`erfc`,
  unary `gamma`).
- `docs/upstream-bugs.md` carries an explicit `v0.9.0 validation`
  block at the top so the historical body below is unambiguously
  archival.
- the ODE docs continue to document the shipped adaptive RK45
  endpoint solver
- the mdBook example validator enforces a minimum number of full
  compile-checked examples
- the legacy harness in `tests_legacy/` includes adversarial
  negative-matrix cases that exercise the NaN-failure paths and
  still runs nightly as a dual-run safety net
