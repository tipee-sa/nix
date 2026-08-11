# tipee SA Nix

Single source of truth for what tipee repos share: third-party **packages**,
**treefmt modules**, and **`lib` helpers**. Consumed as one flake input by hive,
mozart and platform.

```nix
tipee.url = "github:tipee-sa/nix";
tipee.inputs.nixpkgs.follows = "nixpkgs";
tipee.inputs.blueprint.follows = "blueprint";
# add these two if you already have them, to keep one copy in the closure:
tipee.inputs.nix2container.follows = "nix2container";
tipee.inputs.treefmt-nix.follows = "treefmt-nix";
```

## packages/

`fetchzip` wrappers around upstream releases — cockroachdb, consul, dcg, molt,
nomad. Reached through `overlays.default` (so `pkgs.nomad`) or
`perSystem.tipee.nomad`. Bumped nightly by `.github/workflows/update.yml`, which
authenticates each archive before pinning it, then warms the binary cache.

Adding one: `packages/<name>/{default.nix,hashes.json,update.sh}`. Blueprint
discovers it; no `flake.nix` change.

## modules/treefmt/

treefmt-nix modules. Import the ones that apply and keep only what is
repo-shaped locally:

```nix
# nix/formatter.nix — the only file that changes
{ inputs, pkgs, ... }:
(inputs.treefmt-nix.lib.evalModule pkgs {
  imports = (with inputs.tipee.modules.treefmt; [ common js rust ]) ++ [ ./treefmt.nix ];
}).config.build.wrapper
```

| module | what it enables |
| --- | --- |
| `common` | `projectRootFile`, nixfmt, shfmt, just — all three repos already set exactly these |
| `js` | oxfmt over JS/TS/CSS/MD/JSON/YAML, config in the store (printWidth 80, proseWrap always) |
| `rust` | taplo, rustfmt (edition 2024, fenix nightly if present), cargo-sort |

Modules merge, so a repo overrides with `programs.oxfmt.package = …`, extra
`settings.formatter.*`, or `lib.mkForce` on any shared value. Blueprint
auto-discovers `modules/<class>/<name>.nix`, so adding a module needs no
`flake.nix` change either.

## lib/

Helpers that need a `pkgs`, so they cannot be flake outputs. Each is a function
of the *consumer's* `pkgs` — same reason `overlays.default` extends the caller's
package set instead of exporting from the nixpkgs locked here.

```nix
inherit (inputs.tipee.lib.image pkgs) mkImage mkRoot;
inherit (inputs.tipee.lib.rust pkgs) devToolchain fleetRustflags;
```

- **`lib.image`** — `mkRoot` / `mkImage` over nix2container. This is
  `mozart/nix/image.nix` moved verbatim; the same recipe (buildEnv with cacert +
  fakeNss, `maxLayers = 100`, world-writable `/tmp`, `PATH` + `SSL_CERT_FILE`)
  is written out six times across the three repos.
- **`lib.rust`** — `devToolchain` (the fenix combine block, byte-identical in
  hive and platform) and `fleetRustflags` (`-C target-cpu=x86-64-v3`, the
  production pool baseline hive and mozart both hardcode). Requires the fenix
  overlay; throws with a readable message otherwise.

## Adoption cost, per repo

- **hive** — drop ~60 lines from `treefmt.nix` and delete `.oxfmtrc.json`.
  `lib.image` replaces the inline image block, but `mkImage` sets `Entrypoint`
  where hive currently sets `Cmd`; check the Nomad task before switching.
- **mozart** — delete `nix/image.nix` (it is what `lib.image` became) and the
  duplicated treefmt blocks. prettier → oxfmt is one reformat commit.
- **platform** — same treefmt cleanup; `rust` closes a real gap, since
  `tools/accio` and `tools/alohomora` are Cargo workspaces that nothing
  currently formats. oxfmt would also claim `tools/observability-mcp/*.ts`,
  which `deno fmt` owns — exclude those paths from oxfmt locally.

## Deliberately not shared

- **crane setup.** `(crane.mkLib pkgs).overrideToolchain (p: p.fenix.stable.minimalToolchain)`
  is one line in two repos, and platform uses `buildRustPackage` instead. Adding
  crane as an input here — to a repo everything else depends on — to share one
  line is the wrong trade.
- **`rustfmt.toml`.** rustfmt has no store-path config that rust-analyzer also
  honours, so moving it here would blind every editor. hive and mozart have
  drifted (hive adds `wrap_comments`, `imports_granularity`, `group_imports`);
  converge by hand and keep committing the file.
- **A devshell package list.** Beyond `devToolchain`, the shared entries are
  `jq`, `just-lsp`, `process-compose` — three words per repo. A shared list
  would hide what is in the shell to save three lines. `just` is worse: platform
  wraps it to scope colmena, so a shared plain `just` would collide.
- **oxlint config.** oxlint resolves config and plugins through node, not Nix.
  Sharing hive's `.oxlintrc.json` means shipping an npm package.
- **`nixConfig`.** Flake-level `nixConfig` does not compose through inputs, so
  the `nix-cache.tipee.cloud` block has to be copy-pasted per repo regardless.
- **terraform / nomad / go / deno formatters.** platform only. Revisit at the
  second repo.
- **Formatter versions.** With `tipee.inputs.nixpkgs.follows = "nixpkgs"`, each
  consumer's nixpkgs picks the oxfmt build — shared config, unshared binary.
  That is the same trade `overlays.default` already makes on purpose.

## Editors and the store-path config

`nix fmt` and CI are authoritative and correct. The oxfmt LSP/IDE plugin looks
for a tree-local `.oxfmtrc.json` and will not find one. Fix when it bites:
expose the config as a package here and `ln -sf` it from a devshell
`shellHook`.

## Checks

`nix fmt` formats this repo with its own published modules, and
`checks.<system>.treefmt` fails if the tree is not clean — so a broken module is
caught here before any consumer sees it. `rust` is imported even though there is
no Rust code in this tree: its formatters never fire, but the module still has to
evaluate and its tools still have to build.
