#!/bin/bash

# ================================================
# Script para Criar Sistema de Validação Avançado
# Spark Nexus - Email Validator
# ================================================

echo "================================================"
echo "🚀 SPARK NEXUS - Criando Validadores Avançados"
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

echo -e "${CYAN}📁 Criando estrutura de validadores...${NC}"
echo ""

# ================================================
# 1. CRIAR ORQUESTRADOR PRINCIPAL
# ================================================
echo -e "${BLUE}1️⃣ Criando services/validators/index.js${NC}"
cat > services/validators/index.js << 'EOF'
// ================================================
// Orquestrador Principal de Validação
// services/validators/index.js
// ================================================

const SyntaxValidator = require('./syntaxValidator');
const MXValidator = require('./mxValidator');
const DisposableValidator = require('./disposableValidator');
const ScoreCalculator = require('./scoreCalculator');
const EmailParser = require('../utils/emailParser');
const CacheService = require('../utils/cache');

class EmailValidator {
    constructor(databaseService) {
        this.db = databaseService;
        this.cache = new CacheService(databaseService.redis);

        // Inicializar validadores
        this.syntaxValidator = new SyntaxValidator();
        this.mxValidator = new MXValidator();
        this.disposableValidator = new DisposableValidator();
        this.scoreCalculator = new ScoreCalculator();
        this.parser = new EmailParser();
    }

