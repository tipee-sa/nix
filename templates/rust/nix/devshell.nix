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
    cargo-edit
    cargo-machete
    cargo-nextest
    jq
    just
    just-lsp
  ]);
}
