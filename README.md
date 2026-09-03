# tipee SA Nix

What tipee repos share, as one flake input: third-party **packages**, **treefmt
modules**, and **`lib` helpers**.

```nix
tipee.url = "github:tipee-sa/nix";
tipee.inputs.nixpkgs.follows = "nixpkgs";
tipee.inputs.blueprint.follows = "blueprint";
# Redirect these too if you hold them, or the closure carries two copies:
tipee.inputs.nix2container.follows = "nix2container";
tipee.inputs.treefmt-nix.follows = "treefmt-nix";
```

## templates/

```
nix flake init -t github:tipee-sa/nix#rust
nix flake init -t github:tipee-sa/nix#javascript
```

Working consumers. `rust` covers the deployed shape: `overlays.default` for
cockroachdb and `lib.rust.devToolchain` in the dev shell, `fleetRustflags` and
`lib.image` in the package, crane for the build. `javascript` covers a repo
where `nix fmt` owns the JS tree, and applies no overlay — every package here is
infrastructure a JS project has no use for.

Both build as initialised, and both are `nix fmt`-clean on the first run.
Neither is exercised by this repo's `nix flake check` — they are separate flakes
— so changing a module means re-initialising one to confirm it still works.

## packages/

`fetchzip` wrappers around upstream releases: cockroachdb, consul, dcg, molt,
nomad. Reach them through `overlays.default` as `pkgs.<name>`, or as
`perSystem.tipee.<name>`.

`.github/workflows/update.yml` bumps them nightly, authenticating each archive
before pinning it, then warms the binary cache.

Adding one: `packages/<name>/{default.nix,hashes.json,update.sh}`. Blueprint
discovers it; `flake.nix` does not change.

## modules/treefmt/

treefmt-nix modules. Import the ones that apply; keep repo-shaped settings
local.

```nix
# nix/formatter.nix
{ inputs, pkgs, ... }:
(inputs.treefmt-nix.lib.evalModule pkgs {
  imports = (with inputs.tipee.modules.treefmt; [ common markdown rust ]) ++ [ ./treefmt.nix ];
}).config.build.wrapper
```

| module     | enables                                                               |
| ---------- | --------------------------------------------------------------------- |
| `common`   | `projectRootFile`, nixfmt, shfmt, just                                |
| `markdown` | oxfmt over `*.md`, store-path config: printWidth 80, proseWrap always |
| `js`       | imports `markdown`, widens oxfmt to the JS/TS/CSS/JSON/YAML tree      |
| `rust`     | taplo, rustfmt (edition 2024), cargo-sort                             |

Import **`js` only where Nix owns JS formatting**. A repo whose `package.json`
defines a `format` script runs its own oxfmt or prettier over the same files;
importing `js` there puts two formatters on every file. Import `markdown` alone
in that case.

Options merge, so a repo adds `programs.*` and `settings.formatter.*` on top and
overrides a shared value with `lib.mkForce`. Blueprint discovers
`modules/<class>/<name>.nix`, so a new module needs no `flake.nix` change.

### Not provided

- **`rustfmt.toml`** — commit one per repo. rustfmt has no store-path config
  that rust-analyzer also reads, so a shared one would leave editors formatting
  differently from `nix fmt`.
- **oxlint and PHP rules** — oxlint resolves config and plugins through node,
  `easy-coding-standard.php` through composer. Nix pins the formatter binaries
  here; the package manager owns the rules.
- **`nixConfig`** — flake-level `nixConfig` does not compose through inputs, so
  the `nix-cache.tipee.cloud` block belongs in each consumer's `flake.nix`.
- **terraform, nomad, go and deno formatters** — one consumer each so far.

## lib/

Helpers that take the consumer's `pkgs`, so they cannot be flake outputs.

```nix
inherit (inputs.tipee.lib.image pkgs) mkImage mkRoot;
inherit (inputs.tipee.lib.rust pkgs) devToolchain fleetRustflags;
```

**`lib.image`** — `mkRoot name paths` builds an image root with TLS roots and
`/etc/passwd`; `mkImage` wraps it with the fleet's layer and config conventions.
It sets `Entrypoint`, not `Cmd`, because Nomad appends a task's `args` to an
entrypoint but replaces a bare `Cmd`. A package moving off `Cmd` should check
its Nomad task first.

**`lib.rust`** — `devToolchain` for dev shells (a package pins its own
toolchain), and `fleetRustflags`, the CPU baseline deployed binaries are built
with. Both need the fenix overlay on the `pkgs` passed in; `devToolchain` throws
with instructions otherwise.

crane is deliberately absent:
`(crane.mkLib pkgs).overrideToolchain (p: p.fenix.stable.minimalToolchain)` is
one line, and adding crane as an input here puts it in every consumer's closure.

## Adopting the treefmt modules

Both formatter changes below rewrite files, so land the reformat separately from
the wiring.

- **oxfmt replaces prettier** where a repo used prettier. Output is
  Prettier-compatible, so the style holds; oxfmt's coverage is wider, so files
  prettier never matched get formatted for the first time.
- **`common` enables shfmt and just.** A repo that ran neither starts formatting
  every shell script and justfile it has.
- Exclude paths another formatter owns, such as a `deno fmt` tree, with
  `settings.formatter.oxfmt.excludes`.

The store-path oxfmt config is authoritative for `nix fmt` and CI. The oxfmt
LSP/IDE plugin looks for a tree-local `.oxfmtrc.json` and finds none; if that
bites, expose the config as a package here and `ln -sf` it from a devshell
`shellHook`.

## Checks

`nix fmt` formats this repo with the modules it publishes, and
`checks.<system>.treefmt` fails when the tree is not clean — so a module that
stops evaluating fails here rather than in a consumer.
