# Installation

Nautilus is a Reef package. Install Chelis from the
[official releases](https://chelis.ch/docs/chelis/install/), using the compiler version
required by the Nautilus release.

Install the Nautilus release into your local Reef registry. The release is
public, so no token is needed:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.58
```

The command prints `Installed nautilus 0.7.58` and stores the package under
`~/.chelis/reef/packages/nautilus/0.7.58/`.

Add Nautilus to your project's `[dependencies]` table in `reef.toml`:

```toml
[dependencies]
nautilus = { version = "0.7.58" }
```

Set your project's `compiler` pin to the exact compiler version required by
the installed Nautilus package. From the project directory, run:

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
