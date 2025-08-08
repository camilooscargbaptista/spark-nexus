#!/bin/bash
echo "📊 Monitorando Client Dashboard..."
watch -n 2 'docker ps | grep client-dashboard && echo "" && curl -s http://localhost:4201/api/health | jq .'
