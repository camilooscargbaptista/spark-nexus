// ================================================
// Enhanced Email Validator v2.0
// Com TLD Scoring e Cache Persistente
// ================================================

const dns = require('dns').promises;
const emailValidator = require('email-validator');
const punycode = require('punycode/');
const { getDomain } = require('tldts');
const CacheService = require('./services/cache/CacheService');
const TLDAnalyzer = require('./services/validators/tldAnalyzer');

class EnhancedValidator {
    constructor() {
        // Inicializar serviços
        this.cache = new CacheService({
            memoryMaxSize: 1000,
            memoryTTL: 600,      // 10 minutos em memória
            redisTTL: 86400,     // 24 horas no Redis
            enableRedis: true
        });
        
        this.tldAnalyzer = new TLDAnalyzer();
        
        // Lista expandida de emails descartáveis
        this.disposablePatterns = [
            'tempmail', '10minute', 'guerrilla', 'mailinator', 
            'throwaway', 'temp-mail', 'minute', 'mail', 
            'fake', 'trash', 'disposable', 'temporary'
        ];
        
        // Domínios descartáveis conhecidos
        this.disposableDomains = new Set([
            'tempmail.com', 'throwaway.email', '10minutemail.com',
            'guerrillamail.com', 'mailinator.com', 'temp-mail.org',
            'yopmail.com', 'getairmail.com', 'emailondeck.com',
            'maildrop.cc', 'mintemail.com', 'throwemail.com',
            'tmpmail.net', 'fakeinbox.com', 'sneakemail.com',
            'emailsensei.com', 'spamgourmet.com', 'trashmail.net'
        ]);
        
        // Role-based prefixes
        this.roleBasedPrefixes = [
            'admin', 'info', 'contact', 'support', 'sales',
            'help', 'webmaster', 'postmaster', 'noreply',
            'no-reply', 'donotreply', 'abuse', 'spam',
            'marketing', 'team', 'billing', 'legal', 'hr'
        ];
        
        // Estatísticas
        this.stats = {
            totalValidations: 0,
            cacheHits: 0,
            avgResponseTime: 0
        };
    }

    // ================================================
    // Método principal de validação
    // ================================================
    async validateEmail(email, options = {}) {
        const startTime = Date.now();
        this.stats.totalValidations++;
        
        if (!email) {
            return this.createResponse(false, 0, 'Email não fornecido');
        }
        
        const normalizedEmail = email.toLowerCase().trim();
        
        // Verificar cache primeiro
        const cached = await this.cache.getEmailValidation(normalizedEmail);
        if (cached && !options.forceRefresh) {
            this.stats.cacheHits++;
            cached.fromCache = true;
            this.updateResponseTime(Date.now() - startTime);
            return cached;
        }
        
        // Executar validações
        const result = await this.performValidation(normalizedEmail, options);
        
        // Salvar no cache
        const cacheTTL = result.score >= 70 ? 86400 : 3600; // 24h para bons, 1h para ruins
        await this.cache.setEmailValidation(normalizedEmail, result, cacheTTL);
        
        this.updateResponseTime(Date.now() - startTime);
        return result;
    }

    async performValidation(email, options) {
        const validations = {
            format: this.validateFormat(email),
            syntax: this.validateSyntax(email),
            domain: await this.validateDomain(email),
            mx: await this.validateMX(email),
            disposable: this.checkDisposable(email),
            roleBased: this.checkRoleBased(email),
            tld: this.validateTLD(email)
        };
        
        // Calcular score com breakdown detalhado
        const scoreBreakdown = this.calculateScoreBreakdown(validations);
        const finalScore = scoreBreakdown.total;
        
        // Determinar se é válido baseado no score
        const isValid = finalScore >= 40;
        
        return {
            email,
            valid: isValid,
            score: finalScore,
            breakdown: scoreBreakdown,
            validations,
            recommendation: this.getRecommendation(finalScore, validations),
            timestamp: new Date().toISOString()
        };
    }

    // ================================================
    // Validações individuais
    // ================================================
    
    validateFormat(email) {
        return {
            valid: emailValidator.validate(email),
            check: 'format',
            weight: 10
        };
    }
    
    validateSyntax(email) {
        const result = { check: 'syntax', weight: 15 };
        
        // RFC 5322 compliant regex
        const rfc5322 = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
        
        result.valid = rfc5322.test(email);
        
        // Verificações adicionais
        const [local, domain] = email.split('@');
        
        if (local) {
            result.localPart = {
                length: local.length,
                valid: local.length >= 1 && local.length <= 64,
                hasInvalidChars: /[<>()[\]\\,;:\s]/.test(local),
                startsWithDot: local[0] === '.',
                endsWithDot: local[local.length - 1] === '.',
                hasConsecutiveDots: /\.\./.test(local)
            };
            
            result.valid = result.valid && 
                          result.localPart.valid && 
                          !result.localPart.hasInvalidChars &&
                          !result.localPart.startsWithDot &&
                          !result.localPart.endsWithDot &&
                          !result.localPart.hasConsecutiveDots;
        }
        
        return result;
    }
    
