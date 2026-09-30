# Nautilus release artifacts

Each Nautilus release is a GitHub Release tagged `vX.Y.Z` with three assets:

- `nautilus-X.Y.Z.chb`: the Reef package envelope (about 30 KB)
- `nautilus-X.Y.Z.tar.zst`: the source archive (about 30 KB)
- `nautilus-X.Y.Z.sha256`: a SHA-256 manifest covering both payloads

The version and the exact Chelis compiler a release was built with are both
recorded in `reef.toml` at the tagged commit.
The current source checkout pins Chelis 0.18.12, while the last published
Nautilus package, v0.7.46, predates that pin. The source change does not
update the published package; use each release's tagged manifest when
installing it.

## How a release is built

Pushing a `v*` tag runs `.github/workflows/release.yml`. The workflow builds the
package with the pinned compiler and then runs
`scripts/check_release_artifacts.py --write-checksums`, which validates the pair
and seals both payloads with the checksum manifest. It rebuilds from the
unchanged checkout and runs the checker again without write authority. The
second pair must be byte-identical to the first, and only then are all three
assets uploaded together. A successful
rerun performs the same deterministic rebuild
and explicitly replaces all three same-named assets.

The checker:

- runs the compiler-owned `chelis reef verify-artifact`, which consumes the
  complete canonical `.chb` envelope and rejects truncation, trailing bytes,
  non-canonical metadata, and an archive whose digest disagrees with the
  envelope;
- rejects native-code members and unsafe or duplicate paths in the source
  archive;
- installs the exact pair through Reef and compiles a dependent package that
  imports `Nautilus.Special.erf`;
- requires that a mutated archive byte and a trailing `.chb` byte are both
  rejected, as evidence that the validation actually detects tampering.

Normal CI runs the same build, seal, rebuild, and validate sequence on Linux
for every pull request, and on macOS for every push to `main`. CI does not
compare Linux-built bytes with macOS-built bytes, so there is no claim of
cross-platform byte identity.

The checksum manifest detects any change to either payload after the workflow
seals them, such as a one-byte `.chb` edit, appended data, or a modified
archive. It does not protect against a compromised release authority that can
replace both payloads and the manifest, because a checksum created at the same
trust boundary cannot provide that guarantee.

## Artifacts are platform-neutral

The `.chb` is a Zstandard-compressed envelope that holds the desugared,
type-checked AST, module exports, type signatures, effects, and the dependency
list. It contains no native code. The `.tar.zst` holds `reef.toml`, `reef.lock`,
and every `src/*.ch` file. Chelis canonicalizes archive member order, paths,
modes, ownership, and timestamps, and the `.chb` embeds the archive digest.

The compiler toolchain itself is platform-specific: Chelis ships separate
`linux-x86_64-glibc2.31` and `darwin-arm64` builds. The consumer's compiler
reads Nautilus's IR and sources and lowers them for the local platform, so
Nautilus artifacts carry no platform suffix, and they should not.
`check_release_artifacts.py` rejects native-code members in the archive, so a
platform-specific failure indicates an upstream packaging bug, not a missing
Nautilus variant.

## Installing a release

Install the compiler version named by the release's `reef.toml` with
`chelisup`, then install the release into your local Reef registry:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@vX.Y.Z
```

`reef install` validates the envelope and archive before installing them. To
check the transport seal yourself, download all three assets from the same
release and run:

```sh
sha256sum -c nautilus-X.Y.Z.sha256        # Linux
shasum -a 256 -c nautilus-X.Y.Z.sha256    # macOS
```

Only use a checksum manifest that came from the same release.

Then declare the dependency in your project's `reef.toml`:

```toml
[dependencies]
nautilus = { version = "X.Y.Z" }
```

## Tracked files under `dist/`

Build outputs under `dist/` are ignored. The only tracked file there is
`dist/stability.json`, the machine-readable export inventory generated from
`SKILL.md` §6 by `scripts/extract_stability.py`.
