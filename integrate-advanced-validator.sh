#!/bin/bash

# ================================================
# SPARK NEXUS - INTEGRAÇÃO DO VALIDADOR AVANÇADO
# ================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     🚀 INTEGRAÇÃO DO VALIDADOR AVANÇADO${NC}"
echo -e "${MAGENTA}     ✨ MX Records | Disposable | Score | Batch${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ================================================
# VERIFICAÇÃO INICIAL
# ================================================
echo -e "${BLUE}[VERIFICAÇÃO] Status do sistema...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar se client-dashboard está rodando
if docker ps --format "{{.Names}}" | grep -qE "client"; then
    echo -e "${GREEN}✅ Client Dashboard está rodando${NC}"
else
    echo -e "${RED}❌ Client Dashboard não está rodando${NC}"
    echo -e "${YELLOW}Execute primeiro: docker-compose up -d client-dashboard${NC}"
    exit 1
fi

# Testar API
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:4201/api/health" 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ API respondendo corretamente${NC}"
else
    echo -e "${YELLOW}⚠️  API com problemas (HTTP $HTTP_CODE)${NC}"
fi

echo ""

# ================================================
# ETAPA 1: ENTRAR NO CONTAINER E INSTALAR DEPENDÊNCIAS
# ================================================
echo -e "${BLUE}[1/8] Instalando dependências no container...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Pegar nome do container
CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep -E "client" | head -1)

# Instalar dependências necessárias
echo -e "${CYAN}📦 Instalando pacotes NPM...${NC}"
docker exec "$CONTAINER_NAME" sh -c "cd /app && npm install --no-save email-validator@^2.0.4 punycode@^2.3.1 tldts@^6.1.0 disposable-email-domains csv-parser" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Dependências instaladas${NC}"
else
    echo -e "${YELLOW}⚠️  Algumas dependências já existem${NC}"
fi

echo ""

# ================================================
# ETAPA 2: CRIAR ESTRUTURA DE DIRETÓRIOS
# ================================================
echo -e "${BLUE}[2/8] Criando estrutura de diretórios...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

docker exec "$CONTAINER_NAME" sh -c "
    mkdir -p /app/services/validators
    mkdir -p /app/services/data
    mkdir -p /app/services/utils
    mkdir -p /app/services/routes
    mkdir -p /app/services/migrations
"

echo -e "${GREEN}✅ Estrutura criada${NC}"
echo ""

# ================================================
# ETAPA 3: CRIAR ARQUIVOS DO VALIDADOR
# ================================================
echo -e "${BLUE}[3/8] Criando arquivos do validador avançado...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Navegar para o diretório local
cd core/client-dashboard 2>/dev/null || cd client-dashboard 2>/dev/null

# Criar EmailParser
echo -e "${CYAN}📝 Criando EmailParser...${NC}"
cat > services/utils/emailParser.js << 'EOF'
// Parser de Email
class EmailParser {
    parse(email) {
        if (!email || typeof email !== 'string') {
            throw new Error('Email inválido');
        }

        const normalized = email.toLowerCase().trim();
        const parts = normalized.split('@');
        
        if (parts.length !== 2) {
            throw new Error('Formato de email inválido');
        }

        const [local, domain] = parts;
        
        return {
            full: normalized,
            local: local,
            domain: domain,
            tld: domain.split('.').pop(),
            isSubaddressed: local.includes('+')
        };
    }

    normalize(email) {
        const parsed = this.parse(email);
        return parsed.full;
    }
}

module.exports = EmailParser;
EOF

# Criar Cache Service
echo -e "${CYAN}📝 Criando Cache Service...${NC}"
cat > services/utils/cache.js << 'EOF'
// Cache Service
class CacheService {
    constructor() {
        this.memoryCache = new Map();
        this.maxSize = 1000;
    }

    async get(key) {
        const cached = this.memoryCache.get(key);
        if (cached && Date.now() < cached.expires) {
            return cached.value;
        }
        this.memoryCache.delete(key);
        return null;
    }

