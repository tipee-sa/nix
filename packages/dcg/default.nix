{ pkgs, pname, ... }:

let
  inherit (pkgs) lib stdenv fetchzip;

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

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isElf [ pkgs.autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isElf [ pkgs.glibc ];

  installPhase = ''
    install -D -m 0755 dcg $out/bin/dcg
  '';

  meta = {
    description = "Blocks dangerous git and shell commands from being executed by agents";
    homepage = "https://github.com/Dicklesworthstone/destructive_command_guard";
    platforms = builtins.attrNames release.sources;
    mainProgram = "dcg";
  };
}
