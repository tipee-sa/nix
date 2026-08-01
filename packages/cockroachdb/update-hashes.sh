#!/usr/bin/env bash
#
# Version source: the update service every cockroach node and every DB Console
# asks, https://register.cockroachdb.com/api/clusters/updates. Given a current
# version it answers with the releases Cockroach Labs wants you to move to —
# across major boundaries — or with nothing when there is no newer release.
#
# That answer, not the git tags, is what says a release is truly out: tags are
# pushed and binaries published well before the service advertises them. Tags
# are read anyway, but only to report the drift.

. "$(dirname "$0")/../update-lib.sh"

# Synthetic all-zero cluster ID. This is a phone-home endpoint and we are not a
# cluster; the answer depends only on the version we ask about.
updates_url=https://register.cockroachdb.com/api/clusters/updates
cluster_uuid=00000000-0000-0000-0000-000000000000

tags() {
	git ls-remote --tags --refs https://github.com/cockroachdb/cockroach |
		sed -n 's#.*refs/tags/v\([0-9][0-9.]*\)$#\1#p' |
		grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'
}

latest_version() {
	local updates advertised tag_max

	# A malformed or unreachable answer is a hard failure: silently falling
	# back to the tags would change which release we track.
	updates=$(curl -fsSL --get "$updates_url" \
		--data-urlencode "uuid=$cluster_uuid" \
		--data-urlencode "version=v$1")
	advertised=$(printf '%s' "$updates" | jq -r '(.details // [])[].version' |
		sed 's/^v//' | highest)

	tag_max=$(tags | highest)
	if [ "$tag_max" != "${advertised:-$1}" ] &&
		[ "$(printf '%s\n%s\n' "$tag_max" "${advertised:-$1}" | highest)" = "$tag_max" ]; then
		echo "note: v$tag_max is tagged upstream but not advertised by Cockroach Labs" >&2
	fi

	printf '%s\n' "${advertised:-$1}"
}

source_url() {
	local arch
	case $2 in
	x86_64-linux) arch=linux-amd64 ;;
	aarch64-linux) arch=linux-arm64 ;;
	aarch64-darwin) arch=darwin-11.0-arm64 ;;
	*) die "cockroachdb: no source for $2" ;;
	esac
	printf 'https://binaries.cockroachdb.com/cockroach-v%s.%s.tgz\n' "$1" "$arch"
}

update_hashes "$@"
