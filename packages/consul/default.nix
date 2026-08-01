{ pkgs, pname, ... }:

let
  inherit (pkgs) stdenvNoCC fetchzip;

  release = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (release) version;

  source =
    release.sources.${stdenvNoCC.hostPlatform.system}
      or (throw "${pname}: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchzip {
    inherit (source) url hash;
    stripRoot = false;
  };

  installPhase = ''
    install -D -m 0755 consul $out/bin/consul
  '';

  meta = {
    description = "HashiCorp Consul";
    homepage = "https://www.consul.io/";
    platforms = builtins.attrNames release.sources;
    mainProgram = "consul";
  };
}
