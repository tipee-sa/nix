{
  description = "tipee SA Nix Packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05-small";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";

    # Used by lib/image.nix and modules/treefmt/. A consumer holding either input
    # should redirect it with `tipee.inputs.<name>.follows`, or its closure
    # carries two copies.
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    let
      blueprint = inputs.blueprint {
        inherit inputs;
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];
      };
    in
    blueprint
    // {
      # Built against the nixpkgs being extended, not the one locked here, so
      # that a consumer instantiates a single nixpkgs.
      overlays.default = final: _prev: blueprint.mkPackagesFor final;
    };
}
