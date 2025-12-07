SHELL := /bin/bash

.PHONY: up down logs db-wait db/create db/drop db/migrate db/rollback db/status db/dump db/new db/reset db/redo migrate info psql rest gql contracts/export ci jwt/dev test/security test/rest-story test/ui db/test jupyterlite/vendor ui/ready

DOCKER_COMPOSE_AVAILABLE := $(shell if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then echo yes; else echo no; fi)
USE_DOCKER ?= $(DOCKER_COMPOSE_AVAILABLE)

POSTGREST_INTERNAL_PORT ?= 3000
POSTGRAPHILE_INTERNAL_PORT ?= 3001
POSTGREST_HOST_PORT ?= 7100
POSTGRAPHILE_HOST_PORT ?= 7101
POSTGREST_PORT ?= $(POSTGREST_HOST_PORT)
POSTGRAPHILE_PORT ?= $(POSTGRAPHILE_HOST_PORT)
PGRST_JWT_SECRET ?= dev_jwt_secret_change_me_which_is_at_least_32_characters

ifeq ($(USE_DOCKER),yes)
POSTGREST_HOST ?= localhost
POSTGRAPHILE_HOST ?= localhost
DB_HOST_DISPLAY ?= localhost
DB_PORT_DISPLAY ?= 5432
DB_NAME ?= lims
DB_APP_USER ?= dev
DB_APP_PASSWORD ?= devpass
PSQL_CMD ?= docker compose exec -it db psql -U dev -d lims
DB_WAIT_CMD ?= docker compose exec -T db pg_isready -U postgres -d postgres
PSQL_BATCH ?= docker compose exec -T db psql -U dev -d lims
PSQL_SUPER_CMD ?= docker compose exec -T db psql -U postgres -d postgres
LOCAL_DEV ?= no
else
LOCAL_DEV ?= yes
POSTGREST_HOST ?= localhost
POSTGRAPHILE_HOST ?= localhost
DB_HOST ?= 127.0.0.1
DB_PORT ?= 6432
DB_HOST_DISPLAY ?= $(DB_HOST)
DB_PORT_DISPLAY ?= $(DB_PORT)
DB_SUPERUSER ?= postgres
DB_SUPERPASS ?= postgres
DB_APP_USER ?= dev
DB_APP_PASSWORD ?= devpass
DB_NAME ?= lims
PSQL_CMD ?= PGPASSWORD=$(DB_APP_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_APP_USER) -d $(DB_NAME)
PSQL_BATCH ?= PGPASSWORD=$(DB_APP_PASSWORD) psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_APP_USER) -d $(DB_NAME)
DB_WAIT_CMD ?= PGUSER=$(DB_SUPERUSER) PGPASSWORD=$(DB_SUPERPASS) pg_isready -h $(DB_HOST) -p $(DB_PORT) -d postgres
PSQL_SUPER_CMD ?= PGUSER=$(DB_SUPERUSER) PGPASSWORD=$(DB_SUPERPASS) psql -h $(DB_HOST) -p $(DB_PORT) -d postgres
endif

DBMATE ?= ./ops/db/bin/dbmate
LOCAL_DEV_HELPER := ./scripts/local_dev.sh
ifeq ($(USE_DOCKER),yes)
DBMATE_ENV :=
else
DBMATE_ENV := DBMATE_NO_DOCKER=1 LOCAL_DB_PORT=$(DB_PORT)
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
REST_STORY_TEST_SCRIPT := scripts/test_rest_story.sh
JWT_PUBLIC_DIR := ui/public/tokens
POSTGREST_CONTRACT_JWT ?= $(JWT_DIR)/admin.jwt
RUN_FULL_ELN_E2E ?= true

ifeq ($(USE_DOCKER),yes)
FULL_ELN_POSTGREST_URL ?= http://postgrest:3000
else
FULL_ELN_POSTGREST_URL ?= http://$(POSTGREST_HOST):$(POSTGREST_PORT)
endif

ifeq ($(PGHOST),db)
POSTGREST_HOST := postgrest
POSTGRAPHILE_HOST := postgraphile
POSTGREST_PORT := $(POSTGREST_INTERNAL_PORT)
POSTGRAPHILE_PORT := $(POSTGRAPHILE_INTERNAL_PORT)
DB_HOST_DISPLAY := db
endif

