#!/bin/bash

echo "🚀 Starting Spark Nexus (Safe Mode)..."

# Parar containers antigos
echo "Limpando containers antigos..."
docker-compose -f docker-compose.fixed.yml down 2>/dev/null

# Iniciar apenas infraestrutura primeiro
echo "Iniciando infraestrutura..."
docker-compose -f docker-compose.fixed.yml up -d postgres redis rabbitmq

# Aguardar PostgreSQL estar pronto
echo "Aguardando PostgreSQL..."
until docker exec sparknexus-postgres pg_isready -U sparknexus 2>/dev/null; do
    echo -n "."
    sleep 2
done
echo " ✅"

# Iniciar serviços core
echo "Iniciando serviços core..."
docker-compose -f docker-compose.fixed.yml up -d auth-service billing-service tenant-service

# Iniciar módulos
echo "Iniciando módulos..."
docker-compose -f docker-compose.fixed.yml up -d email-validator

# Iniciar gateway e automação
echo "Iniciando gateway e automação..."
docker-compose -f docker-compose.fixed.yml up -d kong n8n

echo ""
echo "✅ Plataforma iniciada com sucesso!"
echo ""
echo "🌐 Serviços disponíveis:"
echo "  - Auth Service: http://localhost:3001/health"
echo "  - Billing Service: http://localhost:3002/health"
echo "  - Tenant Service: http://localhost:3003/health"
echo "  - Email Validator: http://localhost:4001/health"
echo "  - API Gateway: http://localhost:8000"
echo "  - N8N: http://localhost:5678"
echo "  - RabbitMQ: http://localhost:15672"
echo ""
echo "Para ver logs: docker-compose -f docker-compose.fixed.yml logs -f [service-name]"
echo "Para parar: docker-compose -f docker-compose.fixed.yml down"
