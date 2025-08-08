// ================================================
// Validador de Email Aprimorado
// ================================================

const dns = require('dns').promises;

class EnhancedValidator {
    constructor() {
        // Domínios descartáveis conhecidos
        this.disposableDomains = new Set([
            'tempmail.com', '10minutemail.com', 'guerrillamail.com',
            'mailinator.com', 'throwawaymail.com', 'yopmail.com',
            'tempmail.net', 'trashmail.com', 'fakeinbox.com',
            'temp-mail.org', 'sharklasers.com', 'guerrillamail.info',
            'maildrop.cc', 'mintemail.com', 'throwawayemail.com',
            'fakeemail.com', 'dispostable.com', 'mailnesia.com'
        ]);

        // Cache de resultados
        this.cache = new Map();
        this.cacheTime = 300000; // 5 minutos
    }

    /**
     * Validação completa de email
     */
    async validateEmail(email) {
        const startTime = Date.now();
        
        // Verificar cache
        const cached = this.getFromCache(email);
        if (cached) {
            return { ...cached, fromCache: true };
        }

        // Resultado base
        const result = {
            email: email,
            valid: false,
            score: 0,
            quality: 'poor',
            risk: 'high',
            checks: {
                format: false,
                domain: false,
                mx: false,
                disposable: false,
                roleEmail: false
            },
            details: {
                syntaxValid: false,
                domainExists: false,
                mxRecords: [],
                isDisposable: false,
                isRoleEmail: false
            },
            processingTime: 0
        };

        try {
            // 1. Validação de formato
            const formatCheck = this.validateFormat(email);
            result.checks.format = formatCheck.valid;
            result.details.syntaxValid = formatCheck.valid;
            
            if (!formatCheck.valid) {
                result.reason = formatCheck.reason;
                result.processingTime = Date.now() - startTime;
                this.saveToCache(email, result);
                return result;
            }

            // Parse do email
            const [localPart, domain] = email.toLowerCase().split('@');
            
            // 2. Verificar se é email descartável
            const isDisposable = this.checkDisposable(domain);
            result.checks.disposable = !isDisposable;
            result.details.isDisposable = isDisposable;
            
            // 3. Verificar se é role-based
            const isRoleEmail = this.checkRoleEmail(localPart);
            result.checks.roleEmail = !isRoleEmail;
            result.details.isRoleEmail = isRoleEmail;
            
            // 4. Verificar domínio e MX records
            const domainCheck = await this.checkDomain(domain);
            result.checks.domain = domainCheck.exists;
            result.checks.mx = domainCheck.hasMX;
            result.details.domainExists = domainCheck.exists;
            result.details.mxRecords = domainCheck.mxRecords;
            
            // 5. Calcular score
            let score = 0;
            
            // Pontuação base
            if (result.checks.format) score += 20;
            if (result.checks.domain) score += 25;
            if (result.checks.mx) score += 30;
            if (result.checks.disposable) score += 15;
            if (result.checks.roleEmail) score += 10;
            
            // Penalidades
            if (isDisposable) score -= 30;
            if (isRoleEmail) score -= 10;
            if (!domainCheck.hasMX) score -= 20;
            
            // Bônus para domínios conhecidos
            const trustedDomains = ['gmail.com', 'outlook.com', 'yahoo.com', 'hotmail.com'];
            if (trustedDomains.includes(domain)) {
                score += 15;
            }
            
            // Normalizar score
            score = Math.max(0, Math.min(100, score));
            
            // Determinar qualidade e risco
            result.score = score;
            result.valid = score >= 40 && result.checks.format && result.checks.domain;
            
            if (score >= 80) {
                result.quality = 'excellent';
                result.risk = 'low';
            } else if (score >= 60) {
                result.quality = 'good';
                result.risk = 'medium';
            } else if (score >= 40) {
                result.quality = 'fair';
                result.risk = 'medium';
            } else {
                result.quality = 'poor';
                result.risk = 'high';
            }
            
            result.recommendation = score >= 60 ? 'accept' : score >= 40 ? 'review' : 'reject';
            
        } catch (error) {
            console.error('Erro na validação:', error);
            result.error = error.message;
        }
        
        result.processingTime = Date.now() - startTime;
        
        // Salvar no cache
        this.saveToCache(email, result);
        
        return result;
    }

