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
    aarch64-darwin = fetchzip {
      url = "https://binaries.cockroachdb.com/cockroach-v${version}.darwin-11.0-arm64.tgz";
      hash = "sha256-xBDdvQQZAWWqt3/KVzQg1RyX0Bf5RlrdduPz9jKTZoE=";
    };
  };
  src =
    srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

in
if stdenv.hostPlatform.isLinux then
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
else
  stdenv.mkDerivation {
    inherit pname version src;

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/bin
      cp cockroach $out/bin/cockroach
      if [ -d lib ]; then
        cp -r lib $out/lib
      fi
    '';

    meta = {
      platforms = [
        "aarch64-darwin"
      ];
    };
  }
