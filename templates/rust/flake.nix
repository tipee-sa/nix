{
  description = "Rust service: shared formatters, toolchain and OCI image";

  # Flake-level nixConfig does not compose through inputs, so each repo carries
  # this block itself. Nix asks once before honouring it; accepting is what makes
  # a first `nix develop` a download instead of a build.
  nixConfig = {
    extra-substituters = [ "https://nix-cache.tipee.cloud" ];
    extra-trusted-public-keys = [
      "nix-cache.tipee.cloud-1:wyyfWik+x7cpTODlztChPdYTWHEvrc200tLKES43CCE="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    blueprint.url = "github:numtide/blueprint";
    crane.url = "github:ipetkov/crane";
    fenix.url = "github:nix-community/fenix";
    nix2container.url = "github:nlewo/nix2container";
    tipee.url = "github:tipee-sa/nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    blueprint.inputs.nixpkgs.follows = "nixpkgs";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    # Redirecting all four keeps one copy of each in the closure.
    tipee.inputs.blueprint.follows = "blueprint";
    tipee.inputs.nix2container.follows = "nix2container";
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
      # tipee.lib.rust reads pkgs.fenix, so the overlay has to be applied here.
      nixpkgs.overlays = [
        inputs.fenix.overlays.default
        inputs.tipee.overlays.default
      ];
    };
}
