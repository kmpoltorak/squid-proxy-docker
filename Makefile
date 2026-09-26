SHELL := /bin/bash
COMPOSE := docker compose
TEST_PORT ?= 3128
.DEFAULT_GOAL := help
.PHONY: help build up down restart reload rotate logs test lint

help: ## Show available targets
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

build: ## Build the image
	$(COMPOSE) build

up: ## Build and start the proxy, wait until healthy
	$(COMPOSE) up -d --build --wait

down: ## Stop and remove containers
	$(COMPOSE) down --remove-orphans

restart: down up ## Recreate the container

reload: ## Re-read squid.conf without restarting
	$(COMPOSE) exec squid squid -k parse
	$(COMPOSE) exec squid squid -k reconfigure

rotate: ## Rotate log files now (also done daily by the container)
	$(COMPOSE) exec squid squid -k rotate

logs: ## Follow container logs
	$(COMPOSE) logs -f squid

# Settings in .env are overridden so both phases use a known port and auth mode.
# Cleanup (with logs on failure) runs on any exit, including a failed start or Ctrl-C.
test: ## Start, run functional tests without and with auth, tear down
	@set -e; \
	export SQUID_PORT=$(TEST_PORT) PROXY_URL=http://localhost:$(TEST_PORT); \
	trap 'rc=$$?; [ $$rc -eq 0 ] || $(COMPOSE) logs squid; $(COMPOSE) down --remove-orphans; exit $$rc' EXIT; \
	trap 'exit 130' INT TERM; \
	SQUID_USER= SQUID_PASSWORD= $(COMPOSE) up -d --build --wait --wait-timeout 120; \
	PROXY_USER= PROXY_PASSWORD= ./scripts/test-proxy.sh; \
	SQUID_USER=test SQUID_PASSWORD=test $(COMPOSE) up -d --wait --wait-timeout 120; \
	PROXY_USER=test PROXY_PASSWORD=test ./scripts/test-proxy.sh

lint: ## Run hadolint and shellcheck (via Docker)
	docker run --rm -i hadolint/hadolint:v2.12.0 < squid/Dockerfile
	docker run --rm -v "$(CURDIR):/mnt:ro" -w /mnt koalaman/shellcheck:v0.10.0 squid/entrypoint.sh scripts/*.sh
