{
  lib,
  stdenv,
  fetchzip,
  buildFHSEnv,
}:

let
  version = "26.2.4";
  pname = "cockroachdb";

  # You can generate the hashes with
  # nix flake prefetch <url>
  srcs = {
    x86_64-linux = fetchzip {
      url = "https://binaries.cockroachdb.com/cockroach-v${version}.linux-amd64.tgz";
      hash = "sha256-s4Cqg0Dq68m9xTgMJrtc6Cu+7xYf2AON4CvV3PMzFqA=";
    };
    aarch64-linux = fetchzip {
      url = "https://binaries.cockroachdb.com/cockroach-v${version}.linux-arm64.tgz";
      hash = "sha256-fENo2mbeKrdnHPC1K8J7X/OgE0WwIP9DCxrDKyKMiwo=";
    };
    aarch64-darwin = fetchzip {
      url = "https://binaries.cockroachdb.com/cockroach-v${version}.darwin-11.0-arm64.tgz";
      hash = "sha256-8bVxdxW+l1on6rWI1Ty4aDx87jQu7nsfiuxFuWQP6M4=";
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