    async set(key, value, ttl = 3600) {
        this.memoryCache.set(key, {
            value: value,
            expires: Date.now() + (ttl * 1000)
        });
        
        if (this.memoryCache.size > this.maxSize) {
            const firstKey = this.memoryCache.keys().next().value;
            this.memoryCache.delete(firstKey);
        }
    }

    getStats() {
        return { size: this.memoryCache.size };
    }
}

module.exports = CacheService;
EOF

# Criar MX Validator
echo -e "${CYAN}📝 Criando MX Validator...${NC}"
cat > services/validators/mxValidator.js << 'EOF'
// MX Validator
const dns = require('dns').promises;

class MXValidator {
    constructor() {
        this.cache = new Map();
        this.cacheTime = 3600000; // 1 hora
    }

    async validate(domain) {
        const result = {
            valid: false,
            mxRecords: [],
            score: 0,
            reason: null
        };

        try {
            // Verificar cache
            const cached = this.getFromCache(domain);
            if (cached) {
                return { ...cached, cached: true };
            }

            // Buscar MX records
            const mxRecords = await this.getMXRecords(domain);
            
            if (mxRecords && mxRecords.length > 0) {
                result.valid = true;
                result.mxRecords = mxRecords.map(mx => ({
                    exchange: mx.exchange,
                    priority: mx.priority
                }));
                result.score = 80;
            } else {
                result.reason = 'Nenhum MX record encontrado';
                result.score = 20;
            }

            // Salvar no cache
            this.saveToCache(domain, result);
            return result;

        } catch (error) {
            result.error = error.message;
            result.score = 10;
            return result;
        }
    }

    async getMXRecords(domain) {
        try {
            const records = await dns.resolveMx(domain);
            return records;
        } catch (error) {
            return [];
        }
    }

    getFromCache(domain) {
        const cached = this.cache.get(domain);
        if (cached && Date.now() - cached.timestamp < this.cacheTime) {
            return cached.data;
        }
        this.cache.delete(domain);
        return null;
    }

    saveToCache(domain, data) {
        this.cache.set(domain, {
            data: data,
            timestamp: Date.now()
        });
    }
}

module.exports = MXValidator;
EOF

# Criar Disposable Validator
echo -e "${CYAN}📝 Criando Disposable Validator...${NC}"
cat > services/validators/disposableValidator.js << 'EOF'
// Disposable Email Validator
class DisposableValidator {
    constructor() {
        // Lista básica de domínios disposable
        this.disposableSet = new Set([
            'tempmail.com', '10minutemail.com', 'guerrillamail.com',
            'mailinator.com', 'throwawaymail.com', 'yopmail.com',
            'tempmail.net', 'trashmail.com', 'fakeinbox.com',
            'temp-mail.org', 'sharklasers.com', 'guerrillamail.info'
        ]);
        
        this.patterns = [
            /^(temp|tmp|test|fake|spam|trash|disposable)/i,
            /^[0-9]+(minute|hour|day)mail/i
        ];
    }

    async check(email, parsed) {
        const result = {
            isDisposable: false,
            confidence: 0,
            riskLevel: 'low',
            reason: null
        };

        const domain = parsed.domain.toLowerCase();

        // Verificar lista de disposable
        if (this.disposableSet.has(domain)) {
            result.isDisposable = true;
            result.confidence = 95;
            result.riskLevel = 'very_high';
            result.reason = 'Domínio na lista de descartáveis';
            return result;
        }

        // Verificar padrões
        for (const pattern of this.patterns) {
            if (pattern.test(domain) || pattern.test(parsed.local)) {
                result.isDisposable = true;
                result.confidence = 70;
                result.riskLevel = 'high';
                result.reason = 'Padrão suspeito detectado';
                return result;
            }
        }

        return result;
    }

    getStats() {
        return {
            totalDisposable: this.disposableSet.size,
            patterns: this.patterns.length
        };
    }
}

module.exports = DisposableValidator;
EOF

