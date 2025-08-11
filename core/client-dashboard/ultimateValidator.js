// ================================================
// ULTIMATE EMAIL VALIDATOR v3.0
// Sistema completo de validação profissional
// ================================================

const dns = require('dns').promises;
const emailValidator = require('email-validator');
const validator = require('validator');

// Importar todos os validadores avançados
const TLDValidator = require('./services/validators/advanced/TLDValidator');
const DisposableChecker = require('./services/validators/advanced/DisposableChecker');
const SMTPValidator = require('./services/validators/advanced/SMTPValidator');
const PatternDetector = require('./services/validators/advanced/PatternDetector');
const EcommerceScoring = require('./services/validators/advanced/EcommerceScoring');
const CacheService = require('./services/cache/CacheService');

class UltimateValidator {
    constructor(options = {}) {
        // Configurações
        this.config = {
            enableSMTP: options.enableSMTP !== false,
            smtpTimeout: options.smtpTimeout || 5000,
            enableCache: options.enableCache !== false,
            cacheTTL: options.cacheTTL || 3600,
            parallel: options.parallel || 5,
            scoreThreshold: options.scoreThreshold || 40
        };

        // Inicializar validadores
        this.validators = {
            tld: new TLDValidator(),
            disposable: new DisposableChecker(),
            smtp: this.config.enableSMTP ? new SMTPValidator() : null,
            patterns: new PatternDetector(),
            scoring: new EcommerceScoring()
        };

        // Cache
        this.cache = this.config.enableCache ? new CacheService({
            memoryMaxSize: 5000,
            memoryTTL: 300,
            redisTTL: this.config.cacheTTL
        }) : null;

        // Estatísticas
        this.stats = {
            totalValidations: 0,
            validEmails: 0,
            invalidEmails: 0,
            avgScore: 0,
            avgResponseTime: 0,
            cacheHits: 0
        };

        console.log('🚀 Ultimate Validator v3.0 initialized');
        console.log(`   ✅ TLD Validator: Active`);
        console.log(`   ✅ Disposable Checker: Active`);
        console.log(`   ${this.config.enableSMTP ? '✅' : '❌'} SMTP Validator: ${this.config.enableSMTP ? 'Active' : 'Disabled'}`);
        console.log(`   ✅ Pattern Detector: Active`);
        console.log(`   ✅ E-commerce Scoring: Active`);
        console.log(`   ${this.config.enableCache ? '✅' : '❌'} Cache: ${this.config.enableCache ? 'Active' : 'Disabled'}`);
    }

    async validateEmail(email, options = {}) {
        const startTime = Date.now();
        this.stats.totalValidations++;

        // Normalizar email
        const normalizedEmail = email.toLowerCase().trim();

        // Verificar cache
        if (this.cache && !options.skipCache) {
            const cached = await this.cache.get(`email:${normalizedEmail}`);
            if (cached) {
                this.stats.cacheHits++;
                cached.fromCache = true;
                this.updateStats(cached, Date.now() - startTime);
                return cached;
            }
        }

        // Estrutura do resultado
        const result = {
            email: normalizedEmail,
            valid: false,
            score: 0,
            validations: {},
            ecommerce: {},
            recommendations: [],
            metadata: {
                timestamp: new Date().toISOString(),
                processingTime: 0,
                validatorVersion: '3.0.0'
            }
        };

        try {
            // ========== VALIDAÇÕES BÁSICAS ==========

            // 1. Formato básico
            result.validations.format = {
                valid: emailValidator.validate(normalizedEmail),
                check: 'email-validator'
            };

            if (!result.validations.format.valid) {
                result.valid = false;
                result.score = 0;
                result.metadata.processingTime = Date.now() - startTime;
                return result;
            }

            // 2. Validação com validator.js
            result.validations.syntax = {
                valid: validator.isEmail(normalizedEmail, {
                    allow_display_name: false,
                    require_display_name: false,
                    allow_utf8_local_part: true,
                    require_tld: true,
                    allow_ip_domain: false,
                    domain_specific_validation: true
                }),
                check: 'validator.js'
            };

            const [localPart, domain] = normalizedEmail.split('@');

            // ========== VALIDAÇÕES AVANÇADAS ==========

            // 3. Validação de TLD
            result.validations.tld = this.validators.tld.validateTLD(domain);

            // Se TLD está bloqueado, parar aqui
            if (result.validations.tld.isBlocked) {
                result.valid = false;
                result.score = 0;
                result.ecommerce = {
                    buyerType: 'BLOCKED',
                    riskLevel: 'BLOCKED',
                    fraudProbability: 100,
                    message: 'TLD is blocked for testing/invalid use'
                };
                result.metadata.processingTime = Date.now() - startTime;
                await this.saveToCache(normalizedEmail, result);
                return result;
            }

            // 4. Verificação de disposable
            result.validations.disposable = this.validators.disposable.checkEmail(normalizedEmail);

            // 5. Detecção de padrões
            result.validations.patterns = this.validators.patterns.analyzeEmail(normalizedEmail);

            // 6. Verificação DNS/MX
            try {
                const mxRecords = await dns.resolveMx(domain);
                result.validations.mx = {
                    valid: mxRecords && mxRecords.length > 0,
                    records: mxRecords.length,
                    priority: mxRecords[0]?.priority
                };
            } catch (error) {
                result.validations.mx = {
                    valid: false,
                    error: error.code
                };
            }

            // 7. Verificação SMTP (opcional)
            if (this.config.enableSMTP && result.validations.mx.valid) {
                try {
                    result.validations.smtp = await this.validators.smtp.validateEmail(normalizedEmail);
                } catch (error) {
                    result.validations.smtp = {
                        valid: false,
                        error: 'SMTP check failed',
                        message: error.message
                    };
                }
            }

            // ========== SCORING E-COMMERCE ==========

            result.validations.email = normalizedEmail;

            const scoringResult = this.validators.scoring.calculateScore(result.validations);
            result.score = scoringResult.finalScore;
            result.ecommerce = {
                score: scoringResult.finalScore,
                buyerType: scoringResult.buyerType,
                riskLevel: scoringResult.riskLevel,
                fraudProbability: scoringResult.fraudProbability,
                confidence: scoringResult.confidence,
                breakdown: scoringResult.breakdown,
                insights: scoringResult.insights
            };
            result.recommendations = scoringResult.recommendations;

            // Determinar validade final
            result.valid = result.score >= this.config.scoreThreshold;

            // ========== METADADOS FINAIS ==========

            result.metadata.processingTime = Date.now() - startTime;
            result.metadata.checks = {
                format: result.validations.format.valid,
                syntax: result.validations.syntax.valid,
                tld: result.validations.tld.valid,
                mx: result.validations.mx.valid,
                disposable: !result.validations.disposable.isDisposable,
                patterns: !result.validations.patterns.suspicious,
                smtp: result.validations.smtp ? result.validations.smtp.valid : null
            };

            // Salvar no cache
            await this.saveToCache(normalizedEmail, result);

            // Atualizar estatísticas
            this.updateStats(result, result.metadata.processingTime);

        } catch (error) {
            console.error('❌ Erro na validação:', error);
            result.valid = false;
            result.score = 0;
            result.error = error.message;
            result.metadata.processingTime = Date.now() - startTime;
        }

        return result;
    }

