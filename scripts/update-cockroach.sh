#!/usr/bin/env bash
#
# Mechanical updater for pkgs/cockroachdb.nix and pkgs/molt.nix.
#
# Version sources:
#   cockroachdb  the same update service every cockroach node and every DB
#                Console asks, https://register.cockroachdb.com/api/clusters/updates.
#                Given a current version it answers with the releases Cockroach
#                Labs wants you to move to — across major boundaries — or with
#                nothing when there is no newer release. Git tags are read too,
#                but only to report drift: tags can run ahead of what the
#                service advertises.
#   molt         https://molt.cockroachdb.com/molt/cli/versions.txt
#
# Majors are taken as they come. A new major also means moving the
# cockroachdb/cockroach:latest-v<major> image tag in the tipee-sa compose.yaml,
# which lives in another repository and cannot be touched from here, so the PR
# body calls it out.
#
# The URL templates below duplicate those in the Nix files; keep them in step.

set -euo pipefail

dry_run=false
commit=false
for arg in "$@"; do
	case $arg in
	--commit) commit=true ;;
	--dry-run) dry_run=true ;;
	-h | --help)
		sed -n '2,/^$/s/^#\s\?//p' "$0"
		exit 0
		;;
	*)
		echo "unknown argument: $arg" >&2
		exit 2
		;;
	esac
done

cd "$(git rev-parse --show-toplevel)"

crdb_nix=pkgs/cockroachdb.nix
molt_nix=pkgs/molt.nix

# Synthetic all-zero cluster ID. This is a phone-home endpoint and we are not a
# cluster; the answer depends only on the version we ask about.
updates_url=https://register.cockroachdb.com/api/clusters/updates
cluster_uuid=00000000-0000-0000-0000-000000000000

die() {
	echo "error: $*" >&2
	exit 1
}

read_version() {
	local v
	v=$(sed -n 's/^  version = "\([^"]*\)";$/\1/p' "$1")
	[ -n "$v" ] || die "no version line found in $1"
	printf '%s\n' "$v"
}

highest() { sort -V | tail -n1; }

# True when $1 is a strictly higher version than $2.
newer_than() {
	[ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | highest)" = "$1" ]
}

crdb_tags() {
	git ls-remote --tags --refs https://github.com/cockroachdb/cockroach |
		sed -n 's#.*refs/tags/v\([0-9][0-9.]*\)$#\1#p' |
		grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'
}

molt_versions() {
	# Keyed on the linux-amd64 asset so that a listed version is, by
	# construction, one we can actually download.
	curl -fsSL https://molt.cockroachdb.com/molt/cli/versions.txt |
		sed -n 's#.*/molt-\([0-9][0-9.]*\)\.linux-amd64\.tgz$#\1#p' |
		grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -u
}

set_version() {
	grep -q '^  version = "' "$1" || die "version line not found in $1"
	sed -i "s|^  version = \".*\";\$|  version = \"$2\";|" "$1"
}

# Replaces the hash on the first `hash = ` line following the URL that contains
# the given marker, so each architecture keeps its own hash.
set_hash() {
	local file=$1 marker=$2 hash=$3 tmp
	grep -qF "$marker" "$file" ||
		die "URL marker '$marker' not found in $file — upstream naming changed?"
	tmp=$(mktemp)
	awk -v m="$marker" -v h="$hash" '
		index($0, m) { hit = 1 }
		hit && /hash = "sha256-/ { sub(/sha256-[^"]*/, h); hit = 0 }
		{ print }
	' "$file" >"$tmp"
	mv "$tmp" "$file"
}

update_src() {
	local file=$1 marker=$2 url=$3 hash
	# Plain assignment, so set -e aborts when the download fails.
	hash=$(nix flake prefetch --refresh --json "$url" | jq -r .hash)
	[ -n "$hash" ] && [ "$hash" != null ] || die "no hash for $url"
	set_hash "$file" "$marker" "$hash"
}

crdb_from=$(read_version "$crdb_nix")
molt_from=$(read_version "$molt_nix")

