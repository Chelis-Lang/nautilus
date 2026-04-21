# Installation

## Prerequisites

Nautilus requires:
- the latest validated Chelis release, currently [Chelis v0.1.16](https://github.com/Chelis-Lang/chelis/releases/tag/v0.1.16)
- GCC (for compiling generated C code)
- Python 3.10+ with numpy and scipy (for running the test suite)

## Download the Chelis toolchain

```sh
gh release download v0.1.16 \
  --repo Chelis-Lang/chelis \
  --pattern 'chelis-v0.1.16-linux-x86_64.tar.gz'
tar xzf chelis-v0.1.16-linux-x86_64.tar.gz
export PATH="$PWD/chelis-v0.1.16-linux-x86_64/bin:$PATH"
```

The tarball contains `bin/chelis`, `lib/libchelis_runtime.a`, and
`include/chelis_runtime.h`.

## Clone and build Nautilus

```sh
git clone https://github.com/Chelis-Lang/nautilus.git
cd nautilus
chelis reef build
```

This produces `dist/nautilus-0.1.2.chb`, the reef package that other
Chelis projects can depend on.

## Verify the installation

```sh
# Type-check all modules
for f in src/*.ch; do chelis check "$f"; done

# Run the scipy-parity test suite (requires numpy + scipy)
pip install numpy scipy
python tests/run_numeric_tests.py
```

You should see `895 / 895 numerical assertions passed`.

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
