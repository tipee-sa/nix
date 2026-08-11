# Helpers that need a `pkgs` and so cannot be flake outputs. Blueprint imports
# this file as `outputs.lib`, passing `{ inputs, flake }`.
#
# Each entry is a function of the consumer's `pkgs`, so nothing here is built
# against this repo's nixpkgs — same reason `overlays.default` extends the
# consumer's package set rather than exporting from the one locked here.
#
# Consumers:
#   inherit (inputs.tipee.lib.image pkgs) mkImage mkRoot;
#   inherit (inputs.tipee.lib.rust pkgs) devToolchain fleetRustflags;
{ inputs, ... }:
{
  image = pkgs: import ./image.nix { inherit pkgs inputs; };
  rust = pkgs: import ./rust.nix { inherit pkgs; };
}
