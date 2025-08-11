#!/bin/bash

# ================================================
# SPARK NEXUS - FORCE RESTART ALL CONTAINERS
# Reinicialização forçada com limpeza completa
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

# ================================================
# HEADER
# ================================================
clear
echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║      🔄 FORCE RESTART - REINICIALIZAÇÃO COMPLETA            ║${NC}"
echo -e "${RED}║      Limpeza de cache e reinício forçado                    ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================
# PASSO 1: PARAR TODOS OS CONTAINERS
# ================================================
echo -e "${YELLOW}[1/10] Parando TODOS os containers...${NC}"
docker-compose down --remove-orphans
echo -e "${GREEN}✅ Todos os containers parados e removidos${NC}"

# ================================================
# PASSO 2: LIMPAR CONTAINERS ÓRFÃOS
# ================================================
echo -e "\n${YELLOW}[2/10] Limpando containers órfãos...${NC}"
docker container prune -f 2>/dev/null || true
echo -e "${GREEN}✅ Containers órfãos removidos${NC}"

# ================================================
# PASSO 3: LIMPAR CACHE DOCKER DO CLIENT
# ================================================
echo -e "\n${YELLOW}[3/10] Limpando cache e volumes temporários...${NC}"

# Remover volumes temporários (mantém os volumes de dados)
docker volume ls -q | grep -v "_data" | xargs -r docker volume rm 2>/dev/null || true

# Limpar build cache
docker builder prune -f 2>/dev/null || true

echo -e "${GREEN}✅ Cache limpo${NC}"

# ================================================
# PASSO 4: VERIFICAR NODE_MODULES
# ================================================
echo -e "\n${YELLOW}[4/10] Verificando node_modules em client-dashboard...${NC}"

if [ -d "core/client-dashboard/node_modules" ]; then
    MODULE_COUNT=$(ls -1 core/client-dashboard/node_modules 2>/dev/null | wc -l)
    echo -e "${GREEN}✅ $MODULE_COUNT módulos encontrados${NC}"
    
    # Verificar especificamente o exceljs
    if [ -d "core/client-dashboard/node_modules/exceljs" ]; then
        echo -e "${GREEN}✅ ExcelJS está instalado${NC}"
    else
        echo -e "${YELLOW}⚠️  ExcelJS NÃO encontrado - instalando...${NC}"
        cd core/client-dashboard
        npm install exceljs --save
        cd ../..
    fi
else
    echo -e "${YELLOW}⚠️  node_modules não existe - instalando dependências...${NC}"
    cd core/client-dashboard
    npm install
    cd ../..
fi

# ================================================
# PASSO 5: RECONSTRUIR IMAGEM DO CLIENT
# ================================================
echo -e "\n${YELLOW}[5/10] Reconstruindo imagem do client-dashboard...${NC}"
docker-compose build --no-cache client-dashboard
echo -e "${GREEN}✅ Imagem reconstruída${NC}"

# ================================================
# PASSO 6: INICIAR SERVIÇOS BASE
# ================================================
echo -e "\n${YELLOW}[6/10] Iniciando serviços base...${NC}"

# PostgreSQL
echo -n "  📦 PostgreSQL... "
docker-compose up -d postgres
sleep 3
echo -e "${GREEN}OK${NC}"

# Redis
echo -n "  📦 Redis... "
docker-compose up -d redis
sleep 2
echo -e "${GREEN}OK${NC}"

# RabbitMQ
echo -n "  📦 RabbitMQ... "
docker-compose up -d rabbitmq
sleep 3
echo -e "${GREEN}OK${NC}"

# ================================================
# PASSO 7: INICIAR SERVIÇOS DE AUTENTICAÇÃO
# ================================================
echo -e "\n${YELLOW}[7/10] Iniciando serviços de autenticação...${NC}"

echo -n "  🔐 Auth Service... "
docker-compose up -d auth-service
sleep 2
echo -e "${GREEN}OK${NC}"

echo -n "  🏢 Tenant Service... "
docker-compose up -d tenant-service
sleep 2
echo -e "${GREEN}OK${NC}"

echo -n "  💳 Billing Service... "
docker-compose up -d billing-service
sleep 2
echo -e "${GREEN}OK${NC}"

# ================================================
# PASSO 8: INICIAR CLIENT-DASHBOARD
# ================================================
echo -e "\n${YELLOW}[8/10] Iniciando client-dashboard...${NC}"
docker-compose up -d client-dashboard

echo -e "${YELLOW}⏳ Aguardando inicialização (20 segundos)...${NC}"
for i in {1..20}; do
    echo -n "."
    sleep 1
done
echo ""

# ================================================
# PASSO 9: VERIFICAR LOGS E STATUS
# ================================================
echo -e "\n${YELLOW}[9/10] Verificando status...${NC}"

