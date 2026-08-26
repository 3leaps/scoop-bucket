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
```

## Available tools

| Tool | Description |
| --- | --- |
| [decernor](https://github.com/3leaps/decernor) | Local key-material hygiene and readiness checks |
| [sfetch](https://github.com/3leaps/sfetch) | Secure, verifiable, zero-trust downloader for the uncertain world |
| [gonimbus](https://github.com/3leaps/gonimbus) | Cloud object storage crawl, inspect, and streaming CLI |
| [mdmeld](https://github.com/3leaps/mdmeld) | Pack directory trees into markdown archives for AI sharing |
| [seclusor](https://github.com/3leaps/seclusor) | Git-trackable secrets management with age encryption |

## Update

```powershell
scoop update decernor
scoop update sfetch
scoop update gonimbus
scoop update mdmeld
scoop update seclusor
```

## Maintainers

Manifests live in `bucket/`. Update one from a published GitHub release and validate before committing:

```bash
make update-seclusor VERSION=0.1.6   # or: make update APP=<tool> VERSION=<x.y.z>
make check                           # validate manifests + shellcheck/shfmt scripts
```

`make check` runs in CI (`.github/workflows/ci.yml`) on every push and pull request; `scripts/validate-manifests.sh` asserts each manifest is well-formed JSON with required fields, sha256-shaped hashes, and version-matching download URLs.

## License

Apache-2.0