    /**
     * Validar formato do email
     */
    validateFormat(email) {
        if (!email || typeof email !== 'string') {
            return { valid: false, reason: 'Email inválido ou vazio' };
        }

        // Regex mais rigorosa para validação
        const emailRegex = /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
        
        if (!emailRegex.test(email)) {
            return { valid: false, reason: 'Formato de email inválido' };
        }

        const parts = email.split('@');
        if (parts.length !== 2) {
            return { valid: false, reason: 'Email deve conter exatamente um @' };
        }

        const [local, domain] = parts;

        // Validar parte local
        if (local.length === 0 || local.length > 64) {
            return { valid: false, reason: 'Parte local inválida (máx 64 caracteres)' };
        }

        // Validar domínio
        if (domain.length === 0 || domain.length > 253) {
            return { valid: false, reason: 'Domínio inválido' };
        }

        // Verificar pontos consecutivos
        if (/\.{2,}/.test(email)) {
            return { valid: false, reason: 'Pontos consecutivos não são permitidos' };
        }

        // Não pode começar ou terminar com ponto
        if (local.startsWith('.') || local.endsWith('.')) {
            return { valid: false, reason: 'Email não pode começar ou terminar com ponto' };
        }

        return { valid: true };
    }

    /**
     * Verificar se é domínio descartável
     */
    checkDisposable(domain) {
        return this.disposableDomains.has(domain.toLowerCase());
    }

    /**
     * Verificar se é email role-based
     */
    checkRoleEmail(localPart) {
        const roleEmails = [
            'admin', 'administrator', 'webmaster', 'postmaster',
            'info', 'contact', 'support', 'help', 'sales',
            'marketing', 'noreply', 'no-reply', 'donotreply',
            'notifications', 'alert', 'alerts', 'news',
            'newsletter', 'subscribe', 'unsubscribe'
        ];
        
        return roleEmails.includes(localPart.toLowerCase());
    }

    /**
     * Verificar domínio e MX records
     */
    async checkDomain(domain) {
        const result = {
            exists: false,
            hasMX: false,
            mxRecords: []
        };

        try {
            // Verificar se domínio existe (A records)
            try {
                await dns.resolve4(domain);
                result.exists = true;
            } catch {
                // Tentar IPv6
                try {
                    await dns.resolve6(domain);
                    result.exists = true;
                } catch {
                    result.exists = false;
                }
            }

            // Verificar MX records
            try {
                const mxRecords = await dns.resolveMx(domain);
                if (mxRecords && mxRecords.length > 0) {
                    result.hasMX = true;
                    result.mxRecords = mxRecords
                        .sort((a, b) => a.priority - b.priority)
                        .map(mx => ({
                            exchange: mx.exchange,
                            priority: mx.priority
                        }));
                }
            } catch {
                result.hasMX = false;
            }

        } catch (error) {
            console.error('Erro ao verificar domínio:', error);
        }

        return result;
    }

    /**
     * Cache simples
     */
    getFromCache(email) {
        const cached = this.cache.get(email.toLowerCase());
        if (cached && Date.now() - cached.timestamp < this.cacheTime) {
            return cached.data;
        }
        this.cache.delete(email.toLowerCase());
        return null;
    }

    saveToCache(email, data) {
        this.cache.set(email.toLowerCase(), {
            data: data,
            timestamp: Date.now()
        });
        
        // Limpar cache se muito grande
        if (this.cache.size > 1000) {
            const firstKey = this.cache.keys().next().value;
            this.cache.delete(firstKey);
        }
    }

    /**
     * Validação em lote
     */
    async validateBatch(emails) {
        const results = [];
        for (const email of emails) {
            const result = await this.validateEmail(email);
            results.push(result);
        }
        return results;
    }
}

module.exports = EnhancedValidator;
