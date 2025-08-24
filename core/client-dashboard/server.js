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
const billingRoutes = require('./services/routes/billing.routes');
const stripeRoutes = require('./services/routes/stripe.routes');
const AsyncValidationService = require('./services/asyncValidationService');


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

// Serviço de validação assíncrona
let asyncValidationService;

// Inicializar após UltimateValidator
setTimeout(() => {
    asyncValidationService = new AsyncValidationService({
        db,
        emailService,
        ultimateValidator,
        reportEmailService,
        maxConcurrentJobs: 3
    });
    console.log('[ASYNC] Serviço de validação assíncrona inicializado');
}, 1000);

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
app.use('/api/billing', billingRoutes);
app.use('/api/stripe', stripeRoutes);


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
// MÉTODO AUXILIAR PARA BUSCAR ORGANIZATION_ID DO USUÁRIO
// ================================================
const getUserOrganizationId = async (userId) => {
    try {
        const result = await db.pool.query(
            `SELECT organization_id
             FROM tenant.organization_members
             WHERE user_id = $1
             LIMIT 1`,
            [userId]
        );

        if (result.rows.length === 0) {
            console.log(`⚠️ Usuário ${userId} não tem organização associada`);
            return null;
        }

        return result.rows[0].organization_id;
    } catch (error) {
        console.error('Erro ao buscar organization_id:', error);
        return null;
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
    res.sendFile(path.join(__dirname, 'public', 'upload-async.html'));
});

app.get('/validation-history', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'validation-history.html'));
});

app.get('/checkout', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'checkout-dynamic.html'));
});

app.get('/verify-email', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'verify-email.html'));
});


app.get('/payment/success', (req, res) => {
    res.sendFile(path.join(__dirname, 'public/payment', 'success.html'));
});

app.get('/payment/cancel', (req, res) => {
    res.sendFile(path.join(__dirname, 'public/payment', 'cancel.html'));
});

app.get('/profile', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'profile.html'));
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

