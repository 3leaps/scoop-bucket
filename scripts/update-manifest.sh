#!/usr/bin/env bash
set -euo pipefail

usage() {
	echo "Usage: $0 <owner> <app-name> <version> [--github|--local]" >&2
	echo "Example: $0 3leaps sfetch 0.4.5" >&2
}

require_cmd() {
	local command_name="$1"
	if ! command -v "$command_name" >/dev/null 2>&1; then
		echo "ERROR: required command not found: $command_name" >&2
		exit 1
	fi
}

if [[ $# -lt 3 || $# -gt 4 ]]; then
	usage
	exit 1
fi

OWNER="$1"
APP_NAME="$2"
VERSION="${3#v}"
SOURCE="${4:---github}"

case "$SOURCE" in
--github | --local) ;;
*)
	echo "ERROR: invalid source '$SOURCE' (expected --github or --local)" >&2
	usage
	exit 1
	;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST_PATH="${REPO_ROOT}/bucket/${APP_NAME}.json"

if [[ ! -f "$MANIFEST_PATH" ]]; then
	echo "ERROR: manifest not found: $MANIFEST_PATH" >&2
	exit 1
fi

require_cmd python3
require_cmd minisign
if [[ "$SOURCE" == "--github" ]]; then
	require_cmd gh
fi

# Hashes come only from a SHA256SUMS whose minisign signature verifies against
# the key pinned for this app in keys/minisign-pubkeys.txt.
KEYS_FILE="${SCOOP_MINISIGN_KEYS_FILE:-${REPO_ROOT}/keys/minisign-pubkeys.txt}"
PINNED_KEY="$(awk -v app="$APP_NAME" 'NF == 2 && $1 == app { print $2; n++ } END { if (n != 1) exit 1 }' "$KEYS_FILE")" || {
	echo "ERROR: no single pinned minisign key for ${APP_NAME} in ${KEYS_FILE}" >&2
	exit 1
}

TEMP_DIR="$(mktemp -d -t "${APP_NAME}-sums.XXXXXX")"
TEMP_SUMS="${TEMP_DIR}/SHA256SUMS"
TEMP_MANIFEST="${TEMP_DIR}/manifest.json"
trap 'rm -rf "$TEMP_DIR"' EXIT

if [[ "$SOURCE" == "--local" ]]; then
	LOCAL_SUMS_PATH="${REPO_ROOT}/../${APP_NAME}/dist/release/SHA256SUMS"
	for f in "$LOCAL_SUMS_PATH" "${LOCAL_SUMS_PATH}.minisig"; do
		if [[ ! -f "$f" ]]; then
			echo "ERROR: local file not found: $f" >&2
			exit 1
		fi
	done
	cp "$LOCAL_SUMS_PATH" "$TEMP_SUMS"
	cp "${LOCAL_SUMS_PATH}.minisig" "${TEMP_SUMS}.minisig"
else
	gh release download "v${VERSION}" \
		--repo "${OWNER}/${APP_NAME}" \
		--pattern SHA256SUMS \
		--pattern SHA256SUMS.minisig \
		--dir "$TEMP_DIR"
	# GitHub's asset digests are a cross-check against the signed sums below.
	gh release view "v${VERSION}" \
		--repo "${OWNER}/${APP_NAME}" \
		--json assets \
		--jq '[.assets[] | {name, digest}]' >"${TEMP_DIR}/github-digests.json"
fi

if ! VERIFY_OUT="$(minisign -V -P "$PINNED_KEY" -m "$TEMP_SUMS" -x "${TEMP_SUMS}.minisig" 2>&1)"; then
	echo "ERROR: SHA256SUMS signature for ${APP_NAME} v${VERSION} does not verify against the pinned key" >&2
	exit 1
fi
# A trusted comment that names this app must name this version, so an older
# signed manifest cannot be replayed under a newer release.
COMMENT="$(sed -n 's/^Trusted comment: //p' <<<"$VERIFY_OUT")"
if [[ "$COMMENT" == "${APP_NAME} v"* ]]; then
	COMMENT_TAG="${COMMENT#"${APP_NAME} "}"
	COMMENT_TAG="${COMMENT_TAG%% *}"
	if [[ "$COMMENT_TAG" != "v${VERSION}" ]]; then
		echo "ERROR: SHA256SUMS for ${APP_NAME} is signed for ${COMMENT_TAG}, not v${VERSION}" >&2
		exit 1
	fi
fi

python3 - "$MANIFEST_PATH" "$TEMP_SUMS" "$TEMP_MANIFEST" "$OWNER" "$APP_NAME" "$VERSION" "${TEMP_DIR}/github-digests.json" <<'PY'
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sums_path = Path(sys.argv[2])
temp_manifest_path = Path(sys.argv[3])
owner = sys.argv[4]
app_name = sys.argv[5]
version = sys.argv[6]
digests_path = Path(sys.argv[7])
github_digests = {}
if digests_path.exists():
    for asset in json.loads(digests_path.read_text()):
        digest = (asset.get("digest") or "").removeprefix("sha256:")
        if digest:
            github_digests[asset["name"]] = digest

hashes = {}
for line in sums_path.read_text().splitlines():
    parts = line.split()
    if len(parts) >= 2:
        if len(parts[0]) != 64 or any(c not in "0123456789abcdef" for c in parts[0]):
            raise SystemExit("ERROR: malformed SHA256SUMS line")
        name = parts[1].lstrip("*")
        if name in hashes:
            raise SystemExit(f"ERROR: {name} is listed twice in SHA256SUMS")
        hashes[name] = parts[0]

manifest = json.loads(manifest_path.read_text())
manifest["version"] = version

architecture = manifest.get("architecture", {})
autoupdate_arches = manifest.get("autoupdate", {}).get("architecture", {})
updated = []

for arch, arch_manifest in architecture.items():
    template = autoupdate_arches.get(arch, {}).get("url")
    if not template:
        continue
    url = template.replace("$version", version)
    asset_name = url.rsplit("/", 1)[-1]
    if asset_name not in hashes:
        raise SystemExit(f"ERROR: could not find {asset_name} hash in SHA256SUMS")
    if asset_name in github_digests and github_digests[asset_name] != hashes[asset_name]:
        raise SystemExit(f"ERROR: GitHub digest for {asset_name} differs from the signed SHA256SUMS")
    arch_manifest["url"] = url
    arch_manifest["hash"] = hashes[asset_name]
    updated.append((arch, asset_name, hashes[asset_name]))

temp_manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Updated {manifest_path}")
print(f"  version: {version}")
for arch, asset_name, asset_hash in updated:
    print(f"  {arch}: {asset_name} {asset_hash}")
PY

mv "$TEMP_MANIFEST" "$MANIFEST_PATH"
