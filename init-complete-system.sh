#!/bin/bash

# ================================================
# SPARK NEXUS - INICIALIZAÇÃO COMPLETA DO SISTEMA
# Senha correta do banco: SparkNexus2024!
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
echo -e "${MAGENTA}     🚀 SPARK NEXUS - INICIALIZAÇÃO COMPLETA${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ================================================
# 1. ATUALIZAR ARQUIVO .ENV
# ================================================
echo -e "${BLUE}[1/8] Atualizando arquivo .env...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Fazer backup do .env
if [ -f .env ]; then
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✅ Backup do .env criado${NC}"
fi

# Criar/Atualizar .env com credenciais corretas
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

echo -e "${GREEN}✅ Arquivo .env atualizado com credenciais corretas${NC}"

# ================================================
# 2. PARAR CONTAINERS EXISTENTES
# ================================================
echo -e "\n${BLUE}[2/8] Parando containers existentes...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

docker-compose down --remove-orphans || true
docker ps -q --filter "name=sparknexus" | xargs -r docker stop 2>/dev/null || true
docker ps -aq --filter "name=sparknexus" | xargs -r docker rm -f 2>/dev/null || true

echo -e "${GREEN}✅ Containers parados e removidos${NC}"

# ================================================
# 3. INICIAR POSTGRESQL
# ================================================
echo -e "\n${BLUE}[3/8] Iniciando PostgreSQL...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

docker-compose up -d postgres

# Aguardar PostgreSQL iniciar
echo -e "${YELLOW}⏳ Aguardando PostgreSQL iniciar...${NC}"
for i in {1..30}; do
    if docker exec sparknexus-postgres pg_isready -U sparknexus &>/dev/null; then
        echo -e "${GREEN}✅ PostgreSQL está pronto!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# ================================================
# 4. CRIAR DATABASES
# ================================================
echo -e "\n${BLUE}[4/8] Criando databases...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar databases necessários
for db in sparknexus sparknexus_core sparknexus_tenants sparknexus_modules n8n; do
    echo -n "Criando database $db... "
    docker exec sparknexus-postgres psql -U sparknexus -c "CREATE DATABASE $db;" 2>/dev/null && echo -e "${GREEN}✅${NC}" || echo -e "${YELLOW}já existe${NC}"
done

# ================================================
# 5. CRIAR TABELAS
# ================================================
echo -e "\n${BLUE}[5/8] Criando estrutura do banco de dados...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar arquivo SQL temporário
cat > /tmp/create_tables.sql << 'EOSQL'
-- ================================================
-- CRIAR SCHEMAS
-- ================================================
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS tenant;
CREATE SCHEMA IF NOT EXISTS modules;

-- ================================================
-- TABELAS DO SCHEMA AUTH
-- ================================================

-- Tabela de usuários
DROP TABLE IF EXISTS auth.users CASCADE;
CREATE TABLE auth.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    cpf_cnpj VARCHAR(20),
    phone VARCHAR(20),
    company VARCHAR(255),
    email_verified BOOLEAN DEFAULT false,
    phone_verified BOOLEAN DEFAULT false,
    email_verification_token VARCHAR(20),
    phone_verification_token VARCHAR(20),
    email_token_expires TIMESTAMP,
    phone_token_expires TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de sessões
DROP TABLE IF EXISTS auth.sessions CASCADE;
CREATE TABLE auth.sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES auth.users(id) ON DELETE CASCADE,
    token VARCHAR(500) UNIQUE NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

-- Tabela de tentativas de login
DROP TABLE IF EXISTS auth.login_attempts CASCADE;
CREATE TABLE auth.login_attempts (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255),
    ip_address VARCHAR(45),
    success BOOLEAN DEFAULT false,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================
-- TABELAS DO SCHEMA TENANT
-- ================================================

-- Tabela de organizações
DROP TABLE IF EXISTS tenant.organizations CASCADE;
CREATE TABLE tenant.organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    plan VARCHAR(50) DEFAULT 'free',
    max_validations INTEGER DEFAULT 1000,
    validations_used INTEGER DEFAULT 0,
    cnpj VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de membros da organização