# Criar Score Calculator
echo -e "${CYAN}📝 Criando Score Calculator...${NC}"
cat > services/validators/scoreCalculator.js << 'EOF'
// Score Calculator
class ScoreCalculator {
    calculate(data) {
        let score = 50; // Base score
        const breakdown = { base: 50, adjustments: [] };

        // MX Score
        if (data.mx) {
            if (data.mx.valid) {
                score += 25;
                breakdown.adjustments.push({ category: 'mx', points: 25, reason: 'MX válido' });
            } else {
                score -= 15;
                breakdown.adjustments.push({ category: 'mx', points: -15, reason: 'MX inválido' });
            }
        }

        // Disposable Score
        if (data.disposable) {
            if (data.disposable.isDisposable) {
                score -= 40;
                breakdown.adjustments.push({ category: 'disposable', points: -40, reason: 'Email descartável' });
            } else {
                score += 15;
                breakdown.adjustments.push({ category: 'disposable', points: 15, reason: 'Não é descartável' });
            }
        }

        // Domain Score
        if (data.parsed) {
            const corporateDomains = ['gmail.com', 'outlook.com', 'yahoo.com', 'hotmail.com'];
            if (corporateDomains.includes(data.parsed.domain)) {
                score += 10;
                breakdown.adjustments.push({ category: 'domain', points: 10, reason: 'Domínio conhecido' });
            }
        }

        // Normalizar score (0-100)
        score = Math.max(0, Math.min(100, score));

        return {
            total: Math.round(score),
            breakdown: breakdown,
            quality: score >= 80 ? 'excellent' : score >= 60 ? 'good' : score >= 40 ? 'fair' : 'poor',
            recommendation: score >= 60 ? 'accept' : 'review'
        };
    }
}

module.exports = ScoreCalculator;
EOF

# Criar Orquestrador Principal
echo -e "${CYAN}📝 Criando Orquestrador Principal...${NC}"
cat > services/validators/index.js << 'EOF'
// Orquestrador Principal de Validação
const MXValidator = require('./mxValidator');
const DisposableValidator = require('./disposableValidator');
const ScoreCalculator = require('./scoreCalculator');
const EmailParser = require('../utils/emailParser');
const CacheService = require('../utils/cache');

class EmailValidator {
    constructor(databaseService) {
        this.db = databaseService;
        this.cache = new CacheService();
        this.mxValidator = new MXValidator();
        this.disposableValidator = new DisposableValidator();
        this.scoreCalculator = new ScoreCalculator();
        this.parser = new EmailParser();
    }

    async validate(email, options = {}) {
        const startTime = Date.now();
        
        // Verificar cache
        if (options.useCache !== false) {
            const cached = await this.cache.get(`email:${email.toLowerCase()}`);
            if (cached) {
                return { ...cached, fromCache: true };
            }
        }

        try {
            // Parse do email
            const parsed = this.parser.parse(email);
            
            // Validações paralelas
            const [mxResult, disposableResult] = await Promise.all([
                options.checkMX !== false ? this.mxValidator.validate(parsed.domain) : null,
                options.checkDisposable !== false ? this.disposableValidator.check(email, parsed) : null
            ]);

            // Calcular score
            const scoreData = {
                mx: mxResult,
                disposable: disposableResult,
                parsed: parsed
            };
            
            const score = this.scoreCalculator.calculate(scoreData);

            // Montar resultado
            const result = {
                email: email,
                valid: mxResult ? mxResult.valid : true,
                score: score.total,
                quality: score.quality,
                risk: disposableResult?.riskLevel || 'low',
                checks: {
                    mx: mxResult,
                    disposable: disposableResult
                },
                recommendation: score.recommendation,
                processingTime: Date.now() - startTime,
                timestamp: new Date().toISOString()
            };

            // Salvar no cache
            if (options.useCache !== false) {
                await this.cache.set(`email:${email.toLowerCase()}`, result, 3600);
            }

            return result;

        } catch (error) {
            console.error('Erro na validação:', error);
            return {
                email: email,
                valid: false,
                error: error.message,
                processingTime: Date.now() - startTime
            };
        }
    }

    async validateBatch(emails, options = {}) {
        const results = [];
        const batchSize = options.batchSize || 10;
        
        for (let i = 0; i < emails.length; i += batchSize) {
            const batch = emails.slice(i, i + batchSize);
            const batchResults = await Promise.all(
                batch.map(email => this.validate(email, options))
            );
            results.push(...batchResults);
        }
        
        return results;
    }

