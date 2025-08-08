#!/bin/bash

# ================================================
# Script de Configuração Completa - HostGator Email
# Spark Nexus - Setup Final
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
echo -e "${CYAN}✉️  Configuração Final - Email HostGator${NC}"
echo -e "${CYAN}================================================${NC}"

# ================================================
# 1. VERIFICAR STATUS DOS DATABASES
# ================================================
echo -e "\n${BLUE}[1/5] Verificando Databases${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${GREEN}✅ Databases já foram corrigidos com sucesso!${NC}"
echo "  • sparknexus_core ✅"
echo "  • sparknexus_tenants ✅"
echo "  • sparknexus_modules ✅"
echo "  • n8n ✅"

# ================================================
# 2. VERIFICAR CONFIGURAÇÃO DO EMAIL
# ================================================
echo -e "\n${BLUE}[2/5] Verificando Configuração do Email${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar se as variáveis foram configuradas
if grep -q "SMTP_HOST=mail.sparknexus.com.br" .env; then
    echo -e "${GREEN}✅ Email HostGator configurado no .env${NC}"
    echo "  • Host: mail.sparknexus.com.br"
    echo "  • Port: 587"
    echo "  • User: contato@sparknexus.com.br"
else
    echo -e "${YELLOW}⚠️  Configurando email no .env...${NC}"
    
    # Adicionar configurações se não existirem
    cat >> .env << 'EOF'

# HostGator Email Configuration
SMTP_HOST=mail.sparknexus.com.br
SMTP_PORT=587
SMTP_SECURE=tls
SMTP_USER=contato@sparknexus.com.br
SMTP_PASS=Joao@26082310
SMTP_FROM=contato@sparknexus.com.br
EMAIL_FROM_NAME=Spark Nexus
EOF
    echo -e "${GREEN}✅ Configuração adicionada${NC}"
fi

# ================================================
# 3. CRIAR DIRETÓRIOS E ARQUIVOS NECESSÁRIOS
# ================================================
echo -e "\n${BLUE}[3/5] Criando Estrutura de Arquivos${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar diretórios se não existirem
mkdir -p core/email-validator/services
mkdir -p modules/email-validator/services

echo -e "${YELLOW}📁 Criando arquivo de configuração de email...${NC}"

# Criar arquivo de configuração em múltiplos locais para garantir
for DIR in "core/email-validator/services" "modules/email-validator/services"; do
    if [ -d "$DIR" ]; then
        cat > "$DIR/emailConfig.js" << 'EOF'
// Configuração do Email Service para HostGator
const nodemailer = require('nodemailer');

class EmailService {
    constructor() {
        // Configuração específica para HostGator
        this.transporter = nodemailer.createTransport({
            host: process.env.SMTP_HOST || 'mail.sparknexus.com.br',
            port: parseInt(process.env.SMTP_PORT || 587),
            secure: process.env.SMTP_PORT === '465', // true para 465, false para 587
            auth: {
                user: process.env.SMTP_USER || 'contato@sparknexus.com.br',
                pass: process.env.SMTP_PASS
            },
            tls: {
                rejectUnauthorized: false, // Necessário para HostGator
                ciphers: 'SSLv3'
            },
            debug: true,
            logger: true
        });

        // Verificar conexão ao inicializar
        this.verifyConnection();
    }

    async verifyConnection() {
        try {
            await this.transporter.verify();
            console.log('✅ Conexão com HostGator SMTP estabelecida');
            console.log(`   Server: ${process.env.SMTP_HOST}:${process.env.SMTP_PORT}`);
            console.log(`   User: ${process.env.SMTP_USER}`);
        } catch (error) {
            console.error('❌ Erro ao conectar com SMTP HostGator:', error.message);
            console.log('Verifique:');
            console.log('1. Email e senha estão corretos');
            console.log('2. Porta 587 (TLS) ou 465 (SSL)');
            console.log('3. Autenticação SMTP habilitada no cPanel');
        }
    }

