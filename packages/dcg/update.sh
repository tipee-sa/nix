# Version source: the GitHub releases API. Tags carry a leading v that the
# recorded version does not.

latest_version() {
	local version
	version=$(curl -fsSL \
		https://api.github.com/repos/Dicklesworthstone/destructive_command_guard/releases/latest |
		jq -r 'select(.prerelease | not) | .tag_name' | sed 's/^v//')
	printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' ||
		die "dcg: unusable latest release '$version'"
	printf '%s\n' "$version"
}

# Upstream ships x86_64 against musl but aarch64 against glibc; neither target
# has a counterpart under the other libc.
source_url() {
	local target
	case $2 in
	x86_64-linux) target=x86_64-unknown-linux-musl ;;
	aarch64-linux) target=aarch64-unknown-linux-gnu ;;
	aarch64-darwin) target=aarch64-apple-darwin ;;
	*) die "dcg: no source for $2" ;;
	esac
	printf 'https://github.com/Dicklesworthstone/destructive_command_guard/releases/download/v%s/dcg-%s.tar.xz\n' \
		"$1" "$target"
}

# Pinned rather than read from dcg-minisign-release.pub, which ships in the same
# release as the artifact and so vouches for nothing on its own.
minisign_key=RWSoYi6NXJWzaRs1mJmOwwXrZfPWcq6MXnQlNMLBYKzlIQTLwuVQG6uO

verify_source() {
	verify_minisign "$minisign_key" "$(source_url "$1" "$2").minisig" "$3"
}

verify_version() {
	local got
	got=$(nix run "$repo#dcg" -- --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
	[ "$got" = "$1" ] || die "dcg reports '$got', expected '$1'"
}