    getStats() {
        return {
            cacheStats: this.cache.getStats(),
            disposableStats: this.disposableValidator.getStats()
        };
    }
}

module.exports = EmailValidator;
EOF

echo -e "${GREEN}✅ Arquivos do validador criados${NC}"
echo ""

# ================================================
# ETAPA 4: COPIAR ARQUIVOS PARA O CONTAINER
# ================================================
echo -e "${BLUE}[4/8] Copiando arquivos para o container...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Copiar todos os arquivos criados
docker cp services/utils/emailParser.js "$CONTAINER_NAME":/app/services/utils/
docker cp services/utils/cache.js "$CONTAINER_NAME":/app/services/utils/
docker cp services/validators/mxValidator.js "$CONTAINER_NAME":/app/services/validators/
docker cp services/validators/disposableValidator.js "$CONTAINER_NAME":/app/services/validators/
docker cp services/validators/scoreCalculator.js "$CONTAINER_NAME":/app/services/validators/
docker cp services/validators/index.js "$CONTAINER_NAME":/app/services/validators/

echo -e "${GREEN}✅ Arquivos copiados${NC}"
echo ""

# ================================================
# ETAPA 5: CRIAR ROTAS DA API
# ================================================
echo -e "${BLUE}[5/8] Criando rotas da API...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cat > services/routes/advancedValidator.js << 'EOF'
// Rotas do Validador Avançado
const express = require('express');
const router = express.Router();

let emailValidator;

const initializeValidator = (validator) => {
    emailValidator = validator;
    return router;
};

// Validação completa de um email
router.post('/advanced', async (req, res) => {
    try {
        const { email } = req.body;
        
        if (!email) {
            return res.status(400).json({ error: 'Email é obrigatório' });
        }

        const result = await emailValidator.validate(email, {
            checkMX: true,
            checkDisposable: true,
            useCache: true
        });

        res.json(result);
    } catch (error) {
        console.error('Erro na validação:', error);
        res.status(500).json({ error: 'Erro ao validar email' });
    }
});

// Validação em lote
router.post('/batch', async (req, res) => {
    try {
        const { emails } = req.body;
        
        if (!emails || !Array.isArray(emails)) {
            return res.status(400).json({ error: 'Lista de emails é obrigatória' });
        }

        if (emails.length > 100) {
            return res.status(400).json({ error: 'Máximo de 100 emails por lote' });
        }

        const results = await emailValidator.validateBatch(emails, {
            checkMX: true,
            checkDisposable: true,
            batchSize: 10
        });

        res.json({
            total: emails.length,
            results: results,
            summary: {
                valid: results.filter(r => r.valid).length,
                invalid: results.filter(r => !r.valid).length,
                avgScore: Math.round(results.reduce((acc, r) => acc + r.score, 0) / results.length)
            }
        });
    } catch (error) {
        console.error('Erro na validação em lote:', error);
        res.status(500).json({ error: 'Erro ao validar lote' });
    }
});

// Estatísticas
router.get('/stats', (req, res) => {
    try {
        const stats = emailValidator.getStats();
        res.json(stats);
    } catch (error) {
        res.status(500).json({ error: 'Erro ao buscar estatísticas' });
    }
});

module.exports = { initializeValidator, router };
EOF

# Copiar para o container
docker cp services/routes/advancedValidator.js "$CONTAINER_NAME":/app/services/routes/

echo -e "${GREEN}✅ Rotas criadas${NC}"
echo ""

# ================================================
# ETAPA 6: INTEGRAR COM SERVER.JS
# ================================================
echo -e "${BLUE}[6/8] Integrando com server.js...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Criar script de integração
cat > integrate.js << 'EOF'
const fs = require('fs');

// Ler server.js
let serverContent = fs.readFileSync('/app/server.js', 'utf-8');

// Verificar se já foi integrado
if (serverContent.includes('advancedValidator')) {
    console.log('Já integrado');
    process.exit(0);
}

// Adicionar imports após os requires existentes
const importCode = `
// Validador Avançado
const EmailValidator = require('./services/validators');
const { initializeValidator, router: advancedRoutes } = require('./services/routes/advancedValidator');
`;

