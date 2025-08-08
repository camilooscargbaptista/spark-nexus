#!/bin/bash

# ================================================
# Script 1: Setup PostgreSQL e Redis
# Spark Nexus - Configuração de Banco de Dados
# ================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🗄️  Setup PostgreSQL e Redis - Spark Nexus${NC}"
echo -e "${BLUE}================================================${NC}"

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Erro: Execute este script no diretório raiz do spark-nexus${NC}"
    exit 1
fi

# ================================================
# 1. ATUALIZAR DOCKER-COMPOSE.YML
# ================================================
echo -e "${YELLOW}📝 Atualizando docker-compose.yml...${NC}"

# Fazer backup do docker-compose atual
cp docker-compose.yml docker-compose.yml.backup

# Criar novo docker-compose com PostgreSQL e Redis configurados
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # ============================================
  # POSTGRESQL - Banco de Dados Principal
  # ============================================
  postgres:
    image: postgres:15-alpine
    container_name: sparknexus-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: sparknexus
      POSTGRES_USER: sparknexus
      POSTGRES_PASSWORD: SparkDB2024!
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=pt_BR.utf8"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./shared/database/init.sql:/docker-entrypoint-initdb.d/01-init.sql
    ports:
      - "5432:5432"
    networks:
      - sparknexus-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sparknexus"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ============================================
  # REDIS - Cache e Filas
  # ============================================
  redis:
    image: redis:7-alpine
    container_name: sparknexus-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass SparkRedis2024!
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

  # ============================================
  # ADMINER - Interface Web para PostgreSQL
  # ============================================
  adminer:
    image: adminer
    container_name: sparknexus-adminer
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      ADMINER_DEFAULT_SERVER: postgres
      ADMINER_DESIGN: pepa-linha-dark
    networks:
      - sparknexus-network
    depends_on:
      - postgres

  # ============================================
  # REDIS COMMANDER - Interface Web para Redis
  # ============================================
  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: sparknexus-redis-commander
    restart: unless-stopped
    environment:
      REDIS_HOSTS: local:redis:6379:0:SparkRedis2024!
    ports:
      - "8081:8081"
    networks:
      - sparknexus-network
    depends_on:
      - redis

  # ============================================
  # RABBITMQ - Message Broker
  # ============================================
  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: sparknexus-rabbitmq
    restart: unless-stopped
    environment:
      RABBITMQ_DEFAULT_USER: sparknexus
      RABBITMQ_DEFAULT_PASS: SparkMQ2024!
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - sparknexus-network

  # ============================================
  # KONG - API Gateway
  # ============================================
  kong:
    image: kong:3.4-alpine
    container_name: sparknexus-kong
    restart: unless-stopped
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /kong/declarative/kong.yml
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_LISTEN: "0.0.0.0:8001"
    ports:
      - "8000:8000"
      - "8001:8001"
    volumes:
      - ./config/kong:/kong/declarative
    networks:
      - sparknexus-network

  # ============================================
  # N8N - Workflow Automation
  # ============================================
  n8n:
    image: n8nio/n8n
    container_name: sparknexus-n8n
    restart: unless-stopped
    environment:
      N8N_BASIC_AUTH_ACTIVE: "true"
      N8N_BASIC_AUTH_USER: admin
      N8N_BASIC_AUTH_PASSWORD: admin123
      N8N_HOST: localhost
      N8N_PORT: 5678
      N8N_PROTOCOL: http
      WEBHOOK_URL: http://localhost:5678/
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: sparknexus
      DB_POSTGRESDB_PASSWORD: SparkDB2024!
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - sparknexus-network
    depends_on:
      - postgres
      - redis

  # ============================================
  # SERVIÇOS CORE
  # ============================================
  
  auth-service:
    build: ./core/auth-service
    container_name: sparknexus-auth
    restart: unless-stopped
    environment:
      NODE_ENV: development
      PORT: 3001
      DATABASE_URL: postgresql://sparknexus:SparkDB2024!@postgres:5432/sparknexus
      REDIS_URL: redis://:SparkRedis2024!@redis:6379
      JWT_SECRET: ${JWT_SECRET:-spark-nexus-jwt-secret-2024}
      JWT_EXPIRY: 24h
    ports:
      - "3001:3001"
    volumes:
      - ./core/auth-service:/app
      - /app/node_modules
    networks:
      - sparknexus-network
    depends_on:
      - postgres
      - redis

  billing-service:
    build: ./core/billing-service
    container_name: sparknexus-billing
    restart: unless-stopped
    environment:
      NODE_ENV: development
      PORT: 3002
      DATABASE_URL: postgresql://sparknexus:SparkDB2024!@postgres:5432/sparknexus
      REDIS_URL: redis://:SparkRedis2024!@redis:6379
      STRIPE_SECRET_KEY: ${STRIPE_SECRET_KEY}
      STRIPE_WEBHOOK_SECRET: ${STRIPE_WEBHOOK_SECRET}
    ports:
      - "3002:3002"
    volumes:
      - ./core/billing-service:/app
      - /app/node_modules
    networks:
      - sparknexus-network
    depends_on:
      - postgres
      - redis

  tenant-service:
    build: ./core/tenant-service
    container_name: sparknexus-tenant
    restart: unless-stopped
    environment:
      NODE_ENV: development
      PORT: 3003
      DATABASE_URL: postgresql://sparknexus:SparkDB2024!@postgres:5432/sparknexus
      REDIS_URL: redis://:SparkRedis2024!@redis:6379
    ports:
      - "3003:3003"
    volumes:
      - ./core/tenant-service:/app
      - /app/node_modules
    networks:
      - sparknexus-network
    depends_on:
      - postgres
      - redis

  # ============================================
  # MÓDULOS
  # ============================================
  
  email-validator-api:
    build: ./modules/email-validator
    container_name: sparknexus-email-validator-api
    restart: unless-stopped
    environment:
      NODE_ENV: development
      PORT: 4001
      DATABASE_URL: postgresql://sparknexus:SparkDB2024!@postgres:5432/sparknexus
      REDIS_URL: redis://:SparkRedis2024!@redis:6379
      RABBITMQ_URL: amqp://sparknexus:SparkMQ2024!@rabbitmq:5672
      HUNTER_API_KEY: ${HUNTER_API_KEY}
    ports:
      - "4001:4001"
    volumes:
      - ./modules/email-validator:/app
      - /app/node_modules
    networks:
      - sparknexus-network
    depends_on:
      - postgres
      - redis
      - rabbitmq

  email-validator-worker:
    build: ./modules/email-validator
    container_name: sparknexus-email-validator-worker
    restart: unless-stopped
    command: npm run worker
    environment:
      NODE_ENV: development
      DATABASE_URL: postgresql://sparknexus:SparkDB2024!@postgres:5432/sparknexus
      REDIS_URL: redis://:SparkRedis2024!@redis:6379
      RABBITMQ_URL: amqp://sparknexus:SparkMQ2024!@rabbitmq:5672
    volumes:
      - ./modules/email-validator:/app
      - /app/node_modules
    networks:
      - sparknexus-network
    depends_on:
      - postgres
      - redis
      - rabbitmq

  # ============================================
  # DASHBOARDS
  # ============================================
  
  admin-dashboard:
    build: ./core/admin-dashboard
    container_name: sparknexus-admin-dashboard
    restart: unless-stopped
    environment:
      NODE_ENV: development
      PORT: 4200
      API_BASE_URL: http://kong:8000
      DATABASE_URL: postgresql://sparknexus:SparkDB2024!@postgres:5432/sparknexus
      REDIS_URL: redis://:SparkRedis2024!@redis:6379
    ports:
      - "4200:4200"
    volumes:
      - ./core/admin-dashboard:/app
      - /app/node_modules
    networks:
      - sparknexus-network
    depends_on:
      - postgres
      - redis
      - kong

  client-dashboard:
    build: ./core/client-dashboard
    container_name: sparknexus-client-dashboard
    restart: unless-stopped
    environment:
      NODE_ENV: development
      PORT: 4201
      API_BASE_URL: http://kong:8000
      DATABASE_URL: postgresql://sparknexus:SparkDB2024!@postgres:5432/sparknexus
      REDIS_URL: redis://:SparkRedis2024!@redis:6379
      JWT_SECRET: ${JWT_SECRET:-spark-nexus-jwt-secret-2024}
      # Email Service
      SMTP_HOST: ${SMTP_HOST}
      SMTP_PORT: ${SMTP_PORT}
      SMTP_USER: ${SMTP_USER}
      SMTP_PASS: ${SMTP_PASS}
      # SMS Service (Twilio)
      TWILIO_ACCOUNT_SID: ${TWILIO_ACCOUNT_SID}
      TWILIO_AUTH_TOKEN: ${TWILIO_AUTH_TOKEN}
      TWILIO_PHONE_NUMBER: ${TWILIO_PHONE_NUMBER}
      # WhatsApp (Twilio)
      TWILIO_WHATSAPP_NUMBER: ${TWILIO_WHATSAPP_NUMBER}
    ports:
      - "4201:4201"
    volumes:
      - ./core/client-dashboard:/app
      - /app/node_modules
      - ./core/client-dashboard/uploads:/app/uploads
    networks:
      - sparknexus-network
    depends_on:
      - postgres
      - redis
      - auth-service

