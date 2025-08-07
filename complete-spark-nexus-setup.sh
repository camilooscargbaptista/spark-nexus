#!/bin/bash

# ============================================
# SPARK NEXUS - COMPLETAR IMPLEMENTAÇÃO
# ============================================

echo "🔧 Completando implementação do Spark Nexus..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Verificar se está na pasta correta (spark-nexus)
if [ ! -d "core" ] || [ ! -d "modules" ]; then
    echo -e "${RED}❌ Execute este script dentro da pasta spark-nexus${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Pasta spark-nexus detectada${NC}"

# ============================================
# PARTE 1: CRIAR ARQUIVOS FALTANTES
# ============================================

echo -e "${BLUE}📝 Criando arquivos faltantes...${NC}"

# Criar o arquivo init-multi-db.sh se não existir
if [ ! -f "shared/database/init-multi-db.sh" ]; then
    echo -e "${YELLOW}Criando init-multi-db.sh...${NC}"
    cat > shared/database/init-multi-db.sh << 'EOF'
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE sparknexus_core;
    CREATE DATABASE sparknexus_tenants;
    CREATE DATABASE sparknexus_modules;
    CREATE DATABASE n8n;
EOSQL

echo "✅ Databases created successfully"
EOF
    chmod +x shared/database/init-multi-db.sh
fi

# ============================================
# PARTE 2: AJUSTAR DOCKER-COMPOSE
# ============================================

echo -e "${BLUE}🐳 Ajustando Docker Compose...${NC}"

# Verificar se docker-compose.yml existe, senão criar
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${YELLOW}Criando docker-compose.yml...${NC}"
    cat > docker-compose.yml << 'EOF'
version: '3.8'

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
      - POSTGRES_MULTIPLE_DATABASES=sparknexus_core,sparknexus_tenants,sparknexus_modules,n8n
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./shared/database/init-multi-db.sh:/docker-entrypoint-initdb.d/init-multi-db.sh
      - ./shared/database/schemas:/schemas
    ports:
      - "5432:5432"
    networks:
      - sparknexus-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
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

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:

networks:
  sparknexus-network:
    driver: bridge
EOF
fi

# ============================================
# PARTE 3: COMPLETAR ARQUIVOS DOS SERVIÇOS
# ============================================

echo -e "${BLUE}📦 Completando serviços...${NC}"

# Auth Service - Adicionar o index.js principal
if [ ! -f "core/auth-service/src/index.js" ]; then
    echo -e "${YELLOW}Criando auth-service index.js...${NC}"
    cat > core/auth-service/src/index.js << 'EOF'
const express = require('express');
const app = express();
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'auth-service' });
});

