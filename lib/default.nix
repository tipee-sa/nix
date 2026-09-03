# Helpers that take the consumer's `pkgs`, so they cannot be flake outputs.
# Blueprint imports this file as `outputs.lib`.
#
#   inherit (inputs.tipee.lib.image pkgs) mkImage mkRoot;
#   inherit (inputs.tipee.lib.rust pkgs) devToolchain fleetRustflags;
{ inputs, ... }:
{
  image = pkgs: import ./image.nix { inherit pkgs inputs; };
  rust = pkgs: import ./rust.nix { inherit pkgs; };
}
