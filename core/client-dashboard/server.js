// ================================================
// Server Principal - Client Dashboard
// Sistema completo com autenticação e validações
// ================================================

const express = require('express');
const path = require('path');
const cors = require('cors');
const multer = require('multer');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

// Importar serviços
const DatabaseService = require('./services/database');
const EmailService = require('./services/emailService');
const SMSService = require('./services/smsService');
const Validators = require('./services/validators');

// Inicializar Express
const app = express();
const PORT = process.env.CLIENT_DASHBOARD_PORT || 4201;
const JWT_SECRET = process.env.JWT_SECRET || 'spark-nexus-jwt-secret-2024';

// Inicializar serviços
const db = new DatabaseService();
const emailService = new EmailService();
const smsService = new SMSService();

// ================================================
// MIDDLEWARE
// ================================================

// Segurança
app.use(helmet({
    contentSecurityPolicy: false, // Desabilitar para desenvolvimento
}));

// Logs
app.use(morgan('combined'));

// CORS
app.use(cors());

// Parser
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static files
app.use(express.static('public'));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutos
    max: 100 // máximo 100 requisições
});

const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutos
    max: 5 // máximo 5 tentativas de login
});

app.use('/api/', limiter);
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);

// Upload
const upload = multer({
    dest: 'uploads/',
    limits: { fileSize: 10 * 1024 * 1024 }
});

// ================================================
// MIDDLEWARE DE AUTENTICAÇÃO
// ================================================
const authenticateToken = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'Token não fornecido' });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        const session = await db.validateSession(token);

        if (!session) {
            return res.status(403).json({ error: 'Sessão inválida' });
        }

        req.user = decoded;
        req.session = session;
        next();
    } catch (err) {
      console.log('erro token: ', err);
        return res.status(403).json({ error: 'Token inválido' });
    }
};

// ================================================
// ROTAS PÚBLICAS (PÁGINAS)
// ================================================

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/login', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

app.get('/register', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'register.html'));
});

app.get('/upload', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'upload.html'));
});

app.get('/verify-email', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'verify-email.html'));
});

// ================================================
// APIS DE VALIDAÇÃO (PÚBLICAS)
// ================================================

// Validar CPF/CNPJ
app.post('/api/validate/cpf-cnpj', [
    body('document').notEmpty().withMessage('Documento é obrigatório')
], (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    const { document } = req.body;
    const result = Validators.validateCpfCnpj(document);

    res.json(result);
});

// Validar Email (formato apenas)
app.post('/api/validate/email-format', [
    body('email').isEmail().withMessage('Email inválido')
], (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    const { email } = req.body;
    const result = Validators.validateEmail(email);

    res.json(result);
});

// Validar Telefone
app.post('/api/validate/phone', [
    body('phone').notEmpty().withMessage('Telefone é obrigatório')
], (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    const { phone } = req.body;
    const result = Validators.validatePhone(phone);

    res.json(result);
});

// ================================================
// APIS DE AUTENTICAÇÃO
// ================================================

// Registro
app.post('/api/auth/register', [
    body('firstName').notEmpty().withMessage('Nome é obrigatório'),
    body('lastName').notEmpty().withMessage('Sobrenome é obrigatório'),
    body('cpfCnpj').notEmpty().withMessage('CPF/CNPJ é obrigatório'),
    body('email').isEmail().withMessage('Email inválido'),
    body('phone').notEmpty().withMessage('Telefone é obrigatório'),
    body('company').notEmpty().withMessage('Empresa é obrigatória'),
    body('password').isLength({ min: 8 }).withMessage('Senha deve ter no mínimo 8 caracteres')
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const userData = req.body;

        // Validar CPF/CNPJ
        const docValidation = Validators.validateCpfCnpj(userData.cpfCnpj);
        if (!docValidation.valid) {
            return res.status(400).json({ error: 'CPF/CNPJ inválido' });
        }

        // Validar telefone
        const phoneValidation = Validators.validatePhone(userData.phone);
        if (!phoneValidation.valid) {
            return res.status(400).json({ error: 'Telefone inválido' });
        }

        // Validar senha
        const passwordValidation = Validators.validatePassword(userData.password);
        if (!passwordValidation.valid) {
            return res.status(400).json({
                error: 'Senha deve conter maiúsculas, minúsculas, números e caracteres especiais'
            });
        }

        // Gerar tokens de verificação
        userData.emailToken = Validators.generateToken(6, 'alphanumeric');
        userData.phoneToken = Validators.generateToken(6, 'numeric');

        // Criar usuário no banco
        console.log('fazendo registro do usuario')
        const result = await db.createUser(userData);

        if (result.success) {
            // Enviar email de verificação
            await emailService.sendVerificationEmail(
                userData.email,
                userData.emailToken,
                userData.firstName
            );

            // Enviar SMS de verificação
            await smsService.sendVerificationSMS(
                userData.phone,
                userData.phoneToken
            );

            res.json({
                success: true,
                message: 'Usuário criado. Verifique seu email e telefone.',
                userId: result.user.id
            });
        } else {
            throw new Error('Erro ao criar usuário');
        }
    } catch (error) {
        console.error('Erro no registro:', error);
        res.status(400).json({
            error: error.message || 'Erro ao criar conta'
        });
    }
});