DROP TABLE IF EXISTS tenant.organization_members CASCADE;
CREATE TABLE tenant.organization_members (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES auth.users(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'member',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(organization_id, user_id)
);

-- ================================================
-- TABELAS DO SCHEMA MODULES
-- ================================================

-- Tabela de validações de email
DROP TABLE IF EXISTS modules.email_validations CASCADE;
CREATE TABLE modules.email_validations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES auth.users(id),
    organization_id INTEGER REFERENCES tenant.organizations(id),
    email VARCHAR(255) NOT NULL,
    is_valid BOOLEAN,
    is_disposable BOOLEAN,
    is_role_based BOOLEAN,
    mx_records_exist BOOLEAN,
    smtp_check_passed BOOLEAN,
    score INTEGER,
    validated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de jobs de validação
DROP TABLE IF EXISTS modules.validation_jobs CASCADE;
CREATE TABLE modules.validation_jobs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES auth.users(id),
    organization_id INTEGER REFERENCES tenant.organizations(id),
    file_name VARCHAR(255),
    total_emails INTEGER,
    processed_emails INTEGER DEFAULT 0,
    valid_emails INTEGER DEFAULT 0,
    invalid_emails INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT 'pending',
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================
-- ÍNDICES
-- ================================================
CREATE INDEX IF NOT EXISTS idx_users_email ON auth.users(email);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON auth.sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON auth.sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_organizations_slug ON tenant.organizations(slug);
CREATE INDEX IF NOT EXISTS idx_validations_email ON modules.email_validations(email);

-- ================================================
-- DADOS INICIAIS
-- ================================================

-- Inserir usuários de teste (senha: Demo@123456)
INSERT INTO auth.users (email, password_hash, first_name, last_name, cpf_cnpj, phone, company, email_verified, phone_verified)
VALUES 
    ('demo@sparknexus.com', '$2a$10$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq', 'Demo', 'User', '11144477735', '11987654321', 'Demo Company', true, true),
    ('girardelibaptista@gmail.com', '$2a$10$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq', 'Camilo', 'Baptista', '01487829645', '11961411709', 'Camilo Oscar Girardelli Baptista', true, true),
    ('contato@sparknexus.com.br', '$2a$10$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq', 'Contato', 'Spark Nexus', '12345678000190', '11999999999', 'Spark Nexus LTDA', true, true)
ON CONFLICT (email) DO NOTHING;

-- Criar organizações
INSERT INTO tenant.organizations (name, slug, plan, max_validations)
VALUES 
    ('Demo Organization', 'demo-org', 'free', 1000),
    ('Spark Nexus', 'spark-nexus', 'premium', 100000),
    ('Camilo Baptista', 'camilo-baptista', 'free', 1000)
ON CONFLICT (slug) DO NOTHING;

-- Associar usuários às organizações
INSERT INTO tenant.organization_members (organization_id, user_id, role)
SELECT o.id, u.id, 'owner'
FROM tenant.organizations o
CROSS JOIN auth.users u
WHERE 
    (o.slug = 'demo-org' AND u.email = 'demo@sparknexus.com') OR
    (o.slug = 'camilo-baptista' AND u.email = 'girardelibaptista@gmail.com') OR
    (o.slug = 'spark-nexus' AND u.email = 'contato@sparknexus.com.br')
ON CONFLICT DO NOTHING;

-- ================================================
-- VERIFICAÇÃO
-- ================================================
SELECT 'Tabelas criadas com sucesso!' as status;

-- Listar schemas
SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('auth', 'tenant', 'modules');

-- Contar tabelas criadas
SELECT COUNT(*) as total_tabelas FROM information_schema.tables 
WHERE table_schema IN ('auth', 'tenant', 'modules');

-- Verificar usuários criados
SELECT email, first_name || ' ' || last_name as nome_completo FROM auth.users;
EOSQL

# Executar SQL
echo -e "${CYAN}Executando SQL...${NC}"
docker cp /tmp/create_tables.sql sparknexus-postgres:/tmp/
docker exec sparknexus-postgres psql -U sparknexus -d sparknexus -f /tmp/create_tables.sql

echo -e "${GREEN}✅ Tabelas criadas com sucesso!${NC}"

# ================================================
# 6. TESTAR CONEXÃO COM O BANCO
# ================================================
echo -e "\n${BLUE}[6/8] Testando conexão com o banco de dados...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Testar conexão básica
echo -e "${CYAN}Testando conexão...${NC}"
if docker exec sparknexus-postgres psql -U sparknexus -d sparknexus -c "SELECT 'Conexão OK!' as status;" &>/dev/null; then
    echo -e "${GREEN}✅ Conexão com PostgreSQL funcionando!${NC}"
else
    echo -e "${RED}❌ Erro na conexão com PostgreSQL${NC}"
    exit 1
fi

# Verificar tabelas criadas
echo -e "\n${CYAN}Verificando tabelas criadas:${NC}"
docker exec sparknexus-postgres psql -U sparknexus -d sparknexus -t -c "
SELECT 
    table_schema || '.' || table_name as tabela
FROM information_schema.tables 
WHERE table_schema IN ('auth', 'tenant', 'modules')
ORDER BY table_schema, table_name;"

# Verificar usuários
echo -e "\n${CYAN}Usuários cadastrados:${NC}"
docker exec sparknexus-postgres psql -U sparknexus -d sparknexus -t -c "
SELECT email || ' - ' || first_name || ' ' || last_name as usuario 
FROM auth.users;"

# ================================================
# 7. INICIAR TODOS OS SERVIÇOS
# ================================================
echo -e "\n${BLUE}[7/8] Iniciando todos os serviços...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Redis
echo -n "Iniciando Redis... "
docker-compose up -d redis && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}"

