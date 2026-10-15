# `nix fmt` for this repo, built from the modules it publishes.
{ inputs, pkgs, ... }:
let
  treefmt = inputs.treefmt-nix.lib.evalModule pkgs {
    # `rust` stays imported despite there being no Rust here: its formatters
    # never match a file, but the import is what makes `checks.treefmt` fail when
    # the module stops evaluating.
    imports = [
      ./modules/treefmt/common.nix
      ./modules/treefmt/js.nix
      ./modules/treefmt/rust.nix
    ];

    # scripts/update.sh rewrites these with jq on every nightly bump.
    settings.global.excludes = [ "packages/*/hashes.json" ];
  };
in
# checks/treefmt.nix reads `passthru.check`. Both must come from this one
# evaluation, or the check and `nix fmt` can disagree on what is clean.
treefmt.config.build.wrapper.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    check = treefmt.config.build.check;
  };
})