    /**
     * Validação completa de email
     * @param {string} email - Email para validar
     * @param {Object} options - Opções de validação
     * @returns {Object} Resultado completo da validação
     */
    async validate(email, options = {}) {
        const startTime = Date.now();

        // Configurações padrão
        const config = {
            checkMX: options.checkMX !== false,
            checkSMTP: options.checkSMTP === true,
            checkDisposable: options.checkDisposable !== false,
            useCache: options.useCache !== false,
            detailed: options.detailed === true
        };

        // Verificar cache primeiro
        if (config.useCache) {
            const cached = await this.cache.get(`email:${email.toLowerCase()}`);
            if (cached) {
                console.log(`📦 Cache hit for: ${email}`);
                return { ...cached, fromCache: true };
            }
        }

        try {
            // 1. Parse do email
            const parsed = this.parser.parse(email);

            // 2. Validação de sintaxe
            const syntaxResult = await this.syntaxValidator.validate(email, parsed);

            // Se sintaxe inválida, retornar imediatamente
            if (!syntaxResult.valid) {
                const result = {
                    email: email,
                    valid: false,
                    reason: syntaxResult.reason,
                    checks: {
                        syntax: syntaxResult
                    },
                    score: 0,
                    processingTime: Date.now() - startTime
                };

                await this.saveResult(email, result, config.useCache);
                return result;
            }

            // 3. Verificações paralelas
            const checks = await Promise.allSettled([
                config.checkMX ? this.mxValidator.validate(parsed.domain) : Promise.resolve(null),
                config.checkDisposable ? this.disposableValidator.check(email, parsed) : Promise.resolve(null)
            ]);

            const mxResult = checks[0].status === 'fulfilled' ? checks[0].value : null;
            const disposableResult = checks[1].status === 'fulfilled' ? checks[1].value : null;

            // 4. Calcular score
            const scoreData = {
                syntax: syntaxResult,
                mx: mxResult,
                disposable: disposableResult,
                parsed: parsed
            };

            const score = this.scoreCalculator.calculate(scoreData);

            // 5. Montar resultado final
            const result = {
                email: email,
                valid: syntaxResult.valid && (mxResult ? mxResult.valid : true),
                reachable: mxResult ? mxResult.valid : null,
                score: score.total,
                risk: this.getRiskLevel(score.total),

                checks: {
                    syntax: syntaxResult,
                    mx: mxResult,
                    disposable: disposableResult
                },

                details: config.detailed ? {
                    parsed: parsed,
                    scoreBreakdown: score.breakdown,
                    suggestions: this.getSuggestions(email, syntaxResult)
                } : undefined,

                processingTime: Date.now() - startTime,
                timestamp: new Date().toISOString()
            };

            // 6. Salvar resultado
            await this.saveResult(email, result, config.useCache);

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

    /**
     * Validação em lote
     * @param {Array} emails - Lista de emails
     * @param {Object} options - Opções de validação
     * @returns {Array} Resultados das validações
     */
    async validateBatch(emails, options = {}) {
        const batchSize = options.batchSize || 10;
        const results = [];

        // Processar em lotes para não sobrecarregar
        for (let i = 0; i < emails.length; i += batchSize) {
            const batch = emails.slice(i, i + batchSize);
            const batchResults = await Promise.all(
                batch.map(email => this.validate(email, options))
            );
            results.push(...batchResults);

            // Delay entre lotes
            if (i + batchSize < emails.length && options.delay) {
                await new Promise(resolve => setTimeout(resolve, options.delay));
            }
        }

        return results;
    }

    /**
     * Determinar nível de risco
     */
    getRiskLevel(score) {
        if (score >= 80) return 'low';
        if (score >= 60) return 'medium';
        if (score >= 40) return 'high';
        return 'very_high';
    }

    /**
     * Gerar sugestões de correção
     */
    getSuggestions(email, syntaxResult) {
        const suggestions = [];

        if (syntaxResult.typoSuggestion) {
            suggestions.push({
                type: 'typo',
                original: email,
                suggested: syntaxResult.typoSuggestion,
                confidence: syntaxResult.typoConfidence
            });
        }

        return suggestions;
    }

    /**
     * Salvar resultado no cache e banco
     */
    async saveResult(email, result, useCache) {
        // Salvar no cache
        if (useCache) {
            await this.cache.set(
                `email:${email.toLowerCase()}`,
                result,
                3600 // 1 hora de TTL
            );
        }

        // Salvar no banco (async, não bloquear resposta)
        this.saveToDatabase(email, result).catch(console.error);
    }

    /**
     * Salvar no banco de dados
     */
    async saveToDatabase(email, result) {
        try {
            const query = `
                INSERT INTO validation.email_validations
                (email, valid, score, risk, checks, processing_time, created_at)
                VALUES ($1, $2, $3, $4, $5, $6, NOW())
                ON CONFLICT (email) DO UPDATE SET
                    valid = $2,
                    score = $3,
                    risk = $4,
                    checks = $5,
                    processing_time = $6,
                    updated_at = NOW()
            `;

            await this.db.pool.query(query, [
                email.toLowerCase(),
                result.valid,
                result.score,
                result.risk,
                JSON.stringify(result.checks),
                result.processingTime
            ]);
        } catch (error) {
            console.error('Erro ao salvar no banco:', error);
        }
    }

    /**
     * Buscar validação anterior
     */
    async getValidationHistory(email) {
        const query = `
            SELECT * FROM validation.email_validations
            WHERE email = $1
            ORDER BY created_at DESC
            LIMIT 10
        `;

        const result = await this.db.pool.query(query, [email.toLowerCase()]);
        return result.rows;
    }

    /**
     * Estatísticas de validação
     */
    async getStats(userId) {
        const query = `
            SELECT
                COUNT(*) as total_validations,
                AVG(score) as avg_score,
                COUNT(CASE WHEN valid = true THEN 1 END) as valid_count,
                COUNT(CASE WHEN risk = 'low' THEN 1 END) as low_risk,
                COUNT(CASE WHEN risk = 'high' THEN 1 END) as high_risk
            FROM validation.email_validations
            WHERE user_id = $1
                AND created_at > NOW() - INTERVAL '30 days'
        `;

        const result = await this.db.pool.query(query, [userId]);
        return result.rows[0];
    }
}

module.exports = EmailValidator;
EOF
echo -e "${GREEN}✅ Orquestrador principal criado${NC}"

# ================================================
# 2. CRIAR VALIDADOR DE SINTAXE
# ================================================
echo -e "${BLUE}2️⃣ Criando services/validators/syntaxValidator.js${NC}"
cat > services/validators/syntaxValidator.js << 'EOF'
// ================================================
// Validador de Sintaxe Avançado
// services/validators/syntaxValidator.js
// ================================================

const validator = require('email-validator');
const punycode = require('punycode');
const commonTypos = require('../data/commonTypos.json');
const roleBasedPrefixes = require('../data/roleBasedPrefixes.json');

class SyntaxValidator {
    constructor() {
        // RFC 5322 compliant regex (simplificada)
        this.emailRegex = /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;

        // Padrões suspeitos
        this.suspiciousPatterns = [
            /^[0-9]+@/,                    // Começa só com números
            /^.{1,3}@/,                    // Muito curto
            /(.)\1{3,}@/,                  // Repetição de caracteres
            /^(test|temp|fake|spam)/i,     // Palavras suspeitas
            /\d{5,}@/,                     // Muitos números seguidos
            /^[a-z]{15,}@/                 // Strings aleatórias longas
        ];

        // TLDs inválidos ou suspeitos
        this.invalidTlds = ['localhost', 'local', 'internal', 'test', 'example'];
        this.suspiciousTlds = ['tk', 'ml', 'ga', 'cf'];
    }

    /**
     * Validação completa de sintaxe
     */
    async validate(email, parsed) {
        const result = {
            valid: false,
            score: 0,
            checks: {},
            warnings: [],
            reason: null
        };

        // 1. Validação básica com email-validator
        if (!validator.validate(email)) {
            result.reason = 'Formato de email inválido';
            return result;
        }
        result.checks.format = true;
        result.score += 20;

        // 2. Verificar comprimento
        const lengthCheck = this.checkLength(email, parsed);
        result.checks.length = lengthCheck.valid;
        if (!lengthCheck.valid) {
            result.reason = lengthCheck.reason;
            return result;
        }
        result.score += 10;

        // 3. Verificar caracteres especiais
        const charCheck = this.checkCharacters(email, parsed);
        result.checks.characters = charCheck.valid;
        if (!charCheck.valid) {
            result.reason = charCheck.reason;
            return result;
        }
        result.score += 10;

        // 4. Detectar typos comuns
        const typoCheck = this.detectTypos(email, parsed);
        if (typoCheck.found) {
            result.typoSuggestion = typoCheck.suggestion;
            result.typoConfidence = typoCheck.confidence;
            result.warnings.push(`Possível erro de digitação: ${typoCheck.suggestion}`);
            result.score -= 5;
        } else {
            result.score += 15;
        }
        result.checks.typo = !typoCheck.found;

        // 5. Verificar se é role-based
        const roleCheck = this.checkRoleBased(parsed.local);
        result.checks.roleBased = !roleCheck.isRoleBased;
        if (roleCheck.isRoleBased) {
            result.warnings.push('Email genérico/role-based detectado');
            result.roleType = roleCheck.type;
            result.score -= 10;
        } else {
            result.score += 15;
        }

        // 6. Verificar padrões suspeitos
        const suspiciousCheck = this.checkSuspiciousPatterns(email, parsed);
        result.checks.suspicious = !suspiciousCheck.found;
        if (suspiciousCheck.found) {
            result.warnings.push(`Padrão suspeito: ${suspiciousCheck.pattern}`);
            result.suspiciousPattern = suspiciousCheck.pattern;
            result.score -= 15;
        } else {
            result.score += 15;
        }

        // 7. Verificar TLD
        const tldCheck = this.checkTLD(parsed.tld);
        result.checks.tld = tldCheck.valid;
        if (!tldCheck.valid) {
            result.reason = tldCheck.reason;
            return result;
        }
        if (tldCheck.suspicious) {
            result.warnings.push('TLD suspeito detectado');
            result.score -= 5;
        } else {
            result.score += 10;
        }

        // 8. Verificar domínio internacional (IDN)
        if (this.isInternationalDomain(parsed.domain)) {
            try {
                const asciiDomain = punycode.toASCII(parsed.domain);
                result.checks.internationalDomain = true;
                result.asciiDomain = asciiDomain;
                result.score += 5;
            } catch (error) {
                result.reason = 'Domínio internacional inválido';
                return result;
            }
        }

        // Resultado final
        result.valid = true;
        result.finalScore = Math.max(0, Math.min(100, result.score));

        return result;
    }

    /**
     * Verificar comprimento do email
     */
    checkLength(email, parsed) {
        // RFC 5321: máximo 254 caracteres total
        if (email.length > 254) {
            return { valid: false, reason: 'Email muito longo (máximo 254 caracteres)' };
        }

        // Parte local: máximo 64 caracteres
        if (parsed.local.length > 64) {
            return { valid: false, reason: 'Parte local muito longa (máximo 64 caracteres)' };
        }

        // Mínimo razoável
        if (email.length < 6) { // a@b.co
            return { valid: false, reason: 'Email muito curto' };
        }

        return { valid: true };
    }

    /**
     * Verificar caracteres válidos
     */
    checkCharacters(email, parsed) {
        // Verificar caracteres consecutivos
        if (/\.{2,}/.test(email)) {
            return { valid: false, reason: 'Pontos consecutivos não são permitidos' };
        }

        // Não pode começar ou terminar com ponto
        if (parsed.local.startsWith('.') || parsed.local.endsWith('.')) {
            return { valid: false, reason: 'Email não pode começar ou terminar com ponto' };
        }

        // Verificar espaços
        if (/\s/.test(email)) {
            return { valid: false, reason: 'Email não pode conter espaços' };
        }

        return { valid: true };
    }

    /**
     * Detectar typos comuns
     */
    detectTypos(email, parsed) {
        const domain = parsed.domain.toLowerCase();

        // Verificar typos conhecidos
        for (const [correct, typos] of Object.entries(commonTypos)) {
            if (typos.includes(domain)) {
                const suggestion = email.replace(domain, correct);
                return {
                    found: true,
                    original: domain,
                    suggestion: suggestion,
                    confidence: 0.9
                };
            }
        }

        // Verificar distância de Levenshtein para domínios populares
        const popularDomains = ['gmail.com', 'hotmail.com', 'outlook.com', 'yahoo.com'];
        for (const popular of popularDomains) {
            const distance = this.levenshteinDistance(domain, popular);
            if (distance === 1) {
                const suggestion = email.replace(domain, popular);
                return {
                    found: true,
                    original: domain,
                    suggestion: suggestion,
                    confidence: 0.7
                };
            }
        }

        return { found: false };
    }

    /**
     * Verificar se é email role-based
     */
    checkRoleBased(localPart) {
        const lower = localPart.toLowerCase();

        for (const [type, prefixes] of Object.entries(roleBasedPrefixes)) {
            if (prefixes.includes(lower)) {
                return {
                    isRoleBased: true,
                    type: type,
                    prefix: lower
                };
            }
        }

        return { isRoleBased: false };
    }

    /**
     * Verificar padrões suspeitos
     */
    checkSuspiciousPatterns(email, parsed) {
        for (const pattern of this.suspiciousPatterns) {
            if (pattern.test(email)) {
                return {
                    found: true,
                    pattern: pattern.source
                };
            }
        }

        // Verificar aleatoriedade (entropia)
        const entropy = this.calculateEntropy(parsed.local);
        if (entropy > 4.5) {
            return {
                found: true,
                pattern: 'Alta entropia (possível string aleatória)'
            };
        }

        return { found: false };
    }

    /**
     * Verificar TLD
     */
    checkTLD(tld) {
        const lower = tld.toLowerCase();

        if (this.invalidTlds.includes(lower)) {
            return {
                valid: false,
                reason: `TLD inválido: ${tld}`
            };
        }

        if (this.suspiciousTlds.includes(lower)) {
            return {
                valid: true,
                suspicious: true
            };
        }

        return { valid: true, suspicious: false };
    }

    /**
     * Verificar se é domínio internacional
     */
    isInternationalDomain(domain) {
        return /[^\x00-\x7F]/.test(domain);
    }

    /**
     * Calcular distância de Levenshtein
     */
    levenshteinDistance(str1, str2) {
        const matrix = [];

        for (let i = 0; i <= str2.length; i++) {
            matrix[i] = [i];
        }

        for (let j = 0; j <= str1.length; j++) {
            matrix[0][j] = j;
        }

        for (let i = 1; i <= str2.length; i++) {
            for (let j = 1; j <= str1.length; j++) {
                if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
                    matrix[i][j] = matrix[i - 1][j - 1];
                } else {
                    matrix[i][j] = Math.min(
                        matrix[i - 1][j - 1] + 1,
                        matrix[i][j - 1] + 1,
                        matrix[i - 1][j] + 1
                    );
                }
            }
        }

        return matrix[str2.length][str1.length];
    }

    /**
     * Calcular entropia de Shannon
     */
    calculateEntropy(str) {
        const freq = {};
        for (const char of str) {
            freq[char] = (freq[char] || 0) + 1;
        }

        let entropy = 0;
        const len = str.length;

        for (const count of Object.values(freq)) {
            const p = count / len;
            entropy -= p * Math.log2(p);
        }

        return entropy;
    }
}

module.exports = SyntaxValidator;
EOF
echo -e "${GREEN}✅ Validador de sintaxe criado${NC}"

# ================================================
# 3. CRIAR VALIDADOR MX
# ================================================
echo -e "${BLUE}3️⃣ Criando services/validators/mxValidator.js${NC}"
cat > services/validators/mxValidator.js << 'EOF'
// ================================================
// Validador de MX Records
// services/validators/mxValidator.js
// ================================================

const dns = require('dns').promises;
const net = require('net');
const { parse } = require('tldts');

class MXValidator {
    constructor() {
        this.timeout = 5000; // 5 segundos
        this.cache = new Map(); // Cache simples em memória
        this.cacheTime = 3600000; // 1 hora
    }

