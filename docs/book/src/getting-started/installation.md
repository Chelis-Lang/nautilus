# Installation

Nautilus 0.7.47 is a Reef package for Chelis 0.18.12. Reef installs the package
for use from your own Chelis project. Building Nautilus from source is an
alternative when you want to work on the library.

## Install the toolchain

The Chelis and Nautilus releases require access to their GitHub repositories.
Sign in with the GitHub CLI (`gh`), then install `chelisup` and the version
Nautilus pins:

```sh
gh auth login
gh release download --repo Chelis-Lang/chelis --pattern chelisup.sh --output - | sh
export PATH="$HOME/.chelis/bin:$PATH"
chelisup install 0.18.12
chelis --version
```

The version command should print `chelis 0.18.12`. If you already have
`chelisup`, start with `chelisup install`. `chelisup` keeps versions side by
side, and its `chelis` command selects the exact compiler named in a nearby
`reef.toml`.

## Install Nautilus

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.47
```

This puts the released package in your local Reef registry. The command uses
`GITHUB_TOKEN` when set, or your `gh` login, to access the release. It does not
add Nautilus to a project's dependencies.

Create a project with the same compiler:

```sh
chelis reef init demo --module-prefix Demo --output demo
cd demo
```

In the generated `reef.toml`, add this line under the existing
`[dependencies]` table:

```toml
nautilus = { version = "0.7.47" }
```

Keep the generated `compiler = "=0.18.12"` pin. Continue with
[Your first Nautilus program](first-program.md) to evaluate a calculation.

## Work from a source checkout

To inspect or change Nautilus itself, clone the repository and build its Reef
package with the pinned toolchain:

```sh
git clone https://github.com/Chelis-Lang/nautilus.git
cd nautilus
chelisup install 0.18.12
chelis reef setup
chelis reef build
```

`chelis reef build` writes `dist/nautilus-0.7.47.chb` and a source archive. It
does not produce an executable. [maintainer guide](https://github.com/Chelis-Lang/nautilus/blob/main/docs/maintainer-guide.md)
has the native tests and optional SciPy parity commands. Parity needs uv and
Python 3.12; ordinary use of the Reef package does not.
