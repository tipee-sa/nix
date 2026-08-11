{
  description = "JavaScript project: shared formatters";

  # Flake-level nixConfig does not compose through inputs, so each repo carries
  # this block itself.
  nixConfig = {
    extra-substituters = [ "https://nix-cache.tipee.cloud" ];
    extra-trusted-public-keys = [
      "nix-cache.tipee.cloud-1:wyyfWik+x7cpTODlztChPdYTWHEvrc200tLKES43CCE="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    blueprint.url = "github:numtide/blueprint";
    tipee.url = "github:tipee-sa/nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    blueprint.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    tipee.inputs.blueprint.follows = "blueprint";
    tipee.inputs.nixpkgs.follows = "nixpkgs";
    tipee.inputs.treefmt-nix.follows = "treefmt-nix";
  };

  outputs =
    inputs:
    inputs.blueprint {
      inherit inputs;
      prefix = "nix/";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      nixpkgs.overlays = [ inputs.tipee.overlays.default ];
    };
}
