SHELL := /usr/bin/env bash

OWNER ?= 3leaps
APP ?= sfetch
VERSION ?=
SOURCE ?= --github

.PHONY: check update update-gonimbus update-mdmeld update-sfetch update-seclusor release

check:
	@./scripts/validate-manifests.sh
	@shellcheck scripts/*.sh
	@shfmt -d scripts/*.sh
	@echo "All checks passed"

update:
	@if [[ -z "$(VERSION)" ]]; then \
		echo "ERROR: VERSION is required"; \
		echo "Usage: make update APP=sfetch VERSION=0.4.5 [SOURCE=--github|--local]"; \
		exit 1; \
	fi
	@./scripts/update-manifest.sh "$(OWNER)" "$(APP)" "$(VERSION)" "$(SOURCE)"

update-sfetch:
	@if [[ -z "$(VERSION)" ]]; then \
		echo "ERROR: VERSION is required"; \
		echo "Usage: make update-sfetch VERSION=0.4.5 [SOURCE=--github|--local]"; \
		exit 1; \
	fi
	@./scripts/update-manifest.sh "$(OWNER)" sfetch "$(VERSION)" "$(SOURCE)"

update-gonimbus:
	@if [[ -z "$(VERSION)" ]]; then \
		echo "ERROR: VERSION is required"; \
		echo "Usage: make update-gonimbus VERSION=0.3.2 [SOURCE=--github|--local]"; \
		exit 1; \
	fi
	@./scripts/update-manifest.sh "$(OWNER)" gonimbus "$(VERSION)" "$(SOURCE)"

update-mdmeld:
	@if [[ -z "$(VERSION)" ]]; then \
		echo "ERROR: VERSION is required"; \
		echo "Usage: make update-mdmeld VERSION=0.2.0 [SOURCE=--github|--local]"; \
		exit 1; \
	fi
	@./scripts/update-manifest.sh "$(OWNER)" mdmeld "$(VERSION)" "$(SOURCE)"

update-seclusor:
	@if [[ -z "$(VERSION)" ]]; then \
		echo "ERROR: VERSION is required"; \
		echo "Usage: make update-seclusor VERSION=0.1.3 [SOURCE=--github|--local]"; \
		exit 1; \
	fi
	@./scripts/update-manifest.sh "$(OWNER)" seclusor "$(VERSION)" "$(SOURCE)"

release:
	@if [[ -z "$(VERSION)" ]]; then \
		echo "ERROR: VERSION is required"; \
		echo "Usage: make release APP=sfetch VERSION=0.4.5 [SOURCE=--github|--local]"; \
		exit 1; \
	fi
	@$(MAKE) update APP="$(APP)" VERSION="$(VERSION)" SOURCE="$(SOURCE)"
	@git add "bucket/$(APP).json"
	@git commit -m "chore(bucket): update $(APP) to v$(VERSION)"
	@git push origin main