# RabbitMQ
echo -n "Iniciando RabbitMQ... "
docker-compose up -d rabbitmq && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}"

# Auth Service
echo -n "Iniciando Auth Service... "
docker-compose up -d auth-service && echo -e "${GREEN}✅${NC}" || echo -e "${YELLOW}⚠️${NC}"

# Billing Service
echo -n "Iniciando Billing Service... "
docker-compose up -d billing-service && echo -e "${GREEN}✅${NC}" || echo -e "${YELLOW}⚠️${NC}"

# Tenant Service
echo -n "Iniciando Tenant Service... "
docker-compose up -d tenant-service && echo -e "${GREEN}✅${NC}" || echo -e "${YELLOW}⚠️${NC}"

# Admin Dashboard
echo -n "Iniciando Admin Dashboard... "
docker-compose up -d admin-dashboard && echo -e "${GREEN}✅${NC}" || echo -e "${YELLOW}⚠️${NC}"

# Client Dashboard
echo -n "Iniciando Client Dashboard... "
docker-compose up -d client-dashboard && echo -e "${GREEN}✅${NC}" || echo -e "${YELLOW}⚠️${NC}"

# Email Validator
echo -n "Iniciando Email Validator... "
docker-compose up -d email-validator && echo -e "${GREEN}✅${NC}" || echo -e "${YELLOW}⚠️${NC}"

# N8N
echo -n "Iniciando N8N... "
docker-compose up -d n8n && echo -e "${GREEN}✅${NC}" || echo -e "${YELLOW}⚠️${NC}"

echo -e "\n${YELLOW}⏳ Aguardando serviços iniciarem (20 segundos)...${NC}"
sleep 20

# ================================================
# 8. VERIFICAÇÃO FINAL E TESTES
# ================================================
echo -e "\n${BLUE}[8/8] Verificação final e testes...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Status dos containers
echo -e "\n${CYAN}📊 Status dos Containers:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus || echo "Nenhum container sparknexus encontrado"

# Criar arquivo de teste para Postman/curl
cat > test-api.sh << 'EOTEST'
#!/bin/bash

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🧪 TESTES DA API SPARK NEXUS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# URL base
BASE_URL="http://localhost:4201"

# 1. Teste de Health Check
echo -e "\n${YELLOW}1. Health Check:${NC}"
curl -X GET "$BASE_URL/api/health" \
  -H "Content-Type: application/json" | jq '.' || echo "API não respondeu"

# 2. Teste de Registro (Register)
echo -e "\n${YELLOW}2. Teste de Registro de Novo Usuário:${NC}"
curl -X POST "$BASE_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Teste",
    "lastName": "Usuario",
    "cpfCnpj": "12345678901",
    "email": "teste'$(date +%s)'@example.com",
    "phone": "11999999999",
    "company": "Teste Company",
    "password": "Teste@123456"
  }' | jq '.' || echo "Erro no registro"

