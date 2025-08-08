#!/bin/bash
if [ -z "$1" ]; then
    echo "📋 Mostrando logs de todos os serviços..."
    docker-compose logs -f --tail=50
else
    echo "📋 Mostrando logs de $1..."
    docker-compose logs -f --tail=50 "$1"
fi
