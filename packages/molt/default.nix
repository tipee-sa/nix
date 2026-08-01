{ pkgs, pname, ... }:

let
  inherit (pkgs) stdenv fetchzip;

  release = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (release) version;

  source =
    release.sources.${stdenv.hostPlatform.system}
      or (throw "${pname}: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchzip {
    inherit (source) url hash;
    stripRoot = false;
  };

  installPhase = ''
    mkdir -p $out/bin
    cp $src/molt $out/bin/molt
    cp $src/replicator $out/bin/molt-replicator
  '';

  meta = {
    description = "CockroachDB Migrate Off Legacy Technology toolkit";
    homepage = "https://www.cockroachlabs.com/docs/molt/molt-overview";
    platforms = builtins.attrNames release.sources;
    mainProgram = "molt";
  };
}