// Endpoint de quota simplificado - atualizado para novo sistema de créditos
app.get('/api/user/quota/summary', authenticateToken, async (req, res) => {
    try {
        const organizationId = await getUserOrganizationId(req.user.id);
        if (!organizationId) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        // Buscar dados da organização com nova estrutura de créditos
        const orgResult = await db.pool.query(`
            SELECT
                id,
                name,
                plan,
                balance_credits,
                monthly_credits,
                total_validations_ever,
                -- Campos antigos para compatibilidade
                max_validations,
                validations_used
            FROM tenant.organizations
            WHERE id = $1
        `, [organizationId]);

        if (orgResult.rows.length === 0) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        const organization = orgResult.rows[0];

        // Usar novo sistema de créditos se disponível, senão usar sistema antigo
        const balanceCredits = organization.balance_credits !== null ? organization.balance_credits :
            Math.max(0, (organization.max_validations || 100) - (organization.validations_used || 0));

        const totalValidations = organization.total_validations_ever !== null ? organization.total_validations_ever :
            (organization.validations_used || 0);

        res.json({
            organization: organization.name,
            plan: organization.plan,
            // Novo sistema
            balance_credits: balanceCredits,
            monthly_credits: organization.monthly_credits || 0,
            total_validations_ever: totalValidations,
            // Compatibilidade com sistema antigo
            used: organization.validations_used || 0,
            limit: organization.max_validations || 100,
            remaining: balanceCredits,
            percentage: organization.max_validations > 0 ? Math.round(((organization.validations_used || 0) / organization.max_validations) * 100) : 0
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

// Estatísticas históricas do usuário
app.get('/api/user/stats', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;

        // Por enquanto, vamos usar dados mock até implementar as tabelas de histórico
        // TODO: Implementar consulta real ao banco de dados de validações históricas
        const userStats = {
            totalValidations: Math.floor(Math.random() * 5000) + 1000, // Total histórico
            totalEmailsProcessed: Math.floor(Math.random() * 50000) + 10000,
            averageSuccessRate: 85 + Math.floor(Math.random() * 10), // 85-95%
            monthsActive: Math.ceil((Date.now() - new Date('2024-01-01')) / (1000 * 60 * 60 * 24 * 30)),
            firstValidation: '2024-01-15',
            lastValidation: new Date().toISOString().split('T')[0]
        };

        res.json({
            success: true,
            stats: userStats
        });
    } catch (error) {
        console.error('Erro ao buscar estatísticas do usuário:', error);
        res.status(500).json({ error: 'Erro ao buscar estatísticas históricas' });
    }
});


// ================================================
// UPLOAD DE CSV PARA VALIDAÇÃO - PROCESSAMENTO ASSÍNCRONO
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

        console.log('📁 Processando arquivo para:', userData.fullName);

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

        console.log(`\n📧 TOTAL: ${emailsList.length} emails para validação assíncrona`);
        console.log(`📊 ${parseResult.stats.uniqueEmails} emails únicos`);
        console.log(`🔄 ${parseResult.stats.duplicatesCount} duplicados mantidos`);
        console.log(`✏️ ${parseResult.stats.correctedCount} emails corrigidos automaticamente`);

        // ================================================
        // VERIFICAR CRÉDITOS (NÃO CONSUMIR AINDA)
        // ================================================
        const organizationId = await getUserOrganizationId(req.user.id);
        if (!organizationId) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        // Verificar créditos disponíveis
        const creditsResult = await db.pool.query(`
            SELECT
                name,
                plan,
                balance_credits,
                monthly_credits,
                total_validations_ever
            FROM tenant.organizations
            WHERE id = $1
        `, [organizationId]);

        if (creditsResult.rows.length === 0) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        const organization = creditsResult.rows[0];
        const availableCredits = organization.balance_credits || 0;
        const requiredCredits = emailsList.length;

        console.log(`[CRÉDITOS] Verificando: ${requiredCredits} necessários, ${availableCredits} disponíveis`);

        if (availableCredits < requiredCredits) {
            return res.status(429).json({
                error: 'Créditos insuficientes',
                code: 'QUOTA_EXCEEDED',
                details: {
                    message: `Você precisa de ${requiredCredits} créditos, mas tem apenas ${availableCredits} disponíveis`,
                    available: availableCredits,
                    required: requiredCredits,
                    deficit: requiredCredits - availableCredits,
                    plan: organization.plan
                },
                suggestions: [
                    'Compre mais créditos',
                    'Reduza a quantidade de emails no arquivo',
                    'Faça upgrade do seu plano'
                ]
            });
        }

        // ================================================
        // CRIAR JOB ASSÍNCRONO
        // ================================================
        const jobData = {
            organizationId,
            userId: req.user.id,
            emailsList,
            emailsWithInfo,
            parseResult,
            userData,
            fileName: req.file.originalname,
            fileSize: req.file.size
        };

        // Criar job assíncrono
        const jobId = await asyncValidationService.createValidationJob(jobData);

        console.log(`🚀 Job assíncrono criado: ${jobId}`);

        // ================================================
        // RESPOSTA IMEDIATA PARA O USUÁRIO
        // ================================================
        res.json({
            success: true,
            message: `📧 Seu arquivo está sendo processado! Você receberá um e-mail com o relatório em breve.`,
            jobId,
            status: 'processing',
            user: {
                name: userData.fullName,
                email: userData.email,
                company: userData.company
            },
            preview: {
                totalEmails: emailsList.length,
                uniqueEmails: parseResult.stats.uniqueEmails,
                duplicates: parseResult.stats.duplicatesCount,
                corrected: parseResult.stats.correctedCount,
                fileName: req.file.originalname,
                fileSize: req.file.size
            },
            processing: {
                estimatedTime: `${Math.ceil(emailsList.length / 100)} minutos`,
                reportWillBeSentTo: userData.email,
                statusCheckUrl: `/api/validation/status/${jobId}`
            },
            credits: {
                organization: organization.name,
                plan: organization.plan,
                available: availableCredits,
                willBeUsed: requiredCredits,
                remainingAfter: availableCredits - requiredCredits
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

// ================================================
// VALIDAÇÃO EM LOTE VIA TEXTO (NOVO ENDPOINT)
// ================================================
app.post('/api/validate/batch-text', authenticateToken, [
    body('emails').isArray().withMessage('Lista de emails deve ser um array'),
    body('emails.*').isEmail().withMessage('Todos os itens devem ser emails válidos')
], async (req, res) => {
    try {
        console.log('🔤 Iniciando validação em lote via texto...');

        // Validar dados de entrada
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                error: 'Dados de entrada inválidos',
                details: errors.array()
            });
        }

        const { emails } = req.body;
        const emailCount = emails.length;

        console.log(`📧 Recebidos ${emailCount} emails para validação`);

        if (emailCount === 0) {
            return res.status(400).json({
                success: false,
                error: 'Lista de emails não pode estar vazia'
            });
        }

        if (emailCount > 1000) {
            return res.status(400).json({
                success: false,
                error: 'Máximo de 1000 emails por vez. Use o upload de arquivo para listas maiores.'
            });
        }

        // Verificar créditos disponíveis
        const organizationId = await getUserOrganizationId(req.user.id);
        if (!organizationId) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        const creditsResult = await db.pool.query(`
            SELECT
                name,
                plan,
                balance_credits
            FROM tenant.organizations
            WHERE id = $1
        `, [organizationId]);

        if (creditsResult.rows.length === 0) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        const organization = creditsResult.rows[0];
        const availableCredits = organization.balance_credits || 0;

        console.log(`[CRÉDITOS] Verificando: ${emailCount} necessários, ${availableCredits} disponíveis`);

        if (availableCredits < emailCount) {
            return res.status(429).json({
                success: false,
                error: 'Créditos insuficientes',
                code: 'QUOTA_EXCEEDED',
                message: `Você precisa de ${emailCount} créditos, mas tem apenas ${availableCredits} disponíveis`,
                details: {
                    available: availableCredits,
                    required: emailCount,
                    deficit: emailCount - availableCredits
                }
            });
        }

        // Processar validação
        console.log(`🔍 Validando ${emailCount} emails...`);

        const validationPromises = emails.map(email =>
            ultimateValidator.validateEmail(email.trim())
        );

        const results = await Promise.all(validationPromises);

        // Consumir créditos
        try {
            const useCreditsResult = await db.pool.query(
                `SELECT tenant.use_credits($1, $2, $3) as new_balance`,
                [
                    organizationId,
                    emailCount,
                    `Validação em lote de ${emailCount} emails via texto`
                ]
            );

            const newBalance = useCreditsResult.rows[0].new_balance;
            console.log(`[CRÉDITOS] Consumidos ${emailCount} créditos. Saldo atual: ${newBalance}`);

            // Adicionar headers de créditos
            res.set({
                'X-Credits-Available': newBalance,
                'X-Credits-Used': emailCount,
                'X-Credits-Previous': availableCredits
            });

        } catch (creditsError) {
            console.error('[CRÉDITOS] Erro ao consumir créditos:', creditsError.message);
            return res.status(500).json({
                success: false,
                error: 'Erro ao processar créditos'
            });
        }

        // Estatísticas
        const validCount = results.filter(r => r.valid).length;
        const avgScore = results.reduce((acc, r) => acc + r.score, 0) / results.length;

        console.log(`✅ Validação concluída: ${validCount}/${emailCount} válidos`);

        res.json({
            success: true,
            message: `${emailCount} emails validados com sucesso!`,
            results: results,
            stats: {
                total: emailCount,
                valid: validCount,
                invalid: emailCount - validCount,
                validPercentage: Math.round((validCount / emailCount) * 100),
                averageScore: Math.round(avgScore * 100)
            },
            credits: {
                organization: organization.name,
                plan: organization.plan,
                creditsUsed: emailCount,
                newBalance: availableCredits - emailCount
            }
        });

    } catch (error) {
        console.error('❌ Erro na validação em lote via texto:', error);
        res.status(500).json({
            success: false,
            error: 'Erro interno do servidor',
            message: error.message
        });
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

// Obter dados da organização do usuário
app.get('/api/user/organization', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const organizationId = await getUserOrganizationId(userId);

        if (!organizationId) {
            return res.status(404).json({
                success: false,
                error: 'Usuário não possui organização associada'
            });
        }

        // Buscar dados completos da organização
        const result = await db.pool.query(
            `SELECT
                id,
                name,
                slug,
                email,
                plan,
                max_validations,
                validations_used,
                stripe_customer_id,
                created_at
            FROM tenant.organizations
            WHERE id = $1`,
            [organizationId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Organização não encontrada'
            });
        }

        const organization = result.rows[0];

        res.json({
            success: true,
            organization: {
                id: organization.id,
                name: organization.name,
                slug: organization.slug,
                email: organization.email,
                plan: organization.plan,
                maxValidations: organization.max_validations,
                validationsUsed: organization.validations_used,
                stripeCustomerId: organization.stripe_customer_id,
                createdAt: organization.created_at
            }
        });
    } catch (error) {
        console.error('Erro ao buscar dados da organização:', error);
        res.status(500).json({ error: 'Erro ao buscar dados da organização' });
    }
});

// ================================================
// ENDPOINTS DE MONITORAMENTO DE JOBS ASSÍNCRONOS
// ================================================

// Verificar status de um job específico
app.get('/api/validation/status/:jobId', authenticateToken, async (req, res) => {
    // Headers para prevenir cache
    res.set({
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0'
    });

    try {
        const { jobId } = req.params;
        const userId = req.user.id;

        // Verificar se o job existe no serviço (se inicializado)
        let job = null;
        if (asyncValidationService) {
            job = asyncValidationService.getJobStatus(jobId);
            console.log(`[DEBUG] Job ${jobId} encontrado na memória: ${job ? 'SIM' : 'NÃO'}`);
        } else {
            console.log(`[DEBUG] AsyncValidationService não inicializado, buscando no banco`);
        }

        if (!job) {
            // Verificar no histórico do banco de dados
            const historyResult = await db.pool.query(
                `SELECT
                    vh.*,
                    u.first_name,
                    u.last_name,
                    o.name as organization_name
                FROM validation.validation_history vh
                JOIN auth.users u ON vh.user_id = u.id
                JOIN tenant.organizations o ON vh.organization_id = o.id
                WHERE vh.batch_id = $1 AND vh.user_id = $2`,
                [jobId, userId]
            );

            if (historyResult.rows.length === 0) {
                return res.status(404).json({
                    success: false,
                    error: 'Job não encontrado'
                });
            }

            const history = historyResult.rows[0];

            return res.json({
                success: true,
                jobId: jobId,
                status: history.status,
                progress: history.status === 'completed' ? 100 : 0,
                result: history.status === 'completed' ? {
                    totalEmails: history.total_emails,
                    validEmails: history.emails_valid,
                    invalidEmails: history.emails_invalid,
                    correctedEmails: history.emails_corrected,
                    successRate: history.success_rate,
                    qualityScore: history.quality_score,
                    processingTime: history.processing_time_seconds,
                    completedAt: history.completed_at
                } : null,
                error: history.error_message
            });
        }

        // Verificar se o job pertence ao usuário
        if (job.data.userId !== userId) {
            return res.status(403).json({
                success: false,
                error: 'Acesso negado'
            });
        }

        // Calcular progresso estimado
        let progress = 0;
        console.log(`[DEBUG] Job ${jobId} status na memória: ${job.status}`);

        if (job.status === 'completed' || job.status === 'failed') {
            progress = 100;
            console.log(`[DEBUG] Job ${jobId} completed/failed - progress: 100%`);
        } else if (job.status === 'processing') {
            // Progresso estimado baseado no tempo decorrido
            const elapsed = Date.now() - job.startedAt?.getTime();
            const estimated = job.data.emailsList.length * 100; // ~100ms por email
            progress = Math.min(90, Math.round((elapsed / estimated) * 100));
            console.log(`[DEBUG] Job ${jobId} processing - elapsed: ${elapsed}ms, progress: ${progress}%`);
        } else {
            console.log(`[DEBUG] Job ${jobId} status desconhecido: ${job.status}`);
        }

        res.json({
            success: true,
            jobId: job.id,
            status: job.status,
            progress: progress,
            createdAt: job.createdAt,
            startedAt: job.startedAt,
            completedAt: job.completedAt,
            emailsToProcess: job.data.emailsList.length,
            result: job.result || null,
            error: job.error || null
        });

    } catch (error) {
        console.error('Erro ao verificar status do job:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao verificar status do job'
        });
    }
});

// Listar jobs do usuário
app.get('/api/validation/jobs', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const organizationId = await getUserOrganizationId(userId);

        if (!organizationId) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        // Buscar jobs do histórico (concluídos)
        const historyResult = await db.pool.query(
            `SELECT
                vh.batch_id as job_id,
                vh.status,
                vh.validation_type,
                vh.total_emails,
                vh.emails_valid,
                vh.emails_invalid,
                vh.success_rate,
                vh.quality_score,
                vh.file_name,
                vh.started_at,
                vh.completed_at,
                vh.processing_time_seconds,
                vh.credits_consumed
            FROM validation.validation_history vh
            WHERE vh.user_id = $1
            ORDER BY vh.created_at DESC
            LIMIT 20`,
            [userId]
        );

        // Buscar jobs ativos na memória
        const activeJobs = asyncValidationService.getAllJobs()
            .filter(job => job.data.userId === userId)
            .map(job => ({
                job_id: job.id,
                status: job.status,
                validation_type: 'file_upload',
                total_emails: job.data.emailsList.length,
                emails_valid: null,
                emails_invalid: null,
                success_rate: null,
                quality_score: null,
                file_name: job.data.fileName,
                started_at: job.startedAt,
                completed_at: job.completedAt,
                processing_time_seconds: null,
                credits_consumed: job.status === 'completed' ? job.data.emailsList.length : null
            }));

        // Combinar resultados
        const allJobs = [...activeJobs, ...historyResult.rows]
            .sort((a, b) => new Date(b.started_at || b.created_at) - new Date(a.started_at || a.created_at));

        res.json({
            success: true,
            jobs: allJobs
        });

    } catch (error) {
        console.error('Erro ao listar jobs:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao listar jobs'
        });
    }
});

