// ================================================
// Ultimate Email Validator - v3.0
// Sistema completo de validação com correção automática
// ================================================

const dns = require('dns').promises;
const net = require('net');

// Importar validadores avançados
const DomainCorrector = require('./services/validators/advanced/DomainCorrector');
const BlockedDomains = require('./services/validators/advanced/BlockedDomains');
const DisposableChecker = require('./services/validators/advanced/DisposableChecker');
const TLDValidator = require('./services/validators/advanced/TLDValidator');
const PatternDetector = require('./services/validators/advanced/PatternDetector');
const SMTPValidator = require('./services/validators/advanced/SMTPValidator');
const TrustedDomains = require('./services/validators/advanced/TrustedDomains');
const EcommerceScoring = require('./services/validators/advanced/EcommerceScoring');

class UltimateValidator {
    constructor(options = {}) {
        // Configurações
        this.options = {
            enableSMTP: options.enableSMTP !== false,
            enableCache: options.enableCache !== false,
            smtpTimeout: options.smtpTimeout || 5000,
            scoreThreshold: options.scoreThreshold || 40,
            enableCorrection: options.enableCorrection !== false,
            maxCacheSize: options.maxCacheSize || 10000,
            cacheExpiry: options.cacheExpiry || 3600000, // 1 hora
            debug: options.debug || false
        };

        // Inicializar todos os validadores
        this.domainCorrector = new DomainCorrector();
        this.blockedDomains = new BlockedDomains();
        this.disposableChecker = new DisposableChecker();
        this.tldValidator = new TLDValidator();
        this.patternDetector = new PatternDetector();
        this.smtpValidator = new SMTPValidator();
        this.trustedDomains = new TrustedDomains();
        this.ecommerceScoring = new EcommerceScoring();

        // Cache
        this.cache = new Map();
        this.cacheStats = {
            hits: 0,
            misses: 0,
            expired: 0
        };

        // Estatísticas gerais
        this.stats = {
            totalValidated: 0,
            validEmails: 0,
            invalidEmails: 0,
            correctedEmails: 0,
            blockedEmails: 0,
            disposableEmails: 0,
            smtpVerified: 0,
            smtpFailed: 0,
            errors: 0,
            avgProcessingTime: 0,
            processingTimes: []
        };

        // Limpar cache periodicamente
        if (this.options.enableCache) {
            setInterval(() => this.cleanCache(), this.options.cacheExpiry);
        }

        this.log('✅ UltimateValidator inicializado com sucesso');
    }

