#!/bin/bash

# ============================================
# FIX DOCKER COMPOSE ISSUES
# ============================================

echo "🔧 Corrigindo problemas no Docker Compose..."

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. Backup do arquivo atual
if [ -f "docker-compose.complete.yml" ]; then
    cp docker-compose.complete.yml docker-compose.complete.yml.backup
    echo -e "${GREEN}✅ Backup criado: docker-compose.complete.yml.backup${NC}"
fi

# 2. Corrigir a versão do Kong no docker-compose.complete.yml
echo -e "${BLUE}Corrigindo imagem do Kong...${NC}"

# Se o arquivo existe, substituir a versão do Kong
if [ -f "docker-compose.complete.yml" ]; then
    # Mac/BSD sed vs GNU sed
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' 's/kong:3.4-alpine/kong:latest/g' docker-compose.complete.yml
        # Remover a linha version se existir
        sed -i '' '/^version:/d' docker-compose.complete.yml
    else
        # Linux
        sed -i 's/kong:3.4-alpine/kong:latest/g' docker-compose.complete.yml
        # Remover a linha version se existir
        sed -i '/^version:/d' docker-compose.complete.yml
    fi
    echo -e "${GREEN}✅ Imagem do Kong corrigida para kong:latest${NC}"
fi

# 3. Criar um docker-compose.fixed.yml com todas as correções
echo -e "${BLUE}Criando docker-compose.fixed.yml com todas as correções...${NC}"

cat > docker-compose.fixed.yml << 'EOF'
# Spark Nexus Platform - Complete Stack
# Removida a versão para evitar warning

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
  # API GATEWAY - Usando Kong mais estável
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
      - "8000:8000"  # Proxy
      - "8001:8001"  # Admin API
    networks:
      - sparknexus-network

  # ===========================================
  # CORE SERVICES - Com build context correto
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
  # MONITORING (com profile para ser opcional)
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

echo -e "${GREEN}✅ docker-compose.fixed.yml criado${NC}"

# 4. Criar configuração básica do Kong
echo -e "${BLUE}Criando configuração do Kong...${NC}"

mkdir -p infrastructure

cat > infrastructure/kong.yml << 'EOF'
_format_version: "3.0"

services:
  - name: auth-service
    url: http://auth-service:3001
    routes:
      - name: auth-route
        paths:
          - /auth
        strip_path: true

  - name: billing-service
    url: http://billing-service:3002
    routes:
      - name: billing-route
        paths:
          - /billing
        strip_path: true

  - name: tenant-service
    url: http://tenant-service:3003
    routes:
      - name: tenant-route
        paths:
          - /tenant
        strip_path: true

  - name: email-validator
    url: http://email-validator:4001
    routes:
      - name: email-validator-route
        paths:
          - /modules/email-validator
        strip_path: true

plugins:
  - name: cors
    config:
      origins:
        - http://localhost:4200
        - http://localhost:4201
      methods:
        - GET
        - POST
        - PUT
        - DELETE
        - OPTIONS
      headers:
        - Accept
        - Accept-Version
        - Content-Length
        - Content-MD5
        - Content-Type
        - Date
        - X-Auth-Token
        - X-Api-Key
      credentials: true

  - name: rate-limiting
    config:
      second: 10
      hour: 1000
      policy: local
EOF

echo -e "${GREEN}✅ Kong configurado${NC}"

# 5. Criar script de start mais robusto
echo -e "${BLUE}Criando script de inicialização melhorado...${NC}"

cat > start-safe.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Spark Nexus (Safe Mode)..."

# Parar containers antigos
echo "Limpando containers antigos..."
docker-compose -f docker-compose.fixed.yml down 2>/dev/null

# Iniciar apenas infraestrutura primeiro
echo "Iniciando infraestrutura..."
docker-compose -f docker-compose.fixed.yml up -d postgres redis rabbitmq

# Aguardar PostgreSQL estar pronto
echo "Aguardando PostgreSQL..."
until docker exec sparknexus-postgres pg_isready -U sparknexus 2>/dev/null; do
    echo -n "."
    sleep 2
done
echo " ✅"

# Iniciar serviços core
echo "Iniciando serviços core..."
docker-compose -f docker-compose.fixed.yml up -d auth-service billing-service tenant-service

# Iniciar módulos
echo "Iniciando módulos..."
docker-compose -f docker-compose.fixed.yml up -d email-validator

# Iniciar gateway e automação
echo "Iniciando gateway e automação..."
docker-compose -f docker-compose.fixed.yml up -d kong n8n

echo ""
echo "✅ Plataforma iniciada com sucesso!"
echo ""
echo "🌐 Serviços disponíveis:"
echo "  - Auth Service: http://localhost:3001/health"
echo "  - Billing Service: http://localhost:3002/health"
echo "  - Tenant Service: http://localhost:3003/health"
echo "  - Email Validator: http://localhost:4001/health"
echo "  - API Gateway: http://localhost:8000"
echo "  - N8N: http://localhost:5678"
echo "  - RabbitMQ: http://localhost:15672"
echo ""
echo "Para ver logs: docker-compose -f docker-compose.fixed.yml logs -f [service-name]"
echo "Para parar: docker-compose -f docker-compose.fixed.yml down"
EOF

chmod +x start-safe.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ CORREÇÕES APLICADAS!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Problemas corrigidos:"
echo "  ✅ Imagem do Kong atualizada para 'kong:latest'"
echo "  ✅ Removido atributo 'version' obsoleto"
echo "  ✅ Adicionados health checks"
echo "  ✅ Kong configurado em modo declarativo"
echo "  ✅ Criado script de inicialização seguro"
echo ""
echo -e "${YELLOW}🚀 Para iniciar a plataforma:${NC}"
echo ""
echo "  ./start-safe.sh"
echo ""
echo "ou se preferir usar o arquivo corrigido diretamente:"
echo ""
echo "  docker-compose -f docker-compose.fixed.yml up -d"
echo ""
EOF

chmod +x fix-docker-compose.sh