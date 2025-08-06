#!/bin/bash
set -e

# Create multiple databases
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE sparknexus_core;
    CREATE DATABASE sparknexus_tenants;
    CREATE DATABASE sparknexus_modules;
    
    GRANT ALL PRIVILEGES ON DATABASE sparknexus_core TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON DATABASE sparknexus_tenants TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON DATABASE sparknexus_modules TO $POSTGRES_USER;
EOSQL

# Initialize schemas
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d sparknexus_core < /schemas/001-core.sql
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d sparknexus_tenants < /schemas/002-tenants.sql
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d sparknexus_modules < /schemas/003-modules.sql

echo "Databases initialized successfully!"
