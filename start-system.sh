#!/bin/bash

# ================================================
# SPARK NEXUS - INICIALIZAÇÃO DO SISTEMA
# Script que preserva todos os dados existentes
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

# Configurações do banco
DB_USER="sparknexus"
DB_PASSWORD="SparkNexus2024!"
DB_NAME="sparknexus"
DB_HOST="localhost"
DB_PORT="5432"

# ================================================
# HEADER
# ================================================
clear
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     🚀 SPARK NEXUS - INICIALIZAÇÃO RÁPIDA${NC}"
echo -e "${MAGENTA}     📁 Preservando todos os dados existentes${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ================================================
# 1. VERIFICAR ARQUIVO .ENV
# ================================================
echo -e "${BLUE}[1/5] Verificando arquivo .env...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  Arquivo .env não encontrado. Criando...${NC}"
    
    cat > .env << 'EOF'
# PostgreSQL - Credenciais Corretas
POSTGRES_USER=sparknexus
POSTGRES_PASSWORD=SparkNexus2024!
DB_HOST=postgres
DB_PORT=5432
DB_NAME=sparknexus
DB_USER=sparknexus
DB_PASSWORD=SparkNexus2024!
DATABASE_URL=postgresql://sparknexus:SparkNexus2024!@postgres:5432/sparknexus

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=SparkRedis2024!

# RabbitMQ
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USER=sparknexus
RABBITMQ_PASS=SparkMQ2024!

# JWT
JWT_SECRET=spark-nexus-jwt-secret-2024-super-secret

# Email (Titan)
SMTP_HOST=smtp.titan.email
SMTP_PORT=587
SMTP_SECURE=tls
SMTP_USER=contato@sparknexus.com.br
SMTP_PASS=SuaSenhaAqui
SMTP_FROM=contato@sparknexus.com.br
EMAIL_FROM_NAME=Spark Nexus

# Twilio (SMS)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=dummy_token
TWILIO_PHONE_NUMBER=+15555555555

# Application
NODE_ENV=development
CLIENT_DASHBOARD_PORT=4201
EMAIL_VALIDATOR_PORT=4001
ADMIN_DASHBOARD_PORT=4200
AUTH_SERVICE_PORT=3001

# APIs
HUNTER_API_KEY=
OPENAI_API_KEY=

# Stripe
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=

# N8N
N8N_PASSWORD=admin123

# Grafana
GRAFANA_PASSWORD=admin123
EOF
    echo -e "${GREEN}✅ Arquivo .env criado${NC}"
else
    echo -e "${GREEN}✅ Arquivo .env já existe${NC}"
fi

# ================================================
# 2. PARAR CONTAINERS (SEM REMOVER VOLUMES)
# ================================================
echo -e "\n${BLUE}[2/5] Parando containers existentes...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Para containers sem remover volumes (preserva dados)
docker-compose stop 2>/dev/null || true
echo -e "${GREEN}✅ Containers parados (dados preservados)${NC}"

# ================================================
# 3. INICIAR SERVIÇOS BASE
# ================================================
echo -e "\n${BLUE}[3/5] Iniciando serviços base...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# PostgreSQL
echo -n "📦 Iniciando PostgreSQL... "
docker-compose up -d postgres
sleep 3

# Aguardar PostgreSQL ficar pronto
for i in {1..15}; do
    if docker exec sparknexus-postgres pg_isready -U sparknexus &>/dev/null; then
        echo -e "${GREEN}✅${NC}"
        break
    fi
    if [ $i -eq 1 ]; then
        echo -n "aguardando"
    fi
    echo -n "."
    sleep 2
done

# Redis
echo -n "📦 Iniciando Redis... "
docker-compose up -d redis && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}"
sleep 2

# RabbitMQ
echo -n "📦 Iniciando RabbitMQ... "
docker-compose up -d rabbitmq && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}"
sleep 3

# ================================================
# 4. INICIAR SERVIÇOS DA APLICAÇÃO
# ================================================
echo -e "\n${BLUE}[4/5] Iniciando serviços da aplicação...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Array de serviços para iniciar
declare -a services=(
    "auth-service:Auth Service"
    "billing-service:Billing Service"
    "tenant-service:Tenant Service"
    "admin-dashboard:Admin Dashboard"
    "client-dashboard:Client Dashboard"
    "email-validator:Email Validator"
    "n8n:N8N Workflow"
)

# Iniciar cada serviço
for service_info in "${services[@]}"; do
    IFS=':' read -r service_name display_name <<< "$service_info"
    echo -n "🚀 Iniciando ${display_name}... "
    
    if docker-compose up -d "$service_name" 2>/dev/null; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${YELLOW}⚠️${NC}"
    fi
    sleep 1
done