// Cancelar job (se ainda estiver na fila)
app.delete('/api/validation/jobs/:jobId', authenticateToken, async (req, res) => {
    try {
        const { jobId } = req.params;
        const userId = req.user.id;

        const job = asyncValidationService.getJobStatus(jobId);

        if (!job) {
            return res.status(404).json({
                success: false,
                error: 'Job não encontrado'
            });
        }

        if (job.data.userId !== userId) {
            return res.status(403).json({
                success: false,
                error: 'Acesso negado'
            });
        }

        if (job.status === 'processing') {
            return res.status(400).json({
                success: false,
                error: 'Não é possível cancelar job em processamento'
            });
        }

        const cancelled = asyncValidationService.cancelJob(jobId);

        if (cancelled) {
            res.json({
                success: true,
                message: 'Job cancelado com sucesso'
            });
        } else {
            res.status(400).json({
                success: false,
                error: 'Não foi possível cancelar o job'
            });
        }

    } catch (error) {
        console.error('Erro ao cancelar job:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao cancelar job'
        });
    }
});

// ================================================
// ENDPOINTS DE HISTÓRICO DE VALIDAÇÕES
// ================================================

// Listar histórico de validações da organização
app.get('/api/validation/history', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const organizationId = await getUserOrganizationId(userId);

        if (!organizationId) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        const { page = 1, limit = 20, status, startDate, endDate } = req.query;
        const offset = (parseInt(page) - 1) * parseInt(limit);

        let whereClause = 'WHERE vh.organization_id = $1';
        let params = [organizationId];
        let paramCount = 1;

        if (status) {
            paramCount++;
            whereClause += ` AND vh.status = $${paramCount}`;
            params.push(status);
        }

        if (startDate) {
            paramCount++;
            whereClause += ` AND vh.created_at >= $${paramCount}`;
            params.push(startDate);
        }

        if (endDate) {
            paramCount++;
            whereClause += ` AND vh.created_at <= $${paramCount}`;
            params.push(endDate);
        }

        // Buscar registros
        const historyQuery = `
            SELECT
                vh.id,
                vh.batch_id,
                vh.user_id,
                vh.validation_type,
                vh.status,
                vh.total_emails,
                vh.emails_processed,
                vh.emails_valid,
                vh.emails_invalid,
                vh.emails_corrected,
                vh.emails_duplicated,
                vh.success_rate,
                vh.quality_score,
                vh.average_score,
                vh.credits_consumed,
                vh.file_name,
                vh.file_size,
                vh.processing_time_seconds,
                vh.started_at,
                vh.completed_at,
                vh.created_at,
                u.first_name,
                u.last_name,
                u.email as user_email
            FROM validation.validation_history vh
            JOIN auth.users u ON vh.user_id = u.id
            ${whereClause}
            ORDER BY vh.created_at DESC
            LIMIT $${paramCount + 1} OFFSET $${paramCount + 2}
        `;

        params.push(parseInt(limit), offset);

        const historyResult = await db.pool.query(historyQuery, params);

        // Contar total de registros
        const countQuery = `
            SELECT COUNT(*) as total
            FROM validation.validation_history vh
            ${whereClause}
        `;

        const countResult = await db.pool.query(countQuery, params.slice(0, paramCount));
        const totalRecords = parseInt(countResult.rows[0].total);

        res.json({
            success: true,
            data: historyResult.rows.map(row => ({
                id: row.id,
                jobId: row.batch_id,
                user: {
                    id: row.user_id,
                    name: `${row.first_name} ${row.last_name}`,
                    email: row.user_email
                },
                type: row.validation_type,
                status: row.status,
                stats: {
                    totalEmails: row.total_emails,
                    processed: row.emails_processed,
                    valid: row.emails_valid,
                    invalid: row.emails_invalid,
                    corrected: row.emails_corrected,
                    duplicated: row.emails_duplicated,
                    successRate: row.success_rate,
                    qualityScore: row.quality_score,
                    averageScore: row.average_score
                },
                file: {
                    name: row.file_name,
                    size: row.file_size
                },
                credits: row.credits_consumed,
                timing: {
                    processingSeconds: row.processing_time_seconds,
                    startedAt: row.started_at,
                    completedAt: row.completed_at,
                    createdAt: row.created_at
                }
            })),
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total: totalRecords,
                pages: Math.ceil(totalRecords / parseInt(limit))
            }
        });

    } catch (error) {
        console.error('Erro ao buscar histórico:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar histórico de validações'
        });
    }
});

