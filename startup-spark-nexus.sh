#!/bin/bash

# ================================================
# SPARK NEXUS - SCRIPT COMPLETO DE INICIALIZAÇÃO
# Inicializa todo o sistema e cria estrutura se necessário
# ================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ================================================
# FUNÇÕES AUXILIARES
# ================================================

print_header() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}     🚀 SPARK NEXUS - SISTEMA DE VALIDAÇÃO DE EMAILS${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker não está rodando!${NC}"
        echo "Por favor, inicie o Docker Desktop e execute novamente."
        exit 1
    fi
    echo -e "${GREEN}✅ Docker está rodando${NC}"
}

wait_for_postgres() {
    echo -e "${YELLOW}⏳ Aguardando PostgreSQL iniciar...${NC}"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec sparknexus-postgres pg_isready -U sparknexus > /dev/null 2>&1; then
            echo -e "${GREEN}✅ PostgreSQL está pronto!${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}❌ PostgreSQL não iniciou a tempo${NC}"
    return 1
}

# ================================================
# INÍCIO DO SCRIPT
# ================================================

clear
print_header

echo -e "${CYAN}Inicializando Spark Nexus...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ================================================
# 1. VERIFICAR DOCKER
# ================================================
echo -e "\n${BLUE}[Etapa 1/10] Verificando Docker${NC}"
check_docker

# ================================================
# 2. LIMPAR E CORRIGIR DOCKER-COMPOSE
# ================================================
echo -e "\n${BLUE}[Etapa 2/10] Preparando ambiente${NC}"

# Remover atributo version obsoleto
if grep -q "^version:" docker-compose.yml 2>/dev/null; then
    echo "Removendo atributo 'version' obsoleto..."
    sed -i.bak '/^version:/d' docker-compose.yml
fi

# Corrigir imagem do Kong se necessário
if grep -q "kong:.*-alpine" docker-compose.yml 2>/dev/null; then
    echo "Corrigindo imagem do Kong..."
    sed -i.bak 's/kong:.*-alpine/kong:3.4/g' docker-compose.yml
fi

echo -e "${GREEN}✅ Ambiente preparado${NC}"

# ================================================
# 3. PARAR CONTAINERS EXISTENTES
# ================================================
echo -e "\n${BLUE}[Etapa 3/10] Limpando containers antigos${NC}"
docker-compose down --remove-orphans 2>/dev/null || true
echo -e "${GREEN}✅ Containers antigos removidos${NC}"

# ================================================
# 4. INICIAR SERVIÇOS ESSENCIAIS
# ================================================
echo -e "\n${BLUE}[Etapa 4/10] Iniciando serviços essenciais${NC}"

echo "Iniciando PostgreSQL..."
docker-compose up -d postgres

echo "Iniciando Redis..."
docker-compose up -d redis

echo "Iniciando RabbitMQ..."
docker-compose up -d rabbitmq

# Aguardar PostgreSQL
wait_for_postgres

# ================================================
# 5. CRIAR E CONFIGURAR DATABASE
# ================================================
echo -e "\n${BLUE}[Etapa 5/10] Configurando banco de dados${NC}"

# Verificar se database existe
DB_EXISTS=$(docker exec sparknexus-postgres psql -U sparknexus -tAc "SELECT 1 FROM pg_database WHERE datname='sparknexus'" 2>/dev/null || echo "0")

if [ "$DB_EXISTS" != "1" ]; then
    echo "Criando database sparknexus..."
    docker exec sparknexus-postgres createdb -U sparknexus sparknexus
    echo -e "${GREEN}✅ Database criado${NC}"
else
    echo -e "${GREEN}✅ Database já existe${NC}"
fi

# Criar estrutura do banco
echo "Criando estrutura do banco..."
docker exec sparknexus-postgres psql -U sparknexus -d sparknexus << 'EOSQL'
-- ================================================
-- SCHEMAS
-- ================================================
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS tenant;
CREATE SCHEMA IF NOT EXISTS modules;

-- ================================================
-- TABELAS AUTH
-- ================================================
CREATE TABLE IF NOT EXISTS auth.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
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