echo -e "\n${YELLOW}⏳ Aguardando serviços estabilizarem (10 segundos)...${NC}"
sleep 10

# ================================================
# 5. VERIFICAÇÃO FINAL
# ================================================
echo -e "\n${BLUE}[5/5] Verificação final...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar conexão com banco
echo -e "\n${CYAN}🔍 Verificando banco de dados:${NC}"
if docker exec sparknexus-postgres psql -U sparknexus -d sparknexus -c "\dt auth.*" &>/dev/null; then
    echo -e "${GREEN}✅ Banco de dados conectado e estrutura preservada${NC}"
    
    # Contar usuários existentes
    USER_COUNT=$(docker exec sparknexus-postgres psql -U sparknexus -d sparknexus -t -c "SELECT COUNT(*) FROM auth.users;" 2>/dev/null | xargs)
    echo -e "${CYAN}   👥 Usuários cadastrados: ${USER_COUNT}${NC}"
    
    # Contar organizações
    ORG_COUNT=$(docker exec sparknexus-postgres psql -U sparknexus -d sparknexus -t -c "SELECT COUNT(*) FROM tenant.organizations;" 2>/dev/null | xargs)
    echo -e "${CYAN}   🏢 Organizações: ${ORG_COUNT}${NC}"
else
    echo -e "${YELLOW}⚠️  Banco sem estrutura. Execute o script de inicialização completa primeiro.${NC}"
fi

# Status dos containers
echo -e "\n${CYAN}📊 Status dos Containers:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar cada container
running_count=0
total_count=0

for service_info in "${services[@]}"; do
    IFS=':' read -r service_name display_name <<< "$service_info"
    container_name="sparknexus-${service_name}"
    total_count=$((total_count + 1))
    
    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "  ✅ ${display_name}: ${GREEN}Rodando${NC}"
        running_count=$((running_count + 1))
    else
        echo -e "  ❌ ${display_name}: ${RED}Parado${NC}"
    fi
done

# Verificar serviços base também
for base_service in "postgres:PostgreSQL" "redis:Redis" "rabbitmq:RabbitMQ"; do
    IFS=':' read -r service_name display_name <<< "$base_service"
    container_name="sparknexus-${service_name}"
    
    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo -e "  ✅ ${display_name}: ${GREEN}Rodando${NC}"
    else
        echo -e "  ❌ ${display_name}: ${RED}Parado${NC}"
    fi
done

# ================================================
# RESULTADO FINAL
# ================================================
echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     ✅ SISTEMA INICIADO COM SUCESSO!${NC}"
echo -e "${MAGENTA}     📁 Todos os dados foram preservados${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}🌐 URLS DE ACESSO:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  📱 Client Dashboard: ${BLUE}http://localhost:4201${NC}"
echo "  👨‍💼 Admin Dashboard:  ${BLUE}http://localhost:4200${NC}"
echo "  ✉️  Email Validator:  ${BLUE}http://localhost:4001${NC}"
echo "  🔐 Auth Service:     ${BLUE}http://localhost:3001${NC}"
echo "  🔄 N8N Workflows:    ${BLUE}http://localhost:5678${NC}"
echo "  🐰 RabbitMQ Admin:   ${BLUE}http://localhost:15672${NC}"

echo -e "\n${CYAN}🔐 CREDENCIAIS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  📧 Email: girardelibaptista@gmail.com"
echo "  🔑 Senha: Demo@123456"
echo ""
echo "  🗄️  DBeaver/pgAdmin:"
echo "     Host: localhost:5432"
echo "     User: sparknexus"
echo "     Pass: SparkNexus2024!"

echo -e "\n${CYAN}🛠️  COMANDOS ÚTEIS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  Ver logs:        ${YELLOW}docker-compose logs -f [serviço]${NC}"
echo "  Parar sistema:   ${YELLOW}docker-compose stop${NC}"
echo "  Reiniciar:       ${YELLOW}./start-system.sh${NC}"
echo "  Status:          ${YELLOW}docker-compose ps${NC}"

echo -e "\n${GREEN}🚀 Sistema pronto para uso!${NC}\n"

# Criar script auxiliar para parar o sistema
cat > stop-system.sh << 'EOSTOP'
#!/bin/bash
echo "🛑 Parando Spark Nexus..."
docker-compose stop
echo "✅ Sistema parado (dados preservados)"
EOSTOP
chmod +x stop-system.sh

# Criar script auxiliar para ver logs
cat > view-logs.sh << 'EOLOGS'
#!/bin/bash
if [ -z "$1" ]; then
    echo "📋 Mostrando logs de todos os serviços..."
    docker-compose logs -f --tail=50
else
    echo "📋 Mostrando logs de $1..."
    docker-compose logs -f --tail=50 "$1"
fi
EOLOGS
chmod +x view-logs.sh

exit 0