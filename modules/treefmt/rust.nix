# Rust and TOML formatting: rustfmt, taplo, and Cargo.toml dependency sorting.
#
# hive/treefmt.nix and mozart/nix/treefmt.nix carry byte-identical copies of all
# three blocks, comments included. platform has two Cargo workspaces
# (tools/accio, tools/alohomora) and formats neither — importing this closes that
# gap rather than adding anything new to it.
{ pkgs, lib, ... }:
let
  # cargo-sort chokes on bare relative paths (e.g. `Cargo.toml` without a
  # `./` prefix) — which is exactly how treefmt passes files. Resolve each
  # non-flag argument to an absolute path before handing it to cargo-sort.
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
  # TOML — taplo formats every *.toml file. Wide columns keep inline dependency
  # tables on one line; auto-collapse off leaves multi-line arrays (a workspace
  # `members` list) as written.
  programs.taplo = {
    enable = true;
    settings.formatting = {
      column_width = 200;
      array_auto_collapse = false;
    };
  };

  programs.rustfmt = {
    enable = true;
    edition = "2024";
    # Nightly rustfmt when the consumer applied the fenix overlay — hive, mozart
    # and platform all do, and all three pin `latest.rustfmt` in their dev shell
    # — plain nixpkgs rustfmt otherwise, so this module stays usable (and
    # checkable here) without fenix. mkDefault so a repo can pin its own.
    package = lib.mkDefault (pkgs.fenix.latest.rustfmt or pkgs.rustfmt);
  };

  # Cargo.toml dependency sorting. cargo-sort is the only Cargo-aware tool: it
  # sorts `[dependencies]` / `[workspace.dependencies]` only, leaving
  # `[profile.*]` and lint tables untouched. `--no-format` leaves all formatting
  # to taplo; the higher priority runs it after taplo.
  settings.formatter.cargo-sort = {
    command = "${cargo-sort-wrapped}/bin/cargo-sort";
    options = [
      "--grouped"
      "--no-format"
    ];
    # treefmt globs match the whole relative path: a bare `Cargo.toml` only hits
    # the workspace root, so `**/Cargo.toml` is needed for the members.
    includes = [
      "Cargo.toml"
      "**/Cargo.toml"
    ];
    priority = 2;
  };

  # ponytail: `rustfmt.toml` stays committed per repo. rustfmt has no
  # store-path config that rust-analyzer would also honour, so moving it here
  # would blind every editor. hive and mozart have already drifted — hive adds
  # `wrap_comments`, `imports_granularity` and `group_imports` — converge those
  # by hand, then keep them in sync with a committed file, not with Nix.
}
