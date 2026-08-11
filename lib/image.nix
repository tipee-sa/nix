# OCI image scaffolding over nix2container.
#
# This recipe — `buildEnv` with cacert + fakeNss and `pathsToLink = [ "/bin"
# "/etc" ]`, then `buildImage` with `maxLayers = 100`, a world-writable /tmp and
# `PATH` / `SSL_CERT_FILE` in Env — is currently written out six times:
# hive/packages/hive-server.nix, mozart/nix/image.nix (already factored, this is
# that file moved), and platform's accio, alohomora, gha-scaleset and
# nomad-certmanager. platform's dind-rootless opts out of `buildEnv` on purpose
# (it needs a real directory, not a store symlink) and should keep doing so.
{ pkgs, inputs }:
let
  inherit (pkgs) lib;

  nix2container = inputs.nix2container.packages.${pkgs.stdenv.hostPlatform.system}.nix2container;

  # Layers every image shares: TLS roots for outbound HTTPS, `/etc/passwd` so a
  # non-root `User` resolves, and a world-writable `/tmp` for anything reaching
  # for `std::env::temp_dir`. The store is read-only, so the sticky bit has to
  # come from layer metadata.
  base = {
    paths = [
      pkgs.cacert
      pkgs.fakeNss
    ];

    tmp = pkgs.runCommand "image-tmp" { } "mkdir -p $out/tmp";

    env = [
      "PATH=/bin"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };
in
{
  inherit nix2container;

  # `/etc` ends up a real directory rather than a symlink into the store,
  # because two of the paths populate it — which is what lets the docker driver
  # bind-mount `/etc/resolv.conf` and friends into it.
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

  # `Entrypoint`, not `Cmd`: Nomad's `args` are appended to an entrypoint but
  # *replace* a bare `Cmd`, so a task that later grows an `args` block would
  # otherwise try to exec its first flag. hive currently sets `Cmd` — moving it
  # here is the behaviour change to be aware of when it adopts this.
  #
  # `user = null` keeps the image on root; only a deployed server should drop
  # privileges.
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
        # One layer per store path, so an unchanged glibc or cert bundle is
        # skipped by the registry on the next push.
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
