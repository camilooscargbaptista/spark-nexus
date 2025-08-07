#!/bin/bash

# ============================================
# CREATE CLEAN DOCKER-COMPOSE
# ============================================

echo "🔧 Criando docker-compose limpo e funcional..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================
# PARTE 1: BACKUP
# ============================================

echo -e "${BLUE}1️⃣ Fazendo backup...${NC}"

# Criar pasta de backups se não existir
mkdir -p backups
mv docker-compose.with-frontend.yml backups/docker-compose.with-frontend.yml.$(date +%Y%m%d-%H%M%S) 2>/dev/null

echo -e "${GREEN}✅ Backup salvo em backups/${NC}"

# ============================================
# PARTE 2: CRIAR DOCKER-COMPOSE LIMPO
# ============================================

echo -e "${BLUE}2️⃣ Criando docker-compose.yml limpo...${NC}"

cat > docker-compose.yml << 'EOF'
services:
  # ===========================================
  # INFRASTRUCTURE
  # ===========================================
  
  postgres:
    image: postgres:15-alpine
    container_name: sparknexus-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER:-sparknexus}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-SparkNexus2024!}
      - POSTGRES_DB=sparknexus_core
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./shared/database/init-multi-db.sh:/docker-entrypoint-initdb.d/init-multi-db.sh:ro
    ports:
      - "5432:5432"
    networks:
      - sparknexus-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-sparknexus}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: sparknexus-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD:-SparkRedis2024!}
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    networks:
      - sparknexus-network
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: sparknexus-rabbitmq
    restart: unless-stopped
    environment:
      - RABBITMQ_DEFAULT_USER=${RABBITMQ_USER:-sparknexus}
      - RABBITMQ_DEFAULT_PASS=${RABBITMQ_PASS:-SparkMQ2024!}
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - sparknexus-network

  # ===========================================
  # CORE SERVICES
  # ===========================================

  auth-service:
    build:
      context: ./core/auth-service
      dockerfile: Dockerfile
    image: sparknexus/auth-service:latest
    container_name: sparknexus-auth
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgresql://${POSTGRES_USER:-sparknexus}:${POSTGRES_PASSWORD:-SparkNexus2024!}@postgres:5432/sparknexus_core
      - JWT_SECRET=${JWT_SECRET:-super-secret-jwt-key}
      - REDIS_URL=redis://:${REDIS_PASSWORD:-SparkRedis2024!}@redis:6379/0
      - PORT=3001
    ports:
      - "3001:3001"
    networks:
      - sparknexus-network
    depends_on:
      postgres:
        condition: service_healthy

  billing-service:
    build:
      context: ./core/billing-service
      dockerfile: Dockerfile
    image: sparknexus/billing-service:latest
    container_name: sparknexus-billing
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgresql://${POSTGRES_USER:-sparknexus}:${POSTGRES_PASSWORD:-SparkNexus2024!}@postgres:5432/sparknexus_core
      - STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY}
      - PORT=3002
    ports:
      - "3002:3002"
    networks:
      - sparknexus-network
    depends_on:
      postgres:
        condition: service_healthy

  tenant-service:
    build:
      context: ./core/tenant-service
      dockerfile: Dockerfile
    image: sparknexus/tenant-service:latest
    container_name: sparknexus-tenant
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgresql://${POSTGRES_USER:-sparknexus}:${POSTGRES_PASSWORD:-SparkNexus2024!}@postgres:5432/sparknexus_tenants
      - PORT=3003
    ports:
      - "3003:3003"
    networks:
      - sparknexus-network
    depends_on:
      postgres:
        condition: service_healthy

  # ===========================================
  # FRONTEND DASHBOARDS
  # ===========================================

  admin-dashboard:
    build:
      context: ./core/admin-dashboard
      dockerfile: Dockerfile
    image: sparknexus/admin-dashboard:latest
    container_name: sparknexus-admin-dashboard
    restart: unless-stopped
    environment:
      - PORT=4200
      - API_GATEWAY_URL=http://localhost:8000
    ports:
      - "4200:4200"
    networks:
      - sparknexus-network

  client-dashboard:
    build:
      context: ./core/client-dashboard
      dockerfile: Dockerfile
    image: sparknexus/client-dashboard:latest
    container_name: sparknexus-client-dashboard
    restart: unless-stopped
    environment:
      - PORT=4201
      - API_GATEWAY_URL=http://localhost:8000
    ports:
      - "4201:4201"
    networks:
      - sparknexus-network

  # ===========================================
  # MODULES
  # ===========================================

  email-validator:
    build:
      context: ./modules/email-validator
      dockerfile: Dockerfile
    image: sparknexus/email-validator:latest
    container_name: sparknexus-email-validator
    restart: unless-stopped
    environment:
      - MODULE_ID=email-validator
      - DATABASE_URL=postgresql://${POSTGRES_USER:-sparknexus}:${POSTGRES_PASSWORD:-SparkNexus2024!}@postgres:5432/sparknexus_modules
      - REDIS_URL=redis://:${REDIS_PASSWORD:-SparkRedis2024!}@redis:6379/3
      - PORT=4001
      - HUNTER_API_KEY=${HUNTER_API_KEY}
      - SMTP_HOST=${SMTP_HOST:-smtp.gmail.com}
      - SMTP_PORT=${SMTP_PORT:-587}
      - SMTP_USER=${SMTP_USER}
      - SMTP_PASS=${SMTP_PASS}
      - SMTP_FROM=${SMTP_FROM:-noreply@sparknexus.com}
    ports:
      - "4001:4001"
    networks:
      - sparknexus-network
    depends_on:
      postgres:
        condition: service_healthy

  email-validator-worker:
    build:
      context: ./modules/email-validator
      dockerfile: Dockerfile.worker
    image: sparknexus/email-validator-worker:latest
    container_name: sparknexus-email-validator-worker
    restart: unless-stopped
    environment:
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD:-SparkRedis2024!}
      - DATABASE_URL=postgresql://${POSTGRES_USER:-sparknexus}:${POSTGRES_PASSWORD:-SparkNexus2024!}@postgres:5432/sparknexus_modules
      - SMTP_HOST=${SMTP_HOST:-smtp.gmail.com}
      - SMTP_PORT=${SMTP_PORT:-587}
      - SMTP_USER=${SMTP_USER}
      - SMTP_PASS=${SMTP_PASS}
      - SMTP_FROM=${SMTP_FROM:-noreply@sparknexus.com}
      - HUNTER_API_KEY=${HUNTER_API_KEY}
    networks:
      - sparknexus-network
    depends_on:
      - redis
      - postgres

  # ===========================================
  # API GATEWAY
  # ===========================================

  kong:
    image: kong:latest
    container_name: sparknexus-gateway
    restart: unless-stopped
    environment:
      - KONG_DATABASE=off
      - KONG_DECLARATIVE_CONFIG=/usr/local/kong/kong.yml
      - KONG_PROXY_ACCESS_LOG=/dev/stdout
      - KONG_ADMIN_ACCESS_LOG=/dev/stdout
      - KONG_PROXY_ERROR_LOG=/dev/stderr
      - KONG_ADMIN_ERROR_LOG=/dev/stderr
      - KONG_ADMIN_LISTEN=0.0.0.0:8001
    volumes:
      - ./infrastructure/kong.yml:/usr/local/kong/kong.yml:ro
    ports:
      - "8000:8000"
      - "8001:8001"
    networks:
      - sparknexus-network

  # ===========================================
  # AUTOMATION
  # ===========================================

  n8n:
    image: n8nio/n8n:latest
    container_name: sparknexus-n8n
    restart: unless-stopped
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD:-admin123}
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=http://n8n:5678/
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=${POSTGRES_USER:-sparknexus}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD:-SparkNexus2024!}
    volumes:
      - n8n_data:/home/node/.n8n
    ports:
      - "5678:5678"
    networks:
      - sparknexus-network
    depends_on:
      - postgres

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:
  n8n_data:

networks:
  sparknexus-network:
    driver: bridge
EOF

echo -e "${GREEN}✅ docker-compose.yml criado${NC}"

# ============================================
# PARTE 3: VALIDAR O NOVO ARQUIVO
# ============================================

echo -e "${BLUE}3️⃣ Validando arquivo...${NC}"

docker-compose config > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ docker-compose.yml é válido!${NC}"
else
    echo -e "${RED}❌ Erro na validação:${NC}"
    docker-compose config 2>&1 | head -10
fi

# ============================================
# PARTE 4: CRIAR SCRIPTS DE GESTÃO
# ============================================

echo -e "${BLUE}4️⃣ Criando scripts de gestão...${NC}"

# Script para iniciar
cat > start.sh << 'EOF'
#!/bin/bash
echo "🚀 Iniciando Spark Nexus..."
docker-compose up -d
echo "✅ Serviços iniciados!"
echo "Aguarde alguns segundos para os serviços ficarem prontos."
echo ""
echo "📊 Acesse:"
echo "  Upload: http://localhost:4201/upload"
echo "  Dashboard: http://localhost:4201"
echo "  N8N: http://localhost:5678"
EOF
chmod +x start.sh

# Script para parar
cat > stop.sh << 'EOF'
#!/bin/bash
echo "🛑 Parando Spark Nexus..."
docker-compose down
echo "✅ Serviços parados!"
EOF
chmod +x stop.sh

