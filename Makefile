SHELL := /usr/bin/env bash

OWNER ?= 3leaps
APP ?= sfetch
VERSION ?=
SOURCE ?= --github

.PHONY: update update-sfetch release

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
