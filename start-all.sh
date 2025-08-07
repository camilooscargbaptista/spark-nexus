#!/bin/bash

echo "🚀 Starting Spark Nexus Platform..."

# Start infrastructure first
echo "Starting infrastructure..."
docker-compose up -d

# Wait for infrastructure
echo "Waiting for infrastructure to be ready..."
sleep 10

# Start services
echo "Starting services..."
docker-compose -f docker-compose.services.yml up -d

echo "✅ Spark Nexus Platform is running!"
echo ""
echo "🌐 Access Points:"
echo "  - Auth Service: http://localhost:3001/health"
echo "  - Billing Service: http://localhost:3002/health"
echo "  - Email Validator: http://localhost:4001/health"
echo "  - N8N: http://localhost:5678 (admin/admin123)"
echo "  - RabbitMQ: http://localhost:15672 (sparknexus/SparkMQ2024!)"
echo "  - PostgreSQL: localhost:5432 (sparknexus/SparkNexus2024!)"
echo ""
