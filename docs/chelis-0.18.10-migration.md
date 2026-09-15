# Chelis 0.18.10 migration

This release advances the C Note dependency chain from Chelis 0.18.9 to 0.18.10.
The canonical compiler bump regenerates shell scaffolding, compiler-bound
package artifacts and workflow pins together. Unlike the 0.18.9 bump, no
Nautilus source change is required: `chelis reef conform bump 0.18.10` advances
`reef.toml`, the workflow audit mirrors and the managed shell files, and the
Nautilus package version advances from 0.7.44 to 0.7.45.

0.18.10 is a targeted repair release. It fixes two upstream issues that touch
Nautilus directly:

- **chelis#2059 (interpreter performance).** The interpreter's
  `admit_execution_profile` re-lowered definitions per closure application;
  0.18.10 makes the lowering program-scoped. This removes the roughly 2x
  slowdown that 0.18.9 imposed on Nautilus's tensor and Monte-Carlo suite. The
  0.7.44 release carried a temporary CI bandaid for that regression — the
  `chelis test tests/` step in `.github/workflows/ci.yml` raised
  `--suite-timeout` from its 600s default to 2400s. **This release reverts the
  bandaid**: the step returns to `chelis test tests/ --timeout 600 --jobs auto`
  with no `--suite-timeout` override, the same shape it had at 0.7.43/0.18.6.
  The green suite run within the default suite timeout is the proof that
  chelis#2059 is fixed (local wall time recorded below; the Linux gate run is
  the pull request's CI).

- **chelis#2068 (native-C airy ownership).** 0.18.10 repairs a native-C
  ownership error that Nautilus's `src/special.ch::airy_gg` triggered. The
  recursive Airy `g`-series helper now compiles on the native-C target, and the
  whole-package `chelis reef build` plus the sealed release-artifact contract
  exercise it. `airy_gg`/`airy_fg` back the exported `airy_ai`/`airy_bi`
  special functions; their values, shapes and tolerances are unchanged.

Nautilus carries **no dependency cascade** for this wave. Its only dependency is
the compiler-bundled `chelis-std 0.4.0`, so this bump is not blocked on a
sibling release. The bundled standard library stays at 0.4.0, rebound to
`compiler = "=0.18.10"` in the regenerated local `reef.lock`.

The blocked AD probes retain their current expected diagnostics: chelis#676
(both `tests_blocked/curvefit/` wrapper shapes) and chelis#1464
(`tests_blocked/masked_select/untaken_arm_overflow.ch`) all remain live at this
pin, so the finite-difference Jacobian narrowing and the `erf` series clamps
stay. No probe source drift this cycle.

## Release identity

| Item | Value |
|---|---|
| Upstream tag | `v0.18.10`, commit `b9095ccf2c0b76859aa447c6febe699fd287f1d2` (annotated tag object `e247a5d33cd2df552f57e3efddfd4ea30846b3b8`), release workflow run 34966582543 |
| Linux glibc-2.31 archive (what CI installs) | SHA-256 `0843697e0a7783e383df0347ae431ae56f62b5a5ae34a7aa72ac37ee91df1e0b` |
| Linux glibc-2.31 compiler payload (`bin/chelis`) | SHA-256 `6622e40bc786c562b5b66d370a84e46ded551dee70abfc617a71d026c0119b00` |
| Darwin arm64 archive | SHA-256 `80c9c5b42a8fbcee6884915df1a4dafb8bcc1cae33199ded060d8b2ebece8bf0`, checked against its release sidecar |
| Darwin arm64 compiler payload (local gate) | SHA-256 `a6af380886b21761bc2822a814e4fef4232e8b8551922d32bca722cd4e04e1e2`, reports `chelis 0.18.10` |
| Bundled dependency | `chelis-std 0.4.0` installed from the monorepo at `v0.18.10`; `reef.lock` binds it to `compiler = "=0.18.10"` (archive SHA-256 `20f8c777c858c6e9306378086ea01111a6e3adaea5be0aec13ae541feff3944a`, shell SHA-256 `5f1a4ea28c0e5ec2d92bae456a2bd6cab181e5027f36a5b4112960e542d39e7d`) |

## Validation status

Release acceptance, recorded 2026-09-15 on the published Darwin arm64 payload
above with the complete AGENTS.md step 7 local gate:

- `chelis fmt --check` clean over all 53 `.ch` sources in `src/`, `tests/`,
  `tests_neg/` and `tests_blocked/`; `chelis lint --check .` clean over source
  (the pre-existing non-blocking `prefer-pipe-operator` advisories are unchanged
  from 0.18.9, and the `doc-filename-convention` note on the kebab-case
  migration filenames is the same accepted condition present on `main`);
  `chelis reef build` green (built `nautilus 0.7.45`).
- `chelis test tests/ --timeout 600 --jobs auto` **at the default 600s suite
  timeout**: 483 passed, 0 failed, in 413s wall time. This is the proof that
  chelis#2059 is fixed — the suite completes within the default suite timeout
  the 0.7.44 bandaid had to raise to 2400s, so the bandaid is reverted.
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
  unchanged rebuild, canonical verifier) green over 25 source modules.
- `chelis reef conform audit --explain` conformant with no MUST failures;
  `chelis reef conform bump-check --base origin/main` green for
  `0.18.9 -> 0.18.10`.

The Linux glibc-2.31 asset is what CI installs; its gate run is the pull
request's CI, not this record.
