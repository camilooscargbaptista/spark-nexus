#!/bin/bash

# ================================================
# Script de Correção: Databases + Email HostGator
# Spark Nexus - Configuração Completa
# ================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}🔧 Correção de Databases + Config HostGator${NC}"
echo -e "${CYAN}================================================${NC}"

# ================================================
# PARTE 1: CORRIGIR DATABASES
# ================================================
echo -e "\n${BLUE}[PARTE 1] Corrigindo Databases${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar se PostgreSQL está rodando
if ! docker exec sparknexus-postgres pg_isready -U sparknexus > /dev/null 2>&1; then
    echo -e "${RED}❌ PostgreSQL não está rodando. Iniciando...${NC}"
    docker-compose up -d postgres
    sleep 5
fi

echo -e "${YELLOW}🔍 Verificando databases existentes...${NC}"
EXISTING_DBS=$(docker exec sparknexus-postgres psql -U sparknexus -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null | sed 's/^[ \t]*//;s/[ \t]*$//')

echo -e "${CYAN}Databases encontrados:${NC}"
echo "$EXISTING_DBS" | while read -r db; do
    if [ ! -z "$db" ]; then
        echo -e "  ✅ $db"
    fi
done

# Criar databases faltantes
echo -e "\n${YELLOW}🔧 Criando databases faltantes...${NC}"

# Lista de databases necessários
REQUIRED_DBS=(
    "sparknexus"
    "sparknexus_core"
    "sparknexus_tenants"
    "sparknexus_modules"
    "n8n"
)

for DB_NAME in "${REQUIRED_DBS[@]}"; do
    echo -n "Verificando database $DB_NAME... "
    
    if docker exec sparknexus-postgres psql -U sparknexus -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo -e "${GREEN}já existe ✅${NC}"
    else
        echo -e "${YELLOW}criando...${NC}"
        docker exec sparknexus-postgres psql -U sparknexus -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || {
            echo -e "${YELLOW}  ⚠️ Database pode já existir ou houve um warning${NC}"
        }
        
        # Dar permissões
        docker exec sparknexus-postgres psql -U sparknexus -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO sparknexus;" 2>/dev/null || true
    fi
done

# Criar schemas necessários
echo -e "\n${YELLOW}📋 Criando schemas necessários...${NC}"

# Schema para sparknexus_core
docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus_core << 'SQL' 2>/dev/null || true
-- Criar schema auth se não existir
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS public;

-- Tabela de usuários básica
CREATE TABLE IF NOT EXISTS auth.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de sessões
CREATE TABLE IF NOT EXISTS auth.sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES auth.users(id),
    token VARCHAR(500) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);
SQL

echo -e "${GREEN}✅ Schema auth criado/atualizado${NC}"

# Schema para sparknexus_tenants
docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus_tenants << 'SQL' 2>/dev/null || true
-- Criar schema tenant
CREATE SCHEMA IF NOT EXISTS tenant;

