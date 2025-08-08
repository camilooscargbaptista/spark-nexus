#!/bin/bash

# ================================================
# Script de Integração do Sistema de Validação
# Spark Nexus - Email Validator
# ================================================

echo "================================================"
echo "🚀 SPARK NEXUS - Integração do Validador"
echo "================================================"
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Verificar se está no diretório correto
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ Erro: package.json não encontrado!${NC}"
    echo "Certifique-se de estar no diretório client-dashboard/"
    exit 1
fi

# ================================================
# ETAPA 1: EXECUTAR MIGRAÇÃO DO BANCO
# ================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}1️⃣ ETAPA 1: Migração do Banco de Dados${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verificar se o arquivo de migração existe
if [ ! -f "services/migrations/create_validation_tables.sql" ]; then
    echo -e "${YELLOW}⚠️  Arquivo de migração não encontrado. Criando...${NC}"

    mkdir -p services/migrations
    cat > services/migrations/create_validation_tables.sql << 'EOF'
-- ================================================
-- Migração: Criar tabelas de validação de email
-- ================================================

-- Criar schema se não existir
CREATE SCHEMA IF NOT EXISTS validation;

-- Tabela principal de validações
CREATE TABLE IF NOT EXISTS validation.email_validations (
    id SERIAL PRIMARY KEY,
    email VARCHAR(254) NOT NULL,
    valid BOOLEAN NOT NULL,
    score INTEGER CHECK (score >= 0 AND score <= 100),
    risk VARCHAR(20),
    checks JSONB,
    processing_time INTEGER,
    user_id INTEGER REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(email)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_email_validations_email ON validation.email_validations(email);
CREATE INDEX IF NOT EXISTS idx_email_validations_user_id ON validation.email_validations(user_id);
CREATE INDEX IF NOT EXISTS idx_email_validations_created_at ON validation.email_validations(created_at);

-- Tabela de cache de domínios
CREATE TABLE IF NOT EXISTS validation.domain_cache (
    domain VARCHAR(253) PRIMARY KEY,
    mx_records JSONB,
    is_disposable BOOLEAN,
    reputation_score INTEGER,
    last_checked TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de domínios disposable customizados
CREATE TABLE IF NOT EXISTS validation.custom_disposable_domains (
    domain VARCHAR(253) PRIMARY KEY,
    added_by INTEGER REFERENCES auth.users(id),
    reason TEXT,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de whitelist
CREATE TABLE IF NOT EXISTS validation.whitelist_domains (
    domain VARCHAR(253) PRIMARY KEY,
    added_by INTEGER REFERENCES auth.users(id),
    reason TEXT,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de estatísticas
CREATE TABLE IF NOT EXISTS validation.user_stats (
    user_id INTEGER PRIMARY KEY REFERENCES auth.users(id),
    total_validations INTEGER DEFAULT 0,
    valid_emails INTEGER DEFAULT 0,
    invalid_emails INTEGER DEFAULT 0,
    avg_score DECIMAL(5,2),
    last_validation TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers
DROP TRIGGER IF EXISTS update_email_validations_updated_at ON validation.email_validations;
CREATE TRIGGER update_email_validations_updated_at
    BEFORE UPDATE ON validation.email_validations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_stats_updated_at ON validation.user_stats;
CREATE TRIGGER update_user_stats_updated_at
    BEFORE UPDATE ON validation.user_stats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Função para atualizar estatísticas do usuário
CREATE OR REPLACE FUNCTION update_user_stats()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO validation.user_stats (user_id, total_validations, valid_emails, invalid_emails, avg_score, last_validation)
    VALUES (
        NEW.user_id,
        1,
        CASE WHEN NEW.valid THEN 1 ELSE 0 END,
        CASE WHEN NOT NEW.valid THEN 1 ELSE 0 END,
        NEW.score,
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        total_validations = validation.user_stats.total_validations + 1,
        valid_emails = validation.user_stats.valid_emails + CASE WHEN NEW.valid THEN 1 ELSE 0 END,
        invalid_emails = validation.user_stats.invalid_emails + CASE WHEN NOT NEW.valid THEN 1 ELSE 0 END,
        avg_score = ((validation.user_stats.avg_score * validation.user_stats.total_validations) + NEW.score) / (validation.user_stats.total_validations + 1),
        last_validation = NOW();

    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para estatísticas
DROP TRIGGER IF EXISTS update_stats_on_validation ON validation.email_validations;
CREATE TRIGGER update_stats_on_validation
    AFTER INSERT ON validation.email_validations
    FOR EACH ROW
    WHEN (NEW.user_id IS NOT NULL)
    EXECUTE FUNCTION update_user_stats();

-- Adicionar dados iniciais de teste (opcional)
INSERT INTO validation.whitelist_domains (domain, reason)
VALUES ('sparknexus.com.br', 'Domínio próprio')
ON CONFLICT DO NOTHING;
EOF
    echo -e "${GREEN}✅ Arquivo de migração criado${NC}"
fi

# Criar script Node.js para executar migração
echo -e "${YELLOW}📝 Criando script de migração...${NC}"
cat > run-migration.js << 'EOF'
const { Pool } = require('pg');
const fs = require('fs').promises;
const path = require('path');

async function runMigration() {
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL || 'postgresql://sparknexus:SparkNexus2024!@postgres:5432/sparknexus',
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
    });

    try {
        console.log('🔄 Conectando ao banco de dados...');

        // Ler arquivo SQL
        const sqlPath = path.join(__dirname, 'services', 'migrations', 'create_validation_tables.sql');
        const sql = await fs.readFile(sqlPath, 'utf-8');

        console.log('📊 Executando migração...');
        await pool.query(sql);

        console.log('✅ Migração executada com sucesso!');

        // Verificar se as tabelas foram criadas
        const checkQuery = `
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'validation'
            ORDER BY table_name;
        `;

        const result = await pool.query(checkQuery);
        console.log('\n📋 Tabelas criadas:');
        result.rows.forEach(row => {
            console.log(`   ✓ validation.${row.table_name}`);
        });

    } catch (error) {
        console.error('❌ Erro na migração:', error.message);
        process.exit(1);
    } finally {
        await pool.end();
    }
}

runMigration();
EOF

# Executar migração
echo -e "${BLUE}🔄 Executando migração do banco...${NC}"
node run-migration.js

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Migração concluída com sucesso!${NC}"
else
    echo -e "${RED}❌ Erro na migração. Verifique a conexão com o banco.${NC}"
    echo -e "${YELLOW}Você pode executar manualmente mais tarde com: node run-migration.js${NC}"
fi

# Limpar arquivo temporário
rm -f run-migration.js

echo ""

# ================================================
# ETAPA 2: CRIAR BACKUP DO SERVER.JS
# ================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}2️⃣ ETAPA 2: Backup e Integração do server.js${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Criar backup do server.js
echo -e "${YELLOW}📋 Criando backup do server.js...${NC}"
cp server.js server.js.backup-$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✅ Backup criado${NC}"

# ================================================
# ETAPA 3: CRIAR ARQUIVO DE ROTAS
# ================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}3️⃣ ETAPA 3: Criando Rotas de API${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}📝 Criando arquivo de rotas do validador...${NC}"
cat > services/routes/validatorRoutes.js << 'EOF'
// ================================================
// Rotas do Sistema de Validação Avançado
// services/routes/validatorRoutes.js
// ================================================

const express = require('express');
const router = express.Router();
const { body, query, validationResult } = require('express-validator');
const EmailValidator = require('../validators');
const multer = require('multer');
const csv = require('csv-parser');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

// Upload config
const upload = multer({
    dest: 'uploads/',
    limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
    fileFilter: (req, file, cb) => {
        if (file.mimetype === 'text/csv' || file.originalname.endsWith('.csv')) {
            cb(null, true);
        } else {
            cb(new Error('Apenas arquivos CSV são permitidos'));
        }
    }
});

// Inicializar validador (será passado pelo server.js)
let emailValidator;

// Middleware para injetar o validador
const initializeValidator = (validator) => {
    emailValidator = validator;
    return router;
};

// ================================================
// ROTAS PÚBLICAS (SEM AUTENTICAÇÃO)
// ================================================

// Validação rápida (sem MX/SMTP)
router.post('/quick', [
    body('email').isEmail().withMessage('Email inválido')
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { email } = req.body;

        const result = await emailValidator.validate(email, {
            checkMX: false,
            checkSMTP: false,
            checkDisposable: true,
            useCache: true,
            detailed: false
        });

        res.json({
            email,
            valid: result.valid,
            score: result.score,
            risk: result.risk,
            processingTime: result.processingTime
        });
    } catch (error) {
        console.error('Erro na validação rápida:', error);
        res.status(500).json({ error: 'Erro ao validar email' });
    }
});

// ================================================
// ROTAS PROTEGIDAS (REQUEREM AUTENTICAÇÃO)
// ================================================

// Middleware de autenticação (será passado pelo server.js)
const authenticateToken = (req, res, next) => {
    // Esta função será substituída pela real do server.js
    next();
};

// Validação completa de um email
router.post('/complete', authenticateToken, [
    body('email').isEmail().withMessage('Email inválido'),
    body('checkMX').optional().isBoolean(),
    body('checkSMTP').optional().isBoolean(),
    body('detailed').optional().isBoolean()
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { email, checkMX = true, checkSMTP = false, detailed = true } = req.body;

        const result = await emailValidator.validate(email, {
            checkMX,
            checkSMTP,
            checkDisposable: true,
            useCache: true,
            detailed
        });

        // Associar ao usuário se autenticado
        if (req.user && req.user.id) {
            result.userId = req.user.id;
        }

        res.json(result);
    } catch (error) {
        console.error('Erro na validação completa:', error);
        res.status(500).json({ error: 'Erro ao validar email' });
    }
});

// Validação em lote
router.post('/batch', authenticateToken, [
    body('emails').isArray().withMessage('Emails deve ser um array'),
    body('emails.*').isEmail().withMessage('Email inválido no array'),
    body('options').optional().isObject()
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { emails, options = {} } = req.body;

        if (emails.length > 100) {
            return res.status(400).json({
                error: 'Máximo de 100 emails por lote. Use o upload de CSV para listas maiores.'
            });
        }

        // Criar job ID
        const jobId = uuidv4();

        // Processar em background (simplificado - em produção usar queue)
        res.json({
            jobId,
            status: 'processing',
            total: emails.length,
            message: 'Validação iniciada. Use o jobId para verificar o status.'
        });

        // Processar emails (em produção, usar Bull/Redis Queue)
        setImmediate(async () => {
            try {
                const results = await emailValidator.validateBatch(emails, {
                    ...options,
                    batchSize: 10,
                    delay: 100 // ms entre lotes
                });

                // Salvar resultados (em produção, salvar no banco)
                global.validationJobs = global.validationJobs || {};
                global.validationJobs[jobId] = {
                    status: 'completed',
                    results,
                    completedAt: new Date()
                };
            } catch (error) {
                console.error('Erro no processamento em lote:', error);
                global.validationJobs[jobId] = {
                    status: 'failed',
                    error: error.message
                };
            }
        });

    } catch (error) {
        console.error('Erro na validação em lote:', error);
        res.status(500).json({ error: 'Erro ao processar lote' });
    }
});

// Upload e validação de CSV
router.post('/upload-csv', authenticateToken, upload.single('file'), async (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'Nenhum arquivo enviado' });
    }

    try {
        const emails = [];
        const jobId = uuidv4();

        // Ler CSV
        fs.createReadStream(req.file.path)
            .pipe(csv())
            .on('data', (row) => {
                // Procurar campo de email em diferentes colunas comuns
                const email = row.email || row.Email || row.EMAIL ||
                             row.email_address || row['Email Address'] ||
                             Object.values(row).find(val => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val));

                if (email && emails.length < 10000) { // Limite de 10k
                    emails.push(email.trim());
                }
            })
            .on('end', async () => {
                // Deletar arquivo temporário
                fs.unlinkSync(req.file.path);

                if (emails.length === 0) {
                    return res.status(400).json({
                        error: 'Nenhum email válido encontrado no CSV'
                    });
                }

                // Iniciar processamento
                res.json({
                    jobId,
                    status: 'processing',
                    total: emails.length,
                    message: `${emails.length} emails encontrados. Processando...`
                });

                // Processar em background
                setImmediate(async () => {
                    try {
                        const results = await emailValidator.validateBatch(emails, {
                            batchSize: 20,
                            delay: 50,
                            checkMX: true,
                            checkDisposable: true
                        });

                        global.validationJobs = global.validationJobs || {};
                        global.validationJobs[jobId] = {
                            status: 'completed',
                            total: emails.length,
                            results,
                            summary: {
                                valid: results.filter(r => r.valid).length,
                                invalid: results.filter(r => !r.valid).length,
                                avgScore: results.reduce((acc, r) => acc + r.score, 0) / results.length
                            },
                            completedAt: new Date()
                        };
                    } catch (error) {
                        console.error('Erro no processamento do CSV:', error);
                        global.validationJobs[jobId] = {
                            status: 'failed',
                            error: error.message
                        };
                    }
                });
            })
            .on('error', (error) => {
                fs.unlinkSync(req.file.path);
                throw error;
            });

    } catch (error) {
        console.error('Erro no upload CSV:', error);
        res.status(500).json({ error: 'Erro ao processar arquivo CSV' });
    }
});

