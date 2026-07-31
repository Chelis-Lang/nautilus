# Nautilus — Current Status

Prepared for external review. This document reflects the current
repository state on the published `chelis 0.17.4` release
(Nautilus `0.7.36`).

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
| `Nautilus.Stats` | 24 | runtime-verified |
| `Nautilus.Distance` | 8 | runtime-verified |
| `Nautilus.Roots` | 3 | runtime-verified |
| `Nautilus.Ode` | 6 | runtime-verified |
| `Nautilus.Integrate` | 8 | runtime-verified |
| `Nautilus.Testing` | 13 | runtime-verified |
| `Nautilus.Optim` | 4 | runtime-verified |
| `Nautilus.Interpolation` | 5 | runtime-verified |
| `Nautilus.Sde` | 2 | runtime-verified |
| `Nautilus.CurveFit` | 2 | runtime-verified |
| `Nautilus.Signal` | 7 | 6 typed stubs; `fftfreq` functional |
| `Nautilus.Info` | 3 | runtime-verified |
| `Nautilus.Optimize` | 3 | runtime-verified |
| `Nautilus.StateSpace` | 6 | runtime-verified |
| `Nautilus.TimeSeries` | 7 | runtime-verified |
| `Nautilus.Core` | 1 | metadata helper |

Totals:

- Library surface: 192 exports across all modules: 185 numerical/library
  entries, 1 `Nautilus.Core.version` metadata helper, and 6 NaN-returning
  `Nautilus.Signal` stubs.
- The 463-test native gate exercises every shipped module family through
  identities, invariants, solver recovery, tensor paths, edge cases, and
  callability. The external checked-golden subset covers 45 Special and
  Distributions labels across 216 configurations; it intentionally does not
  duplicate the whole native corpus.
- `Nautilus.Core.version` is package metadata and is not part of the
  numerical harness.
