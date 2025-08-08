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