// Estatísticas resumidas do histórico
app.get('/api/validation/history/stats', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const organizationId = await getUserOrganizationId(userId);

        if (!organizationId) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        // Estatísticas gerais
        const generalStats = await db.pool.query(`
            SELECT
                COUNT(*) as total_validations,
                SUM(total_emails) as total_emails_processed,
                SUM(emails_valid) as total_valid_emails,
                SUM(emails_invalid) as total_invalid_emails,
                SUM(emails_corrected) as total_corrected_emails,
                SUM(credits_consumed) as total_credits_used,
                ROUND(AVG(success_rate), 2) as avg_success_rate,
                ROUND(AVG(quality_score), 2) as avg_quality_score,
                MIN(created_at) as first_validation,
                MAX(created_at) as last_validation
            FROM validation.validation_history
            WHERE organization_id = $1 AND status = 'completed'
        `, [organizationId]);

        // Estatísticas dos últimos 30 dias
        const recentStats = await db.pool.query(`
            SELECT
                COUNT(*) as recent_validations,
                SUM(total_emails) as recent_emails,
                SUM(credits_consumed) as recent_credits
            FROM validation.validation_history
            WHERE organization_id = $1
                AND status = 'completed'
                AND created_at >= CURRENT_DATE - INTERVAL '30 days'
        `, [organizationId]);

        // Estatísticas por usuário
        const userStats = await db.pool.query(`
            SELECT
                u.first_name,
                u.last_name,
                u.email,
                COUNT(*) as validations_count,
                SUM(vh.total_emails) as emails_processed,
                SUM(vh.credits_consumed) as credits_used,
                ROUND(AVG(vh.success_rate), 2) as avg_success_rate
            FROM validation.validation_history vh
            JOIN auth.users u ON vh.user_id = u.id
            WHERE vh.organization_id = $1 AND vh.status = 'completed'
            GROUP BY u.id, u.first_name, u.last_name, u.email
            ORDER BY validations_count DESC
            LIMIT 10
        `, [organizationId]);

        const general = generalStats.rows[0];
        const recent = recentStats.rows[0];

        res.json({
            success: true,
            stats: {
                overall: {
                    totalValidations: parseInt(general.total_validations || 0),
                    totalEmailsProcessed: parseInt(general.total_emails_processed || 0),
                    totalValidEmails: parseInt(general.total_valid_emails || 0),
                    totalInvalidEmails: parseInt(general.total_invalid_emails || 0),
                    totalCorrectedEmails: parseInt(general.total_corrected_emails || 0),
                    totalCreditsUsed: parseInt(general.total_credits_used || 0),
                    averageSuccessRate: parseFloat(general.avg_success_rate || 0),
                    averageQualityScore: parseFloat(general.avg_quality_score || 0),
                    firstValidation: general.first_validation,
                    lastValidation: general.last_validation
                },
                recent30Days: {
                    validations: parseInt(recent.recent_validations || 0),
                    emails: parseInt(recent.recent_emails || 0),
                    credits: parseInt(recent.recent_credits || 0)
                },
                byUser: userStats.rows.map(user => ({
                    name: `${user.first_name} ${user.last_name}`,
                    email: user.email,
                    validations: parseInt(user.validations_count),
                    emailsProcessed: parseInt(user.emails_processed),
                    creditsUsed: parseInt(user.credits_used),
                    averageSuccessRate: parseFloat(user.avg_success_rate || 0)
                }))
            }
        });

    } catch (error) {
        console.error('Erro ao buscar estatísticas:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar estatísticas do histórico'
        });
    }
});

