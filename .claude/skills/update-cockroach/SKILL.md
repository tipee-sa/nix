---
name: update-cockroach
description: Update CockroachDB and related tools (MOLT) to their latest versions. Fetches latest versions, updates Nix package files with new hashes, and verifies builds.
user-invocable: true
allowed-tools: WebFetch, Bash(nix *), Read, Edit, Grep, Glob, mcp__github__list_tags
---

# Update CockroachDB & Tools

Update CockroachDB and its related tools to the latest available versions, then verify builds.

## Packages

| Package | Nix file | Version source | Binary URL pattern |
|---------|----------|----------------|--------------------|
| CockroachDB | `pkgs/cockroachdb.nix` | GitHub tags on `cockroachdb/cockroach` | `https://binaries.cockroachdb.com/cockroach-v{version}.linux-{amd64,arm64}.tgz` |
| MOLT | `pkgs/molt.nix` | Version manifest at `https://molt.cockroachdb.com/molt/cli/versions.txt` | `https://molt.cockroachdb.com/molt/cli/molt-{version}.linux-{amd64,arm64}.tgz` |

## Steps

### 1. Determine current versions

Read both Nix package files and extract the current `version = "..."` values.

### 2. Fetch the latest versions

**CockroachDB:** Use the `mcp__github__list_tags` tool for `owner: cockroachdb`, `repo: cockroach`, `perPage: 30`. Pick the highest stable tag matching `vX.Y.Z` (no alpha/beta/rc suffixes). Sort by semver, not by list order — a patch on an older branch (e.g. v25.4.6) may appear before the latest major (e.g. v26.1.0). Strip the leading `v` for the version string.

**MOLT:** Fetch `https://molt.cockroachdb.com/molt/cli/versions.txt` and extract the highest semver from lines matching `molt-X.Y.Z`.

### 3. Compare and report

Print a summary of current vs latest versions. If already up to date, stop here.

### 4. Prefetch hashes

For each package that needs updating, run `nix flake prefetch` for every architecture to get SRI hashes:

```
nix flake prefetch --json '<url>' 2>/dev/null | nix-shell -p jq --run 'jq -r .hash'
```

Run all prefetch commands in parallel to save time.

### 5. Update Nix files

Edit the `version` and `hash` fields in each package file. Be precise — each architecture has its own hash.

### 6. Build and verify

Run `nix build .#<package>` for each updated package. Then verify the installed version:

- **CockroachDB:** `nix run .#cockroachdb -- version` — first output line is `Build Tag:        vX.Y.Z`
- **MOLT:** `nix run .#molt -- --version` — outputs `molt version vX.Y.Z`
