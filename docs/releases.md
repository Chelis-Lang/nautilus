# Nautilus release artifacts

Nautilus publishes two artifacts per tag:

- `nautilus-X.Y.Z.chb` — Reef *shell* package (≈30 KB)
- `nautilus-X.Y.Z.tar.zst` — source archive (≈30 KB)

Both are produced once by the tag-triggered release workflow and uploaded
directly from that tagged checkout. Package outputs under `dist/` are ignored;
only the separately generated `dist/stability.json` API inventory is committed.
The release workflow and normal package CI run
`scripts/check_release_artifacts.py` after the build to validate the archive
contents and the archive↔shell hash pair through Reef's installer.

## These artifacts are platform-agnostic by design

The `.chb` is a Zstandard-compressed envelope containing
desugared/type-checked AST + module exports + type signatures + effects
+ the dependency list. **No native code.** No ELF, no Mach-O, no `.o`,
no `.a`. The format is IR-level metadata that the *downstream*
consumer's chelis compiler reads.

The `.tar.zst` is the source tree (`reef.toml`, `reef.lock`, every
`src/*.ch` file). Its contents are platform-neutral, but this is not currently
a reproducible-build guarantee: unchanged builds can produce different bytes
because archive metadata includes filesystem mtimes, and the `.chb` correctly
changes with the archive hash. Chelis tracks canonical archive metadata and
cross-build byte identity as chelis#970. Consumers identify the one official
asset pair attached to a release; they must not substitute an independently
rebuilt pair by filename alone.

The platform boundary lives **upstream of Nautilus** — in the chelis
toolchain itself, which ships separate `linux-x86_64` and `darwin-arm64`
tarballs because it contains a Rust-compiled binary and a static
runtime archive. Reef *packages* like Nautilus and chelis-std do not
need that split.

## Consumer flow

> **Pre-publication guard:** the repository is validated against the local
> Chelis 0.17.4 release candidate, built from source commit
> `9a58c5781105bbe07d37afbb6ecfc7b3a879e0de`. Its source tag, GitHub Release,
> and checksummed platform assets do not yet exist.
> The commands below are the exact post-publication consumer flow; do not run
> them until those official assets are published. Until then, the latest
> installable upstream release remains v0.17.2 (the `v0.17.3` source tag exists
> without matching release assets).

### Linux (x86_64)

```sh
gh release download v0.17.4 --repo Chelis-Lang/chelis \
  --pattern 'chelis-v0.17.4-linux-x86_64.tar.gz'
tar xzf chelis-v0.17.4-linux-x86_64.tar.gz
export PATH="$PWD/chelis-v0.17.4-linux-x86_64/bin:$PATH"

# In your Chelis project's reef.toml:
#   nautilus = "0.7.36"
chelis reef install --from-monorepo /path/to/nautilus-checkout nautilus
chelis reef build
```

### macOS (Apple Silicon)

Identical except for the toolchain download:

```sh
gh release download v0.17.4 --repo Chelis-Lang/chelis \
  --pattern 'chelis-v0.17.4-darwin-arm64.tar.gz'
tar xzf chelis-v0.17.4-darwin-arm64.tar.gz
export PATH="$PWD/chelis-v0.17.4-darwin-arm64/bin:$PATH"

# Same steps from here on. Nautilus uses the same unsuffixed,
# platform-neutral artifact names on every platform. The Darwin
# chelis compiler reads the IR + sources and lowers to Mach-O.
chelis reef install --from-monorepo /path/to/nautilus-checkout nautilus
chelis reef build
```

After the official assets publish, CI's `mac-smoke` job builds and validates a
Darwin artifact pair from its current checkout as proof-of-life for that toolchain.
It does not compare the Darwin-built bytes with the Linux release pair; that
stronger reproducibility guarantee remains blocked by chelis#970.
Pre-publication acceptance uses the exact local candidate binary and does not
claim that the release-download path or official asset pair is live.

## Non-goal: do NOT add platform suffixes to Nautilus release artifacts

A future contributor reading the chelis release page may notice that
chelis ships `chelis-vX.Y.Z-linux-x86_64.tar.gz` AND
`chelis-vX.Y.Z-darwin-arm64.tar.gz` and feel that Nautilus is missing
something. **It is not.** The two-platform split exists in chelis
because the chelis tarball is a compiled binary. Nautilus's reef
artifacts contain only language-level IR + source — there is no
platform-specific code to vary.

`scripts/check_release_artifacts.py` rejects native-code members in the source
archive and asks Reef to deserialize and install the exact generated pair.
The `mac-smoke` job repeats that validation on Darwin. Treat a failure as an
upstream packaging bug to fix, not evidence that Nautilus needs platform
suffixes.
