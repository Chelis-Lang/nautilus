# Nautilus scope and acceptance

This document defines what Nautilus is for, how it is built, what counts as
acceptance for new surface, and what is deliberately out of scope. The
function-level API inventory, with a stability label on every export, lives in
[`SKILL.md`](../SKILL.md) §6. This document covers architecture and acceptance
and does not repeat that list.

## Intent

Nautilus is a Reef package for the [Chelis](https://github.com/Chelis-Lang/chelis)
language that fills the space between Chelis's raw tensor primitives and domain
applications: special functions, probability distributions, statistics and
hypothesis testing, linear algebra, root finding and optimization, quadrature,
ODE and SDE integration, interpolation, curve fitting, state-space and
time-series models, and rolling-window and lag transforms. Everything lives under the `Nautilus` module prefix. A
Chelis program that needs one of these routines should be able to import it
rather than re-derive it.

## Architecture

- **Pure Chelis.** Nautilus has no C or Rust FFI, no compiler special-casing,
  and no LAPACK or nalgebra backend. Scalar routines, tensor algorithms,
  decompositions, and iterative solvers are built from Chelis primitives,
  collections, recursion, and folds.
- **Precision.** `Nautilus.Special` uses the `{f32, f64}` dtype set,
  so each function can be instantiated at `f32` or `f64` and rejects `f16` and
  `bf16` at checking. A wider type does not
  imply wider accuracy: the per-function error table in the book's precision
  appendix is authoritative. `Nautilus.Rolling` is concrete `f64` over
  `List[f64]`; every other module is currently `f32`. Iteration counts are
  `i64` and predicates are `bool`.
- **Linear algebra is composition.** Fixed-size 2×2 and 3×3 formulas and the
  general square LU, QR, Cholesky, Jacobi SVD, symmetric eigendecomposition,
  and conjugate-gradient routines are all written in Chelis. The general
  decompositions are labelled `alpha` where their shape, convergence, pivoting,
  or symmetry assumptions are narrower than a LAPACK-style interface.
- **`Nautilus.Rolling` departs from the package on precision and on absence,
  and both departures are module-local.** It is concrete `f64` rather than
  `[prec: Float]`, because nautilus#70's generic policy governs *conversion* of
  existing `f32` surface — where an `f32` caller must keep working — and this
  module is new, while the generic form would silently admit `f16`/`bf16`
  (nautilus#75) and needs a scalar cast to the binder that a downstream
  consumer's `chelis build` has rejected. Widening `f64` to generic later
  breaks no call site; narrowing a generic signature back would. And it reports
  a position with no value as `None` rather than as a NaN sentinel, because
  absence there has to survive composition: any sibling validity channel can be
  projected away by a caller who only wanted the numbers, and a NaN sentinel is
  indistinguishable from a NaN the module computed, which is a distinction this
  module's own results turn on. No other module should read either choice as a
  package-wide precedent; nautilus#85 records the reasoning.
- **Differentiability is claimed only where a test proves it.** Because
  Nautilus is pure Chelis, the compiler's automatic differentiation (AD) can in
  principle trace through any of it, but that does not show that the gradient
  through every recursive solver or decomposition is correct. Nautilus ships no
  hand-written adjoints, and a public function is advertised as differentiable
  only when a `grad` test checks it against an exact or finite-difference
  reference.

## Acceptance

- **Native tests are the primary oracle.** `chelis test tests/` covers
  mathematical identities, structural invariants, solver recovery, tensor code
  paths, edge cases, and public callability, without importing any external
  library.
- **At least two configurations per new public function.** Every new public
  numerical function is accepted on at least two distinct shapes or
  configurations. A single fixture is a smoke test, not acceptance.
- **External parity is a reviewed subset.** `parity/` checks selected Special
  and Distributions functions against SciPy and NumPy. Each parity label has at
  least two configurations. The goldens are checked in and reviewed, and CI
  validates them without ever regenerating them. A SciPy golden is not required
  for every module.
- **Linear algebra is checked by identities.** Reconstruction, orthogonality,
  residual, and trace/eigenvalue relations are the primary oracle. External
  matrix cases are added only where Nautilus intentionally promises SciPy or
  NumPy semantics.
- **Rejections and numerical edge cases are tested separately.** Compile-time
  shape and type rejections live in `tests_neg/`, each paired with the
  diagnostic it must produce. Numerical domain failures that the API reports as
  NaN or Inf, such as inverting a singular fixed-size matrix, are ordinary
  positive tests.
- **Documentation is executable.** `chelis reef build` must produce non-empty
  package artifacts. The API-smoke imports, stability metadata, `SKILL.md`
  examples, and mdBook examples must all validate against the pinned compiler.
- **In `Nautilus.Rolling`, a documented domain limit needs an executable pin.**
  Two red-team rounds on this module ended on prose that no artifact checked: a
  trapping set stated as one value when it scales with the series length, and
  three successive wrong statements of an upstream blocker's condition. The
  rule adopted in response, which applies to anyone editing this module: a
  sentence asserting a limit, a divergence, or a condition is either pinned by
  a test in `tests/rolling.ch` or by a `.expect` sidecar, or it is deleted
  rather than reworded. `test_lag_trapping_set_scales_with_length`,
  `test_warmup_is_clipped_to_the_series`,
  `test_ddof_at_or_above_the_count_is_nan`,
  `test_input_nan_propagates_through_every_reduction` and
  `test_documented_divergences_from_pandas` exist for exactly that reason, and
  `docs/UPSTREAM_BUGS.md` now says the function-value condition is
  uncharacterised instead of guessing a fourth time.
- **`Nautilus.Rolling`'s C lane has its own oracle, because the package gates
  cannot see it.** `chelis reef build` type-checks without entering host
  lowering, so a module can pass every package-level gate while no consumer can
  compile against it -- which is the class nautilus#70's 2026-09-17 comment
  records, and which this module hit during review on two independent upstream
  limitations (both in `docs/UPSTREAM_BUGS.md`). `scripts/check_rolling_c_lane.py`
  covers it in two legs: an in-package consumer of all 34 exports plus the clang
  line `chelis build` emits, and a **separate package** that depends on this one,
  rebuilt from current source and installed into a throwaway Reef store so the
  shared `~/.chelis/reef/` is never written. Acceptance is exit 0 with
  `ROLLING C LANE: PASS`, and CI runs it in the `chelis-tests` job. No other job
  in this repository runs `chelis build`. The cross-package leg rebuilds before
  installing on purpose: `dist/` is a build output, and a review round that read
  it without rebuilding produced a confident cross-package finding that the
  committed source does not reproduce.
- **`Nautilus.Rolling`'s pandas contract has its own oracle.**
  `scripts/check_rolling_parity.py` replays the committed goldens in
  `parity/goldens/rolling.json` against `chelis eval`; acceptance is exit 0
  with a final `ROLLING PARITY: PASS` line, and CI runs it in the
  `chelis-tests` job. `scripts/check_rolling_tensor_parity.py` proves each `tensor_` export is
  a literal delegation by reading the source; acceptance is exit 0 with
  `TENSOR DELEGATION: PASS`, and CI runs it with the hard rules. Regenerating
  the goldens needs pandas and is a reviewed manual gate:
  `uv run --with 'pandas==2.3.3' --no-project python parity/rolling_goldens.py --write`.
  The parity set carries no non-finite expectation and no cancellation fixture,
  because pandas accumulates a window incrementally where this module
  re-reduces it; `tests/rolling.ch` owns those cases.

The [maintainer guide](../docs/maintainer_guide.md) lists the commands for each gate.

## Known limitations

- `lm_scalar_nparam` (multi-parameter Levenberg–Marquardt) assembles its
  Jacobian by forward finite differences with `eps = 1e-5`, uses a fixed
  damping of `0.01`, and always runs exactly `max_iters` iterations; `tol` is
  accepted but not yet used. Scale parameters and outputs to O(1) to avoid f32
  cancellation. Replacing the finite differences with an AD Jacobian is blocked
  upstream; see [`docs/UPSTREAM_BUGS.md`](../docs/UPSTREAM_BUGS.md).
- `lu_solve`, `qr_decompose`, `svd_n`, and `eig_n` are `alpha` and square-only.
  `lu_solve` does not pivot, so it requires non-zero leading principal minors.
  `svd_n` and `eig_n` run a fixed 30n Jacobi sweeps with no early exit, and
  `eig_n` assumes a symmetric input.
- `newton_minimize_1d` returns NaN when the curvature at a stationary point is
  below `0.01`, so it can reject very flat true minima.
- `airy_ai` has no dedicated asymptotic branch for large negative `x`.
- `Nautilus.Rolling` re-reduces each window rather than carrying a running
  accumulator, so every reduction is O(`window`) per position rather than
  O(1), and `rolling_min`/`rolling_max` use no monotonic deque. That is the
  deliberate trade for a variance that stays exact on a large mean with a small
  spread. It also does not accept pandas' `min_periods=0`, because no reduction
  is defined on an empty window.
- `Nautilus.Rolling` treats a non-finite input value as a **value**, which
  propagates through all six reductions. pandas treats NaN as **missing**: it
  does not propagate, and only non-NaN observations count toward
  `min_periods`. So the pandas agreement this module claims is for NaN-free,
  finite input, and the parity goldens contain no non-finite input. The
  divergence is documented in the book rather than reconciled, because
  adopting missing-data semantics would change what `min_periods` counts
  across the whole surface; a caller that needs it drops or imputes first. An
  infinity diverges in the other direction, and `rolling_min`/`rolling_max` do
  not preserve signed zero -- the comparison folds return the first of two
  values that compare equal, where pandas returns `-0.0`.
- The lag family traps for the `len(xs)` most negative values of `k`, where
  `i - k` overflows the index arithmetic; the largest index overflows first, so
  on a two-element series both `i64::MIN` and `i64::MIN + 1` trap. Every less
  negative `k` is defined.

## Deferrals

The following are out of scope. Each may be proposed later with its own
acceptance oracle, and until then documentation must not describe it as
available.

- **Complex-valued signal processing.** `Nautilus.Signal` reserves six typed
  transform and filter entry points (`fft_magnitude_stub`,
  `ifft_magnitude_stub`, `stft_magnitude_stub`, `lowpass_stub`,
  `highpass_stub`, `bandpass_stub`) that return NaN until Chelis supports
  complex numbers. The real-valued `fftfreq` helper is fully functional.
  Other complex-valued functions such as `erfi` and complex Bessel functions
  are deferred for the same reason.
- **Constrained convex optimization.** QP, SOCP, LP, and KKT-based
  differentiable optimization.
- **Native acceleration.** A LAPACK or nalgebra FFI layer and hand-written
  decomposition adjoints.
- **Blanket AD coverage.** Gradients through every recursive or fold-based
  solver.
- **Sparse matrices**, which need sparse tensor types in Chelis core.
- **Full external-oracle duplication** of the native test corpus.
