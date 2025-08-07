#!/bin/bash

SERVICE=$1

if [ -z "$SERVICE" ]; then
    echo "📋 Available services:"
    echo "  Infrastructure:"
    echo "    - postgres"
    echo "    - redis"
    echo "    - rabbitmq"
    echo "  Services:"
    echo "    - auth-service"
    echo "    - billing-service"
    echo "    - email-validator"
    echo "    - n8n"
    echo ""
    echo "Usage: ./logs.sh [service-name]"
else
    # Try both docker-compose files
    docker-compose logs -f $SERVICE 2>/dev/null || \
    docker-compose -f docker-compose.services.yml logs -f $SERVICE
fi
