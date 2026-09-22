# Chelis 0.18.9 migration

This release advances the C Note dependency chain. The canonical compiler
bump regenerates shell scaffolding, compiler-bound package artifacts and
workflow pins together. The pin moves from 0.18.6 directly to 0.18.9: 0.18.7
was published but never pinned here, and 0.18.8 was never published.

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

## Release identity

| Item | Value |
|---|---|
| Upstream tag | `v0.18.9`, commit `abff07b47eadc8d2be633e3a7d21220089befb6f` (annotated tag object `4fa7145a29c8e8bdae06fec3c653adc42553767b`), release workflow run 34843914490 |
| Linux glibc-2.31 archive (what CI installs) | SHA-256 `9aed0afbfc93a96a6804b4c82664869d74815bd27ca824dfeab02088b00ddb63` |
| Linux glibc-2.31 compiler payload (`bin/chelis`) | SHA-256 `efe99c09f5d7d7372065206a332a2fd86b8aee77412262b0028cfbdbc98a19f2` |
| Darwin arm64 archive | SHA-256 `44e12cf187b37cb6d2a617e1573832a1bdcaa0e1564f59c4029e24081a84905d`, checked against its release sidecar |
| Darwin arm64 compiler payload (local gate) | SHA-256 `68e460df6e796891fb30c42904b0309b4d5e83d187944222faaaae63241101c7`, reports `chelis 0.18.9` |
| Bundled dependency | `chelis-std 0.4.0` installed from the monorepo at `v0.18.9`; `reef.lock` binds it to `compiler = "=0.18.9"` |

## Validation status

Preparation evidence, recorded before 0.18.9 was published: published 0.18.7
passed the 216-sample strict SciPy comparison and the focused migration
tests, and the combined compiler repair candidate passed all 483 native tests.
Sonar preserves those commands and artifacts at
`landing/runs/g5-nautilus-strict-parity-release/` and
`landing/runs/g5-nautilus-combined-native-suite/`.

Release acceptance, recorded 2026-09-14 on the published Darwin arm64 payload
above with the complete AGENTS.md step 7 local gate (Sonar receipt
`landing/runs/g8-nautilus-local-gate-0189-v3/`; the compiler publication
itself is `landing/runs/g8-chelis-0189-published/`. Two earlier attempts on
the same shared host were interrupted by concurrent library-wave jobs, not by
Nautilus: `g8-nautilus-local-gate-0189` passed every step through the example
validators, then failed the artifact contract because a sibling job
republished this checkout's `dist/` pair with the 0.18.7 compiler mid-run;
`g8-nautilus-local-gate-0189-v2` reached 393 of 483 native tests before the
default 600s suite-timeout fired under load, with no test failing. Both are
kept as the interrupted records, and v3 adds `--suite-timeout 2400` so host
contention cannot fire a false suite-timeout):

- `chelis fmt --check` clean over `src/`, `tests/`, `tests_neg/` and
  `tests_blocked/`; `chelis lint --check .` clean; `chelis reef build` green.
- `chelis test tests/ --timeout 600 --jobs auto`: 483 passed, 0 failed.
- `chelis test tests_neg/ --expect neg`: 4 ok, 0 failing.
- `chelis test tests_blocked/ --expect blocked`: 3 ok, 0 failing (chelis#676
  twice and chelis#1464 all still live; see `docs/UPSTREAM_BUGS.md` for the
  per-surface re-probe record).
- `parity/run_parity.py --strict` through the locked `uv` project: 216
  passed, 0 failed.
- Python automation contracts: 51 tests, 43 passed and 8 skipped (the
  `devenv.nix` contract tests skip outside the Devenv checkout). The
  structured-archive test needs `libzstd`, which this Darwin host supplies
  through `DYLD_LIBRARY_PATH` rather than a system install. Workflow pin
  mirror, oracle isolation, surface, 15/15 SKILL.md and 4/4 mdBook example
  validators green; the release artifact contract (sealed checksums,
  unchanged rebuild, canonical verifier) green.
- `chelis reef conform audit --explain` conformant with no MUST failures;
  `chelis reef conform bump-check --base origin/main` green for
  `0.18.6 -> 0.18.9`.

The Linux glibc-2.31 asset is what CI installs; its gate run is the pull
request's CI, not this record.
