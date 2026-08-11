# Rust settings shared across repos: the dev-shell toolchain and the flags
# deployed binaries are built with.
#
# Requires the fenix overlay on the `pkgs` passed in.
{ pkgs }:
let
  fenix =
    pkgs.fenix
      or (throw "tipee.lib.rust needs the fenix overlay: add inputs.fenix.overlays.default to nixpkgs.overlays");
in
{
  # For dev shells only. A package must pin its own toolchain, so that adding a
  # tool here cannot change a deployed artifact's store path.
  #
  # rustfmt comes from nightly because the repos' rustfmt.toml files use
  # nightly-only options; rust-analyzer tracks rustc's channel so the editor and
  # the build agree on what compiles.
  devToolchain = fenix.combine [
    fenix.stable.cargo
    fenix.stable.rustc
    fenix.stable.rust-src
    fenix.stable.clippy
    fenix.stable.rust-analyzer
    fenix.latest.rustfmt
  ];

  # The baseline the production Nomad pool supports. A native aarch64 rustc
  # rejects the flag, so a package using it needs
  # `meta.platforms = [ "x86_64-linux" ]`.
  fleetRustflags = "-C target-cpu=x86-64-v3";
}
