#!/bin/bash

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

API_URL="http://localhost:4201/api"

echo "================================================"
echo "🧪 Testando APIs do Spark Nexus"
echo "================================================"

# Health Check
echo -e "\n${YELLOW}1. Health Check${NC}"
curl -s "$API_URL/health" | jq '.'

# Validar CPF
echo -e "\n${YELLOW}2. Validar CPF${NC}"
curl -s -X POST "$API_URL/validate/cpf-cnpj" \
  -H "Content-Type: application/json" \
  -d '{"document":"11144477735"}' | jq '.'

# Validar CNPJ
echo -e "\n${YELLOW}3. Validar CNPJ${NC}"
curl -s -X POST "$API_URL/validate/cpf-cnpj" \
  -H "Content-Type: application/json" \
  -d '{"document":"11222333000181"}' | jq '.'

# Validar Email
echo -e "\n${YELLOW}4. Validar Email${NC}"
curl -s -X POST "$API_URL/validate/email-format" \
  -H "Content-Type: application/json" \
  -d '{"email":"teste@exemplo.com"}' | jq '.'

# Validar Telefone
echo -e "\n${YELLOW}5. Validar Telefone${NC}"
curl -s -X POST "$API_URL/validate/phone" \
  -H "Content-Type: application/json" \
  -d '{"phone":"11987654321"}' | jq '.'

echo -e "\n${GREEN}✅ Testes concluídos!${NC}"
echo "Para testar registro e login, acesse: http://localhost:4201/register"
