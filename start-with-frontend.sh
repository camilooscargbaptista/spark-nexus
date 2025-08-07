#!/bin/bash

echo "🚀 Starting Spark Nexus with Frontend..."

# Parar containers antigos
docker-compose -f docker-compose.with-frontend.yml down

# Iniciar infraestrutura
docker-compose -f docker-compose.with-frontend.yml up -d postgres redis rabbitmq

# Aguardar PostgreSQL
echo "Waiting for PostgreSQL..."
until docker exec sparknexus-postgres pg_isready -U sparknexus 2>/dev/null; do
    sleep 2
done

# Iniciar serviços core
docker-compose -f docker-compose.with-frontend.yml up -d auth-service billing-service tenant-service

# Iniciar módulos
docker-compose -f docker-compose.with-frontend.yml up -d email-validator

# Iniciar gateway e automação
docker-compose -f docker-compose.with-frontend.yml up -d kong n8n

# Iniciar dashboards
docker-compose -f docker-compose.with-frontend.yml up -d admin-dashboard client-dashboard

echo "✅ Platform with Frontend running!"
echo ""
echo "🌐 Access Points:"
echo "  - Admin Dashboard: http://localhost:4200"
echo "  - Client Dashboard: http://localhost:4201"
echo "  - Auth Service: http://localhost:3001/health"
echo "  - Billing Service: http://localhost:3002/health"
echo "  - Email Validator: http://localhost:4001/health"
echo "  - N8N: http://localhost:5678"
echo "  - RabbitMQ: http://localhost:15672"
