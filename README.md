# Nautilus

Numerical methods, statistics, and optimization shell for the
[Chelis](https://github.com/Chelis-Lang/chelis) programming language.
Private reef package under the `Chelis-Lang` GitHub org, owned by Chelis
phase 3j. **Scaffolding only** at this point — no `Nautilus.*` surface is
shipped yet; this repo exists to lock in the layout that Coral (3k) and
Shoals (3m) will be copied from.

## Toolchain

Pinned to `chelis v0.1.3`:

```toml
# reef.toml
compiler = "=0.1.3"
```

The released compiler binary is published as a private release on
[`Chelis-Lang/chelis`](https://github.com/Chelis-Lang/chelis). CI
downloads it with a personal access token stored in the repo secret
`CHELIS_RELEASE_TOKEN`, which must have `contents: read` on the Chelis
source repo. See `.github/workflows/ci.yml`.

## Building

Download and extract the pinned tarball, then run check on the
placeholder module:

```sh
gh release download v0.1.3 \
  --repo Chelis-Lang/chelis \
  --pattern 'chelis-v0.1.3-linux-x86_64.tar.gz'
tar xzf chelis-v0.1.3-linux-x86_64.tar.gz
./chelis-v0.1.3-linux-x86_64/chelis check src/core.ch
```

## Drift Rule

Nautilus, Coral, and Shoals share the same scaffolding. Use
`uv run stamp-shell --src nautilus --dst coral --old nautilus --new coral
--description "…" --phase 3k` from the Chelis monorepo's `py/` project to
stamp a new shell repo with the tokens swapped. Remember to also
`gh secret set CHELIS_RELEASE_TOKEN` on each new shell repo.
