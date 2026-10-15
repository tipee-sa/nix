# Repo-local settings only. Formatters come from the tipee modules imported in
# formatter.nix.
{ ... }:
{
  settings.global.excludes = [
    # sqlx rewrites its offline query cache on every `cargo sqlx prepare`, in its
    # own JSON style.
    ".sqlx/*"
  ];
}
