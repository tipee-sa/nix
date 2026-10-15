# Rust and Cargo formatting: rustfmt, taplo over every `*.toml`, and Cargo.toml
# dependency sorting.
#
# Each repo still commits its own `rustfmt.toml`; rustfmt has no store-path
# config that rust-analyzer also reads.
{ pkgs, lib, ... }:
let
  # cargo-sort resolves paths against the manifest directory, not the working
  # directory, so a bare relative path like the `Cargo.toml` treefmt passes is
  # rejected.
  cargo-sort-wrapped = pkgs.writeShellScriptBin "cargo-sort" ''
    args=()
    for arg in "$@"; do
      case "$arg" in
      -*) args+=("$arg") ;;
      *) args+=("$(${pkgs.coreutils}/bin/realpath "$arg")") ;;
      esac
    done
    exec ${pkgs.cargo-sort}/bin/cargo-sort "''${args[@]}"
  '';
in
{
  programs.taplo = {
    enable = true;
    # Narrowing the width or enabling auto-collapse reflows inline dependency
    # tables and hand-expanded arrays such as workspace `members`.
    settings.formatting = {
      column_width = 200;
      array_auto_collapse = false;
    };
  };

  programs.rustfmt = {
    enable = true;
    edition = "2024";
    # The repos' rustfmt.toml files use nightly-only options, so nightly rustfmt
    # where the fenix overlay is applied; nixpkgs rustfmt keeps the module usable
    # without it.
    package = lib.mkDefault (pkgs.fenix.latest.rustfmt or pkgs.rustfmt);
  };

  # Sorts `[dependencies]` and `[workspace.dependencies]` only, leaving
  # `[profile.*]` and lint tables alone. `--no-format` and the priority leave all
  # layout to taplo, which would otherwise undo it on the next run.
  settings.formatter.cargo-sort = {
    command = "${cargo-sort-wrapped}/bin/cargo-sort";
    options = [
      "--grouped"
      "--no-format"
    ];
    # treefmt matches globs against the whole relative path, so a bare
    # `Cargo.toml` reaches only the workspace root.
    includes = [
      "Cargo.toml"
      "**/Cargo.toml"
    ];
    priority = 2;
  };
}
