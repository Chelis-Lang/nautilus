# Installation

## Prerequisites

Nautilus requires:

- Chelis 0.17.5 for the Nautilus 0.7.37 release preparation; it is not yet
  published or validated, so Nautilus 0.7.36 with the published
  [Chelis 0.17.4](https://github.com/Chelis-Lang/chelis/releases/tag/v0.17.4)
  toolchain remains the installable baseline
- GCC (for compiling generated C code)
- uv and Python 3.12 for the isolated parity project

## Install the Chelis toolchain

```sh
chelisup install 0.17.5  # only after the official release is published
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

This produces `dist/nautilus-0.7.37.chb`, the reef package that other
Chelis projects can depend on.

## Verify the installation

```sh
# Type-check all modules
for f in src/*.ch; do chelis check "$f"; done

# Run the native identity / structural test gate (463 tests)
chelis test tests/ --jobs auto

# Verify rejection contracts and current upstream blockers
chelis test tests_neg/ --expect neg
chelis test tests_blocked/ --expect blocked

# Serial fallback for debugging
chelis test tests/ --jobs 1

# Validate against the reviewed SciPy goldens in the locked uv project
uv sync --project parity --frozen
uv run --project parity --frozen python parity/run_parity.py --strict
```

You should see `463 passed, 0 failed` from `chelis test`, and
`parity totals: 216 passed, 0 failed` from the parity oracle.

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
