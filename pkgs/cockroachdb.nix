{
  lib,
  stdenv,
  fetchzip,
  buildFHSEnv,
}:

let
  version = "25.4.3";
  pname = "cockroachdb";

  # You can generate the hashes with
  # nix flake prefetch <url>
  srcs = {
    x86_64-linux = fetchzip {
      url = "https://binaries.cockroachdb.com/cockroach-v${version}.linux-amd64.tgz";
      hash = "sha256-PjlsHdmLk7rfCFi5wqlutuvRAP0+fBTxVvd4AV4afNk=";
    };
    aarch64-linux = fetchzip {
      url = "https://binaries.cockroachdb.com/cockroach-v${version}.linux-arm64.tgz";
      hash = "sha256-vOtthcHyh9GSMM03grU9b72CHnVus0G0mO3bdggZp2o=";
    };
  };
  src =
    srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

in
buildFHSEnv {
  inherit pname version;

  runScript = "${src}/cockroach";

  extraInstallCommands = ''
    cp -P $out/bin/cockroachdb $out/bin/cockroach
  '';

  meta = {
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