// Estatísticas diárias para gráficos
app.get('/api/validation/history/daily', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const organizationId = await getUserOrganizationId(userId);

        if (!organizationId) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        const { days = 30 } = req.query;

        const dailyStats = await db.pool.query(`
            SELECT * FROM validation.daily_validation_stats
            WHERE organization_id = $1
                AND validation_date >= CURRENT_DATE - INTERVAL '${parseInt(days)} days'
            ORDER BY validation_date DESC
        `, [organizationId]);

        res.json({
            success: true,
            data: dailyStats.rows.map(row => ({
                date: row.validation_date,
                validations: parseInt(row.validations_count),
                totalEmails: parseInt(row.total_emails),
                validEmails: parseInt(row.valid_emails),
                successPercentage: parseFloat(row.success_percentage),
                averageQuality: parseFloat(row.avg_quality || 0),
                creditsUsed: parseInt(row.credits_used)
            }))
        });

    } catch (error) {
        console.error('Erro ao buscar estatísticas diárias:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar estatísticas diárias'
        });
    }
});

// Stripe Public Key
app.get('/api/stripe/public-key', (req, res) => {
    res.json({
        publicKey: process.env.STRIPE_PUBLISHABLE_KEY || 'pk_test_51RwQCiDDs93u86g8nLmxFiOtlX9ng32QJu4johWjyI1WiPYMwoK1R14gNY2S9eZfoY6T6NZTa8jl3VVTTLx7ELQJ00xElxaNWp'
    });
});

