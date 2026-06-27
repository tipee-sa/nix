{
  stdenv,
  fetchzip,
}:

let
  version = "1.4.2";
  pname = "molt";

  srcs = {
    x86_64-linux = fetchzip {
      url = "https://molt.cockroachdb.com/molt/cli/molt-${version}.linux-amd64.tgz";
      hash = "sha256-nrTn11twR1CqSztXzNXDhyLN95HeEZnBDYgEvVc/viQ=";
      stripRoot = false;
    };
    aarch64-linux = fetchzip {
      url = "https://molt.cockroachdb.com/molt/cli/molt-${version}.linux-arm64.tgz";
      hash = "sha256-cED9D/Js45k8RTeXJFpaBk+uv5XTUd6GIUWbuCMHpT0=";
      stripRoot = false;
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