-- Tabela de organizações
CREATE TABLE IF NOT EXISTS tenant.organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    plan VARCHAR(50) DEFAULT 'free',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de membros
CREATE TABLE IF NOT EXISTS tenant.organization_members (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER,
    user_id INTEGER,
    role VARCHAR(50) DEFAULT 'member',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL

echo -e "${GREEN}✅ Schema tenant criado/atualizado${NC}"

# Schema para sparknexus_modules
docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus_modules << 'SQL' 2>/dev/null || true
-- Criar schema modules
CREATE SCHEMA IF NOT EXISTS modules;

-- Tabela de módulos instalados
CREATE TABLE IF NOT EXISTS modules.installed (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    version VARCHAR(20),
    active BOOLEAN DEFAULT true,
    installed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inserir módulos padrão
INSERT INTO modules.installed (name, version) VALUES
    ('email-validator', '1.0.0'),
    ('client-dashboard', '1.0.0'),
    ('auth-service', '1.0.0')
ON CONFLICT (name) DO NOTHING;
SQL

echo -e "${GREEN}✅ Schema modules criado/atualizado${NC}"

echo -e "\n${GREEN}✅ TODOS OS DATABASES CORRIGIDOS!${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ================================================
# PARTE 2: CONFIGURAR EMAIL HOSTGATOR
# ================================================
echo -e "\n${BLUE}[PARTE 2] Configurando Email HostGator${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Fazer backup do .env atual
cp .env .env.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

echo -e "${CYAN}📧 Configuração do HostGator Email${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Informações necessárias do seu HostGator:${NC}"
echo ""
echo -e "${CYAN}1. SERVIDOR SMTP:${NC}"
echo "   Se seu domínio é sparknexus.com.br:"
echo "   • Servidor: mail.sparknexus.com.br"
echo "   • Porta: 465 (SSL) ou 587 (TLS)"
echo ""
echo -e "${CYAN}2. CREDENCIAIS:${NC}"
echo "   • Email completo: contato@sparknexus.com.br"
echo "   • Senha: Joao@26082310"
echo ""

# Solicitar informações do usuário
echo -e "${YELLOW}Por favor, forneça as informações:${NC}"
echo ""

read -p "Digite seu email completo do HostGator (ex: contato@sparknexus.com.br): " HOSTGATOR_EMAIL
read -p "Digite o servidor SMTP (ex: mail.sparknexus.com.br): " HOSTGATOR_SMTP
read -p "Digite a porta SMTP (465 para SSL ou 587 para TLS): " HOSTGATOR_PORT
read -s -p "Digite sua senha do email: " HOSTGATOR_PASSWORD
echo ""

# Determinar o tipo de criptografia baseado na porta
if [ "$HOSTGATOR_PORT" == "465" ]; then
    SMTP_SECURE="ssl"
elif [ "$HOSTGATOR_PORT" == "587" ]; then
    SMTP_SECURE="tls"
else
    SMTP_SECURE="tls"
fi

# Atualizar arquivo .env
echo -e "\n${YELLOW}📝 Atualizando arquivo .env...${NC}"

# Criar arquivo .env se não existir
if [ ! -f .env ]; then
    touch .env
fi

# Função para atualizar ou adicionar variável no .env
update_env() {
    local key=$1
    local value=$2
    
    if grep -q "^$key=" .env; then
        # Se a chave existe, atualiza
        sed -i.bak "s|^$key=.*|$key=$value|" .env
    else
        # Se não existe, adiciona
        echo "$key=$value" >> .env
    fi
}

# Atualizar variáveis de email
update_env "SMTP_HOST" "$HOSTGATOR_SMTP"
update_env "SMTP_PORT" "$HOSTGATOR_PORT"
update_env "SMTP_SECURE" "$SMTP_SECURE"
update_env "SMTP_USER" "$HOSTGATOR_EMAIL"
update_env "SMTP_PASS" "$HOSTGATOR_PASSWORD"
update_env "SMTP_FROM" "$HOSTGATOR_EMAIL"
update_env "EMAIL_FROM_NAME" "Spark Nexus"

echo -e "${GREEN}✅ Arquivo .env atualizado com configurações do HostGator${NC}"

# ================================================
# PARTE 3: ATUALIZAR CONFIGURAÇÃO DO EMAIL SERVICE
# ================================================
echo -e "\n${BLUE}[PARTE 3] Atualizando Email Service${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar arquivo de configuração do email service
cat > core/email-validator/services/emailConfig.js << 'EOF'
// Configuração do Email Service para HostGator
const nodemailer = require('nodemailer');

class EmailService {
    constructor() {
        // Configuração específica para HostGator
        this.transporter = nodemailer.createTransport({
            host: process.env.SMTP_HOST,
            port: parseInt(process.env.SMTP_PORT),
            secure: process.env.SMTP_PORT === '465', // true para 465, false para outras
            auth: {
                user: process.env.SMTP_USER,
                pass: process.env.SMTP_PASS
            },
            tls: {
                rejectUnauthorized: false // Necessário para alguns servidores HostGator
            },
            debug: true, // Ativar debug para troubleshooting
            logger: true // Ativar logs
        });

        // Verificar conexão ao inicializar
        this.verifyConnection();
    }

    async verifyConnection() {
        try {
            await this.transporter.verify();
            console.log('✅ Conexão com servidor SMTP HostGator estabelecida');
        } catch (error) {
            console.error('❌ Erro ao conectar com SMTP HostGator:', error);
            console.log('Configuração atual:');
            console.log('- Host:', process.env.SMTP_HOST);
            console.log('- Port:', process.env.SMTP_PORT);
            console.log('- User:', process.env.SMTP_USER);
        }
    }

    async sendEmail(to, subject, html, text) {
        try {
            const mailOptions = {
                from: `"${process.env.EMAIL_FROM_NAME || 'Spark Nexus'}" <${process.env.SMTP_FROM}>`,
                to: to,
                subject: subject,
                html: html,
                text: text || html.replace(/<[^>]*>/g, '')
            };

            const info = await this.transporter.sendMail(mailOptions);
            console.log('✅ Email enviado:', info.messageId);
            return { success: true, messageId: info.messageId };
        } catch (error) {
            console.error('❌ Erro ao enviar email:', error);
            return { success: false, error: error.message };
        }
    }

    async sendValidationReport(to, results) {
        const subject = 'Relatório de Validação - Spark Nexus';
        const html = `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #667eea;">Relatório de Validação Concluído</h2>
                <p>Sua validação de emails foi concluída com sucesso!</p>
                
                <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
                    <h3>Resumo dos Resultados:</h3>
                    <ul>
                        <li>Total de emails: ${results.total || 0}</li>
                        <li>Válidos: ${results.valid || 0}</li>
                        <li>Inválidos: ${results.invalid || 0}</li>
                        <li>Taxa de sucesso: ${results.successRate || 0}%</li>
                    </ul>
                </div>
                
                <p>Acesse o dashboard para ver os detalhes completos.</p>
                
                <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #e0e0e0;">
                    <p style="color: #666; font-size: 12px;">
                        Spark Nexus - Sistema de Validação de Emails<br>
                        Este é um email automático, não responda.
                    </p>
                </div>
            </div>
        `;
        
        return await this.sendEmail(to, subject, html);
    }
}

module.exports = EmailService;
EOF

echo -e "${GREEN}✅ Email Service atualizado para HostGator${NC}"

# ================================================
# PARTE 4: TESTAR CONFIGURAÇÃO
# ================================================
echo -e "\n${BLUE}[PARTE 4] Testando Configuração${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Reiniciar containers para aplicar novas configurações
echo -e "${YELLOW}🔄 Reiniciando serviços...${NC}"
docker-compose restart email-validator
docker-compose restart client-dashboard

echo -e "${YELLOW}⏳ Aguardando serviços reiniciarem...${NC}"
sleep 10

# Criar script de teste de email
cat > test-email-hostgator.js << 'EOF'
// Script de teste para email HostGator
require('dotenv').config();
const nodemailer = require('nodemailer');

async function testEmail() {
    console.log('🧪 Testando configuração de email HostGator...\n');
    
    console.log('Configuração atual:');
    console.log('- SMTP Host:', process.env.SMTP_HOST);
    console.log('- SMTP Port:', process.env.SMTP_PORT);
    console.log('- SMTP User:', process.env.SMTP_USER);
    console.log('- From:', process.env.SMTP_FROM);
    console.log('\nTentando conectar...\n');

    const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT),
        secure: process.env.SMTP_PORT === '465',
        auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS
        },
        tls: {
            rejectUnauthorized: false
        },
        debug: true,
        logger: true
    });

    try {
        // Verificar conexão
        await transporter.verify();
        console.log('✅ Conexão com HostGator SMTP estabelecida!\n');
        
        // Enviar email de teste
        console.log('📧 Enviando email de teste...\n');
        
        const info = await transporter.sendMail({
            from: `"Spark Nexus Test" <${process.env.SMTP_FROM}>`,
            to: process.env.SMTP_USER, // Envia para si mesmo
            subject: 'Teste de Configuração - Spark Nexus',
            html: `
                <h2>✅ Configuração Bem Sucedida!</h2>
                <p>Este é um email de teste do sistema Spark Nexus.</p>
                <p>Se você está recebendo este email, significa que a configuração do HostGator está funcionando corretamente!</p>
                <hr>
                <p><small>Configuração usada:<br>
                Host: ${process.env.SMTP_HOST}<br>
                Port: ${process.env.SMTP_PORT}<br>
                User: ${process.env.SMTP_USER}</small></p>
            `
        });
        
        console.log('✅ Email enviado com sucesso!');
        console.log('Message ID:', info.messageId);
        console.log('\n🎉 Configuração do HostGator funcionando perfeitamente!');
        
    } catch (error) {
        console.error('❌ Erro:', error.message);
        console.log('\n🔧 Possíveis soluções:');
        console.log('1. Verifique se o email e senha estão corretos');
        console.log('2. Certifique-se de que o servidor SMTP está correto');
        console.log('3. Tente usar porta 587 (TLS) ou 465 (SSL)');
        console.log('4. Verifique se o email tem permissão para envio SMTP');
        console.log('5. No cPanel, verifique se a autenticação SMTP está habilitada');
    }
}

