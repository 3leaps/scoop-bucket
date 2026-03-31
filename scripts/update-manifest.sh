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

hashes = {}
for line in sums_path.read_text().splitlines():
    parts = line.split()
    if len(parts) >= 2:
        hashes[parts[1]] = parts[0]

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
