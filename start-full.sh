#!/bin/bash
# ==================================================
# start-full.sh - Tudo incluindo monitoring
# ==================================================

echo "🚀 Starting Complete Spark Nexus Platform..."

# Tudo sem monitoring
docker-compose -f docker-compose.complete.yml up -d

# Monitoring opcional
echo "Start monitoring? (y/n)"
read -r response
if [ "$response" = "y" ]; then
    docker-compose -f docker-compose.complete.yml --profile monitoring up -d
fi

echo "✅ Complete platform running!"
echo ""
echo "🌐 All Services:"
echo "  - Admin Dashboard: http://localhost:4200"
echo "  - Client Dashboard: http://localhost:4201"
echo "  - API Gateway: http://localhost:8000"
echo "  - Auth Service: http://localhost:3001"
echo "  - Billing Service: http://localhost:3002"
echo "  - Tenant Service: http://localhost:3003"
echo "  - Email Validator: http://localhost:4001"
echo "  - N8N: http://localhost:5678"
echo "  - RabbitMQ: http://localhost:15672"
if [ "$response" = "y" ]; then
    echo "  - Prometheus: http://localhost:9090"
    echo "  - Grafana: http://localhost:3000"
fi