# Chelis 0.18.8 migration

This release advances the C Note dependency chain. The canonical compiler
bump regenerates shell scaffolding, compiler-bound package artifacts and
workflow pins together.

The compiler now enforces explicit module exports within a package. LinAlg
exports `la_basis_n_f32`, `la_zeros_mat_like` and `la_tridiag_solve` for their
existing consumers. Interpolation imports its required helper bindings.
Scalar lifts introduce a new axis with `insert`; `expand` operates on an
existing axis. The numerical algorithms and tolerances are preserved.

Shared-helper tests cover analytic basis, zeros and tridiagonal cases. The
tridiagonal helper retains its existing small-pivot behavior, documented in
the API reference. Wrong precision still rejects. Blocked AD probes retain
their current expected diagnostics.

Two upstream compiler repairs are prerequisites: recursive evaluation avoids
copying the declaration table when execution exclusion is inherited
(chelis PR 2021), and typed lexical parameters named like builtins retain
their data-input meaning (chelis PR 2024).

## Validation status

Published 0.18.7 passes the 216-sample strict SciPy comparison and the focused
migration tests. The combined compiler repair candidate passes all 483 native
tests. These are preparation results, not final 0.18.8 release acceptance.
Sonar preserves their commands and artifacts at
`landing/runs/g5-nautilus-strict-parity-release/` and
`landing/runs/g5-nautilus-combined-native-suite/`.

The final published 0.18.8 full gate and release artifact hashes are pending.
Do not publish this package until that record replaces this pending marker.
