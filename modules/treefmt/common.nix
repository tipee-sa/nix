# The baseline. `projectRootFile` and nixfmt are set identically by all four
# repos; shfmt and just by hive, mozart and platform.
#
# tipee enables neither shfmt nor just today, so importing this starts formatting
# 28 shell scripts and 13 justfiles there — a real reformat commit, not a no-op.
# Land it separately from the wiring.
#
# Import alongside the language modules that apply (`markdown` or `js`, `rust`).
# Options merge, so a repo adds its own `programs.*` / `settings.formatter.*` on
# top and overrides a shared value with `lib.mkForce`.
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