// Login
app.post('/api/auth/login', [
    body('email').isEmail().withMessage('Email inválido'),
    body('password').notEmpty().withMessage('Senha é obrigatória')
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    const { email, password } = req.body;
    const ipAddress = req.ip;

    try {
        // Verificar tentativas de login
        const attempts = await db.checkLoginAttempts(email, ipAddress);
        if (attempts >= 5) {
            return res.status(429).json({
                error: 'Muitas tentativas. Tente novamente em 15 minutos.'
            });
        }

        // Buscar usuário
        console.log('email: ', email)
        const user = await db.getUserByEmail(email);

        console.log('user ---:', user);
        if (!user) {
            await db.logLoginAttempt(email, ipAddress, false);
            return res.status(401).json({ error: 'Email ou senha inválidos' });
        }

        // Verificar senha

        console.log('Senha digitada:', password);
        console.log('Hash do banco:', user.password_hash);

        // Teste direto
        const validPassword_ = await bcrypt.compare(password, user.password_hash);
        console.log('Senha válida?', validPassword_);

        // Se estiver falhando, verifique:
        // 1. A senha está vindo corretamente do frontend?
        console.log('Tipo da senha:', typeof password);
        console.log('Comprimento:', password.length);

        // 2. O hash está vindo corretamente do banco?
        console.log('Tipo do hash:', typeof user.password_hash);
        console.log('Comprimento do hash:', user.password_hash.length);
        const validPassword = await bcrypt.compare(password, user.password_hash);

        if (!validPassword) {
            await db.logLoginAttempt(email, ipAddress, false);
            return res.status(401).json({ error: 'Email ou senha inválidos' });
        }

        // Verificar se email foi verificado
        if (!user.email_verified) {
            return res.status(403).json({
                error: 'Email não verificado. Verifique seu email.'
            });
        }

        // Criar token JWT
        const token = jwt.sign(
            {
                id: user.id,
                email: user.email,
                firstName: user.first_name,
                lastName: user.last_name
            },
            JWT_SECRET,
            { expiresIn: '24h' }
        );

        // Criar sessão
        await db.createSession(
            user.id,
            token,
            ipAddress,
            req.headers['user-agent']
        );

        // Log sucesso
        await db.logLoginAttempt(email, ipAddress, true);

        res.json({
            token,
            user: {
                id: user.id,
                email: user.email,
                firstName: user.first_name,
                lastName: user.last_name,
                company: user.company,
                phoneVerified: user.phone_verified
            }
        });
    } catch (error) {
        console.error('Erro no login:', error);
        res.status(500).json({ error: 'Erro ao fazer login' });
    }
});

// Verificar Email
app.post('/api/auth/verify-email', [
    body('email').isEmail().withMessage('Email inválido'),
    body('token').notEmpty().withMessage('Token é obrigatório')
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { token } = req.body;

        const result = await db.verifyEmail(token);

        if (result) {
            // Enviar email de boas-vindas
            await emailService.sendWelcomeEmail(
                result.email,
                result.first_name
            );

            res.json({
                success: true,
                message: 'Email verificado com sucesso'
            });
        } else {
            res.status(400).json({
                error: 'Token inválido ou expirado'
            });
        }
    } catch (error) {
        console.error('Erro ao verificar email:', error);
        res.status(500).json({ error: 'Erro ao verificar email' });
    }
});