// Executar migração do histórico de validações
app.post('/api/admin/migrate-validation-history', authenticateToken, async (req, res) => {
    try {
        // Verificar se o usuário é admin (implementar verificação adequada)
        const fs = require('fs').promises;
        const migrationSQL = await fs.readFile(
            path.join(__dirname, 'services/migrations/013_create_validation_history.sql'),
            'utf-8'
        );

        await db.pool.query(migrationSQL);

        res.json({
            success: true,
            message: 'Migração do histórico de validações executada com sucesso'
        });

    } catch (error) {
        console.error('Erro na migração:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao executar migração'
        });
    }
});

// ================================================
// ENDPOINTS DE PLANOS PARA CHECKOUT
// ================================================

// Buscar todos os planos ativos
app.get('/api/billing/plans', async (req, res) => {
    try {
        const { type, period } = req.query;

        let query = `
            SELECT
                id,
                plan_key,
                name,
                type,
                period,
                emails_limit,
                price,
                original_price,
                price_per_month,
                price_per_email,
                discount_percentage,
                savings_amount,
                features,
                benefits,
                is_popular,
                display_order,
                metadata
            FROM billing.plans
            WHERE is_active = true
        `;

        const params = [];
        let paramCount = 0;

        if (type) {
            paramCount++;
            query += ` AND type = $${paramCount}`;
            params.push(type);
        }

        if (period) {
            paramCount++;
            query += ` AND period = $${paramCount}`;
            params.push(period);
        }

        query += ' ORDER BY display_order ASC, price ASC';

        const result = await db.pool.query(query, params);

        // Formatar dados para o frontend
        const plans = result.rows.map(plan => ({
            id: plan.id,
            planKey: plan.plan_key,
            name: plan.name,
            type: plan.type,
            period: plan.period,
            emailsLimit: plan.emails_limit,
            price: parseFloat(plan.price),
            originalPrice: plan.original_price ? parseFloat(plan.original_price) : null,
            pricePerMonth: plan.price_per_month ? parseFloat(plan.price_per_month) : null,
            pricePerEmail: plan.price_per_email ? parseFloat(plan.price_per_email) : null,
            discountPercentage: plan.discount_percentage || 0,
            savingsAmount: plan.savings_amount ? parseFloat(plan.savings_amount) : null,
            features: plan.features || [],
            benefits: plan.benefits || [],
            isPopular: plan.is_popular || false,
            displayOrder: plan.display_order || 0,
            metadata: plan.metadata || {}
        }));

        res.json({
            success: true,
            plans: plans
        });

    } catch (error) {
        console.error('Erro ao buscar planos:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar planos disponíveis'
        });
    }
});

