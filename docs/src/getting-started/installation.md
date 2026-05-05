# Installation

## Prerequisites

Nautilus requires:
- the latest validated Chelis release, currently [Chelis 0.5.0](https://github.com/Chelis-Lang/chelis/releases/tag/v0.5.0)
- GCC (for compiling generated C code)
- Python 3.10+ with numpy and scipy (for the scipy-parity oracle in `parity/`)

## Download the Chelis toolchain

```sh
gh release download v0.5.0 \
  --repo Chelis-Lang/chelis \
  --pattern 'chelis-v0.5.0-linux-x86_64.tar.gz'
tar xzf chelis-v0.5.0-linux-x86_64.tar.gz
export PATH="$PWD/chelis-v0.5.0-linux-x86_64/bin:$PATH"
```

The tarball contains `bin/chelis`, `lib/libchelis_runtime.a`, and
`include/chelis_runtime.h`.

## Clone and build Nautilus

```sh
git clone https://github.com/Chelis-Lang/nautilus.git
cd nautilus
chelis reef build
```

This produces `dist/nautilus-0.5.0.chb`, the reef package that other
Chelis projects can depend on.

## Verify the installation

```sh
# Type-check all modules
for f in src/*.ch; do chelis check "$f"; done

# Run the native identity / structural test gate (438 tests)
chelis test tests/

# Run the scipy-parity oracle (requires numpy + scipy)
pip install numpy scipy
python parity/run_parity.py --strict
```

You should see `438 passed, 0 failed` from `chelis test`, and
`parity totals: 216 passed, 0 failed` from the parity oracle.

If your `chelis` binary is not on `PATH`, set `CHELIS_BIN=/abs/path/to/chelis`
when running the Python validation scripts.

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
