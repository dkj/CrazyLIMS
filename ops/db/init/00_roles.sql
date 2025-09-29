-- Core roles
CREATE ROLE web_anon NOLOGIN;
CREATE ROLE dev LOGIN PASSWORD 'devpass';
CREATE ROLE app_auth NOLOGIN;

-- Ensure dev can manage schema during Phase0
GRANT web_anon TO dev;
GRANT app_auth TO dev;