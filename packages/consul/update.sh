# Version source: https://api.releases.hashicorp.com/v1/releases/consul/latest.
# Enterprise and musl builds carry a +ent suffix and fail the shape check.

latest_version() {
	local release version
	release=$(curl -fsSL https://api.releases.hashicorp.com/v1/releases/consul/latest)
	version=$(printf '%s' "$release" | jq -r 'select(.is_prerelease | not) | .version')
	printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' ||
		die "consul: unusable latest release '$version'"
	printf '%s\n' "$version"
}

source_url() {
	local arch
	case $2 in
	x86_64-linux) arch=linux_amd64 ;;
	aarch64-linux) arch=linux_arm64 ;;
	aarch64-darwin) arch=darwin_arm64 ;;
	*) die "consul: no source for $2" ;;
	esac
	printf 'https://releases.hashicorp.com/consul/%s/consul_%s_%s.zip\n' "$1" "$1" "$arch"
}

verify_source() {
	verify_gpg_sha256sums hashicorp-release.asc \
		"https://releases.hashicorp.com/consul/$1/consul_$1_SHA256SUMS" "$3"
}

verify_version() {
	local got
	got=$(nix run "$repo#consul" -- version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
	[ "$got" = "$1" ] || die "consul reports '$got', expected '$1'"
}