    /**
     * Valida um único email com todas as verificações
     * @param {string} email - Email para validar
     * @returns {Object} Resultado completo da validação
     */
    async validateEmail(email) {
        const startTime = Date.now();
        this.stats.totalValidated++;

        try {
            // Validação básica de formato
            if (!email || typeof email !== 'string') {
                return this.createErrorResult(email, 'Email inválido ou vazio');
            }

            const emailLower = email.toLowerCase().trim();

            // Verificar cache se habilitado
            if (this.options.enableCache) {
                const cached = this.getCached(emailLower);
                if (cached) {
                    this.cacheStats.hits++;
                    this.log(`📦 Cache hit para: ${emailLower}`);
                    return cached;
                }
                this.cacheStats.misses++;
            }

            // ================================================
            // PASSO 1: CORREÇÃO DE DOMÍNIO
            // ================================================
            let correctionResult = null;
            let emailToValidate = emailLower;
            let wasCorrected = false;

            if (this.options.enableCorrection) {
                correctionResult = this.domainCorrector.correctEmail(emailLower);

                if (correctionResult.wasCorrected) {
                    emailToValidate = correctionResult.corrected;
                    wasCorrected = true;
                    this.stats.correctedEmails++;
                    this.log(`✏️ Email corrigido: ${emailLower} → ${emailToValidate}`);
                }
            }

            // Estrutura base do resultado
            const result = {
                email: email,
                normalizedEmail: emailLower,
                correctedEmail: wasCorrected ? emailToValidate : null,
                wasCorrected: wasCorrected,
                correctionDetails: wasCorrected ? correctionResult.correction : null,
                valid: false,
                score: 0,
                timestamp: new Date().toISOString(),
                processingTime: 0,
                checks: {
                    format: null,
                    blocked: null,
                    disposable: null,
                    tld: null,
                    dns: null,
                    pattern: null,
                    smtp: null,
                    trusted: null
                },
                scoring: null,
                recommendations: [],
                metadata: {}
            };

            // ================================================
            // PASSO 2: VALIDAÇÃO DE FORMATO
            // ================================================
            const formatCheck = this.validateFormat(emailToValidate);
            result.checks.format = formatCheck;

            if (!formatCheck.valid) {
                result.valid = false;
                result.score = 0;
                result.recommendations.push('Email em formato inválido');
                return this.finalizeResult(result, startTime);
            }

            const [localPart, domain] = emailToValidate.split('@');
            result.metadata.localPart = localPart;
            result.metadata.domain = domain;

            // ================================================
            // PASSO 3: VERIFICAR DOMÍNIO BLOQUEADO
            // ================================================
            const blockCheck = this.blockedDomains.isBlocked(emailToValidate);
            result.checks.blocked = blockCheck;

            if (blockCheck.blocked) {
                this.stats.blockedEmails++;
                result.valid = false;
                result.score = 0;
                result.recommendations.push(`Email bloqueado: ${blockCheck.reason}`);
                this.log(`🚫 Email bloqueado: ${emailToValidate} - ${blockCheck.reason}`);
                return this.finalizeResult(result, startTime);
            }

            // ================================================
            // PASSO 4: VERIFICAR EMAIL DESCARTÁVEL
            // ================================================
            const disposableCheck = this.disposableChecker.checkEmail(emailToValidate);
            result.checks.disposable = disposableCheck;

            if (disposableCheck.isDisposable) {
                this.stats.disposableEmails++;
                result.valid = false;
                result.score = disposableCheck.score || 0;
                result.recommendations.push('Email temporário/descartável detectado');
                this.log(`🗑️ Email descartável: ${emailToValidate}`);
            }

            // ================================================
            // PASSO 5: VALIDAR TLD
            // ================================================
            const tldCheck = this.tldValidator.validateTLD(domain);
            result.checks.tld = tldCheck;

            if (!tldCheck.valid || tldCheck.isBlocked) {
                result.valid = false;
                result.score = Math.min(result.score, 20);
                result.recommendations.push('TLD inválido ou bloqueado');
                this.log(`❌ TLD inválido: ${domain}`);
            }

            // ================================================
            // PASSO 6: VERIFICAR DNS/MX
            // ================================================
            const dnsCheck = await this.checkDNS(domain);
            result.checks.dns = dnsCheck;

            if (!dnsCheck.valid) {
                result.valid = false;
                result.score = Math.min(result.score, 30);
                result.recommendations.push('Domínio não possui registros MX válidos');
                this.log(`📭 Sem MX records: ${domain}`);
            }

            // ================================================
            // PASSO 7: DETECTAR PADRÕES SUSPEITOS
            // ================================================
            const patternCheck = this.patternDetector.analyzeEmail(emailToValidate);
            result.checks.pattern = patternCheck;

            if (patternCheck.suspicious) {
                result.metadata.suspicionLevel = patternCheck.suspicionLevel;
                result.metadata.suspiciousPatterns = patternCheck.patterns;

                if (patternCheck.suspicionLevel >= 7) {
                    result.valid = false;
                    result.score = Math.min(result.score, 20);
                    result.recommendations.push('Padrões altamente suspeitos detectados');
                }
            }

            // ================================================
            // PASSO 8: VERIFICAÇÃO SMTP (se habilitado)
            // ================================================
            if (this.options.enableSMTP && dnsCheck.valid) {
                try {
                    const smtpCheck = await this.smtpValidator.validateEmail(emailToValidate);
                    result.checks.smtp = smtpCheck;

                    if (smtpCheck.exists) {
                        this.stats.smtpVerified++;
                        result.metadata.mailboxVerified = true;
                    } else {
                        this.stats.smtpFailed++;
                        result.valid = false;
                        result.score = Math.min(result.score, 40);
                        result.recommendations.push('Caixa postal não encontrada no servidor');
                        this.log(`📪 Mailbox não existe: ${emailToValidate}`);
                    }
                } catch (smtpError) {
                    this.log(`⚠️ Erro SMTP para ${emailToValidate}: ${smtpError.message}`);
                    result.checks.smtp = {
                        checked: false,
                        error: smtpError.message,
                        exists: null
                    };
                }
            } else {
                result.checks.smtp = {
                    checked: false,
                    reason: this.options.enableSMTP ? 'No MX records' : 'SMTP disabled'
                };
            }

            // ================================================
            // PASSO 9: VERIFICAR DOMÍNIO CONFIÁVEL
            // ================================================
            const isTrusted = this.trustedDomains.isTrusted(domain);
            const trustCategory = this.trustedDomains.getCategory(domain);
            const trustScore = this.trustedDomains.getTrustScore(domain);

            result.checks.trusted = {
                isTrusted: isTrusted,
                category: trustCategory,
                trustScore: trustScore
            };

            result.metadata.trustedDomain = isTrusted;
            result.metadata.domainCategory = trustCategory;

            // ================================================
            // PASSO 10: CALCULAR SCORE FINAL (E-commerce Scoring)
            // ================================================
            const scoringInput = {
                email: emailToValidate,
                wasCorrected: wasCorrected,
                correctionDetails: correctionResult,
                tld: tldCheck,
                disposable: disposableCheck,
                smtp: result.checks.smtp,
                patterns: patternCheck,
                dns: dnsCheck,
                trusted: result.checks.trusted,
                blocked: blockCheck
            };

            const scoringResult = this.ecommerceScoring.calculateScore(scoringInput);
            result.scoring = scoringResult;
            result.score = scoringResult.finalScore;
            result.valid = scoringResult.valid;

            // ================================================
            // PASSO 11: CONSOLIDAR RECOMENDAÇÕES
            // ================================================
            // Adicionar recomendações do scoring
            if (scoringResult.recommendations) {
                result.recommendations.push(...scoringResult.recommendations.map(r =>
                    typeof r === 'string' ? r : r.message
                ));
            }

            // Recomendação sobre correção
            if (wasCorrected) {
                result.recommendations.unshift(
                    `Email corrigido automaticamente de "${email}" para "${emailToValidate}"`
                );
            }

            // Recomendação final baseada no score
            if (result.score >= 80) {
                result.recommendations.push('✅ Email altamente confiável');
                result.valid = true;
            } else if (result.score >= 60) {
                result.recommendations.push('✓ Email válido com confiança moderada');
                result.valid = true;
            } else if (result.score >= this.options.scoreThreshold) {
                result.recommendations.push('⚠️ Email duvidoso - verificação adicional recomendada');
                result.valid = true; // Válido mas com ressalvas
            } else {
                result.recommendations.push('❌ Email inválido ou de alto risco');
                result.valid = false;
            }

            // ================================================
            // PASSO 12: ADICIONAR METADADOS FINAIS
            // ================================================
            result.metadata.finalDecision = result.valid ? 'APPROVED' : 'REJECTED';
            result.metadata.confidenceLevel = this.getConfidenceLevel(result.score);
            result.metadata.riskLevel = scoringResult.riskLevel || 'UNKNOWN';
            result.metadata.buyerType = scoringResult.buyerType || 'UNKNOWN';

            // Atualizar estatísticas
            if (result.valid) {
                this.stats.validEmails++;
            } else {
                this.stats.invalidEmails++;
            }

            // Finalizar e cachear resultado
            return this.finalizeResult(result, startTime);

        } catch (error) {
            this.stats.errors++;
            this.log(`❌ Erro ao validar ${email}: ${error.message}`);
            return this.createErrorResult(email, error.message);
        }
    }