REST_URL := http://$(POSTGREST_HOST):$(POSTGREST_PORT)/samples
GRAPHILE_URL := http://$(POSTGRAPHILE_HOST):$(POSTGRAPHILE_PORT)/graphiql

ifeq ($(USE_DOCKER),yes)
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

db/terminate-connections:
ifeq ($(USE_DOCKER),yes)
	@if [ -n "$(shell docker compose ps -q db 2>/dev/null)" ]; then \
		$(PSQL_SUPER_CMD) -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$(DB_NAME)' AND pid <> pg_backend_pid();"; \
	else \
		echo "db container not running; skipping terminate-connections"; \
	fi
else
	$(PSQL_SUPER_CMD) -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$(DB_NAME)' AND pid <> pg_backend_pid();"
endif

db/drop: db/terminate-connections
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

ifeq ($(USE_DOCKER),yes)
contracts/export:
	docker compose up -d db postgrest postgraphile
	$(MAKE) db-wait >/dev/null
	mkdir -p $(POSTGREST_CONTRACT_DIR) $(POSTGRAPHILE_CONTRACT_DIR)
	@if [ ! -f "$(POSTGREST_CONTRACT_JWT)" ]; then \
	        echo "Missing PostgREST contract JWT: $(POSTGREST_CONTRACT_JWT)" >&2; \
	        exit 1; \
	fi
	@./scripts/export_postgrest_openapi.sh "$(POSTGREST_BASE_URL)" "$(POSTGREST_CONTRACT_JWT)" "$(POSTGREST_OPENAPI)"
	$(MAKE) db-wait >/dev/null
	jq -n --rawfile query $(INTROSPECTION_QUERY_FILE) '{"query": $$query}' > $(INTROSPECTION_PAYLOAD)
	curl -sS --retry 12 --retry-delay 1 --retry-all-errors -H "Content-Type: application/json" --data-binary @$(INTROSPECTION_PAYLOAD) $(POSTGRAPHILE_GRAPHQL_URL) | jq . > $(POSTGRAPHILE_SCHEMA_JSON)
	rm -f $(INTROSPECTION_PAYLOAD)
	@echo "Contracts exported to $(CONTRACTS_DIR)"
else
contracts/export:
	$(LOCAL_DEV_HELPER) start >/dev/null 2>&1
	$(MAKE) db-wait >/dev/null
	mkdir -p $(POSTGREST_CONTRACT_DIR) $(POSTGRAPHILE_CONTRACT_DIR)
	@if [ ! -f "$(POSTGREST_CONTRACT_JWT)" ]; then \
	        echo "Missing PostgREST contract JWT: $(POSTGREST_CONTRACT_JWT)" >&2; \
	        exit 1; \
	fi
	@./scripts/export_postgrest_openapi.sh "$(POSTGREST_BASE_URL)" "$(POSTGREST_CONTRACT_JWT)" "$(POSTGREST_OPENAPI)"
	$(MAKE) db-wait >/dev/null
	jq -n --rawfile query $(INTROSPECTION_QUERY_FILE) '{"query": $$query}' > $(INTROSPECTION_PAYLOAD)
	curl -sS --retry 12 --retry-delay 1 --retry-all-errors -H "Content-Type: application/json" --data-binary @$(INTROSPECTION_PAYLOAD) $(POSTGRAPHILE_GRAPHQL_URL) | jq . > $(POSTGRAPHILE_SCHEMA_JSON)
	rm -f $(INTROSPECTION_PAYLOAD)
	@echo "Contracts exported to $(CONTRACTS_DIR)"
endif

ifeq ($(USE_DOCKER),yes)
ci:
	docker compose stop postgrest postgraphile >/dev/null 2>&1 || true
	$(MAKE) db/reset
	$(MAKE) db/test
	$(MAKE) contracts/export
	$(MAKE) test/security
	$(MAKE) test/rest-story
	$(MAKE) test/ui
