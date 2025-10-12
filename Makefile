SHELL := /bin/bash

.PHONY: up down logs db-wait db/create db/drop db/migrate db/rollback db/status db/dump db/new db/reset db/redo migrate info psql rest gql contracts/export ci jwt/dev test/security db/test

DOCKER_COMPOSE_READY := $(shell if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then echo yes; else echo no; fi)
DEV_RUNTIME ?= $(if $(filter yes,$(DOCKER_COMPOSE_READY)),docker,local)

ifdef USE_DOCKER
ifeq ($(USE_DOCKER),yes)
DEV_RUNTIME := docker
else
DEV_RUNTIME := local
endif
endif

export DEV_RUNTIME

POSTGREST_PORT ?= 3000
POSTGRAPHILE_PORT ?= 3001
PGRST_JWT_SECRET ?= dev_jwt_secret_change_me_which_is_at_least_32_characters
POSTGREST_HOST ?= localhost
POSTGRAPHILE_HOST ?= localhost

DB_NAME ?= lims
DB_APP_USER ?= dev
DB_APP_PASSWORD ?= devpass
DB_SUPERUSER ?= postgres
DB_SUPERPASS ?= postgres
DB_HOST ?= 127.0.0.1
DB_PORT ?= 6432

ifeq ($(DEV_RUNTIME),docker)
DB_HOST_DISPLAY ?= localhost
DB_PORT_DISPLAY ?= 5432
PSQL_CMD ?= docker compose exec -it db psql -U dev -d lims
DB_WAIT_CMD ?= docker compose exec -T db pg_isready -U postgres -d postgres
PSQL_BATCH ?= docker compose exec -T db psql -U dev -d lims
else
DB_HOST_DISPLAY ?= $(DB_HOST)
DB_PORT_DISPLAY ?= $(DB_PORT)
PSQL_CMD ?= PGPASSWORD=$(DB_APP_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_APP_USER) -d $(DB_NAME)
PSQL_BATCH ?= PGPASSWORD=$(DB_APP_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_APP_USER) -d $(DB_NAME)
DB_WAIT_CMD ?= PGUSER=$(DB_SUPERUSER) PGPASSWORD=$(DB_SUPERPASS) pg_isready -h $(DB_HOST) -p $(DB_PORT) -d postgres
endif

DBMATE ?= ./ops/db/bin/dbmate
LOCAL_DEV_HELPER := ./scripts/local_dev.sh

ifeq ($(DEV_RUNTIME),docker)
DBMATE_ENV := DBMATE_MODE=docker
else
DBMATE_ENV := DBMATE_MODE=local LOCAL_DB_PORT=$(DB_PORT)
endif

CONTRACTS_DIR ?= contracts
POSTGREST_CONTRACT_DIR := $(CONTRACTS_DIR)/postgrest
POSTGRAPHILE_CONTRACT_DIR := $(CONTRACTS_DIR)/postgraphile
POSTGREST_OPENAPI := $(POSTGREST_CONTRACT_DIR)/openapi.json
POSTGRAPHILE_SCHEMA_JSON := $(POSTGRAPHILE_CONTRACT_DIR)/schema.json
INTROSPECTION_QUERY_FILE ?= ops/contracts/introspection.graphql
INTROSPECTION_PAYLOAD := $(POSTGRAPHILE_CONTRACT_DIR)/.introspection-request.json
POSTGREST_BASE_URL = http://$(POSTGREST_HOST):$(POSTGREST_PORT)
POSTGRAPHILE_GRAPHQL_URL = http://$(POSTGRAPHILE_HOST):$(POSTGRAPHILE_PORT)/graphql
JWT_DIR := ops/examples/jwts
JWT_DEV_SCRIPT := $(JWT_DIR)/make-dev-jwts.sh
RBAC_TEST_SCRIPT := scripts/test_rbac.sh
JWT_PUBLIC_DIR := ui/public/tokens

ifeq ($(PGHOST),db)
POSTGREST_HOST := postgrest
POSTGRAPHILE_HOST := postgraphile
DB_HOST_DISPLAY := db
endif

REST_URL := http://$(POSTGREST_HOST):$(POSTGREST_PORT)/samples
GRAPHILE_URL := http://$(POSTGRAPHILE_HOST):$(POSTGRAPHILE_PORT)/graphiql

ifeq ($(DEV_RUNTIME),docker)
up:
	docker compose up -d --build

down:
	docker compose down -v

logs:
	docker compose logs -f --tail=200
else
up:
	$(LOCAL_DEV_HELPER) start

down:
	$(LOCAL_DEV_HELPER) stop

logs:
	$(LOCAL_DEV_HELPER) logs
endif

db-wait:
	@bash -lc 'until $(DB_WAIT_CMD); do sleep 1; done'

db/create:
	$(DBMATE_ENV) $(DBMATE) create

db/drop:
	$(DBMATE_ENV) $(DBMATE) drop

db/migrate:
	$(DBMATE_ENV) $(DBMATE) migrate

db/rollback:
	$(DBMATE_ENV) $(DBMATE) rollback

db/status:
	$(DBMATE_ENV) $(DBMATE) status

db/dump:
	$(DBMATE_ENV) $(DBMATE) dump

db/new:
	@test -n "$(name)" || (echo "usage: make db/new name=add_table" >&2; exit 1)
	$(DBMATE_ENV) $(DBMATE) new "$(name)"

