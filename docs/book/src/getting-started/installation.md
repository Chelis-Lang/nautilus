# Installation

## Prerequisites

Nautilus requires:

- the Chelis toolchain version pinned in `reef.toml` (currently
  [Chelis 0.18.11](https://github.com/Chelis-Lang/chelis/releases/tag/v0.18.11))
- a C compiler such as GCC or Clang, for the generated C code
- uv and Python 3.12 for the isolated parity project

## Install the Chelis toolchain

```sh
chelisup install 0.18.11
```

`chelisup` installs releases side by side. Its `chelis` shim resolves the
version from the nearest `reef.toml`; never replace it with a fixed symlink.

## Clone and build Nautilus

```sh
git clone https://github.com/Chelis-Lang/nautilus.git
cd nautilus
chelis reef setup
chelis reef build
```

This produces `dist/nautilus-X.Y.Z.chb`, where `X.Y.Z` is the version in
`reef.toml`: the Reef package that other Chelis projects can depend on.

## Verify the installation

```sh
# Type-check all modules
for f in src/*.ch; do chelis check "$f"; done

# Run the native identity / structural test suite
chelis test tests/ --jobs auto

# Verify that invalid programs are still rejected
chelis test tests_neg/ --expect neg

# Serial fallback for debugging
chelis test tests/ --jobs 1

# Validate against the reviewed SciPy goldens in the locked uv project
uv sync --project parity --frozen
uv run --project parity --frozen python parity/run_parity.py --strict
```

Every test should pass, and the parity oracle should report
`parity totals: 216 passed, 0 failed`. When `tests_blocked/` contains
reproducers of upstream compiler limitations, `chelis test tests_blocked/
--expect blocked` confirms each still fails with its recorded diagnostic;
it currently contains none.

Ensure the `chelisup` shim is on `PATH` so parity probes resolve the reef-pinned
toolchain.

## Using Nautilus in your project

Add Nautilus as a reef dependency in your project's `reef.toml`:

```toml
[dependencies]
nautilus = { path = "../nautilus" }
```

Then import the modules you need:

```chelis-fragment
import Nautilus.Special (erf, erfinv)
import Nautilus.Distributions (normal_cdf, normal_inv_cdf)
```