networks:
  sparknexus-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:
  n8n_data:
EOF

# ================================================
# 2. CRIAR SCRIPT DE INICIALIZAÇÃO DO BANCO
# ================================================
echo -e "${YELLOW}📄 Criando script SQL de inicialização...${NC}"

mkdir -p shared/database

cat > shared/database/init.sql << 'EOF'
-- ================================================
-- Spark Nexus - Database Initialization
-- ================================================

-- Criar banco para N8N se não existir
CREATE DATABASE n8n;

-- Conectar ao banco principal
\c sparknexus;

-- Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ================================================
-- SCHEMA: auth (Autenticação)
-- ================================================
CREATE SCHEMA IF NOT EXISTS auth;

-- Tabela de usuários
CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    cpf_cnpj VARCHAR(20) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    company VARCHAR(255) NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    email_verification_token VARCHAR(100),
    phone_verification_token VARCHAR(6),
    email_token_expires TIMESTAMP,
    phone_token_expires TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    is_admin BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de sessões
CREATE TABLE IF NOT EXISTS auth.sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token VARCHAR(500) NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de tentativas de login
CREATE TABLE IF NOT EXISTS auth.login_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45),
    success BOOLEAN DEFAULT FALSE,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================
-- SCHEMA: tenant (Multi-tenancy)
-- ================================================
CREATE SCHEMA IF NOT EXISTS tenant;

