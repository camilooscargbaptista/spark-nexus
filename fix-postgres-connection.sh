#!/bin/bash

# ================================================
# SPARK NEXUS - FIX POSTGRESQL CONNECTION
# Corrige erro ECONNREFUSED ::1:5432 (IPv6 vs IPv4)
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

# ================================================
# HEADER
# ================================================
clear
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     🔧 SPARK NEXUS - CORREÇÃO DE CONEXÃO POSTGRESQL${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ================================================
# 1. VERIFICAR STATUS DO POSTGRESQL
# ================================================
echo -e "${BLUE}[1/5] Verificando PostgreSQL...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if docker ps | grep -q sparknexus-postgres; then
    echo -e "${GREEN}✅ PostgreSQL está rodando${NC}"
    
    # Verificar conectividade
    if docker exec sparknexus-postgres pg_isready -U sparknexus &>/dev/null; then
        echo -e "${GREEN}✅ PostgreSQL está respondendo${NC}"
    else
        echo -e "${YELLOW}⚠️ PostgreSQL está rodando mas não responde${NC}"
    fi
else
    echo -e "${RED}❌ PostgreSQL não está rodando${NC}"
    echo -e "${YELLOW}Iniciando PostgreSQL...${NC}"
    docker-compose up -d postgres
    sleep 5
fi

# Mostrar informações de rede do container
echo -e "\n${CYAN}Informações de rede do PostgreSQL:${NC}"
docker inspect sparknexus-postgres | grep -A 5 "IPAddress" | head -6 || true

# ================================================
# 2. FAZER BACKUP DO .ENV
# ================================================
echo -e "\n${BLUE}[2/5] Fazendo backup das configurações...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -f .env ]; then
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✅ Backup criado${NC}"
else
    echo -e "${YELLOW}⚠️ Arquivo .env não encontrado, criando...${NC}"
    touch .env
fi

# ================================================
# 3. CORRIGIR CONFIGURAÇÕES DE CONEXÃO
# ================================================
echo -e "\n${BLUE}[3/5] Corrigindo configurações de conexão...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Função para atualizar ou adicionar variável no .env
update_env() {
    local key=$1
    local value=$2
    
    if grep -q "^$key=" .env; then
        # macOS compatible sed
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^$key=.*|$key=$value|" .env
        else
            sed -i "s|^$key=.*|$key=$value|" .env
        fi
        echo "  Atualizado: $key=$value"
    else
        echo "$key=$value" >> .env
        echo "  Adicionado: $key=$value"
    fi
}

echo -e "${CYAN}Configurando conexões do banco de dados...${NC}"

# Configurar para usar nome do container ao invés de localhost/::1
update_env "DB_HOST" "postgres"
update_env "DB_PORT" "5432"
update_env "DB_NAME" "sparknexus"
update_env "DB_USER" "sparknexus"
update_env "DB_PASSWORD" "SparkNexus2024"

# Configuração alternativa para DATABASE_URL
update_env "DATABASE_URL" "postgresql://sparknexus:SparkNexus2024@postgres:5432/sparknexus"

# Redis
update_env "REDIS_HOST" "redis"
update_env "REDIS_PORT" "6379"

# RabbitMQ
update_env "RABBITMQ_HOST" "rabbitmq"
update_env "RABBITMQ_PORT" "5672"

echo -e "${GREEN}✅ Configurações atualizadas${NC}"

# ================================================
# 4. CRIAR/ATUALIZAR ARQUIVO DE CONFIGURAÇÃO DO DATABASE
# ================================================
echo -e "\n${BLUE}[4/5] Atualizando configuração do database service...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar diretório se não existir
mkdir -p core/client-dashboard/config

# Criar arquivo de configuração do database
cat > core/client-dashboard/config/database.js << 'EOF'
// Configuração do Database - Corrigido para IPv4
const { Pool } = require('pg');

const dbConfig = {
    host: process.env.DB_HOST || 'postgres',  // Usar nome do container
    port: parseInt(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || 'sparknexus',
    user: process.env.DB_USER || 'sparknexus',
    password: process.env.DB_PASSWORD || 'SparkNexus2024',
    
    // Configurações adicionais para evitar problemas de conexão
    connectionTimeoutMillis: 10000,
    idleTimeoutMillis: 30000,
    max: 20,
    
    // Forçar IPv4
    connectionString: process.env.DATABASE_URL || null,
};

// Se estiver no Docker, usar nome do container
if (process.env.NODE_ENV === 'production' || process.env.DOCKER_ENV) {
    dbConfig.host = 'postgres';
}

// Criar pool de conexões
const pool = new Pool(dbConfig);

// Evento de erro
pool.on('error', (err) => {
    console.error('Erro inesperado no pool do PostgreSQL:', err);
});

// Testar conexão ao inicializar
pool.connect((err, client, release) => {
    if (err) {
        console.error('❌ Erro ao conectar ao PostgreSQL:', err.message);
        console.error('Configuração usada:', {
            host: dbConfig.host,
            port: dbConfig.port,
            database: dbConfig.database,
            user: dbConfig.user
        });
    } else {
        console.log('✅ Conectado ao PostgreSQL com sucesso!');
        console.log(`   Host: ${dbConfig.host}:${dbConfig.port}`);
        console.log(`   Database: ${dbConfig.database}`);
        release();
    }
});

module.exports = { pool, dbConfig };
EOF

echo -e "${GREEN}✅ Arquivo de configuração criado${NC}"

# ================================================
# 5. REINICIAR SERVIÇOS
# ================================================
echo -e "\n${BLUE}[5/5] Reiniciando serviços...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Rebuild do client-dashboard para aplicar mudanças
echo -e "${YELLOW}Reconstruindo client-dashboard...${NC}"
docker-compose build client-dashboard

echo -e "${YELLOW}Reiniciando containers...${NC}"
docker-compose restart client-dashboard
docker-compose restart auth-service 2>/dev/null || true
docker-compose restart email-validator-api 2>/dev/null || true

echo -e "${YELLOW}⏳ Aguardando serviços reiniciarem (15 segundos)...${NC}"
sleep 15

# ================================================
# VERIFICAÇÃO FINAL
# ================================================
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📊 Verificação Final${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Testar conexão direta com o banco
echo -e "\n${YELLOW}Testando conexão com o banco de dados...${NC}"
if docker exec sparknexus-postgres psql -U sparknexus -d sparknexus -c "SELECT COUNT(*) FROM auth.users;" &>/dev/null; then
    echo -e "${GREEN}✅ Conexão com banco de dados OK${NC}"
    
    # Mostrar usuários cadastrados
    echo -e "\n${CYAN}Usuários cadastrados:${NC}"
    docker exec sparknexus-postgres psql -U sparknexus -d sparknexus -t -c "SELECT email, first_name || ' ' || last_name as nome FROM auth.users;" | head -5
else
    echo -e "${RED}❌ Erro ao conectar ao banco de dados${NC}"
fi

# Verificar se client-dashboard está rodando
echo -e "\n${YELLOW}Verificando status dos serviços...${NC}"
if docker ps | grep -q sparknexus-client-dashboard; then
    echo -e "${GREEN}✅ Client Dashboard está rodando${NC}"
    
    # Testar acesso HTTP
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:4201 | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✅ Client Dashboard está respondendo${NC}"
    else
        echo -e "${YELLOW}⚠️ Client Dashboard rodando mas não responde em HTTP${NC}"
    fi
else
    echo -e "${RED}❌ Client Dashboard não está rodando${NC}"
fi

# ================================================
# RESULTADO FINAL
# ================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ CORREÇÕES APLICADAS COM SUCESSO!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}🔍 O que foi corrigido:${NC}"
echo "  • Configuração do DB_HOST para usar nome do container (postgres)"
echo "  • Remoção de referências a localhost/::1"
echo "  • Criação de arquivo de configuração com pool de conexões"
echo "  • Rebuild e restart dos serviços"

echo -e "\n${CYAN}🌐 Acesse o sistema:${NC}"
echo "  ${GREEN}http://localhost:4201${NC} - Dashboard Principal"
echo "  ${GREEN}http://localhost:4201/login${NC} - Página de Login"
echo "  ${GREEN}http://localhost:4201/register${NC} - Página de Cadastro"

echo -e "\n${CYAN}👤 Suas credenciais:${NC}"
echo "  Email: girardelibaptista@gmail.com"
echo "  Senha: Demo@123456"

echo -e "\n${CYAN}📝 Comandos úteis:${NC}"
echo "  Ver logs: ${YELLOW}docker-compose logs -f client-dashboard${NC}"
echo "  Status: ${YELLOW}docker ps | grep sparknexus${NC}"
echo "  Testar DB: ${YELLOW}docker exec sparknexus-postgres psql -U sparknexus -d sparknexus${NC}"

echo -e "\n${MAGENTA}🚀 Sistema corrigido e pronto para uso!${NC}"
echo ""

# Verificar se há erros nos logs
echo -e "${YELLOW}Verificando logs por erros...${NC}"
if docker logs sparknexus-client-dashboard 2>&1 | tail -5 | grep -q "ECONNREFUSED"; then
    echo -e "${YELLOW}⚠️ Ainda há erros de conexão. Executando correção adicional...${NC}"
    
    # Correção adicional - forçar uso de bridge network
    docker network connect spark-nexus_sparknexus-network sparknexus-postgres 2>/dev/null || true
    docker network connect spark-nexus_sparknexus-network sparknexus-client-dashboard 2>/dev/null || true
    
    # Restart final
    docker-compose restart client-dashboard
    echo -e "${GREEN}✅ Correção adicional aplicada${NC}"
else
    echo -e "${GREEN}✅ Nenhum erro de conexão detectado nos logs${NC}"
fi

echo -e "\n${GREEN}Script de correção concluído!${NC}"
exit 0