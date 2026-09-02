## Pinned consumption of the Buoy consumer package for Nautilus provenance.
##
## Every input comes from `provenance/buoy-pin.toml` and from the pinned Buoy
## tree itself: the evaluation context, the Rust toolchain, the declared
## source filter, and the reviewed source-content hash are the pinned
## revision's own single-owner definitions. Nothing here follows a branch,
## vendors sources, or derives a verification value from the tree under test.
##
## Realize on demand: `nix-build nix/buoy-consumer.nix`. The result exposes
## `bin/chelis-provenance` and the `buoy` command family.
{
  digestFeature ? "xxh3-128",
}:

let
  pin = (builtins.fromTOML (builtins.readFile ../provenance/buoy-pin.toml)).buoy;
  buoySrc = builtins.fetchGit {
    url = pin.repository;
    rev = pin.revision;
  };
  declared = import "${buoySrc}/nix/tools/declared-source.nix" { };
in
declared.pkgs.callPackage "${buoySrc}/nix/consumer-package-v1.nix" {
  src = declared.source;
  sourceRevision = pin.revision;
  # The Nautilus-reviewed constant for the clean fetched tree. The upstream
  # committed constant covers a development worktree, so the pin record owns
  # the clean-tree value; Nix still fails closed on any difference.
  sourceContentHash = pin.reviewed_source_content_hash;
  inherit (declared) rustToolchain;
  system = declared.pkgs.stdenv.hostPlatform.system;
  inherit digestFeature;
}
