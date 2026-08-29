## Pinned source build of the `chelis-provenance` command.
##
## The upstream consumer package at the pinned revision builds only the root
## `buoy` package, so it does not expose the `chelis-provenance` binary. This
## fallback builds that one workspace member from the same pinned, reviewed
## source closure. The pin record documents the upstream follow-up that adds
## the command to the consumer package; when that lands, this file retires.
{ }:

let
  pin = (builtins.fromTOML (builtins.readFile ../provenance/buoy-pin.toml)).buoy;
  buoySrc = builtins.fetchGit {
    url = pin.repository;
    rev = pin.revision;
  };
  declared = import "${buoySrc}/nix/tools/declared-source.nix" { };
  pkgs = declared.pkgs;
  rustPlatform = pkgs.makeRustPlatform {
    cargo = declared.rustToolchain;
    rustc = declared.rustToolchain;
  };
  # The same fail-closed reviewed-content verification the upstream package
  # uses: Nix derives the filtered tree's own recursive content hash and
  # rejects the build when it differs from the pin record's reviewed value.
  verifiedSource = pkgs.stdenv.mkDerivation {
    pname = "buoy-verified-source-for-chelis-provenance";
    version = pin.revision;
    src = declared.source;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    dontPatchShebangs = true;
    installPhase = ''
      cp -a "$src" "$out"
      chmod -R u+w "$out"
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = pin.reviewed_source_content_hash;
  };
in
rustPlatform.buildRustPackage {
  pname = "chelis-provenance";
  version = pin.revision;
  src = declared.source;
  cargoLock.lockFile = declared.source + "/Cargo.lock";
  cargoBuildFlags = [
    "--package"
    "chelis-provenance"
  ];
  BUOY_VERIFIED_SOURCE = verifiedSource;
  preBuild = ''
    test -d "$BUOY_VERIFIED_SOURCE"
  '';
  nativeBuildInputs = [ declared.rustToolchain ];
  doCheck = false;
  meta = {
    description = "Pinned chelis-provenance executable for Nautilus";
    license = pkgs.lib.licenses.mit;
  };
}
