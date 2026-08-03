# FocusQuest database migrations (golang-migrate)

MIGRATE_VERSION ?= v4.18.1
MIGRATE_BIN ?= migrate
MIGRATIONS_DIR := $(CURDIR)/migrations
DOCKER_IMAGE := postgres:16-alpine
CONTAINER_NAME := focusquest-db-test
POSTGRES_USER := focusquest
POSTGRES_PASSWORD := focusquest
POSTGRES_DB := focusquest
POSTGRES_PORT ?= 54329
DATABASE_URL := postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@localhost:$(POSTGRES_PORT)/$(POSTGRES_DB)?sslmode=disable

.PHONY: help install-migrate postgres-up postgres-down postgres-wait migrate-up migrate-down migrate-force test schema-test clean

help:
	@echo "FocusQuest database migration targets:"
	@echo "  make install-migrate  Install golang-migrate CLI locally"
	@echo "  make postgres-up      Start Docker Postgres for local testing"
	@echo "  make postgres-down    Stop Docker Postgres"
	@echo "  make migrate-up       Apply all migrations"
	@echo "  make migrate-down     Roll back the latest migration"
	@echo "  make test             Run schema integration tests (requires Docker)"
	@echo "  make schema-test      Alias for test"

install-migrate:
	@command -v $(MIGRATE_BIN) >/dev/null 2>&1 || \
		go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@$(MIGRATE_VERSION)

postgres-up:
	@docker rm -f $(CONTAINER_NAME) >/dev/null 2>&1 || true
	docker run -d \
		--name $(CONTAINER_NAME) \
		-e POSTGRES_USER=$(POSTGRES_USER) \
		-e POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) \
		-e POSTGRES_DB=$(POSTGRES_DB) \
		-p $(POSTGRES_PORT):5432 \
		$(DOCKER_IMAGE)
	@$(MAKE) postgres-wait

postgres-wait:
	@echo "Waiting for Postgres on port $(POSTGRES_PORT)..."
	@for i in $$(seq 1 30); do \
		if docker exec $(CONTAINER_NAME) pg_isready -U $(POSTGRES_USER) -d $(POSTGRES_DB) >/dev/null 2>&1; then \
			echo "Postgres is ready"; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Postgres failed to become ready"; \
	exit 1

postgres-down:
	@docker rm -f $(CONTAINER_NAME) >/dev/null 2>&1 || true

migrate-up:
	@if command -v $(MIGRATE_BIN) >/dev/null 2>&1; then \
		$(MIGRATE_BIN) -path $(MIGRATIONS_DIR) -database "$(DATABASE_URL)" up; \
	elif command -v go >/dev/null 2>&1; then \
		$(MAKE) install-migrate; \
		$(MIGRATE_BIN) -path $(MIGRATIONS_DIR) -database "$(DATABASE_URL)" up; \
	else \
		docker run --rm -v $(MIGRATIONS_DIR):/migrations migrate/migrate:$(MIGRATE_VERSION) \
			-path=/migrations -database "postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@host.docker.internal:$(POSTGRES_PORT)/$(POSTGRES_DB)?sslmode=disable" up; \
	fi

migrate-down:
	@if command -v $(MIGRATE_BIN) >/dev/null 2>&1; then \
		$(MIGRATE_BIN) -path $(MIGRATIONS_DIR) -database "$(DATABASE_URL)" down 1; \
	elif command -v go >/dev/null 2>&1; then \
		$(MAKE) install-migrate; \
		$(MIGRATE_BIN) -path $(MIGRATIONS_DIR) -database "$(DATABASE_URL)" down 1; \
	else \
		docker run --rm -v $(MIGRATIONS_DIR):/migrations migrate/migrate:$(MIGRATE_VERSION) \
			-path=/migrations -database "postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@host.docker.internal:$(POSTGRES_PORT)/$(POSTGRES_DB)?sslmode=disable" down 1; \
	fi

migrate-force: install-migrate
	@if [ -z "$(VERSION)" ]; then echo "Set VERSION=<number> for migrate-force"; exit 1; fi
	$(MIGRATE_BIN) -path $(MIGRATIONS_DIR) -database "$(DATABASE_URL)" force $(VERSION)

test schema-test:
	bash tests/schema_test.sh

clean: postgres-down
