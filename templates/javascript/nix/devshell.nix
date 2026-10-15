{ pkgs, perSystem }:
pkgs.mkShell {
  packages = [
    # treefmt on PATH with the exact config `nix fmt` uses.
    perSystem.self.formatter
  ]
  ++ (with pkgs; [
    # Pin the Node major CI and Docker use; the nixpkgs default moves.
    nodejs_22
    pnpm
    jq
    just
    just-lsp
    # Ad-hoc oxlint. A checkout's node_modules copy stays authoritative for
    # `pnpm run lint`.
    oxlint
  ]);
}
