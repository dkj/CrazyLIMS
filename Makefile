SHELL := /bin/bash

.PHONY: up down logs db-wait db/create db/drop db/migrate db/rollback db/status db/dump db/new db/reset db/redo migrate info psql rest gql contracts/export ci jwt/dev test/security db/test

POSTGREST_HOST ?= localhost
POSTGRAPHILE_HOST ?= localhost
DB_HOST_DISPLAY ?= localhost
PSQL_CMD ?= docker compose exec -it db psql -U dev -d lims
DB_WAIT_CMD ?= docker compose exec -T db pg_isready -U postgres -d postgres
DBMATE ?= ./ops/db/bin/dbmate
PGRST_JWT_SECRET ?= dev_jwt_secret_change_me_which_is_at_least_32_characters
PSQL_BATCH ?= docker compose exec -T db psql -U dev -d lims

CONTRACTS_DIR ?= contracts
POSTGREST_CONTRACT_DIR := $(CONTRACTS_DIR)/postgrest
POSTGRAPHILE_CONTRACT_DIR := $(CONTRACTS_DIR)/postgraphile
POSTGREST_OPENAPI := $(POSTGREST_CONTRACT_DIR)/openapi.json
POSTGRAPHILE_SCHEMA_JSON := $(POSTGRAPHILE_CONTRACT_DIR)/schema.json
INTROSPECTION_QUERY_FILE ?= ops/contracts/introspection.graphql
INTROSPECTION_PAYLOAD := $(POSTGRAPHILE_CONTRACT_DIR)/.introspection-request.json
POSTGREST_BASE_URL = http://$(POSTGREST_HOST):3000
POSTGRAPHILE_GRAPHQL_URL = http://$(POSTGRAPHILE_HOST):3001/graphql
JWT_DIR := ops/examples/jwts
JWT_DEV_SCRIPT := $(JWT_DIR)/make-dev-jwts.sh
RBAC_TEST_SCRIPT := scripts/test_rbac.sh
JWT_PUBLIC_DIR := ui/public/tokens

ifeq ($(PGHOST),db)
POSTGREST_HOST := postgrest
POSTGRAPHILE_HOST := postgraphile
DB_HOST_DISPLAY := db
endif

REST_URL := http://$(POSTGREST_HOST):3000/samples
GRAPHILE_URL := http://$(POSTGRAPHILE_HOST):3001/graphiql

up:
	docker compose up -d --build

down:
	docker compose down -v

logs:
	docker compose logs -f --tail=200

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
	@echo "Postgres:    $(DB_HOST_DISPLAY):5432  db=lims  user=dev  pass=devpass"
	@echo "PostgREST:   $(REST_URL)"
	@echo "PostGraphile:$(GRAPHILE_URL)"

psql:
	$(PSQL_CMD)

contracts/export:
	docker compose up -d db postgrest postgraphile
	mkdir -p $(POSTGREST_CONTRACT_DIR) $(POSTGRAPHILE_CONTRACT_DIR)
	curl -sS --retry 12 --retry-delay 1 --retry-all-errors -H "Accept: application/openapi+json" $(POSTGREST_BASE_URL)/ | jq . > $(POSTGREST_OPENAPI)
	jq -n --rawfile query $(INTROSPECTION_QUERY_FILE) '{"query": $$query}' > $(INTROSPECTION_PAYLOAD)
	curl -sS --retry 12 --retry-delay 1 --retry-all-errors -H "Content-Type: application/json" --data-binary @$(INTROSPECTION_PAYLOAD) $(POSTGRAPHILE_GRAPHQL_URL) | jq . > $(POSTGRAPHILE_SCHEMA_JSON)
	rm -f $(INTROSPECTION_PAYLOAD)
	@echo "Contracts exported to $(CONTRACTS_DIR)"

ci:
	docker compose stop postgrest postgraphile >/dev/null 2>&1 || true
	$(MAKE) db/reset
	$(MAKE) db/test
	$(MAKE) contracts/export
	$(MAKE) test/security

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
	docker compose up -d db postgrest postgraphile >/dev/null
	$(MAKE) db-wait >/dev/null
	$(MAKE) jwt/dev >/dev/null
	POSTGREST_URL=$(POSTGREST_BASE_URL) POSTGRAPHILE_URL=$(POSTGRAPHILE_GRAPHQL_URL) $(RBAC_TEST_SCRIPT)

db/test:
	cat ops/db/tests/security.sql | $(PSQL_BATCH)

rest:
	@echo "GET /samples via PostgREST";
	curl -s $(REST_URL) | jq .

gql:
	@echo "Open GraphiQL at $(GRAPHILE_URL)"