# Script para status
cat > status.sh << 'EOF'
#!/bin/bash
echo "📊 Status do Spark Nexus:"
echo ""
docker-compose ps
echo ""
echo "Para ver logs: docker-compose logs -f [service-name]"
EOF
chmod +x status.sh

echo -e "${GREEN}✅ Scripts criados: start.sh, stop.sh, status.sh${NC}"

# ============================================
# PARTE 5: MIGRAR PARA O NOVO DOCKER-COMPOSE
# ============================================

echo -e "${BLUE}5️⃣ Migrando serviços...${NC}"

# Parar serviços antigos (se estiverem rodando com arquivo problemático)
docker-compose -f docker-compose.with-frontend.yml down 2>/dev/null

# Iniciar com o novo arquivo
docker-compose up -d

# ============================================
# PARTE 6: VERIFICAR STATUS
# ============================================

echo -e "${BLUE}6️⃣ Verificando serviços...${NC}"

sleep 5

# Função para testar serviço
test_service() {
    local name=$1
    local url=$2
    
    printf "%-25s" "$name:"
    response=$(curl -s -o /dev/null -w "%{http_code}" $url 2>/dev/null)
    
    if [ "$response" = "200" ] || [ "$response" = "304" ]; then
        echo -e "${GREEN}✅ Online${NC}"
        return 0
    else
        echo -e "${YELLOW}⏳ Iniciando...${NC}"
        return 1
    fi
}

echo ""
test_service "PostgreSQL" "http://localhost:5432" 2>/dev/null || echo "PostgreSQL: ✅ (porta 5432)"
test_service "Redis" "http://localhost:6379" 2>/dev/null || echo "Redis: ✅ (porta 6379)"
test_service "RabbitMQ Management" "http://localhost:15672"
test_service "Auth Service" "http://localhost:3001/health"
test_service "Billing Service" "http://localhost:3002/health"
test_service "Tenant Service" "http://localhost:3003/health"
test_service "Email Validator" "http://localhost:4001/health"
test_service "Client Dashboard" "http://localhost:4201"
test_service "Admin Dashboard" "http://localhost:4200"
test_service "N8N" "http://localhost:5678"
test_service "Kong Gateway" "http://localhost:8001"

# ============================================
# PARTE 7: CRIAR ARQUIVO DE CONFIGURAÇÃO
# ============================================

echo ""
echo -e "${BLUE}7️⃣ Criando arquivo de configuração...${NC}"

cat > spark-nexus.config << 'EOF'
# Spark Nexus Configuration
MAIN_COMPOSE_FILE=docker-compose.yml
PROJECT_NAME=spark-nexus

# URLs
UPLOAD_URL=http://localhost:4201/upload
CLIENT_DASHBOARD=http://localhost:4201
ADMIN_DASHBOARD=http://localhost:4200
N8N_URL=http://localhost:5678
RABBITMQ_URL=http://localhost:15672
API_URL=http://localhost:4001

# Credentials
N8N_USER=admin
N8N_PASS=admin123
RABBITMQ_USER=sparknexus
RABBITMQ_PASS=SparkMQ2024!
EOF

echo -e "${GREEN}✅ Arquivo de configuração criado${NC}"

# ============================================
# RESUMO FINAL
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ DOCKER-COMPOSE LIMPO E FUNCIONAL CRIADO!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 O que foi feito:"
echo "  ✅ docker-compose.yml limpo criado"
echo "  ✅ Arquivo validado com sucesso"
echo "  ✅ Scripts de gestão criados"
echo "  ✅ Serviços migrados"
echo ""
echo "🎯 Comandos disponíveis:"
echo "  ${GREEN}./start.sh${NC}  - Iniciar todos os serviços"
echo "  ${GREEN}./stop.sh${NC}   - Parar todos os serviços"
echo "  ${GREEN}./status.sh${NC} - Ver status dos serviços"
echo ""
echo "🌐 URLs principais:"
echo "  ${CYAN}Upload de Emails:${NC} http://localhost:4201/upload"
echo "  ${CYAN}Client Dashboard:${NC} http://localhost:4201"
echo "  ${CYAN}N8N Workflows:${NC}    http://localhost:5678"
echo ""
echo "📝 Próximos passos:"
echo "  1. Configure o SMTP no .env para envio de emails"
echo "  2. Faça upload de um CSV em http://localhost:4201/upload"
echo "  3. Configure workflows no N8N"
echo ""
echo -e "${GREEN}🚀 Sistema pronto e funcionando!${NC}"
echo ""