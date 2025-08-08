#!/bin/bash

# ================================================
# Script 2: Setup Sistema de Cadastro Completo
# Spark Nexus - CPF/CNPJ, Telefone, Validações
# ================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}📝 Setup Sistema de Cadastro Completo${NC}"
echo -e "${BLUE}================================================${NC}"

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Erro: Execute este script no diretório raiz do spark-nexus${NC}"
    exit 1
fi

# ================================================
# 1. ATUALIZAR PACKAGE.JSON DO CLIENT DASHBOARD
# ================================================
echo -e "${YELLOW}📦 Atualizando dependências...${NC}"

cat > core/client-dashboard/package.json << 'EOF'
{
  "name": "sparknexus-client-dashboard",
  "version": "2.0.0",
  "description": "Client Dashboard for Spark Nexus with Full Authentication",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "multer": "^1.4.5-lts.1",
    "axios": "^1.6.0",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "dotenv": "^16.0.3",
    "pg": "^8.11.3",
    "redis": "^4.6.10",
    "nodemailer": "^6.9.7",
    "twilio": "^4.19.0",
    "express-validator": "^7.0.1",
    "express-rate-limit": "^7.1.5",
    "helmet": "^7.1.0",
    "morgan": "^1.10.0",
    "uuid": "^9.0.1",
    "cpf-cnpj-validator": "^1.0.3"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

# ================================================
# 2. CRIAR SERVIÇO DE VALIDAÇÃO (validators.js)
# ================================================
echo -e "${YELLOW}🔍 Criando validadores...${NC}"

mkdir -p core/client-dashboard/services

cat > core/client-dashboard/services/validators.js << 'EOF'
// ================================================
// Validadores para CPF, CNPJ, Email e Telefone
// ================================================

const { cpf, cnpj } = require('cpf-cnpj-validator');

class Validators {
    // Validar CPF ou CNPJ
    static validateCpfCnpj(value) {
        // Remove caracteres não numéricos
        const cleaned = value.replace(/[^\d]/g, '');
        
        if (cleaned.length === 11) {
            // É CPF
            return {
                valid: cpf.isValid(cleaned),
                type: 'CPF',
                formatted: cpf.format(cleaned)
            };
        } else if (cleaned.length === 14) {
            // É CNPJ
            return {
                valid: cnpj.isValid(cleaned),
                type: 'CNPJ',
                formatted: cnpj.format(cleaned)
            };
        } else {
            return {
                valid: false,
                type: null,
                formatted: null,
                error: 'Documento deve ter 11 dígitos (CPF) ou 14 dígitos (CNPJ)'
            };
        }
    }

    // Validar email
    static validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        const valid = emailRegex.test(email);
        
        // Verificar domínios descartáveis comuns
        const disposableDomains = [
            'tempmail.com', 'throwaway.email', '10minutemail.com',
            'guerrillamail.com', 'mailinator.com', 'temp-mail.org'
        ];
        
        const domain = email.split('@')[1]?.toLowerCase();
        const isDisposable = disposableDomains.includes(domain);
        
        return {
            valid: valid && !isDisposable,
            isDisposable,
            domain
        };
    }

    // Validar telefone brasileiro
    static validatePhone(phone) {
        // Remove caracteres não numéricos
        const cleaned = phone.replace(/[^\d]/g, '');
        
        // Telefone brasileiro deve ter 10 ou 11 dígitos
        if (cleaned.length === 10 || cleaned.length === 11) {
            // Verifica se começa com DDD válido (11-99)
            const ddd = parseInt(cleaned.substring(0, 2));
            if (ddd >= 11 && ddd <= 99) {
                // Formatar telefone
                let formatted;
                if (cleaned.length === 11) {
                    // Celular: (XX) 9XXXX-XXXX
                    formatted = `(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 7)}-${cleaned.substring(7)}`;
                } else {
                    // Fixo: (XX) XXXX-XXXX
                    formatted = `(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 6)}-${cleaned.substring(6)}`;
                }
                
                return {
                    valid: true,
                    type: cleaned.length === 11 ? 'mobile' : 'landline',
                    formatted,
                    ddd
                };
            }
        }
        
        return {
            valid: false,
            error: 'Telefone deve ter 10 ou 11 dígitos com DDD válido'
        };
    }

    // Validar senha forte
    static validatePassword(password) {
        const minLength = 8;
        const hasUpperCase = /[A-Z]/.test(password);
        const hasLowerCase = /[a-z]/.test(password);
        const hasNumbers = /\d/.test(password);
        const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);
        
        const strength = {
            length: password.length >= minLength,
            uppercase: hasUpperCase,
            lowercase: hasLowerCase,
            numbers: hasNumbers,
            special: hasSpecialChar
        };
        
        const score = Object.values(strength).filter(Boolean).length;
        
        return {
            valid: score >= 4,
            strength,
            score,
            level: score <= 2 ? 'weak' : score <= 3 ? 'medium' : 'strong'
        };
    }

    // Gerar token aleatório
    static generateToken(length = 6, type = 'numeric') {
        const numeric = '0123456789';
        const alphanumeric = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
        
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

# ================================================
# 3. CRIAR SERVIÇO DE EMAIL
# ================================================
echo -e "${YELLOW}📧 Criando serviço de email...${NC}"

cat > core/client-dashboard/services/emailService.js << 'EOF'
// ================================================
// Serviço de Email com Nodemailer
// ================================================

const nodemailer = require('nodemailer');

class EmailService {
    constructor() {
        this.transporter = nodemailer.createTransport({
            host: process.env.SMTP_HOST || 'smtp.gmail.com',
            port: parseInt(process.env.SMTP_PORT || '587'),
            secure: process.env.SMTP_SECURE === 'true',
            auth: {
                user: process.env.SMTP_USER,
                pass: process.env.SMTP_PASS
            }
        });
    }

    // Enviar email de verificação
    async sendVerificationEmail(to, token, name) {
        const verificationUrl = `${process.env.APP_URL || 'http://localhost:4201'}/verify-email?token=${token}`;
        
        const mailOptions = {
            from: `"Spark Nexus" <${process.env.SMTP_USER}>`,
            to,
            subject: '🔐 Verificação de Email - Spark Nexus',
            html: `
                <!DOCTYPE html>
                <html>
                <head>
                    <style>
                        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                        .content { background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }
                        .token-box { background: white; border: 2px dashed #667eea; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px; }
                        .token { font-size: 32px; font-weight: bold; color: #667eea; letter-spacing: 5px; }
                        .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
                        .footer { text-align: center; color: #666; font-size: 12px; margin-top: 20px; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="header">
                            <h1>🚀 Spark Nexus</h1>
                            <p>Verificação de Email</p>
                        </div>
                        <div class="content">
                            <h2>Olá ${name}!</h2>
                            <p>Obrigado por se cadastrar no Spark Nexus. Para completar seu cadastro, precisamos verificar seu email.</p>
                            
                            <div class="token-box">
                                <p>Seu código de verificação é:</p>
                                <div class="token">${token}</div>
                            </div>
                            
                            <p>Ou clique no botão abaixo:</p>
                            <div style="text-align: center;">
                                <a href="${verificationUrl}" class="button">Verificar Email</a>
                            </div>
                            
                            <p><strong>⏰ Este código expira em 30 minutos.</strong></p>
                            
                            <div class="footer">
                                <p>Se você não solicitou este email, pode ignorá-lo com segurança.</p>
                                <p>© 2024 Spark Nexus. Todos os direitos reservados.</p>
                            </div>
                        </div>
                    </div>
                </body>
                </html>
            `
        };

        try {
            const info = await this.transporter.sendMail(mailOptions);
            console.log('Email enviado:', info.messageId);
            return { success: true, messageId: info.messageId };
        } catch (error) {
            console.error('Erro ao enviar email:', error);
            return { success: false, error: error.message };
        }
    }

    // Enviar email de boas-vindas
    async sendWelcomeEmail(to, name) {
        const mailOptions = {
            from: `"Spark Nexus" <${process.env.SMTP_USER}>`,
            to,
            subject: '🎉 Bem-vindo ao Spark Nexus!',
            html: `
                <!DOCTYPE html>
                <html>
                <head>
                    <style>
                        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                        .content { background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }
                        .feature { background: white; padding: 15px; margin: 10px 0; border-radius: 8px; border-left: 4px solid #667eea; }
                        .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="header">
                            <h1>🚀 Bem-vindo ao Spark Nexus!</h1>
                        </div>
                        <div class="content">
                            <h2>Olá ${name}!</h2>
                            <p>Sua conta foi criada com sucesso! Agora você tem acesso a todas as nossas ferramentas:</p>
                            
                            <div class="feature">
                                <strong>📧 Email Validator</strong>
                                <p>Valide listas de emails em lote com alta precisão</p>
                            </div>
                            
                            <div class="feature">
                                <strong>🔗 CRM Connector</strong>
                                <p>Integre com os principais CRMs do mercado</p>
                            </div>
                            
                            <div class="feature">
                                <strong>🎯 Lead Scorer AI</strong>
                                <p>Score automático de leads com Machine Learning</p>
                            </div>
                            
                            <div style="text-align: center;">
                                <a href="http://localhost:4201" class="button">Acessar Dashboard</a>
                            </div>
                            
                            <p>Qualquer dúvida, estamos à disposição!</p>
                            <p>Equipe Spark Nexus</p>
                        </div>
                    </div>
                </body>
                </html>
            `
        };

        try {
            await this.transporter.sendMail(mailOptions);
            return { success: true };
        } catch (error) {
            console.error('Erro ao enviar email de boas-vindas:', error);
            return { success: false, error: error.message };
        }
    }
}

module.exports = EmailService;
EOF

# ================================================
# 4. CRIAR SERVIÇO DE SMS
# ================================================
echo -e "${YELLOW}📱 Criando serviço de SMS...${NC}"

cat > core/client-dashboard/services/smsService.js << 'EOF'
// ================================================
// Serviço de SMS com Twilio
// ================================================

const twilio = require('twilio');

class SMSService {
    constructor() {
        // Inicializar Twilio se as credenciais estiverem configuradas
        if (process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN) {
            this.client = twilio(
                process.env.TWILIO_ACCOUNT_SID,
                process.env.TWILIO_AUTH_TOKEN
            );
            this.fromNumber = process.env.TWILIO_PHONE_NUMBER;
            this.whatsappNumber = process.env.TWILIO_WHATSAPP_NUMBER;
            this.enabled = true;
        } else {
            console.log('⚠️  Twilio não configurado - SMS em modo demo');
            this.enabled = false;
        }
    }

    // Enviar SMS de verificação
    async sendVerificationSMS(to, token) {
        const message = `🚀 Spark Nexus\n\nSeu código de verificação é: ${token}\n\nVálido por 10 minutos.`;

        if (!this.enabled) {
            console.log(`[DEMO SMS] Para: ${to}`);
            console.log(`[DEMO SMS] Mensagem: ${message}`);
            return { 
                success: true, 
                demo: true, 
                token,
                message: 'SMS enviado (modo demo)' 
            };
        }

        try {
            // Formatar número para padrão internacional
            const formattedNumber = this.formatPhoneNumber(to);
            
            const result = await this.client.messages.create({
                body: message,
                from: this.fromNumber,
                to: formattedNumber
            });

            console.log(`SMS enviado: ${result.sid}`);
            return { 
                success: true, 
                sid: result.sid,
                to: formattedNumber
            };
        } catch (error) {
            console.error('Erro ao enviar SMS:', error);
            return { 
                success: false, 
                error: error.message 
            };
        }
    }

    // Enviar WhatsApp de verificação
    async sendVerificationWhatsApp(to, token) {
        const message = `🚀 *Spark Nexus*\n\nSeu código de verificação é:\n\n*${token}*\n\n_Válido por 10 minutos._`;

        if (!this.enabled) {
            console.log(`[DEMO WhatsApp] Para: ${to}`);
            console.log(`[DEMO WhatsApp] Mensagem: ${message}`);
            return { 
                success: true, 
                demo: true, 
                token,
                message: 'WhatsApp enviado (modo demo)' 
            };
        }

        try {
            const formattedNumber = this.formatPhoneNumber(to);
            
            const result = await this.client.messages.create({
                body: message,
                from: this.whatsappNumber || 'whatsapp:+14155238886', // Número sandbox do Twilio
                to: `whatsapp:${formattedNumber}`
            });

            console.log(`WhatsApp enviado: ${result.sid}`);
            return { 
                success: true, 
                sid: result.sid,
                to: formattedNumber
            };
        } catch (error) {
            console.error('Erro ao enviar WhatsApp:', error);
            // Tentar SMS como fallback
            return this.sendVerificationSMS(to, token);
        }
    }

    // Formatar número de telefone para padrão internacional
    formatPhoneNumber(phone) {
        // Remove caracteres não numéricos
        let cleaned = phone.replace(/[^\d]/g, '');
        
        // Se não começar com código do país, adicionar +55 (Brasil)
        if (!cleaned.startsWith('55')) {
            cleaned = '55' + cleaned;
        }
        
        return '+' + cleaned;
    }

    // Verificar se número pode receber WhatsApp
    async checkWhatsAppCapability(phone) {
        if (!this.enabled) {
            return { capable: true, demo: true };
        }

        try {
            const formattedNumber = this.formatPhoneNumber(phone);
            // Aqui você pode implementar verificação real via Twilio API
            return { capable: true, number: formattedNumber };
        } catch (error) {
            return { capable: false, error: error.message };
        }
    }
}

module.exports = SMSService;
EOF

# ================================================
# 5. CRIAR SERVIÇO DE BANCO DE DADOS
# ================================================
echo -e "${YELLOW}🗄️  Criando serviço de banco de dados...${NC}"

cat > core/client-dashboard/services/database.js << 'EOF'
// ================================================
// Serviço de Banco de Dados PostgreSQL
// ================================================

const { Pool } = require('pg');
const redis = require('redis');
const bcrypt = require('bcryptjs');

class DatabaseService {
    constructor() {
        // Configurar PostgreSQL
        this.pool = new Pool({
            connectionString: process.env.DATABASE_URL || 'postgresql://sparknexus:SparkDB2024!@localhost:5432/sparknexus',
            ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
        });

        // Configurar Redis
        this.setupRedis();
    }

    async setupRedis() {
        this.redis = redis.createClient({
            url: process.env.REDIS_URL || 'redis://:SparkRedis2024!@localhost:6379'
        });

        this.redis.on('error', (err) => console.error('Redis Error:', err));
        
        try {
            await this.redis.connect();
            console.log('✅ Redis conectado');
        } catch (error) {
            console.error('❌ Erro ao conectar Redis:', error);
        }
    }

    // ================================================
    // USUÁRIOS
    // ================================================

    // Criar usuário
    async createUser(userData) {
        const client = await this.pool.connect();
        
        try {
            await client.query('BEGIN');

            // Hash da senha
            const passwordHash = await bcrypt.hash(userData.password, 10);

            // Inserir usuário
            const query = `
                INSERT INTO auth.users (
                    email, password_hash, first_name, last_name, 
                    cpf_cnpj, phone, company,
                    email_verification_token, phone_verification_token,
                    email_token_expires, phone_token_expires
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                RETURNING id, email, first_name, last_name, company
            `;

            const tokenExpiry = new Date();
            tokenExpiry.setMinutes(tokenExpiry.getMinutes() + 30);

            const phoneTokenExpiry = new Date();
            phoneTokenExpiry.setMinutes(phoneTokenExpiry.getMinutes() + 10);

            const result = await client.query(query, [
                userData.email.toLowerCase(),
                passwordHash,
                userData.firstName,
                userData.lastName,
                userData.cpfCnpj,
                userData.phone,
                userData.company,
                userData.emailToken,
                userData.phoneToken,
                tokenExpiry,
                phoneTokenExpiry
            ]);

            // Criar organização para o usuário
            const orgQuery = `
                INSERT INTO tenant.organizations (name, slug, cnpj)
                VALUES ($1, $2, $3)
                RETURNING id
            `;

            const slug = userData.company.toLowerCase()
                .replace(/[^\w\s-]/g, '')
                .replace(/\s+/g, '-');

            const orgResult = await client.query(orgQuery, [
                userData.company,
                slug + '-' + Date.now(),
                userData.cpfCnpj.length === 14 ? userData.cpfCnpj : null
            ]);

            // Associar usuário à organização
            await client.query(
                `INSERT INTO tenant.organization_members (organization_id, user_id, role)
                 VALUES ($1, $2, 'owner')`,
                [orgResult.rows[0].id, result.rows[0].id]
            );

            await client.query('COMMIT');

            return {
                success: true,
                user: result.rows[0],
                organizationId: orgResult.rows[0].id
            };
        } catch (error) {
            await client.query('ROLLBACK');
            console.error('Erro ao criar usuário:', error);
            
            if (error.code === '23505') {
                if (error.constraint === 'users_email_key') {
                    throw new Error('Email já cadastrado');
                }
                if (error.constraint === 'users_cpf_cnpj_key') {
                    throw new Error('CPF/CNPJ já cadastrado');
                }
            }
            
            throw error;
        } finally {
            client.release();
        }
    }

    // Buscar usuário por email
    async getUserByEmail(email) {
        const query = `
            SELECT id, email, password_hash, first_name, last_name, 
                   cpf_cnpj, phone, company, email_verified, phone_verified
            FROM auth.users
            WHERE email = $1
        `;

        const result = await this.pool.query(query, [email.toLowerCase()]);
        return result.rows[0];
    }

    // Verificar email
    async verifyEmail(token) {
        const query = `
            UPDATE auth.users
            SET email_verified = true,
                email_verification_token = NULL,
                email_token_expires = NULL
            WHERE email_verification_token = $1
                AND email_token_expires > NOW()
            RETURNING id, email, first_name
        `;

        const result = await this.pool.query(query, [token]);
        return result.rows[0];
    }

    // Verificar telefone
    async verifyPhone(userId, token) {
        const query = `
            UPDATE auth.users
            SET phone_verified = true,
                phone_verification_token = NULL,
                phone_token_expires = NULL
            WHERE id = $1 
                AND phone_verification_token = $2
                AND phone_token_expires > NOW()
            RETURNING id, phone
        `;

        const result = await this.pool.query(query, [userId, token]);
        return result.rows[0];
    }

    // Criar sessão
    async createSession(userId, token, ipAddress, userAgent) {
        const expires = new Date();
        expires.setHours(expires.getHours() + 24);

        const query = `
            INSERT INTO auth.sessions (user_id, token, ip_address, user_agent, expires_at)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id
        `;

        const result = await this.pool.query(query, [
            userId, token, ipAddress, userAgent, expires
        ]);

        // Salvar no Redis para acesso rápido
        if (this.redis && this.redis && this.redis.isOpen) {
            await this.redis.setEx(`session:${token}`, 86400, JSON.stringify({
                userId, ipAddress, userAgent
            }));
        }

        return result.rows[0];
    }

    // Validar sessão
    async validateSession(token) {
        // Primeiro verificar no Redis
        if (this.redis && this.redis.isOpen) {
            const cached = await this.redis.get(`session:${token}`);
            if (cached) {
                return JSON.parse(cached);
            }
        }

        // Se não estiver no cache, buscar no banco
        const query = `
            SELECT s.*, u.email, u.first_name, u.last_name
            FROM auth.sessions s
            JOIN auth.users u ON s.user_id = u.id
            WHERE s.token = $1 AND s.expires_at > NOW()
        `;

        const result = await this.pool.query(query, [token]);
        
        if (result.rows[0] && this.redis && this.redis.isOpen) {
            // Cachear para próximas requisições
            await this.redis.setEx(`session:${token}`, 3600, JSON.stringify(result.rows[0]));
        }

        return result.rows[0];
    }

    // Registrar tentativa de login
    async logLoginAttempt(email, ipAddress, success) {
        const query = `
            INSERT INTO auth.login_attempts (email, ip_address, success)
            VALUES ($1, $2, $3)
        `;

        await this.pool.query(query, [email, ipAddress, success]);
    }

    // Verificar tentativas de login
    async checkLoginAttempts(email, ipAddress) {
        const query = `
            SELECT COUNT(*) as attempts
            FROM auth.login_attempts
            WHERE (email = $1 OR ip_address = $2)
                AND success = false
                AND attempted_at > NOW() - INTERVAL '15 minutes'
        `;

        const result = await this.pool.query(query, [email, ipAddress]);
        return parseInt(result.rows[0].attempts);
    }

    // Limpar dados expirados
    async cleanupExpiredData() {
        // Limpar sessões expiradas
        await this.pool.query(
            `DELETE FROM auth.sessions WHERE expires_at < NOW()`
        );

        // Limpar tokens de verificação expirados
        await this.pool.query(`
            UPDATE auth.users
            SET email_verification_token = NULL
            WHERE email_token_expires < NOW() AND email_verification_token IS NOT NULL
        `);

        await this.pool.query(`
            UPDATE auth.users
            SET phone_verification_token = NULL
            WHERE phone_token_expires < NOW() AND phone_verification_token IS NOT NULL
        `);
    }
}

module.exports = DatabaseService;
EOF

# ================================================
# 6. CRIAR DOCKERFILE ATUALIZADO
# ================================================
echo -e "${YELLOW}🐳 Criando Dockerfile...${NC}"

cat > core/client-dashboard/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copiar package.json
COPY package*.json ./

# Instalar dependências
RUN npm install

# Copiar código
COPY . .

# Criar diretório de uploads
RUN mkdir -p uploads

EXPOSE 4201

CMD ["node", "server.js"]
EOF

# ================================================
# 7. CRIAR NOVA PÁGINA DE REGISTRO
# ================================================
echo -e "${YELLOW}📝 Criando página de registro completa...${NC}"

cat > core/client-dashboard/public/register.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cadastro - Spark Nexus</title>
    <link rel="stylesheet" href="/css/style.css">
    <style>
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 20px 0;
        }
        
        .register-container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
            width: 600px;
            max-width: 90%;
        }
        
        .register-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 30px;
            text-align: center;
        }
        
        .register-header h1 {
            color: white;
            font-size: 28px;
            margin-bottom: 10px;
        }
        
        .register-form {
            padding: 30px;
        }
        
        .form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
        }
        
        .btn-register {
            width: 100%;
            margin-top: 20px;
        }
        
        .steps {
            display: flex;
            justify-content: space-between;
            margin-bottom: 30px;
        }
        
        .step {
            flex: 1;
            text-align: center;
            padding: 10px;
            background: #f0f0f0;
            margin: 0 5px;
            border-radius: 5px;
            position: relative;
        }
        
        .step.active {
            background: #667eea;
            color: white;
        }
        
        .step.completed {
            background: #48bb78;
            color: white;
        }
        
        .step-content {
            display: none;
        }
        
        .step-content.active {
            display: block;
        }
        
        .password-strength {
            margin-top: 10px;
            height: 5px;
            background: #e0e0e0;
            border-radius: 3px;
            overflow: hidden;
        }
        
        .password-strength-bar {
            height: 100%;
            transition: all 0.3s;
            border-radius: 3px;
        }
        
        .strength-weak { background: #f56565; width: 33%; }
        .strength-medium { background: #ed8936; width: 66%; }
        .strength-strong { background: #48bb78; width: 100%; }
        
        .verification-input {
            display: flex;
            justify-content: space-between;
            margin: 20px 0;
        }
        
        .verification-input input {
            width: 50px;
            height: 50px;
            text-align: center;
            font-size: 24px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
        }
        
        .error-text {
            color: #f56565;
            font-size: 12px;
            margin-top: 5px;
        }
        
        .success-text {
            color: #48bb78;
            font-size: 12px;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="register-container">
        <div class="register-header">
            <h1>🚀 Criar Conta</h1>
            <p style="color: rgba(255,255,255,0.8);">Complete seu cadastro em 3 passos</p>
        </div>
        
        <div class="register-form">
            <!-- Progress Steps -->
            <div class="steps">
                <div class="step active" id="step1-indicator">
                    <strong>1</strong><br>Dados Pessoais
                </div>
                <div class="step" id="step2-indicator">
                    <strong>2</strong><br>Verificação Email
                </div>
                <div class="step" id="step3-indicator">
                    <strong>3</strong><br>Verificação Telefone
                </div>
            </div>
            
            <div id="alertBox" class="alert"></div>
            
            <!-- Step 1: Dados Pessoais -->
            <div class="step-content active" id="step1">
                <form id="registerForm">
                    <div class="form-row">
                        <div class="form-group">
                            <label for="firstName">Nome *</label>
                            <input type="text" id="firstName" name="firstName" required>
                            <span class="error-text" id="firstNameError"></span>
                        </div>
                        
                        <div class="form-group">
                            <label for="lastName">Sobrenome *</label>
                            <input type="text" id="lastName" name="lastName" required>
                            <span class="error-text" id="lastNameError"></span>
                        </div>
                    </div>
                    
                    <div class="form-group">
                        <label for="cpfCnpj">CPF ou CNPJ *</label>
                        <input type="text" id="cpfCnpj" name="cpfCnpj" required placeholder="Digite apenas números">
                        <span class="error-text" id="cpfCnpjError"></span>
                        <span class="success-text" id="cpfCnpjSuccess"></span>
                    </div>
                    
                    <div class="form-group">
                        <label for="email">Email *</label>
                        <input type="email" id="email" name="email" required>
                        <span class="error-text" id="emailError"></span>
                    </div>
                    
                    <div class="form-group">
                        <label for="phone">Telefone/WhatsApp *</label>
                        <input type="tel" id="phone" name="phone" required placeholder="(11) 98765-4321">
                        <span class="error-text" id="phoneError"></span>
                        <span class="success-text" id="phoneSuccess"></span>
                    </div>
                    
                    <div class="form-group">
                        <label for="company">Empresa *</label>
                        <input type="text" id="company" name="company" required>
                        <span class="error-text" id="companyError"></span>
                    </div>
                    
                    <div class="form-row">
                        <div class="form-group">
                            <label for="password">Senha *</label>
                            <input type="password" id="password" name="password" required minlength="8">
                            <div class="password-strength">
                                <div class="password-strength-bar" id="passwordStrengthBar"></div>
                            </div>
                            <span class="error-text" id="passwordError"></span>
                        </div>
                        
                        <div class="form-group">
                            <label for="confirmPassword">Confirmar Senha *</label>
                            <input type="password" id="confirmPassword" name="confirmPassword" required>
                            <span class="error-text" id="confirmPasswordError"></span>
                        </div>
                    </div>
                    
                    <button type="submit" class="btn btn-primary btn-register">
                        Continuar para Verificação →
                    </button>
                </form>
            </div>
            
            <!-- Step 2: Verificação de Email -->
            <div class="step-content" id="step2">
                <h3>📧 Verificação de Email</h3>
                <p>Enviamos um código de verificação para: <strong id="emailDisplay"></strong></p>
                
                <div class="verification-input" id="emailVerification">
                    <input type="text" maxlength="1" class="email-code" data-index="0">
                    <input type="text" maxlength="1" class="email-code" data-index="1">
                    <input type="text" maxlength="1" class="email-code" data-index="2">
                    <input type="text" maxlength="1" class="email-code" data-index="3">
                    <input type="text" maxlength="1" class="email-code" data-index="4">
                    <input type="text" maxlength="1" class="email-code" data-index="5">
                </div>
                
                <button class="btn btn-primary" onclick="verifyEmail()" style="width: 100%;">
                    Verificar Email
                </button>
                
                <p style="text-align: center; margin-top: 20px;">
                    Não recebeu? <a href="#" onclick="resendEmailCode()">Reenviar código</a>
                </p>
            </div>
            
            <!-- Step 3: Verificação de Telefone -->
            <div class="step-content" id="step3">
                <h3>📱 Verificação de Telefone</h3>
                <p>Enviamos um código via SMS/WhatsApp para: <strong id="phoneDisplay"></strong></p>
                
                <div class="verification-input" id="phoneVerification">
                    <input type="text" maxlength="1" class="phone-code" data-index="0">
                    <input type="text" maxlength="1" class="phone-code" data-index="1">
                    <input type="text" maxlength="1" class="phone-code" data-index="2">
                    <input type="text" maxlength="1" class="phone-code" data-index="3">
                    <input type="text" maxlength="1" class="phone-code" data-index="4">
                    <input type="text" maxlength="1" class="phone-code" data-index="5">
                </div>
                
                <button class="btn btn-primary" onclick="verifyPhone()" style="width: 100%;">
                    Verificar Telefone
                </button>
                
                <p style="text-align: center; margin-top: 20px;">
                    Não recebeu? 
                    <a href="#" onclick="resendPhoneCode('sms')">Reenviar SMS</a> | 
                    <a href="#" onclick="resendPhoneCode('whatsapp')">Enviar via WhatsApp</a>
                </p>
            </div>
            
            <div class="login-link" style="text-align: center; margin-top: 20px;">
                Já tem uma conta? <a href="/login">Faça login</a>
            </div>
        </div>
    </div>

    <script src="/js/auth.js"></script>
    <script src="/js/register.js"></script>
</body>
</html>
EOF

# ================================================
# 8. CRIAR JS DO REGISTRO
# ================================================
echo -e "${YELLOW}🔧 Criando JavaScript do registro...${NC}"

cat > core/client-dashboard/public/js/register.js << 'EOF'
// ================================================
// Sistema de Registro Completo
// ================================================

let currentStep = 1;
let userData = {};

// Máscaras e validações
document.addEventListener('DOMContentLoaded', () => {
    setupInputMasks();
    setupPasswordStrength();
    setupVerificationInputs();
});

// Configurar máscaras de input
function setupInputMasks() {
    // Máscara para CPF/CNPJ
    const cpfCnpjInput = document.getElementById('cpfCnpj');
    cpfCnpjInput.addEventListener('input', (e) => {
        let value = e.target.value.replace(/\D/g, '');
        
        // Identificar se é CPF ou CNPJ
        if (value.length <= 11) {
            // CPF: 000.000.000-00
            value = value.replace(/(\d{3})(\d)/, '$1.$2');
            value = value.replace(/(\d{3})(\d)/, '$1.$2');
            value = value.replace(/(\d{3})(\d{1,2})/, '$1-$2');
        } else {
            // CNPJ: 00.000.000/0000-00
            value = value.replace(/(\d{2})(\d)/, '$1.$2');
            value = value.replace(/(\d{3})(\d)/, '$1.$2');
            value = value.replace(/(\d{3})(\d)/, '$1/$2');
            value = value.replace(/(\d{4})(\d)/, '$1-$2');
        }
        
        e.target.value = value;
        validateCpfCnpj(value);
    });
    
    // Máscara para telefone
    const phoneInput = document.getElementById('phone');
    phoneInput.addEventListener('input', (e) => {
        let value = e.target.value.replace(/\D/g, '');
        
        if (value.length <= 11) {
            // Formato: (00) 00000-0000 ou (00) 0000-0000
            value = value.replace(/(\d{2})(\d)/, '($1) $2');
            if (value.length > 10) {
                value = value.replace(/(\d{5})(\d)/, '$1-$2');
            } else {
                value = value.replace(/(\d{4})(\d)/, '$1-$2');
            }
        }
        
        e.target.value = value;
        validatePhone(value);
    });
}

// Validar CPF/CNPJ em tempo real
async function validateCpfCnpj(value) {
    const cleanValue = value.replace(/\D/g, '');
    const errorSpan = document.getElementById('cpfCnpjError');
    const successSpan = document.getElementById('cpfCnpjSuccess');
    
    errorSpan.textContent = '';
    successSpan.textContent = '';
    
    if (cleanValue.length === 11 || cleanValue.length === 14) {
        try {
            const response = await fetch('/api/validate/cpf-cnpj', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ document: cleanValue })
            });
            
            const result = await response.json();
            
            if (result.valid) {
                successSpan.textContent = `✓ ${result.type} válido`;
            } else {
                errorSpan.textContent = result.error || 'Documento inválido';
            }
        } catch (error) {
            console.error('Erro ao validar documento:', error);
        }
    }
}

// Validar telefone em tempo real
async function validatePhone(value) {
    const cleanValue = value.replace(/\D/g, '');
    const errorSpan = document.getElementById('phoneError');
    const successSpan = document.getElementById('phoneSuccess');
    
    errorSpan.textContent = '';
    successSpan.textContent = '';
    
    if (cleanValue.length >= 10) {
        if (cleanValue.length === 10 || cleanValue.length === 11) {
            successSpan.textContent = '✓ Telefone válido';
        } else {
            errorSpan.textContent = 'Telefone inválido';
        }
    }
}

// Configurar medidor de força da senha
function setupPasswordStrength() {
    const passwordInput = document.getElementById('password');
    const strengthBar = document.getElementById('passwordStrengthBar');
    
    passwordInput.addEventListener('input', (e) => {
        const password = e.target.value;
        const strength = calculatePasswordStrength(password);
        
        strengthBar.className = 'password-strength-bar';
        if (strength.score <= 2) {
            strengthBar.classList.add('strength-weak');
        } else if (strength.score <= 3) {
            strengthBar.classList.add('strength-medium');
        } else {
            strengthBar.classList.add('strength-strong');
        }
    });
}

// Calcular força da senha
function calculatePasswordStrength(password) {
    const checks = {
        length: password.length >= 8,
        uppercase: /[A-Z]/.test(password),
        lowercase: /[a-z]/.test(password),
        numbers: /\d/.test(password),
        special: /[!@#$%^&*(),.?":{}|<>]/.test(password)
    };
    
    const score = Object.values(checks).filter(Boolean).length;
    
    return { checks, score };
}

// Configurar inputs de verificação
function setupVerificationInputs() {
    // Email verification
    const emailInputs = document.querySelectorAll('.email-code');
    emailInputs.forEach((input, index) => {
        input.addEventListener('input', (e) => {
            if (e.target.value && index < emailInputs.length - 1) {
                emailInputs[index + 1].focus();
            }
        });
        
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Backspace' && !e.target.value && index > 0) {
                emailInputs[index - 1].focus();
            }
        });
    });
    
    // Phone verification
    const phoneInputs = document.querySelectorAll('.phone-code');
    phoneInputs.forEach((input, index) => {
        input.addEventListener('input', (e) => {
            if (e.target.value && index < phoneInputs.length - 1) {
                phoneInputs[index + 1].focus();
            }
        });
        
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Backspace' && !e.target.value && index > 0) {
                phoneInputs[index - 1].focus();
            }
        });
    });
}