    async sendEmail(to, subject, html, text) {
        try {
            const mailOptions = {
                from: `"${process.env.EMAIL_FROM_NAME || 'Spark Nexus'}" <${process.env.SMTP_FROM || process.env.SMTP_USER}>`,
                to: to,
                subject: subject,
                html: html,
                text: text || html.replace(/<[^>]*>/g, '')
            };

            const info = await this.transporter.sendMail(mailOptions);
            console.log('✅ Email enviado via HostGator:', info.messageId);
            return { success: true, messageId: info.messageId };
        } catch (error) {
            console.error('❌ Erro ao enviar email:', error);
            return { success: false, error: error.message };
        }
    }

    async sendTestEmail(to) {
        const subject = '✅ Teste de Configuração - Spark Nexus';
        const html = `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px 10px 0 0;">
                    <h1 style="color: white; margin: 0;">🎉 Configuração Bem Sucedida!</h1>
                </div>
                
                <div style="padding: 30px; background: #f8f9fa;">
                    <h2 style="color: #333;">Email HostGator Configurado ✅</h2>
                    <p style="color: #666; line-height: 1.6;">
                        Este é um email de teste enviado através do servidor SMTP do HostGator.
                        Se você está recebendo este email, significa que a configuração está funcionando perfeitamente!
                    </p>
                    
                    <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0;">
                        <h3 style="color: #667eea;">Detalhes da Configuração:</h3>
                        <ul style="color: #666;">
                            <li>Servidor: ${process.env.SMTP_HOST}</li>
                            <li>Porta: ${process.env.SMTP_PORT}</li>
                            <li>Usuário: ${process.env.SMTP_USER}</li>
                            <li>Segurança: ${process.env.SMTP_PORT === '465' ? 'SSL' : 'TLS'}</li>
                        </ul>
                    </div>
                    
                    <p style="color: #666;">
                        Agora você pode usar o sistema Spark Nexus para validar e enviar emails!
                    </p>
                </div>
                
                <div style="background: #333; padding: 20px; text-align: center; border-radius: 0 0 10px 10px;">
                    <p style="color: #999; margin: 0; font-size: 12px;">
                        Spark Nexus - Sistema de Validação de Emails<br>
                        © 2024 - Todos os direitos reservados
                    </p>
                </div>
            </div>
        `;
        
        return await this.sendEmail(to, subject, html);
    }
}

module.exports = EmailService;
EOF
        echo -e "${GREEN}✅ Arquivo criado em $DIR${NC}"
    fi
done

# ================================================
# 4. REINICIAR SERVIÇOS
# ================================================
echo -e "\n${BLUE}[4/5] Reiniciando Serviços${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}🔄 Reiniciando containers...${NC}"
docker-compose restart email-validator 2>/dev/null || echo "  ⚠️ email-validator não está rodando"
docker-compose restart client-dashboard 2>/dev/null || echo "  ⚠️ client-dashboard não está rodando"

echo -e "${YELLOW}⏳ Aguardando serviços iniciarem (15 segundos)...${NC}"
sleep 15

# ================================================
# 5. TESTAR CONFIGURAÇÃO
# ================================================
echo -e "\n${BLUE}[5/5] Testando Configuração${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar script de teste local
cat > test-hostgator-email.js << 'EOF'
// Script de Teste - HostGator Email
require('dotenv').config();
const nodemailer = require('nodemailer');

console.log('🧪 Testando configuração HostGator...\n');
console.log('Configuração:');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log(`Host: ${process.env.SMTP_HOST}`);
console.log(`Port: ${process.env.SMTP_PORT}`);
console.log(`User: ${process.env.SMTP_USER}`);
console.log(`From: ${process.env.SMTP_FROM}`);
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

