# Changelog

All notable changes to this project are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
