{
  stdenv,
  fetchzip,
}:

let
  version = "1.3.4";
  pname = "molt";

  srcs = {
    x86_64-linux = fetchzip {
      url = "https://molt.cockroachdb.com/molt/cli/molt-${version}.linux-amd64.tgz";
      hash = "sha256-Uc275HtRc8N18zwyqPYVCsuu8zZifvKWC/Sxidibt6s=";
    };
    aarch64-linux = fetchzip {
      url = "https://molt.cockroachdb.com/molt/cli/molt-${version}.linux-arm64.tgz";
      hash = "sha256-3yvyS/jxyBKw0xWvgWCOVysV1stUg7bR40nBwOnfjb8=";
    };
  };
  src =
    srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

in
stdenv.mkDerivation {
  inherit pname version src;

  buildInputs = [ ];
  nativeBuildInputs = [ ];

  installPhase = ''
    mkdir -p $out/bin

    # Copy the 'molt' binary to $out/bin/molt
    cp $src/molt $out/bin/molt

    # Copy the 'replicator' binary to $out/bin/molt-replicator
    # Note: Assuming the binary inside the tgz is named 'replicator'
    cp $src/replicator $out/bin/molt-replicator
  '';

  meta = {
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
