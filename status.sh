#!/bin/bash
echo "📊 Status do Spark Nexus:"
echo ""
docker-compose ps
echo ""
echo "Para ver logs: docker-compose logs -f [service-name]"
