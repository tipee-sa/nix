#!/usr/bin/env bash
#
# Updates packages/<pname>/hashes.json to the newest upstream release, builds
# the result and commits it. With no arguments, every package under packages/.
#
# Each package is described by packages/<pname>/update.sh, which is sourced and
# declares:
#   latest_version CURRENT             required, prints the newest upstream version
#   source_url VERSION SYSTEM          required, prints one platform's download URL
#   verify_source VERSION SYSTEM FILE  optional, authenticates the archive
#   verify_version VERSION             optional, checks the built binary reports VERSION
#
# `die`, `fetch`, `highest`, `repo`, `with_pkg`, `verify_gpg_sha256sums` and
# `verify_minisign` are available to those hooks. A package declaring no
# verify_source is recorded as UNVERIFIED, which is the honest label for an
# upstream publishing nothing to authenticate a download against.
#
# Recorded hashes are the NAR hash of the unpacked archive, which is what
# `nix flake prefetch` reports and what fetchzip expects. A package fetching
# with fetchurl would need the flat file hash and does not fit this driver.

set -euo pipefail

repo=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
dry_run=false

die() {
	echo "error: $*" >&2
	exit 1
}

highest() { sort -V | tail -n1; }

# A redirect to plain http would otherwise strip the transport authentication
# the rest of this script builds on.
fetch() {
	curl -fsSL --proto '=https' --proto-redir '=https' -o "$2" "$1" ||
		die "cannot fetch $1"
}

# Verification tools come from the flake's locked nixpkgs rather than whatever
# the runner happens to have installed.
with_pkg() {
	local pkg=$1
	shift
	nix shell --inputs-from "$repo" "nixpkgs#$pkg" -c "$@"
}

# ARCHIVE must be listed in a SHA256SUMS file carrying a detached GPG signature
# at SUMS_URL.sig, made by a key pinned under scripts/keys.
verify_gpg_sha256sums() {
	local key=$1 sums_url=$2 archive=$3
	local dir name want got
	dir=$(dirname "$archive")
	name=$(basename "$archive")

	fetch "$sums_url" "$dir/SHA256SUMS"
	fetch "$sums_url.sig" "$dir/SHA256SUMS.sig"
	with_pkg gnupg gpg --batch --yes --dearmor -o "$dir/key.gpg" "$repo/scripts/keys/$key"
	with_pkg gnupg gpgv --keyring "$dir/key.gpg" \
		"$dir/SHA256SUMS.sig" "$dir/SHA256SUMS" ||
		die "SHA256SUMS is not signed by $key"

	want=$(awk -v n="$name" '$2 == n || $2 == "*" n {print $1}' "$dir/SHA256SUMS")
	[ -n "$want" ] || die "$name is absent from SHA256SUMS"
	got=$(sha256sum "$archive" | cut -d' ' -f1)
	[ "$want" = "$got" ] || die "$name does not match its signed checksum"
}

# ARCHIVE must carry a minisign signature at SIG_URL made by PUBKEY.
verify_minisign() {
	local pubkey=$1 sig_url=$2 archive=$3
	fetch "$sig_url" "$archive.minisig"
	with_pkg minisign minisign -Vm "$archive" -P "$pubkey" >/dev/null ||
		die "$(basename "$archive") is not signed by the pinned key"
}

update_one() {
	local pname=$1 dir hashes from to
	dir=$repo/packages/$pname
	hashes=$dir/hashes.json
	[ -f "$dir/update.sh" ] || die "$pname: no update.sh"

	# shellcheck source=/dev/null
	. "$dir/update.sh"

	from=$(jq -r .version "$hashes")
	to=$(latest_version "$from")
	[ -n "$to" ] || die "$pname: upstream reported no version"
	printf '%s  %s -> %s\n' "$pname" "$from" "$to"

	if [ "$to" = "$from" ]; then
		echo "already up to date"
		return 0
	fi

	if [ "$dry_run" = true ]; then
		echo "dry run, no files touched"
		return 0
	fi

	local updated system url hash archive mark

	# `tmp` is deliberately not local: the EXIT trap also runs once this
	# function has returned, in a scope where a local would no longer exist.
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT

	updated=$(jq --arg v "$to" '.version = $v' "$hashes")
	for system in $(jq -r '.sources | keys[]' "$hashes"); do
		url=$(source_url "$to" "$system")
		archive=$tmp/${url##*/}
		fetch "$url" "$archive"

		if declare -F verify_source >/dev/null; then
			verify_source "$to" "$system" "$archive"
			mark=verified
		else
			mark=UNVERIFIED
		fi

		# Hashing the bytes just authenticated. Prefetching the URL again here
		# would pin something nothing has vouched for.
		hash=$(nix flake prefetch --json "file://$archive" | jq -r .hash)
		[ -n "$hash" ] && [ "$hash" != null ] || die "no hash for $url"
		printf '  %-16s %-10s %s\n' "$system" "$mark" "$hash"
		updated=$(jq --arg s "$system" --arg u "$url" --arg h "$hash" \
			'.sources[$s] = {url: $u, hash: $h}' <<<"$updated")
	done
	printf '%s\n' "$updated" >"$hashes"

	echo "building..."
	nix build --no-link "$repo#$pname"
	if declare -F verify_version >/dev/null; then
		verify_version "$to"
	fi

	git -C "$repo" add "$hashes"
	git -C "$repo" commit -m "$pname: update $from → $to"
}

names=()
for arg in "$@"; do
	case $arg in
	--dry-run) dry_run=true ;;
	-*) die "unknown argument: $arg" ;;
	*) names+=("$arg") ;;
	esac
done

if [ ${#names[@]} -eq 0 ]; then
	for hook in "$repo"/packages/*/update.sh; do
		names+=("$(basename "$(dirname "$hook")")")
	done
fi

# A subshell per package, so a hook declared by one is not still defined for the
# next: an optional hook would otherwise leak across packages.
#
# `set -e` is re-armed inside because bash suppresses errexit for a command in
# an AND-OR list and the suppression is inherited by the subshell, which would
# let a failed build fall through to the commit below.
rc=0
set +e
for name in "${names[@]}"; do
	(
		set -e
		update_one "$name"
	)
	[ $? -eq 0 ] || rc=1
done
set -e
exit $rc