-- Tabela de organizações
CREATE TABLE IF NOT EXISTS tenant.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    cnpj VARCHAR(20),
    plan VARCHAR(50) DEFAULT 'free',
    is_active BOOLEAN DEFAULT TRUE,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de membros da organização
CREATE TABLE IF NOT EXISTS tenant.organization_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(organization_id, user_id)
);

-- ================================================
-- SCHEMA: email_validator (Módulo de validação)
-- ================================================
CREATE SCHEMA IF NOT EXISTS email_validator;

-- Tabela de jobs de validação
CREATE TABLE IF NOT EXISTS email_validator.validation_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES tenant.organizations(id),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    status VARCHAR(50) DEFAULT 'pending',
    total_emails INTEGER DEFAULT 0,
    processed_emails INTEGER DEFAULT 0,
    valid_emails INTEGER DEFAULT 0,
    invalid_emails INTEGER DEFAULT 0,
    file_name VARCHAR(255),
    results_file VARCHAR(255),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de resultados de validação
CREATE TABLE IF NOT EXISTS email_validator.validation_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES email_validator.validation_jobs(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    is_valid BOOLEAN,
    score INTEGER,
    checks JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================
-- SCHEMA: billing (Faturamento)
-- ================================================
CREATE SCHEMA IF NOT EXISTS billing;

-- Tabela de planos
CREATE TABLE IF NOT EXISTS billing.plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    credits INTEGER DEFAULT 0,
    features JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de assinaturas
CREATE TABLE IF NOT EXISTS billing.subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES tenant.organizations(id),
    plan_id UUID NOT NULL REFERENCES billing.plans(id),
    stripe_subscription_id VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    current_period_start TIMESTAMP,
    current_period_end TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================
-- INDEXES
-- ================================================
CREATE INDEX idx_users_email ON auth.users(email);
CREATE INDEX idx_users_cpf_cnpj ON auth.users(cpf_cnpj);
CREATE INDEX idx_users_phone ON auth.users(phone);
CREATE INDEX idx_sessions_token ON auth.sessions(token);
CREATE INDEX idx_sessions_user_id ON auth.sessions(user_id);
CREATE INDEX idx_organizations_slug ON tenant.organizations(slug);
CREATE INDEX idx_validation_jobs_org ON email_validator.validation_jobs(organization_id);
CREATE INDEX idx_validation_jobs_user ON email_validator.validation_jobs(user_id);

-- ================================================
-- DEFAULT DATA
-- ================================================

-- Inserir planos padrão
INSERT INTO billing.plans (name, slug, price, credits, features) VALUES
('Free', 'free', 0.00, 100, '{"validations_per_month": 100, "api_access": false}'),
('Starter', 'starter', 29.90, 1000, '{"validations_per_month": 1000, "api_access": true, "priority_support": false}'),
('Professional', 'professional', 99.90, 5000, '{"validations_per_month": 5000, "api_access": true, "priority_support": true}'),
('Enterprise', 'enterprise', 299.90, 999999, '{"validations_per_month": "unlimited", "api_access": true, "priority_support": true, "dedicated_account": true}')
ON CONFLICT (slug) DO NOTHING;

-- Criar organização demo
INSERT INTO tenant.organizations (name, slug, plan) VALUES
('Demo Organization', 'demo', 'free')
ON CONFLICT (slug) DO NOTHING;

-- ================================================
-- FUNCTIONS & TRIGGERS
-- ================================================

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para atualizar updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON tenant.organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Função para validar CPF
CREATE OR REPLACE FUNCTION validate_cpf(cpf VARCHAR) RETURNS BOOLEAN AS $$
DECLARE
    digits VARCHAR;
    sum1 INTEGER := 0;
    sum2 INTEGER := 0;
    i INTEGER;
BEGIN
    -- Remove caracteres não numéricos
    digits := regexp_replace(cpf, '[^0-9]', '', 'g');
    
    -- CPF deve ter 11 dígitos
    IF length(digits) != 11 THEN
        RETURN FALSE;
    END IF;
    
    -- Verifica se todos os dígitos são iguais
    IF digits ~ '^(\d)\1{10}$' THEN
        RETURN FALSE;
    END IF;
    
    -- Calcula primeiro dígito verificador
    FOR i IN 1..9 LOOP
        sum1 := sum1 + (substring(digits, i, 1)::INTEGER * (11 - i));
    END LOOP;
    
    sum1 := 11 - (sum1 % 11);
    IF sum1 >= 10 THEN sum1 := 0; END IF;
    
    -- Verifica primeiro dígito
    IF sum1 != substring(digits, 10, 1)::INTEGER THEN
        RETURN FALSE;
    END IF;
    
    -- Calcula segundo dígito verificador
    FOR i IN 1..10 LOOP
        sum2 := sum2 + (substring(digits, i, 1)::INTEGER * (12 - i));
    END LOOP;
    
    sum2 := 11 - (sum2 % 11);
    IF sum2 >= 10 THEN sum2 := 0; END IF;
    
    -- Verifica segundo dígito
    RETURN sum2 = substring(digits, 11, 1)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Função para validar CNPJ
CREATE OR REPLACE FUNCTION validate_cnpj(cnpj VARCHAR) RETURNS BOOLEAN AS $$
DECLARE
    digits VARCHAR;
    sum INTEGER;
    digit INTEGER;
    i INTEGER;
    weight INTEGER[];
BEGIN
    -- Remove caracteres não numéricos
    digits := regexp_replace(cnpj, '[^0-9]', '', 'g');
    
    -- CNPJ deve ter 14 dígitos
    IF length(digits) != 14 THEN
        RETURN FALSE;
    END IF;
    
    -- Verifica se todos os dígitos são iguais
    IF digits ~ '^(\d)\1{13}$' THEN
        RETURN FALSE;
    END IF;
    
    -- Pesos para cálculo
    weight := ARRAY[6,5,4,3,2,9,8,7,6,5,4,3,2];
    
    -- Calcula primeiro dígito
    sum := 0;
    FOR i IN 1..12 LOOP
        sum := sum + (substring(digits, i, 1)::INTEGER * weight[i+1]);
    END LOOP;
    
    digit := 11 - (sum % 11);
    IF digit >= 10 THEN digit := 0; END IF;
    
    IF digit != substring(digits, 13, 1)::INTEGER THEN
        RETURN FALSE;
    END IF;
    
    -- Calcula segundo dígito
    sum := 0;
    FOR i IN 1..13 LOOP
        sum := sum + (substring(digits, i, 1)::INTEGER * weight[i]);
    END LOOP;
    
    digit := 11 - (sum % 11);
    IF digit >= 10 THEN digit := 0; END IF;
    
    RETURN digit = substring(digits, 14, 1)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Constraint para validar CPF/CNPJ
ALTER TABLE auth.users ADD CONSTRAINT check_cpf_cnpj 
    CHECK (
        (length(regexp_replace(cpf_cnpj, '[^0-9]', '', 'g')) = 11 AND validate_cpf(cpf_cnpj))
        OR 
        (length(regexp_replace(cpf_cnpj, '[^0-9]', '', 'g')) = 14 AND validate_cnpj(cpf_cnpj))
    );

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO sparknexus;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA tenant TO sparknexus;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA email_validator TO sparknexus;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA billing TO sparknexus;
GRANT USAGE ON ALL SCHEMAS TO sparknexus;
EOF

# ================================================
# 3. ATUALIZAR ARQUIVO .ENV
# ================================================
echo -e "${YELLOW}🔐 Atualizando arquivo .env...${NC}"

# Fazer backup do .env atual se existir
if [ -f ".env" ]; then
    cp .env .env.backup
fi

cat > .env << 'EOF'
# ================================================
# Spark Nexus - Environment Variables
# ================================================

# Environment
NODE_ENV=development

# Database
DATABASE_URL=postgresql://sparknexus:SparkDB2024!@localhost:5432/sparknexus
POSTGRES_DB=sparknexus
POSTGRES_USER=sparknexus
POSTGRES_PASSWORD=SparkDB2024!

# Redis
REDIS_URL=redis://:SparkRedis2024!@localhost:6379
REDIS_PASSWORD=SparkRedis2024!

# RabbitMQ
RABBITMQ_URL=amqp://sparknexus:SparkMQ2024!@localhost:5672
RABBITMQ_USER=sparknexus
RABBITMQ_PASSWORD=SparkMQ2024!

# JWT
JWT_SECRET=spark-nexus-jwt-secret-2024-super-secure
JWT_EXPIRY=24h

# Email Service (Gmail)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=seu-email@gmail.com
SMTP_PASS=sua-senha-de-app

# SMS Service (Twilio)
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE_NUMBER=+1234567890
TWILIO_WHATSAPP_NUMBER=whatsapp:+14155238886

# Stripe (Billing)
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# External APIs
HUNTER_API_KEY=your_hunter_api_key

# Ports
AUTH_SERVICE_PORT=3001
BILLING_SERVICE_PORT=3002
TENANT_SERVICE_PORT=3003
EMAIL_VALIDATOR_PORT=4001
ADMIN_DASHBOARD_PORT=4200
CLIENT_DASHBOARD_PORT=4201

# Kong API Gateway
KONG_ADMIN_URL=http://localhost:8001
KONG_PROXY_URL=http://localhost:8000

# N8N
N8N_URL=http://localhost:5678
N8N_USER=admin
N8N_PASSWORD=admin123
EOF

# ================================================
# 4. PARAR CONTAINERS ANTIGOS
# ================================================
echo -e "${YELLOW}🛑 Parando containers antigos...${NC}"
docker-compose down

# ================================================
# 5. LIMPAR VOLUMES ANTIGOS (OPCIONAL)
# ================================================
read -p "Deseja limpar volumes antigos? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🧹 Limpando volumes...${NC}"
    docker volume prune -f
fi

# ================================================
# 6. INICIAR NOVOS CONTAINERS
# ================================================
echo -e "${YELLOW}🚀 Iniciando novos containers...${NC}"
docker-compose up -d postgres redis

# Aguardar PostgreSQL estar pronto
echo -e "${YELLOW}⏳ Aguardando PostgreSQL inicializar...${NC}"
sleep 10

# Verificar se PostgreSQL está rodando
until docker exec sparknexus-postgres pg_isready -U sparknexus; do
    echo "Aguardando PostgreSQL..."
    sleep 2
done

echo -e "${GREEN}✅ PostgreSQL está pronto!${NC}"

# Verificar Redis
docker exec sparknexus-redis redis-cli -a SparkRedis2024! ping
echo -e "${GREEN}✅ Redis está pronto!${NC}"

# ================================================
# 7. EXIBIR INFORMAÇÕES DE ACESSO
# ================================================
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ BANCO DE DADOS CONFIGURADO COM SUCESSO!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}📊 Acessos aos Bancos de Dados:${NC}"
echo -e "   PostgreSQL:"
echo -e "   - Host: ${YELLOW}localhost:5432${NC}"
echo -e "   - Database: ${YELLOW}sparknexus${NC}"
echo -e "   - User: ${YELLOW}sparknexus${NC}"
echo -e "   - Password: ${YELLOW}SparkDB2024!${NC}"
echo -e "   - Adminer: ${GREEN}http://localhost:8080${NC}"
echo ""
echo -e "   Redis:"
echo -e "   - Host: ${YELLOW}localhost:6379${NC}"
echo -e "   - Password: ${YELLOW}SparkRedis2024!${NC}"
echo -e "   - Commander: ${GREEN}http://localhost:8081${NC}"
echo ""
echo -e "${BLUE}📝 Próximo Passo:${NC}"
echo -e "   Execute: ${YELLOW}./02-setup-registration.sh${NC}"
echo ""
echo -e "${YELLOW}⚠️  Não esqueça de configurar as variáveis no .env:${NC}"
echo -e "   - Credenciais do Gmail (SMTP)"
echo -e "   - Credenciais do Twilio (SMS/WhatsApp)"
echo -e "   - Chaves do Stripe (Pagamento)"
EOF

chmod +x 01-setup-database.sh

echo -e "${GREEN}✅ Script 01-setup-database.sh criado!${NC}"