SHELL := /bin/bash

.PHONY: up down logs db-wait migrate info psql rest gql seed

POSTGREST_HOST ?= localhost
POSTGRAPHILE_HOST ?= localhost
DB_HOST_DISPLAY ?= localhost
PSQL_CMD ?= docker compose exec -it db psql -U dev -d lims
DB_WAIT_CMD ?= docker compose exec -T db pg_isready -U postgres -d postgres

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

migrate:
	# entrypoint scripts already ran; but use this for subsequent sql in ops/db/migrations if you add them
	@echo "✔ Phase0 init complete (entrypoint init scripts)."

info:
	@echo "Postgres:    $(DB_HOST_DISPLAY):5432  db=lims  user=dev  pass=devpass"
	@echo "PostgREST:   $(REST_URL)"
	@echo "PostGraphile:$(GRAPHILE_URL)"

psql:
	$(PSQL_CMD)

rest:
	@echo "GET /samples via PostgREST";
	curl -s $(REST_URL) | jq .

gql:
	@echo "Open GraphiQL at $(GRAPHILE_URL)"