// Handle registro form
document.getElementById('registerForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const alertBox = document.getElementById('alertBox');
    const formData = new FormData(e.target);
    
    // Validar senhas
    if (formData.get('password') !== formData.get('confirmPassword')) {
        document.getElementById('confirmPasswordError').textContent = 'As senhas não coincidem';
        return;
    }
    
    // Validar força da senha
    const strength = calculatePasswordStrength(formData.get('password'));
    if (strength.score < 4) {
        document.getElementById('passwordError').textContent = 'Senha deve ter maiúsculas, minúsculas, números e caracteres especiais';
        return;
    }
    
    // Preparar dados
    userData = {
        firstName: formData.get('firstName'),
        lastName: formData.get('lastName'),
        cpfCnpj: formData.get('cpfCnpj').replace(/\D/g, ''),
        email: formData.get('email'),
        phone: formData.get('phone').replace(/\D/g, ''),
        company: formData.get('company'),
        password: formData.get('password')
    };
    
    try {
        // Enviar para o servidor
        const response = await fetch('/api/auth/register', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(userData)
        });
        
        const result = await response.json();
        
        if (response.ok) {
            // Mostrar email no step 2
            document.getElementById('emailDisplay').textContent = userData.email;
            document.getElementById('phoneDisplay').textContent = formData.get('phone');
            
            // Avançar para step 2
            showStep(2);
        } else {
            alertBox.className = 'alert alert-error';
            alertBox.textContent = result.error || 'Erro ao criar conta';
            alertBox.style.display = 'block';
        }
    } catch (error) {
        alertBox.className = 'alert alert-error';
        alertBox.textContent = 'Erro ao conectar com o servidor';
        alertBox.style.display = 'block';
    }
});

