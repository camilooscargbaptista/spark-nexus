#!/bin/bash

# ================================================
# Script Completo - Corrigir e Iniciar Tudo
# Spark Nexus - Fix & Start All Services
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
echo -e "${MAGENTA}🚀 SPARK NEXUS - INICIALIZAÇÃO COMPLETA${NC}"
echo -e "${MAGENTA}================================================${NC}"

# ================================================
# 1. CORRIGIR PROBLEMA DO KONG
# ================================================
echo -e "\n${BLUE}[1/7] Corrigindo Kong${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Remover atributo version obsoleto
echo "Removendo atributo 'version' obsoleto..."
sed -i.bak '/^version:/d' docker-compose.yml 2>/dev/null || true

# Corrigir imagem do Kong
echo "Corrigindo imagem do Kong..."
sed -i.bak 's/kong:3.4-alpine/kong:3.4/g' docker-compose.yml 2>/dev/null || true
sed -i.bak 's/kong:3.3-alpine/kong:3.3/g' docker-compose.yml 2>/dev/null || true

echo -e "${GREEN}✅ Kong corrigido${NC}"

# ================================================
# 2. LIMPAR AMBIENTE
# ================================================
echo -e "\n${BLUE}[2/7] Limpando Ambiente${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Parando todos os containers..."
docker-compose down --remove-orphans 2>/dev/null || true

echo -e "${GREEN}✅ Ambiente limpo${NC}"

# ================================================
# 3. INICIAR SERVIÇOS ESSENCIAIS
# ================================================
echo -e "\n${BLUE}[3/7] Iniciando Serviços Essenciais${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Iniciando PostgreSQL e Redis..."
docker-compose up -d postgres redis

echo "Iniciando RabbitMQ..."
docker-compose up -d rabbitmq

echo -e "${YELLOW}⏳ Aguardando serviços essenciais (20 segundos)...${NC}"
sleep 20

# Verificar saúde
docker exec sparknexus-postgres pg_isready -U sparknexus > /dev/null 2>&1 && echo -e "${GREEN}✅ PostgreSQL OK${NC}" || echo -e "${YELLOW}⚠️ PostgreSQL iniciando...${NC}"
docker exec sparknexus-redis redis-cli ping > /dev/null 2>&1 && echo -e "${GREEN}✅ Redis OK${NC}" || echo -e "${YELLOW}⚠️ Redis iniciando...${NC}"

# ================================================
# 4. INICIAR SERVIÇOS DE AUTENTICAÇÃO
# ================================================
echo -e "\n${BLUE}[4/7] Iniciando Serviços de Autenticação${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Iniciando Auth Service..."
docker-compose up -d auth-service

sleep 5

# ================================================
# 5. INICIAR SERVIÇOS DA APLICAÇÃO
# ================================================
echo -e "\n${BLUE}[5/7] Iniciando Aplicações${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Email Validator
echo "Iniciando Email Validator API..."
docker-compose up -d email-validator-api

echo "Iniciando Email Validator Worker..."
docker-compose up -d email-validator-worker

# Dashboards
echo "Iniciando Client Dashboard..."
docker-compose up -d client-dashboard

echo "Iniciando Admin Dashboard..."
docker-compose up -d admin-dashboard

# Outros serviços
echo "Iniciando Tenant Service..."
docker-compose up -d tenant-service

echo "Iniciando Billing Service..."
docker-compose up -d billing-service

echo -e "${YELLOW}⏳ Aguardando aplicações iniciarem (15 segundos)...${NC}"
sleep 15

# ================================================
# 6. INICIAR SERVIÇOS ADMINISTRATIVOS
# ================================================
echo -e "\n${BLUE}[6/7] Iniciando Serviços Administrativos${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "Iniciando Adminer (PostgreSQL Admin)..."
docker-compose up -d adminer

echo "Iniciando Redis Commander..."
docker-compose up -d redis-commander

# N8N se configurado
if grep -q "N8N_" .env 2>/dev/null; then
    echo "Iniciando N8N..."
    docker-compose up -d n8n
fi

# Kong se possível
echo "Tentando iniciar Kong API Gateway..."
docker-compose up -d kong 2>/dev/null || echo -e "${YELLOW}⚠️ Kong não pôde ser iniciado (opcional)${NC}"

