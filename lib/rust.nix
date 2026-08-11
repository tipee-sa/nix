# Rust facts that must not drift between repos.
#
# Deliberately does NOT wrap crane. `craneLib = (crane.mkLib pkgs).overrideToolchain
# (p: p.fenix.stable.minimalToolchain)` is one line, duplicated in hive and
# mozart only, and platform builds its leaf tools with `buildRustPackage`
# instead. Pulling crane in as an input to this repo — which every other repo
# depends on — to share one line is the wrong trade. Copy the line.
{ pkgs }:
let
  fenix =
    pkgs.fenix
      or (throw "tipee.lib.rust needs the fenix overlay: add inputs.fenix.overlays.default to nixpkgs.overlays");
in
{
  # The dev-shell toolchain. hive and platform have byte-identical copies of
  # this block; mozart builds the same effective set from `stable.minimalToolchain
  # + clippy`. What it pins is the org decision: stable channel for the compiler,
  # nightly only for rustfmt (the repos' rustfmt.toml files use nightly-only
  # options), and rust-analyzer from the same channel as rustc so the editor and
  # the build agree.
  #
  # Not the toolchain a *build* should use — a package should pin
  # `fenix.stable.minimalToolchain` itself, so a new dev tool here cannot
  # invalidate a deployed artifact.
  devToolchain = fenix.combine [
    fenix.stable.cargo
    fenix.stable.rustc
    fenix.stable.rust-src
    fenix.stable.clippy
    fenix.stable.rust-analyzer
    fenix.latest.rustfmt
  ];

  # The production Nomad pool is x86-64-v3-capable throughout, so deployed
  # binaries are compiled for it. hive/packages/hive-server.nix and
  # mozart/nix/packages/mozart-server.nix both set this with the same comment —
  # if the pool baseline ever moves, it has to move in one place.
  #
  # Note the consequence both repos hit: a native aarch64 rustc rejects this
  # flag, so a package using it needs `meta.platforms = [ "x86_64-linux" ]`.
  fleetRustflags = "-C target-cpu=x86-64-v3";
}