// Mostrar step específico
function showStep(step) {
    currentStep = step;
    
    // Atualizar indicadores
    document.querySelectorAll('.step').forEach((el, index) => {
        if (index < step - 1) {
            el.classList.add('completed');
            el.classList.remove('active');
        } else if (index === step - 1) {
            el.classList.add('active');
            el.classList.remove('completed');
        } else {
            el.classList.remove('active', 'completed');
        }
    });
    
    // Mostrar conteúdo do step
    document.querySelectorAll('.step-content').forEach((el, index) => {
        el.classList.toggle('active', index === step - 1);
    });
}

// Verificar email
async function verifyEmail() {
    const inputs = document.querySelectorAll('.email-code');
    const code = Array.from(inputs).map(i => i.value).join('');
    
    if (code.length !== 6) {
        alert('Digite o código completo');
        return;
    }
    
    try {
        const response = await fetch('/api/auth/verify-email', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                email: userData.email, 
                token: code 
            })
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showStep(3);
        } else {
            alert(result.error || 'Código inválido');
        }
    } catch (error) {
        alert('Erro ao verificar email');
    }
}

// Verificar telefone
async function verifyPhone() {
    const inputs = document.querySelectorAll('.phone-code');
    const code = Array.from(inputs).map(i => i.value).join('');
    
    if (code.length !== 6) {
        alert('Digite o código completo');
        return;
    }
    
    try {
        const response = await fetch('/api/auth/verify-phone', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                email: userData.email, 
                token: code 
            })
        });
        
        const result = await response.json();
        
        if (response.ok) {
            alert('✅ Cadastro completo! Redirecionando para login...');
            setTimeout(() => {
                window.location.href = '/login';
            }, 2000);
        } else {
            alert(result.error || 'Código inválido');
        }
    } catch (error) {
        alert('Erro ao verificar telefone');
    }
}