# Ask Cockroach Labs what to move to. A malformed or unreachable answer is a
# hard failure: silently falling back to git tags would change policy.
updates=$(curl -fsSL --get "$updates_url" \
	--data-urlencode "uuid=$cluster_uuid" \
	--data-urlencode "version=v$crdb_from")
advertised=$(printf '%s' "$updates" | jq -r '(.details // [])[].version' |
	sed 's/^v//' | highest)

crdb_to=${advertised:-$crdb_from}
molt_to=$(molt_versions | highest)

printf 'cockroachdb  %s -> %s  (cockroach labs advertises: %s)\n' \
	"$crdb_from" "$crdb_to" "${advertised:-nothing newer}"
printf 'molt         %s -> %s\n' "$molt_from" "$molt_to"

# Tags are informational only. They regularly carry a release that the update
# service does not advertise yet, which is worth seeing but not worth acting on.
crdb_tag_max=$(crdb_tags | highest)
tag_drift=
if newer_than "$crdb_tag_max" "$crdb_to"; then
	tag_drift="v$crdb_tag_max is tagged upstream but not advertised by Cockroach Labs"
	echo "note: $tag_drift"
fi

series_change=false
if [ "${crdb_to%.*}" != "${crdb_from%.*}" ]; then
	series_change=true
	echo "note: release series changes ${crdb_from%.*} -> ${crdb_to%.*}"
fi

if [ "$dry_run" = true ]; then
	echo "dry run, no files touched"
	exit 0
fi

if [ "$crdb_to" = "$crdb_from" ] && [ "$molt_to" = "$molt_from" ]; then
	echo "already up to date"
	exit 0
fi

if [ "$crdb_to" != "$crdb_from" ]; then
	base=https://binaries.cockroachdb.com/cockroach-v$crdb_to
	set_version "$crdb_nix" "$crdb_to"
	update_src "$crdb_nix" linux-amd64.tgz "$base.linux-amd64.tgz"
	update_src "$crdb_nix" linux-arm64.tgz "$base.linux-arm64.tgz"
	update_src "$crdb_nix" darwin-11.0-arm64.tgz "$base.darwin-11.0-arm64.tgz"
fi

if [ "$molt_to" != "$molt_from" ]; then
	base=https://molt.cockroachdb.com/molt/cli/molt-$molt_to
	set_version "$molt_nix" "$molt_to"
	update_src "$molt_nix" linux-amd64.tgz "$base.linux-amd64.tgz"
	update_src "$molt_nix" linux-arm64.tgz "$base.linux-arm64.tgz"
fi

# Only x86_64-linux is buildable here. The aarch64-linux and aarch64-darwin
# hashes are still validated, by the prefetch download itself: fetchzip hashes
# are the NAR hash of the unpacked tree and so are platform independent.
echo "building..."
nix build --no-link .#cockroachdb .#molt

got=$(nix run .#cockroachdb -- version | sed -n 's/^Build Tag: *v//p' | head -n1)
[ "$got" = "$crdb_to" ] || die "cockroachdb reports '$got', expected '$crdb_to'"
got=$(nix run .#molt -- --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
[ "$got" = "$molt_to" ] || die "molt reports '$got', expected '$molt_to'"
echo "verified cockroachdb $crdb_to and molt $molt_to on x86_64-linux"

subject="cockroach: update "
if [ "$crdb_to" != "$crdb_from" ] && [ "$molt_to" != "$molt_from" ]; then
	subject+="cockroachdb to $crdb_to and molt to $molt_to"
elif [ "$crdb_to" != "$crdb_from" ]; then
	subject+="cockroachdb to $crdb_to"
else
	subject+="molt to $molt_to"
fi
echo "$subject"

[ "$commit" = true ] || exit 0

git add "$crdb_nix" "$molt_nix"
if [ "$series_change" = true ]; then
	# A series change is the one case where the commit needs to explain itself:
	# the image tag it has to stay in step with lives in another repository.
	git commit -m "$subject" -m "The tipee-sa compose.yaml pins cockroachdb/cockroach:latest-v${crdb_from%.*} and must
move in step. CockroachDB majors cannot be skipped, nor downgraded once
finalized."
else
	git commit -m "$subject"
fi
