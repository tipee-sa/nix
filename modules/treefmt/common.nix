# Formatters every repo enables regardless of language: nix, shell, justfiles.
#
# Import alongside the language modules that apply: `markdown` or `js`, `rust`.
{ lib, ... }:
{
  projectRootFile = lib.mkDefault "flake.nix";

  programs.nixfmt.enable = true;
  programs.shfmt.enable = true;
  programs.just.enable = true;
}
