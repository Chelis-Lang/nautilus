# Installation

Nautilus is a Reef package. Install Chelis from the
[official releases](https://chelis.ch/docs/chelis/install/). Nautilus 0.7.59 needs
Chelis 0.23.1.

After Nautilus 0.7.59 is available as a public GitHub release, install it into
your local Reef registry. This direct download needs no GitHub token:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.59
```

Reef stores this package under `~/.chelis/reef/packages/nautilus/0.7.59/`.

Set the compiler pin and Nautilus dependency in your project's `reef.toml`:

```toml
[package]
compiler = "=0.23.1"

[dependencies]
nautilus = { version = "0.7.59" }
```

From the project directory, run:

```sh
chelis reef build
```

The build resolves Nautilus from the local registry, writes `reef.lock` with
the pinned versions and hashes, and prints `Built <project> <version>`. If
Nautilus is not in the local registry, `reef build` can discover its public
GitHub release after you set `GITHUB_TOKEN` or authenticate with `gh auth login`.
On another machine, `chelis reef setup` reinstalls every dependency recorded
in `reef.lock`.

Continue with [Your first Nautilus program](first-program.md)
to evaluate a calculation. The [Reef and packages guide](https://chelis.ch/docs/chelis/reef/)
covers dependency setup and compiler compatibility.