    /**
     * Validar domínio via MX records
     */
    async validate(domain) {
        const result = {
            valid: false,
            mxRecords: [],
            score: 0,
            reason: null,
            cached: false
        };

        try {
            // Verificar cache
            const cached = this.getFromCache(domain);
            if (cached) {
                return { ...cached, cached: true };
            }

            // Parse do domínio com tldts
            const parsed = parse(domain);
            if (!parsed.domain) {
                result.reason = 'Domínio inválido';
                return result;
            }

            // 1. Verificar se domínio existe (DNS A record)
            const domainExists = await this.checkDomainExists(domain);
            if (!domainExists) {
                result.reason = 'Domínio não existe';
                this.saveToCache(domain, result);
                return result;
            }
            result.score += 30;

            // 2. Buscar MX records
            const mxRecords = await this.getMXRecords(domain);

            if (!mxRecords || mxRecords.length === 0) {
                // Tentar com domínio principal se for subdomínio
                if (parsed.subdomain) {
                    const mainDomain = parsed.domain;
                    const mainMX = await this.getMXRecords(mainDomain);
                    if (mainMX && mainMX.length > 0) {
                        mxRecords.push(...mainMX);
                    }
                }
            }

            if (!mxRecords || mxRecords.length === 0) {
                result.reason = 'Nenhum MX record encontrado';
                result.score += 10; // Alguns domínios válidos não têm MX
                this.saveToCache(domain, result);
                return result;
            }

            // 3. Ordenar por prioridade
            mxRecords.sort((a, b) => a.priority - b.priority);
            result.mxRecords = mxRecords.map(mx => ({
                exchange: mx.exchange,
                priority: mx.priority
            }));
            result.score += 40;

            // 4. Verificar se MX records apontam para IPs válidos
            const mxValid = await this.verifyMXServers(mxRecords);
            if (!mxValid) {
                result.reason = 'MX servers não respondem';
                result.score -= 20;
            } else {
                result.score += 30;
            }

            // 5. Detectar configurações suspeitas
            const suspicious = this.detectSuspiciousMX(mxRecords, domain);
            if (suspicious.found) {
                result.warnings = suspicious.warnings;
                result.score -= 10;
            }

            result.valid = mxRecords.length > 0 && mxValid;
            result.finalScore = Math.max(0, Math.min(100, result.score));

            // Salvar no cache
            this.saveToCache(domain, result);

            return result;

        } catch (error) {
            console.error(`Erro ao validar MX para ${domain}:`, error);
            result.error = error.message;

            // Se for timeout, ainda pode ser válido
            if (error.code === 'ETIMEOUT') {
                result.valid = true;
                result.reason = 'Timeout na verificação (domínio pode ser válido)';
                result.score = 50;
            }

            return result;
        }
    }