db/reset: db/drop db/create db/migrate

db/redo:
	$(DBMATE_ENV) $(DBMATE) rollback
	$(DBMATE_ENV) $(DBMATE) migrate

migrate: db/migrate

info:
	@echo "Postgres:    $(DB_HOST_DISPLAY):$(DB_PORT_DISPLAY)  db=$(DB_NAME)  user=$(DB_APP_USER)  pass=$(DB_APP_PASSWORD)"
	@echo "PostgREST:   $(REST_URL)"
	@echo "PostGraphile:$(GRAPHILE_URL)"

psql:
	$(PSQL_CMD)

ifeq ($(DEV_RUNTIME),docker)
contracts/export:
	docker compose up -d db postgrest postgraphile
	mkdir -p $(POSTGREST_CONTRACT_DIR) $(POSTGRAPHILE_CONTRACT_DIR)
	curl -sS --retry 12 --retry-delay 1 --retry-all-errors -H "Accept: application/openapi+json" $(POSTGREST_BASE_URL)/ | jq . > $(POSTGREST_OPENAPI)
	jq -n --rawfile query $(INTROSPECTION_QUERY_FILE) '{"query": $$query}' > $(INTROSPECTION_PAYLOAD)
	curl -sS --retry 12 --retry-delay 1 --retry-all-errors -H "Content-Type: application/json" --data-binary @$(INTROSPECTION_PAYLOAD) $(POSTGRAPHILE_GRAPHQL_URL) | jq . > $(POSTGRAPHILE_SCHEMA_JSON)
	rm -f $(INTROSPECTION_PAYLOAD)
	@echo "Contracts exported to $(CONTRACTS_DIR)"
else
contracts/export:
	$(LOCAL_DEV_HELPER) start >/dev/null 2>&1
	mkdir -p $(POSTGREST_CONTRACT_DIR) $(POSTGRAPHILE_CONTRACT_DIR)
	curl -sS --retry 12 --retry-delay 1 --retry-all-errors -H "Accept: application/openapi+json" $(POSTGREST_BASE_URL)/ | jq . > $(POSTGREST_OPENAPI)
	jq -n --rawfile query $(INTROSPECTION_QUERY_FILE) '{"query": $$query}' > $(INTROSPECTION_PAYLOAD)
	curl -sS --retry 12 --retry-delay 1 --retry-all-errors -H "Content-Type: application/json" --data-binary @$(INTROSPECTION_PAYLOAD) $(POSTGRAPHILE_GRAPHQL_URL) | jq . > $(POSTGRAPHILE_SCHEMA_JSON)
	rm -f $(INTROSPECTION_PAYLOAD)
	@echo "Contracts exported to $(CONTRACTS_DIR)"
endif

ifeq ($(DEV_RUNTIME),docker)
ci:
	docker compose stop postgrest postgraphile >/dev/null 2>&1 || true
	$(MAKE) db/reset
	$(MAKE) db/test
	$(MAKE) contracts/export
	$(MAKE) test/security
else
ci:
	$(LOCAL_DEV_HELPER) reset >/dev/null 2>&1
	$(LOCAL_DEV_HELPER) start >/dev/null 2>&1
	$(MAKE) db/reset
	$(MAKE) db/test
	$(MAKE) contracts/export
	$(MAKE) test/security
endif

jwt/dev:
	PGRST_JWT_SECRET="$(PGRST_JWT_SECRET)" $(JWT_DEV_SCRIPT)
	@if [ -d "$(JWT_PUBLIC_DIR)" ]; then \
		mkdir -p $(JWT_PUBLIC_DIR); \
		cp $(JWT_DIR)/*.jwt $(JWT_PUBLIC_DIR)/; \
		echo "Copied JWT fixtures into $(JWT_PUBLIC_DIR)"; \
	fi

ui/dev:
	docker compose up ui

ifeq ($(DEV_RUNTIME),docker)
test/security:
	docker compose up -d db postgrest postgraphile >/dev/null
	$(MAKE) db-wait >/dev/null
	$(MAKE) jwt/dev >/dev/null
	POSTGREST_URL=$(POSTGREST_BASE_URL) POSTGRAPHILE_URL=$(POSTGRAPHILE_GRAPHQL_URL) $(RBAC_TEST_SCRIPT)
else
test/security:
	$(LOCAL_DEV_HELPER) start >/dev/null 2>&1
	$(MAKE) db-wait >/dev/null
	$(MAKE) jwt/dev >/dev/null
	POSTGREST_URL=$(POSTGREST_BASE_URL) \
	POSTGRAPHILE_URL=$(POSTGRAPHILE_GRAPHQL_URL) \
	DB_HOST=$(DB_HOST) DB_PORT=$(DB_PORT) \
	DB_APP_USER=$(DB_APP_USER) DB_APP_PASSWORD=$(DB_APP_PASSWORD) DB_NAME=$(DB_NAME) \
	$(RBAC_TEST_SCRIPT)
endif

db/test:
	cat ops/db/tests/security.sql | $(PSQL_BATCH)

rest:
	@echo "GET /samples via PostgREST";
	curl -s $(REST_URL) | jq .

gql:
	@echo "Open GraphiQL at $(GRAPHILE_URL)"