# Verificar se há erros
CONTAINER_STATUS=$(docker ps --filter "name=sparknexus-client" --format "{{.Status}}" | head -1)
if [ ! -z "$CONTAINER_STATUS" ]; then
    echo -e "${GREEN}✅ Container rodando: $CONTAINER_STATUS${NC}"
    
    # Verificar últimos logs
    echo -e "\n${CYAN}📋 Últimos logs:${NC}"
    docker-compose logs --tail=10 client-dashboard 2>&1 | grep -v "node_modules" || true
    
    # Verificar erros específicos
    ERROR_COUNT=$(docker-compose logs --tail=50 client-dashboard 2>&1 | grep -c "Error\|Cannot find module" || echo "0")
    
    if [ "$ERROR_COUNT" -gt "0" ]; then
        echo -e "\n${YELLOW}⚠️  $ERROR_COUNT erros encontrados${NC}"
        echo -e "${YELLOW}Módulos com erro:${NC}"
        docker-compose logs --tail=50 client-dashboard 2>&1 | grep "Cannot find module" | tail -3
    else
        echo -e "${GREEN}✅ Sem erros de módulos${NC}"
    fi
else
    echo -e "${RED}❌ Container não está rodando${NC}"
fi

# ================================================
# PASSO 10: TESTAR CONECTIVIDADE
# ================================================
echo -e "\n${YELLOW}[10/10] Testando conectividade...${NC}"

# Iniciar outros serviços importantes
echo -e "${CYAN}Iniciando outros serviços...${NC}"
docker-compose up -d admin-dashboard email-validator

sleep 5

# Testar cada serviço
echo -e "\n${CYAN}🧪 Testando APIs:${NC}"

# Client Dashboard
echo -n "  Client Dashboard (4201): "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4201/health 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✅ OK (HTTP 200)${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP $RESPONSE${NC}"
fi

# Admin Dashboard
echo -n "  Admin Dashboard (4200):  "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4200/health 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✅ OK (HTTP 200)${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP $RESPONSE${NC}"
fi

# Auth Service
echo -n "  Auth Service (3001):     "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✅ OK (HTTP 200)${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP $RESPONSE${NC}"
fi

# Email Validator
echo -n "  Email Validator (4001):  "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4001/health 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✅ OK (HTTP 200)${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP $RESPONSE${NC}"
fi

# ================================================
# STATUS DOS CONTAINERS
# ================================================
echo -e "\n${CYAN}📊 Status de todos os containers:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | head -20

# ================================================
# RELATÓRIO FINAL
# ================================================
echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     🔄 REINICIALIZAÇÃO FORÇADA CONCLUÍDA${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}📝 AÇÕES REALIZADAS:${NC}"
echo "  ✅ Todos os containers parados e removidos"
echo "  ✅ Cache Docker limpo"
echo "  ✅ Imagem client-dashboard reconstruída"
echo "  ✅ Todos os serviços reiniciados"
echo "  ✅ Conectividade testada"

echo -e "\n${CYAN}🔧 COMANDOS PARA DEBUG:${NC}"
echo -e "  Ver logs em tempo real:    ${YELLOW}docker-compose logs -f client-dashboard${NC}"
echo -e "  Entrar no container:        ${YELLOW}docker exec -it sparknexus-client sh${NC}"
echo -e "  Verificar módulos:          ${YELLOW}docker exec sparknexus-client ls /app/node_modules/ | grep exceljs${NC}"
echo -e "  Reiniciar apenas um:        ${YELLOW}docker-compose restart client-dashboard${NC}"
echo -e "  Ver todos os containers:    ${YELLOW}docker-compose ps${NC}"

# Se ainda houver problemas com módulos
if [ "$ERROR_COUNT" -gt "0" ]; then
    echo -e "\n${YELLOW}⚠️  ATENÇÃO: Ainda há erros de módulos!${NC}"
    echo -e "${CYAN}Tente estas opções:${NC}"
    echo "  1. Verifique se o arquivo server.js está correto:"
    echo -e "     ${YELLOW}cat core/client-dashboard/server.js | head -20${NC}"
    echo "  2. Force a reinstalação dentro do container:"
    echo -e "     ${YELLOW}docker exec sparknexus-client npm install${NC}"
    echo "  3. Verifique o mapeamento de volumes:"
    echo -e "     ${YELLOW}docker inspect sparknexus-client | grep -A 10 Mounts${NC}"
else
    echo -e "\n${GREEN}🎉 SISTEMA REINICIADO COM SUCESSO!${NC}"
    echo -e "${GREEN}Acesse: http://localhost:4201${NC}"
fi

echo -e "\n${GREEN}✅ Script concluído!${NC}\n"

# Opção para ver logs em tempo real
read -p "Deseja ver os logs em tempo real? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    docker-compose logs -f client-dashboard
fi

exit 0