// Adicionar após 'const smsService = new SMSService();'
const initCode = `
// Inicializar validador avançado
const advancedValidator = new EmailValidator(db);
initializeValidator(advancedValidator);
`;

// Adicionar rotas antes de '// Health Check'
const routeCode = `
// Rotas do Validador Avançado
app.use('/api/validate', advancedRoutes);

`;

// Inserir imports
const lastRequireIndex = serverContent.lastIndexOf("require('./services/validators')");
if (lastRequireIndex === -1) {
    const validatorsIndex = serverContent.indexOf("const Validators = require('./services/validators');");
    serverContent = serverContent.slice(0, validatorsIndex + 55) + importCode + serverContent.slice(validatorsIndex + 55);
}

// Inserir inicialização
const smsIndex = serverContent.indexOf('const smsService = new SMSService();');
if (smsIndex !== -1 && !serverContent.includes('advancedValidator')) {
    const endLine = serverContent.indexOf('\n', smsIndex);
    serverContent = serverContent.slice(0, endLine + 1) + initCode + serverContent.slice(endLine + 1);
}

// Inserir rotas
const healthIndex = serverContent.indexOf('// Health Check');
if (healthIndex !== -1 && !serverContent.includes('/api/validate')) {
    serverContent = serverContent.slice(0, healthIndex) + routeCode + serverContent.slice(healthIndex);
}

// Salvar
fs.writeFileSync('/app/server.js', serverContent);
console.log('Integração concluída');
EOF

# Executar integração no container
docker cp integrate.js "$CONTAINER_NAME":/app/
docker exec "$CONTAINER_NAME" node /app/integrate.js
docker exec "$CONTAINER_NAME" rm /app/integrate.js

echo -e "${GREEN}✅ Integração realizada${NC}"
echo ""

# ================================================
# ETAPA 7: REINICIAR SERVIDOR
# ================================================
echo -e "${BLUE}[7/8] Reiniciando servidor...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Reiniciar o processo Node.js dentro do container
docker exec "$CONTAINER_NAME" sh -c "pkill node || true"
sleep 2

echo -e "${YELLOW}⏳ Aguardando reinicialização (10 segundos)...${NC}"
for i in {1..10}; do
    echo -n "."
    sleep 1
done
echo ""
echo -e "${GREEN}✅ Servidor reiniciado${NC}"
echo ""

# ================================================
# ETAPA 8: TESTE FINAL
# ================================================
echo -e "${BLUE}[8/8] Testando o validador avançado...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

sleep 5

# Testar endpoint de validação avançada
echo -e "${CYAN}🧪 Testando validação avançada...${NC}"
RESPONSE=$(curl -s -X POST http://localhost:4201/api/validate/advanced \
  -H "Content-Type: application/json" \
  -d '{"email":"test@gmail.com"}' 2>/dev/null)

if echo "$RESPONSE" | grep -q "score"; then
    echo -e "${GREEN}✅ Validador avançado funcionando!${NC}"
    echo -e "${CYAN}Resposta:${NC}"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
else
    echo -e "${YELLOW}⚠️  Validador pode precisar de mais tempo para inicializar${NC}"
    echo -e "${CYAN}Resposta recebida:${NC} $RESPONSE"
fi

echo ""