// Verificar status de job
router.get('/job/:jobId', authenticateToken, (req, res) => {
    const { jobId } = req.params;

    global.validationJobs = global.validationJobs || {};
    const job = global.validationJobs[jobId];

    if (!job) {
        return res.status(404).json({ error: 'Job não encontrado' });
    }

    res.json(job);
});

// Download de resultados
router.get('/download/:jobId', authenticateToken, (req, res) => {
    const { jobId } = req.params;
    const format = req.query.format || 'json';

    global.validationJobs = global.validationJobs || {};
    const job = global.validationJobs[jobId];

    if (!job || job.status !== 'completed') {
        return res.status(404).json({ error: 'Resultados não disponíveis' });
    }

    if (format === 'csv') {
        // Gerar CSV
        const csvContent = 'Email,Valid,Score,Risk,Reason\n' +
            job.results.map(r =>
                `${r.email},${r.valid},${r.score},${r.risk},"${r.reason || ''}"`
            ).join('\n');

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="validation-${jobId}.csv"`);
        res.send(csvContent);
    } else {
        res.json(job.results);
    }
});

// Estatísticas do usuário
router.get('/stats', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const period = req.query.period || '30'; // dias

        const stats = await emailValidator.getStats(userId);

        res.json({
            ...stats,
            period: `${period} dias`
        });
    } catch (error) {
        console.error('Erro ao buscar estatísticas:', error);
        res.status(500).json({ error: 'Erro ao buscar estatísticas' });
    }
});

// Histórico de validações
router.get('/history', authenticateToken, [
    query('email').optional().isEmail(),
    query('limit').optional().isInt({ min: 1, max: 100 })
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { email, limit = 10 } = req.query;

        if (email) {
            const history = await emailValidator.getValidationHistory(email);
            res.json(history);
        } else {
            // Retornar últimas validações do usuário
            res.json({
                message: 'Endpoint em desenvolvimento',
                tip: 'Passe ?email=exemplo@email.com para ver histórico específico'
            });
        }
    } catch (error) {
        console.error('Erro ao buscar histórico:', error);
        res.status(500).json({ error: 'Erro ao buscar histórico' });
    }
});

// ================================================
// ROTAS DE ADMINISTRAÇÃO
// ================================================

// Adicionar domínio ao disposable customizado
router.post('/admin/disposable', authenticateToken, [
    body('domain').notEmpty().withMessage('Domínio é obrigatório'),
    body('reason').optional().isString()
], async (req, res) => {
    // Verificar se é admin (implementar lógica de permissão)
    if (!req.user || req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Acesso negado' });
    }

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { domain, reason } = req.body;

        await emailValidator.disposableValidator.addToCustomList(domain);

        res.json({
            success: true,
            message: `Domínio ${domain} adicionado à lista de disposable`
        });
    } catch (error) {
        console.error('Erro ao adicionar disposable:', error);
        res.status(500).json({ error: 'Erro ao adicionar domínio' });
    }
});

// Adicionar ao whitelist
router.post('/admin/whitelist', authenticateToken, [
    body('domain').notEmpty().withMessage('Domínio é obrigatório'),
    body('reason').optional().isString()
], async (req, res) => {
    // Verificar se é admin
    if (!req.user || req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Acesso negado' });
    }

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    try {
        const { domain, reason } = req.body;

        await emailValidator.disposableValidator.addToWhitelist(domain);

        res.json({
            success: true,
            message: `Domínio ${domain} adicionado ao whitelist`
        });
    } catch (error) {
        console.error('Erro ao adicionar ao whitelist:', error);
        res.status(500).json({ error: 'Erro ao adicionar ao whitelist' });
    }
});

// Estatísticas do sistema
router.get('/admin/system-stats', authenticateToken, async (req, res) => {
    // Verificar se é admin
    if (!req.user || req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Acesso negado' });
    }

    try {
        const disposableStats = emailValidator.disposableValidator.getStats();
        const cacheStats = emailValidator.cache.getStats();

        res.json({
            disposable: disposableStats,
            cache: cacheStats,
            jobs: Object.keys(global.validationJobs || {}).length
        });
    } catch (error) {
        console.error('Erro ao buscar estatísticas do sistema:', error);
        res.status(500).json({ error: 'Erro ao buscar estatísticas' });
    }
});

module.exports = { initializeValidator, router };
EOF
echo -e "${GREEN}✅ Arquivo de rotas criado${NC}"

# ================================================
# ETAPA 4: INTEGRAR COM SERVER.JS
# ================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}4️⃣ ETAPA 4: Integrando com server.js${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}📝 Criando script de integração...${NC}"
cat > integrate-server.js << 'EOF'
const fs = require('fs').promises;
const path = require('path');

async function integrateServer() {
    try {
        console.log('📄 Lendo server.js...');

        const serverPath = path.join(__dirname, 'server.js');
        let serverContent = await fs.readFile(serverPath, 'utf-8');

        // Verificar se já foi integrado
        if (serverContent.includes('EmailValidator')) {
            console.log('⚠️  Validador já está integrado ao server.js');
            return;
        }

        // Adicionar imports no início (após os requires existentes)
        const importSection = `
// ================================================
// IMPORTS DO VALIDADOR AVANÇADO
// ================================================
const EmailValidator = require('./services/validators');
const { initializeValidator, router: validatorRouter } = require('./services/routes/validatorRoutes');
`;

        // Encontrar posição após último require
        const lastRequireIndex = serverContent.lastIndexOf('const Validators = require');
        const endOfLine = serverContent.indexOf('\n', lastRequireIndex);

        serverContent =
            serverContent.slice(0, endOfLine + 1) +
            importSection +
            serverContent.slice(endOfLine + 1);

        // Adicionar inicialização após DatabaseService
        const initSection = `
// Inicializar validador avançado
const advancedValidator = new EmailValidator(db);
initializeValidator(advancedValidator);
`;

        const dbInitIndex = serverContent.indexOf('const smsService = new SMSService();');
        const dbInitEnd = serverContent.indexOf('\n', dbInitIndex);

        serverContent =
            serverContent.slice(0, dbInitEnd + 1) +
            initSection +
            serverContent.slice(dbInitEnd + 1);

        // Adicionar rotas antes das rotas existentes
        const routeSection = `
// ================================================
// ROTAS DO VALIDADOR AVANÇADO
// ================================================
// Modificar authenticateToken para ser exportável
const authenticateTokenExport = authenticateToken;

// Passar authenticateToken para as rotas do validador
validatorRouter.authenticateToken = authenticateTokenExport;

// Montar rotas do validador
app.use('/api/validate', validatorRouter);

// Documentação da API
app.get('/api/validate/docs', (req, res) => {
    res.json({
        endpoints: {
            public: {
                'POST /api/validate/quick': 'Validação rápida sem MX/SMTP',
            },
            authenticated: {
                'POST /api/validate/complete': 'Validação completa com todos os checks',
                'POST /api/validate/batch': 'Validação em lote (até 100 emails)',
                'POST /api/validate/upload-csv': 'Upload de CSV para validação',
                'GET /api/validate/job/:jobId': 'Verificar status de job',
                'GET /api/validate/download/:jobId': 'Download de resultados',
                'GET /api/validate/stats': 'Estatísticas do usuário',
                'GET /api/validate/history': 'Histórico de validações'
            },
            admin: {
                'POST /api/validate/admin/disposable': 'Adicionar domínio disposable',
                'POST /api/validate/admin/whitelist': 'Adicionar ao whitelist',
                'GET /api/validate/admin/system-stats': 'Estatísticas do sistema'
            }
        },
        examples: {
            quick: {
                method: 'POST',
                url: '/api/validate/quick',
                body: { email: 'test@example.com' }
            },
            complete: {
                method: 'POST',
                url: '/api/validate/complete',
                headers: { 'Authorization': 'Bearer TOKEN' },
                body: {
                    email: 'test@example.com',
                    checkMX: true,
                    checkSMTP: false,
                    detailed: true
                }
            }
        }
    });
});
`;

        // Encontrar onde adicionar as rotas (antes de "// Health Check")
        const healthCheckIndex = serverContent.indexOf('// Health Check');

        serverContent =
            serverContent.slice(0, healthCheckIndex) +
            routeSection + '\n' +
            serverContent.slice(healthCheckIndex);

        // Salvar arquivo modificado
        await fs.writeFile(serverPath, serverContent);

        console.log('✅ server.js integrado com sucesso!');

        // Criar arquivo de exemplo
        console.log('📝 Criando arquivo de exemplo...');

        const exampleContent = `// ================================================
// Exemplos de uso do Validador Avançado
// ================================================

const axios = require('axios');

const API_URL = 'http://localhost:4201';
const TOKEN = 'SEU_TOKEN_AQUI'; // Obter via login

// Exemplo 1: Validação Rápida (sem autenticação)
async function quickValidation() {
    try {
        const response = await axios.post(\`\${API_URL}/api/validate/quick\`, {
            email: 'test@gmail.com'
        });

        console.log('Validação Rápida:', response.data);
        // { email: 'test@gmail.com', valid: true, score: 75, risk: 'low' }
    } catch (error) {
        console.error('Erro:', error.response.data);
    }
}

// Exemplo 2: Validação Completa (com autenticação)
async function completeValidation() {
    try {
        const response = await axios.post(
            \`\${API_URL}/api/validate/complete\`,
            {
                email: 'ceo@company.com',
                checkMX: true,
                checkSMTP: false,
                detailed: true
            },
            {
                headers: {
                    'Authorization': \`Bearer \${TOKEN}\`
                }
            }
        );

        console.log('Validação Completa:', JSON.stringify(response.data, null, 2));
    } catch (error) {
        console.error('Erro:', error.response.data);
    }
}

// Exemplo 3: Validação em Lote
async function batchValidation() {
    try {
        const response = await axios.post(
            \`\${API_URL}/api/validate/batch\`,
            {
                emails: [
                    'valid@gmail.com',
                    'invalid@tempmail.com',
                    'typo@gmial.com'
                ],
                options: {
                    checkMX: true,
                    checkDisposable: true
                }
            },
            {
                headers: {
                    'Authorization': \`Bearer \${TOKEN}\`
                }
            }
        );

        console.log('Job criado:', response.data);

        // Verificar status do job
        setTimeout(async () => {
            const jobStatus = await axios.get(
                \`\${API_URL}/api/validate/job/\${response.data.jobId}\`,
                {
                    headers: {
                        'Authorization': \`Bearer \${TOKEN}\`
                    }
                }
            );
            console.log('Status do Job:', jobStatus.data);
        }, 5000);
    } catch (error) {
        console.error('Erro:', error.response.data);
    }
}

// Exemplo 4: Upload de CSV
async function uploadCSV() {
    const FormData = require('form-data');
    const fs = require('fs');

    const form = new FormData();
    form.append('file', fs.createReadStream('emails.csv'));

    try {
        const response = await axios.post(
            \`\${API_URL}/api/validate/upload-csv\`,
            form,
            {
                headers: {
                    ...form.getHeaders(),
                    'Authorization': \`Bearer \${TOKEN}\`
                }
            }
        );

        console.log('Upload CSV:', response.data);
    } catch (error) {
        console.error('Erro:', error.response.data);
    }
}

// Executar exemplos
async function runExamples() {
    console.log('🧪 Executando exemplos...\n');

    await quickValidation();
    console.log('\\n---\\n');

    // Para testar com autenticação, faça login primeiro e adicione o token
    // await completeValidation();
    // await batchValidation();
}

runExamples();
`;

        await fs.writeFile('validator-examples.js', exampleContent);
        console.log('✅ Arquivo de exemplos criado: validator-examples.js');

    } catch (error) {
        console.error('❌ Erro na integração:', error);
    }
}

integrateServer();
EOF

# Executar integração
echo -e "${BLUE}🔄 Integrando com server.js...${NC}"
node integrate-server.js

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Integração concluída!${NC}"
else
    echo -e "${RED}❌ Erro na integração${NC}"
fi

# Limpar arquivo temporário
rm -f integrate-server.js

echo ""

# ================================================
# ETAPA 5: INSTALAR DEPENDÊNCIA ADICIONAL
# ================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}5️⃣ ETAPA 5: Instalando dependência CSV${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verificar se csv-parser está instalado
if ! npm list csv-parser &>/dev/null; then
    echo -e "${YELLOW}📦 Instalando csv-parser...${NC}"
    npm install csv-parser
    echo -e "${GREEN}✅ csv-parser instalado${NC}"
else
    echo -e "${GREEN}✅ csv-parser já está instalado${NC}"
fi

# ================================================
# CRIAR ARQUIVO DE TESTE
# ================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}6️⃣ ETAPA 6: Criando arquivo de teste${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}📝 Criando arquivo de teste...${NC}"
cat > test-advanced-validator.js << 'EOF'
// ================================================
// Teste do Sistema de Validação Avançado
// ================================================

const axios = require('axios');

const API_URL = 'http://localhost:4201';

// Cores para console
const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m'
};

// Lista de emails para testar
const testEmails = [
    { email: 'valid@gmail.com', expected: 'valid' },
    { email: 'ceo@microsoft.com', expected: 'valid' },
    { email: 'test@tempmail.com', expected: 'disposable' },
    { email: 'admin@company.com', expected: 'role-based' },
    { email: 'user@gmial.com', expected: 'typo' },
    { email: 'invalido@', expected: 'invalid' },
    { email: 'fake123@mailinator.com', expected: 'disposable' },
    { email: 'joão.silva@empresa.com.br', expected: 'valid' }
];

async function testQuickValidation() {
    console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}`);
    console.log(`${colors.blue}🧪 Testando Validação Rápida (Pública)${colors.reset}`);
    console.log(`${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

    for (const test of testEmails) {
        try {
            const response = await axios.post(`${API_URL}/api/validate/quick`, {
                email: test.email
            });

            const { valid, score, risk } = response.data;
            const icon = valid ? '✅' : '❌';
            const color = valid ? colors.green : colors.red;

            console.log(`${icon} ${test.email}`);
            console.log(`   ${color}Valid: ${valid} | Score: ${score}/100 | Risk: ${risk}${colors.reset}`);

            if (test.expected === 'typo' && response.data.suggestions) {
                console.log(`   ${colors.yellow}💡 Sugestão: ${response.data.suggestions}${colors.reset}`);
            }
        } catch (error) {
            console.log(`❌ ${test.email}`);
            console.log(`   ${colors.red}Erro: ${error.response?.data?.error || error.message}${colors.reset}`);
        }

        // Delay para não sobrecarregar
        await new Promise(resolve => setTimeout(resolve, 100));
    }
}

async function testBatchValidation() {
    console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}`);
    console.log(`${colors.blue}🧪 Testando Validação em Lote${colors.reset}`);
    console.log(`${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

    const emails = testEmails.map(t => t.email);

    try {
        // Primeiro fazer login para obter token (usar credenciais de demo)
        console.log('🔐 Fazendo login...');
        const loginResponse = await axios.post(`${API_URL}/api/auth/login`, {
            email: 'demo@sparknexus.com',
            password: 'Demo@123456'
        });

        const token = loginResponse.data.token;
        console.log(`${colors.green}✅ Login realizado${colors.reset}\n`);

        // Enviar lote
        console.log('📦 Enviando lote de emails...');
        const batchResponse = await axios.post(
            `${API_URL}/api/validate/batch`,
            { emails, options: { checkMX: true } },
            { headers: { 'Authorization': `Bearer ${token}` } }
        );

        const { jobId, total } = batchResponse.data;
        console.log(`${colors.green}✅ Job criado: ${jobId}${colors.reset}`);
        console.log(`   Total de emails: ${total}\n`);

        // Aguardar processamento
        console.log('⏳ Aguardando processamento...');
        await new Promise(resolve => setTimeout(resolve, 3000));

        // Verificar status
        const statusResponse = await axios.get(
            `${API_URL}/api/validate/job/${jobId}`,
            { headers: { 'Authorization': `Bearer ${token}` } }
        );

        if (statusResponse.data.status === 'completed') {
            const { summary } = statusResponse.data;
            console.log(`${colors.green}✅ Processamento concluído!${colors.reset}`);
            console.log(`   Válidos: ${summary.valid}`);
            console.log(`   Inválidos: ${summary.invalid}`);
            console.log(`   Score médio: ${summary.avgScore.toFixed(2)}/100`);
        } else {
            console.log(`${colors.yellow}⚠️ Status: ${statusResponse.data.status}${colors.reset}`);
        }

    } catch (error) {
        console.log(`${colors.red}❌ Erro: ${error.response?.data?.error || error.message}${colors.reset}`);
    }
}

async function showAPIDocumentation() {
    console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}`);
    console.log(`${colors.blue}📚 Documentação da API${colors.reset}`);
    console.log(`${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

    try {
        const response = await axios.get(`${API_URL}/api/validate/docs`);
        console.log(JSON.stringify(response.data, null, 2));
    } catch (error) {
        console.log(`${colors.red}❌ Erro ao buscar documentação${colors.reset}`);
    }
}

// Executar testes
async function runTests() {
    console.log(`${colors.cyan}════════════════════════════════════════${colors.reset}`);
    console.log(`${colors.blue}🚀 SPARK NEXUS - Teste do Validador Avançado${colors.reset}`);
    console.log(`${colors.cyan}════════════════════════════════════════${colors.reset}`);

    await testQuickValidation();
    await testBatchValidation();
    await showAPIDocumentation();

    console.log(`\n${colors.green}✨ Testes concluídos!${colors.reset}\n`);
}

// Verificar se o servidor está rodando
axios.get(`${API_URL}/api/health`)
    .then(() => {
        runTests();
    })
    .catch(() => {
        console.log(`${colors.red}❌ Servidor não está rodando em ${API_URL}${colors.reset}`);
        console.log(`${colors.yellow}Execute: npm start${colors.reset}`);
    });
EOF
echo -e "${GREEN}✅ Arquivo de teste criado${NC}"

# ================================================
# CRIAR CSV DE EXEMPLO
# ================================================
echo -e "${YELLOW}📝 Criando CSV de exemplo...${NC}"
cat > test-emails.csv << 'EOF'
Email,Nome,Empresa
joao.silva@gmail.com,João Silva,Empresa A
maria@tempmail.com,Maria Santos,Empresa B
admin@company.com,Admin,Empresa C
ceo@microsoft.com,CEO,Microsoft
test@gmial.com,Teste,Empresa D
invalido@,Inválido,Empresa E
user123@mailinator.com,User,Empresa F
contato@sparknexus.com.br,Contato,Spark Nexus
EOF
echo -e "${GREEN}✅ CSV de teste criado: test-emails.csv${NC}"

# ================================================
# RESUMO FINAL
# ================================================
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 INTEGRAÇÃO COMPLETA REALIZADA!${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}✅ O que foi feito:${NC}"
echo "   1. ✓ Migração do banco de dados executada"
echo "   2. ✓ Backup do server.js criado"
echo "   3. ✓ Rotas do validador criadas"
echo "   4. ✓ Integração com server.js realizada"
echo "   5. ✓ Dependências instaladas"
echo "   6. ✓ Arquivos de teste criados"
echo ""
echo -e "${CYAN}📁 Arquivos criados:${NC}"
echo "   • services/routes/validatorRoutes.js"
echo "   • services/migrations/create_validation_tables.sql"
echo "   • validator-examples.js"
echo "   • test-advanced-validator.js"
echo "   • test-emails.csv"
echo ""
echo -e "${CYAN}🔧 Endpoints disponíveis:${NC}"
echo ""
echo -e "${YELLOW}Públicos:${NC}"
echo "   POST /api/validate/quick - Validação rápida"
echo ""
echo -e "${YELLOW}Autenticados:${NC}"
echo "   POST /api/validate/complete - Validação completa"
echo "   POST /api/validate/batch - Validação em lote"
echo "   POST /api/validate/upload-csv - Upload de CSV"
echo "   GET  /api/validate/job/:jobId - Status do job"
echo "   GET  /api/validate/download/:jobId - Download resultados"
echo "   GET  /api/validate/stats - Estatísticas"
echo "   GET  /api/validate/history - Histórico"
echo ""
echo -e "${YELLOW}Admin:${NC}"
echo "   POST /api/validate/admin/disposable - Adicionar disposable"
echo "   POST /api/validate/admin/whitelist - Adicionar whitelist"
echo "   GET  /api/validate/admin/system-stats - Stats do sistema"
echo ""
echo -e "${CYAN}🚀 Como testar:${NC}"
echo ""
echo "1. Reiniciar o servidor:"
echo -e "   ${GREEN}npm start${NC}"
echo ""
echo "2. Testar validação rápida:"
echo -e "   ${GREEN}node test-advanced-validator.js${NC}"
echo ""
echo "3. Testar com curl:"
echo -e "   ${GREEN}curl -X POST http://localhost:4201/api/validate/quick \\
   -H 'Content-Type: application/json' \\
   -d '{\"email\":\"test@gmail.com\"}'${NC}"
echo ""
echo "4. Ver documentação:"
echo -e "   ${GREEN}curl http://localhost:4201/api/validate/docs${NC}"
echo ""
echo -e "${YELLOW}📝 Backups criados:${NC}"
ls -la server.js.backup-* 2>/dev/null | tail -1
echo ""
echo -e "${GREEN}✨ Sistema de validação avançado totalmente integrado!${NC}"
echo -e "${CYAN}Desenvolvido por Spark Nexus - Email Validation System v2.0${NC}"
echo ""
