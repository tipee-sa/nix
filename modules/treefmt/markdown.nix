# The tipee prose style, via oxfmt on Markdown only.
#
# This is the one formatting decision all four repos already agree on:
# printWidth 80 with proseWrap always. hive and tipee reach it with oxfmt,
# mozart and platform with prettier — oxfmt wins because it is what the two
# repos that thought about it hardest already run, and its output is
# Prettier-compatible, so the style does not change for the other two.
#
# Markdown is separate from `js.nix` on purpose. tipee restricts oxfmt to
# `*.md` because `react/package.json` owns TS formatting through
# `pnpm format` (its own `react/node_modules/oxfmt`); having Nix claim the
# same files would put two formatters on one tree. Import this module when Nix
# should own prose only, `js.nix` when it should own the JS tree as well.
#
# The config lives in the store, not in a per-repo dotfile — the point being
# that a repo cannot drift by editing its own copy. Options are tipee's
# `scripts/oxfmtrc.markdown.json`, the most considered of the four, minus its
# `$schema` (a relative path into node_modules, meaningless from the store).
{ pkgs, ... }:
{
  programs.oxfmt = {
    enable = true;
    # Narrowed from oxfmt's default set, which also claims ts/tsx/css/json/yaml.
    # `js.nix` adds those back; module lists concatenate, so importing both
    # yields markdown plus the JS tree.
    includes = [ "*.md" ];
  };

  # `--config` makes this authoritative, so a repo-local `.oxfmtrc.json` is
  # ignored rather than merged. Do not also pass `--disable-nested-config`: the
  # two are mutually exclusive in oxfmt's argument parser and it exits 1
  # ("`--disable-nested-config` is not expected in this context").
  settings.formatter.oxfmt.options = [
    "--config"
    "${(pkgs.formats.json { }).generate "oxfmtrc.json" {
      printWidth = 80;
      tabWidth = 2;
      useTabs = false;
      proseWrap = "always";
      embeddedLanguageFormatting = "auto";
      insertFinalNewline = true;
      endOfLine = "lf";
    }}"
  ];
}