    /**
     * Verificar se domínio existe
     */
    async checkDomainExists(domain) {
        try {
            const addresses = await dns.resolve4(domain).catch(() => null);
            const addresses6 = await dns.resolve6(domain).catch(() => null);
            return !!(addresses || addresses6);
        } catch {
            return false;
        }
    }

    /**
     * Buscar MX records
     */
    async getMXRecords(domain) {
        try {
            const records = await dns.resolveMx(domain);
            return records;
        } catch (error) {
            if (error.code === 'ENOTFOUND' || error.code === 'ENODATA') {
                return [];
            }
            throw error;
        }
    }

    /**
     * Verificar se servidores MX respondem
     */
    async verifyMXServers(mxRecords) {
        if (mxRecords.length === 0) return false;

        // Verificar apenas o primeiro MX (maior prioridade)
        const primaryMX = mxRecords[0];

        try {
            // Verificar se o servidor MX resolve para IP
            const addresses = await dns.resolve4(primaryMX.exchange).catch(() => null);
            return !!addresses && addresses.length > 0;
        } catch {
            return false;
        }
    }

    /**
     * Detectar configurações MX suspeitas
     */
    detectSuspiciousMX(mxRecords, domain) {
        const warnings = [];
        let found = false;

        // Verificar se MX aponta para o próprio domínio
        for (const mx of mxRecords) {
            if (mx.exchange === domain || mx.exchange === `${domain}.`) {
                warnings.push('MX aponta para o próprio domínio');
                found = true;
            }

            // Verificar MX localhost/127.0.0.1
            if (mx.exchange.includes('localhost') || mx.exchange.includes('127.0.0.1')) {
                warnings.push('MX aponta para localhost');
                found = true;
            }

            // Verificar IPs privados
            if (/^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)/.test(mx.exchange)) {
                warnings.push('MX aponta para IP privado');
                found = true;
            }
        }

        // Muitos MX records pode ser suspeito
        if (mxRecords.length > 10) {
            warnings.push('Número excessivo de MX records');
            found = true;
        }

        return { found, warnings };
    }

    /**
     * Cache simples em memória
     */
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

        // Limpar cache antigo (máximo 1000 entradas)
        if (this.cache.size > 1000) {
            const firstKey = this.cache.keys().next().value;
            this.cache.delete(firstKey);
        }
    }

    /**
     * Verificação SMTP (simplificada)
     * NOTA: Muitos servidores bloqueiam isso
     */
    async checkSMTP(email, mxRecord) {
        return new Promise((resolve) => {
            const timeout = setTimeout(() => {
                client.destroy();
                resolve({ valid: false, reason: 'timeout' });
            }, this.timeout);

            const client = net.createConnection(25, mxRecord, () => {
                clearTimeout(timeout);

                let stage = 0;
                const responses = [];

                client.on('data', (data) => {
                    const response = data.toString();
                    responses.push(response);

                    if (stage === 0 && response.includes('220')) {
                        client.write('HELO mail.example.com\r\n');
                        stage++;
                    } else if (stage === 1 && response.includes('250')) {
                        client.write('MAIL FROM:<test@example.com>\r\n');
                        stage++;
                    } else if (stage === 2 && response.includes('250')) {
                        client.write(`RCPT TO:<${email}>\r\n`);
                        stage++;
                    } else if (stage === 3) {
                        client.write('QUIT\r\n');
                        client.destroy();

                        // 250 = aceito, 550 = rejeitado
                        const valid = response.includes('250');
                        resolve({
                            valid,
                            code: response.substring(0, 3),
                            reason: valid ? 'accepted' : 'rejected'
                        });
                    }
                });
            });

            client.on('error', () => {
                clearTimeout(timeout);
                resolve({ valid: false, reason: 'connection_error' });
            });
        });
    }
}

module.exports = MXValidator;
EOF
echo -e "${GREEN}✅ Validador MX criado${NC}"

# ================================================
# 4. CRIAR VALIDADOR DE DISPOSABLE
# ================================================
echo -e "${BLUE}4️⃣ Criando services/validators/disposableValidator.js${NC}"
cat > services/validators/disposableValidator.js << 'EOF'
// ================================================
// Detector de Emails Temporários/Descartáveis
// services/validators/disposableValidator.js
// ================================================

const disposableDomains = require('disposable-email-domains');
const fs = require('fs').promises;
const path = require('path');

class DisposableValidator {
    constructor() {
        this.disposableSet = new Set(disposableDomains);
        this.customDisposable = new Set();
        this.whitelistedDomains = new Set();
        this.loadCustomLists();

        // Padrões de domínios temporários
        this.patterns = [
            /^(temp|tmp|test|fake|spam|trash|disposable|throwaway)/i,
            /^[0-9]+(minute|hour|day)mail/i,
            /mailinator|guerrillamail|10minutemail|yopmail/i,
            /sharklasers|grr\.la|mailnesia|mintemail/i
        ];

        // Provedores conhecidos de email temporário
        this.knownProviders = {
            'high_risk': [
                'mailinator.com', 'guerrillamail.com', '10minutemail.com',
                'tempmail.com', 'throwawaymail.com', 'yopmail.com'
            ],
            'medium_risk': [
                'protonmail.com', 'tutanota.com', 'mail.com'
            ]
        };
    }

    /**
     * Carregar listas customizadas
     */
    async loadCustomLists() {
        try {
            // Carregar lista customizada de disposable
            const customPath = path.join(__dirname, '../data/custom-disposable.json');
            const customData = await fs.readFile(customPath, 'utf-8').catch(() => '[]');
            const customList = JSON.parse(customData);
            customList.forEach(domain => this.customDisposable.add(domain.toLowerCase()));

            // Carregar whitelist
            const whitelistPath = path.join(__dirname, '../data/whitelist-domains.json');
            const whitelistData = await fs.readFile(whitelistPath, 'utf-8').catch(() => '[]');
            const whitelist = JSON.parse(whitelistData);
            whitelist.forEach(domain => this.whitelistedDomains.add(domain.toLowerCase()));

        } catch (error) {
            console.log('Listas customizadas não encontradas, usando padrões');
        }
    }