- Six `Nautilus.Signal` transform/filter entries remain stubs under the dated
  [`spec/phase3j.md` deferral](../spec/phase3j.md#explicit-deferrals) pending
  upstream complex-number support; `fftfreq` is a functional real-valued utility.

## Verification Gates

Clean `HEAD` is expected to pass these repo-local gates:

```sh
chelis reef build
chelis test tests/ --jobs auto
chelis test tests/ --jobs 1
uv sync --project parity --frozen
uv run --project parity --frozen python parity/run_parity.py --strict
python3 scripts/check_oracle_isolation.py
python3 scripts/validate_surface.py
python3 scripts/validate_skill_examples.py
python3 scripts/extract_stability.py --check
python3 scripts/validate_book_examples.py
mdbook build docs/book
```

Expected results on a clean run:

```text
chelis test tests/ --jobs auto -> 463 passed, 0 failed
chelis test tests/ --jobs 1    -> 463 passed, 0 failed
parity/run_parity.py           -> parity totals: 216 passed, 0 failed
```

The v0.7.6 node-local test timing record remains archived at
`docs/testing_cutover_0.7.6.json`; it is not the current pin record.

What those gates cover:

- `chelis reef build`: reef packaging and import surface
- `chelis test tests/ --jobs auto`: native identity / structural
  assertions across `tests/*.ch` with node-local parallelism. This is
  the internal-correctness gate.
- `parity/run_parity.py --strict`: validates the Nautilus surface against the
  reviewed SciPy/NumPy corpus under `parity/goldens/`; CI never regenerates it.
- `scripts/check_oracle_isolation.py`: confines external-oracle imports to
  `parity/` and rejects oracle callables in every Chelis source file
- `scripts/validate_surface.py`: cross-checks API-smoke imports, README
  claims, and stability metadata against the source exports
- `scripts/validate_skill_examples.py`: checks full Chelis/Deep examples
  embedded in `SKILL.md`
- `scripts/extract_stability.py --check`: SKILL.md stability tables
  parse cleanly and round-trip to `dist/stability.json`
- `scripts/validate_book_examples.py`: full `chelis` blocks in the
  mdBook, with a minimum-block sanity check
- `mdbook build docs`: rendered docs stay buildable

The former Python numerical harness and its separate golden corpus were retired;
Git history preserves them. The active checked-golden gate under `parity/` is
the sole external correctness oracle.

## Harness Notes

The canonical validation split is:

- `tests/*.ch`: native identity, structural, solver, tensor-path, sampling, and
  edge-case coverage across the full non-stub surface;
- `tests_neg/`: public-contract rejection cases with diagnostic sidecars;
- `tests_blocked/`: current upstream limitations with FIX-DETECTED/DRIFTED
  semantics;
- `parity/run_parity.py`: the reviewed 216-configuration SciPy subset for
  Special and Distributions.

The mdBook validator intentionally checks only full ` ```chelis `
blocks, not illustrative `chelis-fragment` snippets.

## Upstream State

Nautilus is pinned to the published `chelis 0.17.4` release exactly via
`reef.toml`. The official Linux glibc-2.31 asset passed the complete local
acceptance gate on 2026-07-31. Historical
compiler/runtime bugs discovered during Nautilus P0-P3 and current narrowed
limitations are documented in `docs/UPSTREAM_BUGS.md`.

For the pinned toolchain:

- The shipped finite-difference `lm_scalar_nparam` surface remains
  runtime-verified. The positive native gate is `463 / 463`, strict parity is
  `216 / 216`, and two shapes of the current AD replacement blocker are
  executable under `tests_blocked/curvefit/`.
- Tensor-wrt and capture-free multi-argument grad now evaluate and C-build.
  Chelis 0.17.4 retains the fix for the former generic `n`/`m` checker collapse
  (chelis#847). The exact permanent Jacobian path remains blocked at one
  malformed backward-DAG layer (chelis#676), reproduced by both generic and
  concrete arbitrary vector-model wrappers.
- Package-aware `eval --file` calls used by parity pass. The historical hang is
  fixed; the import-only startup benchmark instead exposes a tracked symbolic-
  input residue and no longer uses a 5-second timeout.
- The release gate uses the compiler-owned canonical artifact verifier,
  adversarially requires archive-mutation and CHB-trailing-byte rejection, and
  requires two unchanged builds to produce byte-identical archive and CHB
  payloads. The downloaded official v0.17.4 asset passed these checks,
  completing the chelis#970 and chelis#972 de-narrowing milestone.
- The old `redundant-linearity-call` false positive is fixed. The 131 copies it
  now identifies in `src/linalg.ch` were removed with a green package build;
  11 semantically required copies remain.

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
- `lm_scalar_nparam` uses a finite-difference Jacobian (`eps=1e-5`) while
  `chelis#676` blocks the exact AD replacement for both generic and concrete
  arbitrary vector-model wrappers. Scale
  parameters and outputs to O(1) to avoid f32 cancellation in
  finite-difference columns.
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
- `Signal` retains six stubs under the dated
  [`spec/phase3j.md` deferral](../spec/phase3j.md#explicit-deferrals);
  `fftfreq` is the functional real-valued utility that ships today.
- `airy_ai` does not yet have a dedicated large-negative-x asymptotic
  branch.

## Recent Review Outcome

The most recent repo sweep (2026-07-14, against `chelis 0.16.1`) refreshed
the release and conformance surface to the current pin state:

- docs/spec text now reflects the 192-export library surface (185
  numerical/library + 1 metadata helper + 6 Signal stubs), the accepted
  pure-Chelis Phase 3j architecture, the 216/216 reviewed scipy-parity subset,
  and the native `chelis test tests/` harness as the internal-correctness gate.
- README, mdBook, and SKILL.md list the v0.4.0 additions (`erfc`,
  unary `gamma`).
- `docs/UPSTREAM_BUGS.md` carries the contract sections and preserves older
  validation records as historical evidence.
- the ODE docs continue to document the shipped adaptive RK45
  endpoint solver
- the mdBook example validator enforces a minimum number of full
  compile-checked examples
- the duplicate legacy numerical harness was retired; native tests and the
  single checked-golden parity project are the only correctness gates
