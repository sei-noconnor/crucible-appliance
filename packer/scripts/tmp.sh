#!/bin/bash
POSTGRES_PASSWORD="odrXqetU5L"
kubectl -n default exec postgresql-0 -- bash -c "PGPASSWORD=${POSTGRES_PASSWORD} psql -h localhost -p 5432 -U postgres -c 'CREATE EXTENSION 'uuid-ossp';" || true
kubectl -n default exec postgresql-0 -- bash -c "PGPASSWORD=${POSTGRES_PASSWORD} psql -h localhost -p 5432 -U postgres -c "ALTER USER postgres PASSWORD 'crucible';"" || true
DROP DATABASE alloy_db WITH (FORCE);