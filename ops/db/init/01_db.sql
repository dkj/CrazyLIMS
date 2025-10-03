-- Create database and grant to dev
-- (Entry-point runs in 'postgres' DB already)
CREATE DATABASE lims OWNER postgres;
GRANT CONNECT ON DATABASE lims TO dev, postgrest_authenticator, postgraphile_authenticator;
\connect lims;

-- Basic extensions useful in Phase0
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Schemas
CREATE SCHEMA IF NOT EXISTS lims AUTHORIZATION postgres;

-- Ownership and grants
ALTER SCHEMA lims OWNER TO postgres;
GRANT USAGE ON SCHEMA lims TO web_anon, app_auth, dev;
GRANT CREATE ON SCHEMA lims TO dev;
