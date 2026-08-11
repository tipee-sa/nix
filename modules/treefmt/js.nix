# The tipee style for JS/TS/CSS/Markdown/JSON/YAML.
#
# All three repos already agree on the intent — printWidth 80, proseWrap always —
# and disagree on the tool: hive runs oxfmt from a committed `.oxfmtrc.json`,
# mozart and platform run prettier with the settings inline. This module settles
# it on oxfmt: Prettier-compatible output, and its default `includes` covers
# tsx/jsx/css/scss/graphql/vue, which mozart's hand-written `includes` list and
# platform's `**/*.md`-only list both miss.
#
# Cost of adopting: one reformat commit each in mozart and platform, mostly on
# files prettier was never looking at. Style itself does not change.
#
# The config lives in the store, not in a per-repo dotfile. That is the point:
# one file here is the org style and a repo cannot drift by editing its own copy.
# The trade-off is that editors do not see it — see README.
{ pkgs, ... }:
let
  oxfmtrc = (pkgs.formats.json { }).generate "oxfmtrc.json" {
    printWidth = 80;
    proseWrap = "always";
  };
in
{
  programs.oxfmt.enable = true;

  # `-c` makes this config authoritative, so a repo-local `.oxfmtrc.json` is
  # ignored rather than merged. Do not also pass `--disable-nested-config`: the
  # two are mutually exclusive in oxfmt's argument parser and it exits 1
  # ("`--disable-nested-config` is not expected in this context").
  settings.formatter.oxfmt.options = [
    "-c"
    "${oxfmtrc}"
  ];

  # ponytail: no shared oxlint config. oxlint resolves its config and plugins
  # through node, not Nix — hive's `.oxlintrc.json` and the `better-tailwindcss`
  # rules would have to ship as an npm package to be shared, which is a different
  # project. Nix owns the tool version here, npm owns the lint rules.
}
