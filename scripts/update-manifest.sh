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
if [[ "$SOURCE" == "--github" ]]; then
	require_cmd gh
fi

TEMP_SUMS="$(mktemp -t "${APP_NAME}-sha256.XXXXXX")"
TEMP_MANIFEST="$(mktemp -t "${APP_NAME}-manifest.XXXXXX")"
trap 'rm -f "$TEMP_SUMS" "$TEMP_MANIFEST"' EXIT

if [[ "$SOURCE" == "--local" ]]; then
	LOCAL_SUMS_PATH="${REPO_ROOT}/../${APP_NAME}/dist/release/SHA256SUMS"
	if [[ ! -f "$LOCAL_SUMS_PATH" ]]; then
		echo "ERROR: local SHA256SUMS not found: $LOCAL_SUMS_PATH" >&2
		exit 1
	fi
	cp "$LOCAL_SUMS_PATH" "$TEMP_SUMS"
else
	gh release download "v${VERSION}" \
		--repo "${OWNER}/${APP_NAME}" \
		--pattern SHA256SUMS \
		--output "$TEMP_SUMS" \
		--clobber
fi

python3 - "$MANIFEST_PATH" "$TEMP_SUMS" "$TEMP_MANIFEST" "$OWNER" "$APP_NAME" "$VERSION" <<'PY'
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sums_path = Path(sys.argv[2])
temp_manifest_path = Path(sys.argv[3])
owner = sys.argv[4]
app_name = sys.argv[5]
version = sys.argv[6]

asset_map = {
    "64bit": f"{app_name}_windows_amd64.zip",
    "arm64": f"{app_name}_windows_arm64.zip",
}

hashes = {}
for line in sums_path.read_text().splitlines():
    parts = line.split()
    if len(parts) >= 2:
        hashes[parts[1]] = parts[0]

manifest = json.loads(manifest_path.read_text())
manifest["version"] = version

architecture = manifest.get("architecture", {})
for scoop_arch, asset_name in asset_map.items():
    if scoop_arch not in architecture:
        continue
    if asset_name not in hashes:
        raise SystemExit(f"ERROR: could not find {asset_name} hash in SHA256SUMS")
    architecture[scoop_arch]["url"] = (
        f"https://github.com/{owner}/{app_name}/releases/download/v{version}/{asset_name}"
    )
    architecture[scoop_arch]["hash"] = hashes[asset_name]

temp_manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Updated {manifest_path}")
print(f"  version: {version}")
for scoop_arch, asset_name in asset_map.items():
    if scoop_arch in architecture:
        print(f"  {scoop_arch}: {hashes[asset_name]}")
PY

mv "$TEMP_MANIFEST" "$MANIFEST_PATH"
