{
  description = "tipee SA Nix Packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05-small";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";

    # Needed by lib/image.nix and modules/treefmt/. Both are already inputs of
    # every consumer, so add `tipee.inputs.<name>.follows = "<name>"` there to
    # keep a single copy in the closure — as they already do for blueprint.
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
