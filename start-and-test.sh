#!/bin/bash

# ================================================
# Script de Inicialização e Teste Completo
# Spark Nexus - Start & Test
# ================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${MAGENTA}================================================${NC}"
echo -e "${MAGENTA}🚀 INICIANDO SISTEMA SPARK NEXUS${NC}"
echo -e "${MAGENTA}================================================${NC}"

# ================================================
# 1. VERIFICAR DOCKER
# ================================================
echo -e "\n${BLUE}[1/8] Verificando Docker${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker não está rodando!${NC}"
    echo "Por favor, inicie o Docker Desktop primeiro."
    exit 1
fi
echo -e "${GREEN}✅ Docker está rodando${NC}"

# ================================================
# 2. PARAR TUDO PRIMEIRO
# ================================================
echo -e "\n${BLUE}[2/8] Limpando ambiente${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Parando containers existentes..."
docker-compose down 2>/dev/null || true
echo -e "${GREEN}✅ Ambiente limpo${NC}"

# ================================================
# 3. INICIAR SERVIÇOS ESSENCIAIS
# ================================================
echo -e "\n${BLUE}[3/8] Iniciando Serviços Essenciais${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Iniciando PostgreSQL e Redis..."
docker-compose up -d postgres redis

echo -e "${YELLOW}⏳ Aguardando banco de dados (20 segundos)...${NC}"
sleep 20

# Verificar se estão saudáveis
echo "Verificando saúde dos serviços..."
docker exec sparknexus-postgres pg_isready -U sparknexus || {
    echo -e "${RED}❌ PostgreSQL não está pronto${NC}"
    exit 1
}
echo -e "${GREEN}✅ PostgreSQL está saudável${NC}"

docker exec sparknexus-redis redis-cli ping || {
    echo -e "${RED}❌ Redis não está respondendo${NC}"
    exit 1
}
echo -e "${GREEN}✅ Redis está saudável${NC}"

# ================================================
# 4. INICIAR SERVIÇOS DA APLICAÇÃO
# ================================================
echo -e "\n${BLUE}[4/8] Iniciando Aplicação${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Iniciando Email Validator..."
docker-compose up -d email-validator

echo "Iniciando Client Dashboard..."
docker-compose up -d client-dashboard

echo "Iniciando Auth Service..."
docker-compose up -d auth

echo -e "${YELLOW}⏳ Aguardando serviços iniciarem (15 segundos)...${NC}"
sleep 15

# ================================================
# 5. VERIFICAR STATUS
# ================================================
echo -e "\n${BLUE}[5/8] Verificando Status${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}📊 Containers Rodando:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep sparknexus || echo "Nenhum container sparknexus encontrado"

# Verificar se há containers com problemas
FAILED=$(docker ps -a --filter "name=sparknexus" --filter "status=exited" --format "{{.Names}}")
if [ ! -z "$FAILED" ]; then
    echo -e "\n${YELLOW}⚠️ Containers com problemas:${NC}"
    echo "$FAILED"
    echo -e "${YELLOW}Verificando logs...${NC}"
    for container in $FAILED; do
        echo -e "\n${YELLOW}Logs de $container:${NC}"
        docker logs --tail 10 $container 2>&1
    done
fi

# ================================================
# 6. TESTAR APIS
# ================================================
echo -e "\n${BLUE}[6/8] Testando APIs${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Função para testar endpoint
test_endpoint() {
    local url=$1
    local name=$2
    
    echo -n "Testando $name... "
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✅ Online${NC}"
        return 0
    else
        echo -e "${RED}❌ Offline${NC}"
        return 1
    fi
}

# Testar cada endpoint
test_endpoint "http://localhost:4201/api/health" "API Health Check"
test_endpoint "http://localhost:4201" "Client Dashboard"
test_endpoint "http://localhost:4201/upload" "Upload Page"
test_endpoint "http://localhost:4200" "Email Validator API"

# ================================================
# 7. CRIAR ARQUIVO DE TESTE
# ================================================
echo -e "\n${BLUE}[7/8] Criando Arquivo de Teste${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cat > test-emails.csv << 'EOF'
email,name,company
contato@sparknexus.com.br,Contato Principal,Spark Nexus
teste@gmail.com,Teste Gmail,Test Company
invalid-email,Email Invalido,Test Company
admin@example.com,Admin User,Example Corp
info@google.com,Google Info,Google
support@microsoft.com,MS Support,Microsoft
hello@world.com,Hello World,World Inc
test@test.com,Test User,Test Inc
noreply@github.com,GitHub,GitHub Inc
contact@amazon.com,Amazon Contact,Amazon
EOF

echo -e "${GREEN}✅ Arquivo test-emails.csv criado${NC}"
echo "   10 emails de teste prontos para validação"

# ================================================
# 8. INSTRUÇÕES FINAIS
# ================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SISTEMA SPARK NEXUS INICIADO COM SUCESSO!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}🎯 COMO TESTAR O SISTEMA:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}Opção 1 - Interface Web (Recomendado):${NC}"
echo "1. Abra o navegador"
echo "2. Acesse: ${CYAN}http://localhost:4201/upload${NC}"
echo "3. Clique em 'Escolher arquivo'"
echo "4. Selecione: ${YELLOW}test-emails.csv${NC}"
echo "5. Digite seu email: ${YELLOW}contato@sparknexus.com.br${NC}"
echo "6. Clique em 'Iniciar Validação'"
echo "7. Aguarde o email com o relatório!"

echo -e "\n${GREEN}Opção 2 - Teste via Terminal:${NC}"
echo "curl -X POST http://localhost:4201/api/validate/email-format \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"email\":\"contato@sparknexus.com.br\"}'"

echo -e "\n${GREEN}Opção 3 - Teste de Email Direto:${NC}"
echo "node test-titan-email.js"

echo -e "\n${CYAN}📊 URLS DISPONÍVEIS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "• Upload de Emails: ${GREEN}http://localhost:4201/upload${NC}"
echo "• Dashboard: ${GREEN}http://localhost:4201${NC}"
echo "• API Health: ${GREEN}http://localhost:4201/api/health${NC}"
echo "• Email Validator: ${GREEN}http://localhost:4200${NC}"

echo -e "\n${CYAN}🔍 COMANDOS ÚTEIS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "• Ver logs em tempo real:"
echo "  ${YELLOW}docker-compose logs -f${NC}"
echo ""
echo "• Ver logs de um serviço específico:"
echo "  ${YELLOW}docker-compose logs -f email-validator${NC}"
echo ""
echo "• Verificar status:"
echo "  ${YELLOW}docker ps | grep sparknexus${NC}"
echo ""
echo "• Parar tudo:"
echo "  ${YELLOW}docker-compose down${NC}"
echo ""
echo "• Reiniciar um serviço:"
echo "  ${YELLOW}docker-compose restart client-dashboard${NC}"

echo -e "\n${CYAN}📧 VERIFICAR EMAIL:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Após fazer o upload, verifique seu email em:"
echo "• Webmail Titan: ${GREEN}https://mail.titan.email${NC}"
echo "• Ou no seu cliente de email configurado"

echo -e "\n${MAGENTA}🚀 Sistema pronto para uso!${NC}"
echo -e "${MAGENTA}   Abra: http://localhost:4201/upload${NC}"

# Abrir automaticamente no navegador (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "\n${YELLOW}Abrindo navegador...${NC}"
    sleep 2
    open "http://localhost:4201/upload"
fi