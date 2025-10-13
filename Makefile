SHELL := /bin/bash

.PHONY: up down logs db-wait db/create db/drop db/migrate db/rollback db/status db/dump db/new db/reset db/redo migrate info psql rest gql contracts/export ci jwt/dev test/security db/test

# Runtime detection ---------------------------------------------------------
# Determine whether developer tooling should talk to Docker Compose services
# or to locally managed daemons. Developers can force the mode by exporting
# DEV_RUNTIME=docker|local (or the legacy USE_DOCKER=yes|no).
DOCKER_COMPOSE_AVAILABLE := $(shell if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then echo yes; else echo no; fi)
DEV_RUNTIME ?= auto

ifeq ($(DEV_RUNTIME),auto)
  ifeq ($(DOCKER_COMPOSE_AVAILABLE),yes)
    DEV_RUNTIME := docker
  else
    DEV_RUNTIME := local
  endif
endif

ifdef USE_DOCKER
  ifeq ($(USE_DOCKER),yes)
    DEV_RUNTIME := docker
  else ifeq ($(USE_DOCKER),no)
    DEV_RUNTIME := local
  endif
endif

export DEV_RUNTIME

# Shared configuration ------------------------------------------------------
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

LOCAL_DEV_HELPER := ./scripts/local_dev.sh
LOCAL_DEV_ENV := PGHOST=$(DB_HOST) PG_PORT=$(DB_PORT) PG_SUPERUSER=$(DB_SUPERUSER) PG_SUPERPASS=$(DB_SUPERPASS) \
  POSTGREST_PORT=$(POSTGREST_PORT) POSTGRAPHILE_PORT=$(POSTGRAPHILE_PORT) PGRST_JWT_SECRET=$(PGRST_JWT_SECRET)

export LOCAL_DB_PORT := $(DB_PORT)

# Runtime specific overrides ------------------------------------------------
ifeq ($(DEV_RUNTIME),docker)
  DB_HOST_DISPLAY := localhost
  DB_PORT_DISPLAY := 5432
  PSQL_CMD := docker compose exec -it db psql -U $(DB_APP_USER) -d $(DB_NAME)
  PSQL_BATCH := docker compose exec -T db psql -U $(DB_APP_USER) -d $(DB_NAME)
  DB_WAIT_CMD := docker compose exec -T db pg_isready -U $(DB_SUPERUSER) -d postgres
  UP_CMD := docker compose up -d --build
  DOWN_CMD := docker compose down -v
  LOGS_CMD := docker compose logs -f --tail=200
  CONTRACTS_BOOT := docker compose up -d db postgrest postgraphile
  TEST_BOOT := docker compose up -d db postgrest postgraphile >/dev/null
else
  DB_HOST_DISPLAY := $(DB_HOST)
  DB_PORT_DISPLAY := $(DB_PORT)
  PSQL_CMD := PGPASSWORD=$(DB_APP_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_APP_USER) -d $(DB_NAME)
  PSQL_BATCH := PGPASSWORD=$(DB_APP_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_APP_USER) -d $(DB_NAME)
  DB_WAIT_CMD := PGUSER=$(DB_SUPERUSER) PGPASSWORD=$(DB_SUPERPASS) pg_isready -h $(DB_HOST) -p $(DB_PORT) -d postgres
  UP_CMD := $(LOCAL_DEV_ENV) $(LOCAL_DEV_HELPER) start
  DOWN_CMD := $(LOCAL_DEV_ENV) $(LOCAL_DEV_HELPER) stop
  LOGS_CMD := $(LOCAL_DEV_ENV) $(LOCAL_DEV_HELPER) logs
  CONTRACTS_BOOT := $(LOCAL_DEV_ENV) $(LOCAL_DEV_HELPER) start >/dev/null 2>&1
  TEST_BOOT := $(LOCAL_DEV_ENV) $(LOCAL_DEV_HELPER) start >/dev/null 2>&1
endif

