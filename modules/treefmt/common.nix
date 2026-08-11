# Formatters every tipee repo already enables, verbatim and identically:
# hive/treefmt.nix, mozart/nix/treefmt.nix and platform/nix/formatter.nix all
# set exactly these four.
#
# Import alongside the language modules that apply (`js`, `rust`). Options merge,
# so a repo adds its own `programs.*` / `settings.formatter.*` on top and
# overrides a shared value with `lib.mkForce`.
{ lib, ... }:
{
  # Every tipee repo is a flake, so this is the root marker everywhere.
  # mkDefault so a repo with a different layout can still override it.
  projectRootFile = lib.mkDefault "flake.nix";

  programs.nixfmt.enable = true;
  programs.shfmt.enable = true;
  programs.just.enable = true;

  # ponytail: no shared `settings.global.excludes`. Every exclude in the three
  # repos today is repo-shaped (`.sqlx/*`, `yaak/*`, `hack/grafana/dashboard.json`,
  # `crates/hive-ui/app/dist/*`), and treefmt only walks git-tracked files, so
  # `target/*` and `node_modules/*` are already handled by .gitignore. Add a
  # shared exclude here once the same path shows up in three repos.
}