    /**
     * Valida formato básico do email
     */
    validateFormat(email) {
        const result = {
            valid: false,
            details: {}
        };

        // Regex RFC 5322 simplificado
        const emailRegex = /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;

        if (!emailRegex.test(email)) {
            result.details.reason = 'Formato inválido';
            return result;
        }

        const parts = email.split('@');
        if (parts.length !== 2) {
            result.details.reason = 'Deve conter exatamente um @';
            return result;
        }

        const [localPart, domain] = parts;

        // Validar local part
        if (localPart.length === 0 || localPart.length > 64) {
            result.details.reason = 'Local part deve ter entre 1 e 64 caracteres';
            return result;
        }

        // Validar domain
        if (domain.length === 0 || domain.length > 253) {
            result.details.reason = 'Domínio deve ter entre 1 e 253 caracteres';
            return result;
        }

        // Verificar caracteres consecutivos inválidos
        if (/\.{2,}/.test(email)) {
            result.details.reason = 'Pontos consecutivos não são permitidos';
            return result;
        }

        result.valid = true;
        result.details = {
            localPart: localPart,
            domain: domain,
            localPartLength: localPart.length,
            domainLength: domain.length
        };

        return result;
    }

    /**
     * Verifica DNS e MX records
     */
    async checkDNS(domain) {
        const result = {
            valid: false,
            hasMX: false,
            hasA: false,
            mxRecords: [],
            details: {}
        };

        try {
            // Verificar MX records
            try {
                const mxRecords = await dns.resolveMx(domain);
                if (mxRecords && mxRecords.length > 0) {
                    result.hasMX = true;
                    result.mxRecords = mxRecords.sort((a, b) => a.priority - b.priority);
                    result.valid = true;
                }
            } catch (mxError) {
                // MX não encontrado, tentar A record
            }

            // Se não tem MX, verificar A record
            if (!result.hasMX) {
                try {
                    const addresses = await dns.resolve4(domain);
                    if (addresses && addresses.length > 0) {
                        result.hasA = true;
                        result.valid = true; // Alguns domínios usam A record para email
                        result.details.aRecords = addresses;
                    }
                } catch (aError) {
                    // A record também não encontrado
                }
            }

            result.details.preferredExchange = result.mxRecords[0]?.exchange || null;

        } catch (error) {
            result.details.error = error.message;
        }

        return result;
    }