    /**
     * Verificar se email é descartável
     */
    async check(email, parsed) {
        const result = {
            isDisposable: false,
            confidence: 0,
            riskLevel: 'low',
            reason: null,
            provider: null,
            checks: {}
        };

        const domain = parsed.domain.toLowerCase();
        const local = parsed.local.toLowerCase();

        // 1. Verificar whitelist primeiro
        if (this.whitelistedDomains.has(domain)) {
            result.checks.whitelisted = true;
            result.confidence = 100;
            return result;
        }

        // 2. Verificar lista principal de disposable
        if (this.disposableSet.has(domain)) {
            result.isDisposable = true;
            result.confidence = 95;
            result.riskLevel = 'very_high';
            result.reason = 'Domínio na lista de descartáveis conhecidos';
            result.checks.inDisposableList = true;
            return result;
        }

        // 3. Verificar lista customizada
        if (this.customDisposable.has(domain)) {
            result.isDisposable = true;
            result.confidence = 90;
            result.riskLevel = 'high';
            result.reason = 'Domínio na lista customizada de descartáveis';
            result.checks.inCustomList = true;
            return result;
        }

        // 4. Verificar padrões de nomes
        for (const pattern of this.patterns) {
            if (pattern.test(domain) || pattern.test(local)) {
                result.isDisposable = true;
                result.confidence = 70;
                result.riskLevel = 'high';
                result.reason = `Padrão suspeito detectado: ${pattern.source}`;
                result.checks.patternMatch = true;
                return result;
            }
        }

        // 5. Verificar provedores conhecidos
        for (const [risk, providers] of Object.entries(this.knownProviders)) {
            if (providers.includes(domain)) {
                result.provider = domain;
                result.riskLevel = risk === 'high_risk' ? 'high' : 'medium';
                result.confidence = risk === 'high_risk' ? 80 : 50;
                result.reason = `Provedor de email ${risk.replace('_', ' ')}`;
                result.checks.knownProvider = true;

                if (risk === 'high_risk') {
                    result.isDisposable = true;
                }
                return result;
            }
        }

        // 6. Verificar características suspeitas
        const suspicious = this.checkSuspiciousCharacteristics(domain, local);
        if (suspicious.found) {
            result.confidence = suspicious.confidence;
            result.riskLevel = suspicious.riskLevel;
            result.reason = suspicious.reason;
            result.checks.suspicious = true;

            if (suspicious.confidence > 70) {
                result.isDisposable = true;
            }
        }

        // 7. Análise de subdomínios
        if (parsed.subdomain) {
            const subdomainCheck = this.checkSubdomain(parsed.subdomain);
            if (subdomainCheck.suspicious) {
                result.confidence = Math.max(result.confidence, subdomainCheck.confidence);
                result.riskLevel = 'medium';
                result.checks.suspiciousSubdomain = true;
            }
        }

        return result;
    }

    /**
     * Verificar características suspeitas
     */
    checkSuspiciousCharacteristics(domain, local) {
        let confidence = 0;
        const reasons = [];

        // Domínio muito novo (verificar via API externa se disponível)
        // Por ora, verificar apenas padrões

        // Muitos números no domínio
        const numberCount = (domain.match(/\d/g) || []).length;
        if (numberCount > 3) {
            confidence += 30;
            reasons.push('Muitos números no domínio');
        }

        // Domínio muito curto ou muito longo
        if (domain.length < 5) {
            confidence += 20;
            reasons.push('Domínio muito curto');
        } else if (domain.length > 30) {
            confidence += 25;
            reasons.push('Domínio muito longo');
        }

        // Hífens múltiplos
        if ((domain.match(/-/g) || []).length > 2) {
            confidence += 20;
            reasons.push('Múltiplos hífens no domínio');
        }

        // Parte local genérica
        const genericLocals = ['user', 'test', 'email', 'mail', 'contact'];
        if (genericLocals.includes(local)) {
            confidence += 15;
            reasons.push('Nome de usuário genérico');
        }

        // Parte local com muitos números
        const localNumbers = (local.match(/\d/g) || []).length;
        if (localNumbers > 4) {
            confidence += 20;
            reasons.push('Muitos números no nome de usuário');
        }

        return {
            found: confidence > 0,
            confidence: Math.min(confidence, 85),
            riskLevel: confidence > 60 ? 'high' : confidence > 30 ? 'medium' : 'low',
            reason: reasons.join('; ')
        };
    }

    /**
     * Verificar subdomínio suspeito
     */
    checkSubdomain(subdomain) {
        const suspicious = [
            'mail', 'email', 'temp', 'tmp', 'test',
            'demo', 'trial', 'free', 'spam'
        ];

        const lower = subdomain.toLowerCase();

        for (const word of suspicious) {
            if (lower.includes(word)) {
                return {
                    suspicious: true,
                    confidence: 40,
                    pattern: word
                };
            }
        }

        return { suspicious: false };
    }

    /**
     * Adicionar domínio à lista customizada
     */
    async addToCustomList(domain) {
        this.customDisposable.add(domain.toLowerCase());

        // Salvar no arquivo
        const customPath = path.join(__dirname, '../data/custom-disposable.json');
        const list = Array.from(this.customDisposable);
        await fs.writeFile(customPath, JSON.stringify(list, null, 2));
    }

    /**
     * Adicionar ao whitelist
     */
    async addToWhitelist(domain) {
        this.whitelistedDomains.add(domain.toLowerCase());

        // Salvar no arquivo
        const whitelistPath = path.join(__dirname, '../data/whitelist-domains.json');
        const list = Array.from(this.whitelistedDomains);
        await fs.writeFile(whitelistPath, JSON.stringify(list, null, 2));
    }

    /**
     * Obter estatísticas
     */
    getStats() {
        return {
            memoryCacheSize: this.memoryCache.size,
            redisConnected: this.redis && this.redis.isOpen
        };
    }
}

module.exports = CacheService;
EOF
echo -e "${GREEN}✅ Cache service criado${NC}"

# ================================================
# CRIAR ARQUIVO DE MIGRAÇÃO DO BANCO
# ================================================
echo -e "${CYAN}📊 Criando script de migração do banco...${NC}"
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
RETURNS TRIGGER AS $
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$ language 'plpgsql';

-- Triggers
CREATE TRIGGER update_email_validations_updated_at
    BEFORE UPDATE ON validation.email_validations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_stats_updated_at
    BEFORE UPDATE ON validation.user_stats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Função para atualizar estatísticas do usuário
CREATE OR REPLACE FUNCTION update_user_stats()
RETURNS TRIGGER AS $
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
$ language 'plpgsql';

-- Trigger para estatísticas
CREATE TRIGGER update_stats_on_validation
    AFTER INSERT ON validation.email_validations
    FOR EACH ROW
    WHEN (NEW.user_id IS NOT NULL)
    EXECUTE FUNCTION update_user_stats();
EOF
echo -e "${GREEN}✅ Script de migração criado${NC}"