CREATE TABLE IF NOT EXISTS auth.sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES auth.users(id) ON DELETE CASCADE,
    token VARCHAR(500) UNIQUE NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS auth.login_attempts (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255),
    ip_address VARCHAR(45),
    success BOOLEAN DEFAULT false,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================================================
-- TABELAS TENANT
-- ================================================
CREATE TABLE IF NOT EXISTS tenant.organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    plan VARCHAR(50) DEFAULT 'free',
    max_validations INTEGER DEFAULT 1000,
    validations_used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tenant.organization_members (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES auth.users(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'member',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(organization_id, user_id)
);

-- ================================================
-- TABELAS MODULES
-- ================================================
CREATE TABLE IF NOT EXISTS modules.email_validations (
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

CREATE TABLE IF NOT EXISTS modules.validation_jobs (
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
CREATE INDEX IF NOT EXISTS idx_validations_user ON modules.email_validations(user_id);

-- ================================================
-- DADOS INICIAIS
-- ================================================

-- Inserir usuários de teste (senha: Demo@123456)
INSERT INTO auth.users (
    email, 
    password_hash, 
    first_name, 
    last_name, 
    cpf_cnpj, 
    phone, 
    company,
    email_verified,
    phone_verified
) VALUES 
(
    'demo@sparknexus.com',
    '$2a$10$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq',
    'Demo',
    'User',
    '11144477735',
    '11987654321',
    'Demo Company',
    true,
    true
),
(
    'girardelibaptista@gmail.com',
    '$2a$10$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq',
    'Camilo',
    'Baptista',
    '01487829645',
    '11961411709',
    'Camilo Oscar Girardelli Baptista',
    true,
    true
),
(
    'contato@sparknexus.com.br',
    '$2a$10$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq',
    'Contato',
    'Spark Nexus',
    '12345678000190',
    '11999999999',
    'Spark Nexus LTDA',
    true,
    true
)
ON CONFLICT (email) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    email_verified = true,
    phone_verified = true;

-- Criar organizações
INSERT INTO tenant.organizations (name, slug, plan, max_validations)
VALUES 
    ('Demo Organization', 'demo-org', 'free', 1000),
    ('Spark Nexus', 'spark-nexus', 'premium', 100000),
    ('Camilo Baptista', 'camilo-baptista', 'free', 1000)
ON CONFLICT (slug) DO NOTHING;

-- Associar usuários às organizações
INSERT INTO tenant.organization_members (organization_id, user_id, role)
SELECT o.id, u.id, 
    CASE 
        WHEN u.email = 'demo@sparknexus.com' THEN 'owner'
        WHEN u.email = 'girardelibaptista@gmail.com' THEN 'owner'
        WHEN u.email = 'contato@sparknexus.com.br' THEN 'admin'
        ELSE 'member'
    END
FROM tenant.organizations o
CROSS JOIN auth.users u
WHERE 
    (o.slug = 'demo-org' AND u.email = 'demo@sparknexus.com') OR
    (o.slug = 'camilo-baptista' AND u.email = 'girardelibaptista@gmail.com') OR
    (o.slug = 'spark-nexus' AND u.email IN ('contato@sparknexus.com.br', 'girardelibaptista@gmail.com'))
ON CONFLICT DO NOTHING;

-- Verificar dados criados
SELECT 'Usuários criados:' as info;
SELECT email, first_name || ' ' || last_name as nome, cpf_cnpj, email_verified 
FROM auth.users;

SELECT 'Organizações criadas:' as info;
SELECT name, slug, plan, max_validations 
FROM tenant.organizations;

EOSQL

echo -e "${GREEN}✅ Banco de dados configurado${NC}"

# ================================================
# 6. CONFIGURAR VARIÁVEIS DE AMBIENTE
# ================================================
echo -e "\n${BLUE}[Etapa 6/10] Configurando variáveis de ambiente${NC}"

# Verificar se .env existe, senão criar
if [ ! -f .env ]; then
    cat > .env << 'EOENV'
# Database
DB_HOST=postgres
DB_PORT=5432
DB_NAME=sparknexus
DB_USER=sparknexus
DB_PASSWORD=SparkNexus2024

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# RabbitMQ
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USER=guest
RABBITMQ_PASS=guest

# JWT
JWT_SECRET=spark-nexus-jwt-secret-2024

# Email (Titan)
SMTP_HOST=smtp.titan.email
SMTP_PORT=587
SMTP_SECURE=tls
SMTP_USER=contato@sparknexus.com.br
SMTP_PASS=SuaSenhaAqui
SMTP_FROM=contato@sparknexus.com.br
EMAIL_FROM_NAME=Spark Nexus

# Twilio (SMS) - Dummy values
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=dummy_token
TWILIO_PHONE_NUMBER=+15555555555

# Application
NODE_ENV=development
CLIENT_DASHBOARD_PORT=4201
EMAIL_VALIDATOR_PORT=4200
ADMIN_DASHBOARD_PORT=4202
AUTH_SERVICE_PORT=4203

# URLs
APP_URL=http://localhost:4201
API_URL=http://localhost:4200
EOENV
    echo -e "${GREEN}✅ Arquivo .env criado${NC}"
else
    echo -e "${GREEN}✅ Arquivo .env já existe${NC}"
fi

# ================================================
# 7. INICIAR SERVIÇOS DE AUTENTICAÇÃO
# ================================================
echo -e "\n${BLUE}[Etapa 7/10] Iniciando serviços de autenticação${NC}"

if docker-compose config --services | grep -q "auth-service"; then
    docker-compose up -d auth-service
    echo -e "${GREEN}✅ Auth Service iniciado${NC}"
fi

if docker-compose config --services | grep -q "auth"; then
    docker-compose up -d auth
    echo -e "${GREEN}✅ Auth iniciado${NC}"
fi

# ================================================
# 8. INICIAR APLICAÇÕES PRINCIPAIS
# ================================================
echo -e "\n${BLUE}[Etapa 8/10] Iniciando aplicações${NC}"

# Email Validator API
if docker-compose config --services | grep -q "email-validator-api"; then
    docker-compose up -d email-validator-api
    echo -e "${GREEN}✅ Email Validator API iniciado${NC}"
fi

# Email Validator Worker
if docker-compose config --services | grep -q "email-validator-worker"; then
    docker-compose up -d email-validator-worker 2>/dev/null || echo -e "${YELLOW}⚠️ Worker pode estar com problemas${NC}"
fi

# Client Dashboard
if docker-compose config --services | grep -q "client-dashboard"; then
    docker-compose up -d client-dashboard
    echo -e "${GREEN}✅ Client Dashboard iniciado${NC}"
fi

# Admin Dashboard
if docker-compose config --services | grep -q "admin-dashboard"; then
    docker-compose up -d admin-dashboard
    echo -e "${GREEN}✅ Admin Dashboard iniciado${NC}"
fi

# Tenant Service
if docker-compose config --services | grep -q "tenant-service"; then
    docker-compose up -d tenant-service
    echo -e "${GREEN}✅ Tenant Service iniciado${NC}"
fi

# Billing Service
if docker-compose config --services | grep -q "billing-service"; then
    docker-compose up -d billing-service
    echo -e "${GREEN}✅ Billing Service iniciado${NC}"
fi

# ================================================
# 9. INICIAR SERVIÇOS ADMINISTRATIVOS
# ================================================
echo -e "\n${BLUE}[Etapa 9/10] Iniciando ferramentas administrativas${NC}"

# Adminer
if docker-compose config --services | grep -q "adminer"; then
    docker-compose up -d adminer
    echo -e "${GREEN}✅ Adminer (PostgreSQL Admin) iniciado${NC}"
fi

# Redis Commander
if docker-compose config --services | grep -q "redis-commander"; then
    docker-compose up -d redis-commander
    echo -e "${GREEN}✅ Redis Commander iniciado${NC}"
fi

# N8N
if docker-compose config --services | grep -q "n8n"; then
    docker-compose up -d n8n
    echo -e "${GREEN}✅ N8N iniciado${NC}"
fi

# Kong (opcional)
if docker-compose config --services | grep -q "kong"; then
    docker-compose up -d kong 2>/dev/null || echo -e "${YELLOW}⚠️ Kong não iniciado (opcional)${NC}"
fi

echo -e "${YELLOW}⏳ Aguardando todos os serviços iniciarem (20 segundos)...${NC}"
sleep 20

# ================================================
# 10. VERIFICAR STATUS E MOSTRAR RESULTADO
# ================================================
echo -e "\n${BLUE}[Etapa 10/10] Verificando status final${NC}"

echo -e "\n${CYAN}📊 Status dos Containers:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus || echo "Nenhum container sparknexus encontrado"

# Criar arquivo de teste de emails
if [ ! -f "test-emails.csv" ]; then
    cat > test-emails.csv << 'EOF'
email,name,company
contato@sparknexus.com.br,Contato Principal,Spark Nexus
girardelibaptista@gmail.com,Camilo Baptista,Camilo Baptista
demo@sparknexus.com,Demo User,Demo Company
teste@gmail.com,Teste Gmail,Test Company
invalid-email,Email Invalido,Test Company
admin@example.com,Admin User,Example Corp
info@google.com,Google Info,Google
support@microsoft.com,MS Support,Microsoft
hello@world.com,Hello World,World Inc
test@test.com,Test User,Test Inc
EOF
    echo -e "${GREEN}✅ Arquivo test-emails.csv criado${NC}"
fi

# ================================================
# RESULTADO FINAL
# ================================================

clear
print_header

echo -e "${GREEN}✅ SISTEMA SPARK NEXUS INICIADO COM SUCESSO!${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}                    🌐 URLS DE ACESSO${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}📤 Upload de Emails:${NC}      http://localhost:4201/upload"
echo -e "${GREEN}📊 Client Dashboard:${NC}      http://localhost:4201"
echo -e "${GREEN}🔐 Login:${NC}                 http://localhost:4201/login"
echo -e "${GREEN}📝 Registro:${NC}              http://localhost:4201/register"
echo -e "${GREEN}📧 API de Validação:${NC}      http://localhost:4200"
echo -e "${GREEN}🔧 Admin Dashboard:${NC}       http://localhost:4202"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}                 🔧 FERRAMENTAS ADMIN${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}🐘 PostgreSQL Admin:${NC}      http://localhost:8080"
echo "   └─ User: sparknexus | Pass: SparkNexus2024"
echo -e "${GREEN}🔴 Redis Commander:${NC}       http://localhost:8081"
echo -e "${GREEN}🐰 RabbitMQ:${NC}              http://localhost:15672"
echo "   └─ User: guest | Pass: guest"
echo -e "${GREEN}🔄 N8N Automation:${NC}        http://localhost:5678"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}                   👤 USUÁRIOS DE TESTE${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Usuário 1 (Demo):${NC}"
echo "  📧 Email: demo@sparknexus.com"
echo "  🔐 Senha: Demo@123456"
echo ""
echo -e "${YELLOW}Usuário 2 (Seu):${NC}"
echo "  📧 Email: girardelibaptista@gmail.com"
echo "  🔐 Senha: Demo@123456"
echo ""
echo -e "${YELLOW}Usuário 3 (Empresa):${NC}"
echo "  📧 Email: contato@sparknexus.com.br"
echo "  🔐 Senha: Demo@123456"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}                    📝 COMANDOS ÚTEIS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Ver logs:${NC}           docker-compose logs -f [serviço]"
echo -e "${GREEN}Status:${NC}             docker ps | grep sparknexus"
echo -e "${GREEN}Parar tudo:${NC}         docker-compose down"
echo -e "${GREEN}Reiniciar:${NC}          ./startup-spark-nexus.sh"
echo -e "${GREEN}Testar email:${NC}       node test-titan-email.js"
echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}           🚀 Sistema pronto para uso!${NC}"
echo -e "${MAGENTA}     Acesse: http://localhost:4201/upload${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Abrir no navegador se for macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Abrindo navegador em 3 segundos...${NC}"
    sleep 3
    open "http://localhost:4201"
fi

# Salvar log
echo "[$(date)] Spark Nexus iniciado com sucesso" >> spark-nexus-startup.log

exit 0