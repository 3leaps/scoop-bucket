# 3leaps/scoop-bucket

[![checks](https://github.com/3leaps/scoop-bucket/actions/workflows/ci.yml/badge.svg)](https://github.com/3leaps/scoop-bucket/actions/workflows/ci.yml)

Scoop bucket for 3leaps CLI tools.

## Usage

```powershell
scoop bucket add 3leaps https://github.com/3leaps/scoop-bucket
scoop install decernor
scoop install sfetch
scoop install gonimbus
scoop install mdmeld
scoop install seclusor
scoop install spanwit
```

## Available tools

| Tool | Description |
| --- | --- |
| [decernor](https://github.com/3leaps/decernor) | Local key-material hygiene and readiness checks |
| [sfetch](https://github.com/3leaps/sfetch) | Secure, verifiable, zero-trust downloader for the uncertain world |
| [gonimbus](https://github.com/3leaps/gonimbus) | Cloud object storage crawl, inspect, and streaming CLI |
| [mdmeld](https://github.com/3leaps/mdmeld) | Pack directory trees into markdown archives for AI sharing |
| [seclusor](https://github.com/3leaps/seclusor) | Git-trackable secrets management with age encryption |
| [spanwit](https://github.com/3leaps/spanwit) | Context-aware disk-space diagnostics and safe reclamation |

## Update

```powershell
scoop update decernor
scoop update sfetch
scoop update gonimbus
scoop update mdmeld
scoop update seclusor
scoop update spanwit
```

## Maintainers

Manifests live in `bucket/`. Update one from a published GitHub release and validate before committing:

```bash
make update-seclusor VERSION=0.1.6   # or: make update APP=<tool> VERSION=<x.y.z>
make update-spanwit VERSION=0.2.1
make check                           # validate manifests, lint scripts, run updater tests
```

The updater takes hashes only from the release `SHA256SUMS` after verifying `SHA256SUMS.minisig` with `minisign` against the key pinned for the app in `keys/minisign-pubkeys.txt`, and refuses a name listed twice. When the trusted comment starts with `<app> v`, it must name the requested version; a comment in another form (such as minisign's default timestamp) is not checked for the version. GitHub's asset digest is a cross-check: a disagreement stops the update, and an asset with no GitHub digest (or a `--local` run) is not cross-checked. `minisign` must be installed. A key change is a reviewed edit to `keys/minisign-pubkeys.txt`, never something read from a release.

`make check` runs in CI (`.github/workflows/ci.yml`) on every push and pull request; `scripts/validate-manifests.sh` asserts each manifest is well-formed JSON with required fields, sha256-shaped hashes, and version-matching download URLs, and `tests/update-manifest_test.sh` covers the signature checks with throwaway keys.

## License

Apache-2.0
