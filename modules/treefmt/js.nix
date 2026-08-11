# Hands the whole JS tree to oxfmt, on top of the prose style in `markdown.nix`.
#
# Import this ONLY where Nix owns JS formatting. It is right for hive, whose
# `nix fmt` already formats `crates/hive-ui/app`, and for mozart and platform,
# whose prettier `includes` lists are narrower than this by accident rather than
# by design.
#
# It is WRONG for tipee: `react/package.json` defines `"format": "oxfmt"` against
# its own `react/node_modules/oxfmt`, so pnpm owns that tree. tipee should import
# `markdown` alone and leave it that way — two formatters on one file is a fight
# no config setting resolves.
#
# The file list is oxfmt's own default `includes` minus `*.md`, which
# `markdown.nix` already contributes; module lists concatenate.
{ ... }:
{
  imports = [ ./markdown.nix ];

  programs.oxfmt.includes = [
    "*.cjs"
    "*.css"
    "*.graphql"
    "*.hbs"
    "*.html"
    "*.js"
    "*.json"
    "*.json5"
    "*.jsonc"
    "*.jsx"
    "*.mdx"
    "*.mjs"
    "*.mustache"
    "*.scss"
    "*.ts"
    "*.tsx"
    "*.vue"
    "*.yaml"
    "*.yml"
  ];

  # ponytail: no shared oxlint config. oxlint resolves config and plugins through
  # node, not Nix — sharing hive's `.oxlintrc.json` and its `better-tailwindcss`
  # rules means shipping an npm package, which is a different project. Nix owns
  # the tool version here; npm owns the lint rules.
}