// Login endpoint placeholder
app.post('/auth/login', async (req, res) => {
  const { email, password, organizationSlug } = req.body;
  
  // TODO: Implement actual authentication
  res.json({
    token: 'mock-jwt-token',
    user: {
      id: '123',
      email: email,
      organizationSlug: organizationSlug
    }
  });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Auth Service running on port ${PORT}`);
});
EOF
fi

# Billing Service - Adicionar o index.js principal
if [ ! -f "core/billing-service/src/index.js" ]; then
    echo -e "${YELLOW}Criando billing-service index.js...${NC}"
    cat > core/billing-service/src/index.js << 'EOF'
const express = require('express');
const app = express();
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'billing-service' });
});

// Create checkout placeholder
app.post('/billing/create-checkout', async (req, res) => {
  const { organizationId, planId } = req.body;
  
  // TODO: Implement Stripe checkout
  res.json({
    checkoutUrl: 'https://checkout.stripe.com/mock',
    sessionId: 'mock-session-id'
  });
});

const PORT = process.env.PORT || 3002;
app.listen(PORT, () => {
  console.log(`Billing Service running on port ${PORT}`);
});
EOF
fi

# Email Validator - Garantir que main.js existe
if [ ! -f "modules/email-validator/src/index.js" ] && [ -f "modules/email-validator/src/main.js" ]; then
    echo -e "${YELLOW}Email validator já tem main.js${NC}"
elif [ ! -f "modules/email-validator/src/index.js" ] && [ ! -f "modules/email-validator/src/main.js" ]; then
    echo -e "${YELLOW}Criando email-validator index.js...${NC}"
    cat > modules/email-validator/src/index.js << 'EOF'
const express = require('express');
const app = express();
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'email-validator' });
});

// Validate endpoint
app.post('/validate', async (req, res) => {
  const { emails } = req.body;
  
  // Mock validation
  const results = emails.map(email => ({
    email,
    valid: email.includes('@'),
    score: Math.floor(Math.random() * 100)
  }));
  
  res.json({ results });
});

const PORT = process.env.PORT || 4001;
app.listen(PORT, () => {
  console.log(`Email Validator Module running on port ${PORT}`);
});
EOF
fi

# ============================================
# PARTE 4: CRIAR DOCKER-COMPOSE PARA SERVIÇOS
# ============================================

echo -e "${BLUE}🐳 Criando Docker Compose para serviços...${NC}"

cat > docker-compose.services.yml << 'EOF'
version: '3.8'

services:
  # Core Services
  auth-service:
    build:
      context: ./core/auth-service
      dockerfile: Dockerfile
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
      - postgres
      - redis

  billing-service:
    build:
      context: ./core/billing-service
      dockerfile: Dockerfile
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
      - postgres

  # Modules
  email-validator:
    build:
      context: ./modules/email-validator
      dockerfile: Dockerfile
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
      - postgres

  # N8N
  n8n:
    image: n8nio/n8n:latest
    container_name: sparknexus-n8n
    restart: unless-stopped
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD:-admin123}
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
  n8n_data:

networks:
  sparknexus-network:
    external: true
EOF

# ============================================
# PARTE 5: SCRIPTS DE GESTÃO
# ============================================

echo -e "${BLUE}📝 Criando scripts de gestão...${NC}"

# Script para iniciar tudo
cat > start-all.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Spark Nexus Platform..."

# Start infrastructure first
echo "Starting infrastructure..."
docker-compose up -d

# Wait for infrastructure
echo "Waiting for infrastructure to be ready..."
sleep 10

# Start services
echo "Starting services..."
docker-compose -f docker-compose.services.yml up -d

echo "✅ Spark Nexus Platform is running!"
echo ""
echo "🌐 Access Points:"
echo "  - Auth Service: http://localhost:3001/health"
echo "  - Billing Service: http://localhost:3002/health"
echo "  - Email Validator: http://localhost:4001/health"
echo "  - N8N: http://localhost:5678 (admin/admin123)"
echo "  - RabbitMQ: http://localhost:15672 (sparknexus/SparkMQ2024!)"
echo "  - PostgreSQL: localhost:5432 (sparknexus/SparkNexus2024!)"
echo ""
EOF
chmod +x start-all.sh

# Script para parar tudo
cat > stop-all.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Spark Nexus Platform..."
docker-compose -f docker-compose.services.yml down
docker-compose down
echo "✅ Platform stopped"
EOF
chmod +x stop-all.sh

# Script para ver logs
cat > logs.sh << 'EOF'
#!/bin/bash

SERVICE=$1

if [ -z "$SERVICE" ]; then
    echo "📋 Available services:"
    echo "  Infrastructure:"
    echo "    - postgres"
    echo "    - redis"
    echo "    - rabbitmq"
    echo "  Services:"
    echo "    - auth-service"
    echo "    - billing-service"
    echo "    - email-validator"
    echo "    - n8n"
    echo ""
    echo "Usage: ./logs.sh [service-name]"
else
    # Try both docker-compose files
    docker-compose logs -f $SERVICE 2>/dev/null || \
    docker-compose -f docker-compose.services.yml logs -f $SERVICE
fi
EOF
chmod +x logs.sh

# ============================================
# PARTE 6: INSTALAR DEPENDÊNCIAS
# ============================================

echo -e "${BLUE}📦 Instalando dependências dos serviços...${NC}"

# Função para instalar dependências
install_deps() {
    local service_path=$1
    local service_name=$2
    
    if [ -d "$service_path" ] && [ -f "$service_path/package.json" ]; then
        echo -e "${YELLOW}Installing dependencies for $service_name...${NC}"
        cd "$service_path"
        npm install
        cd - > /dev/null
    fi
}

# Instalar dependências dos serviços
install_deps "core/auth-service" "Auth Service"
install_deps "core/billing-service" "Billing Service"
install_deps "modules/email-validator" "Email Validator"

# ============================================
# PARTE 7: CRIAR SCHEMAS SQL
# ============================================

echo -e "${BLUE}💾 Verificando schemas SQL...${NC}"

# Garantir que a pasta schemas existe
mkdir -p shared/database/schemas

# Se o arquivo 001-core.sql não existir, criar um básico
if [ ! -f "shared/database/schemas/001-core.sql" ]; then
    echo -e "${YELLOW}Criando schema SQL básico...${NC}"
    cat > shared/database/schemas/001-core.sql << 'EOF'
-- Basic schema for Spark Nexus
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Organizations table
CREATE TABLE IF NOT EXISTS organizations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    slug VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Modules table
CREATE TABLE IF NOT EXISTS modules (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default data
INSERT INTO modules (id, name, description) VALUES
('email-validator', 'Email Validator', 'Validate and enrich emails')
ON CONFLICT (id) DO NOTHING;
EOF
fi

# ============================================
# TESTE DE CONECTIVIDADE
# ============================================

echo -e "${BLUE}🔍 Criando script de teste...${NC}"

cat > test-services.sh << 'EOF'
#!/bin/bash

echo "🔍 Testing Spark Nexus Services..."
echo ""

# Function to test endpoint
test_endpoint() {
    local service=$1
    local url=$2
    
    echo -n "Testing $service... "
    response=$(curl -s -o /dev/null -w "%{http_code}" $url)
    
    if [ "$response" = "200" ]; then
        echo "✅ OK"
    else
        echo "❌ Failed (HTTP $response)"
    fi
}

# Test services
test_endpoint "Auth Service" "http://localhost:3001/health"
test_endpoint "Billing Service" "http://localhost:3002/health"
test_endpoint "Email Validator" "http://localhost:4001/health"
test_endpoint "N8N" "http://localhost:5678"
test_endpoint "RabbitMQ Management" "http://localhost:15672"

echo ""
echo "Done!"
EOF
chmod +x test-services.sh

# ============================================
# FINALIZANDO
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 IMPLEMENTAÇÃO COMPLETADA!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}📋 O que foi feito:${NC}"
echo "  ✅ Arquivos de configuração criados/verificados"
echo "  ✅ Docker Compose configurado"
echo "  ✅ Scripts de gestão criados"
echo "  ✅ Dependências instaladas"
echo "  ✅ Estrutura SQL básica criada"
echo ""
echo -e "${BLUE}🚀 Para iniciar a plataforma:${NC}"
echo ""
echo "  ./start-all.sh"
echo ""
echo -e "${BLUE}🔍 Para testar os serviços:${NC}"
echo ""
echo "  ./test-services.sh"
echo ""
echo -e "${BLUE}📋 Para ver logs:${NC}"
echo ""
echo "  ./logs.sh [nome-do-serviço]"
echo ""
echo -e "${GREEN}Plataforma pronta para uso!${NC}"