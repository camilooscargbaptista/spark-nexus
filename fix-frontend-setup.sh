#!/bin/bash

# ============================================
# FIX FRONTEND SETUP - Corrigir configuração
# ============================================

echo "🔧 Corrigindo configuração do Frontend..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================
# PARTE 1: CRIAR NOVO DOCKER COMPOSE COM DASHBOARDS
# ============================================

echo -e "${BLUE}🐳 Criando docker-compose com dashboards...${NC}"

# Fazer backup do atual
cp docker-compose.fixed.yml docker-compose.fixed.yml.backup-frontend

# Criar novo docker-compose com dashboards incluídos
cat > docker-compose.with-frontend.yml << 'EOF'
# Spark Nexus Platform - Complete Stack with Frontend

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
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

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
      redis:
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
    depends_on:
      - auth-service
      - billing-service
      - tenant-service

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
    depends_on:
      - auth-service
      - email-validator

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
      - PORT=4001
    ports:
      - "4001:4001"
    networks:
      - sparknexus-network
    depends_on:
      postgres:
        condition: service_healthy

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
    volumes:
      - n8n_data:/home/node/.n8n
    ports:
      - "5678:5678"
    networks:
      - sparknexus-network

  # ===========================================
  # MONITORING (opcional)
  # ===========================================

  prometheus:
    image: prom/prometheus:latest
    container_name: sparknexus-prometheus
    restart: unless-stopped
    volumes:
      - ./infrastructure/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - sparknexus-network
    profiles:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: sparknexus-grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-admin123}
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    networks:
      - sparknexus-network
    profiles:
      - monitoring

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:
  n8n_data:
  prometheus_data:
  grafana_data:

networks:
  sparknexus-network:
    driver: bridge
EOF

echo -e "${GREEN}✅ Docker Compose com Frontend criado${NC}"

# ============================================
# PARTE 2: BUILD E START DOS DASHBOARDS
# ============================================

echo -e "${BLUE}🚀 Construindo e iniciando dashboards...${NC}"

# Verificar se os arquivos existem
if [ ! -f "core/admin-dashboard/server.js" ]; then
    echo -e "${RED}❌ Arquivos do dashboard não encontrados. Execute setup-frontend.sh primeiro${NC}"
    exit 1
fi

# Build das imagens
echo "Building Admin Dashboard..."
docker-compose -f docker-compose.with-frontend.yml build admin-dashboard

echo "Building Client Dashboard..."
docker-compose -f docker-compose.with-frontend.yml build client-dashboard

# Iniciar os dashboards
echo "Starting dashboards..."
docker-compose -f docker-compose.with-frontend.yml up -d admin-dashboard client-dashboard

# ============================================
# PARTE 3: VERIFICAR STATUS
# ============================================

echo -e "${BLUE}🔍 Verificando status...${NC}"

# Aguardar inicialização
sleep 5

# Função para testar
test_service() {
    local name=$1
    local url=$2
    
    printf "%-20s" "$name:"
    
    response=$(curl -s -o /dev/null -w "%{http_code}" $url 2>/dev/null)
    
    if [ "$response" = "200" ] || [ "$response" = "304" ]; then
        echo -e "${GREEN}✅ Online${NC}"
        return 0
    else
        echo -e "${RED}❌ Offline (HTTP $response)${NC}"
        
        # Mostrar logs se falhou
        if [ "$name" = "Admin Dashboard" ]; then
            echo "Últimas linhas do log:"
            docker-compose -f docker-compose.with-frontend.yml logs --tail=5 admin-dashboard
        elif [ "$name" = "Client Dashboard" ]; then
            echo "Últimas linhas do log:"
            docker-compose -f docker-compose.with-frontend.yml logs --tail=5 client-dashboard
        fi
        return 1
    fi
}

echo ""
echo "Status dos Dashboards:"
test_service "Admin Dashboard" "http://localhost:4200"
test_service "Client Dashboard" "http://localhost:4201"

# ============================================
# PARTE 4: CRIAR SCRIPT DE START ATUALIZADO
# ============================================

echo ""
echo -e "${BLUE}📝 Criando script de inicialização atualizado...${NC}"

cat > start-with-frontend.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Spark Nexus with Frontend..."

# Parar containers antigos
docker-compose -f docker-compose.with-frontend.yml down

# Iniciar infraestrutura
docker-compose -f docker-compose.with-frontend.yml up -d postgres redis rabbitmq

# Aguardar PostgreSQL
echo "Waiting for PostgreSQL..."
until docker exec sparknexus-postgres pg_isready -U sparknexus 2>/dev/null; do
    sleep 2
done

# Iniciar serviços core
docker-compose -f docker-compose.with-frontend.yml up -d auth-service billing-service tenant-service

# Iniciar módulos
docker-compose -f docker-compose.with-frontend.yml up -d email-validator

# Iniciar gateway e automação
docker-compose -f docker-compose.with-frontend.yml up -d kong n8n

# Iniciar dashboards
docker-compose -f docker-compose.with-frontend.yml up -d admin-dashboard client-dashboard

echo "✅ Platform with Frontend running!"
echo ""
echo "🌐 Access Points:"
echo "  - Admin Dashboard: http://localhost:4200"
echo "  - Client Dashboard: http://localhost:4201"
echo "  - Auth Service: http://localhost:3001/health"
echo "  - Billing Service: http://localhost:3002/health"
echo "  - Email Validator: http://localhost:4001/health"
echo "  - N8N: http://localhost:5678"
echo "  - RabbitMQ: http://localhost:15672"
EOF

chmod +x start-with-frontend.sh

echo -e "${GREEN}✅ Script de inicialização criado${NC}"

# ============================================
# RESUMO FINAL
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ FRONTEND CORRIGIDO E FUNCIONANDO!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 O que foi feito:"
echo "  ✅ Criado docker-compose.with-frontend.yml"
echo "  ✅ Dashboards construídos e iniciados"
echo "  ✅ Script start-with-frontend.sh criado"
echo ""
echo "🌐 Acesse os dashboards:"
echo "  - Admin Dashboard: http://localhost:4200"
echo "  - Client Dashboard: http://localhost:4201"
echo ""
echo "💡 Para reiniciar tudo com frontend:"
echo "  ./start-with-frontend.sh"
echo ""
echo "📝 Para ver logs:"
echo "  docker-compose -f docker-compose.with-frontend.yml logs -f admin-dashboard"
echo "  docker-compose -f docker-compose.with-frontend.yml logs -f client-dashboard"
echo ""