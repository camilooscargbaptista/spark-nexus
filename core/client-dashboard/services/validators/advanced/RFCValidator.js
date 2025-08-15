// ================================================
// RFC 5321/5322 Email Syntax Validator
// Validação completa de sintaxe segundo padrões RFC
// ================================================

class RFCValidator {
    constructor(options = {}) {
        this.debug = options.debug || false;

        // ================================================
        // RFC 5321/5322 SPECIFICATIONS
        // ================================================
        this.specifications = {
            localPart: {
                minLength: 1,
                maxLength: 64,
                // Caracteres permitidos sem aspas
                allowedChars: /^[a-zA-Z0-9!#$%&'*+\-/=?^_`{|}~.]+$/,
                // Caracteres que requerem aspas
                quotedChars: /^"[^"\\]*"$/,
                // Validações específicas
                consecutiveDots: /\.\./,
                startsWithDot: /^\./,
                endsWithDot: /\.$/
            },
            domain: {
                minLength: 3,
                maxLength: 255,
                // Pattern para domínio válido
                pattern: /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/,
                // Validações específicas
                consecutiveDots: /\.\./,
                startsWithDot: /^\./,
                endsWithDot: /\.$/,
                consecutiveHyphens: /--/,
                startsWithHyphen: /^-/,
                endsWithHyphen: /-$/
            },
            email: {
                maxLength: 320, // RFC 5321
                minLength: 3,
                // Pattern completo RFC 5322
                strictPattern: /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/,
                // Pattern mais permissivo para casos especiais
                relaxedPattern: /^[^@\s]+@[^@\s]+\.[^@\s]+$/
            }
        };

        // ================================================
        // SMTP RESPONSE CODES
        // ================================================
        this.smtpCodes = {
            syntax: {
                '501': 'Syntax error in parameters or arguments',
                '502': 'Command not implemented',
                '503': 'Bad sequence of commands',
                '504': 'Command parameter not implemented',
                '555': 'MAIL FROM/RCPT TO parameters not recognized'
            }
        };

        // Estatísticas
        this.stats = {
            totalValidated: 0,
            validSyntax: 0,
            invalidSyntax: 0,
            errors: {
                localPart: 0,
                domain: 0,
                format: 0,
                length: 0
            }
        };
    }

