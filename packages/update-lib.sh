# Driver for the packages/<pname>/update-hashes.sh convention.
#
# A package script sources this file, defines the hooks below, and ends with
# `update_hashes "$@"`. The platforms to refresh are read from the package's
# own hashes.json, so adding one is a JSON edit.
#
# Hooks:
#   latest_version CURRENT     required, prints the newest upstream version
#   source_url VERSION SYSTEM  required, prints one platform's download URL
#   verify_version VERSION     optional, checks the built binary reports VERSION
#
# Recorded hashes are the NAR hash of the unpacked archive, which is what
# `nix flake prefetch` reports and what fetchzip expects. A package fetching
# with fetchurl would need the flat file hash and does not fit this driver.

set -euo pipefail

die() {
	echo "error: $*" >&2
	exit 1
}

# Highest of the versions on stdin.
highest() { sort -V | tail -n1; }

prefetch_hash() {
	local hash
	# Plain assignment, so set -e aborts when the download fails.
	hash=$(nix flake prefetch --refresh --json "$1" | jq -r .hash)
	[ -n "$hash" ] && [ "$hash" != null ] || die "no hash for $1"
	printf '%s\n' "$hash"
}

update_hashes() {
	local commit=true dry_run=false arg
	for arg in "$@"; do
		case $arg in
		--no-commit) commit=false ;;
		--dry-run)
			dry_run=true
			commit=false
			;;
		-h | --help)
			echo "usage: $(basename "$0") [--no-commit] [--dry-run]"
			return 0
			;;
		*) die "unknown argument: $arg" ;;
		esac
	done

	local dir pname hashes from to
	dir=$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)
	pname=$(basename "$dir")
	hashes=$dir/hashes.json
	[ -f "$hashes" ] || die "$pname: no hashes.json"

	# Exported so hooks can address the flake without rediscovering the root.
	repo=$(git -C "$dir" rev-parse --show-toplevel)

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
		hash=$(prefetch_hash "$url")
		printf '  %-16s %s\n' "$system" "$hash"
		updated=$(printf '%s' "$updated" |
			jq --arg s "$system" --arg u "$url" --arg h "$hash" \
				'.sources[$s] = {url: $u, hash: $h}')
	done
	printf '%s\n' "$updated" >"$hashes"

	# Only the host system is buildable here. The other platforms' hashes are
	# still validated, by the prefetch download itself: a NAR hash of the
	# unpacked tree is platform independent.
	echo "building..."
	nix build --no-link "$repo#$pname"
	if declare -F verify_version >/dev/null; then
		verify_version "$to"
	fi

	[ "$commit" = true ] || return 0

	git -C "$repo" add "$hashes"
	git -C "$repo" commit -m "$pname: update $from → $to"
}
