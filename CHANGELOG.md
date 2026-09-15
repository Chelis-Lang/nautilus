# Changelog

All notable changes to this project are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [0.7.45] - 2026-09-15

Compiler-pin release for Chelis v0.18.10, a targeted repair on top of the
2026-09-14 dependency wave used by C Note. `chelis reef conform bump 0.18.10`
advances `reef.toml`, the workflow audit mirrors and the managed shell files,
and the Nautilus package version advances from 0.7.44 to 0.7.45. **No Nautilus
source behaviour change was required by the compiler:** the whole-package build,
the 483-test suite, the negative sidecars, the three blocked probes, and the
216/216 strict SciPy parity gate are all green on 0.18.10.

- **chelis#2059 is fixed, but the CI `--suite-timeout` raise is retained — it
  was misattributed to #2059.** 0.18.9 re-lowered definitions per closure
  application in the interpreter's `admit_execution_profile`; 0.18.10 makes that
  lowering program-scoped. That regression degraded the closure-heavy
  package/prove route (the on-demand NN prove exhausting its budget); its fix is
  verified there, not on this suite. Measurement on GitHub's Linux runner shows
  this tensor / Monte-Carlo suite takes ~800-940s under 0.18.9 (with the raise)
  and still exceeds the 600s default under 0.18.10 — the wall time is intrinsic
  suite weight on a comparatively slow runner, not #2059. So the
  `chelis test tests/` step keeps `--suite-timeout 2400` in
  `.github/workflows/ci.yml`, now documented as suite weight rather than a
  temporary #2059 bandaid. Every test passes; only wall time exceeds the default.
  Locally (Apple silicon) the full suite is 483/483 in 413s. The proper fix is
  to shard `tests/` across a CI matrix so each shard fits the default; tracked
  for a follow-up. `nightly.yml` and `release.yml` never ran `chelis test tests/`,
  so neither carries the raise.
- **chelis#2068 (native-C airy ownership) is fixed.** Nautilus's
  `src/special.ch::airy_gg` — the recursive Airy `g`-series helper behind the
  exported `airy_ai`/`airy_bi` — was the upstream trigger for a native-C
  ownership error; 0.18.10 compiles it on the native-C target. The
  whole-package `chelis reef build` and the sealed release-artifact contract
  exercise it, and its numerics, shapes and tolerances are unchanged.
- The bundled `chelis-std 0.4.0` is rebound to `compiler = "=0.18.10"` in the
  regenerated local `reef.lock`; Nautilus carries **no dependency cascade** for
  this wave.
- The blocked probes stay live: chelis#676 (both `tests_blocked/curvefit/`
  wrapper shapes) and chelis#1464 (`tests_blocked/masked_select/`) all still
  reach their pinned diagnostics with no source drift, so the finite-difference
  Jacobian narrowing and the `erf` series clamps are retained.
- Published-compiler acceptance and artifact identities are recorded in
  `docs/chelis-0.18.10-migration.md` before publication.

## [0.7.44] - 2026-09-14

Compiler-pin release for Chelis v0.18.9, the 2026-09-14 dependency wave used
by C Note. The migration was prepared against published 0.18.7 and the 0.18.8
repair candidate; 0.18.8 was never published, so this release targets 0.18.9
directly. `chelis reef conform bump 0.18.9` advances `reef.toml`, the workflow
audit mirrors and the managed shell files, and the Nautilus package version
advances from 0.7.43 to 0.7.44.

- Chelis 0.18.x enforces explicit exports within a package. LinAlg now exports
  the shared helpers `la_basis_n_f32`, `la_zeros_mat_like` and
  `la_tridiag_solve` for their existing in-package consumers, and Interpolation
  imports the four LinAlg bindings it uses explicitly. Analytic shared-helper
  tests cover the basis, zeros and tridiagonal cases and wrong precision still
  rejects. This repairs nautilus#61.
- Scalar lifts introduce their new axis through `insert`; `expand` now operates
  only on an existing axis. Values, shapes and numerical tolerances are
  unchanged, and the blocked AD probes keep their current expected diagnostics.
- `Nautilus.Core.version` migrates its return type from the `i32` alias to the
  canonical `int32` spelling; the numerics are unchanged and the constant is
  still 1000.
- The provenance launcher is now `scripts/provenance_oracle.py`, replacing the
  shell wrapper; it runs under the selected interpreter and propagates the
  subprocess status, and unit tests cover the propagation.
- Executable documentation and the CLI command inventory are refreshed.
  Published-compiler acceptance and artifact identities are recorded in
  `docs/chelis-0.18.9-migration.md` before publication.

- CI carries a temporary bandaid: the native-suite job raises `--suite-timeout`
  from its 600s default because Chelis v0.18.9 has a tensor and Monte-Carlo
  performance regression (chelis#2059) that roughly doubles suite wall time.
  Every test still passes; only speed regressed. The raise reverts once
  chelis#2059 is fixed.

## [0.7.43] - 2026-08-29

Compiler-pin release for Chelis v0.18.6. `chelis reef conform bump 0.18.6`
advanced the compiler pin and all workflow audit mirrors, and the Nautilus
package version advanced from 0.7.42 to 0.7.43. **No Nautilus source behaviour
change was required by the compiler:** the whole-package build, the 472-test
suite, the negative sidecars, the two blocked probes, and the 216/216 strict
SciPy parity gate are all green on 0.18.6 exactly as they were on 0.18.5.

Nautilus carries **no dependency cascade** for this wave. Its only dependency is
the compiler-bundled `chelis-std 0.4.0`, so unlike coral and shoals this bump is
not blocked on a sibling release and can tag as soon as it merges.

**0.18.6 is a large release and Nautilus is unexposed to all of it.** The
published C numeric ABI is replaced with exact tagged carriers, `bool` narrows
to one byte, package schema and CHB advance to v2, WireDag advances to
exact-only v6, every on-disk compiler cache is invalidated, three exported
stdlib names are removed, `Std.Test.assert_close_tensor` acquires a stricter
signature, `JsonBigInt(string)` joins the `Json` ADT, and `diagonal`/`trace`
are repaired for the whole axis domain. `docs/UPSTREAM_BUGS.md` records the
per-item argument for why none of them reaches this package; the short version
is that Nautilus ships no native code, references no `Json`, targets no GPU,
imports no removed name, and calls `diagonal`/`trace` only at the one axis pair
that was already correct.

**One conformance repair the pin forced.** chelis#1270 (chelis PR #1279)
widened the shell-contract §4 narrowing-citation grammar so a `<sibling>#NNN`
reference, not only `chelis#NNN`, counts as a citation requiring coverage.
Nautilus used `nautilus#45` and `nautilus#47` in four `src/` comments as
provenance notes for its own feature PRs rather than as narrowings, and the
widened grammar read them as uncovered citations, failing `conform audit` row 9
at the new pin. The four notes now read `nautilus PR 45` / `nautilus PR 47`,
which keeps the provenance without asserting a blocked upstream probe that does
not exist. No behaviour changes; the affected lines are comments in
`src/distance.ch`, `src/distributions.ch`, `src/linalg.ch`, and
`src/special.ch`.

**chelis#676 remains live.** Both `tests_blocked/curvefit/` shapes still fail
backward-DAG verification at this pin with no probe-source drift, so the
finite-difference Jacobian narrowing stays. Nothing is retired this cycle.

**Verified against the published toolchain.** Every gate above was run with
the installed `chelis 0.18.6` Darwin arm64 release asset (release SHA-256
`08580435570c6fd44716f4d5c64117e973e379808cefeaaa97c8faefa2588f6c`, compiler
payload SHA-256
`1c88c737d7d3740eb4adbe7b50ea31d29ee64498b9d74b35664255ca16aea8d4`, source
commit `cf49f85bf0d1bca2c87c88a3e459c446912189c0`). The tarball matches its
release sidecar and the installed payload is byte-identical to the `bin/chelis`
inside it. `docs/UPSTREAM_BUGS.md` carries the same record plus the Linux
asset hashes.

## [0.7.42] - 2026-08-22

Compiler-pin release for Chelis v0.18.5. `chelis reef conform bump 0.18.5`
advanced the compiler pin and all workflow audit mirrors, and the Nautilus
package version advanced from 0.7.41 to 0.7.42. **No Nautilus source change was
required by the compiler:** the whole-package build, the 463-test suite, the
negative sidecars, and the strict SciPy parity gate are all green on 0.18.5
exactly as they were on 0.18.4.

The official Darwin arm64 asset was verified at SHA-256
`0ff7b4e168d8b51277e05d44bfa658364630176d56d79c9cf8aceaea15335551`; its
installed compiler payload was
`bcf8da8bd2df9acb8816194f9251b26e23ec57527d4fc928bea6e1f6120628b2`,
byte-identical to the release tarball. The upstream source commit is
`6602f01719f55b8d4c7f52ee70e7c7b58f136107`.

**Repaired the last of the canonical Surf v0.19 residue in prose docs.** The
0.7.41 migration converted `src/` and `tests/` but not the Chelis examples
embedded in `SKILL.md` and the mdBook, which are extracted and type-checked by
the nightly documentation gates. Three `SKILL.md` blocks and one
`docs/book/src/solvers/roots.md` block still used pre-v0.19 spellings and had
been failing since 0.18.4: two redundant one-expression block braces, and two
float literals that are no longer accepted spellings (`3.1415926535897932` and
`0.0000000001`, respelled to `3.141592653589793` and `1e-10`). Both gates are
now clean at 15/15 and 4/4. This is the cause of the currently open
`nightly-failure` issue #42.

**Nothing was de-narrowed at this pin.** 0.18.5 fixes chelis#1200, chelis#1197,
and chelis#1209, none of which Nautilus works around in shipped source.
chelis#1197 (`chelis migrate surf` aborting a whole batch on the first file it
cannot resugar) was filed from this repo during the 0.7.41 migration; it was a
one-time tooling limitation, so there is nothing to revert. chelis#1209 and its
fix in chelis#1254 covered the aliased-closure generation path that
`Nautilus.LinAlg.lu_solve` depends on (`lu_fwd = lu`, one closure per name);
that spelling is explicitly re-verified green at this pin.

