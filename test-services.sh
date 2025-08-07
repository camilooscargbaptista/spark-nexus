#!/bin/bash

echo "🔍 Testing Spark Nexus Services..."
echo ""

# Function to test endpoint
test_endpoint() {
    local service=$1
    local url=$2
    
    echo -n "Testing $service... "
    response=$(curl -s -o /dev/null -w "%{http_code}" $url)
    
    if [ "$response" = "200" ]; then
        echo "✅ OK"
    else
        echo "❌ Failed (HTTP $response)"
    fi
}

# Test services
test_endpoint "Auth Service" "http://localhost:3001/health"
test_endpoint "Billing Service" "http://localhost:3002/health"
test_endpoint "Email Validator" "http://localhost:4001/health"
test_endpoint "N8N" "http://localhost:5678"
test_endpoint "RabbitMQ Management" "http://localhost:15672"

echo ""
echo "Done!"
