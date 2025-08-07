#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE sparknexus_core;
    CREATE DATABASE sparknexus_tenants;
    CREATE DATABASE sparknexus_modules;
    CREATE DATABASE n8n;
EOSQL

echo "✅ Databases created successfully"