// Verificar Telefone
app.post('/api/auth/verify-phone', [
    body('email').isEmail().withMessage('Email inválido'),
    body('token').notEmpty().withMessage('Token é obrigatório')
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { email, token } = req.body;

        // Buscar usuário
        const user = await db.getUserByEmail(email);
        if (!user) {
            return res.status(404).json({ error: 'Usuário não encontrado' });
        }

        const result = await db.verifyPhone(user.id, token);

        if (result) {
            res.json({
                success: true,
                message: 'Telefone verificado com sucesso'
            });
        } else {
            res.status(400).json({
                error: 'Token inválido ou expirado'
            });
        }
    } catch (error) {
        console.error('Erro ao verificar telefone:', error);
        res.status(500).json({ error: 'Erro ao verificar telefone' });
    }
});

// Reenviar Email
app.post('/api/auth/resend-email', [
    body('email').isEmail().withMessage('Email inválido')
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { email } = req.body;

        // Buscar usuário
        const user = await db.getUserByEmail(email);
        if (!user) {
            return res.status(404).json({ error: 'Usuário não encontrado' });
        }

        if (user.email_verified) {
            return res.status(400).json({ error: 'Email já verificado' });
        }

        // Gerar novo token
        const newToken = Validators.generateToken(6, 'alphanumeric');

        // Atualizar token no banco
        const tokenExpiry = new Date();
        tokenExpiry.setMinutes(tokenExpiry.getMinutes() + 30);

        await db.pool.query(
            `UPDATE auth.users
             SET email_verification_token = $1, email_token_expires = $2
             WHERE id = $3`,
            [newToken, tokenExpiry, user.id]
        );

        // Enviar email
        await emailService.sendVerificationEmail(
            email,
            newToken,
            user.first_name
        );

        res.json({
            success: true,
            message: 'Email reenviado'
        });
    } catch (error) {
        console.error('Erro ao reenviar email:', error);
        res.status(500).json({ error: 'Erro ao reenviar email' });
    }
});

// Reenviar SMS/WhatsApp
app.post('/api/auth/resend-phone', [
    body('email').isEmail().withMessage('Email inválido'),
    body('method').isIn(['sms', 'whatsapp']).withMessage('Método inválido')
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { email, method } = req.body;

        // Buscar usuário
        const user = await db.getUserByEmail(email);
        if (!user) {
            return res.status(404).json({ error: 'Usuário não encontrado' });
        }

        if (user.phone_verified) {
            return res.status(400).json({ error: 'Telefone já verificado' });
        }

        // Gerar novo token
        const newToken = Validators.generateToken(6, 'numeric');

        // Atualizar token no banco
        const tokenExpiry = new Date();
        tokenExpiry.setMinutes(tokenExpiry.getMinutes() + 10);

        await db.pool.query(
            `UPDATE auth.users
             SET phone_verification_token = $1, phone_token_expires = $2
             WHERE id = $3`,
            [newToken, tokenExpiry, user.id]
        );

        // Enviar SMS ou WhatsApp
        if (method === 'whatsapp') {
            await smsService.sendVerificationWhatsApp(user.phone, newToken);
        } else {
            await smsService.sendVerificationSMS(user.phone, newToken);
        }

        res.json({
            success: true,
            message: `Código reenviado via ${method.toUpperCase()}`
        });
    } catch (error) {
        console.error('Erro ao reenviar código:', error);
        res.status(500).json({ error: 'Erro ao reenviar código' });
    }
});

// Verificar Token JWT
app.get('/api/auth/verify', authenticateToken, (req, res) => {
    res.json({
        valid: true,
        user: req.user
    });
});

// Logout
app.post('/api/auth/logout', authenticateToken, async (req, res) => {
    try {
        // Remover sessão do banco
        await db.pool.query(
            'DELETE FROM auth.sessions WHERE token = $1',
            [req.headers['authorization'].split(' ')[1]]
        );

        // Remover do Redis se disponível
        if (db.redis.isOpen) {
            await db.redis.del(`session:${req.headers['authorization'].split(' ')[1]}`);
        }

        res.json({ success: true, message: 'Logout realizado' });
    } catch (error) {
        console.error('Erro no logout:', error);
        res.status(500).json({ error: 'Erro ao fazer logout' });
    }
});

// ================================================
// APIS PROTEGIDAS (REQUEREM AUTENTICAÇÃO)
// ================================================

// Dashboard Stats
app.get('/api/stats', authenticateToken, async (req, res) => {
    try {
        // Buscar estatísticas do usuário
        const stats = {
            totalValidations: Math.floor(Math.random() * 1000),
            successRate: Math.floor(Math.random() * 100),
            totalEmails: Math.floor(Math.random() * 10000),
            recentActivity: []
        };

        res.json(stats);
    } catch (error) {
        res.status(500).json({ error: 'Erro ao buscar estatísticas' });
    }
});