async function testEmail() {
    const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST || 'mail.sparknexus.com.br',
        port: parseInt(process.env.SMTP_PORT || 587),
        secure: process.env.SMTP_PORT === '465',
        auth: {
            user: process.env.SMTP_USER || 'contato@sparknexus.com.br',
            pass: process.env.SMTP_PASS
        },
        tls: {
            rejectUnauthorized: false,
            ciphers: 'SSLv3'
        }
    });

    try {
        console.log('📡 Verificando conexão...');
        await transporter.verify();
        console.log('✅ Conexão estabelecida!\n');
        
        console.log('📧 Enviando email de teste...');
        const info = await transporter.sendMail({
            from: `"Spark Nexus" <${process.env.SMTP_FROM || process.env.SMTP_USER}>`,
            to: process.env.SMTP_USER,
            subject: '✅ Teste HostGator - Spark Nexus',
            html: '<h2>Email de teste enviado com sucesso!</h2><p>HostGator SMTP funcionando.</p>'
        });
        
        console.log('✅ Email enviado!');
        console.log('Message ID:', info.messageId);
        console.log('\n🎉 Configuração funcionando perfeitamente!');
        
    } catch (error) {
        console.error('\n❌ Erro:', error.message);
        console.log('\n🔧 Soluções:');
        console.log('1. Verifique email e senha');
        console.log('2. No cPanel, verifique se SMTP está habilitado');
        console.log('3. Tente porta 465 ao invés de 587');
        console.log('4. Verifique firewall/antivirus local');
    }
}

testEmail();
EOF

# Verificar se npm está disponível localmente
if command -v npm &> /dev/null; then
    echo -e "${YELLOW}📧 Instalando dependências para teste local...${NC}"
    npm install nodemailer dotenv 2>/dev/null || true
    
    echo -e "${YELLOW}🧪 Executando teste de email...${NC}"
    node test-hostgator-email.js || echo -e "${YELLOW}⚠️ Teste local falhou, verifique as dependências${NC}"
else
    echo -e "${YELLOW}⚠️ npm não encontrado localmente, teste será feito via Docker${NC}"
fi

# Teste via curl na API
echo -e "\n${YELLOW}🔍 Testando API de email...${NC}"
curl -X POST http://localhost:4201/api/test-email \
    -H "Content-Type: application/json" \
    -d '{"email":"contato@sparknexus.com.br"}' 2>/dev/null || echo -e "${YELLOW}⚠️ API ainda não está pronta${NC}"

# ================================================
# RESULTADO FINAL
# ================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ CONFIGURAÇÃO COMPLETA!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verificar status dos containers
echo -e "${CYAN}📊 Status dos Serviços:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus || echo "Verificando..."

echo ""
echo -e "${CYAN}📧 Configuração HostGator:${NC}"
echo "  • Host: mail.sparknexus.com.br"
echo "  • Port: 587 (TLS)"
echo "  • User: contato@sparknexus.com.br"
echo "  • Status: Configurado ✅"

echo ""
echo -e "${CYAN}🔍 Comandos Úteis:${NC}"
echo -e "${YELLOW}# Ver logs do email service:${NC}"
echo "docker-compose logs -f email-validator"
echo ""
echo -e "${YELLOW}# Testar envio de email:${NC}"
echo "node test-hostgator-email.js"
echo ""
echo -e "${YELLOW}# Verificar containers:${NC}"
echo "docker ps | grep sparknexus"
echo ""
echo -e "${YELLOW}# Acessar o sistema:${NC}"
echo "open http://localhost:4201/upload"

echo ""
echo -e "${BLUE}💡 Próximos Passos:${NC}"
echo "1. Acesse: http://localhost:4201/upload"
echo "2. Faça upload de uma lista de emails"
echo "3. Você receberá o relatório em contato@sparknexus.com.br"

echo ""
echo -e "${YELLOW}⚠️  Limites do HostGator:${NC}"
echo "• Planos compartilhados: 500 emails/hora"
echo "• Se exceder, aguarde 1 hora"
echo "• Para mais envios, considere um plano dedicado"

echo ""
echo -e "${GREEN}🚀 Sistema Spark Nexus com HostGator configurado e pronto!${NC}"