    async validateBatch(emails, options = {}) {
        const results = [];
        const batchSize = options.batchSize || this.config.parallel;

        console.log(`📧 Validando lote de ${emails.length} emails...`);

        for (let i = 0; i < emails.length; i += batchSize) {
            const batch = emails.slice(i, i + batchSize);
            const promises = batch.map(email => this.validateEmail(email, options));
            const batchResults = await Promise.all(promises);
            results.push(...batchResults);

            // Log de progresso
            const progress = Math.min(i + batchSize, emails.length);
            console.log(`   Progresso: ${progress}/${emails.length} (${((progress/emails.length)*100).toFixed(1)}%)`);
        }

        return results;
    }

    async saveToCache(email, result) {
        if (!this.cache) return;

        try {
            // Cache por tempo baseado no score
            const ttl = result.score >= 70 ? 86400 : result.score >= 40 ? 7200 : 3600;
            await this.cache.set(`email:${email}`, result, ttl);
        } catch (error) {
            console.error('Erro ao salvar no cache:', error);
        }
    }

    updateStats(result, processingTime) {
        if (result.valid) {
            this.stats.validEmails++;
        } else {
            this.stats.invalidEmails++;
        }

        // Média móvel do score
        const alpha = 0.1;
        this.stats.avgScore = this.stats.avgScore * (1 - alpha) + result.score * alpha;

        // Média móvel do tempo de resposta
        this.stats.avgResponseTime = this.stats.avgResponseTime * (1 - alpha) + processingTime * alpha;
    }

    getStatistics() {
        return {
            total: this.stats.totalValidations,
            valid: this.stats.validEmails,
            invalid: this.stats.invalidEmails,
            validRate: this.stats.totalValidations > 0
                ? ((this.stats.validEmails / this.stats.totalValidations) * 100).toFixed(2) + '%'
                : '0%',
            avgScore: this.stats.avgScore.toFixed(1),
            avgResponseTime: this.stats.avgResponseTime.toFixed(0) + 'ms',
            cacheHitRate: this.stats.totalValidations > 0
                ? ((this.stats.cacheHits / this.stats.totalValidations) * 100).toFixed(2) + '%'
                : '0%',
            validators: {
                tld: this.validators.tld.getStatistics(),
                disposable: this.validators.disposable.getStatistics(),
                patterns: this.validators.patterns.getStatistics(),
                smtp: this.validators.smtp ? this.validators.smtp.getStatistics() : null
            }
        };
    }

    async clearCache() {
        if (this.cache) {
            await this.cache.clear();
            console.log('✅ Cache limpo');
        }
    }

    async shutdown() {
        if (this.cache) {
            await this.cache.shutdown();
        }
        console.log('Ultimate Validator encerrado');
    }
}

module.exports = UltimateValidator;
