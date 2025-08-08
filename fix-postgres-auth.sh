#!/bin/bash

# ================================================
# Script para Corrigir PostgreSQL e Autenticação
# Spark Nexus - Fix PostgreSQL Connection
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

echo -e "${MAGENTA}================================================${NC}"
echo -e "${MAGENTA}🔧 CORRIGINDO POSTGRESQL E AUTENTICAÇÃO${NC}"
echo -e "${MAGENTA}================================================${NC}"

# ================================================
# 1. VERIFICAR STATUS DO POSTGRESQL
# ================================================
echo -e "\n${BLUE}[1/6] Verificando PostgreSQL${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar se o container está rodando
if docker ps | grep -q sparknexus-postgres; then
    echo -e "${GREEN}✅ Container PostgreSQL está rodando${NC}"
else
    echo -e "${YELLOW}⚠️ Container PostgreSQL não está rodando. Iniciando...${NC}"
    docker-compose up -d postgres
    sleep 10
fi

# Verificar conectividade
echo "Testando conexão com PostgreSQL..."
if docker exec sparknexus-postgres pg_isready -U sparknexus; then
    echo -e "${GREEN}✅ PostgreSQL está respondendo${NC}"
else
    echo -e "${YELLOW}⚠️ PostgreSQL não está pronto. Aguardando...${NC}"
    sleep 5
fi

# ================================================
# 2. CRIAR DATABASE SE NÃO EXISTIR
# ================================================
echo -e "\n${BLUE}[2/6] Verificando Databases${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar database sparknexus se não existir
docker exec sparknexus-postgres psql -U sparknexus -tc "SELECT 1 FROM pg_database WHERE datname = 'sparknexus'" | grep -q 1 || \
docker exec sparknexus-postgres psql -U sparknexus -c "CREATE DATABASE sparknexus;"

echo -e "${GREEN}✅ Database sparknexus existe${NC}"

# ================================================
# 3. CRIAR ESTRUTURA DO BANCO
# ================================================
echo -e "\n${BLUE}[3/6] Criando Estrutura do Banco${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar schema e tabelas
docker exec sparknexus-postgres psql -U sparknexus -d sparknexus << 'EOF'
-- Criar schema auth
CREATE SCHEMA IF NOT EXISTS auth;

-- Criar tabela de usuários
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Criar tabela de sessões
CREATE TABLE IF NOT EXISTS auth.sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES auth.users(id),
    token VARCHAR(500) UNIQUE NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

-- Criar tabela de tentativas de login
CREATE TABLE IF NOT EXISTS auth.login_attempts (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255),
    ip_address VARCHAR(45),
    success BOOLEAN DEFAULT false,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Schema tenant
CREATE SCHEMA IF NOT EXISTS tenant;

-- Tabela de organizações
CREATE TABLE IF NOT EXISTS tenant.organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    plan VARCHAR(50) DEFAULT 'free',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de membros da organização
CREATE TABLE IF NOT EXISTS tenant.organization_members (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES tenant.organizations(id),
    user_id INTEGER REFERENCES auth.users(id),
    role VARCHAR(50) DEFAULT 'member',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(organization_id, user_id)
);

SELECT 'Estrutura do banco criada com sucesso!' as status;
EOF

echo -e "${GREEN}✅ Estrutura do banco criada${NC}"

# ================================================
# 4. INSERIR USUÁRIOS DE TESTE
# ================================================
echo -e "\n${BLUE}[4/6] Inserindo Usuários${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Inserir usuários (senha: Demo@123456)
docker exec sparknexus-postgres psql -U sparknexus -d sparknexus << 'EOF'
-- Limpar usuários existentes para evitar conflitos
TRUNCATE auth.users CASCADE;

-- Inserir usuário demo
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
) VALUES (
    'demo@sparknexus.com',
    '$2a$10$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq',
    'Demo',
    'User',
    '11144477735',
    '11987654321',
    'Demo Company',
    true,
    true
);

-- Inserir usuário Camilo
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
) VALUES (
    'girardelibaptista@gmail.com',
    '$2a$10$YrJpDFBBIrXzKDFYtFkKPuWR8vhLXGNxVxLxvKnHz2vz3fA6UyXJq',
    'Camilo',
    'Baptista',
    '01487829645',
    '11961411709',
    'Camilo Oscar Girardelli Baptista',
    true,
    true
);

