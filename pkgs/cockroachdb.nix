{
  lib,
  stdenv,
  fetchzip,
  buildFHSEnv,
}:

let
  version = "26.1.0";
  pname = "cockroachdb";

  # You can generate the hashes with
  # nix flake prefetch <url>
  srcs = {
    x86_64-linux = fetchzip {
      url = "https://binaries.cockroachdb.com/cockroach-v${version}.linux-amd64.tgz";
      hash = "sha256-7VXmw0Gtypbb2QFCI3n3vXhQmKFYFrwBl5JeApUxOf4=";
    };
    aarch64-linux = fetchzip {
      url = "https://binaries.cockroachdb.com/cockroach-v${version}.linux-arm64.tgz";
      hash = "sha256-1DyjEcmrV/sF/aIKfypBg9B7cN1HNVTME0aYodEduBg=";
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
