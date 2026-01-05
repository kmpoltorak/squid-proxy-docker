SHELL := /bin/bash
.PHONY: build up down test

build:
	docker-compose build --quiet

up:
	docker-compose up -d --build

down:
	docker-compose down --remove-orphans

test: up
	@echo "Running proxy functional test..."
	./scripts/test-proxy.sh
	$(MAKE) down
	@echo "Test finished"
