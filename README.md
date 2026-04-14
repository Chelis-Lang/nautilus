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

The released compiler binary lives in the sibling public repo
[`Chelis-Lang/chelis-toolchain`](https://github.com/Chelis-Lang/chelis-toolchain)
(a mirror that hosts only the release tarballs so downstream shell CI can
download them with the default `GITHUB_TOKEN`). The Chelis source repo
stays private.

## Building

Download and extract the pinned tarball, then run check on the
placeholder module:

```sh
gh release download v0.1.3 \
  --repo Chelis-Lang/chelis-toolchain \
  --pattern 'chelis-v0.1.3-linux-x86_64.tar.gz'
tar xzf chelis-v0.1.3-linux-x86_64.tar.gz
./chelis-v0.1.3-linux-x86_64/chelis check src/core.ch
```

## Drift Rule

Nautilus, Coral, and Shoals share the same scaffolding. Use
`uv run stamp-shell --src nautilus --dst coral --old nautilus --new coral
--description "…" --phase 3k` from the Chelis monorepo's `py/` project to
stamp a new shell repo with the tokens swapped.