    async validateDomain(email) {
        const result = { check: 'domain', weight: 20 };
        const domain = email.split('@')[1];
        
        if (!domain) {
            result.valid = false;
            result.error = 'Domínio não encontrado';
            return result;
        }
        
        try {
            // Verificar se domínio já está no cache
            const cachedDomain = await this.cache.getDomainValidation(domain);
            if (cachedDomain) {
                return { ...result, ...cachedDomain, fromCache: true };
            }
            
            // Converter IDN para ASCII
            const asciiDomain = punycode.toASCII(domain);
            
            // Validar formato do domínio
            const domainRegex = /^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/i;
            result.valid = domainRegex.test(asciiDomain);
            result.ascii = asciiDomain;
            result.unicode = domain;
            
            // Analisar TLD
            const tldAnalysis = this.tldAnalyzer.analyzeDomain(domain);
            result.tldAnalysis = tldAnalysis;
            
            // Cache resultado do domínio
            await this.cache.setDomainValidation(domain, result, 7200);
            
        } catch (error) {
            result.valid = false;
            result.error = error.message;
        }
        
        return result;
    }
    
    async validateMX(email) {
        const result = { check: 'mx', weight: 25 };
        const domain = email.split('@')[1];
        
        if (!domain) {
            result.valid = false;
            return result;
        }
        
        try {
            const mxRecords = await dns.resolveMx(domain);
            result.valid = mxRecords && mxRecords.length > 0;
            result.records = mxRecords.sort((a, b) => a.priority - b.priority);
            result.count = mxRecords.length;
            
            // Verificar qualidade dos MX records
            if (result.valid) {
                result.quality = this.assessMXQuality(mxRecords, domain);
            }
        } catch (error) {
            result.valid = false;
            result.error = error.code;
            
            // NODATA significa que o domínio existe mas não tem MX
            if (error.code === 'ENODATA') {
                result.description = 'Domínio existe mas não tem registros MX';
            } else if (error.code === 'ENOTFOUND') {
                result.description = 'Domínio não encontrado';
            }
        }
        
        return result;
    }
    
    checkDisposable(email) {
        const result = { check: 'disposable', weight: -20 };
        const domain = email.split('@')[1];
        const local = email.split('@')[0];
        
        if (!domain) {
            result.isDisposable = false;
            return result;
        }
        
        // Verificar domínio na lista
        result.isDisposable = this.disposableDomains.has(domain);
        
        // Verificar padrões no domínio
        if (!result.isDisposable) {
            for (const pattern of this.disposablePatterns) {
                if (domain.includes(pattern) || local.includes(pattern)) {
                    result.isDisposable = true;
                    result.pattern = pattern;
                    break;
                }
            }
        }
        
        result.valid = !result.isDisposable;
        
        return result;
    }
    
    checkRoleBased(email) {
        const result = { check: 'roleBased', weight: -10 };
        const local = email.split('@')[0].toLowerCase();
        
        result.isRoleBased = this.roleBasedPrefixes.some(prefix => 
            local === prefix || local.startsWith(prefix + '.') || local.startsWith(prefix + '-')
        );
        
        if (result.isRoleBased) {
            result.role = this.roleBasedPrefixes.find(prefix => 
                local === prefix || local.startsWith(prefix)
            );
        }
        
        result.valid = !result.isRoleBased;
        
        return result;
    }
    
    validateTLD(email) {
        const result = { check: 'tld', weight: 20 };
        const domain = email.split('@')[1];
        
        if (!domain) {
            result.valid = false;
            return result;
        }
        
        // Usar TLD Analyzer
        const analysis = this.tldAnalyzer.analyzeDomain(domain);
        
        result.valid = analysis.finalScore >= 3;
        result.analysis = analysis;
        result.score = analysis.finalScore;
        result.trust = analysis.factors.tldTrust;
        
        return result;
    }
    
    // ================================================
    // Cálculo de Score
    // ================================================
    
    calculateScoreBreakdown(validations) {
        const breakdown = {
            components: {},
            penalties: [],
            bonuses: [],
            total: 0
        };
        
        let baseScore = 0;
        
        // Processar cada validação
        for (const [key, validation] of Object.entries(validations)) {
            if (!validation) continue;
            
            const points = validation.valid ? Math.abs(validation.weight) : 0;
            
            breakdown.components[key] = {
                passed: validation.valid,
                weight: validation.weight,
                points: points,
                details: validation
            };
            
            baseScore += points;
            
            // Adicionar penalidades específicas
            if (key === 'disposable' && validation.isDisposable) {
                breakdown.penalties.push({
                    reason: 'Email descartável/temporário',
                    impact: -20
                });
            }
            
            if (key === 'roleBased' && validation.isRoleBased) {
                breakdown.penalties.push({
                    reason: `Email role-based (${validation.role})`,
                    impact: -10
                });
            }
            
            if (key === 'tld' && validation.analysis) {
                const tldScore = validation.analysis.finalScore;
                if (tldScore <= 2) {
                    breakdown.penalties.push({
                        reason: 'TLD suspeito ou não confiável',
                        impact: -15
                    });
                } else if (tldScore >= 8) {
                    breakdown.bonuses.push({
                        reason: 'TLD premium ou institucional',
                        impact: 10
                    });
                }
            }
        }
        
        // Aplicar bônus para MX de qualidade
        if (validations.mx?.quality?.score >= 8) {
            breakdown.bonuses.push({
                reason: 'Servidor de email corporativo reconhecido',
                impact: 5
            });
        }
        
        // Calcular score final
        let finalScore = baseScore;
        
        breakdown.penalties.forEach(p => {
            finalScore += p.impact;
        });
        
        breakdown.bonuses.forEach(b => {
            finalScore += b.impact;
        });
        
        // Garantir que o score fique entre 0 e 100
        breakdown.total = Math.max(0, Math.min(100, finalScore));
        
        return breakdown;
    }
    
