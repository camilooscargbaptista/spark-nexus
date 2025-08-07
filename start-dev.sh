#!/bin/bash
# ==================================================
# start-dev.sh - Para desenvolvimento
# ==================================================

echo "🚀 Starting Development Environment..."

# Apenas infraestrutura
docker-compose -f docker-compose.complete.yml up -d postgres redis rabbitmq

echo "✅ Infrastructure ready for development!"
echo ""
echo "Now you can run services locally:"
echo "  cd core/auth-service && npm run dev"
echo "  cd core/billing-service && npm run dev"
echo "  cd modules/email-validator && npm run dev"
echo ""
echo "Infrastructure ports:"
echo "  - PostgreSQL: localhost:5432"
echo "  - Redis: localhost:6379"
echo "  - RabbitMQ: localhost:5672"