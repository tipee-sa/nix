# `nix fmt` for this repo, built from the modules it publishes — so a broken
# shared module fails here before any consumer sees it. `rust` is imported even
# though there is no Rust code in this tree: with no *.rs and no Cargo.toml its
# formatters never fire, but the module still has to evaluate and its tools still
# have to build, which is the coverage worth having.
{ inputs, pkgs, ... }:
let
  treefmt = inputs.treefmt-nix.lib.evalModule pkgs {
    # `js` pulls in `markdown`, so all four published modules are exercised.
    imports = [
      ./modules/treefmt/common.nix
      ./modules/treefmt/js.nix
      ./modules/treefmt/rust.nix
    ];

    # jq writes these on every nightly bump (scripts/update.sh) in its own style.
    # Letting oxfmt reformat them would fight the updater exactly as it would
    # fight `cargo sqlx prepare` in hive.
    settings.global.excludes = [ "packages/*/hashes.json" ];
  };
in
# Return the `nix fmt` wrapper, but smuggle the treefmt-nix flake check through
# passthru so checks/treefmt.nix can reuse *this* evaluation — same idiom as
# platform/nix/formatter.nix.
treefmt.config.build.wrapper.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    check = treefmt.config.build.check;
  };
})