else
ci:
	$(LOCAL_DEV_HELPER) reset >/dev/null 2>&1
	$(LOCAL_DEV_HELPER) start >/dev/null 2>&1
	$(MAKE) db-wait >/dev/null
	$(MAKE) db/reset
	$(MAKE) db/test
	$(LOCAL_DEV_HELPER) stop >/dev/null 2>&1
	$(LOCAL_DEV_HELPER) start >/dev/null 2>&1
	$(MAKE) db-wait >/dev/null
	$(MAKE) contracts/export
	$(MAKE) test/security
	$(MAKE) test/rest-story
	$(MAKE) test/ui
endif

jwt/dev:
	PGRST_JWT_SECRET="$(PGRST_JWT_SECRET)" $(JWT_DEV_SCRIPT)
	@if [ -d "$(JWT_PUBLIC_DIR)" ]; then \
		mkdir -p $(JWT_PUBLIC_DIR); \
		cp $(JWT_DIR)/*.jwt $(JWT_PUBLIC_DIR)/; \
		echo "Copied JWT fixtures into $(JWT_PUBLIC_DIR)"; \
	fi

UI_SERVICE_MARKER := ui/.ui-service-started

ui/ready: jupyterlite/vendor ui/install

ifeq ($(USE_DOCKER),yes)
ui/dev: ui/ready $(UI_SERVICE_MARKER)

ui/install: ui/node_modules/.deps-ready

ui/node_modules/.deps-ready:
	docker compose down ui >/dev/null 2>&1 || true
	docker compose run --rm --no-deps ui sh -c 'npm ci && touch node_modules/.deps-ready'

$(UI_SERVICE_MARKER): ui/node_modules/.deps-ready
	docker compose up -d ui
	touch $(UI_SERVICE_MARKER)

test/ui: ui/install jupyterlite/vendor
	docker compose run --rm --no-deps \
		-e RUN_FULL_ELN_E2E=$(RUN_FULL_ELN_E2E) \
		-e FULL_ELN_POSTGREST_URL=$(FULL_ELN_POSTGREST_URL) \
		ui npm run test:ui
else
ui/dev: ui/ready
	$(LOCAL_DEV_HELPER) start >/dev/null 2>&1 || true
	@echo "UI dev server not managed by make in local mode; run: cd ui && npm install && npm run dev -- --host 0.0.0.0 --port 5173"

ui/install:
	$(LOCAL_DEV_HELPER) playwright-install

test/ui: ui/install
	$(LOCAL_DEV_HELPER) start >/dev/null 2>&1 || true
	$(MAKE) db-wait >/dev/null
	$(MAKE) jwt/dev >/dev/null
	$(MAKE) jupyterlite/vendor >/dev/null
	cd ui && RUN_FULL_ELN_E2E=$(RUN_FULL_ELN_E2E) \
		FULL_ELN_POSTGREST_URL=$(FULL_ELN_POSTGREST_URL) \
		npm run test:ui
endif

jupyterlite/vendor:
	./scripts/jupyterlite_vendor.sh

ifeq ($(USE_DOCKER),yes)
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

ifeq ($(USE_DOCKER),yes)
test/rest-story:
	docker compose up -d db postgrest >/dev/null
	$(MAKE) db-wait >/dev/null
	$(MAKE) jwt/dev >/dev/null
	PGRST_JWT_SECRET=$(PGRST_JWT_SECRET) \
	POSTGREST_URL=$(POSTGREST_BASE_URL) \
	$(REST_STORY_TEST_SCRIPT)
else
test/rest-story:
	$(LOCAL_DEV_HELPER) start >/dev/null 2>&1
	$(MAKE) db-wait >/dev/null
	$(MAKE) jwt/dev >/dev/null
	PGRST_JWT_SECRET=$(PGRST_JWT_SECRET) \
	POSTGREST_URL=$(POSTGREST_BASE_URL) \
	$(REST_STORY_TEST_SCRIPT)
endif

ifeq ($(USE_DOCKER),yes)
db/test:
	cat ops/db/tests/*.sql | $(PSQL_BATCH)
else
db/test:
	$(LOCAL_DEV_HELPER) start >/dev/null 2>&1
	$(MAKE) db-wait >/dev/null
	cat ops/db/tests/*.sql | $(PSQL_BATCH)
endif

rest:
	@echo "GET /samples via PostgREST";
	curl -s $(REST_URL) | jq .

gql:
	@echo "Open GraphiQL at $(GRAPHILE_URL)"
