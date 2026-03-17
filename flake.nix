{
  description = "tipee SA Nix Packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      overlays.default = final: prev: {
        cockroachdb = final.callPackage ./pkgs/cockroachdb.nix { };
        molt = final.callPackage ./pkgs/molt.nix { };
      };

      packages =
        let
          systems = [
            "x86_64-linux"
            "aarch64-linux"
            "aarch64-darwin"
          ];
        in
        nixpkgs.lib.genAttrs systems (
          system:
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ self.overlays.default ];
            };
          in
          {
            inherit (pkgs) cockroachdb molt;
            cockroach = pkgs.cockroachdb;
          }
        );
    };
}
