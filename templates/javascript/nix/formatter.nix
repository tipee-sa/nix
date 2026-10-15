# `js` hands the whole tree to oxfmt, so package.json must not also define a
# `format` script — two formatters over the same files fight on every run. Where
# pnpm owns formatting instead, import `markdown` alone and drop `js`.
{ inputs, pkgs, ... }:
(inputs.treefmt-nix.lib.evalModule pkgs {
  imports = with inputs.tipee.modules.treefmt; [
    common
    js
  ];

  settings.global.excludes = [
    # pnpm rewrites the lockfile in its own YAML style on every install.
    "pnpm-lock.yaml"
  ];
}).config.build.wrapper
