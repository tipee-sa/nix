{
  pkgs,
  perSystem,
  inputs,
}:
pkgs.mkShell {
  packages = [
    # treefmt on PATH with the exact config `nix fmt` uses.
    perSystem.self.formatter
    (inputs.tipee.lib.rust pkgs).devToolchain
  ]
  ++ (with pkgs; [
    # cockroachdb comes from tipee's overlay, applied in flake.nix; nixpkgs has
    # no such package.
    cockroachdb
    cargo-edit
    cargo-machete
    cargo-nextest
    jq
    just
    just-lsp
    process-compose
  ]);
}
