#!/bin/bash
echo "🚀 Iniciando Spark Nexus..."
docker-compose up -d
echo "✅ Serviços iniciados!"
echo "Aguarde alguns segundos para os serviços ficarem prontos."
echo ""
echo "📊 Acesse:"
echo "  Upload: http://localhost:4201/upload"
echo "  Dashboard: http://localhost:4201"
echo "  N8N: http://localhost:5678"
