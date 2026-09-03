# Fails if the tree is not treefmt-clean, which also requires every module
# formatter.nix imports to evaluate and its formatters to build.
{ perSystem, flake, ... }: perSystem.self.formatter.passthru.check flake