    assessMXQuality(mxRecords, domain) {
        const quality = {
            score: 5,
            factors: []
        };
        
        // Verificar se usa serviços conhecidos
        const knownProviders = {
            'google.com': { name: 'Google Workspace', score: 9 },
            'googlemail.com': { name: 'Gmail', score: 8 },
            'outlook.com': { name: 'Outlook', score: 8 },
            'microsoft.com': { name: 'Microsoft', score: 9 },
            'amazonses.com': { name: 'Amazon SES', score: 7 },
            'sendgrid.net': { name: 'SendGrid', score: 7 }
        };
        
        for (const mx of mxRecords) {
            for (const [provider, info] of Object.entries(knownProviders)) {
                if (mx.exchange.includes(provider)) {
                    quality.score = Math.max(quality.score, info.score);
                    quality.factors.push(`Usa ${info.name}`);
                    quality.provider = info.name;
                    break;
                }
            }
        }
        
        // Verificar se MX aponta para o próprio domínio
        if (mxRecords.some(mx => mx.exchange.includes(domain))) {
            quality.factors.push('MX próprio do domínio');
            quality.score = Math.max(quality.score, 6);
        }
        
        // Múltiplos MX records (redundância)
        if (mxRecords.length > 1) {
            quality.factors.push(`${mxRecords.length} servidores MX (redundância)`);
            quality.score = Math.min(quality.score + 1, 10);
        }
        
        return quality;
    }
    
    // ================================================
    // Métodos auxiliares
    // ================================================
    
    getRecommendation(score, validations) {
        if (score >= 80) {
            return {
                status: 'excellent',
                message: 'Email altamente confiável',
                action: 'safe_to_use'
            };
        } else if (score >= 60) {
            return {
                status: 'good',
                message: 'Email válido e confiável',
                action: 'safe_to_use'
            };
        } else if (score >= 40) {
            return {
                status: 'acceptable',
                message: 'Email válido mas com ressalvas',
                action: 'use_with_caution'
            };
        } else if (score >= 20) {
            return {
                status: 'poor',
                message: 'Email suspeito ou problemático',
                action: 'verification_recommended'
            };
        } else {
            return {
                status: 'invalid',
                message: 'Email inválido ou não confiável',
                action: 'do_not_use'
            };
        }
    }
    
    createResponse(valid, score, reason) {
        return {
            valid,
            score,
            reason,
            timestamp: new Date().toISOString()
        };
    }
    
    updateResponseTime(time) {
        const alpha = 0.1; // Fator de suavização
        this.stats.avgResponseTime = this.stats.avgResponseTime * (1 - alpha) + time * alpha;
    }
    
    // ================================================
    // Validação em lote
    // ================================================
    async validateBatch(emails, options = {}) {
        const results = [];
        const batchSize = options.batchSize || 10;
        
        for (let i = 0; i < emails.length; i += batchSize) {
            const batch = emails.slice(i, i + batchSize);
            const promises = batch.map(email => this.validateEmail(email, options));
            const batchResults = await Promise.all(promises);
            results.push(...batchResults);
        }
        
        return results;
    }
    
    // ================================================
    // Estatísticas e manutenção
    // ================================================
    
    async getStatistics() {
        const cacheStats = await this.cache.getStatistics();
        const tldStats = this.tldAnalyzer.getStatistics();
        
        return {
            validator: {
                ...this.stats,
                cacheHitRate: this.stats.totalValidations > 0
                    ? ((this.stats.cacheHits / this.stats.totalValidations) * 100).toFixed(2) + '%'
                    : '0%',
                avgResponseTimeMs: Math.round(this.stats.avgResponseTime)
            },
            cache: cacheStats,
            tld: tldStats
        };
    }
    
    async clearCache() {
        await this.cache.clear();
        this.tldAnalyzer.clearCache();
        console.log('✅ Todos os caches limpos');
    }
    
    async shutdown() {
        await this.cache.shutdown();
        console.log('Enhanced Validator encerrado');
    }
}

module.exports = EnhancedValidator;