# 3. Teste de Login
echo -e "\n${YELLOW}3. Teste de Login:${NC}"
RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "girardelibaptista@gmail.com",
    "password": "Demo@123456"
  }')

echo "$RESPONSE" | jq '.' || echo "$RESPONSE"

# Extrair token se login bem sucedido
TOKEN=$(echo "$RESPONSE" | jq -r '.token' 2>/dev/null)

if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    echo -e "\n${GREEN}✅ Login bem sucedido! Token obtido.${NC}"
    
    # 4. Teste de endpoint autenticado
    echo -e "\n${YELLOW}4. Teste de Endpoint Autenticado:${NC}"
    curl -X GET "$BASE_URL/api/stats" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" | jq '.' || echo "Erro ao acessar stats"
else
    echo -e "\n${YELLOW}⚠️ Login falhou ou token não obtido${NC}"
fi

# 5. Teste de Validação de CPF
echo -e "\n${YELLOW}5. Teste de Validação de CPF:${NC}"
curl -X POST "$BASE_URL/api/validate/cpf-cnpj" \
  -H "Content-Type: application/json" \
  -d '{
    "document": "01487829645"
  }' | jq '.' || echo "Erro na validação"

# 6. Teste de Validação de Email
echo -e "\n${YELLOW}6. Teste de Validação de Email:${NC}"
curl -X POST "$BASE_URL/api/validate/email-format" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "teste@example.com"
  }' | jq '.' || echo "Erro na validação de email"

echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Testes concluídos!${NC}"
EOTEST

chmod +x test-api.sh

# ================================================
# RESULTADO FINAL
# ================================================
clear
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     ✅ SPARK NEXUS - SISTEMA INICIADO COM SUCESSO!${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}🔐 CREDENCIAIS DO BANCO DE DADOS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Host: localhost"
echo "Porta: 5432"
echo "Database: sparknexus"
echo "Usuário: sparknexus"
echo "Senha: SparkNexus2024!"

echo -e "\n${CYAN}🌐 URLS DE ACESSO:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Client Dashboard: http://localhost:4201"
echo "Admin Dashboard: http://localhost:4200"
echo "Email Validator: http://localhost:4001"
echo "Auth Service: http://localhost:3001"
echo "N8N: http://localhost:5678"
echo "RabbitMQ: http://localhost:15672"

echo -e "\n${CYAN}👤 USUÁRIOS DE TESTE:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Email: girardelibaptista@gmail.com"
echo "Senha: Demo@123456"

echo -e "\n${CYAN}🧪 TESTAR APIs:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Execute: ./test-api.sh"

echo -e "\n${CYAN}📝 EXEMPLOS CURL PARA POSTMAN:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}REGISTRO (POST):${NC}"
echo 'curl -X POST "http://localhost:4201/api/auth/register" \'
echo '  -H "Content-Type: application/json" \'
echo '  -d '\''{'
echo '    "firstName": "Novo",'
echo '    "lastName": "Usuario",'
echo '    "cpfCnpj": "12345678901",'
echo '    "email": "novo@example.com",'
echo '    "phone": "11999999999",'
echo '    "company": "Nova Company",'
echo '    "password": "Senha@123456"'
echo '  }'\'''

echo -e "\n${GREEN}LOGIN (POST):${NC}"
echo 'curl -X POST "http://localhost:4201/api/auth/login" \'
echo '  -H "Content-Type: application/json" \'
echo '  -d '\''{'
echo '    "email": "girardelibaptista@gmail.com",'
echo '    "password": "Demo@123456"'
echo '  }'\'''

echo -e "\n${CYAN}📋 VER LOGS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Registro: docker-compose logs -f client-dashboard | grep -i register"
echo "Todos: docker-compose logs -f"

echo -e "\n${MAGENTA}🚀 Sistema pronto para uso!${NC}"
echo -e "${MAGENTA}   DBeaver: localhost:5432 | sparknexus | SparkNexus2024!${NC}"
echo ""

exit 0