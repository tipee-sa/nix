#!/usr/bin/env bash
#
# Version source: https://molt.cockroachdb.com/molt/cli/versions.txt, keyed on
# the linux-amd64 asset so that a listed version is, by construction, one we
# can actually download.

. "$(dirname "$0")/../update-lib.sh"

latest_version() {
	curl -fsSL https://molt.cockroachdb.com/molt/cli/versions.txt |
		sed -n 's#.*/molt-\([0-9][0-9.]*\)\.linux-amd64\.tgz$#\1#p' |
		grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | highest
}

source_url() {
	local arch
	case $2 in
	x86_64-linux) arch=linux-amd64 ;;
	aarch64-linux) arch=linux-arm64 ;;
	*) die "molt: no source for $2" ;;
	esac
	printf 'https://molt.cockroachdb.com/molt/cli/molt-%s.%s.tgz\n' "$1" "$arch"
}

verify_version() {
	local got
	got=$(nix run "$repo#molt" -- --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
	[ "$got" = "$1" ] || die "molt reports '$got', expected '$1'"
}

update_hashes "$@"