Nautilus is unexposed to all three 0.18.5 breaking changes. Polymorphic
recursion now rejects at check time and integer literals in bare *type*
positions are now parse errors; `chelis reef build` type-checks the whole
package and passes, which rules both out by construction. `>` now evaluates its
operands left to right; every Nautilus comparison operand is a pure f32
expression, so operand order is unobservable, and both the suite and the
216-sample parity gate are numerically unchanged.

**Validation on 0.18.5:** `chelis reef conform audit` conformant with no MUST
failures and `bump-check --base origin/main` green; `chelis reef build` green;
463 positive tests passed, 0 failed; 3 negative sidecars ok; both chelis#676
blocked probes still fail at the backward-DAG verifier with the pinned
`mismatched dimension count: 0 vs 1`, with no probe source drift, so that
narrowing is unchanged; 216/216 strict SciPy parity; `chelis lint --check .`
clean; 36 script unit tests ok.

## [0.7.41] - 2026-08-05

Compiler-pin and grammar-migration release for Chelis v0.18.4. The
`chelis reef conform bump 0.18.4` command advanced the compiler pin and all
workflow audit mirrors, and the Nautilus package version advanced from 0.7.40
to 0.7.41. The version bump lands in a follow-up to PR #40, which carried the
pin and migration; the published 0.7.40 artifact pins `=0.18.3` and is
unchanged.

