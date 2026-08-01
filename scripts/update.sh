#!/usr/bin/env bash
#
# Updates packages/<pname>/hashes.json to the newest upstream release, builds
# the result and commits it. With no arguments, every package under packages/.
#
# Each package is described by packages/<pname>/update.sh, which is sourced and
# declares:
#   latest_version CURRENT     required, prints the newest upstream version
#   source_url VERSION SYSTEM  required, prints one platform's download URL
#   verify_version VERSION     optional, checks the built binary reports VERSION
#
# `die`, `highest` and `repo` are available to those hooks.
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

	local updated system url hash
	updated=$(jq --arg v "$to" '.version = $v' "$hashes")
	for system in $(jq -r '.sources | keys[]' "$hashes"); do
		url=$(source_url "$to" "$system")
		hash=$(nix flake prefetch --refresh --json "$url" | jq -r .hash)
		[ -n "$hash" ] && [ "$hash" != null ] || die "no hash for $url"
		printf '  %-16s %s\n' "$system" "$hash"
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