DBMATE ?= ./ops/db/bin/dbmate

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

REST_URL := $(POSTGREST_BASE_URL)/samples
GRAPHILE_URL := http://$(POSTGRAPHILE_HOST):$(POSTGRAPHILE_PORT)/graphiql

# Targets -------------------------------------------------------------------
up:
	$(UP_CMD)

down:
	$(DOWN_CMD)

logs:
	$(LOGS_CMD)

db-wait:
	@bash -lc 'until $(DB_WAIT_CMD); do sleep 1; done'

db/create:
	$(DBMATE) create

db/drop:
	$(DBMATE) drop

db/migrate:
	$(DBMATE) migrate

db/rollback:
	$(DBMATE) rollback

db/status:
	$(DBMATE) status

db/dump:
	$(DBMATE) dump

db/new:
	@test -n "$(name)" || (echo "usage: make db/new name=add_table" >&2; exit 1)
	$(DBMATE) new "$(name)"

db/reset: db/drop db/create db/migrate

db/redo:
	$(DBMATE) rollback
	$(DBMATE) migrate

migrate: db/migrate

info:
	@echo "Runtime:    $(DEV_RUNTIME)"
	@echo "Postgres:   $(DB_HOST_DISPLAY):$(DB_PORT_DISPLAY)  db=$(DB_NAME)  user=$(DB_APP_USER)  pass=$(DB_APP_PASSWORD)"
	@echo "PostgREST:  $(REST_URL)"
	@echo "PostGraphile: $(GRAPHILE_URL)"

psql:
	$(PSQL_CMD)

contracts/export:
	$(CONTRACTS_BOOT)
	mkdir -p $(POSTGREST_CONTRACT_DIR) $(POSTGRAPHILE_CONTRACT_DIR)
	curl -sS --retry 12 --retry-delay 1 --retry-all-errors -H "Accept: application/openapi+json" $(POSTGREST_BASE_URL)/ | jq . > $(POSTGREST_OPENAPI)
	jq -n --rawfile query $(INTROSPECTION_QUERY_FILE) '{"query": $$query}' > $(INTROSPECTION_PAYLOAD)
	curl -sS --retry 12 --retry-delay 1 --retry-all-errors -H "Content-Type: application/json" --data-binary @$(INTROSPECTION_PAYLOAD) $(POSTGRAPHILE_GRAPHQL_URL) | jq . > $(POSTGRAPHILE_SCHEMA_JSON)
	rm -f $(INTROSPECTION_PAYLOAD)
	@echo "Contracts exported to $(CONTRACTS_DIR)"

ifeq ($(DEV_RUNTIME),docker)
ci:
	docker compose stop postgrest postgraphile >/dev/null 2>&1 || true
	$(MAKE) db/reset
	$(MAKE) db/test
	$(MAKE) contracts/export
	$(MAKE) test/security
else
ci:
	$(LOCAL_DEV_ENV) $(LOCAL_DEV_HELPER) reset >/dev/null 2>&1
	$(LOCAL_DEV_ENV) $(LOCAL_DEV_HELPER) start >/dev/null 2>&1
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

test/security:
	$(TEST_BOOT)
	$(MAKE) db-wait >/dev/null
	$(MAKE) jwt/dev >/dev/null
	POSTGREST_URL=$(POSTGREST_BASE_URL) \
	POSTGRAPHILE_URL=$(POSTGRAPHILE_GRAPHQL_URL) \
	DB_HOST=$(DB_HOST_DISPLAY) DB_PORT=$(DB_PORT_DISPLAY) \
	DEV_RUNTIME=$(DEV_RUNTIME) \
	$(RBAC_TEST_SCRIPT)

db/test:
	cat ops/db/tests/security.sql | $(PSQL_BATCH)

rest:
	@echo "GET /samples via PostgREST";
	curl -s $(REST_URL) | jq .

gql:
	@echo "Open GraphiQL at $(GRAPHILE_URL)"