    /**
     * Valida múltiplos emails em lote
     */
    async validateBatch(emails, options = {}) {
        const batchSize = options.batchSize || 10;
        const results = [];

        this.log(`🔄 Iniciando validação em lote de ${emails.length} emails`);

        for (let i = 0; i < emails.length; i += batchSize) {
            const batch = emails.slice(i, i + batchSize);
            const batchPromises = batch.map(email => this.validateEmail(email));
            const batchResults = await Promise.allSettled(batchPromises);

            batchResults.forEach((result, index) => {
                if (result.status === 'fulfilled') {
                    results.push(result.value);
                } else {
                    results.push(this.createErrorResult(batch[index], result.reason));
                }
            });

            this.log(`✅ Processados ${Math.min(i + batchSize, emails.length)}/${emails.length}`);
        }

        return results;
    }

    /**
     * Gerenciamento de cache
     */
    getCached(email) {
        if (!this.cache.has(email)) return null;

        const cached = this.cache.get(email);
        const now = Date.now();

        if (now - cached.cachedAt > this.options.cacheExpiry) {
            this.cache.delete(email);
            this.cacheStats.expired++;
            return null;
        }

        return { ...cached.result, fromCache: true };
    }

    setCached(email, result) {
        if (this.cache.size >= this.options.maxCacheSize) {
            // Remover entrada mais antiga
            const firstKey = this.cache.keys().next().value;
            this.cache.delete(firstKey);
        }

        this.cache.set(email, {
            result: result,
            cachedAt: Date.now()
        });
    }

