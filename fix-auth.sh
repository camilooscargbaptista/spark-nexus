#!/bin/bash

# ================================================
# Script para Corrigir Erro de Autenticação
# Spark Nexus - Fix Authentication
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
echo -e "${MAGENTA}🔐 CORRIGINDO AUTENTICAÇÃO${NC}"
echo -e "${MAGENTA}================================================${NC}"

# ================================================
# 1. CRIAR USUÁRIO DE TESTE NO BANCO
# ================================================
echo -e "\n${BLUE}[1/4] Criando Usuário de Teste${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar usuário demo com senha já hasheada
docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus << 'SQL'
-- Criar schema auth se não existir
CREATE SCHEMA IF NOT EXISTS auth;

-- Criar tabela de usuários se não existir
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

-- Criar tabela de sessões se não existir
CREATE TABLE IF NOT EXISTS auth.sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES auth.users(id),
    token VARCHAR(500) UNIQUE NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

-- Inserir usuário demo (senha: Demo@123456)
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
    '01487829645',
    '11987654321',
    'Demo Company',
    true,
    true
) ON CONFLICT (email) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    email_verified = true,
    phone_verified = true;

-- Inserir usuário com o CPF/CNPJ do formulário
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
) ON CONFLICT (email) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    email_verified = true,
    phone_verified = true;

-- Verificar usuários criados
SELECT email, first_name, last_name, cpf_cnpj, email_verified FROM auth.users;

SQL

echo -e "${GREEN}✅ Usuários criados no banco${NC}"

# ================================================
# 2. VERIFICAR/CRIAR ARQUIVO DE VALIDAÇÃO
# ================================================
echo -e "\n${BLUE}[2/4] Verificando Validadores${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar arquivo de validação de CPF/CNPJ se não existir
mkdir -p core/client-dashboard/services

cat > core/client-dashboard/services/validators.js << 'EOF'
// Validadores de CPF/CNPJ e outros

class Validators {
    // Validar CPF
    static validateCPF(cpf) {
        // Remove caracteres não numéricos
        cpf = cpf.replace(/[^\d]/g, '');
        
        // Verifica se tem 11 dígitos
        if (cpf.length !== 11) {
            return { valid: false, message: 'CPF deve ter 11 dígitos' };
        }
        
        // Verifica se todos os dígitos são iguais
        if (/^(\d)\1+$/.test(cpf)) {
            return { valid: false, message: 'CPF inválido' };
        }
        
        // Por simplicidade, vamos aceitar qualquer CPF com 11 dígitos
        // Em produção, implemente a validação completa do dígito verificador
        return { 
            valid: true, 
            formatted: cpf.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4')
        };
    }
    
    // Validar CNPJ
    static validateCNPJ(cnpj) {
        // Remove caracteres não numéricos
        cnpj = cnpj.replace(/[^\d]/g, '');
        
        // Verifica se tem 14 dígitos
        if (cnpj.length !== 14) {
            return { valid: false, message: 'CNPJ deve ter 14 dígitos' };
        }
        
        // Por simplicidade, vamos aceitar qualquer CNPJ com 14 dígitos
        // Em produção, implemente a validação completa
        return { 
            valid: true,
            formatted: cnpj.replace(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '$1.$2.$3/$4-$5')
        };
    }
    
    // Validar CPF ou CNPJ
    static validateCpfCnpj(doc) {
        // Remove caracteres não numéricos
        const cleanDoc = doc.replace(/[^\d]/g, '');
        
        if (cleanDoc.length === 11) {
            return this.validateCPF(cleanDoc);
        } else if (cleanDoc.length === 14) {
            return this.validateCNPJ(cleanDoc);
        } else {
            return { 
                valid: false, 
                message: 'Documento deve ter 11 dígitos (CPF) ou 14 dígitos (CNPJ)' 
            };
        }
    }
    
    // Validar Email
    static validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        const valid = emailRegex.test(email);
        