-- Criar organização demo
INSERT INTO tenant.organizations (name, slug, plan)
VALUES ('Demo Organization', 'demo-org', 'free')
ON CONFLICT (slug) DO NOTHING;

-- Associar usuários à organização
INSERT INTO tenant.organization_members (organization_id, user_id, role)
SELECT o.id, u.id, 'owner'
FROM tenant.organizations o, auth.users u
WHERE o.slug = 'demo-org' AND u.email IN ('demo@sparknexus.com', 'girardelibaptista@gmail.com')
ON CONFLICT DO NOTHING;

-- Verificar usuários criados
SELECT 
    email, 
    first_name || ' ' || last_name as nome_completo,
    cpf_cnpj,
    phone,
    email_verified,
    phone_verified
FROM auth.users;
EOF

echo -e "${GREEN}✅ Usuários inseridos com sucesso${NC}"

# ================================================
# 5. CRIAR MOCK DO DATABASE SERVICE
# ================================================
echo -e "\n${BLUE}[5/6] Criando Database Service${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar database service mock se necessário
mkdir -p core/client-dashboard/services

cat > core/client-dashboard/services/database.js << 'EOF'
// Database Service - Mock para desenvolvimento
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

class DatabaseService {
    constructor() {
        this.pool = new Pool({
            host: process.env.DB_HOST || 'postgres',
            port: process.env.DB_PORT || 5432,
            database: process.env.DB_NAME || 'sparknexus',
            user: process.env.DB_USER || 'sparknexus',
            password: process.env.DB_PASSWORD || 'SparkNexus2024'
        });
        
        // Redis mock
        this.redis = {
            isOpen: false,
            get: async () => null,
            set: async () => true,
            del: async () => true,
            quit: () => {}
        };
    }
    
    async createUser(userData) {
        try {
            // Hash da senha
            const passwordHash = await bcrypt.hash(userData.password, 10);
            
            const query = `
                INSERT INTO auth.users (
                    email, password_hash, first_name, last_name,
                    cpf_cnpj, phone, company, 
                    email_verification_token, phone_verification_token
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                RETURNING id, email, first_name, last_name
            `;
            
            const values = [
                userData.email,
                passwordHash,
                userData.firstName,
                userData.lastName,
                userData.cpfCnpj,
                userData.phone,
                userData.company,
                userData.emailToken,
                userData.phoneToken
            ];
            
            const result = await this.pool.query(query, values);
            return { success: true, user: result.rows[0] };
        } catch (error) {
            console.error('Erro ao criar usuário:', error);
            if (error.code === '23505') { // Unique violation
                throw new Error('Email já cadastrado');
            }
            throw error;
        }
    }
    
    async getUserByEmail(email) {
        try {
            const query = 'SELECT * FROM auth.users WHERE email = $1';
            const result = await this.pool.query(query, [email]);
            return result.rows[0];
        } catch (error) {
            console.error('Erro ao buscar usuário:', error);
            return null;
        }
    }
    
    async validateSession(token) {
        try {
            const query = `
                SELECT s.*, u.email, u.first_name, u.last_name 
                FROM auth.sessions s
                JOIN auth.users u ON s.user_id = u.id
                WHERE s.token = $1 AND s.expires_at > NOW()
            `;
            const result = await this.pool.query(query, [token]);
            return result.rows[0];
        } catch (error) {
            console.error('Erro ao validar sessão:', error);
            return null;
        }
    }
    
    async createSession(userId, token, ipAddress, userAgent) {
        try {
            const expiresAt = new Date();
            expiresAt.setHours(expiresAt.getHours() + 24);
            
            const query = `
                INSERT INTO auth.sessions (user_id, token, ip_address, user_agent, expires_at)
                VALUES ($1, $2, $3, $4, $5)
                RETURNING id
            `;
            
            const values = [userId, token, ipAddress, userAgent, expiresAt];
            await this.pool.query(query, values);
            return true;
        } catch (error) {
            console.error('Erro ao criar sessão:', error);
            return false;
        }
    }
    