# ================================================
# 7. VERIFICAR STATUS E TESTAR
# ================================================
echo -e "\n${BLUE}[7/7] Verificando Status${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}📊 Containers Rodando:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus || echo "Verificando..."

# Testar endpoints principais
echo -e "\n${CYAN}🔍 Testando Endpoints:${NC}"

test_endpoint() {
    local url=$1
    local name=$2
    
    echo -n "  $name: "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ] || [ "$response" = "301" ] || [ "$response" = "302" ]; then
        echo -e "${GREEN}✅ Online${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️ HTTP $response${NC}"
        return 1
    fi
}

# Testar serviços principais
test_endpoint "http://localhost:4200" "Email Validator API (4200)"
test_endpoint "http://localhost:4201" "Client Dashboard (4201)"
test_endpoint "http://localhost:4201/upload" "Upload Page (4201/upload)"
test_endpoint "http://localhost:4202" "Admin Dashboard (4202)"
test_endpoint "http://localhost:8080" "Adminer - PostgreSQL (8080)"
test_endpoint "http://localhost:8081" "Redis Commander (8081)"
test_endpoint "http://localhost:15672" "RabbitMQ Management (15672)"

# Criar arquivo de teste se não existir
if [ ! -f "test-emails.csv" ]; then
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
EOF
    echo -e "\n${GREEN}✅ Arquivo test-emails.csv criado${NC}"
fi

# ================================================
# INSTRUÇÕES FINAIS
# ================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SISTEMA SPARK NEXUS INICIADO!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}🎯 PRINCIPAIS URLS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📤 Upload de Emails:${NC} http://localhost:4201/upload"
echo -e "${GREEN}📊 Client Dashboard:${NC} http://localhost:4201"
echo -e "${GREEN}🔧 Admin Dashboard:${NC} http://localhost:4202"
echo -e "${GREEN}📧 Email Validator API:${NC} http://localhost:4200"

echo -e "\n${CYAN}🗄️ INTERFACES ADMINISTRATIVAS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🐘 PostgreSQL Admin:${NC} http://localhost:8080"
echo "     Sistema: PostgreSQL | Servidor: postgres"
echo "     Usuário: sparknexus | Senha: SparkNexus2024"
echo "     Banco: sparknexus"
echo ""
echo -e "${GREEN}🔴 Redis Commander:${NC} http://localhost:8081"
echo -e "${GREEN}🐰 RabbitMQ:${NC} http://localhost:15672"
echo "     Usuário: guest | Senha: guest"

echo -e "\n${CYAN}📝 COMO TESTAR:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "1. Acesse: http://localhost:4201/upload"
echo "2. Faça upload do arquivo: test-emails.csv"
echo "3. Digite seu email: contato@sparknexus.com.br"
echo "4. Clique em 'Iniciar Validação'"
echo "5. Verifique o email no Titan: https://mail.titan.email"

echo -e "\n${CYAN}🔍 COMANDOS ÚTEIS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "• Ver logs gerais: ${YELLOW}docker-compose logs -f${NC}"
echo "• Ver logs específicos: ${YELLOW}docker-compose logs -f client-dashboard${NC}"
echo "• Status dos containers: ${YELLOW}docker ps | grep sparknexus${NC}"
echo "• Parar tudo: ${YELLOW}docker-compose down${NC}"
echo "• Reiniciar serviço: ${YELLOW}docker-compose restart [serviço]${NC}"

echo -e "\n${CYAN}🧪 TESTE RÁPIDO DE EMAIL:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "node test-titan-email.js"

# Verificar containers com problemas
echo -e "\n${CYAN}⚠️ VERIFICANDO PROBLEMAS:${NC}"
FAILED=$(docker ps -a --filter "name=sparknexus" --filter "status=exited" --format "{{.Names}}")
if [ ! -z "$FAILED" ]; then
    echo -e "${RED}Containers com erro:${NC}"
    for container in $FAILED; do
        echo "  • $container"
        echo "    Ver logs: docker logs $container"
    done
else
    echo -e "${GREEN}✅ Todos os containers estão rodando${NC}"
fi

# Abrir navegador automaticamente
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "\n${YELLOW}Abrindo navegador em 3 segundos...${NC}"
    sleep 3
    open "http://localhost:4201/upload" 2>/dev/null || open "http://localhost:4201"
fi

echo -e "\n${MAGENTA}🚀 Sistema pronto! Acesse: http://localhost:4201/upload${NC}"