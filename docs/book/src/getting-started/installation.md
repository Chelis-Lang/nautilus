# Installation

Nautilus 0.7.48 is a Reef package for Chelis 0.18.13. Reef installs the package
for use from your own Chelis project. The commands below build and install the
package from this repository's source.

## Install the toolchain

Sign in with the GitHub CLI (`gh`) for the release download, then install `chelisup` and the version
Nautilus pins:

```sh
gh auth login
gh release download --repo Chelis-Lang/chelis --pattern chelisup.sh --output - | sh
export PATH="$HOME/.chelis/bin:$PATH"
chelisup install 0.18.13
chelis --version
```

The version command should print `chelis 0.18.13`. If you already have
`chelisup`, start with `chelisup install`. `chelisup` keeps versions side by
side, and its `chelis` command selects the exact compiler named in a nearby
`reef.toml`.

## Install Nautilus

```sh
mkdir -p nautilus-work/packages
git clone https://github.com/Chelis-Lang/nautilus.git nautilus-work/packages/nautilus
cd nautilus-work/packages/nautilus
chelis reef setup
chelis reef build
chelis reef install --from-monorepo ../.. nautilus
cd ../..
```

The install command copies the built artifacts into your local Reef registry.
It does not add Nautilus to a project's dependencies. To install a published
release instead, read its tagged `reef.toml` for the compiler and package
versions, then use `chelis reef install --from-github
Chelis-Lang/nautilus@vX.Y.Z` with that tag. Reef's GitHub installer requires
`GITHUB_TOKEN` or a working `gh auth token`, even for a public release.

Create a project with the same compiler:

```sh
chelis reef init demo --module-prefix Demo --output demo
cd demo
```

In the generated `reef.toml`, add this line under the existing
`[dependencies]` table:

```toml
nautilus = { version = "0.7.48" }
```

Keep the generated `compiler = "=0.18.13"` pin. Continue with
[Your first Nautilus program](first-program.md) to evaluate a calculation.

## Work from a source checkout

The clone above is also the development checkout. `chelis reef build` writes
`dist/nautilus-0.7.48.chb` and a source archive; it does not produce an
executable. The [maintainer guide](https://github.com/Chelis-Lang/nautilus/blob/main/docs/maintainer_guide.md)
has the native tests and optional SciPy parity commands. Parity needs uv and
Python 3.12; ordinary use of the Reef package does not.
