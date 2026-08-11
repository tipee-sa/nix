# `nix flake check` gate: fails if any in-tree file is not treefmt-clean, which
# also means the published treefmt modules evaluate and build. Reuses the
# formatter's evaluation via its passthru (see formatter.nix).
{ perSystem, flake, ... }: perSystem.self.formatter.passthru.check flake