# ================================================
# RESUMO FINAL
# ================================================
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✨ TODOS OS ARQUIVOS FORAM CRIADOS!${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}📁 Estrutura criada:${NC}"
echo "   services/"
echo "   ├── validators/"
echo "   │   ├── index.js (Orquestrador)"
echo "   │   ├── syntaxValidator.js (Validação avançada)"
echo "   │   ├── mxValidator.js (Verificação MX)"
echo "   │   ├── disposableValidator.js (Detecção disposable)"
echo "   │   └── scoreCalculator.js (Cálculo de score)"
echo "   ├── data/"
echo "   │   ├── commonTypos.json"
echo "   │   ├── roleBasedPrefixes.json"
echo "   │   ├── tldScores.json"
echo "   │   ├── custom-disposable.json"
echo "   │   └── whitelist-domains.json"
echo "   ├── utils/"
echo "   │   ├── emailParser.js"
echo "   │   └── cache.js"
echo "   └── migrations/"
echo "       └── create_validation_tables.sql"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 Próximos passos:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. Executar a migração do banco:"
echo -e "   ${CYAN}psql \$DATABASE_URL < services/migrations/create_validation_tables.sql${NC}"
echo ""
echo "2. Atualizar o server.js para usar o novo validador:"
echo -e "   ${CYAN}const EmailValidator = require('./services/validators');${NC}"
echo ""
echo "3. Adicionar as novas rotas de API:"
echo "   - POST /api/validate/email (validação completa)"
echo "   - POST /api/validate/batch (validação em lote)"
echo "   - GET /api/validate/stats (estatísticas)"
echo ""
echo "4. Testar o sistema:"
echo -e "   ${CYAN}npm test${NC}"
echo ""
echo -e "${GREEN}🎉 Sistema de validação avançado pronto para uso!${NC}"
echo ""

# Perguntar se quer criar arquivo de teste
read -p "Deseja criar um arquivo de teste básico? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}📄 Criando arquivo de teste...${NC}"
    cat > test-validator.js << 'EOF'
// ================================================
// Teste do Validador de Email
// ================================================

const EmailValidator = require('./services/validators');
const DatabaseService = require('./services/database');

async function test() {
    console.log('🧪 Iniciando teste do validador...\n');

    // Inicializar
    const db = new DatabaseService();
    const validator = new EmailValidator(db);

    // Emails para testar
    const testEmails = [
        'joao.silva@gmail.com',          // Válido
        'maria@empresa.com.br',           // Válido corporativo
        'test@tempmail.com',              // Disposable
        'admin@company.com',              // Role-based
        'user@gmial.com',                 // Typo
        'invalido@',                      // Inválido
        'test123456@mailinator.com',      // Disposable conhecido
        'ceo@microsoft.com'               // Corporativo
    ];

    console.log('Testando emails:\n');

    for (const email of testEmails) {
        console.log(`\n📧 ${email}`);
        console.log('─'.repeat(40));

        try {
            const result = await validator.validate(email, {
                checkMX: true,
                checkDisposable: true,
                detailed: true
            });

            console.log(`✓ Válido: ${result.valid ? '✅' : '❌'}`);
            console.log(`✓ Score: ${result.score}/100`);
            console.log(`✓ Risco: ${result.risk}`);
            console.log(`✓ Tempo: ${result.processingTime}ms`);

            if (result.details && result.details.suggestions.length > 0) {
                console.log(`💡 Sugestão: ${result.details.suggestions[0].suggested}`);
            }

        } catch (error) {
            console.error(`❌ Erro: ${error.message}`);
        }
    }

    console.log('\n\n✅ Teste concluído!');
    process.exit(0);
}

// Executar teste
test().catch(console.error);
EOF
    echo -e "${GREEN}✅ Arquivo de teste criado: test-validator.js${NC}"
    echo -e "   Execute com: ${CYAN}node test-validator.js${NC}"
fi

