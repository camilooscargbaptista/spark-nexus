#!/bin/bash

# ============================================
# START COMPLETE - Iniciar toda a plataforma
# ============================================

echo "🚀 Iniciando Spark Nexus Platform COMPLETA..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ASCII Art
echo -e "${CYAN}"
cat << "EOF"
   _____                  __      _   __                    
  / ___/____  ____ ______/ /__   / | / /__  _  ____  _______
  \__ \/ __ \/ __ `/ ___/ //_/  /  |/ / _ \| |/_/ / / / ___/
 ___/ / /_/ / /_/ / /  / ,<    / /|  /  __/>  </ /_/ (__  ) 
/____/ .___/\__,_/_/  /_/|_|  /_/ |_/\___/_/|_|\__,_/____/  
    /_/                                                      
EOF
echo -e "${NC}"

# ============================================
# VERIFICAÇÕES INICIAIS
# ============================================

echo -e "${BLUE}🔍 Verificando pré-requisitos...${NC}"

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker não está instalado${NC}"
    exit 1
fi

# Verificar Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose não está instalado${NC}"
    exit 1
fi

# Verificar arquivo docker-compose.fixed.yml
if [ ! -f "docker-compose.fixed.yml" ]; then
    echo -e "${RED}❌ docker-compose.fixed.yml não encontrado${NC}"
    echo "Execute primeiro: ./fix-docker-compose.sh"
    exit 1
fi

echo -e "${GREEN}✅ Pré-requisitos OK${NC}"

# ============================================
# LIMPEZA (OPCIONAL)
# ============================================

echo ""
echo -e "${YELLOW}Deseja limpar containers antigos? (y/n)${NC}"
read -r clean_response

if [ "$clean_response" = "y" ]; then
    echo -e "${BLUE}🧹 Limpando containers antigos...${NC}"
    docker-compose -f docker-compose.fixed.yml down
    sleep 2
fi

# ============================================
# INICIAR INFRAESTRUTURA
# ============================================

echo ""
echo -e "${BLUE}1️⃣  Iniciando Infraestrutura...${NC}"

docker-compose -f docker-compose.fixed.yml up -d postgres redis rabbitmq

# Aguardar PostgreSQL
echo -n "   Aguardando PostgreSQL"
until docker exec sparknexus-postgres pg_isready -U sparknexus 2>/dev/null; do
    echo -n "."
    sleep 2
done
echo -e " ${GREEN}✅${NC}"

# Aguardar Redis
echo -n "   Aguardando Redis"
until docker exec sparknexus-redis redis-cli ping 2>/dev/null | grep -q PONG; do
    echo -n "."
    sleep 1
done
echo -e " ${GREEN}✅${NC}"

# Aguardar RabbitMQ
echo -n "   Aguardando RabbitMQ"
until docker exec sparknexus-rabbitmq rabbitmq-diagnostics ping 2>/dev/null | grep -q "Ping succeeded"; do
    echo -n "."
    sleep 2
done
echo -e " ${GREEN}✅${NC}"

# ============================================
# INICIAR SERVIÇOS CORE
# ============================================

echo ""
echo -e "${BLUE}2️⃣  Iniciando Serviços Core...${NC}"

docker-compose -f docker-compose.fixed.yml up -d auth-service billing-service tenant-service

sleep 3

# Verificar serviços
echo -n "   Auth Service"
if curl -s http://localhost:3001/health > /dev/null 2>&1; then
    echo -e " ${GREEN}✅${NC}"
else
    echo -e " ${YELLOW}⚠️  (iniciando...)${NC}"
fi

echo -n "   Billing Service"
if curl -s http://localhost:3002/health > /dev/null 2>&1; then
    echo -e " ${GREEN}✅${NC}"
else
    echo -e " ${YELLOW}⚠️  (iniciando...)${NC}"
fi

echo -n "   Tenant Service"
if curl -s http://localhost:3003/health > /dev/null 2>&1; then
    echo -e " ${GREEN}✅${NC}"
else
    echo -e " ${YELLOW}⚠️  (iniciando...)${NC}"
fi

# ============================================
# INICIAR MÓDULOS
# ============================================

echo ""
echo -e "${BLUE}3️⃣  Iniciando Módulos...${NC}"

docker-compose -f docker-compose.fixed.yml up -d email-validator

# Se existirem outros módulos, adicionar aqui
if [ -f "modules/crm-connector/Dockerfile" ]; then
    docker-compose -f docker-compose.fixed.yml up -d crm-connector 2>/dev/null
fi

if [ -f "modules/lead-scorer/Dockerfile" ]; then
    docker-compose -f docker-compose.fixed.yml up -d lead-scorer 2>/dev/null
fi

sleep 2

echo -n "   Email Validator"
if curl -s http://localhost:4001/health > /dev/null 2>&1; then
    echo -e " ${GREEN}✅${NC}"
else
    echo -e " ${YELLOW}⚠️  (iniciando...)${NC}"
fi

# ============================================
# INICIAR API GATEWAY E AUTOMAÇÃO
# ============================================

echo ""
echo -e "${BLUE}4️⃣  Iniciando Gateway e Automação...${NC}"

docker-compose -f docker-compose.fixed.yml up -d kong n8n

sleep 3

echo -n "   Kong API Gateway"
if curl -s http://localhost:8000 > /dev/null 2>&1; then
    echo -e " ${GREEN}✅${NC}"
else
    echo -e " ${YELLOW}⚠️  (iniciando...)${NC}"
fi

echo -n "   N8N Automation"
if curl -s http://localhost:5678 > /dev/null 2>&1; then
    echo -e " ${GREEN}✅${NC}"
else
    echo -e " ${YELLOW}⚠️  (iniciando...)${NC}"
fi

# ============================================
# INICIAR FRONTEND DASHBOARDS
# ============================================

echo ""
echo -e "${BLUE}5️⃣  Iniciando Frontend Dashboards...${NC}"

# Verificar se os dashboards existem
if [ ! -f "core/admin-dashboard/Dockerfile" ] || [ ! -f "core/client-dashboard/Dockerfile" ]; then
    echo -e "${YELLOW}   Dashboards não configurados. Executando setup...${NC}"
    if [ -f "setup-frontend.sh" ]; then
        ./setup-frontend.sh
    else
        echo -e "${RED}   setup-frontend.sh não encontrado${NC}"
    fi
else
    # Build e iniciar dashboards
    docker-compose -f docker-compose.fixed.yml build admin-dashboard client-dashboard
    docker-compose -f docker-compose.fixed.yml up -d admin-dashboard client-dashboard
fi

sleep 3

echo -n "   Admin Dashboard"
if curl -s http://localhost:4200 > /dev/null 2>&1; then
    echo -e " ${GREEN}✅${NC}"
else
    echo -e " ${YELLOW}⚠️  (iniciando...)${NC}"
fi

echo -n "   Client Dashboard"
if curl -s http://localhost:4201 > /dev/null 2>&1; then
    echo -e " ${GREEN}✅${NC}"
else
    echo -e " ${YELLOW}⚠️  (iniciando...)${NC}"
fi

# ============================================
# MONITORING (OPCIONAL)
# ============================================

echo ""
echo -e "${YELLOW}Deseja iniciar o monitoramento (Prometheus + Grafana)? (y/n)${NC}"
read -r monitoring_response

if [ "$monitoring_response" = "y" ]; then
    echo -e "${BLUE}6️⃣  Iniciando Monitoramento...${NC}"
    docker-compose -f docker-compose.fixed.yml --profile monitoring up -d
    
    sleep 3
    
    echo -n "   Prometheus"
    if curl -s http://localhost:9090 > /dev/null 2>&1; then
        echo -e " ${GREEN}✅${NC}"
    else
        echo -e " ${YELLOW}⚠️  (iniciando...)${NC}"
    fi
    
    echo -n "   Grafana"
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo -e " ${GREEN}✅${NC}"
    else
        echo -e " ${YELLOW}⚠️  (iniciando...)${NC}"
    fi
fi

# ============================================
# RESUMO FINAL
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 SPARK NEXUS PLATFORM - INICIADO COM SUCESSO!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Listar todos os containers rodando
echo -e "${CYAN}📦 Containers Ativos:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus

echo ""
echo -e "${CYAN}🌐 URLs de Acesso:${NC}"
echo ""
echo -e "${YELLOW}Frontend:${NC}"
echo "  📊 Admin Dashboard:    http://localhost:4200"
echo "  📱 Client Dashboard:   http://localhost:4201"
echo ""
echo -e "${YELLOW}APIs:${NC}"
echo "  🔐 Auth Service:       http://localhost:3001/health"
echo "  💳 Billing Service:    http://localhost:3002/health"
echo "  🏢 Tenant Service:     http://localhost:3003/health"
echo "  📧 Email Validator:    http://localhost:4001/health"
echo "  🌐 API Gateway:        http://localhost:8000"
echo ""
echo -e "${YELLOW}Ferramentas:${NC}"
echo "  🔄 N8N Workflows:      http://localhost:5678 (admin/admin123)"
echo "  📬 RabbitMQ:          http://localhost:15672 (sparknexus/SparkMQ2024!)"

if [ "$monitoring_response" = "y" ]; then
    echo ""
    echo -e "${YELLOW}Monitoramento:${NC}"
    echo "  📊 Prometheus:        http://localhost:9090"
    echo "  📈 Grafana:           http://localhost:3000 (admin/admin123)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}💡 Comandos Úteis:${NC}"
echo ""
echo "  Ver logs de um serviço:"
echo "    docker-compose -f docker-compose.fixed.yml logs -f [nome-do-serviço]"
echo ""
echo "  Parar toda a plataforma:"
echo "    docker-compose -f docker-compose.fixed.yml down"
echo ""
echo "  Ver estatísticas:"
echo "    docker stats"
echo ""
echo "  Testar serviços:"
echo "    ./test-all.sh"
echo ""
echo -e "${GREEN}🚀 Plataforma pronta para uso!${NC}"
echo ""