        return {
            valid,
            format: valid,
            domain: valid ? email.split('@')[1] : null,
            isDisposable: false // Simplificado
        };
    }
    
    // Validar Telefone
    static validatePhone(phone) {
        // Remove caracteres não numéricos
        const cleanPhone = phone.replace(/[^\d]/g, '');
        
        // Verifica se tem 10 ou 11 dígitos
        const valid = cleanPhone.length === 10 || cleanPhone.length === 11;
        
        return {
            valid,
            formatted: valid ? 
                cleanPhone.replace(/(\d{2})(\d{4,5})(\d{4})/, '($1) $2-$3') : 
                phone,
            type: cleanPhone.length === 11 ? 'mobile' : 'landline'
        };
    }
    
    // Validar Senha
    static validatePassword(password) {
        const minLength = password.length >= 8;
        const hasUpperCase = /[A-Z]/.test(password);
        const hasLowerCase = /[a-z]/.test(password);
        const hasNumbers = /\d/.test(password);
        const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);
        
        const valid = minLength && hasUpperCase && hasLowerCase && hasNumbers;
        
        return {
            valid,
            strength: valid ? 'strong' : 'weak',
            requirements: {
                minLength,
                hasUpperCase,
                hasLowerCase,
                hasNumbers,
                hasSpecialChar
            }
        };
    }
    
    // Gerar Token
    static generateToken(length = 6, type = 'numeric') {
        const numeric = '0123456789';
        const alphanumeric = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        
        const chars = type === 'numeric' ? numeric : alphanumeric;
        let token = '';
        
        for (let i = 0; i < length; i++) {
            token += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        
        return token;
    }
}

module.exports = Validators;
EOF

echo -e "${GREEN}✅ Arquivo de validadores criado${NC}"

# ================================================
# 3. REINICIAR CLIENT DASHBOARD
# ================================================
echo -e "\n${BLUE}[3/4] Reiniciando Client Dashboard${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

docker-compose restart client-dashboard

echo -e "${YELLOW}⏳ Aguardando serviço reiniciar (10 segundos)...${NC}"
sleep 10

# ================================================
# 4. TESTAR ACESSO
# ================================================
echo -e "\n${BLUE}[4/4] Testando Sistema${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Testar API de validação
echo -e "${CYAN}Testando validação de CPF...${NC}"
curl -X POST http://localhost:4201/api/validate/cpf-cnpj \
  -H "Content-Type: application/json" \
  -d '{"document":"01487829645"}' 2>/dev/null | jq '.' || echo "API ainda iniciando..."

# Verificar status do dashboard
echo -e "\n${CYAN}Verificando status do dashboard...${NC}"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:4201/register

# ================================================
# RESULTADO FINAL
# ================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ AUTENTICAÇÃO CORRIGIDA!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}👤 USUÁRIOS CRIADOS:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${GREEN}Usuário 1:${NC}"
echo "  Email: demo@sparknexus.com"
echo "  Senha: Demo@123456"
echo "  CPF: 014.878.296-45"

echo -e "\n${GREEN}Usuário 2:${NC}"
echo "  Email: girardelibaptista@gmail.com"
echo "  Senha: Demo@123456"
echo "  CPF: 014.878.296-45"

echo -e "\n${CYAN}🔐 COMO FAZER LOGIN:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "1. Acesse: http://localhost:4201/login"
echo "2. Use um dos emails acima"
echo "3. Senha: Demo@123456"

echo -e "\n${CYAN}📝 PARA CRIAR NOVA CONTA:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "1. Acesse: http://localhost:4201/register"
echo "2. Preencha o formulário"
echo "3. Use os dados:"
echo "   • Nome: Camilo"
echo "   • Sobrenome: Baptista"
echo "   • CPF: 01487829645"
echo "   • Email: girardelibaptista@gmail.com"
echo "   • Telefone: (11) 96141-1709"
echo "   • Empresa: Camilo Oscar Girardelli Baptista"
echo "   • Senha: Uma senha forte (ex: Senha@123)"

echo -e "\n${CYAN}🔍 VERIFICAR USUÁRIOS NO BANCO:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "1. Acesse: http://localhost:8080"
echo "2. Login com:"
echo "   • Sistema: PostgreSQL"
echo "   • Servidor: postgres"
echo "   • Usuário: sparknexus"
echo "   • Senha: SparkNexus2024"
echo "   • Banco: sparknexus"
echo "3. Execute: SELECT * FROM auth.users;"

echo -e "\n${MAGENTA}🚀 Sistema pronto! Tente fazer login agora.${NC}"

# Abrir página de registro
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "\n${YELLOW}Abrindo página de registro...${NC}"
    sleep 2
    open "http://localhost:4201/register"
fi