echo ""
echo -e "${GREEN}🚀 Script concluído com sucesso!${NC}"
     */
    getStats() {
        return {
            totalDisposable: this.disposableSet.size + this.customDisposable.size,
            mainList: this.disposableSet.size,
            customList: this.customDisposable.size,
            whitelisted: this.whitelistedDomains.size,
            patterns: this.patterns.length
        };
    }

    /**
     * Atualizar lista de domínios descartáveis
     */
    async updateDisposableList() {
        try {
            // Aqui você pode implementar download de lista atualizada
            // Por exemplo, do GitHub do disposable-email-domains
            console.log('Atualizando lista de domínios descartáveis...');

            // Por ora, apenas recarregar
            this.disposableSet = new Set(disposableDomains);

            return {
                success: true,
                count: this.disposableSet.size
            };
        } catch (error) {
            console.error('Erro ao atualizar lista:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }
}

module.exports = DisposableValidator;
EOF
echo -e "${GREEN}✅ Validador de disposable criado${NC}"

# ================================================
# 5. CRIAR CALCULADORA DE SCORE
# ================================================
echo -e "${BLUE}5️⃣ Criando services/validators/scoreCalculator.js${NC}"
cat > services/validators/scoreCalculator.js << 'EOF'
// ================================================
// Calculadora de Score de Qualidade
// services/validators/scoreCalculator.js
// ================================================

const tldScores = require('../data/tldScores.json');

class ScoreCalculator {
    constructor() {
        // Pesos para cada componente
        this.weights = {
            syntax: 0.25,      // 25%
            mx: 0.30,          // 30%
            disposable: 0.20,  // 20%
            domain: 0.15,      // 15%
            patterns: 0.10     // 10%
        };

        // Fatores de penalidade
        this.penalties = {
            roleEmail: -15,
            disposableEmail: -40,
            noMxRecords: -20,
            suspiciousPattern: -10,
            typoDetected: -5,
            genericProvider: -5,
            suspiciousTld: -10
        };

        // Fatores de bônus
        this.bonuses = {
            corporateDomain: 15,
            verifiedMx: 10,
            establishedDomain: 10,
            properFormat: 5
        };
    }

    /**
     * Calcular score final
     */
    calculate(data) {
        let score = 50; // Score base
        const breakdown = {
            base: 50,
            adjustments: []
        };

        // 1. Score de sintaxe
        if (data.syntax) {
            const syntaxScore = this.calculateSyntaxScore(data.syntax);
            score += syntaxScore.points;
            breakdown.adjustments.push({
                category: 'syntax',
                points: syntaxScore.points,
                reason: syntaxScore.reason
            });
        }

        // 2. Score de MX
        if (data.mx) {
            const mxScore = this.calculateMXScore(data.mx);
            score += mxScore.points;
            breakdown.adjustments.push({
                category: 'mx',
                points: mxScore.points,
                reason: mxScore.reason
            });
        }

        // 3. Score de disposable
        if (data.disposable) {
            const disposableScore = this.calculateDisposableScore(data.disposable);
            score += disposableScore.points;
            breakdown.adjustments.push({
                category: 'disposable',
                points: disposableScore.points,
                reason: disposableScore.reason
            });
        }

        // 4. Score de domínio
        if (data.parsed) {
            const domainScore = this.calculateDomainScore(data.parsed);
            score += domainScore.points;
            breakdown.adjustments.push({
                category: 'domain',
                points: domainScore.points,
                reason: domainScore.reason
            });
        }

        // Normalizar score (0-100)
        score = Math.max(0, Math.min(100, score));

        // Calcular nível de confiança
        const confidence = this.calculateConfidence(data);

        return {
            total: Math.round(score),
            confidence: confidence,
            breakdown: breakdown,
            recommendation: this.getRecommendation(score),
            quality: this.getQualityLevel(score)
        };
    }

    /**
     * Calcular score de sintaxe
     */
    calculateSyntaxScore(syntax) {
        let points = 0;
        let reasons = [];

        if (syntax.valid) {
            points += 15;
            reasons.push('Sintaxe válida (+15)');
        } else {
            points -= 30;
            reasons.push('Sintaxe inválida (-30)');
            return { points, reason: reasons.join(', ') };
        }

        // Penalidades
        if (syntax.checks && syntax.checks.roleBased === false) {
            points += this.penalties.roleEmail;
            reasons.push('Email role-based (-15)');
        }

        if (syntax.typoSuggestion) {
            points += this.penalties.typoDetected;
            reasons.push('Possível typo (-5)');
        }

        if (syntax.suspiciousPattern) {
            points += this.penalties.suspiciousPattern;
            reasons.push('Padrão suspeito (-10)');
        }

        // Bônus
        if (syntax.checks && syntax.checks.format) {
            points += this.bonuses.properFormat;
            reasons.push('Formato adequado (+5)');
        }

        return { points, reason: reasons.join(', ') };
    }

    /**
     * Calcular score de MX
     */
    calculateMXScore(mx) {
        let points = 0;
        let reasons = [];

        if (mx.valid) {
            points += 20;
            reasons.push('MX válido (+20)');

            if (mx.mxRecords && mx.mxRecords.length > 0) {
                points += this.bonuses.verifiedMx;
                reasons.push('MX verificado (+10)');
            }
        } else {
            if (mx.reason === 'Nenhum MX record encontrado') {
                points += this.penalties.noMxRecords;
                reasons.push('Sem MX records (-20)');
            } else {
                points -= 15;
                reasons.push('MX inválido (-15)');
            }
        }

        return { points, reason: reasons.join(', ') };
    }

    /**
     * Calcular score de disposable
     */
    calculateDisposableScore(disposable) {
        let points = 0;
        let reasons = [];

        if (disposable.isDisposable) {
            points += this.penalties.disposableEmail;
            reasons.push('Email descartável (-40)');
        } else {
            points += 10;
            reasons.push('Não é descartável (+10)');
        }

        // Ajustar baseado no nível de risco
        switch (disposable.riskLevel) {
            case 'very_high':
                points -= 10;
                reasons.push('Risco muito alto (-10)');
                break;
            case 'high':
                points -= 5;
                reasons.push('Risco alto (-5)');
                break;
            case 'medium':
                points -= 2;
                reasons.push('Risco médio (-2)');
                break;
        }

        return { points, reason: reasons.join(', ') };
    }

    /**
     * Calcular score de domínio
     */
    calculateDomainScore(parsed) {
        let points = 0;
        let reasons = [];

        const domain = parsed.domain.toLowerCase();

        // Verificar TLD
        const tldScore = tldScores[parsed.tld] || 5;
        points += (tldScore - 5); // Normalizar em torno de 0
        if (tldScore > 7) {
            reasons.push(`TLD confiável (+${tldScore - 5})`);
        } else if (tldScore < 3) {
            reasons.push(`TLD suspeito (${tldScore - 5})`);
        }

        // Domínios corporativos conhecidos
        const corporateDomains = [
            'gmail.com', 'outlook.com', 'yahoo.com', 'hotmail.com',
            'icloud.com', 'protonmail.com', 'aol.com'
        ];

        if (corporateDomains.includes(domain)) {
            points += this.bonuses.corporateDomain;
            reasons.push('Domínio corporativo (+15)');
        }

        // Verificar se é provedor genérico
        const genericProviders = ['gmail.com', 'hotmail.com', 'yahoo.com'];
        if (genericProviders.includes(domain)) {
            points += this.penalties.genericProvider;
            reasons.push('Provedor genérico (-5)');
        }

        return { points, reason: reasons.join(', ') };
    }

    /**
     * Calcular confiança
     */
    calculateConfidence(data) {
        let checks = 0;
        let completed = 0;

        if (data.syntax) {
            checks++;
            if (data.syntax.valid !== undefined) completed++;
        }
        if (data.mx) {
            checks++;
            if (data.mx.valid !== undefined) completed++;
        }
        if (data.disposable) {
            checks++;
            if (data.disposable.isDisposable !== undefined) completed++;
        }

        return checks > 0 ? Math.round((completed / checks) * 100) : 0;
    }

    /**
     * Obter recomendação
     */
    getRecommendation(score) {
        if (score >= 80) {
            return {
                action: 'accept',
                message: 'Email de alta qualidade, recomendado aceitar'
            };
        } else if (score >= 60) {
            return {
                action: 'review',
                message: 'Email de qualidade média, revisar manualmente'
            };
        } else if (score >= 40) {
            return {
                action: 'caution',
                message: 'Email de baixa qualidade, usar com cautela'
            };
        } else {
            return {
                action: 'reject',
                message: 'Email de qualidade muito baixa, recomendado rejeitar'
            };
        }
    }

    /**
     * Obter nível de qualidade
     */
    getQualityLevel(score) {
        if (score >= 80) return 'excellent';
        if (score >= 60) return 'good';
        if (score >= 40) return 'fair';
        if (score >= 20) return 'poor';
        return 'very_poor';
    }
}

module.exports = ScoreCalculator;
EOF
echo -e "${GREEN}✅ Calculadora de score criada${NC}"

# ================================================
# CRIAR ARQUIVOS DE DADOS
# ================================================
echo -e "${CYAN}📂 Criando arquivos de dados...${NC}"

# Criar commonTypos.json
echo -e "${BLUE}📄 Criando services/data/commonTypos.json${NC}"
cat > services/data/commonTypos.json << 'EOF'
{
  "gmail.com": ["gmial.com", "gmai.com", "gmali.com", "gmail.co", "gmaill.com", "gmail.com.br"],
  "hotmail.com": ["hotmai.com", "hotmial.com", "hotmal.com", "hotmeil.com", "hotmil.com"],
  "outlook.com": ["outlok.com", "outloook.com", "outlook.co", "outllok.com"],
  "yahoo.com": ["yaho.com", "yahooo.com", "yahoo.co", "yhoo.com", "yaho.com.br"],
  "icloud.com": ["iclound.com", "icloude.com", "icloud.co"],
  "protonmail.com": ["protonmai.com", "protonemail.com", "proton.com"]
}
EOF

# Criar roleBasedPrefixes.json
echo -e "${BLUE}📄 Criando services/data/roleBasedPrefixes.json${NC}"
cat > services/data/roleBasedPrefixes.json << 'EOF'
{
  "administrative": [
    "admin", "administrator", "root", "system", "webmaster",
    "postmaster", "hostmaster", "manager"
  ],
  "support": [
    "support", "help", "helpdesk", "customerservice", "service",
    "contact", "contacts", "feedback", "suporte", "atendimento"
  ],
  "sales": [
    "sales", "vendas", "comercial", "business", "ventas",
    "inquiries", "inquiry", "pedidos"
  ],
  "info": [
    "info", "information", "informacion", "informacao", "about"
  ],
  "marketing": [
    "marketing", "newsletter", "news", "media", "press",
    "pr", "publicrelations", "comunicacao"
  ],
  "noreply": [
    "noreply", "no-reply", "donotreply", "do-not-reply",
    "notification", "notifications", "alert", "alerts"
  ],
  "technical": [
    "tech", "technical", "it", "dev", "developer", "engineering",
    "devops", "sysadmin", "security"
  ],
  "billing": [
    "billing", "invoice", "invoices", "payment", "payments",
    "finance", "accounting", "faturamento", "financeiro"
  ],
  "hr": [
    "hr", "human-resources", "careers", "jobs", "recruitment",
    "rh", "recursos-humanos", "talentos"
  ]
}
EOF

# Criar tldScores.json
echo -e "${BLUE}📄 Criando services/data/tldScores.json${NC}"
cat > services/data/tldScores.json << 'EOF'
{
  "com": 10,
  "org": 9,
  "net": 8,
  "edu": 10,
  "gov": 10,
  "br": 9,
  "co.uk": 9,
  "de": 9,
  "fr": 9,
  "ca": 9,
  "au": 9,
  "jp": 9,
  "io": 7,
  "co": 7,
  "us": 8,
  "me": 6,
  "info": 6,
  "biz": 5,
  "tv": 5,
  "cc": 4,
  "ws": 4,
  "tk": 2,
  "ml": 2,
  "ga": 2,
  "cf": 2,
  "click": 3,
  "download": 3,
  "review": 3,
  "top": 3,
  "xyz": 4,
  "online": 5,
  "site": 5,
  "tech": 7,
  "app": 7,
  "dev": 8
}
EOF

# Criar listas vazias para customização
echo -e "${BLUE}📄 Criando services/data/custom-disposable.json${NC}"
echo '[]' > services/data/custom-disposable.json

echo -e "${BLUE}📄 Criando services/data/whitelist-domains.json${NC}"
cat > services/data/whitelist-domains.json << 'EOF'
[
  "empresa.com.br",
  "sparknexus.com.br"
]
EOF

# ================================================
# CRIAR UTILITÁRIOS
# ================================================
echo -e "${CYAN}🔧 Criando utilitários...${NC}"

# Criar EmailParser
echo -e "${BLUE}📄 Criando services/utils/emailParser.js${NC}"
cat > services/utils/emailParser.js << 'EOF'
// ================================================
// Parser de Email
// services/utils/emailParser.js
// ================================================

const { parse } = require('tldts');

class EmailParser {
    /**
     * Parse completo do email
     */
    parse(email) {
        if (!email || typeof email !== 'string') {
            throw new Error('Email inválido');
        }

        const normalized = email.toLowerCase().trim();
        const parts = normalized.split('@');

        if (parts.length !== 2) {
            throw new Error('Formato de email inválido');
        }

        const [local, fullDomain] = parts;

        // Parse do domínio usando tldts
        const domainParsed = parse(fullDomain);

        // Detectar subaddressing (user+tag@domain)
        let baseLocal = local;
        let tag = null;
        if (local.includes('+')) {
            const plusParts = local.split('+');
            baseLocal = plusParts[0];
            tag = plusParts[1];
        }

        return {
            full: normalized,
            local: local,
            baseLocal: baseLocal,
            tag: tag,
            domain: fullDomain,
            hostname: domainParsed.hostname,
            subdomain: domainParsed.subdomain,
            domainWithoutSuffix: domainParsed.domainWithoutSuffix,
            publicSuffix: domainParsed.publicSuffix,
            tld: domainParsed.publicSuffix,
            isSubaddressed: !!tag,
            isIp: domainParsed.isIp,
            isPrivate: domainParsed.isPrivate
        };
    }

    /**
     * Normalizar email
     */
    normalize(email) {
        const parsed = this.parse(email);

        // Remover tags e normalizar
        return `${parsed.baseLocal}@${parsed.domain}`;
    }

    /**
     * Extrair domínio
     */
    extractDomain(email) {
        const parsed = this.parse(email);
        return parsed.domain;
    }

    /**
     * Verificar se é email corporativo
     */
    isCorporate(email) {
        const parsed = this.parse(email);
        const genericProviders = [
            'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com',
            'aol.com', 'icloud.com', 'mail.com', 'protonmail.com'
        ];

        return !genericProviders.includes(parsed.domain);
    }
}

module.exports = EmailParser;
EOF

# Criar Cache Service
echo -e "${BLUE}📄 Criando services/utils/cache.js${NC}"
cat > services/utils/cache.js << 'EOF'
// ================================================
// Serviço de Cache
// services/utils/cache.js
// ================================================

class CacheService {
    constructor(redisClient = null) {
        this.redis = redisClient;
        this.memoryCache = new Map();
        this.maxMemoryCacheSize = 1000;
    }

    /**
     * Obter do cache
     */
    async get(key) {
        // Tentar Redis primeiro
        if (this.redis && this.redis.isOpen) {
            try {
                const value = await this.redis.get(key);
                if (value) {
                    return JSON.parse(value);
                }
            } catch (error) {
                console.error('Erro ao buscar do Redis:', error);
            }
        }

        // Fallback para cache em memória
        const cached = this.memoryCache.get(key);
        if (cached && Date.now() < cached.expires) {
            return cached.value;
        }

        this.memoryCache.delete(key);
        return null;
    }

    /**
     * Salvar no cache
     */
    async set(key, value, ttl = 3600) {
        // Salvar no Redis se disponível
        if (this.redis && this.redis.isOpen) {
            try {
                await this.redis.setEx(key, ttl, JSON.stringify(value));
            } catch (error) {
                console.error('Erro ao salvar no Redis:', error);
            }
        }

        // Salvar também na memória
        this.memoryCache.set(key, {
            value: value,
            expires: Date.now() + (ttl * 1000)
        });

        // Limpar cache se muito grande
        if (this.memoryCache.size > this.maxMemoryCacheSize) {
            const firstKey = this.memoryCache.keys().next().value;
            this.memoryCache.delete(firstKey);
        }
    }

    /**
     * Deletar do cache
     */
    async delete(key) {
        if (this.redis && this.redis.isOpen) {
            try {
                await this.redis.del(key);
            } catch (error) {
                console.error('Erro ao deletar do Redis:', error);
            }
        }

        this.memoryCache.delete(key);
    }

    /**
     * Limpar todo o cache
     */
    async clear() {
        if (this.redis && this.redis.isOpen) {
            try {
                await this.redis.flushDb();
            } catch (error) {
                console.error('Erro ao limpar Redis:', error);
            }
        }

        this.memoryCache.clear();
    }

    /**
     * Obter estatísticas
