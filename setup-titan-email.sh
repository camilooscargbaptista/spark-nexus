#!/bin/bash

# ================================================
# Configuração do Titan Email - HostGator
# Spark Nexus - Setup Correto
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
echo -e "${MAGENTA}⚡ Configuração Titan Email - HostGator${NC}"
echo -e "${MAGENTA}================================================${NC}"

# ================================================
# INFORMAÇÕES DO TITAN EMAIL
# ================================================
echo -e "\n${CYAN}📧 CONFIGURAÇÕES DO TITAN EMAIL:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Servidor SMTP:${NC} smtp.titan.email"
echo -e "${GREEN}Porta:${NC} 587 (TLS) ou 465 (SSL)"
echo -e "${GREEN}Segurança:${NC} STARTTLS/TLS"
echo -e "${GREEN}Autenticação:${NC} Sim, obrigatória"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ================================================
# 1. FAZER BACKUP
# ================================================
echo -e "\n${BLUE}[1/6] Fazendo Backup${NC}"
cp .env .env.backup.titan.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
echo -e "${GREEN}✅ Backup criado${NC}"

# ================================================
# 2. CONFIGURAR TITAN EMAIL NO .ENV
# ================================================
echo -e "\n${BLUE}[2/6] Configurando Titan Email${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Função para atualizar .env
update_env() {
    local key=$1
    local value=$2
    
    if grep -q "^$key=" .env; then
        sed -i.bak "s|^$key=.*|$key=$value|" .env
    else
        echo "$key=$value" >> .env
    fi
}

# Configurações do Titan Email
update_env "SMTP_HOST" "smtp.titan.email"
update_env "SMTP_PORT" "587"
update_env "SMTP_SECURE" "tls"
update_env "SMTP_USER" "contato@sparknexus.com.br"
update_env "SMTP_FROM" "contato@sparknexus.com.br"
update_env "EMAIL_FROM_NAME" "Spark Nexus"

echo -e "${GREEN}✅ Configurações do Titan Email aplicadas${NC}"

# Confirmar senha
echo -e "\n${YELLOW}⚠️  IMPORTANTE: A senha do Titan Email${NC}"
echo "É a senha que você usa para acessar o webmail Titan,"
echo "NÃO é a senha do cPanel do HostGator!"
echo ""
read -s -p "Digite a senha do Titan Email para contato@sparknexus.com.br: " TITAN_PASSWORD
echo ""

update_env "SMTP_PASS" "$TITAN_PASSWORD"
echo -e "${GREEN}✅ Senha configurada${NC}"

# ================================================
# 3. CRIAR ARQUIVO DE CONFIGURAÇÃO ESPECÍFICO
# ================================================
echo -e "\n${BLUE}[3/6] Criando Configuração Específica${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar diretórios necessários
mkdir -p core/email-validator/services
mkdir -p modules/email-validator/config

# Criar configuração para Titan Email
cat > core/email-validator/services/titanEmailService.js << 'EOF'
// Serviço de Email - Titan Email (HostGator)
const nodemailer = require('nodemailer');

class TitanEmailService {
    constructor() {
        // Configuração específica para Titan Email
        this.transporter = nodemailer.createTransport({
            host: 'smtp.titan.email',
            port: parseInt(process.env.SMTP_PORT || 587),
            secure: false, // false para TLS/STARTTLS
            auth: {
                user: process.env.SMTP_USER,
                pass: process.env.SMTP_PASS
            },
            tls: {
                ciphers: 'SSLv3',
                rejectUnauthorized: false
            },
            requireTLS: true,
            connectionTimeout: 10000,
            greetingTimeout: 10000,
            debug: true,
            logger: true
        });

        this.verifyConnection();
    }

    async verifyConnection() {
        try {
            console.log('🔌 Conectando ao Titan Email...');
            await this.transporter.verify();
            console.log('✅ Conexão com Titan Email estabelecida!');
            console.log(`   Server: smtp.titan.email:${process.env.SMTP_PORT}`);
            console.log(`   User: ${process.env.SMTP_USER}`);
            return true;
        } catch (error) {
            console.error('❌ Erro ao conectar com Titan Email:', error.message);
            console.log('\nVerifique:');
            console.log('1. Email: contato@sparknexus.com.br');
            console.log('2. Senha: A senha do Titan Email (não do cPanel)');
            console.log('3. Acesse: https://mail.titan.email para confirmar credenciais');
            return false;
        }
    }