// Reenviar código de email
async function resendEmailCode() {
    try {
        const response = await fetch('/api/auth/resend-email', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: userData.email })
        });
        
        if (response.ok) {
            alert('Código reenviado para seu email');
        }
    } catch (error) {
        alert('Erro ao reenviar código');
    }
}

// Reenviar código de telefone
async function resendPhoneCode(method) {
    try {
        const response = await fetch('/api/auth/resend-phone', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                email: userData.email,
                phone: userData.phone,
                method: method // 'sms' ou 'whatsapp'
            })
        });
        
        if (response.ok) {
            alert(`Código reenviado via ${method.toUpperCase()}`);
        }
    } catch (error) {
        alert('Erro ao reenviar código');
    }
}
EOF

# ================================================
# 9. REBUILD CONTAINERS
# ================================================
echo -e "${YELLOW}🔄 Reconstruindo containers...${NC}"

docker-compose build client-dashboard
docker-compose up -d client-dashboard

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ SISTEMA DE CADASTRO CONFIGURADO!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}📝 Funcionalidades Implementadas:${NC}"
echo -e "   ✅ Validação de CPF/CNPJ"
echo -e "   ✅ Validação de telefone"
echo -e "   ✅ Medidor de força de senha"
echo -e "   ✅ Verificação por email"
echo -e "   ✅ Verificação por SMS/WhatsApp"
echo -e "   ✅ Cadastro em 3 etapas"
echo ""
echo -e "${YELLOW}⚠️  Próximo passo:${NC}"
echo -e "   Execute: ${GREEN}./03-setup-validation-apis.sh${NC}"
EOF

chmod +x 02-setup-registration.sh

echo -e "${GREEN}✅ Script 02-setup-registration.sh criado!${NC}"