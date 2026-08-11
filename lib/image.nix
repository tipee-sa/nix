# OCI image scaffolding over nix2container: `mkRoot` builds an image root,
# `mkImage` wraps it with the layer and config conventions the fleet expects.
{ pkgs, inputs }:
let
  inherit (pkgs) lib;

  nix2container = inputs.nix2container.packages.${pkgs.stdenv.hostPlatform.system}.nix2container;

  base = {
    # TLS roots for outbound HTTPS and `/etc/passwd` so a non-root `User`
    # resolves.
    paths = [
      pkgs.cacert
      pkgs.fakeNss
    ];

    # The store is read-only, so the sticky world-writable bits on `/tmp` can only
    # come from the layer metadata in `mkImage`.
    tmp = pkgs.runCommand "image-tmp" { } "mkdir -p $out/tmp";

    env = [
      "PATH=/bin"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };
in
{
  inherit nix2container;

  # Two of the linked paths populate `/etc`, which is what keeps it a real
  # directory instead of a store symlink; the docker driver can then bind-mount
  # `/etc/resolv.conf` and friends into it.
  mkRoot =
    name: paths:
    pkgs.buildEnv {
      inherit name;
      paths = paths ++ base.paths;
      pathsToLink = [
        "/bin"
        "/etc"
      ];
    };

  # `Entrypoint` rather than `Cmd`: Nomad appends a task's `args` to an
  # entrypoint but replaces a bare `Cmd`, so a task that later grows an `args`
  # block would exec its own first flag.
  mkImage =
    {
      name,
      tag ? null,
      roots,
      entrypoint,
      cmd ? null,
      user ? null,
    }:
    nix2container.buildImage (
      {
        inherit name;
        # Lowering this coalesces store paths into shared layers and defeats
        # registry-side reuse of an unchanged glibc or cert bundle across pushes.
        maxLayers = 100;
        copyToRoot = roots ++ [ base.tmp ];
        perms = [
          {
            path = base.tmp;
            regex = "/tmp";
            mode = "1777";
          }
        ];
        config = {
          Entrypoint = entrypoint;
          Env = base.env;
        }
        // lib.optionalAttrs (cmd != null) { Cmd = cmd; }
        // lib.optionalAttrs (user != null) { User = user; };
      }
      // lib.optionalAttrs (tag != null) { inherit tag; }
    );
}