// Buscar plano específico por ID ou chave
app.get('/api/billing/plans/:identifier', async (req, res) => {
    try {
        const { identifier } = req.params;

        // Tentar buscar por ID (número) ou por plan_key (string)
        const isNumeric = /^\d+$/.test(identifier);
        const query = `
            SELECT
                id,
                plan_key,
                name,
                type,
                period,
                emails_limit,
                price,
                original_price,
                price_per_month,
                price_per_email,
                discount_percentage,
                savings_amount,
                features,
                benefits,
                is_popular,
                display_order,
                metadata
            FROM billing.plans
            WHERE is_active = true AND ${isNumeric ? 'id = $1' : 'plan_key = $1'}
        `;

        const result = await db.pool.query(query, [identifier]);

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Plano não encontrado'
            });
        }

        const plan = result.rows[0];

        res.json({
            success: true,
            plan: {
                id: plan.id,
                planKey: plan.plan_key,
                name: plan.name,
                type: plan.type,
                period: plan.period,
                emailsLimit: plan.emails_limit,
                price: parseFloat(plan.price),
                originalPrice: plan.original_price ? parseFloat(plan.original_price) : null,
                pricePerMonth: plan.price_per_month ? parseFloat(plan.price_per_month) : null,
                pricePerEmail: plan.price_per_email ? parseFloat(plan.price_per_email) : null,
                discountPercentage: plan.discount_percentage || 0,
                savingsAmount: plan.savings_amount ? parseFloat(plan.savings_amount) : null,
                features: plan.features || [],
                benefits: plan.benefits || [],
                isPopular: plan.is_popular || false,
                displayOrder: plan.display_order || 0,
                metadata: plan.metadata || {}
            }
        });

    } catch (error) {
        console.error('Erro ao buscar plano:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar detalhes do plano'
        });
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
    - POST /api/validate/batch-text
    - GET  /api/validator/stats
    - POST /api/validator/cache/clear
    - GET  /api/reports/download/:filename
    - POST /api/reports/generate
    - GET  /api/user/profile
    - GET  /api/user/quota
    - GET  /api/user/quota/summary
    - GET  /api/user/stats
    - GET  /api/user/organization
    - GET  /api/stripe/public-key

    JOB MONITORING:
    - GET  /api/validation/status/:jobId
    - GET  /api/validation/jobs
    - DELETE /api/validation/jobs/:jobId

    VALIDATION HISTORY:
    - GET  /api/validation/history
    - GET  /api/validation/history/stats
    - GET  /api/validation/history/daily

    ADMIN:
    - POST /api/admin/migrate-validation-history

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
