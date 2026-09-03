# The org prose style — printWidth 80, proseWrap always — as oxfmt over `*.md`.
#
# Import this alone where something outside Nix already formats the JS tree, and
# `js.nix` instead where Nix should own it too.
{ pkgs, ... }:
{
  programs.oxfmt = {
    enable = true;
    # Narrower than oxfmt's default set, which also claims ts/tsx/css/json/yaml.
    # `js.nix` contributes those; module lists concatenate, so importing both
    # yields the union.
    includes = [ "*.md" ];
  };

  # `--config` overrides a repo-local `.oxfmtrc.json` rather than merging with it.
  # Do not also pass `--disable-nested-config`: oxfmt's parser rejects the two
  # together and exits 1.
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
