#!/bin/bash

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🧪 TESTES DA API SPARK NEXUS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# URL base
BASE_URL="http://localhost:4201"

# 1. Teste de Health Check
echo -e "\n${YELLOW}1. Health Check:${NC}"
curl -X GET "$BASE_URL/api/health" \
  -H "Content-Type: application/json" | jq '.' || echo "API não respondeu"

# 2. Teste de Registro (Register)
echo -e "\n${YELLOW}2. Teste de Registro de Novo Usuário:${NC}"
curl -X POST "$BASE_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Teste",
    "lastName": "Usuario",
    "cpfCnpj": "12345678901",
    "email": "teste'$(date +%s)'@example.com",
    "phone": "11999999999",
    "company": "Teste Company",
    "password": "Teste@123456"
  }' | jq '.' || echo "Erro no registro"

# 3. Teste de Login
echo -e "\n${YELLOW}3. Teste de Login:${NC}"
RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "girardelibaptista@gmail.com",
    "password": "Demo@123456"
  }')

echo "$RESPONSE" | jq '.' || echo "$RESPONSE"

# Extrair token se login bem sucedido
TOKEN=$(echo "$RESPONSE" | jq -r '.token' 2>/dev/null)

if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    echo -e "\n${GREEN}✅ Login bem sucedido! Token obtido.${NC}"
    
    # 4. Teste de endpoint autenticado
    echo -e "\n${YELLOW}4. Teste de Endpoint Autenticado:${NC}"
    curl -X GET "$BASE_URL/api/stats" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" | jq '.' || echo "Erro ao acessar stats"
else
    echo -e "\n${YELLOW}⚠️ Login falhou ou token não obtido${NC}"
fi

# 5. Teste de Validação de CPF
echo -e "\n${YELLOW}5. Teste de Validação de CPF:${NC}"
curl -X POST "$BASE_URL/api/validate/cpf-cnpj" \
  -H "Content-Type: application/json" \
  -d '{
    "document": "01487829645"
  }' | jq '.' || echo "Erro na validação"

# 6. Teste de Validação de Email
echo -e "\n${YELLOW}6. Teste de Validação de Email:${NC}"
curl -X POST "$BASE_URL/api/validate/email-format" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "teste@example.com"
  }' | jq '.' || echo "Erro na validação de email"

echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Testes concluídos!${NC}"
