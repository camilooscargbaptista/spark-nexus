
#!/bin/bash
# ==================================================
# start-minimal.sh - Apenas o essencial
# ==================================================

echo "🚀 Starting Spark Nexus (Minimal)..."

# Infraestrutura básica
docker-compose -f docker-compose.complete.yml up -d postgres redis

# Aguardar
sleep 10

# Serviços core
docker-compose -f docker-compose.complete.yml up -d auth-service billing-service tenant-service

# Módulo principal
docker-compose -f docker-compose.complete.yml up -d email-validator

echo "✅ Minimal setup running!"
echo "Services: PostgreSQL, Redis, Auth, Billing, Tenant, Email Validator"