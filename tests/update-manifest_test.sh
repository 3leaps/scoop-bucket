#!/usr/bin/env bash
# update-manifest.sh takes hashes only from a SHA256SUMS signed by the pinned
# minisign key. Throwaway keys and a stub gh; nothing real is used.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/repo/bucket" "$TMP/repo/scripts" "$TMP/bin" "$TMP/release"
cp "$ROOT/scripts/update-manifest.sh" "$TMP/repo/scripts/"
cp "$ROOT/bucket/spanwit.json" "$TMP/repo/bucket/"

minisign -G -W -p "$TMP/good.pub" -s "$TMP/good.key" >/dev/null
minisign -G -W -p "$TMP/other.pub" -s "$TMP/other.key" >/dev/null
printf 'spanwit %s\n' "$(sed -n 2p "$TMP/good.pub")" >"$TMP/keys.txt"
export SCOOP_MINISIGN_KEYS_FILE="$TMP/keys.txt"

cat >"$TMP/bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2" == "release view" ]]; then
	cat "${DIGESTS_FIXTURE:?}"
	exit 0
fi
[[ "$1 $2" == "release download" ]] || { echo "unexpected gh call: $*" >&2; exit 1; }
dir=""
while [[ $# -gt 0 ]]; do
	[[ "$1" == "--dir" ]] && dir="$2"
	shift
done
cp "${RELEASE_FIXTURE_DIR:?}/SHA256SUMS" "${RELEASE_FIXTURE_DIR}/SHA256SUMS.minisig" "${dir:?}/"
GH
chmod +x "$TMP/bin/gh"
export RELEASE_FIXTURE_DIR="$TMP/release"
# Release metadata as gh --jq would emit it: one digest per asset.
digests() {
	printf '[{"name":"spanwit_9.9.9_windows_amd64.zip","digest":"sha256:%s"},{"name":"spanwit_9.9.9_windows_arm64.zip","digest":"sha256:%s"}]\n' "$1" "$2" >"$TMP/digests.json"
}
export DIGESTS_FIXTURE="$TMP/digests.json"

amd=1111111111111111111111111111111111111111111111111111111111111111
arm=2222222222222222222222222222222222222222222222222222222222222222
digests "$amd" "$arm"

# sign <key> <comment> [<hash> <name>]...
sign() {
	local key="$1" comment="$2"
	shift 2
	: >"$TMP/release/SHA256SUMS"
	while [[ $# -gt 0 ]]; do
		printf '%s  %s\n' "$1" "$2" >>"$TMP/release/SHA256SUMS"
		shift 2
	done
	minisign -S -W -s "$key" -t "$comment" -m "$TMP/release/SHA256SUMS" >/dev/null
}

run() {
	PATH="$TMP/bin:$PATH" "$TMP/repo/scripts/update-manifest.sh" 3leaps spanwit 9.9.9 --github
}

# expect_refusal <label> <expected error text>
expect_refusal() {
	local label="$1" reason="$2" before err
	before="$(shasum -a 256 "$TMP/repo/bucket/spanwit.json")"
	if err="$(run 2>&1 >/dev/null)"; then
		echo "FAIL expected refusal: $label" >&2
		exit 1
	fi
	if [[ "$err" != *"$reason"* ]]; then
		echo "FAIL $label refused for the wrong reason: $err" >&2
		exit 1
	fi
	if [[ "$(shasum -a 256 "$TMP/repo/bucket/spanwit.json")" != "$before" ]]; then
		echo "FAIL refused run still rewrote the manifest: $label" >&2
		exit 1
	fi
}

sign "$TMP/other.key" "spanwit v9.9.9 2026-01-01T00:00:00Z" \
	"$amd" spanwit_9.9.9_windows_amd64.zip "$arm" spanwit_9.9.9_windows_arm64.zip
expect_refusal "signature from an unpinned key" "does not verify against the pinned key"

sign "$TMP/good.key" "spanwit v9.9.9 2026-01-01T00:00:00Z" \
	"$amd" spanwit_9.9.9_windows_amd64.zip "$arm" spanwit_9.9.9_windows_arm64.zip
sed -i.bak "s/$amd/$arm/" "$TMP/release/SHA256SUMS"
expect_refusal "manifest changed after signing" "does not verify against the pinned key"

sign "$TMP/good.key" "spanwit v9.9.8 2026-01-01T00:00:00Z" \
	"$amd" spanwit_9.9.9_windows_amd64.zip "$arm" spanwit_9.9.9_windows_arm64.zip
expect_refusal "signed manifest for another version" "is signed for v9.9.8"

sign "$TMP/good.key" "spanwit v9.9.9 2026-01-01T00:00:00Z" \
	"$amd" spanwit_9.9.9_windows_amd64.zip
expect_refusal "archive not in signed manifest" "could not find spanwit_9.9.9_windows_arm64.zip"

sign "$TMP/good.key" "spanwit v9.9.9 2026-01-01T00:00:00Z" \
	"$amd" spanwit_9.9.9_windows_amd64.zip "$arm" spanwit_9.9.9_windows_arm64.zip
digests "$arm" "$arm"
expect_refusal "GitHub digest differs from signed manifest" "GitHub digest for spanwit_9.9.9_windows_amd64.zip differs"
digests "$amd" "$arm"

sign "$TMP/good.key" "spanwit v9.9.9 2026-01-01T00:00:00Z" \
	"$amd" spanwit_9.9.9_windows_amd64.zip "$arm" spanwit_9.9.9_windows_arm64.zip "$arm" spanwit_9.9.9_windows_amd64.zip
expect_refusal "duplicate name in signed manifest" "is listed twice"

sign "$TMP/good.key" "spanwit v9.9.9 2026-01-01T00:00:00Z" \
	"$amd" spanwit_9.9.9_windows_amd64.zip "$arm" spanwit_9.9.9_windows_arm64.zip
printf 'other %s\n' "$(sed -n 2p "$TMP/good.pub")" >"$TMP/keys-none.txt"
SCOOP_MINISIGN_KEYS_FILE="$TMP/keys-none.txt" expect_refusal "no pinned key" "no single pinned minisign key"
printf 'spanwit %s\nspanwit %s\n' "$(sed -n 2p "$TMP/good.pub")" "$(sed -n 2p "$TMP/other.pub")" >"$TMP/keys-dup.txt"
SCOOP_MINISIGN_KEYS_FILE="$TMP/keys-dup.txt" expect_refusal "two pinned keys" "no single pinned minisign key"

run >/dev/null
[[ "$(jq -r .version "$TMP/repo/bucket/spanwit.json")" == "9.9.9" ]]
[[ "$(jq -r '.architecture["64bit"].hash' "$TMP/repo/bucket/spanwit.json")" == "$amd" ]]
[[ "$(jq -r '.architecture.arm64.hash' "$TMP/repo/bucket/spanwit.json")" == "$arm" ]]
[[ "$(jq -r '.architecture.arm64.url' "$TMP/repo/bucket/spanwit.json")" == *"/v9.9.9/spanwit_9.9.9_windows_arm64.zip" ]]

echo "update-manifest signed-checksum tests passed"
