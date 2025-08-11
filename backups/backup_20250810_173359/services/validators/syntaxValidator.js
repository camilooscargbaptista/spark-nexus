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
