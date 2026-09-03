# The deployed binary and its OCI image. `passthru.image.copyTo` is what a deploy
# streams to the registry.
{ pkgs, inputs, ... }:
let
  inherit (pkgs) lib;
  inherit (inputs.tipee.lib.image pkgs) mkImage mkRoot;
  inherit (inputs.tipee.lib.rust pkgs) fleetRustflags;

  # tipee.lib deliberately does not wrap crane; this is the line to copy.
  craneLib = (inputs.crane.mkLib pkgs).overrideToolchain (p: p.fenix.stable.minimalToolchain);

  # Naming the sources keeps a README or CI edit from rebuilding the binary.
  src = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ../../Cargo.toml
      ../../Cargo.lock
      ../../src
    ];
  };

  commonArgs = {
    pname = "example-server";
    version = "0.1.0";
    inherit src;
    strictDeps = true;
    doCheck = false;
    env.RUSTFLAGS = fleetRustflags;
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  example-server = craneLib.buildPackage (
    commonArgs
    // {
      inherit cargoArtifacts;
      passthru = { inherit image; };
      meta = {
        mainProgram = "example-server";
        # Not platforms.linux: a native aarch64 rustc rejects fleetRustflags.
        platforms = [ "x86_64-linux" ];
      };
    }
  );

  image = mkImage {
    name = "example-server";
    roots = [ (mkRoot "example-server-image-root" [ example-server ]) ];
    entrypoint = [ "/bin/example-server" ];
    user = "nobody";
  };
in
example-server
