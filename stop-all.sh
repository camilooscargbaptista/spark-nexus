#!/bin/bash

echo "🛑 Stopping Spark Nexus Platform..."
docker-compose -f docker-compose.services.yml down
docker-compose down
echo "✅ Platform stopped"
