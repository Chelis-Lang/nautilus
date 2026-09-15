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
  0.18.10 makes the lowering program-scoped. That regression degraded the
  closure-heavy package/prove route (the on-demand NN prove exhausting its
  budget); the fix is verified there. The 0.7.44 release raised this suite's CI
  `--suite-timeout` from 600s to 2400s and attributed it to #2059. **That
  attribution was wrong, and the raise is retained (now re-documented), not
  reverted.** Measurement on GitHub's Linux runner: this tensor / Monte-Carlo
  suite ran ~800-940s under 0.18.9 (with the raise) and still exceeds the 600s
  default under 0.18.10 — the wall time is intrinsic suite weight on a slow
  runner, not #2059, which touches a different workload. So `chelis test tests/`
  keeps `--suite-timeout 2400`, its comment rewritten to say suite weight. Local
  wall time is recorded below; the proper fix is to shard `tests/` across a CI
  matrix so each shard fits the default (follow-up).

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
- `chelis test tests/ --timeout 600 --jobs auto` on Apple silicon: 483 passed,
  0 failed, in 413s wall time. On GitHub's slower Linux runner the same suite
  exceeds the 600s default (measured ~800-940s under 0.18.9), so CI retains
  `--suite-timeout 2400`; every test passes, only wall time regresses. This
  suite is not the workload chelis#2059 governed (see above).
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
