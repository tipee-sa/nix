{
  description = "tipee SA Nix Packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
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