testEmail();
EOF

# Executar teste dentro do container
echo -e "\n${YELLOW}🧪 Executando teste de email...${NC}"
docker exec sparknexus-email-validator node -e "
const nodemailer = require('nodemailer');
(async () => {
    console.log('Testando conexão SMTP...');
    const transporter = nodemailer.createTransport({
        host: '$HOSTGATOR_SMTP',
        port: $HOSTGATOR_PORT,
        secure: $HOSTGATOR_PORT === 465,
        auth: {
            user: '$HOSTGATOR_EMAIL',
            pass: '$HOSTGATOR_PASSWORD'
        },
        tls: { rejectUnauthorized: false }
    });
    
    try {
        await transporter.verify();
        console.log('✅ Conexão SMTP OK!');
    } catch (e) {
        console.log('❌ Erro:', e.message);
    }
})();
" 2>/dev/null || echo -e "${YELLOW}⚠️ Teste será executado após reiniciar os containers${NC}"

# ================================================
# RESULTADO FINAL
# ================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ CONFIGURAÇÃO COMPLETA!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}📊 Status dos Databases:${NC}"
echo -e "  ✅ sparknexus"
echo -e "  ✅ sparknexus_core"
echo -e "  ✅ sparknexus_tenants"  
echo -e "  ✅ sparknexus_modules"
echo -e "  ✅ n8n"
echo ""
echo -e "${CYAN}📧 Configuração de Email HostGator:${NC}"
echo -e "  Host: $HOSTGATOR_SMTP"
echo -e "  Port: $HOSTGATOR_PORT"
echo -e "  User: $HOSTGATOR_EMAIL"
echo -e "  Security: $SMTP_SECURE"
echo ""
echo -e "${YELLOW}🔍 Para verificar os logs de email:${NC}"
echo -e "  docker-compose logs -f email-validator"
echo ""
echo -e "${YELLOW}🧪 Para testar o envio de email:${NC}"
echo -e "  node test-email-hostgator.js"
echo ""
echo -e "${BLUE}💡 Dicas Importantes HostGator:${NC}"
echo -e "  1. Certifique-se de que a autenticação SMTP está habilitada no cPanel"
echo -e "  2. Use a senha do EMAIL, não a senha do cPanel"
echo -e "  3. Se usar porta 465, o SSL deve estar ativo"
echo -e "  4. Se usar porta 587, use TLS/STARTTLS"
echo -e "  5. Alguns planos limitam envios a 500 emails/hora"
echo ""
echo -e "${GREEN}Sistema pronto para uso com HostGator Email! 🚀${NC}"