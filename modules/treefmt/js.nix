# Extends `markdown` to hand the whole JS tree to oxfmt.
#
# Import only where Nix owns JS formatting. Where a package manager formats the
# same files — an `oxfmt` or `prettier` script in package.json — two formatters
# end up fighting over every file, which no setting here resolves; import
# `markdown` alone there.
{ ... }:
{
  imports = [ ./markdown.nix ];

  # oxfmt's default `includes` less `*.md`, which `markdown.nix` contributes.
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
}