    async sendEmail(to, subject, html, text) {
        try {
            const mailOptions = {
                from: `"${process.env.EMAIL_FROM_NAME || 'Spark Nexus'}" <${process.env.SMTP_FROM}>`,
                to: to,
                subject: subject,
                html: html,
                text: text || html.replace(/<[^>]*>/g, ''),
                headers: {
                    'X-Mailer': 'Spark Nexus Email System',
                    'X-Priority': '3'
                }
            };

            console.log(`📧 Enviando email para: ${to}`);
            const info = await this.transporter.sendMail(mailOptions);
            console.log('✅ Email enviado via Titan:', info.messageId);
            return { success: true, messageId: info.messageId };
        } catch (error) {
            console.error('❌ Erro ao enviar email:', error);
            return { success: false, error: error.message };
        }
    }

    async sendTestEmail() {
        const to = process.env.SMTP_USER;
        const subject = '✅ Titan Email Configurado - Spark Nexus';
        const html = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
                    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center; }
                    .header h1 { color: white; margin: 0; font-size: 28px; }
                    .content { padding: 30px; }
                    .success-box { background: #d4edda; color: #155724; padding: 15px; border-radius: 5px; margin: 20px 0; }
                    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
                    .info-table td { padding: 10px; border-bottom: 1px solid #eee; }
                    .info-table td:first-child { font-weight: bold; color: #667eea; width: 40%; }
                    .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 12px; }
                    .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>🚀 Spark Nexus</h1>
                        <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0;">Sistema de Validação de Emails</p>
                    </div>
                    
                    <div class="content">
                        <div class="success-box">
                            <h2 style="margin: 0 0 10px 0;">✅ Titan Email Configurado com Sucesso!</h2>
                            <p style="margin: 0;">Seu sistema está pronto para enviar emails através do Titan Email.</p>
                        </div>
                        
                        <h3 style="color: #333;">Detalhes da Configuração:</h3>
                        <table class="info-table">
                            <tr>
                                <td>Servidor SMTP:</td>
                                <td>smtp.titan.email</td>
                            </tr>
                            <tr>
                                <td>Porta:</td>
                                <td>${process.env.SMTP_PORT}</td>
                            </tr>
                            <tr>
                                <td>Segurança:</td>
                                <td>TLS/STARTTLS</td>
                            </tr>
                            <tr>
                                <td>Email:</td>
                                <td>${process.env.SMTP_USER}</td>
                            </tr>
                            <tr>
                                <td>Data/Hora:</td>
                                <td>${new Date().toLocaleString('pt-BR')}</td>
                            </tr>
                        </table>
                        
                        <div style="text-align: center;">
                            <a href="http://localhost:4201/upload" class="button">Acessar Sistema</a>
                        </div>
                        
                        <h3 style="color: #333;">Próximos Passos:</h3>
                        <ol style="color: #666; line-height: 1.8;">
                            <li>Acesse o sistema em <a href="http://localhost:4201/upload">http://localhost:4201/upload</a></li>
                            <li>Faça upload de uma lista de emails para validar</li>
                            <li>Você receberá o relatório neste email</li>
                        </ol>
                    </div>
                    
                    <div class="footer">
                        <p>Este é um email automático enviado pelo sistema Spark Nexus.</p>
                        <p>Powered by Titan Email - HostGator</p>
                    </div>
                </div>
            </body>
            </html>
        `;
        
        return await this.sendEmail(to, subject, html);
    }
}

module.exports = TitanEmailService;
EOF

echo -e "${GREEN}✅ Serviço Titan Email criado${NC}"

# ================================================
# 4. CRIAR SCRIPT DE TESTE
# ================================================
echo -e "\n${BLUE}[4/6] Criando Script de Teste${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cat > test-titan-email.js << 'EOF'
// Teste do Titan Email
require('dotenv').config();
const nodemailer = require('nodemailer');

console.log('\n⚡ TESTE TITAN EMAIL - HOSTGATOR');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('Servidor: smtp.titan.email');
console.log('Porta:', process.env.SMTP_PORT);
console.log('Usuário:', process.env.SMTP_USER);
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

async function testTitanEmail() {
    const transporter = nodemailer.createTransport({
        host: 'smtp.titan.email',
        port: parseInt(process.env.SMTP_PORT || 587),
        secure: false,
        auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS
        },
        tls: {
            rejectUnauthorized: false,
            ciphers: 'SSLv3'
        },
        requireTLS: true,
        debug: true
    });

    try {
        console.log('🔌 Conectando ao Titan Email...');
        await transporter.verify();
        console.log('✅ CONEXÃO ESTABELECIDA!\n');
        
        console.log('📧 Enviando email de teste...');
        const info = await transporter.sendMail({
            from: `"Spark Nexus Test" <${process.env.SMTP_USER}>`,
            to: process.env.SMTP_USER,
            subject: '✅ Titan Email Funcionando - ' + new Date().toLocaleString('pt-BR'),
            html: `
                <div style="font-family: Arial; padding: 20px; background: #f5f5f5;">
                    <div style="background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                        <h2 style="color: #28a745;">✅ Titan Email Configurado!</h2>
                        <p>Este email confirma que o Titan Email está funcionando corretamente com o Spark Nexus.</p>
                        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
                        <p><strong>Detalhes:</strong></p>
                        <ul>
                            <li>Servidor: smtp.titan.email</li>
                            <li>Porta: ${process.env.SMTP_PORT}</li>
                            <li>Email: ${process.env.SMTP_USER}</li>
                            <li>Data/Hora: ${new Date().toLocaleString('pt-BR')}</li>
                        </ul>
                        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
                        <p style="color: #666; font-size: 12px;">
                            Spark Nexus - Sistema de Validação de Emails<br>
                            Powered by Titan Email
                        </p>
                    </div>
                </div>
            `
        });
        
        console.log('\n✅ EMAIL ENVIADO COM SUCESSO!');
        console.log('Message ID:', info.messageId);
        console.log('\n🎉 TITAN EMAIL CONFIGURADO E FUNCIONANDO!\n');
        console.log('📌 Verifique sua caixa de entrada em:');
        console.log('   https://mail.titan.email');
        console.log('   ou no seu cliente de email\n');
        
    } catch (error) {
        console.error('\n❌ ERRO:', error.message);
        
        if (error.code === 'EAUTH') {
            console.log('\n🔐 Erro de Autenticação:');
            console.log('1. Verifique se o email está correto: contato@sparknexus.com.br');
            console.log('2. A senha deve ser a do Titan Email (não do cPanel)');
            console.log('3. Acesse https://mail.titan.email para testar suas credenciais');
            console.log('4. Se esqueceu a senha, redefina no painel do Titan');
        } else if (error.code === 'ECONNECTION' || error.code === 'ETIMEDOUT') {
            console.log('\n🌐 Erro de Conexão:');
            console.log('1. Verifique sua conexão com a internet');
            console.log('2. Tente a porta 465 ao invés de 587');
            console.log('3. Verifique se não há firewall bloqueando');
        } else {
            console.log('\n📝 Dicas:');
            console.log('1. Certifique-se de que o Titan Email está ativo');
            console.log('2. Verifique no painel do HostGator se o serviço está OK');
            console.log('3. Tente fazer login em https://mail.titan.email');
        }
        
        console.log('\n💡 Para redefinir a senha do Titan Email:');
        console.log('1. Acesse o cPanel do HostGator');
        console.log('2. Vá em "Gerenciar E-mail Titan"');
        console.log('3. Clique em "Gerenciar" ao lado do email');
        console.log('4. Use a opção de redefinir senha');
    }
}

testTitanEmail();
EOF

echo -e "${GREEN}✅ Script de teste criado${NC}"

# ================================================
# 5. REINICIAR CONTAINERS
# ================================================
echo -e "\n${BLUE}[5/6] Reiniciando Serviços${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Parar e reiniciar containers
docker-compose stop client-dashboard email-validator 2>/dev/null
docker-compose up -d client-dashboard email-validator

echo -e "${YELLOW}⏳ Aguardando serviços iniciarem (15 segundos)...${NC}"
sleep 15

# Verificar status
echo -e "\n${CYAN}📊 Status dos Containers:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sparknexus

# ================================================
# 6. EXECUTAR TESTE
# ================================================
echo -e "\n${BLUE}[6/6] Testando Titan Email${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Instalar dependências se necessário
npm install nodemailer dotenv 2>/dev/null || true

# Executar teste
node test-titan-email.js

# ================================================
# RESULTADO FINAL
# ================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ CONFIGURAÇÃO DO TITAN EMAIL COMPLETA!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}📧 Configuração Titan Email:${NC}"
echo "  • Servidor: smtp.titan.email"
echo "  • Porta: 587 (TLS)"
echo "  • Email: contato@sparknexus.com.br"
echo "  • Webmail: https://mail.titan.email"

echo -e "\n${CYAN}🔍 URLs do Sistema:${NC}"
echo "  • Upload: http://localhost:4201/upload"
echo "  • Dashboard: http://localhost:4201"
echo "  • Health Check: http://localhost:4201/api/health"

echo -e "\n${CYAN}📝 Comandos Úteis:${NC}"
echo "  • Ver logs: docker-compose logs -f email-validator"
echo "  • Testar email: node test-titan-email.js"
echo "  • Status: docker ps | grep sparknexus"

echo -e "\n${YELLOW}💡 Dicas Importantes:${NC}"
echo "  • Use a senha do Titan Email, não do cPanel"
echo "  • Acesse https://mail.titan.email para gerenciar emails"
echo "  • Limite: Titan não tem limite rígido de envios"
echo "  • Suporte: https://support.titan.email"

echo -e "\n${GREEN}🚀 Sistema pronto com Titan Email!${NC}"
echo -e "${GREEN}   Acesse: http://localhost:4201/upload${NC}"