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
const ReportService = require('./services/reportServiceSimple');

// Validador Aprimorado
const ReportEmailService = require('./services/reports/ReportEmailService');
const reportEmailService = new ReportEmailService();
const UltimateValidator = require('./ultimateValidator');

// Sistema de Quota
const quotaMiddleware = require('./middleware/quotaMiddleware');
const quotaForSingle = quotaMiddleware.quotaForSingle;
const quotaForBatch = quotaMiddleware.quotaForBatch;
const quotaForUpload = quotaMiddleware.quotaForUpload;
const getQuotaStats = quotaMiddleware.getQuotaStats;
console.log('[QUOTA] Sistema de quota carregado');

const ultimateValidator = new UltimateValidator({
    enableSMTP: true,
    enableCache: true,
    scoreThreshold: 40
});

// Inicializar Express
const app = express();
const PORT = process.env.CLIENT_DASHBOARD_PORT || 4201;
const JWT_SECRET = process.env.JWT_SECRET || 'spark-nexus-jwt-secret-2024';

// Inicializar serviços
const db = new DatabaseService();
const emailService = new EmailService();
const smsService = new SMSService();
const reportService = new ReportService();

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
// MÉTODO AUXILIAR PARA BUSCAR DADOS COMPLETOS DO USUÁRIO
// ================================================
const getUserFullData = async (userId) => {
    try {
        const result = await db.pool.query(
            `SELECT
                id,
                first_name,
                last_name,
                email,
                phone,
                cpf_cnpj,
                company,
                email_verified,
                phone_verified,
                created_at
            FROM auth.users
            WHERE id = $1`,
            [userId]
        );

        if (result.rows.length === 0) {
            return null;
        }

        return {
            id: result.rows[0].id,
            firstName: result.rows[0].first_name,
            lastName: result.rows[0].last_name,
            email: result.rows[0].email,
            phone: result.rows[0].phone,
            cpfCnpj: result.rows[0].cpf_cnpj,
            company: result.rows[0].company,
            emailVerified: result.rows[0].email_verified,
            phoneVerified: result.rows[0].phone_verified,
            createdAt: result.rows[0].created_at,
            fullName: `${result.rows[0].first_name} ${result.rows[0].last_name}`
        };
    } catch (error) {
        console.error('Erro ao buscar dados completos do usuário:', error);
        return null;
    }
};

// ================================================
// FUNÇÃO AUXILIAR PARA PARSE DE CSV - COM CORREÇÃO DE TYPOS
// ================================================
const DomainCorrector = require('./services/validators/advanced/DomainCorrector');
const domainCorrector = new DomainCorrector();