**The entire Surf corpus migrated to canonical Surf v0.19 (chelis#1031).**
Chelis 0.18.4 defines one canonical written form for Surf and its style gate
runs `chelis fmt --check` ahead of the front-end pipeline, so this migration
and the pin bump are one atomic change: 5 of 12 sampled migrated files fail
`fmt --check` under 0.18.3, and unmigrated files fail it under 0.18.4. Most
of the rewrite is `chelis migrate surf --from 0.18` output; the residue was
repaired from the compiler's own diagnostics (float literals respelled to
exponent form, redundant one-expression block braces dropped, explicit
first-argument pipe lambdas rewritten to canonical call-stage sugar). The
migrator was driven per file because its batch mode aborts entirely on the
first file it cannot resugar (chelis#1197).

The official Darwin arm64 asset was verified at SHA-256
`ac905d2a2d471ff09a46e39c7ae78ede85aab2f97515553b445ffd0dc0d29fea`; its
installed compiler payload was
`b6b80d65bf1822f6ad926915b4c5d4b3c94e414a9afcafa0bc02f9fc29a48037`,
byte-identical to the release tarball. The upstream source commit is
`c0138c828bf2c42e1c8941e824f16616bd974fd5`.

**Validation on 0.18.4:** `chelis reef conform audit` conformant with no MUST
failures; 463 positive tests passed, 0 failed; 3 negative sidecars ok; both
chelis#676 blocked probes still fail at the backward-DAG verifier with the
pinned `mismatched dimension count: 0 vs 1`, so that narrowing is unchanged
(no movement on chelis#676 at 0.18.4, and no probe source drift this cycle).

Nautilus is unaffected by chelis#1200 (the 0.18.4 `_ = f(x)`
wildcard-discard consume regression): its suite is fully green, and it has no
record-destructuring callee reached through a discarded result.

## [0.7.40] - 2026-08-04

Compiler-pin and de-narrowing release for Chelis v0.18.3. The required
`chelis reef conform bump 0.18.3` command advanced the compiler pin and all
workflow audit mirrors, and the Nautilus package version advanced from 0.7.39
to 0.7.40.

The official Darwin arm64 asset was verified at SHA-256
`cc8737adf8c21040432d94b96635ef48895bd7ac8cdf94bd7696046c44bc7371`; its
installed compiler payload was
`3a14b0d7e0a46a49c9b25f3dc61573d5972a91b411021672e09b8e3e0e9e1eba`, byte-identical
to the release tarball. The upstream source commit is
`29700dd73c0e35b672bdd384493054b3107ce308`.

**Retired the chelis#759 `floor` workaround.** Chelis 0.18.3 ships `cast_trunc`
([05-OP-6]) as the named truncating float-to-integer cast on the Surf, eval, and
compiled-C surfaces. The five fractional cast sites that 0.7.39 wrapped in
`floor(...)` — in `distributions.ch` (`is_integer_f32`), `interpolation.ch`
(`linear_interp_uniform`), `special.ch` (`is_nonpositive_integer`), and
`stats.ch` (`quantile_vec`, `trimmed_mean_vec`) — now call `cast_trunc`
directly. This is behavior-preserving at every site: three operate on values
clamped non-negative, where floor and truncation agree, and the other two are
is-integer predicates, where `floor(x) == x` and `trunc(x) == x` are the same
test. It also unbreaks downstream compiled-lane consumers, since `floor` has no
`chelis build` expression identity and 0.7.39 therefore failed Coral's native
build.

**Adopted the 0.18.3 extent-dtype rules** ([05-DIM-1]/[05-DIM-2],
chelis#1130/chelis#1145): `sort` axis arguments are now int32 via a new
`zero_axis()` helper in `stats.ch` (five call sites), and the two
`tests_blocked/curvefit/` probes had their `expand` extents widened to int64.
Both blocked probes retain their exact chelis#676 malformed backward-DAG
diagnostic, so the finite-difference Jacobian remains.

The complete local gate passed: 463 positive tests, 3 negative contracts, 2
blocked probes, and 216/216 strict SciPy parity. Publishing remains gated on the
milestone red team.

## [0.7.39] - 2026-08-03

Compiler-pin release for Chelis v0.18.2, published as `v0.7.39`. The
`chelis reef conform bump 0.18.2` command advanced the compiler pin and all
workflow audit mirrors, and the Nautilus package version advanced from 0.7.38
to 0.7.39. Five fractional float-to-integer casts were wrapped in `floor(...)`
to work around the chelis#759 numeric trap; that workaround is retired in
0.7.40 in favour of `cast_trunc`.

## [0.7.38] - 2026-08-01

Compiler-pin and de-narrowing release for Chelis v0.18.1. The required
`chelis reef conform bump 0.18.1` command advanced the compiler pin and all
workflow audit mirrors, and the Nautilus package version advanced from 0.7.37
to 0.7.38.

The official Linux glibc-2.31 asset was verified at SHA-256
`88a1a53b47b7168e4df614e66a6d9313176174b1dc3a25a43db5f73a3ee8f0cd`;
its installed compiler payload was
`0d7a46262b4ba2975702d5ed2def5d54b79b5d68258602da59069b6715cc690b`.
The extracted release compiler reports `chelis 0.18.1` and discharges the
release SMT probe through cvc5. Both chelis#676 CurveFit blocker shapes retain
their exact malformed backward-DAG diagnostic, so the finite-difference
Jacobian remains. All 15 package-import startup shapes continue to execute.
The complete local gate passed; publishing remains gated on the milestone red
team.

## [0.7.37] - 2026-07-31

Compiler-pin and de-narrowing release for Chelis v0.17.5. The required
`chelis reef conform bump 0.17.5` command advanced the compiler pin and all
workflow audit mirrors, and the Nautilus package version advanced from 0.7.36
to 0.7.37.

The official Linux glibc-2.31 asset was verified at SHA-256
`65f5949a540a547aacbee9845b3d40d2a02d1b28e3c8d608fc7af140fafd6ccf`;
its installed compiler payload was
`9728e7824cd5d8aba26daf5189f95b90c98f9636b8aa0b6ca2fe9cc286c44801`.
The release fixes the import-only `eval --file` residue tracked by chelis#848:
all 15 benchmark shapes now execute. Both chelis#676 CurveFit blocker shapes
retain their expected diagnostic, so the finite-difference Jacobian remains.
The complete local gate passed before this candidate was pushed; publishing
still requires the milestone red-team pass.

## [0.7.36] - 2026-07-31

Compiler and release-artifact hardening release for Chelis v0.17.4. The
compiler pin advanced from `=0.17.1` to `=0.17.4`, and the Nautilus package
version advanced from 0.7.35 to 0.7.36. The official Linux glibc-2.31 asset was
validated end to end: 463 native tests, 3 negative contracts, 2 blocked probes,
216 strict SciPy parity samples, and all 25 source modules passed with a
type-check score of 1 and no errors.

### Changed

- Made `reef.toml` the runtime source of truth for CI toolchain and registry
  installation. The shared installer now resolves and verifies the exact
  compiler pin itself; workflow pin variables remain audit-only mirrors as
  required by the shell contract.
- Corrected the release-artifact contract: versioned Reef package outputs are
  built once from the tag and uploaded, not committed. CI now rejects native
  source-archive members and asks Reef to validate/install the exact generated
  archive↔shell pair. The release and CI gates now rebuild from the unchanged
  checkout and require byte-identical archive and CHB outputs, resolving the
  Nautilus narrowing tracked by chelis#970.
- Sealed the complete release payload set with an independently transported
  SHA-256 manifest, added byte-flip and appended-junk regressions, and compiled
  a fresh dependent package through the installed shell. The gate now invokes
  `chelis reef verify-artifact` and requires compiler rejection of an archive
  mutation and CHB trailing byte, resolving the chelis#972 narrowing while
  retaining the checksum's explicit release-authority trust boundary.

## [0.7.34] - 2026-07-15

Compiler and shell-conformance release for chelis v0.16.1. The compiler pin
advanced from `=0.14.0` to `=0.16.1`, and the Nautilus package version advanced
from 0.7.33 to 0.7.34. There are no public Nautilus API changes.

### Changed

- Made the SciPy parity gate contract-compliant: external-oracle code is
  confined to the locked `parity/` uv project, reviewed 216-sample goldens are
  checked in and never regenerated by CI, strict validation fails closed, and
  a repository-wide guard rejects oracle imports outside `parity/` or oracle
  callables in Chelis source. Retired the duplicate Python numerical harness,
  separate legacy golden corpus, standalone generator, stale benchmark, and
  hard-coded red-team executable; Git history remains the archive for their
  historical evidence. Active surface and SKILL example validators now live
  under `scripts/`.

## [0.7.33] - 2026-07-04

Compiler-pin alignment for chelis v0.14.0. The compiler pin advanced from
`=0.12.0` to `=0.14.0`, and the Nautilus package version advanced from 0.7.32
to 0.7.33. No public Nautilus API changes.

## [0.7.32] - 2026-07-01

Cascade to chelis v0.12.0. `compiler = "=0.11.1"` → `"=0.12.0"`; CI /
nightly / release workflow env vars updated to track `v0.12.0`. Package
version bumped 0.7.31 → 0.7.32. Breaking upstream: chelis 0.12.0 restricts
`div` to float operands (#511). Fixed `Nautilus.Stats.median_vec`, which
computed the median split index with `div(numel, 2)` on two `int64`
operands — now `floor_div(numel, 2)` (numerically identical for the
non-negative count; median floor index). Full suite green on 0.12.0:
`chelis test` 459/0, scipy-parity 216/0.

## [0.7.31] - 2026-06-26

Cascade to chelis v0.11.1. `compiler = "=0.10.1"` → `"=0.11.1"`; CI /
release workflow env vars updated to track `v0.11.1`. Package version bumped
0.7.30 → 0.7.31. Breaking: Std.Tensor.Reduce removed in 0.11.0 (not used by
nautilus).

## [0.7.30] - 2026-06-25

Cascade to chelis v0.10.1. `compiler = "=0.10.0"` → `"=0.10.1"`; CI /
release workflow env vars updated to track `v0.10.1`. Package version bumped
0.7.29 → 0.7.30. No source or API changes.

## [0.7.29] - 2026-06-24

Compiler-pin alignment for chelis 0.10.0. `compiler = "=0.9.0"` to
`"=0.10.0"`; CI / release / nightly workflow env vars (and the
`install-chelis` action defaults plus `scripts/install_chelis_std.py`
default tag) updated to track `v0.10.0`. Package version bumped 0.7.28 →
0.7.29. chelis-std stays 0.4.0 (bundled in the 0.10.0 compiler). No source
or API changes: `chelis reef build` succeeds at `=0.10.0` and all 459 tests
pass unchanged. `reef.lock` regenerated against the 0.10.0 toolchain. README
/ docs / upstream-bugs current-pin references updated to chelis 0.10.0.

## [0.7.28] - 2026-06-23

Compiler-pin alignment for chelis 0.9.0. `compiler = "=0.8.0"` to
`"=0.9.0"`; CI / release / nightly workflow env vars (and the
`install-chelis` action defaults plus `scripts/install_chelis_std.py`
default tag) updated to track `v0.9.0`. Package version bumped 0.7.27
to 0.7.28. chelis-std stays `0.4.0`. No Nautilus API changes; this
release publishes artifacts built against chelis 0.9.0. Validation:
`chelis reef build` (clean, `dist/nautilus-0.7.28.{chb,tar.zst}`),
per-file `chelis check` over `src/*.ch` (score 1, no errors),
`chelis fmt --check` (clean across `src/`, `tests/`, `parity/`),
`chelis test tests/ --timeout 600 --jobs auto` (459 passed, 0 failed),
and `parity/run_parity.py --strict` (216 passed, 0 failed), all after
an immediate `chelis --version` check reporting `chelis 0.9.0`.

chelis 0.9.0 ships the verification-stack Phase 1/2 substrate, the
honest-verdict `chelis prove` taxonomy, and Deep authoring L0. Nautilus
imports only the core chelis-std surface (`Std.Test`) and uses neither
`chelis prove` nor Deep authoring, so none of the 0.9.0 feature surface
touches anything Nautilus relies on. The one observable 0.9.0 change
for this repo is the chelis#190 fix to `doc-filename-convention`
(§8.3/§8.5 now path-based, not `book.toml`-ancestor-based): the
pre-existing kebab-case `docs/*.md` filenames are now flagged by
`chelis lint --check .` — a command Nautilus does not gate on in CI.
See `docs/UPSTREAM_BUGS.md` (v0.9.0 validation block) for detail; the
docs rename is deferred as a separate documentation-hygiene change.
Part of the coordinated chelis 0.9.0 release cascade.

## [0.7.27] - 2026-06-19

Compiler-pin alignment for chelis 0.8.0. `compiler = "=0.7.27"` to
`"=0.8.0"`; CI / release / nightly workflow env vars updated to track
`v0.8.0`. Package version bumped 0.7.26 to 0.7.27. chelis-std stays
`0.4.0`. No Nautilus API changes; this release publishes artifacts built
against chelis 0.8.0. Validation: `chelis reef build`, rotating
`chelis check` on `src/special.ch`, `chelis test tests/ --timeout 600
--jobs auto` (459 passed, 0 failed), and `parity/run_parity.py
--strict` (216 passed, 0 failed), all after an immediate `chelis
--version` check reporting `chelis 0.8.0`.

## [0.7.26] - 2026-06-17

Compiler-pin alignment for chelis 0.7.27. `compiler = "=0.7.26"` to
`"=0.7.27"`; CI / release / nightly workflow env vars updated to track
`v0.7.27`. Package version bumped 0.7.25 to 0.7.26. chelis-std stays
`0.4.0`. No Nautilus API changes; this release publishes artifacts built
against chelis 0.7.27 (459 `chelis test` cases pass unchanged).

chelis 0.7.27 is chelis 0.7.26 plus a single fix (chelis#399): the eval
renderer now de-mangles ADT constructor names. Nautilus imports only the
core chelis-std surface (`Std.Test`) — no ML, no `prove`, no cross-module
ADT evaluation — so the #399 fix does not change anything Nautilus relies
on. Mechanical bump. Part of the coordinated chelis 0.7.27 release
cascade.

## [0.7.25] - 2026-06-16

Compiler-pin alignment for chelis 0.7.26. `compiler = "=0.7.21"` to
`"=0.7.26"` and `chelis-std` 0.3.0 to 0.4.0; CI / release / nightly
workflow env vars updated to track `v0.7.26`. Package version bumped
0.7.20 to 0.7.25, catching up across the chelis 0.7.22 through 0.7.25
releases Nautilus had skipped while pinned at chelis 0.7.21. No Nautilus
API changes; this release publishes artifacts built against chelis
0.7.26 (459 `chelis test` cases pass unchanged). chelis-std 0.4.0 moved
the ML modules out to the `school` package; Nautilus imports only the
core surface (`Std.Test`), so the move is transparent here. Part of the
coordinated chelis 0.7.26 release cascade.

## [0.7.20] - 2026-06-01

Compiler-pin alignment for chelis 0.7.21. `compiler = "=0.7.20"` to
`"=0.7.21"`; CI / release / nightly workflow env vars updated to track
`v0.7.21`. Package version bumped 0.7.19 to 0.7.20. No Nautilus API
changes; this release publishes artifacts built against chelis 0.7.21
(459 `chelis test` cases pass unchanged). Part of the coordinated chelis
0.7.21 release cascade.

## [0.7.19] - 2026-05-29

Compiler-pin alignment for chelis 0.7.20. `compiler = "=0.7.19"` to
`"=0.7.20"`; CI / release / nightly workflow env vars updated to track
`v0.7.20`. Package version bumped 0.7.18 to 0.7.19. No Nautilus API
changes; this release exists to publish artifacts built against the
Chelis test batching release.

chelis 0.7.20 adds default `chelis test` suite batching for eligible
test files. Nautilus keeps invoking `chelis test tests/ --jobs auto`;
the compiler now amortizes module-graph compilation inside that
default path instead of requiring shell-local batching workarounds.

### Fixed

- Closed five static-check drift items that were turning the nightly
  `tests_legacy/run_static_checks.py` job red since 2026-05-18.
  `src/apismoke.ch` was importing four modules (`Nautilus.Info`,
  `Nautilus.Optimize`, `Nautilus.StateSpace`, `Nautilus.TimeSeries`)
  that exist as `src/info.ch`, `src/optimize.ch`, `src/statespace.ch`,
  and `src/timeseries.ch` but were never registered in the
  `MODULES` table in `tests_legacy/run_static_checks.py` or the
  `exported_surface()` table in `scripts/extract_stability.py`. The
  fifth item was the `Nautilus.Stats` API table in SKILL.md
  documenting only 14 of the module's 24 exports
  (missing: `benjamini_hochberg_adjust`, `bonferroni_adjust`,
  `correlation_2x2`, `correlation_matrix_2`, `covariance_2x2`,
  `covariance_matrix_2`, `fdr_adjust`, `likelihood_ratio_p_value`,
  `likelihood_ratio_stat`, `stat_holm_adjust`). Added the four
  missing module dict entries, added four new SKILL.md §6 tables for
  the new modules, appended the ten missing Stats rows (and bumped
  the section header from `(14 exports)` to `(24 exports)`), and
  regenerated `dist/stability.json`. All new entries are marked
  `alpha`. No source or runtime behavior changes.

### Changed

- Migrated the mdBook source tree from `docs/src/` to `docs/book/src/`
  (and `docs/book.toml` to `docs/book/book.toml`) to satisfy the
  path-based `doc-filename-convention` opt-in shipped in chelis 0.7.19
  (chelis PR #244 / chelis#190). Under the new rule, §8.5 (kebab-case)
  applies only to paths whose components literally include `book`; the
  previous `docs/src/` location was reclassified as §8.3 (snake_case),
  flagging the 7 kebab-cased chapter filenames under `docs/src/`. The
  one-time migration restores §8.5 classification for the mdBook tree
  without renaming chapter files. Updates: `book.toml`
  `edit-url-template` repointed to `docs/book/src/{path}`,
  `scripts/validate_book_examples.py` walks the new path, `.gitignore`
  now excludes only the build output `docs/book/book/` rather than
  the whole `docs/book/` tree. No URL change for the published
  mdBook: relative paths inside the book are unchanged, so chapter
  URL slugs (e.g., `/getting-started/first-program.html`) remain
  stable.

  Note: the 5 top-level kebab-cased `docs/*.md` files
  (`benchmark-findings.md`, `eval-startup-findings.md`,
  `maintenance-schedule.md`, `nautilus-status.md`, `upstream-bugs.md`)
  and the 2 issue bodies subsequently filed as chelis#189 and chelis#190
  remained §8.3 violations under chelis 0.7.19. Those were intentionally out
  of scope for this migration (resolution path (a) per the 0.7.18 release
  note); the filed issue-body duplicates were later excised, while top-level
  filename cleanup remains tracked separately.

## [0.7.18] - 2026-05-26

Compiler-pin alignment for chelis 0.7.19. `compiler = "=0.7.18"` to
`"=0.7.19"`; CI / release / nightly workflow env vars updated to track
`v0.7.19`. Package version bumped 0.7.17 to 0.7.18. No nautilus source
changes; this release exists to publish nautilus artifacts built
against the latest chelis hotfix line.

chelis 0.7.19 is a six-fix release (all bug fixes, no API breakage):

- chelis#188 / chelis PR #241: bump GitHub Actions to Node-24-compatible
  versions. Pure CI hygiene; no behavior change for downstream
  consumers.
- chelis#189 / chelis PR #243: backend-c emits f32 / f64 constants via
  bit pattern instead of a lossy format string. Closes a silent
  precision-loss path in generated C code.
- chelis#190 / chelis PR #244: `doc-filename-convention` lint switches
  from `book.toml`-ancestor-walk to a path-based opt-in (a path is
  mdBook content iff one of its components is the literal name
  `book/`). Removes the retroactive-flip footgun where dropping or
  removing `book.toml` flipped every `docs/*.md` between snake_case
  and kebab-case. See "Known regression" below.
- chelis#197 / chelis PR #245: AD CLI routes `grad` through
  `grad_dag_checked`; `Floor`, `Ceil`, `Argmax`, `Argmin` emit
  `AdError::NotSupported` instead of silently returning zero gradients.
- chelis#207 / chelis PR #246: `chelis check` exits non-zero when
  errors are present (previously exit 0 with errors reported on
  stderr).
- chelis#208 / chelis PR #242: runtime shape semantics §4.7 documented.
  Spec-only; no code change.

### Known regression: doc-filename-convention path-based opt-in

chelis 0.7.19's #190 fix changes which files are linted as mdBook
content. Before: any `*.md` under a directory tree containing a
`book.toml` (nautilus has `docs/book.toml`) was treated as mdBook
content and allowed kebab-case. After: only paths with a literal
`book/` component are mdBook content.

Effect on this repo: 14 kebab-case markdown files under `docs/` are now
flagged by `chelis lint --check .`:

- `docs/{benchmark-findings,eval-startup-findings,maintenance-schedule,nautilus-status,upstream-bugs}.md`
- `docs/src/distributions/{gamma-family,other-continuous}.md`
- `docs/src/finance/{black-scholes,monte-carlo}.md`
- `docs/src/getting-started/first-program.md`
- `docs/src/linalg/{cg-solve,small-n}.md`
- the issue body subsequently filed as chelis#189
- the issue body subsequently filed as chelis#190

`chelis lint --check .` exits non-zero on this repo at chelis 0.7.19.
Nautilus CI does not gate on `chelis lint --check`, so the release
workflow is not blocked. Resolution path is one of: (a) move
`docs/src/` to `docs/book/src/` (and `docs/book.toml` to
`docs/book/book.toml`) so the mdBook tree is path-based opt-in; (b)
rename each kebab `*.md` to snake_case and update `docs/src/SUMMARY.md`
cross-references; (c) excise the top-level kebab docs that are not
mdBook content. Deferred to a follow-up PR; tracked separately from
this release-alignment PR.

### chelis 0.7.19 fixes pulled in

- chelis#188: GitHub Actions Node-24 bump.
- chelis#189: backend-c f32 / f64 bit-pattern emission.
- chelis#190: `doc-filename-convention` path-based opt-in (see Known
  regression).
- chelis#197: AD CLI grad checked; Floor/Ceil/Argmax/Argmin emit
  NotSupported.
- chelis#207: `chelis check` exits non-zero on errors.
- chelis#208: runtime shape semantics docs.

### Verified

`chelis reef build` clean against chelis 0.7.19. `chelis check` on all
25 `src/*.ch` files: score=1, errors=[] on every file. `chelis test
tests/ --jobs auto`: 459 passed, 0 failed (unchanged from 0.7.17).
`python3 parity/run_parity.py --strict`: 216 passed, 0 failed
(unchanged from 0.7.17). `chelis lint --check .`: exit 1, 14 blocking
`doc-filename-convention` errors (see Known regression above), 172
advisory warnings (unchanged from 0.7.17).

## [0.7.17] - 2026-05-25

Compiler-pin alignment for chelis 0.7.18. `compiler = "=0.7.16"` to
`"=0.7.18"`; CI / release / nightly workflow env vars updated to track
`v0.7.18`. Package version bumped 0.7.16 to 0.7.17. No nautilus source
changes; this release exists to publish nautilus artifacts built
against the latest chelis hotfix line.

chelis 0.7.18 is chelis 0.7.16 plus two stacked releases:

- chelis 0.7.17 (PRs #234, #236, #238): final removal of the
  `module-pascal-components` lint rule (already advisory-only since
  0.7.16), `chelis prove` lowered-root-count mismatch fix
  (chelis#232 / PR #236), and `argmax_reduce` / `argmin_reduce`
  host-runtime storage widened to `int64` (chelis#233 / PR #238).
- chelis 0.7.18 (PR #239): zero-offset spurious-consume linearity
  sweep across consumer classes (chelis#237 + chelis#229). Closes the
  remaining class of `UseAfterConsume` false positives that the
  chelis#226 hotfix in nautilus 0.7.14 addressed for `Std.Nn.Embedding`
  specifically.

### chelis 0.7.17 / 0.7.18 fixes pulled in

- chelis#232 / chelis PR #236: `chelis prove` was reporting a lowered
  root count that did not match the prover's actual roots. Fixed.
- chelis#233 / chelis PR #238: `argmax_reduce` and `argmin_reduce`
  output dtype on the host runtime was narrower than the IR-declared
  `int64`. Widened to match. Builds on the chelis#230 hotfix from
  nautilus 0.7.14 (which closed the same gap for `argmax_reduce`
  specifically); 0.7.17 generalizes the fix and adds `argmin_reduce`
  coverage.
- chelis#237 + chelis#229 / chelis PR #239: zero-offset accesses into
  a consumed tensor were producing spurious `UseAfterConsume`
  diagnostics across multiple consumer classes (not just
  `Std.Nn.Embedding`, which chelis#226 had patched at v0.7.14).
  Sweep-fix in 0.7.18. Not a current nautilus consumer pattern, but
  unblocks future shells that route through the affected primitives.
- chelis PR #234: removed the `module-pascal-components` lint rule
  entirely. Advisory-only since 0.7.16; full deletion in 0.7.17
  closes the rule lifecycle.

### Verified

`chelis reef build` clean; `chelis check` clean on all `src/` files;
`chelis test tests/ --jobs auto` results recorded in the PR;
`python3 parity/run_parity.py --strict` results recorded in the PR;
`chelis lint --check .` results recorded in the PR.

## [0.7.16] - 2026-05-25

Formatter follow-up for chelis 0.7.16. Canonicalizes the remaining
`Nautilus.Optim` and `Nautilus.Special` files that the stricter
`chelis check` gate now rejects when they are not exactly formatted.

## [0.7.15] - 2026-05-25

FlukeBall support release. Adds the minimal analytics surface needed by
Whale and downstream football experiments: information metrics,
optimization compatibility, state-space helpers, and time-series
primitives. This release also retargets CI, release, and package pins to
chelis 0.7.16 so downstream shells can consume the new `Std.Index`,
`Std.Scan`, and `Std.Sort` wrappers from the bundled standard library.

## [0.7.14] — 2026-05-24

Compiler-pin alignment for chelis 0.7.15 (skipping the 0.7.11 and
0.7.12 pins at the consumer level: both were nautilus cleanup
releases that intentionally kept the chelis pin at `=0.7.10`, so this
is a single five-version catch-up jump mirroring the 0.7.8 → 0.7.10
release pattern). `compiler = "=0.7.10"` → `"=0.7.15"`; CI/release
workflow env vars updated to track `v0.7.15`. Package version bumped
0.7.13 → 0.7.14 because the `v0.7.13` nautilus GH release artifact
already exists (built against chelis 0.7.10), so the new tag cannot
reuse `0.7.13`.

chelis 0.7.15 is chelis 0.7.13 + chelis#226 hotfix + chelis#230
argmax_reduce output-dtype hotfix. All other behavior identical to
0.7.13; the fix-set below is the chelis 0.7.13 surface preserved
through 0.7.14/0.7.15.

### chelis 0.7.13 / 0.7.14 / 0.7.15 fixes pulled in

- chelis#186 / chelis PR #205: `conv2d` validator was rejecting every
  well-formed call. Not a current nautilus consumer, but unblocks
  future shells that route through nautilus's signal/filtering surface.
- chelis#187 / chelis PR #214: `shrink`, `stride`, and `pad` are now
  callable from Surf. Frees nautilus's signal-processing roadmap from
  hand-rolled slicing helpers.
- chelis#199 Part 1 / chelis PR #211: `BlasMatmul` gradient rule.
  Part 2 (`to_tensor` inside differentiable bodies) deferred to
  chelis#218; nautilus does not currently call `to_tensor` from a
  `grad(...)` body, so Part 2 is non-blocking for this release.
- chelis#206 / chelis PR #213: runtime-dim `reshape` now preserves
  the declared symbolic shape on its output. Tightens type information
  for any nautilus path that reshapes a runtime-dim tensor; no current
  consumer was relying on the prior weakening.
- chelis#209 / chelis PR #210: lint em-dash UTF-8 boundary panic is
  fixed. nautilus's `chelis lint --check .` no longer crashes when
  CHANGELOG.md em-dashes are processed at certain byte boundaries.
- chelis#185 / chelis PR #217: host-runtime arms wired up for 14
  builtins plus an invariant lock. Closes a class of "compiles but
  panics at runtime" gaps in the host backend.
- chelis#226: spurious `UseAfterConsume` in `Std.Nn.Embedding.forward`
  during reef-resolve linearity analysis. Surfaced by a sibling shell's
  cascade attempt and rolled into 0.7.14 as a point hotfix on top of
  0.7.13. Not a current nautilus consumer (no `Std.Nn.Embedding` use
  in src/), included here for completeness of the upstream surface.
- chelis#230: `argmax_reduce` output dtype regression — fixed in
  chelis 0.7.15 as a surgical hotfix on top of 0.7.14. Surfaced by
  the hydronnx PR #2 ArgMax compile-run-parity test. Not a current
  nautilus consumer; included for completeness of the upstream
  surface.
- chelis PR #221: end-to-end Hydronnx H3 acceptance shapes are locked
  in chelis CI. Not nautilus-facing, but the locked oracle is durable
  evidence the 0.7.13/0.7.14 surface is stable end-to-end.

### Verified

`chelis reef build` clean; `chelis check` clean on all `src/` files;
`chelis test tests/ --jobs auto` → 441 passed, 0 failed;
`python3 parity/run_parity.py --strict` → 216 passed, 0 failed;
`chelis lint --check .` → 0 errors, advisory warnings unchanged from
0.7.12 (`prefer-pipe-operator` / `redundant-linearity-call` retained
inside plateau-stop-containing functions per the 0.7.12 WS-A
discipline). Local verification was performed against the chelis
0.7.13 binary; chelis 0.7.15 differs only by the chelis#226 and
chelis#230 hotfixes, neither of which is exercised by any nautilus
source file.

## [0.7.12] — 2026-05-22

Cleanup-wave release. No compiler-pin change (still `=0.7.10`).
Closes the warning regression from the 0.7.10 lint-fix that was lost
during pristine-source verification, extends the `Nautilus.Roots`
plateau-stop discipline (shipped in 0.7.11) to three more iterative
modules as defense-in-depth, replaces the 0.7.10 CHANGELOG's
"tracked upstream" placeholder with concrete chelis-repo issue
references for the f32 evaluator/C-backend divergence and the
`doc-filename-convention` design wart, and adds a CI maintenance
schedule for the Node 20 → Node 24 GitHub Actions migration.

### Changed: re-applied lost `chelis lint --fix` cleanup on `optim.ch` / `special.ch`

The 0.7.10 release shipped with the `chelis lint --fix` cleanup applied
across most of `src/`, but during pristine-source verification of the
0.7.10 f32-hardening bug, `src/optim.ch` and `src/special.ch` were
reverted to HEAD and never re-lint-fixed. 0.7.10 therefore carried 85
extra advisory warnings (14 in `optim.ch` + 71 in `special.ch`, all
`prefer-pipe-operator`) on top of the warning floor the 0.7.10 release
notes implied.

Re-applied `chelis lint --fix` to those two files only, under the
strict discipline that **no f32-hardening / NaN-handling / plateau-stop
/ tolerance-floor line may change byte-for-byte**. Where `chelis lint
--fix` semantically rewrote a function containing a plateau-stop site
(per the WS-A do-not-touch inventory: `optim.ch` lines 19, 28–29, 44,
73, 87, 105, 141, 149, 156, 163; `special.ch` lines 556–573, 575–592,
655–656, 672–673), that function was reverted whole and its advisory
warnings retained. The NaN-producing primitives `opt_nan_f32()`,
`pos_inf()`, `neg_inf()`, `nan_f32()` were likewise preserved verbatim.

Final state: `chelis lint --check src/` → **214 advisory warnings**
(down from 273; expected drop ≈80, actual drop 59, the gap being the
26 warnings stuck inside the seven plateau-stop-containing functions
that had to be reverted whole: `opt_gs_rec`, `opt_brent_rec`,
`opt_gd_rec`, `airy_f_rec`, `airy_g_rec`, `ellip_agm_a_rec`,
`ellip_agm_csum_rec`). All 438 tests + 216 parity samples remain
green. The 0.7.10 release notes (line 98 above) overstated the
cleanup state by 1 (273 actual vs 272 claimed) in addition to the
85-warning regression now closed here.

### Changed: structural f32-plateau-stop hardening for three iterative modules

Extends the `Nautilus.Roots` plateau-stop discipline (shipped in 0.7.11)
to the three other recursive numeric kernels surfaced by the WS-B audit:

- `Nautilus.CurveFit` `lm1_rec`: adds `eq(theta_next, theta)` plateau
  check ahead of the existing `lt(abs_delta, tol)` convergence test.
- `Nautilus.Ode` `rk45_adaptive_rec`: adds `eq(y_next, y)` plateau
  check in the accepted-step branch, after the existing
  `lt(|t_end - t_next|, tiny_h)` terminal-step short-circuit.
- `Nautilus.Integrate` `adaptive_simpson_rec`: adds
  `plateau = eq(sum_lr, whole)` to the existing
  `or(converged, exhausted)` exit condition. The pre-existing
  `tol_floor = cast(0.0000001, f32)` (L88) on the recursed half-tol is
  retained.

Unlike `Nautilus.Roots`'s iter-exhaustion which returns `r_nan_f32()`
(making the plateau-stop a true correctness fix under sub-ULP tol),
these three modules' iter/depth-exhaustion fallbacks already return
the current iterate (`theta` for lm1, `y` for rk45, `sum_lr +
correction` for adaptive Simpson). Because the iterate at the f32
fixed point is stable, exhaustion returns the same value the plateau
short-circuit would. The hardening is therefore structural
defense-in-depth: it aligns these modules with the `roots.ch` style,
short-circuits unnecessary iterations once the iterate plateaus at
f32 resolution, and provides a regression hook against future
weakening of the iter-exhaust semantics.

Per-module sub-ULP regression tests added (passing) that exercise
the hardened path under adversarial (NaN/zero) tolerances:

- `tests/curvefit.ch::test_lm1_sub_ulp_tol_plateau_locks_fixed_point`
- `tests/ode.ch::test_rk45_sub_ulp_step_plateau_locks_iterate`
- `tests/integrate.ch::test_adapt_sub_ulp_tol_plateau_terminates_sum`

These tests pass with the hardening in place; they also pass without
it, because in these three modules iter/depth-exhaustion already
returns the f32-plateau iterate. They function as regression
guards rather than differential-failure tests. See the WS-B report
for the full analysis.

`tol_floor` literal source: `src/roots.ch:62-63`,
`tol_floor = cast(0.000001, f32)` / `tol_eff = if lt(tol, tol_floor)
then tol_floor else tol`. Not introduced into curvefit or ode this
wave (their convergence checks compare iterate-deltas, which the
plateau check subsumes for positive tol); integrate.ch retains its
pre-existing distinct `tol_floor = cast(0.0000001, f32)` at L88,
which guards the recursed half-tol rather than the top-level
convergence check.

### Verified

`chelis test tests/ --jobs auto` → 441 passed (was 438; +3 new
sub-ULP tests), 0 failed; `python3 parity/run_parity.py --strict` →
216 passed, 0 failed; `chelis lint --check .` → 274 advisory
warnings (unchanged from main; all `prefer-pipe-operator`, none
introduced by this wave).

## [0.7.11] — 2026-05-22

f32-plateau hardening for `Nautilus.Roots` — the structurally-identical
robustness fix the 0.7.10 cleanup applied to `Nautilus.Optim` and
`Nautilus.Special` but missed for `Nautilus.Roots`. No compiler-pin
change (still `=0.7.10`).

### Fixed — `bisection`/`newton`/`brent` could return `NaN` on valid brackets under sub-ULP tolerances

`Nautilus.Roots`'s three root-finders previously had only
`lt(width, tol)` / `lt(afx, tol)` convergence checks plus an
iters-exhausted `r_nan_f32()` fallback. With a tolerance below the
f32 ULP near the root (e.g. `tol = 1e-8` near √2, where the f32
gap is ~1.2e-7), neither convergence check can ever fire — the
iteration plateaus above `tol`, exhausts its iteration budget, and
returns `NaN`. A correct bisection should never `NaN` on a valid
bracket; this is a real robustness bug. Hardened:

- `bisection_rec`: stops when the midpoint coincides with either
  bracket endpoint in f32 (`eq(mid, lo)` or `eq(mid, hi)`) — the
  f32-plateau signal that no further bisection is possible — and
  returns `mid` as the best estimate.
- `newton_rec`: stops when the Newton step produces no change in
  f32 (`eq(x_next, x)`), returning `x_next`.
- `brent_rec`: adds a `tol_floor = 1e-6` (the smallest realistic
  f32 tolerance) so the existing `lt(awidth, tol_eff)` /
  `lt(afb1, tol_eff)` checks always reach a representable bound,
  plus an `eq(s, b1)` plateau check after candidate selection.

The 0.7.10 release shipped with these unhardened. The new
`Nautilus.Roots` returns f32-plateau-best estimates accurate to
~1 ULP (≈ 1e-7 near typical roots) — well within any realistic
test tolerance.

### Verified

Pinned still at chelis `=0.7.10`. `chelis reef build` clean;
`chelis check src/roots.ch` → score 1, 0 errors; `chelis test
tests/roots.ch` → 13 passed, 0 failed (unchanged from 0.7.10);
`chelis test tests/ --jobs auto` → 438 passed, 0 failed (full
suite); `python3 parity/run_parity.py --strict` → 216 passed, 0
failed.

## [0.7.10] — 2026-05-15

Compiler-pin alignment for chelis 0.7.10 (skipping the 0.7.9 pin at
the consumer level — chelis 0.7.9 shipped a `chelis test` lowering
blocker that 0.7.10 fixed). `compiler = "=0.7.8"` → `"=0.7.10"`,
CI/release workflow env vars updated to track v0.7.10. This release
also pays down the latent unsoundness that chelis 0.7.9's tightened
checks surfaced, plus f32 numeric hardening exposed by 0.7.10's
evaluator.

### Fixed — dim-parameter rigidity violation (chelis 0.7.9 `check_declared_dvars_rigid`)

`apismoke.ch`'s `smoke_linalg[m, k, n]` fed `at: tensor[k, m, f32]`
(a rectangular transpose) into `trace_scalar[n](&tensor[n, n, f32])`,
which unified the declared-distinct dims `k` and `m`. chelis 0.7.9
made declared dim parameters rigid within a def body and correctly
rejects this. Routed the trace through the square
`aat_mat: tensor[m, m, f32]`; `at` still exercises `transpose`. No
test depended on the unsound path.

### Fixed — linearity violations in linalg SVD/eig (chelis 0.7.9 stricter linearity)

`linalg.ch`'s `la_svd_rot_g`, `la_svd_rot_v`, `svd_n`,
`la_eig_rot_a`, `la_eig_rot_q`, and `eig_n` had 17 `UseAfterConsume`
errors under chelis 0.7.9 — values consumed by closure capture or by
the by-value `tpl` parameters of `la_svd_g_sw` / `la_eig_a_sw`, then
reused. These six functions are reverted to their pristine pre-0.7.8
form, which carries the explicit `copy()` calls the consume sites
require. (Those `copy()` calls now show as advisory
`redundant-linearity-call` warnings — see lint note below.)

### Fixed — f32 optimizer and elliptic-integral recurrences (chelis 0.7.10 evaluator)

chelis 0.7.10's f32-preserving evaluator exposed unit-roundoff stalls
in scalar numeric code that the prior double-promoting evaluator
masked. `optim.ch`: golden-section and Brent now stop on equal
objective samples; gradient descent and Newton stop when the iterate
no longer changes. `special.ch`: the elliptic AGM helpers stop when
`a`/`b` plateau before the weight term can explode. With these,
`newton_minimize_1d` converges (it was reaching `NaN`) and
`golden_section_search` lands inside tolerance.

### Changed — lint cleanup + doc renames

`chelis lint --fix` auto-fixes (`redundant-linearity-call`,
`prefer-pipe-operator`) applied across `src/` and `tests/`. Final
state under chelis 0.7.10: `chelis lint --check .` → **0 errors, 272
advisory warnings** (all `redundant-linearity-call` /
`prefer-pipe-operator`, concentrated in the six reverted linalg
functions and in `optim.ch` / `special.ch`, where the f32 hardening
took priority over cosmetic pipe rewrites). Five `docs/` files
renamed from SCREAMING_SNAKE_CASE to kebab-case to satisfy
`doc-filename-convention §8.5`; em-dash fixes in `scripts/`.

### Verified

`chelis reef build` clean; `chelis check` clean across all 21
`src/*.ch`; `chelis test tests/ --jobs auto` → 438 passed, 0 failed;
`python3 parity/run_parity.py --strict` → 216 passed, 0 failed.

### Tracked upstream (not blocking)

chelis 0.7.10's scalar-f32 evaluator preserves the source f64 value
verbatim (its internal `TensorValue.data` is `Vec<f64>`), while the C
backend quantizes scalar-f32 constants via an `as f32` cast composed
with a `%.8` format string in `emit_const`, dropping precision before
the C compiler ever sees the literal. The two paths therefore disagree
on small-magnitude f32 constants (e.g., `1.23456789e-7` becomes
`1.19999996e-7` on the C side, a ~3% drift). The f32 hardening above
makes nautilus robust either way, but the divergence is a chelis
soundness item filed at
[Chelis-Lang/chelis#189](https://github.com/Chelis-Lang/chelis/issues/189).

Separately, the `doc-filename-convention` lint rule's §8.3 vs §8.5
dichotomy retroactively flips every `docs/*.md` correctness verdict
when a `book.toml` is added or removed in any ancestor directory.
nautilus's 0.7.10 SCREAMING_SNAKE→kebab rename was a direct
consequence of this footgun. Filed for design discussion at
[Chelis-Lang/chelis#190](https://github.com/Chelis-Lang/chelis/issues/190).

The full reasoning was filed upstream in chelis#189 and chelis#190; canonical
citations use those issue numbers.

## [0.7.9] — 2026-05-13

Compiler-pin alignment release for chelis 0.7.8. No source changes
from 0.7.8 — only the `compiler = "=0.7.7"` → `"=0.7.8"` pin bump,
package version bump to 0.7.9, and CI/release workflow env vars
updated to track v0.7.8. Required because chelis 0.7.8's reef
validator rejects any package whose `package.compiler` is not exactly
`=0.7.8`. The 0.7.8 source cleanup re-verified under 0.7.8 with
zero failures (438/438 native tests, 216/216 scipy-parity samples).

## [0.7.8] — 2026-05-13

Source cleanup pass against the chelis 0.7.7 toolchain pin. No
behavioral change — `chelis reef build`, all 438 native tests, and
all 216 scipy-parity samples remain green. The change set strips
migration scaffolding that the chelis 0.7.6 → 0.7.7 bump made
formally redundant:

- **Drop strip:** 902 `_ = drop(<expr>)` statement lines removed
  across `src/` and `tests/`. Under chelis 0.7.7 implicit linearity
  the compiler inserts the corresponding IR drop node, so the source
  call is redundant (flagged by `chelis lint --rule
  redundant-linearity-call`). Drop statements have unit-typed RHS
  and ignore the result, so removing them is type-preserving.
- **Borrow-orphan collapse:** 462 `__borrow_migration_out_N = <expr>`
  / `__borrow_migration_out_N` bind-then-reference pairs collapsed
  to bare `<expr>`. With the drop statements gone these pairs were
  pure scaffolding.
- **Pipe-operator rewrites (conservative subset):** mechanical
  `f(g(x), …)` → `g(x) |> f(…)` rewrites applied to 21 sites across
  `src/{distance,integrate,testing}.ch` where every non-first
  argument is a simple name/literal AND the rewrite survives a
  whole-package `chelis reef build`. Sites in other modules were
  attempted by the same rewriter and reverted because they failed
  `reef build` cross-module type-check; lifting those to named
  bindings is a separate refactor and left for follow-up. See
  `docs/UPSTREAM_BUGS.md` for the reasoning.
- **`chelis fmt --inplace`** on `src/{curvefit,distributions,integrate,
  interpolation,linalg,ode}.ch`, which were not canonically formatted
  under 0.7.7's stricter `fmt --check` gate.
- **`copy()` calls retained as-is.** The `redundant-linearity-call`
  rule also flags source-level `copy()` calls but the chelis 0.7.7
  compiler does not auto-insert the borrow→owned conversion they
  perform; stripping them breaks the type-check. Documented as an
  upstream issue.

## [0.7.7] — 2026-05-12

Compiler-pin alignment release for chelis 0.7.7. No source changes —
only the package version and the `compiler = "=0.7.6"` → `"=0.7.7"`
pin bump, plus CI/release workflow env updates to track the new
chelis tag. Required because chelis 0.7.7's reef validator rejects
any package whose `package.compiler` field is not exactly `=0.7.7`.

chelis 0.7.7 itself closes the implicit-copy fan-out gap (Item 1
v2), the deep-user-symbol-charset CLOSED_TAGS gap (Item 3), the
module-pascal-components ecosystem allowlist (Item 4), and the
Linearity-F3 module-wrapped linearity skip. nautilus's existing
source passes `chelis check` and `chelis lint --check src/` with
zero error-severity findings under 0.7.7.

## [0.6.1] — 2026-05-06

Compiler-pin alignment release. Tracks chelis 0.6.0 → 0.6.1
(bootstrap-list patch). No source changes — only the package
version bump and the `compiler = "=0.6.0"` → `"=0.6.1"` pin.
Required because chelis 0.6.0's source tree shipped pre-rename
chelis-std-0.1.0 artifacts; chelis 0.6.1 ships the post-rename
chelis-std-0.2.0 artifacts that downstream consumers need.

## [0.6.0] — 2026-05-06

Naming-convention release. Aligns nautilus with the recorded style
guide in `chelis/spec/01-nomenclature.md`. Track-forward for chelis
0.6.0 / chelis-std 0.2.0.

### Changed (breaking) — module renames per §6.3 PascalCase per component

Six example modules renamed from lowercase-after-first compounds to
proper PascalCase:

| Old                              | New                              |
|----------------------------------|----------------------------------|
| `Nautilus.Examplerootfind`       | `Nautilus.ExampleRootFind`       |
| `Nautilus.Exampleodedemo`        | `Nautilus.ExampleOdeDemo`        |
| `Nautilus.Exampledistributions`  | `Nautilus.ExampleDistributions`  |
| `Nautilus.Exampleintegration`    | `Nautilus.ExampleIntegration`    |
| `Nautilus.Exampleoptim`          | `Nautilus.ExampleOptim`          |
| `Nautilus.Apismoke`              | `Nautilus.ApiSmoke`              |

On-disk filenames are unchanged (forced lowercase by §1.2 module-path
mapping). Downstream `import Nautilus.Examplerootfind ...` etc. must
update to the new names.

### Changed (breaking) — module renames per §6.2 Title-case compounds

Two ALL-CAPS abbreviation modules renamed to Title-case:

| Old              | New              |
|------------------|------------------|
| `Nautilus.ODE`   | `Nautilus.Ode`   |
| `Nautilus.SDE`   | `Nautilus.Sde`   |

Plus `Nautilus.Tests.{ODE,SDE}` → `Nautilus.Tests.{Ode,Sde}`.
Downstream callers must update their imports.

### Changed — `install_chelis_std.sh` ported to Python

Per §2.9 (no shell scripts; Python only). The script is now
`scripts/install_chelis_std.py`, invoked as
`python3 scripts/install_chelis_std.py` from CI.

### Changed — compiler pin bumped to `=0.6.0`

`reef.toml` now requires chelis 0.6.0 and chelis-std 0.2.0.
Downstream consumers must bump their pins to match.

### Style guide

Adheres to `chelis/spec/01-nomenclature.md` (the recorded style
guide). The local `STYLE.md` is a one-line pointer at the central
guide. The `la_*` private-helper prefix in `Nautilus.LinAlg`
remains, recognized as the module's domain shorthand under §7.1
(`la` = initials of `LinAlg`).

The math/algorithm prefixes `airy_/beta_/chi_/cg_/det_/eig_/inv_/
lm_/erf_` are recognized as §7.1.1 model/algorithm sub-namespaces.