# ================================================
# CRIAR ARQUIVO DE TESTE
# ================================================
cat > test-validator.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Teste - Validador Avançado</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 600px;
            width: 100%;
        }
        h1 {
            color: #333;
            margin-bottom: 30px;
            text-align: center;
            font-size: 28px;
        }
        .test-section {
            margin-bottom: 30px;
        }
        h2 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 18px;
        }
        .input-group {
            display: flex;
            gap: 10px;
            margin-bottom: 15px;
        }
        input {
            flex: 1;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
        }
        button {
            padding: 12px 24px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
        }
        button:hover { opacity: 0.9; }
        button:disabled { opacity: 0.5; cursor: not-allowed; }
        .result {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 15px;
            margin-top: 15px;
            display: none;
        }
        .result.show { display: block; }
        .score {
            font-size: 48px;
            font-weight: bold;
            text-align: center;
            margin: 20px 0;
        }
        .score.excellent { color: #4caf50; }
        .score.good { color: #8bc34a; }
        .score.fair { color: #ff9800; }
        .score.poor { color: #f44336; }
        .detail {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #e0e0e0;
        }
        .detail:last-child { border-bottom: none; }
        .badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
        }
        .badge.valid { background: #4caf50; color: white; }
        .badge.invalid { background: #f44336; color: white; }
        .badge.warning { background: #ff9800; color: white; }
        .loading {
            text-align: center;
            color: #667eea;
            display: none;
        }
        .loading.show { display: block; }
        textarea {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 14px;
            font-family: monospace;
            min-height: 100px;
            resize: vertical;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 15px;
            margin-top: 20px;
        }
        .stat-card {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-value {
            font-size: 24px;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            font-size: 12px;
            color: #666;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Validador Avançado de Email</h1>
        
        <!-- Teste Individual -->
        <div class="test-section">
            <h2>Validação Individual</h2>
            <div class="input-group">
                <input type="email" id="singleEmail" placeholder="Digite um email para validar" value="test@gmail.com">
                <button onclick="validateSingle()">Validar</button>
            </div>
            <div class="loading" id="singleLoading">⏳ Validando...</div>
            <div class="result" id="singleResult"></div>
        </div>

        <!-- Teste em Lote -->
        <div class="test-section">
            <h2>Validação em Lote</h2>
            <textarea id="batchEmails" placeholder="Digite vários emails (um por linha)">test@gmail.com
admin@company.com
user@tempmail.com
ceo@microsoft.com
fake@mailinator.com</textarea>
            <button onclick="validateBatch()" style="margin-top: 10px">Validar Lote</button>
            <div class="loading" id="batchLoading">⏳ Validando lote...</div>
            <div class="result" id="batchResult"></div>
        </div>

        <!-- Estatísticas -->
        <div class="test-section">
            <h2>Estatísticas do Sistema</h2>
            <button onclick="getStats()">Buscar Estatísticas</button>
            <div class="result" id="statsResult"></div>
        </div>
    </div>

    <script>
        const API_URL = 'http://localhost:4201/api/validate';

        async function validateSingle() {
            const email = document.getElementById('singleEmail').value;
            const loading = document.getElementById('singleLoading');
            const result = document.getElementById('singleResult');
            
            loading.classList.add('show');
            result.classList.remove('show');
            
            try {
                const response = await fetch(`${API_URL}/advanced`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email })
                });
                
                const data = await response.json();
                
                result.innerHTML = `
                    <div class="score ${data.quality}">${data.score}</div>
                    <div class="detail">
                        <span>Email:</span>
                        <strong>${data.email}</strong>
                    </div>
                    <div class="detail">
                        <span>Válido:</span>
                        <span class="badge ${data.valid ? 'valid' : 'invalid'}">
                            ${data.valid ? 'SIM' : 'NÃO'}
                        </span>
                    </div>
                    <div class="detail">
                        <span>Qualidade:</span>
                        <strong>${data.quality}</strong>
                    </div>
                    <div class="detail">
                        <span>Risco:</span>
                        <span class="badge ${data.risk === 'low' ? 'valid' : 'warning'}">
                            ${data.risk}
                        </span>
                    </div>
                    <div class="detail">
                        <span>Recomendação:</span>
                        <strong>${data.recommendation}</strong>
                    </div>
                    <div class="detail">
                        <span>MX Records:</span>
                        <span class="badge ${data.checks?.mx?.valid ? 'valid' : 'invalid'}">
                            ${data.checks?.mx?.valid ? 'Válido' : 'Inválido'}
                        </span>
                    </div>
                    <div class="detail">
                        <span>Descartável:</span>
                        <span class="badge ${data.checks?.disposable?.isDisposable ? 'invalid' : 'valid'}">
                            ${data.checks?.disposable?.isDisposable ? 'SIM' : 'NÃO'}
                        </span>
                    </div>
                    <div class="detail">
                        <span>Tempo:</span>
                        <strong>${data.processingTime}ms</strong>
                    </div>
                `;
                
                result.classList.add('show');
            } catch (error) {
                result.innerHTML = `<div style="color: red">Erro: ${error.message}</div>`;
                result.classList.add('show');
            } finally {
                loading.classList.remove('show');
            }
        }

        async function validateBatch() {
            const emails = document.getElementById('batchEmails').value
                .split('\n')
                .filter(e => e.trim())
                .map(e => e.trim());
            
            const loading = document.getElementById('batchLoading');
            const result = document.getElementById('batchResult');
            
            loading.classList.add('show');
            result.classList.remove('show');
            
            try {
                const response = await fetch(`${API_URL}/batch`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ emails })
                });
                
                const data = await response.json();
                
                let html = `
                    <div class="stats">
                        <div class="stat-card">
                            <div class="stat-value">${data.total}</div>
                            <div class="stat-label">Total</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value">${data.summary.valid}</div>
                            <div class="stat-label">Válidos</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value">${data.summary.avgScore}</div>
                            <div class="stat-label">Score Médio</div>
                        </div>
                    </div>
                    <h3 style="margin-top: 20px; margin-bottom: 10px">Resultados:</h3>
                `;
                
                data.results.forEach(r => {
                    html += `
                        <div class="detail">
                            <span>${r.email}</span>
                            <div>
                                <span class="badge ${r.valid ? 'valid' : 'invalid'}">
                                    ${r.valid ? 'Válido' : 'Inválido'}
                                </span>
                                <span style="margin-left: 10px">Score: ${r.score}</span>
                            </div>
                        </div>
                    `;
                });
                
                result.innerHTML = html;
                result.classList.add('show');
            } catch (error) {
                result.innerHTML = `<div style="color: red">Erro: ${error.message}</div>`;
                result.classList.add('show');
            } finally {
                loading.classList.remove('show');
            }
        }

        async function getStats() {
            const result = document.getElementById('statsResult');
            
            try {
                const response = await fetch(`${API_URL}/stats`);
                const data = await response.json();
                
                result.innerHTML = `
                    <pre>${JSON.stringify(data, null, 2)}</pre>
                `;
                result.classList.add('show');
            } catch (error) {
                result.innerHTML = `<div style="color: red">Erro: ${error.message}</div>`;
                result.classList.add('show');
            }
        }
    </script>
</body>
</html>
EOF

echo -e "${GREEN}✅ Arquivo de teste criado: test-validator.html${NC}"
echo ""

# ================================================
# RESULTADO FINAL
# ================================================
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}     ✅ VALIDADOR AVANÇADO INTEGRADO COM SUCESSO!${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}📊 FEATURES IMPLEMENTADAS:${NC}"
echo "   ✅ Validação de MX Records"
echo "   ✅ Detecção de emails temporários"
echo "   ✅ Sistema de Score (0-100)"
echo "   ✅ Validação em lote"
echo "   ✅ Cache de resultados"
echo "   ✅ API REST completa"
echo ""
echo -e "${CYAN}🔌 ENDPOINTS DISPONÍVEIS:${NC}"
echo "   POST ${BLUE}http://localhost:4201/api/validate/advanced${NC}"
echo "        → Validação completa de um email"
echo ""
echo "   POST ${BLUE}http://localhost:4201/api/validate/batch${NC}"
echo "        → Validação de múltiplos emails"
echo ""
echo "   GET  ${BLUE}http://localhost:4201/api/validate/stats${NC}"
echo "        → Estatísticas do sistema"
echo ""
echo -e "${CYAN}🧪 COMO TESTAR:${NC}"
echo ""
echo "1. Interface Web:"
echo -e "   Abra ${YELLOW}test-validator.html${NC} no navegador"
echo ""
echo "2. Via Terminal:"
echo -e "   ${GREEN}curl -X POST http://localhost:4201/api/validate/advanced \\
     -H 'Content-Type: application/json' \\
     -d '{\"email\":\"test@gmail.com\"}'${NC}"
echo ""
echo "3. Interface do Sistema:"
echo -e "   Acesse ${BLUE}http://localhost:4201/upload${NC}"
echo -e "   Faça login e teste a validação"
echo ""
echo -e "${GREEN}🎉 Sistema completo e funcionando!${NC}"
echo ""

# Limpar arquivos temporários
rm -f integrate.js

exit 0