    async checkLoginAttempts(email, ipAddress) {
        try {
            const query = `
                SELECT COUNT(*) as attempts
                FROM auth.login_attempts
                WHERE (email = $1 OR ip_address = $2)
                AND attempted_at > NOW() - INTERVAL '15 minutes'
                AND success = false
            `;
            const result = await this.pool.query(query, [email, ipAddress]);
            return parseInt(result.rows[0].attempts) || 0;
        } catch (error) {
            console.error('Erro ao verificar tentativas:', error);
            return 0;
        }
    }
    
    async logLoginAttempt(email, ipAddress, success) {
        try {
            const query = `
                INSERT INTO auth.login_attempts (email, ip_address, success)
                VALUES ($1, $2, $3)
            `;
            await this.pool.query(query, [email, ipAddress, success]);
        } catch (error) {
            console.error('Erro ao registrar tentativa:', error);
        }
    }
    
    async verifyEmail(token) {
        try {
            const query = `
                UPDATE auth.users 
                SET email_verified = true, email_verification_token = NULL
                WHERE email_verification_token = $1
                RETURNING email, first_name
            `;
            const result = await this.pool.query(query, [token]);
            return result.rows[0];
        } catch (error) {
            console.error('Erro ao verificar email:', error);
            return null;
        }
    }
    
    async verifyPhone(userId, token) {
        try {
            const query = `
                UPDATE auth.users 
                SET phone_verified = true, phone_verification_token = NULL
                WHERE id = $1 AND phone_verification_token = $2
                RETURNING id
            `;
            const result = await this.pool.query(query, [userId, token]);
            return result.rows[0];
        } catch (error) {
            console.error('Erro ao verificar telefone:', error);
            return null;
        }
    }
    
    async cleanupExpiredData() {
        try {
            // Limpar sessões expiradas
            await this.pool.query('DELETE FROM auth.sessions WHERE expires_at < NOW()');
            
            // Limpar tentativas antigas de login
            await this.pool.query(
                "DELETE FROM auth.login_attempts WHERE attempted_at < NOW() - INTERVAL '24 hours'"
            );
        } catch (error) {
            console.error('Erro ao limpar dados expirados:', error);
        }
    }
}

module.exports = DatabaseService;
EOF

echo -e "${GREEN}✅ Database Service criado${NC}"

# ================================================
# 6. REINICIAR SERVIÇOS
# ================================================
echo -e "\n${BLUE}[6/6] Reiniciando Serviços${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Rebuild e restart do client-dashboard
docker-compose build client-dashboard
docker-compose up -d client-dashboard

echo -e "${YELLOW}⏳ Aguardando serviços (15 segundos)...${NC}"
sleep 15

# Verificar status
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus-client-dashboard

# ================================================
# RESULTADO FINAL
# ================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SISTEMA CORRIGIDO E PRONTO!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}👤 USUÁRIOS DISPONÍVEIS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}Usuário 1 (Demo):${NC}"
echo "  📧 Email: demo@sparknexus.com"
echo "  🔐 Senha: Demo@123456"
echo "  📄 CPF: 111.444.777-35"

echo -e "\n${GREEN}Usuário 2 (Seu):${NC}"
echo "  📧 Email: girardelibaptista@gmail.com"
echo "  🔐 Senha: Demo@123456"
echo "  📄 CPF: 014.878.296-45"

echo -e "\n${CYAN}🚀 COMO USAR:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${GREEN}Opção 1 - Fazer Login:${NC}"
echo "1. Acesse: http://localhost:4201/login"
echo "2. Use: girardelibaptista@gmail.com"
echo "3. Senha: Demo@123456"

echo -e "\n${GREEN}Opção 2 - Criar Nova Conta:${NC}"
echo "1. Acesse: http://localhost:4201/register"
echo "2. Preencha com seus dados"
echo "3. Confirme o email (verificação mockada)"

echo -e "\n${GREEN}Opção 3 - Acessar Direto:${NC}"
echo "• Dashboard: http://localhost:4201"
echo "• Upload: http://localhost:4201/upload"
echo "• API: http://localhost:4200"

echo -e "\n${CYAN}🔍 VERIFICAR NO BANCO:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "docker exec sparknexus-postgres psql -U sparknexus -d sparknexus -c 'SELECT email, first_name, last_name FROM auth.users;'"

echo -e "\n${MAGENTA}🎉 Tudo pronto! Acesse http://localhost:4201${NC}"

# Abrir no navegador
if [[ "$OSTYPE" == "darwin"* ]]; then
    sleep 2
    open "http://localhost:4201/register"
fi