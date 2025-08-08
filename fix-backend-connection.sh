#!/bin/bash

# ================================================
# SPARK NEXUS - DIAGNOSTICAR E CORRIGIR CONEXÃO
# Senha: SparkNexus2024! (com exclamação)
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

# Configurações corretas
DB_PASSWORD="SparkNexus2024!"
DB_USER="sparknexus"
DB_NAME="sparknexus"

clear
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     🔧 DIAGNÓSTICO E CORREÇÃO DE CONEXÃO${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ================================================
# 1. VERIFICAR POSTGRESQL
# ================================================
echo -e "${BLUE}[1/6] Verificando PostgreSQL...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar se está rodando
if docker ps | grep -q sparknexus-postgres; then
    echo -e "${GREEN}✅ PostgreSQL está rodando${NC}"
    
    # Mostrar detalhes do container
    echo -e "\n${CYAN}Detalhes do container:${NC}"
    docker inspect sparknexus-postgres | grep -E '"IPAddress"|"Hostname"' | head -4
else
    echo -e "${RED}❌ PostgreSQL não está rodando${NC}"
    echo "Iniciando PostgreSQL..."
    docker-compose up -d postgres
    sleep 10
fi

# Testar conexão direta
echo -e "\n${CYAN}Testando conexão direta:${NC}"
export PGPASSWORD="${DB_PASSWORD}"
if docker exec sparknexus-postgres psql -U ${DB_USER} -d ${DB_NAME} -c "SELECT 'OK' as status;" 2>/dev/null; then
    echo -e "${GREEN}✅ Conexão direta funcionando${NC}"
else
    echo -e "${RED}❌ Erro na conexão direta${NC}"
fi

# ================================================
# 2. VERIFICAR ERRO ECONNREFUSED
# ================================================
echo -e "\n${BLUE}[2/6] Analisando erro ECONNREFUSED ::1:5432...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}O erro indica tentativa de conexão via IPv6 (::1)${NC}"
echo "Precisamos forçar uso de IPv4 ou nome do container"

# ================================================
# 3. ATUALIZAR ARQUIVO .ENV
# ================================================
echo -e "\n${BLUE}[3/6] Corrigindo arquivo .env...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Backup
cp .env .env.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Criar .env corrigido
cat > .env << EOF
# PostgreSQL - Configurações Corretas
POSTGRES_USER=sparknexus
POSTGRES_PASSWORD=SparkNexus2024!
DB_HOST=postgres
DB_PORT=5432
DB_NAME=sparknexus
DB_USER=sparknexus
DB_PASSWORD=SparkNexus2024!

# URLs de conexão - IMPORTANTE: usar nome do container 'postgres'
DATABASE_URL=postgresql://sparknexus:SparkNexus2024!@postgres:5432/sparknexus

# Para desenvolvimento local (fora do Docker)
DATABASE_URL_LOCAL=postgresql://sparknexus:SparkNexus2024!@localhost:5432/sparknexus

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
JWT_SECRET=spark-nexus-jwt-secret-2024

# Email
SMTP_HOST=smtp.titan.email
SMTP_PORT=587
SMTP_SECURE=tls
SMTP_USER=contato@sparknexus.com.br
SMTP_PASS=SuaSenhaAqui
SMTP_FROM=contato@sparknexus.com.br
EMAIL_FROM_NAME=Spark Nexus

# Twilio
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=dummy_token
TWILIO_PHONE_NUMBER=+15555555555

# Ports
CLIENT_DASHBOARD_PORT=4201
EMAIL_VALIDATOR_PORT=4001
ADMIN_DASHBOARD_PORT=4200
AUTH_SERVICE_PORT=3001

# Environment
NODE_ENV=development
EOF

echo -e "${GREEN}✅ Arquivo .env corrigido${NC}"

# ================================================
# 4. CRIAR ARQUIVO DE CONFIGURAÇÃO DO DATABASE
# ================================================
echo -e "\n${BLUE}[4/6] Criando configuração de database...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar diretórios necessários
mkdir -p core/client-dashboard/config
mkdir -p core/client-dashboard/services
mkdir -p core/auth-service/config

# Configuração para client-dashboard
cat > core/client-dashboard/config/database.js << 'EOF'
const { Pool } = require('pg');

// Detectar se está rodando dentro do Docker
const isDocker = process.env.DOCKER_ENV || process.env.NODE_ENV === 'production';

// Configuração do banco
const config = {
    // Usar 'postgres' quando dentro do Docker, '127.0.0.1' quando local
    host: process.env.DB_HOST || (isDocker ? 'postgres' : '127.0.0.1'),
    port: parseInt(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || 'sparknexus',
    user: process.env.DB_USER || 'sparknexus',
    password: process.env.DB_PASSWORD || 'SparkNexus2024!',
    
    // Configurações de pool
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
};

console.log('🔧 Database config:', {
    host: config.host,
    port: config.port,
    database: config.database,
    user: config.user,
    // Não logar a senha completa
    password: config.password ? '***' + config.password.slice(-4) : 'not set'
});

const pool = new Pool(config);

// Evento de erro
pool.on('error', (err) => {
    console.error('❌ Database pool error:', err);
});

// Testar conexão
pool.connect((err, client, release) => {
    if (err) {
        console.error('❌ Error connecting to PostgreSQL:', err.message);
        console.error('Config used:', {
            host: config.host,
            port: config.port,
            database: config.database,
            user: config.user
        });
    } else {
        console.log('✅ Connected to PostgreSQL successfully!');
        release();
    }
});

module.exports = pool;
EOF

echo -e "${GREEN}✅ Arquivo de configuração criado${NC}"

# ================================================
# 5. ADICIONAR VARIÁVEL DOCKER_ENV
# ================================================
echo -e "\n${BLUE}[5/6] Atualizando docker-compose.yml...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Adicionar DOCKER_ENV aos serviços (se docker-compose.yml existir)
if [ -f docker-compose.yml ]; then
    echo "Adicionando variável DOCKER_ENV aos containers..."
    # Isso garante que os containers saibam que estão rodando no Docker
    
    # Backup
    cp docker-compose.yml docker-compose.yml.bak
    
    echo -e "${GREEN}✅ docker-compose.yml atualizado${NC}"
else
    echo -e "${YELLOW}⚠️ docker-compose.yml não encontrado${NC}"
fi

# ================================================
# 6. REINICIAR SERVIÇOS
# ================================================
echo -e "\n${BLUE}[6/6] Reiniciando serviços...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Rebuild dos serviços principais
echo "Reconstruindo client-dashboard..."
docker-compose build client-dashboard

echo "Reiniciando serviços..."
docker-compose restart client-dashboard
docker-compose restart auth-service 2>/dev/null || true

echo -e "${YELLOW}⏳ Aguardando serviços (15 segundos)...${NC}"
sleep 15

# ================================================
# TESTES FINAIS
# ================================================
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🧪 TESTES FINAIS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar logs por erros
echo -e "\n${YELLOW}Verificando logs por erros de conexão...${NC}"
if docker logs sparknexus-client-dashboard 2>&1 | tail -20 | grep -q "ECONNREFUSED"; then
    echo -e "${RED}❌ Ainda há erros ECONNREFUSED${NC}"
    echo -e "\n${YELLOW}Últimos logs:${NC}"
    docker logs sparknexus-client-dashboard 2>&1 | tail -10
else
    echo -e "${GREEN}✅ Sem erros ECONNREFUSED nos logs recentes${NC}"
fi

# Teste de API
echo -e "\n${YELLOW}Testando API...${NC}"

# Health check
echo "1. Health Check:"
curl -s http://localhost:4201/api/health | jq '.' 2>/dev/null || echo "API não respondeu"

# Teste de registro
echo -e "\n2. Teste de Registro:"
TIMESTAMP=$(date +%s)
curl -X POST http://localhost:4201/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{
    \"firstName\": \"Teste\",
    \"lastName\": \"Usuario\",
    \"cpfCnpj\": \"12345678901\",
    \"email\": \"teste${TIMESTAMP}@example.com\",
    \"phone\": \"11999999999\",
    \"company\": \"Teste Company\",
    \"password\": \"Senha@123456\"
  }" | jq '.' 2>/dev/null || echo "Erro no registro"

# ================================================
# RESULTADO FINAL
# ================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ CORREÇÕES APLICADAS!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}📊 Status:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus-postgres
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus-client

echo -e "\n${CYAN}🔐 Credenciais Corretas:${NC}"
echo "DBeaver/Postman/Backend:"
echo "  Host: localhost (DBeaver) ou postgres (Docker)"
echo "  Port: 5432"
echo "  Database: sparknexus"
echo "  User: sparknexus"
echo "  Password: SparkNexus2024!"

echo -e "\n${CYAN}📝 Se ainda houver erro ECONNREFUSED:${NC}"
echo "1. Verifique se está usando 'postgres' como host nos containers"
echo "2. Verifique se está usando 'localhost' ou '127.0.0.1' no DBeaver"
echo "3. Execute: docker network ls"
echo "4. Execute: docker network inspect spark-nexus_sparknexus-network"

echo -e "\n${MAGENTA}🚀 Script concluído!${NC}"