const parseCSVContent = (csvContent) => {
    // Remover BOM se existir e normalizar quebras de linha
    const cleanContent = csvContent
        .replace(/^\uFEFF/, '') // Remove BOM
        .replace(/\r\n/g, '\n') // Normaliza quebras de linha Windows
        .replace(/\r/g, '\n');   // Normaliza quebras de linha Mac

    // Dividir em linhas - NÃO filtrar ainda para contar corretamente
    const allLines = cleanContent.split('\n');

    console.log(`Total de linhas brutas no arquivo: ${allLines.length}`);

    const allEmailsWithLineInfo = []; // Array com email e linha original
    const invalidEmails = []; // Apenas para tracking
    const correctedEmails = []; // NOVO - emails que foram corrigidos
    const emailOccurrences = new Map(); // Para rastrear ocorrências de cada email
    const correctionMap = new Map(); // NOVO - mapa de correções feitas
    let skippedLines = [];

    // Detectar o delimitador usado no arquivo
    let delimiter = ','; // padrão
    let hasHeader = false;
    let columnCount = 1; // número de colunas esperadas

    // Verificar primeira linha não vazia para detectar delimitador e cabeçalho
    let firstNonEmptyLine = '';
    for (let line of allLines) {
        if (line.trim()) {
            firstNonEmptyLine = line.trim();
            break;
        }
    }

    if (firstNonEmptyLine) {
        // Contar ocorrências de possíveis delimitadores
        const tabCount = (firstNonEmptyLine.match(/\t/g) || []).length;
        const commaCount = (firstNonEmptyLine.match(/,/g) || []).length;
        const semicolonCount = (firstNonEmptyLine.match(/;/g) || []).length;
        const pipeCount = (firstNonEmptyLine.match(/\|/g) || []).length;

        // Escolher o delimitador mais frequente
        if (tabCount > 0 && tabCount >= commaCount && tabCount >= semicolonCount) {
            delimiter = '\t';
            columnCount = tabCount + 1;
            console.log(`Delimitador detectado: TAB (${columnCount} colunas)`);
        } else if (semicolonCount > commaCount) {
            delimiter = ';';
            columnCount = semicolonCount + 1;
            console.log(`Delimitador detectado: ponto-e-vírgula (${columnCount} colunas)`);
        } else if (pipeCount > commaCount) {
            delimiter = '|';
            columnCount = pipeCount + 1;
            console.log(`Delimitador detectado: pipe (${columnCount} colunas)`);
        } else if (commaCount > 0) {
            delimiter = ',';
            columnCount = commaCount + 1;
            console.log(`Delimitador detectado: vírgula (${columnCount} colunas)`);
        } else {
            delimiter = 'none';
            columnCount = 1;
            console.log('Nenhum delimitador detectado - arquivo com uma coluna');
        }

        // Verificar se é cabeçalho
        const firstLineLower = firstNonEmptyLine.toLowerCase();
        if (firstLineLower.includes('email') || firstLineLower.includes('e-mail') ||
            firstLineLower.includes('mail') || firstLineLower.includes('correo') ||
            firstLineLower.includes('endereço')) {
            hasHeader = true;
            console.log('Cabeçalho detectado:', firstNonEmptyLine);
        }
    }

    // Processar TODAS as linhas
    let lineNumber = 0;
    let headerSkipped = false;
    let totalCorrections = 0;

    for (let i = 0; i < allLines.length; i++) {
        const line = allLines[i];
        lineNumber++;

        // Se linha está completamente vazia, pular
        if (!line || line.trim() === '') {
            skippedLines.push({ line: lineNumber, reason: 'Linha vazia' });
            continue;
        }

        // Se é cabeçalho e ainda não pulamos
        if (hasHeader && !headerSkipped) {
            const lineLower = line.toLowerCase();
            if (lineLower.includes('email') || lineLower.includes('e-mail') ||
                lineLower.includes('mail') || lineLower.includes('correo')) {
                headerSkipped = true;
                console.log(`Pulando cabeçalho na linha ${lineNumber}: "${line.trim()}"`);
                continue;
            }
        }

        const trimmedLine = line.trim();
        console.log(`Processando linha ${lineNumber}: "${trimmedLine.substring(0, 50)}${trimmedLine.length > 50 ? '...' : ''}"`);

        // Extrair email da linha
        let emailValue = '';

        if (delimiter === 'none') {
            // Arquivo com apenas uma coluna
            emailValue = trimmedLine.replace(/^["']|["']$/g, '').trim();
        } else {
            // Para CSV com múltiplas colunas
            const delimiterCount = (trimmedLine.match(new RegExp(
                delimiter === '.' ? '\\.' :
                delimiter === '|' ? '\\|' :
                delimiter, 'g'
            )) || []).length;

            if (delimiterCount === columnCount - 1) {
                // Número esperado de colunas
                const values = trimmedLine.split(delimiter).map(v => v.trim().replace(/^["']|["']$/g, ''));
                emailValue = values[0] || '';
            } else if (delimiterCount === columnCount) {
                // Possível caso especial: email incompleto com extensão na próxima coluna
                const values = trimmedLine.split(delimiter).map(v => v.trim().replace(/^["']|["']$/g, ''));

                // Verificar se parece ser um email quebrado (ex: "usuario@dominio,com")
                if (values[0] && values[0].includes('@') && !values[0].includes('.')) {
                    // Se o primeiro valor tem @ mas não tem ponto, e o segundo valor parece uma extensão
                    if (values[1] && /^[a-z]{2,}$/i.test(values[1])) {
                        emailValue = values[0] + '.' + values[1];
                        console.log(`  → Email reconstruído: ${emailValue}`);
                    } else {
                        emailValue = values[0];
                    }
                } else {
                    emailValue = values[0] || '';
                }
            } else {
                // Número inesperado de colunas - tentar extrair o email
                const values = trimmedLine.split(delimiter).map(v => v.trim().replace(/^["']|["']$/g, ''));

                // Procurar o valor que mais parece um email
                for (let val of values) {
                    if (val && val.includes('@')) {
                        emailValue = val;
                        break;
                    }
                }

                // Se não encontrou @ em nenhum campo, pegar o primeiro
                if (!emailValue) {
                    emailValue = values[0] || '';
                }
            }
        }

        // Limpar espaços extras e caracteres especiais comuns
        emailValue = emailValue
            .trim()
            .replace(/^[<\[\{\(]/, '') // Remove caracteres de abertura
            .replace(/[>\]\}\)]$/, '') // Remove caracteres de fechamento
            .replace(/\s+/g, ''); // Remove espaços internos

        // IMPORTANTE: Adicionar QUALQUER valor não vazio
        if (emailValue) {
            // Converter para minúsculas para padronizar
            const emailLower = emailValue.toLowerCase();

            // ================================================
            // NOVO: APLICAR CORREÇÃO DE DOMÍNIO
            // ================================================
            let finalEmail = emailLower;
            let wasCorrected = false;
            let correctionDetails = null;

            const correctionResult = domainCorrector.correctEmail(emailLower);

            if (correctionResult.wasCorrected) {
                totalCorrections++;
                wasCorrected = true;
                correctionDetails = correctionResult.correction;
                finalEmail = correctionResult.corrected;

                // Adicionar à lista de emails corrigidos
                correctedEmails.push({
                    line: lineNumber,
                    original: emailLower,
                    corrected: finalEmail,
                    correction: correctionDetails
                });

                // Guardar no mapa de correções
                correctionMap.set(emailLower, {
                    corrected: finalEmail,
                    details: correctionDetails
                });

                console.log(`  ✏️ Email corrigido: ${emailLower} → ${finalEmail}`);
            }

            // Rastrear ocorrências para marcar duplicados (usando email CORRIGIDO)
            if (!emailOccurrences.has(finalEmail)) {
                emailOccurrences.set(finalEmail, []);
            }
            emailOccurrences.get(finalEmail).push(lineNumber);

            // Adicionar à lista com informação da linha
            allEmailsWithLineInfo.push({
                email: finalEmail,                    // Email final (corrigido se necessário)
                originalEmail: emailLower,            // Email original do CSV
                originalLine: lineNumber,
                originalValue: emailValue,             // Valor exato do CSV
                wasCorrected: wasCorrected,          // NOVO - flag de correção
                correctionDetails: correctionDetails  // NOVO - detalhes da correção
            });

            // Verificar formato do email FINAL
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

            if (emailRegex.test(finalEmail)) {
                console.log(`  ✓ Email com formato válido: ${finalEmail}${wasCorrected ? ' (corrigido)' : ''}`);
            } else {
                invalidEmails.push({
                    line: lineNumber,
                    value: finalEmail,
                    original: emailLower,
                    reason: 'Formato de email inválido após correção',
                    wasCorrected: wasCorrected
                });
                console.log(`  ⚠ Email com formato inválido mesmo após correção: ${finalEmail}`);
            }
        } else {
            skippedLines.push({ line: lineNumber, reason: 'Sem conteúdo de email' });
            console.log(`  ⏩ Linha ${lineNumber} pulada - sem conteúdo`);
        }
    }

    // Marcar duplicados no array de emails
    const emailsWithDuplicateInfo = allEmailsWithLineInfo.map(item => {
        const occurrences = emailOccurrences.get(item.email);
        const isDuplicate = occurrences.length > 1;
        const duplicateIndex = isDuplicate ? occurrences.indexOf(item.originalLine) + 1 : 0;

        return {
            ...item,
            isDuplicate: isDuplicate,
            duplicateCount: occurrences.length,
            duplicateIndex: duplicateIndex, // 1ª, 2ª, 3ª ocorrência etc
            allOccurrences: occurrences
        };
    });

    // Estatísticas
    const uniqueEmailCount = emailOccurrences.size;
    const totalEmailCount = allEmailsWithLineInfo.length;
    const duplicatesCount = totalEmailCount - uniqueEmailCount;

    // Listar emails que aparecem mais de uma vez
    const duplicatesList = [];
    emailOccurrences.forEach((lines, email) => {
        if (lines.length > 1) {
            duplicatesList.push({
                email: email,
                lines: lines,
                count: lines.length
            });
        }
    });

    // Listar correções únicas
    const uniqueCorrections = new Map();
    correctedEmails.forEach(item => {
        const key = `${item.original}→${item.corrected}`;
        if (!uniqueCorrections.has(key)) {
            uniqueCorrections.set(key, {
                from: item.original,
                to: item.corrected,
                type: item.correction.type,
                count: 1
            });
        } else {
            uniqueCorrections.get(key).count++;
        }
    });

    console.log('\n=== Resumo do processamento do CSV ===');
    console.log(`Total de linhas no arquivo: ${allLines.length}`);
    console.log(`Linhas processadas: ${allLines.length - skippedLines.length}`);
    console.log(`Linhas puladas: ${skippedLines.length}`);
    console.log(`Total de emails extraídos: ${totalEmailCount}`);
    console.log(`Emails únicos: ${uniqueEmailCount}`);
    console.log(`Emails duplicados: ${duplicatesCount}`);
    console.log(`Emails corrigidos: ${totalCorrections} (${((totalCorrections/totalEmailCount)*100).toFixed(1)}%)`);
    console.log(`Emails com formato inválido: ${invalidEmails.length}`);

    if (totalCorrections > 0) {
        console.log('\n🔧 Correções aplicadas:');
        uniqueCorrections.forEach((correction, key) => {
            console.log(`  - "${correction.from}" → "${correction.to}" (${correction.type}) - ${correction.count}x`);
        });
    }

    if (duplicatesList.length > 0) {
        console.log('\n📋 Emails que aparecem mais de uma vez:');
        duplicatesList.slice(0, 10).forEach(dup => {
            console.log(`  - "${dup.email}" aparece ${dup.count} vezes nas linhas: ${dup.lines.join(', ')}`);
        });
        if (duplicatesList.length > 10) {
            console.log(`  ... e mais ${duplicatesList.length - 10} emails duplicados`);
        }
    }

    // Lista final de emails para verificação
    console.log(`\n=== TOTAL DE EMAILS A PROCESSAR: ${totalEmailCount} ===`);
    if (totalEmailCount <= 10) {
        emailsWithDuplicateInfo.forEach((item, idx) => {
            const dupInfo = item.isDuplicate ? ` (duplicado ${item.duplicateIndex}/${item.duplicateCount})` : '';
            const corrInfo = item.wasCorrected ? ' [CORRIGIDO]' : '';
            console.log(`  ${idx + 1}. ${item.email}${dupInfo}${corrInfo}`);
            if (item.wasCorrected) {
                console.log(`     Original: ${item.originalEmail}`);
            }
        });
    } else {
        emailsWithDuplicateInfo.slice(0, 5).forEach((item, idx) => {
            const dupInfo = item.isDuplicate ? ` (duplicado ${item.duplicateIndex}/${item.duplicateCount})` : '';
            const corrInfo = item.wasCorrected ? ' [CORRIGIDO]' : '';
            console.log(`  ${idx + 1}. ${item.email}${dupInfo}${corrInfo}`);
            if (item.wasCorrected) {
                console.log(`     Original: ${item.originalEmail}`);
            }
        });
        console.log(`  ... e mais ${totalEmailCount - 5} emails`);
    }

    return {
        emails: emailsWithDuplicateInfo,              // TODOS os emails com informação de duplicados e correções
        emailsList: emailsWithDuplicateInfo.map(e => e.email), // Lista simples para validação
        invalidFormatEmails: invalidEmails,           // Info sobre emails com formato inválido
        duplicatesList: duplicatesList,                // Lista de duplicados
        correctedEmails: correctedEmails,             // NOVO - Lista de emails corrigidos
        correctionMap: correctionMap,                 // NOVO - Mapa de correções
        skippedLines: skippedLines,
        stats: {
            totalLines: allLines.length,
            processedLines: allLines.length - skippedLines.length,
            totalEmails: totalEmailCount,
            uniqueEmails: uniqueEmailCount,
            duplicatesCount: duplicatesCount,
            correctedCount: totalCorrections,         // NOVO - contador de correções
            correctionRate: ((totalCorrections/totalEmailCount)*100).toFixed(2) + '%', // NOVO - taxa de correção
            invalidFormatCount: invalidEmails.length,
            skippedLinesCount: skippedLines.length
        }
    };
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

        const validPassword = await bcrypt.compare(password, user.password_hash);
        console.log('Senha válida?', validPassword);

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

// Endpoint de Quota
app.get('/api/user/quota', authenticateToken, getQuotaStats);

// Endpoint de quota simplificado
app.get('/api/user/quota/summary', authenticateToken, async (req, res) => {
    try {
        const QuotaService = require('./services/QuotaService');
        const quotaService = new QuotaService(db.pool, db.redis);
        const organization = await quotaService.getUserOrganization(req.user.id);

        if (!organization) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        const quota = await quotaService.checkQuota(organization.id);

        res.json({
            organization: organization.name,
            plan: organization.plan,
            used: quota.used,
            limit: quota.limit,
            remaining: quota.remaining,
            percentage: Math.round((quota.used / quota.limit) * 100)
        });
    } catch (error) {
        console.error('Erro ao buscar quota:', error);
        res.status(500).json({ error: 'Sistema de quota não configurado' });
    }
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


// ================================================
// UPLOAD DE CSV PARA VALIDAÇÃO - COM CORREÇÃO DE TYPOS
// ================================================
app.post('/api/upload', authenticateToken, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Nenhum arquivo enviado' });
        }

        // Buscar dados completos do usuário
        const userData = await getUserFullData(req.user.id);

        if (!userData) {
            return res.status(404).json({ error: 'Dados do usuário não encontrados' });
        }

        console.log('Dados do usuário recuperados:', userData);

        // Processar arquivo CSV com a função que mantém duplicados E corrige typos
        const fs = require('fs').promises;
        const csvContent = await fs.readFile(req.file.path, 'utf-8');

        // Usar a função de parse que mantém duplicados e corrige emails
        const parseResult = parseCSVContent(csvContent);

        // Limpar arquivo temporário
        try {
            await fs.unlink(req.file.path);
            console.log('Arquivo temporário removido');
        } catch (err) {
            console.error('Erro ao remover arquivo temporário:', err);
        }

        // Verificar se encontrou algum email
        if (parseResult.emailsList.length === 0) {
            return res.status(400).json({
                error: 'Nenhum email encontrado no arquivo',
                details: {
                    stats: parseResult.stats,
                    message: 'O arquivo parece estar vazio ou em formato não reconhecido'
                }
            });
        }

        const emailsList = parseResult.emailsList; // Lista simples para validação (já corrigida)
        const emailsWithInfo = parseResult.emails; // Lista com informações de duplicados e correções

        console.log(`\n📧 TOTAL: ${emailsList.length} emails para validação (incluindo duplicados)`);
        console.log(`📊 ${parseResult.stats.uniqueEmails} emails únicos`);
        console.log(`🔄 ${parseResult.stats.duplicatesCount} duplicados mantidos para transparência`);
        console.log(`✏️ ${parseResult.stats.correctedCount} emails corrigidos automaticamente`);

        // ================================================
        // VERIFICAR E CONSUMIR QUOTA
        // ================================================
        let quotaInfo = null;
        try {
            const QuotaService = require('./services/QuotaService');
            const quotaService = new QuotaService(db.pool, db.redis);

            // Buscar organização do usuário
            const organization = await quotaService.getUserOrganization(req.user.id);

            if (organization) {
                // Verificar se tem quota suficiente para TODOS os emails (incluindo duplicados)
                const quotaCheck = await quotaService.checkQuota(organization.id, emailsList.length);

                if (!quotaCheck.allowed) {
                    return res.status(429).json({
                        error: 'Limite de validações excedido',
                        code: 'QUOTA_EXCEEDED',
                        details: {
                            message: quotaCheck.message,
                            limit: quotaCheck.limit,
                            used: quotaCheck.used,
                            remaining: quotaCheck.remaining,
                            requested: emailsList.length,
                            plan: organization.plan
                        },
                        suggestions: [
                            'Reduza a quantidade de emails no arquivo',
                            'Aguarde até o próximo período de faturamento',
                            'Faça upgrade do seu plano'
                        ]
                    });
                }

                console.log(`[QUOTA] Processando ${emailsList.length} emails para ${organization.name}`);
                quotaInfo = {
                    organization: organization.name,
                    plan: organization.plan,
                    limit: quotaCheck.limit,
                    used: quotaCheck.used,
                    remaining: quotaCheck.remaining
                };
            }
        } catch (quotaError) {
            console.error('[QUOTA] Erro ao verificar quota:', quotaError.message);
            // Continuar sem quota se houver erro
        }

        // Criar job de validação
        const jobId = uuidv4();

        // Processar TODOS os emails com validador aprimorado
        // NOTA: Os emails já estão corrigidos, então o UltimateValidator não precisa corrigir novamente
        console.log(`\n🔍 Iniciando validação de ${emailsList.length} emails...`);

        // Configurar UltimateValidator para pular correção (já foi feita no parse)
        const validationPromises = emailsList.map((email, index) => {
            // Passar informação de correção junto para o validador saber
            const emailInfo = emailsWithInfo[index];
            return ultimateValidator.validateEmail(email).then(result => ({
                ...result,
                wasPreCorrected: emailInfo.wasCorrected,
                originalEmailBeforeCorrection: emailInfo.originalEmail,
                correctionAppliedDuringParse: emailInfo.correctionDetails
            }));
        });

        const validationResults = await Promise.all(validationPromises);

        // Adicionar informação de duplicados e correções aos resultados
        const validationResultsWithFullInfo = validationResults.map((result, index) => {
            const emailInfo = emailsWithInfo[index];
            return {
                ...result,
                isDuplicate: emailInfo.isDuplicate,
                duplicateIndex: emailInfo.duplicateIndex,
                duplicateCount: emailInfo.duplicateCount,
                originalLine: emailInfo.originalLine,
                // Informações de correção do parse
                correctedDuringParse: emailInfo.wasCorrected,
                originalBeforeParse: emailInfo.originalEmail
            };
        });

        // ================================================
        // INCREMENTAR QUOTA APÓS SUCESSO
        // ================================================
        if (quotaInfo) {
            try {
                const QuotaService = require('./services/QuotaService');
                const quotaService = new QuotaService(db.pool, db.redis);
                const organization = await quotaService.getUserOrganization(req.user.id);

                if (organization) {
                    const incrementResult = await quotaService.incrementUsage(organization.id, emailsList.length);
                    console.log(`[QUOTA] Incrementado ${emailsList.length} validações. Restam: ${incrementResult.remaining}`);

                    // Atualizar quotaInfo
                    quotaInfo.remaining = incrementResult.remaining;
                    quotaInfo.used = organization.validations_used + emailsList.length;

                    // Adicionar headers de quota na resposta
                    res.set({
                        'X-RateLimit-Limit': organization.max_validations,
                        'X-RateLimit-Remaining': incrementResult.remaining,
                        'X-RateLimit-Used': organization.validations_used + emailsList.length
                    });
                }
            } catch (quotaError) {
                console.error('[QUOTA] Erro ao incrementar uso:', quotaError.message);
            }
        }

        // Preparar informações do usuário para o relatório
        const userInfo = {
            name: userData.fullName,
            email: userData.email,
            company: userData.company,
            phone: userData.phone
        };

        // Gerar e enviar relatório com informações completas
        console.log(`\n📊 Enviando relatório com ${validationResultsWithFullInfo.length} emails para: ${userData.email}`);
        const reportResult = await reportEmailService.generateAndSendReport(
            validationResultsWithFullInfo,
            userData.email,
            userInfo
        );

        console.log('✅ Relatório enviado com sucesso');

        // Estatísticas
        const validCount = validationResults.filter(r => r.valid).length;
        const avgScore = validationResults.reduce((acc, r) => acc + r.score, 0) / validationResults.length;

        // Resposta completa
        res.json({
            success: true,
            message: `${emailsList.length} emails validados com sucesso! O relatório será enviado por e-mail.`,
            jobId,
            user: {
                name: userData.fullName,
                email: userData.email,
                company: userData.company
            },
            stats: {
                total: emailsList.length,
                unique: parseResult.stats.uniqueEmails,
                duplicates: parseResult.stats.duplicatesCount,
                corrected: parseResult.stats.correctedCount,          // NOVO
                correctionRate: parseResult.stats.correctionRate,    // NOVO
                valid: validCount,
                invalid: emailsList.length - validCount,
                averageScore: Math.round(avgScore),
                invalidFormat: parseResult.stats.invalidFormatCount
            },
            corrections: {                                           // NOVO - detalhes das correções
                total: parseResult.stats.correctedCount,
                rate: parseResult.stats.correctionRate,
                samples: parseResult.correctedEmails.slice(0, 5).map(c => ({
                    original: c.original,
                    corrected: c.corrected,
                    type: c.correction.type,
                    line: c.line
                }))
            },
            quota: quotaInfo,
            reportSent: true,
            reportDetails: {
                sentTo: userData.email,
                filename: reportResult.filename,
                sentAt: new Date().toISOString()
            },
            parseDetails: {
                totalLinesInFile: parseResult.stats.totalLines,
                totalLinesProcessed: parseResult.stats.processedLines,
                totalEmails: parseResult.stats.totalEmails,
                uniqueEmails: parseResult.stats.uniqueEmails,
                correctedEmails: parseResult.stats.correctedCount,    // NOVO
                duplicatesInfo: parseResult.duplicatesList.slice(0, 5)
            }
        });
    } catch (error) {
        console.error('❌ Erro no upload:', error);
        res.status(500).json({ error: 'Erro ao processar arquivo: ' + error.message });
    }
});

// Validar email único (com verificação completa)
app.post('/api/validate/single', authenticateToken, quotaForSingle, [
    body('email').isEmail().withMessage('Email inválido')
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { email } = req.body;

        // Usar o validador aprimorado
        const result = await ultimateValidator.validateEmail(email);

        res.json(result);
    } catch (error) {
        res.status(500).json({ error: 'Erro ao validar email' });
    }
});

// Validação avançada
app.post('/api/validate/advanced', authenticateToken, quotaForSingle, async (req, res) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ error: 'Email é obrigatório' });
        }

        const result = await ultimateValidator.validateEmail(email);
        res.json(result);
    } catch (error) {
        console.error('Erro na validação avançada:', error);
        res.status(500).json({ error: 'Erro ao validar email' });
    }
});

// Validação em lote
app.post('/api/validate/batch', authenticateToken, quotaForBatch, async (req, res) => {
    try {
        const { emails } = req.body;

        if (!emails || !Array.isArray(emails)) {
            return res.status(400).json({ error: 'Lista de emails é obrigatória' });
        }

        if (emails.length > 100) {
            return res.status(400).json({ error: 'Máximo de 100 emails por lote' });
        }

        // Buscar dados do usuário
        const userData = await getUserFullData(req.user.id);

        const results = await ultimateValidator.validateBatch(emails);

        res.json({
            total: emails.length,
            results: results,
            summary: {
                valid: results.filter(r => r.valid).length,
                invalid: results.filter(r => !r.valid).length,
                avgScore: Math.round(results.reduce((acc, r) => acc + r.score, 0) / results.length)
            },
            user: {
                email: userData?.email,
                company: userData?.company
            }
        });
    } catch (error) {
        console.error('Erro na validação em lote:', error);
        res.status(500).json({ error: 'Erro ao validar lote' });
    }
});

// Estatísticas do validador
app.get('/api/validator/stats', authenticateToken, async (req, res) => {
    try {
        const stats = await ultimateValidator.getStatistics();
        res.json(stats);
    } catch (error) {
        console.error('Erro ao buscar estatísticas:', error);
        res.status(500).json({ error: 'Erro ao buscar estatísticas' });
    }
});

// Limpar cache do validador
app.post('/api/validator/cache/clear', authenticateToken, async (req, res) => {
    try {
        await ultimateValidator.clearCache();
        res.json({ success: true, message: 'Cache limpo com sucesso' });
    } catch (error) {
        console.error('Erro ao limpar cache:', error);
        res.status(500).json({ error: 'Erro ao limpar cache' });
    }
});

// Download de relatório
app.get('/api/reports/download/:filename', authenticateToken, async (req, res) => {
    try {
        const { filename } = req.params;
        const filepath = path.join(__dirname, 'reports', filename);

        // Verificar se arquivo existe
        const fs = require('fs');
        if (!fs.existsSync(filepath)) {
            return res.status(404).json({ error: 'Relatório não encontrado' });
        }

        // Enviar arquivo
        res.download(filepath, filename, (err) => {
            if (err) {
                console.error('Erro no download:', err);
                res.status(500).json({ error: 'Erro ao baixar arquivo' });
            }
        });
    } catch (error) {
        console.error('Erro:', error);
        res.status(500).json({ error: 'Erro ao processar download' });
    }
});

// Gerar relatório sob demanda
app.post('/api/reports/generate', authenticateToken, async (req, res) => {
    try {
        const { emails } = req.body;

        if (!emails || !Array.isArray(emails)) {
            return res.status(400).json({ error: 'Lista de emails é obrigatória' });
        }

        // Buscar dados completos do usuário
        const userData = await getUserFullData(req.user.id);

        if (!userData) {
            return res.status(404).json({ error: 'Dados do usuário não encontrados' });
        }

        // Validar emails
        const validationResults = await ultimateValidator.validateBatch(emails);

        // Gerar relatório
        const reportData = await reportEmailService.generateValidationReport(
            validationResults,
            {
                name: userData.fullName,
                email: userData.email,
                company: userData.company
            }
        );

        // Enviar por email se solicitado
        if (req.body.sendEmail) {
            await emailService.sendValidationReport(
                userData.email, // Usar email do usuário autenticado
                reportData,
                reportData.filepath,
                {
                    name: userData.firstName,
                    company: userData.company
                }
            );
        }

        res.json({
            success: true,
            filename: reportData.filename,
            downloadUrl: `/api/reports/download/${reportData.filename}`,
            stats: reportData.stats,
            sentTo: req.body.sendEmail ? userData.email : null
        });
    } catch (error) {
        console.error('Erro ao gerar relatório:', error);
        res.status(500).json({ error: 'Erro ao gerar relatório' });
    }
});

// Estatísticas detalhadas do Ultimate Validator
app.get('/api/validator/ultimate-stats', authenticateToken, async (req, res) => {
    try {
        const stats = ultimateValidator.getStatistics();
        res.json(stats);
    } catch (error) {
        console.error('Erro ao buscar estatísticas:', error);
        res.status(500).json({ error: 'Erro ao buscar estatísticas' });
    }
});

// Endpoint para validação com relatório por email
app.post('/api/validate/batch-with-report', authenticateToken, quotaForBatch, async (req, res) => {
    try {
        const { emails, sendReport } = req.body;

        if (!emails || !Array.isArray(emails)) {
            return res.status(400).json({ error: 'Lista de emails é obrigatória' });
        }

        // Buscar dados completos do usuário
        const userData = await getUserFullData(req.user.id);

        if (!userData) {
            return res.status(404).json({ error: 'Dados do usuário não encontrados' });
        }

        console.log(`📧 Validando ${emails.length} emails para ${userData.fullName}...`);

        // Validar emails
        const validationResults = await ultimateValidator.validateBatch(emails);

        // Se solicitado, enviar relatório por email
        if (sendReport) {
            console.log(`📊 Gerando e enviando relatório para ${userData.email}...`);

            const userInfo = {
                name: userData.fullName,
                email: userData.email,
                company: userData.company,
                phone: userData.phone
            };

            const reportResult = await reportEmailService.generateAndSendReport(
                validationResults,
                userData.email, // Email do usuário autenticado
                userInfo
            );

            return res.json({
                success: true,
                totalEmails: emails.length,
                validationResults: validationResults,
                report: {
                    ...reportResult,
                    sentTo: userData.email
                },
                user: {
                    name: userData.fullName,
                    email: userData.email,
                    company: userData.company
                }
            });
        }

        // Retornar apenas resultados se não for para enviar relatório
        res.json({
            success: true,
            totalEmails: emails.length,
            validationResults: validationResults,
            user: {
                name: userData.fullName,
                email: userData.email,
                company: userData.company
            }
        });

    } catch (error) {
        console.error('Erro na validação com relatório:', error);
        res.status(500).json({ error: error.message });
    }
});

// Obter dados do usuário autenticado
app.get('/api/user/profile', authenticateToken, async (req, res) => {
    try {
        const userData = await getUserFullData(req.user.id);

        if (!userData) {
            return res.status(404).json({ error: 'Dados do usuário não encontrados' });
        }

        res.json({
            success: true,
            user: userData
        });
    } catch (error) {
        console.error('Erro ao buscar perfil:', error);
        res.status(500).json({ error: 'Erro ao buscar dados do usuário' });
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
    - POST /api/upload (Processa TODOS os 264 emails, marcando duplicados)
    - POST /api/validate/single
    - POST /api/validate/advanced
    - POST /api/validate/batch
    - POST /api/validate/batch-with-report
    - GET  /api/validator/stats
    - POST /api/validator/cache/clear
    - GET  /api/reports/download/:filename
    - POST /api/reports/generate
    - GET  /api/user/profile
    - GET  /api/user/quota
    - GET  /api/user/quota/summary

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
