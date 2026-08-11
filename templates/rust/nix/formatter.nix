# `markdown`, not `js`: this tree has no JavaScript. A repo that also builds an
# SPA and wants `nix fmt` to own it swaps in `js`, which imports `markdown`.
{ inputs, pkgs, ... }:
(inputs.treefmt-nix.lib.evalModule pkgs {
  imports =
    (with inputs.tipee.modules.treefmt; [
      common
      markdown
      rust
    ])
    ++ [ ./treefmt.nix ];
}).config.build.wrapper
