#!/usr/bin/env bash
set -euo pipefail

# Validate every Scoop manifest in bucket/: well-formed JSON, required fields,
# sha256-shaped hashes, and download URLs that match the manifest version.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

fail=0
for manifest in "${REPO_ROOT}"/bucket/*.json; do
	name="$(basename "$manifest")"

	if ! jq empty "$manifest" 2>/dev/null; then
		echo "FAIL ${name}: invalid JSON"
		fail=1
		continue
	fi

	errors="$(jq -r '
		[
			(if (.version // "") == "" then "missing version" else empty end),
			(if (.description // "") == "" then "missing description" else empty end),
			(if (.homepage // "") == "" then "missing homepage" else empty end),
			(if (.license // "") == "" then "missing license" else empty end),
			(if ((.architecture // {}) | length) == 0 then "missing architecture" else empty end),
			(.version as $v | (.architecture // {}) | to_entries[] |
				(if (.value.url // "") == "" then "architecture \(.key): missing url" else empty end),
				(if ((.value.hash // "") | test("^[a-fA-F0-9]{64}$") | not) then "architecture \(.key): hash is not a sha256" else empty end),
				(if (.value.url // "") != "" and ((.value.url | contains($v)) | not) then "architecture \(.key): url does not contain version \($v)" else empty end)
			)
		] | .[]
	' "$manifest")"

	if [[ -n "$errors" ]]; then
		while IFS= read -r e; do echo "FAIL ${name}: ${e}"; done <<<"$errors"
		fail=1
	else
		echo "OK   ${name}"
	fi
done

if [[ "$fail" -ne 0 ]]; then
	echo "Manifest validation failed."
	exit 1
fi
echo "All manifests valid."
