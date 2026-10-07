# Installation

Nautilus 0.7.50 is a Reef package for Chelis 0.19.1. Install Chelis from the
[official releases](https://chelis.ch/docs/chelis/install/), using the compiler version
required by the Nautilus release.

Install the Nautilus release into your local Reef registry. The release is
public, so no token is needed:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.50
```

The command prints `Installed nautilus 0.7.50` and stores the package under
`~/.chelis/reef/packages/nautilus/0.7.50/`.

Add Nautilus to your project's `[dependencies]` table in `reef.toml`:

```toml
[dependencies]
nautilus = { version = "0.7.50" }
```

Set the project's `compiler` pin to `"=0.19.1"`. From the project directory,
run:

```sh
chelis reef build
```

The build resolves Nautilus from the local registry, writes `reef.lock` with
the pinned versions and hashes, and prints `Built <project> <version>`. If
Nautilus is not in the local registry, `reef build` looks it up on GitHub
instead and stops with an error unless `GITHUB_TOKEN` is set or `gh` is
signed in. On another machine, `chelis reef setup` reinstalls every
dependency recorded in `reef.lock`.

Continue with [Your first Nautilus program](first-program.md)
to evaluate a calculation. The [Reef and packages guide](https://chelis.ch/docs/chelis/reef/)
covers dependency setup and compiler compatibility.
