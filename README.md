# Nautilus

Numerical methods, statistics, and optimization shell for the
[Chelis](https://github.com/Chelis-Lang/chelis) programming language.
Private reef package under the `Chelis-Lang` GitHub org, owned by Chelis
phase 3j. **Scaffolding only** at this point — no `Nautilus.*` surface is
shipped yet; this repo exists to lock in the layout that Coral (3k) and
Shoals (3m) will be copied from.

## Toolchain

The released binary is `chelis v0.1.2` (download from
`Chelis-Lang/chelis` releases). Note the pin in `reef.toml` is the
string `"=0.1.0"`, not `"=0.1.2"`:

```toml
# reef.toml
compiler = "=0.1.0"
```

This is a **known monorepo bug**: `chelis-reef` hard-codes
`CURRENT_COMPILER_VERSION = "=0.1.0"` and rejects any other string, so
every released binary through v0.1.2 actually enforces `"=0.1.0"` at
reef-manifest time. The pin should be fixed upstream in a follow-up
Chelis commit, after which Nautilus, Coral, and Shoals should all bump
to the real version pin in the same change set.

## Building

Once the `chelis` compiler binary is on your PATH (download the release
tarball from `Chelis-Lang/chelis` releases):

```sh
chelis check src/core.ch
```

## Known limitation — CI auth

The `.github/workflows/ci.yml` workflow downloads the pinned chelis
release tarball from the sibling **private** `Chelis-Lang/chelis` repo.
The default `GITHUB_TOKEN` is scoped to this repo only and will not have
read access to sibling private repo releases. Before the CI run can
succeed we need one of: (a) an org-level PAT stored as a secret named
`CHELIS_RELEASE_TOKEN`, (b) making release assets public while keeping
source private, or (c) publishing the compiler as a GitHub Packages
artifact with org-wide pull access. Tracked as `TODO(toolchain-auth)`
in the workflow file. Same flag applies to Coral and Shoals when they
are stamped from this template.