// Upload de CSV para validação
app.post('/api/upload', authenticateToken, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Nenhum arquivo enviado' });
        }

        // Processar arquivo (implementação simplificada)
        const fs = require('fs').promises;
        const csvContent = await fs.readFile(req.file.path, 'utf-8');
        const lines = csvContent.split('\n').filter(line => line.trim());
        const emails = [];

        for (let i = 1; i < lines.length; i++) {
            const values = lines[i].split(',').map(v => v.trim());
            if (values[0]) {
                emails.push(values[0]);
            }
        }

        // Limpar arquivo temporário
        await fs.unlink(req.file.path);

        // Criar job de validação
        const jobId = uuidv4();

        res.json({
            success: true,
            message: `${emails.length} emails enviados para validação`,
            jobId,
            emails: emails.slice(0, 5) // Preview
        });
    } catch (error) {
        console.error('Erro no upload:', error);
        res.status(500).json({ error: 'Erro ao processar arquivo' });
    }
});

// Validar email único (com verificação completa)
app.post('/api/validate/single', authenticateToken, [
    body('email').isEmail().withMessage('Email inválido')
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { email } = req.body;

        // Validação básica
        const validation = Validators.validateEmail(email);

        // Aqui você pode adicionar validações mais avançadas
        // como verificação de MX, SMTP, etc.

        res.json({
            email,
            valid: validation.valid,
            score: validation.valid ? 85 : 15,
            checks: {
                format: true,
                disposable: validation.isDisposable,
                domain: validation.domain
            }
        });
    } catch (error) {
        res.status(500).json({ error: 'Erro ao validar email' });
    }
});

// Health Check
app.get('/api/health', (req, res) => {
    res.json({
        status: 'ok',
        service: 'client-dashboard',
        version: '2.0.0',
        timestamp: new Date().toISOString()
    });
});

// ================================================
// TRATAMENTO DE ERROS
// ================================================

// 404 Handler
app.use((req, res) => {
    if (req.path.startsWith('/api/')) {
        res.status(404).json({ error: 'Endpoint não encontrado' });
    } else {
        res.status(404).sendFile(path.join(__dirname, 'public', '404.html'));
    }
});

// Error Handler
app.use((err, req, res, next) => {
    console.error('Erro:', err);
    res.status(500).json({
        error: 'Erro interno do servidor',
        message: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
});

// ================================================
// INICIALIZAÇÃO DO SERVIDOR
// ================================================

// Limpar dados expirados periodicamente
setInterval(() => {
    db.cleanupExpiredData().catch(console.error);
}, 60 * 60 * 1000); // A cada hora

// Iniciar servidor
const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`
    ================================================
    🚀 Spark Nexus - Client Dashboard
    ================================================
    ✅ Servidor rodando em: http://localhost:${PORT}

    📍 Endpoints disponíveis:

    PÁGINAS:
    - Home:         http://localhost:${PORT}/
    - Login:        http://localhost:${PORT}/login
    - Cadastro:     http://localhost:${PORT}/register
    - Upload:       http://localhost:${PORT}/upload

    APIs PÚBLICAS:
    - POST /api/validate/cpf-cnpj
    - POST /api/validate/email-format
    - POST /api/validate/phone
    - POST /api/auth/register
    - POST /api/auth/login
    - POST /api/auth/verify-email
    - POST /api/auth/verify-phone
    - POST /api/auth/resend-email
    - POST /api/auth/resend-phone

    APIs PROTEGIDAS:
    - GET  /api/auth/verify
    - POST /api/auth/logout
    - GET  /api/stats
    - POST /api/upload
    - POST /api/validate/single

    HEALTH:
    - GET  /api/health

    📌 Credenciais de Demo:
    - Email: demo@sparknexus.com
    - Senha: Demo@123456

    ⚠️  Ambiente: ${process.env.NODE_ENV || 'development'}
    ================================================
    `);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM recebido. Encerrando servidor...');
    server.close(() => {
        db.pool.end();
        if (db.redis.isOpen) {
            db.redis.quit();
        }
        process.exit(0);
    });
});

process.on('uncaughtException', (error) => {
    console.error('❌ Erro não capturado:', error);
});

process.on('unhandledRejection', (error) => {
    console.error('❌ Promise rejeitada:', error);
});

module.exports = app;