    cleanCache() {
        const now = Date.now();
        let cleaned = 0;

        for (const [email, data] of this.cache.entries()) {
            if (now - data.cachedAt > this.options.cacheExpiry) {
                this.cache.delete(email);
                cleaned++;
            }
        }

        if (cleaned > 0) {
            this.log(`🧹 Cache limpo: ${cleaned} entradas removidas`);
        }
    }

    /**
     * Finaliza o resultado e adiciona ao cache
     */
    finalizeResult(result, startTime) {
        const processingTime = Date.now() - startTime;
        result.processingTime = processingTime;

        // Atualizar estatísticas de tempo
        this.stats.processingTimes.push(processingTime);
        if (this.stats.processingTimes.length > 100) {
            this.stats.processingTimes.shift();
        }
        this.stats.avgProcessingTime = Math.round(
            this.stats.processingTimes.reduce((a, b) => a + b, 0) / this.stats.processingTimes.length
        );

        // Cachear se habilitado
        if (this.options.enableCache) {
            this.setCached(result.normalizedEmail, result);
        }

        return result;
    }

    /**
     * Cria resultado de erro
     */
    createErrorResult(email, errorMessage) {
        return {
            email: email,
            valid: false,
            score: 0,
            error: errorMessage,
            timestamp: new Date().toISOString(),
            recommendations: ['Email inválido ou erro no processamento']
        };
    }

    /**
     * Determina nível de confiança baseado no score
     */
    getConfidenceLevel(score) {
        if (score >= 90) return 'VERY_HIGH';
        if (score >= 75) return 'HIGH';
        if (score >= 60) return 'MODERATE';
        if (score >= 40) return 'LOW';
        return 'VERY_LOW';
    }

    /**
     * Log condicional baseado em debug
     */
    log(message) {
        if (this.options.debug) {
            console.log(`[UltimateValidator] ${message}`);
        }
    }

    /**
     * Retorna estatísticas do validador
     */
    getStatistics() {
        return {
            ...this.stats,
            cache: {
                ...this.cacheStats,
                size: this.cache.size,
                hitRate: this.cacheStats.hits > 0
                    ? ((this.cacheStats.hits / (this.cacheStats.hits + this.cacheStats.misses)) * 100).toFixed(2) + '%'
                    : '0%'
            },
            validationRate: this.stats.totalValidated > 0
                ? ((this.stats.validEmails / this.stats.totalValidated) * 100).toFixed(2) + '%'
                : '0%',
            correctionRate: this.stats.totalValidated > 0
                ? ((this.stats.correctedEmails / this.stats.totalValidated) * 100).toFixed(2) + '%'
                : '0%',
            subValidators: {
                domainCorrector: this.domainCorrector.getStatistics(),
                disposableChecker: this.disposableChecker.getStatistics(),
                patternDetector: this.patternDetector.getStatistics(),
                smtpValidator: this.smtpValidator.getStatistics(),
                tldValidator: this.tldValidator.getStatistics()
            }
        };
    }

    /**
     * Limpa todas as estatísticas
     */
    resetStatistics() {
        this.stats = {
            totalValidated: 0,
            validEmails: 0,
            invalidEmails: 0,
            correctedEmails: 0,
            blockedEmails: 0,
            disposableEmails: 0,
            smtpVerified: 0,
            smtpFailed: 0,
            errors: 0,
            avgProcessingTime: 0,
            processingTimes: []
        };

        this.cacheStats = {
            hits: 0,
            misses: 0,
            expired: 0
        };

        // Resetar estatísticas dos sub-validadores
        this.domainCorrector.reset();
        this.patternDetector.resetStats();

        this.log('📊 Estatísticas resetadas');
    }

    /**
     * Limpa todo o cache
     */
    clearCache() {
        this.cache.clear();
        this.patternDetector.clearCache();
        this.log('🧹 Cache completamente limpo');
    }
}

module.exports = UltimateValidator;