    // ================================================
    // MÉTODO PRINCIPAL - VALIDAR SINTAXE
    // ================================================
    validateSyntax(email) {
        this.stats.totalValidated++;

        const result = {
            valid: true,
            rfc5321Compliant: true,
            rfc5322Compliant: true,
            errors: [],
            warnings: [],
            details: {
                localPart: null,
                domain: null,
                format: null
            },
            score: 100, // Score de sintaxe (0-100)
            timestamp: new Date().toISOString()
        };

        // Validação básica
        if (!email || typeof email !== 'string') {
            result.valid = false;
            result.errors.push('Email inválido ou vazio');
            result.score = 0;
            this.stats.invalidSyntax++;
            return result;
        }

        email = email.trim().toLowerCase();

        // ================================================
        // 1. VALIDAR COMPRIMENTO TOTAL
        // ================================================
        if (email.length > this.specifications.email.maxLength) {
            result.valid = false;
            result.rfc5321Compliant = false;
            result.errors.push(`Email excede ${this.specifications.email.maxLength} caracteres (RFC 5321)`);
            result.score -= 30;
            this.stats.errors.length++;
        }

        if (email.length < this.specifications.email.minLength) {
            result.valid = false;
            result.errors.push('Email muito curto');
            result.score = 0;
            this.stats.invalidSyntax++;
            return result;
        }

        // ================================================
        // 2. VERIFICAR PRESENÇA DE @
        // ================================================
        const atCount = (email.match(/@/g) || []).length;

        if (atCount === 0) {
            result.valid = false;
            result.errors.push('Email sem @');
            result.score = 0;
            this.stats.errors.format++;
            this.stats.invalidSyntax++;
            return result;
        }

        if (atCount > 1) {
            result.valid = false;
            result.errors.push('Email com múltiplos @');
            result.score = 0;
            this.stats.errors.format++;
            this.stats.invalidSyntax++;
            return result;
        }

        // ================================================
        // 3. SEPARAR LOCAL PART E DOMAIN
        // ================================================
        const [localPart, domain] = email.split('@');

        result.details.localPart = this.validateLocalPart(localPart);
        result.details.domain = this.validateDomain(domain);
        result.details.format = this.validateFormat(email);

        // ================================================
        // 4. VALIDAR LOCAL PART
        // ================================================
        if (!result.details.localPart.valid) {
            result.valid = false;
            result.errors.push(...result.details.localPart.errors);
            result.warnings.push(...result.details.localPart.warnings);
            result.score -= 40;
            this.stats.errors.localPart++;
        }

        // ================================================
        // 5. VALIDAR DOMAIN
        // ================================================
        if (!result.details.domain.valid) {
            result.valid = false;
            result.errors.push(...result.details.domain.errors);
            result.warnings.push(...result.details.domain.warnings);
            result.score -= 40;
            this.stats.errors.domain++;
        }

        // ================================================
        // 6. VALIDAR FORMATO COMPLETO
        // ================================================
        if (!result.details.format.valid) {
            result.valid = false;
            result.rfc5322Compliant = false;
            result.errors.push(...result.details.format.errors);
            result.score -= 20;
            this.stats.errors.format++;
        }

        // ================================================
        // 7. VERIFICAÇÕES ADICIONAIS
        // ================================================

        // Verificar caracteres especiais problemáticos
        const problematicChars = /[\s\(\)\[\]\{\}<>\\,;:'"`]/;
        if (problematicChars.test(email)) {
            result.warnings.push('Email contém caracteres que podem causar problemas');
            result.score -= 5;
        }

        // Verificar se parece email temporário pela estrutura
        if (/^[a-z0-9]{8,}@/.test(email) && !/\.|_|-/.test(localPart)) {
            result.warnings.push('Estrutura suspeita de email temporário');
            result.score -= 10;
        }

        // Finalizar score
        result.score = Math.max(0, result.score);

        // Atualizar estatísticas
        if (result.valid) {
            this.stats.validSyntax++;
        } else {
            this.stats.invalidSyntax++;
        }

        this.logDebug(`Sintaxe validada para ${email}: válido=${result.valid}, score=${result.score}`);

        return result;
    }

    // ================================================
    // VALIDAR LOCAL PART
    // ================================================
    validateLocalPart(localPart) {
        const validation = {
            valid: true,
            errors: [],
            warnings: [],
            details: {}
        };

        if (!localPart) {
            validation.valid = false;
            validation.errors.push('Parte local do email vazia');
            return validation;
        }

        // Verificar comprimento
        if (localPart.length > this.specifications.localPart.maxLength) {
            validation.valid = false;
            validation.errors.push(`Parte local excede ${this.specifications.localPart.maxLength} caracteres`);
        }

        if (localPart.length < this.specifications.localPart.minLength) {
            validation.valid = false;
            validation.errors.push('Parte local muito curta');
        }

        // Verificar dots consecutivos
        if (this.specifications.localPart.consecutiveDots.test(localPart)) {
            validation.valid = false;
            validation.errors.push('Pontos consecutivos não permitidos na parte local');
        }

        // Verificar início com dot
        if (this.specifications.localPart.startsWithDot.test(localPart)) {
            validation.valid = false;
            validation.errors.push('Parte local não pode começar com ponto');
        }

        // Verificar fim com dot
        if (this.specifications.localPart.endsWithDot.test(localPart)) {
            validation.valid = false;
            validation.errors.push('Parte local não pode terminar com ponto');
        }

        // Verificar caracteres permitidos (sem aspas)
        if (!localPart.startsWith('"')) {
            if (!this.specifications.localPart.allowedChars.test(localPart)) {
                validation.valid = false;
                validation.errors.push('Parte local contém caracteres inválidos');
            }
        } else {
            // Verificar formato com aspas
            if (!this.specifications.localPart.quotedChars.test(localPart)) {
                validation.valid = false;
                validation.errors.push('Formato com aspas inválido');
            }
        }

        // Warnings para práticas não recomendadas
        if (localPart.length > 32) {
            validation.warnings.push('Parte local muito longa (>32 caracteres)');
        }

        if (/\d{5,}/.test(localPart)) {
            validation.warnings.push('Muitos números consecutivos');
        }

        return validation;
    }

    // ================================================
    // VALIDAR DOMAIN
    // ================================================
    validateDomain(domain) {
        const validation = {
            valid: true,
            errors: [],
            warnings: [],
            details: {}
        };

        if (!domain) {
            validation.valid = false;
            validation.errors.push('Domínio vazio');
            return validation;
        }

        // Verificar comprimento
        if (domain.length > this.specifications.domain.maxLength) {
            validation.valid = false;
            validation.errors.push(`Domínio excede ${this.specifications.domain.maxLength} caracteres`);
        }

        if (domain.length < this.specifications.domain.minLength) {
            validation.valid = false;
            validation.errors.push('Domínio muito curto');
        }

        // Verificar pattern do domínio
        if (!this.specifications.domain.pattern.test(domain)) {
            validation.valid = false;
            validation.errors.push('Formato de domínio inválido');
        }

        // Verificar dots consecutivos
        if (this.specifications.domain.consecutiveDots.test(domain)) {
            validation.valid = false;
            validation.errors.push('Pontos consecutivos não permitidos no domínio');
        }

        // Verificar hyphens
        const parts = domain.split('.');
        for (const part of parts) {
            if (this.specifications.domain.startsWithHyphen.test(part)) {
                validation.valid = false;
                validation.errors.push('Parte do domínio não pode começar com hífen');
            }
            if (this.specifications.domain.endsWithHyphen.test(part)) {
                validation.valid = false;
                validation.errors.push('Parte do domínio não pode terminar com hífen');
            }
            if (part.length > 63) {
                validation.valid = false;
                validation.errors.push('Parte do domínio excede 63 caracteres');
            }
        }

        // Verificar TLD
        const tld = parts[parts.length - 1];
        if (tld && tld.length < 2) {
            validation.valid = false;
            validation.errors.push('TLD muito curto');
        }

        if (tld && /^\d+$/.test(tld)) {
            validation.valid = false;
            validation.errors.push('TLD não pode ser apenas números');
        }

        // Warnings
        if (parts.length > 4) {
            validation.warnings.push('Muitos subdomínios');
        }

        return validation;
    }

    // ================================================
    // VALIDAR FORMATO COMPLETO
    // ================================================
    validateFormat(email) {
        const validation = {
            valid: true,
            errors: [],
            warnings: []
        };

        // Verificar com pattern strict RFC 5322
        if (!this.specifications.email.strictPattern.test(email)) {
            // Tentar pattern relaxado
            if (!this.specifications.email.relaxedPattern.test(email)) {
                validation.valid = false;
                validation.errors.push('Formato de email inválido (RFC 5322)');
            } else {
                validation.warnings.push('Email válido mas não estritamente RFC 5322 compliant');
            }
        }

        return validation;
    }

    // ================================================
    // MÉTODO PARA SUGERIR CORREÇÃO
    // ================================================
    suggestCorrection(email) {
        const suggestions = [];

        // Remover espaços
        if (/\s/.test(email)) {
            suggestions.push({
                original: email,
                suggested: email.replace(/\s/g, ''),
                issue: 'Espaços removidos'
            });
        }

        // Corrigir múltiplos @
        if ((email.match(/@/g) || []).length > 1) {
            const parts = email.split('@');
            if (parts.length > 2) {
                suggestions.push({
                    original: email,
                    suggested: `${parts[0]}@${parts[parts.length - 1]}`,
                    issue: 'Múltiplos @ corrigidos'
                });
            }
        }

        // Corrigir dots consecutivos
        if (/\.\./.test(email)) {
            suggestions.push({
                original: email,
                suggested: email.replace(/\.+/g, '.'),
                issue: 'Pontos consecutivos corrigidos'
            });
        }

        // Adicionar @ se não tiver
        if (!email.includes('@') && email.includes('.')) {
            const parts = email.split('.');
            if (parts.length >= 2) {
                const possibleEmail = `${parts[0]}@${parts.slice(1).join('.')}`;
                suggestions.push({
                    original: email,
                    suggested: possibleEmail,
                    issue: '@ adicionado'
                });
            }
        }

        return suggestions;
    }

    // ================================================
    // ESTATÍSTICAS
    // ================================================
    getStatistics() {
        return {
            ...this.stats,
            validRate: this.stats.totalValidated > 0
                ? ((this.stats.validSyntax / this.stats.totalValidated) * 100).toFixed(2) + '%'
                : '0%',
            errorDistribution: {
                localPart: this.stats.errors.localPart,
                domain: this.stats.errors.domain,
                format: this.stats.errors.format,
                length: this.stats.errors.length
            }
        };
    }

    resetStatistics() {
        this.stats = {
            totalValidated: 0,
            validSyntax: 0,
            invalidSyntax: 0,
            errors: {
                localPart: 0,
                domain: 0,
                format: 0,
                length: 0
            }
        };
    }

    logDebug(message) {
        if (this.debug) {
            console.log(`[RFCValidator] ${message}`);
        }
    }
}

module.exports = RFCValidator;
