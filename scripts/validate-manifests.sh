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

	errors="$(jq -r --arg fname "$name" '
		def is_raw_manifest:
			($fname == "gonimbus.json") or ($fname | test("^gonimbus-[0-9]+\\.[0-9]+\\.json$"))
			or ([(.architecture // {}) | to_entries[] | (.value.url // "") | endswith(".exe")] | any);
		[
			(if (.version // "") == "" then "missing version" else empty end),
			(if (.description // "") == "" then "missing description" else empty end),
			(if (.homepage // "") == "" then "missing homepage" else empty end),
			(if (.license // "") == "" then "missing license" else empty end),
			(if ((.architecture // {}) | length) == 0 then "missing architecture" else empty end),
			(if is_raw_manifest then
				(if has("extract_dir") then "raw-binary manifest must not set extract_dir" else empty end),
				(["pre_install","post_install","installer","uninstaller","pre_uninstall","post_uninstall","psmodule","env_add_path","env_set","shortcuts"][] as $k |
					if has($k) then "raw-binary manifest must not set \($k)" else empty end
				),
				(keys[] as $k |
					if (["version","description","homepage","license","architecture","checkver","autoupdate"] | index($k)) == null then
						"raw-binary manifest contains disallowed top-level key: \($k)"
					else empty end
				)
			else empty end),
			(.version as $v | is_raw_manifest as $raw | (.architecture // {}) | to_entries[] |
				(if (.value.url // "") == "" then "architecture \(.key): missing url" else empty end),
				(if ((.value.hash // "") | test("^[a-fA-F0-9]{64}$") | not) then "architecture \(.key): hash is not a sha256" else empty end),
				(if (.value.url // "") != "" and ((.value.url | contains($v)) | not) then "architecture \(.key): url does not contain version \($v)" else empty end),
				(if $raw then
					(if ((.value.url // "") | test("^https://github\\.com/3leaps/[A-Za-z0-9._-]+/releases/download/v" + ($v | gsub("\\."; "\\.")) + "/[^/]+\\.exe$") | not) then
						"architecture \(.key): raw-binary url must reference https://github.com/3leaps/<repo>/releases/download/v\($v)/<asset>.exe"
					else empty end),
					(if (.value | has("extract_dir")) then
						"architecture \(.key): raw-binary manifest must not set extract_dir"
					else empty end),
					(.key as $arch | .value as $av | ["pre_install","post_install","installer","uninstaller","pre_uninstall","post_uninstall","psmodule","env_add_path","env_set","shortcuts"][] as $k |
						if ($av | has($k)) then
							"architecture \($arch): raw-binary manifest must not set \($k)"
						else empty end
					),
					(.key as $arch | (.value | keys[]) as $k |
						if (["url","hash","bin"] | index($k)) == null then
							"architecture \($arch): raw-binary manifest contains disallowed key: \($k)"
						else empty end
					),
					(((.value.url // "") | split("/") | last) as $asset |
						if ((.value.bin | type) != "array"
							or (.value.bin | length) != 1
							or (.value.bin[0] | type) != "array"
							or (.value.bin[0] | length) != 2
							or (.value.bin[0][0] != $asset)
							or ((.value.bin[0][1] | type) != "string")
							or (.value.bin[0][1] == "")) then
							"architecture \(.key): raw-binary bin must be [[\"\($asset)\", \"<cmd>\"]] with no extra shim args"
						else empty end
					)
				else empty end)
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
