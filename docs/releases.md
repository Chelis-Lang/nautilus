# Nautilus release artifacts

Nautilus publishes two artifacts per tag:

- `nautilus-X.Y.Z.chb` — Reef *shell* package (≈30 KB)
- `nautilus-X.Y.Z.tar.zst` — source archive (≈30 KB)

Both are produced by `chelis reef build` and committed under `dist/` in
the repo. `gh release create` uploads them as assets at tag time.

## These artifacts are platform-agnostic by design

The `.chb` is a Zstandard-compressed envelope containing
desugared/type-checked AST + module exports + type signatures + effects
+ the dependency list. **No native code.** No ELF, no Mach-O, no `.o`,
no `.a`. The format is IR-level metadata that the *downstream*
consumer's chelis compiler reads.

The `.tar.zst` is the source tree (`reef.toml`, `reef.lock`, every
`src/*.ch` file). Identical bytes regardless of build host.

The platform boundary lives **upstream of Nautilus** — in the chelis
toolchain itself, which ships separate `linux-x86_64` and `darwin-arm64`
tarballs because it contains a Rust-compiled binary and a static
runtime archive. Reef *packages* like Nautilus and chelis-std do not
need that split.

## Consumer flow

### Linux (x86_64)

```sh
gh release download v0.8.0 --repo Chelis-Lang/chelis \
  --pattern 'chelis-v0.8.0-linux-x86_64.tar.gz'
tar xzf chelis-v0.8.0-linux-x86_64.tar.gz
export PATH="$PWD/chelis-v0.8.0-linux-x86_64/bin:$PATH"

# In your Chelis project's reef.toml:
#   nautilus = "0.7.27"
chelis reef install --from-monorepo /path/to/nautilus-checkout nautilus
chelis reef build
```

### macOS (Apple Silicon)

Identical except for the toolchain download:

```sh
gh release download v0.8.0 --repo Chelis-Lang/chelis \
  --pattern 'chelis-v0.8.0-darwin-arm64.tar.gz'
tar xzf chelis-v0.8.0-darwin-arm64.tar.gz
export PATH="$PWD/chelis-v0.8.0-darwin-arm64/bin:$PATH"

# Same steps from here on. The Nautilus .chb + .tar.zst are
# the same files used on Linux. The Darwin chelis compiler
# reads the IR + sources and lowers to Mach-O.
chelis reef install --from-monorepo /path/to/nautilus-checkout nautilus
chelis reef build
```

The CI's `mac-smoke` job runs this exact flow on every push as
proof-of-life that the Nautilus reef package builds under the
Darwin chelis toolchain.

## Non-goal: do NOT add platform suffixes to Nautilus release artifacts

A future contributor reading the chelis release page may notice that
chelis ships `chelis-vX.Y.Z-linux-x86_64.tar.gz` AND
`chelis-vX.Y.Z-darwin-arm64.tar.gz` and feel that Nautilus is missing
something. **It is not.** The two-platform split exists in chelis
because the chelis tarball is a compiled binary. Nautilus's reef
artifacts contain only language-level IR + source — there is no
platform-specific code to vary.

If a regression ever causes Nautilus's `.chb` to embed native code, the
`mac-smoke` CI job will fail (the artifact built on Linux won't load
under Darwin chelis). Treat that signal as a chelis upstream bug to
fix, not a "Nautilus needs a darwin variant" problem.
