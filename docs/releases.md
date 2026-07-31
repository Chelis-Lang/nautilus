# Nautilus release artifacts

Nautilus publishes three assets per tag:

- `nautilus-X.Y.Z.chb` — Reef *shell* package (≈30 KB)
- `nautilus-X.Y.Z.tar.zst` — source archive (≈30 KB)
- `nautilus-X.Y.Z.sha256` — canonical SHA-256 manifest for both payloads

The tag-triggered release workflow builds a matching pair from its checkout,
validates it semantically and canonically, seals both payloads with the checksum
manifest, rebuilds from the unchanged checkout, and requires the second pair to
be byte-identical before uploading all three assets together. A successful
rerun performs the same deterministic rebuild and explicitly replaces all three
same-named attached assets.

New package outputs under `dist/` are ignored. Two historical bootstrap
artifacts, `dist/nautilus-0.1.4.chb` and
`dist/nautilus-0.1.4.tar.zst`, remain tracked alongside the separately
generated `dist/stability.json` API inventory; they are not the current release
inputs. The release workflow and normal package CI run
`scripts/check_release_artifacts.py --write-checksums` after the build, then run
the checker again without write authority before upload. The checker validates
the archive contents, the archive↔shell hash pair through Reef's installer,
byte-identical placement, and a fresh dependent package compilation importing
`Nautilus.Special.erf`. It also calls the compiler-owned
`chelis reef verify-artifact` oracle directly. That verifier consumes the
complete canonical CHB envelope and rejects truncation, trailing bytes,
noncanonical metadata, and an archive whose digest disagrees with the CHB.

The checksum manifest is an independently transported seal over every byte of
both payloads. It detects a one-byte `.chb` change, appended junk, or archive
mutation after the workflow seals the release. It does not distinguish a
malicious or compromised release authority that can replace both payloads and
their checksum manifest: a checksum created at the same trust boundary cannot
provide that stronger provenance claim. The compiler-owned canonical validator
closes [chelis#972](https://github.com/Chelis-Lang/chelis/issues/972) at the
0.17.4 integration candidate; the checksum manifest remains necessary for
transport integrity and publisher identification.

## These artifacts are platform-agnostic by design

The `.chb` is a Zstandard-compressed envelope containing
desugared/type-checked AST + module exports + type signatures + effects
+ the dependency list. **No native code.** No ELF, no Mach-O, no `.o`,
no `.a`. The format is IR-level metadata that the *downstream*
consumer's chelis compiler reads.

The `.tar.zst` is the source tree (`reef.toml`, `reef.lock`, every
`src/*.ch` file). Its contents and build metadata are platform-neutral. Chelis
0.17.4's integration candidate canonicalizes archive member order, paths,
modes, ownership, and timestamps; the `.chb` embeds the resulting archive
digest. The Linux release job and both Linux and Darwin CI jobs now build twice
from the same checkout and require byte-identical archive and CHB bytes,
closing [chelis#970](https://github.com/Chelis-Lang/chelis/issues/970) for the
unchanged-build surface Nautilus claims. CI does not compare Linux-built bytes
with Darwin-built bytes, so it does not claim a separately measured
cross-platform identity result.

The platform boundary lives **upstream of Nautilus** — in the chelis
toolchain itself, which ships separate `linux-x86_64` and `darwin-arm64`
tarballs because it contains a Rust-compiled binary and a static
runtime archive. Reef *packages* like Nautilus and chelis-std do not
need that split.

## Consumer flow

Download all three Nautilus assets from the same GitHub Release, then verify
them before installation:

```sh
sha256sum -c nautilus-X.Y.Z.sha256
```

On macOS, use `shasum -a 256 -c nautilus-X.Y.Z.sha256`. Do not accept a
checksum manifest transported from a different release or channel.

> **Pre-publication guard:** the repository is validated against the local
> Chelis 0.17.4 cascade-integration candidate. The final merged source SHA and
> official checksummed platform-asset SHA-256 values are deliberately pending
> until upstream main is green and the v0.17.4 release assets exist; no local
> candidate digest is presented as a release digest.
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

After the official assets publish, CI's `mac-smoke` job builds, seals, and
validates a Darwin artifact pair from its current checkout as proof-of-life for
that toolchain.
It enforces unchanged-build byte identity on Darwin but does not compare the
Darwin-built bytes with the Linux release pair.
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
archive, invokes `chelis reef verify-artifact`, verifies the checksum seal,
asks Reef to install the exact generated pair, and compiles a dependent package
through the installed shell. It adversarially requires rejection of an archive
byte mutation and a CHB trailing byte. The `mac-smoke` job repeats that
validation on Darwin. Treat a failure as an upstream packaging bug to fix, not
evidence that Nautilus needs platform suffixes.
