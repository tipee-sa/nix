{ pkgs, pname, ... }:

let
  inherit (pkgs) stdenv fetchzip buildFHSEnv;

  release = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (release) version;

  source =
    release.sources.${stdenv.hostPlatform.system}
      or (throw "${pname}: unsupported platform ${stdenv.hostPlatform.system}");

  src = fetchzip { inherit (source) url hash; };

  meta = {
    description = "Distributed SQL database";
    homepage = "https://www.cockroachlabs.com/";
    platforms = builtins.attrNames release.sources;
  };
in
if stdenv.hostPlatform.isLinux then
  buildFHSEnv {
    inherit pname version meta;

    runScript = "${src}/cockroach";

    extraInstallCommands = ''
      cp -P $out/bin/${pname} $out/bin/cockroach
    '';
  }
else
  stdenv.mkDerivation {
    inherit
      pname
      version
      src
      meta
      ;

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/bin
      cp cockroach $out/bin/cockroach
      if [ -d lib ]; then
        cp -r lib $out/lib
      fi
    '';
  }
