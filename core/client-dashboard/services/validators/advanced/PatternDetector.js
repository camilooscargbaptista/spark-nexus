// ================================================
// Pattern Detector - Detecção de padrões suspeitos
// Integrado com DomainCorrector para correções
// ================================================

const DomainCorrector = require('./DomainCorrector');

class PatternDetector {
    constructor() {
        // Inicializar DomainCorrector
        this.domainCorrector = new DomainCorrector();

        this.stats = {
            totalChecked: 0,
            suspiciousFound: 0,
            correctionsFound: 0,
            patternsDetected: 0
        };

        // Padrões conhecidos de teste
        this.testPatterns = [
            /^test\d*@/i,
            /^teste\d*@/i,
            /^demo\d*@/i,
            /^example\d*@/i,
            /^sample\d*@/i,
            /^user\d*@/i,
            /^email\d*@/i,
            /^mail\d*@/i,
            /^admin\d*@/i,
            /^info\d*@/i,
            /^fake\d*@/i,
            /^temp\d*@/i,
            /^spam\d*@/i,
            /^noreply@/i,
            /^no-reply@/i,
            /^donotreply@/i
        ];

        // Keyboard walks
        this.keyboardWalks = [
            'qwerty', 'asdfgh', 'zxcvbn', 'qwertyuiop',
            'asdfghjkl', 'zxcvbnm', '123456', '12345678',
            '1234567890', 'qweasd', 'qazwsx', 'password',
            'admin123', 'teste123', 'mudar123', 'senha123'
        ];

        // Sequências numéricas e alfabéticas
        this.sequentialPatterns = [
            /\d{5,}/,           // 5+ números seguidos
            /(.)\1{4,}/,        // Caractere repetido 5+ vezes
            /(012|123|234|345|456|567|678|789|890)+/, // Sequências numéricas
            /(abc|bcd|cde|def|efg|fgh|ghi|hij|ijk)/i, // Sequências alfabéticas
            /(987|876|765|654|543|432|321|210)/       // Sequências reversas
        ];

        // Padrões de nomes falsos/genéricos
        this.genericNames = [
            'asdf', 'asdfasdf', 'qwer', 'qwerqwer',
            'zxcv', 'zxcvzxcv', 'aaa', 'aaaa', 'aaaaa',
            'bbb', 'ccc', 'xxx', 'yyy', 'zzz',
            'abc', 'abcd', 'abcde', 'xyz',
            'foo', 'bar', 'baz', 'foobar',
            'blah', 'blahblah', 'whatever',
            'dummy', 'default', 'none', 'null'
        ];

        // Cache de análises
        this.cache = new Map();
    }

    analyzeEmail(email) {
        this.stats.totalChecked++;

        // Verificar cache
        if (this.cache.has(email)) {
            return this.cache.get(email);
        }

        const result = {
            suspicious: false,
            suspicionLevel: 0,      // 0-10
            patterns: [],
            corrections: null,       // Correções do DomainCorrector
            correctedEmail: null,    // Email corrigido se houver
            score: 10,              // Score inicial (10 = perfeito)
            flags: [],              // Flags de problemas encontrados
            recommendations: []      // Recomendações
        };

        // Validação básica
        const emailLower = email.toLowerCase().trim();
        const parts = emailLower.split('@');

        if (parts.length !== 2) {
            result.suspicious = true;
            result.suspicionLevel = 10;
            result.score = 0;
            result.flags.push('INVALID_FORMAT');
            result.recommendations.push('Email em formato inválido');
            this.cache.set(email, result);
            return result;
        }

        const [localPart, domain] = parts;

        // ================================================
        // 1. VERIFICAR CORREÇÕES DE DOMÍNIO
        // ================================================
        const correctionResult = this.domainCorrector.correctEmail(email);

        if (correctionResult.wasCorrected) {
            this.stats.correctionsFound++;
            result.corrections = correctionResult;
            result.correctedEmail = correctionResult.corrected;
            result.suspicionLevel = Math.max(result.suspicionLevel, 3);
            result.score = Math.min(result.score, 7);
            result.flags.push('TYPO_DETECTED');
            result.patterns.push({
                type: 'domain_typo',
                original: correctionResult.correction.from,
                corrected: correctionResult.correction.to,
                confidence: correctionResult.correction.confidence,
                severity: 'medium'
            });
            result.recommendations.push(`Possível erro de digitação detectado. Você quis dizer: ${correctionResult.corrected}?`);
        }

        // ================================================
        // 2. VERIFICAR PADRÕES DE TESTE
        // ================================================
        for (const pattern of this.testPatterns) {
            if (pattern.test(emailLower)) {
                result.suspicious = true;
                result.patterns.push({
                    type: 'test_pattern',
                    pattern: pattern.source,
                    severity: 'critical'
                });
                result.suspicionLevel = Math.max(result.suspicionLevel, 9);
                result.flags.push('TEST_PATTERN');
                this.stats.patternsDetected++;
            }
        }

        // ================================================
        // 3. VERIFICAR KEYBOARD WALKS
        // ================================================
        const localPartLower = localPart.toLowerCase();
        for (const walk of this.keyboardWalks) {
            if (localPartLower.includes(walk)) {
                result.suspicious = true;
                result.patterns.push({
                    type: 'keyboard_walk',
                    pattern: walk,
                    severity: 'high'
                });
                result.suspicionLevel = Math.max(result.suspicionLevel, 8);
                result.flags.push('KEYBOARD_WALK');
                this.stats.patternsDetected++;
                break; // Um keyboard walk já é suficiente
            }
        }

        // ================================================
        // 4. VERIFICAR NOMES GENÉRICOS
        // ================================================
        for (const genericName of this.genericNames) {
            if (localPartLower === genericName || localPartLower.startsWith(genericName)) {
                result.suspicious = true;
                result.patterns.push({
                    type: 'generic_name',
                    pattern: genericName,
                    severity: 'high'
                });
                result.suspicionLevel = Math.max(result.suspicionLevel, 7);
                result.flags.push('GENERIC_NAME');
                this.stats.patternsDetected++;
                break;
            }
        }

        // ================================================
        // 5. VERIFICAR SEQUÊNCIAS
        // ================================================
        for (const pattern of this.sequentialPatterns) {
            if (pattern.test(localPart)) {
                result.suspicious = true;
                result.patterns.push({
                    type: 'sequential_pattern',
                    pattern: pattern.source,
                    severity: 'medium'
                });
                result.suspicionLevel = Math.max(result.suspicionLevel, 6);
                result.flags.push('SEQUENTIAL_PATTERN');
                this.stats.patternsDetected++;
            }
        }

        // ================================================
        // 6. VERIFICAR ALEATORIEDADE
        // ================================================
        if (this.isRandomString(localPart)) {
            result.suspicious = true;
            result.patterns.push({
                type: 'random_string',
                severity: 'medium',
                details: 'Local part appears to be randomly generated'
            });
            result.suspicionLevel = Math.max(result.suspicionLevel, 7);
            result.flags.push('RANDOM_STRING');
            this.stats.patternsDetected++;
        }

        // ================================================
        // 7. VERIFICAR COMPRIMENTO
        // ================================================
        if (localPart.length < 2) {
            result.patterns.push({
                type: 'too_short',
                length: localPart.length,
                severity: 'high'
            });
            result.suspicionLevel = Math.max(result.suspicionLevel, 8);
            result.flags.push('TOO_SHORT');
            result.suspicious = true;
        } else if (localPart.length < 4) {
            result.patterns.push({
                type: 'short_length',
                length: localPart.length,
                severity: 'low'
            });
            result.suspicionLevel = Math.max(result.suspicionLevel, 3);
            result.flags.push('SHORT_LOCAL_PART');
        } else if (localPart.length > 30) {
            result.patterns.push({
                type: 'too_long',
                length: localPart.length,
                severity: 'medium'
            });
            result.suspicionLevel = Math.max(result.suspicionLevel, 5);
            result.flags.push('TOO_LONG');
        }

        // ================================================
        // 8. VERIFICAR CARACTERES ESPECIAIS EXCESSIVOS
        // ================================================
        const specialChars = (localPart.match(/[._\-+]/g) || []).length;
        if (specialChars > 3) {
            result.patterns.push({
                type: 'excessive_special_chars',
                count: specialChars,
                severity: 'low'
            });
            result.suspicionLevel = Math.max(result.suspicionLevel, 4);
            result.flags.push('EXCESSIVE_SPECIAL_CHARS');
        }

        // ================================================
        // 9. VERIFICAR NÚMEROS EXCESSIVOS
        // ================================================
        const numbers = (localPart.match(/\d/g) || []).length;
        const numberRatio = numbers / localPart.length;

        if (numberRatio > 0.6) {
            result.patterns.push({
                type: 'excessive_numbers',
                ratio: Math.round(numberRatio * 100),
                severity: 'medium'
            });
            result.suspicionLevel = Math.max(result.suspicionLevel, 6);
            result.flags.push('EXCESSIVE_NUMBERS');
        }

        // ================================================
        // 10. CALCULAR SCORE FINAL
        // ================================================
        if (result.suspicionLevel >= 9) {
            result.score = 0;  // Email muito suspeito/teste
        } else if (result.suspicionLevel >= 7) {
            result.score = 2;  // Email altamente suspeito
        } else if (result.suspicionLevel >= 5) {
            result.score = 4;  // Email suspeito
        } else if (result.suspicionLevel >= 3) {
            result.score = 6;  // Email duvidoso
        } else if (result.suspicionLevel >= 1) {
            result.score = 8;  // Email levemente suspeito
        } else {
            result.score = 10; // Email aparentemente normal
        }

        // ================================================
        // 11. GERAR RECOMENDAÇÕES FINAIS
        // ================================================
        if (result.suspicious) {
            this.stats.suspiciousFound++;

            if (result.suspicionLevel >= 7) {
                result.recommendations.push('Email altamente suspeito - verificação manual recomendada');
            } else if (result.suspicionLevel >= 5) {
                result.recommendations.push('Email suspeito - considere validação adicional');
            } else {
                result.recommendations.push('Email com padrões incomuns detectados');
            }
        }

        // ================================================
        // 12. ADICIONAR METADADOS
        // ================================================
        result.metadata = {
            localPart: localPart,
            domain: domain,
            localPartLength: localPart.length,
            hasNumbers: /\d/.test(localPart),
            hasSpecialChars: /[._\-+]/.test(localPart),
            isAllLowercase: localPart === localPart.toLowerCase(),
            isAllUppercase: localPart === localPart.toUpperCase(),
            checkTimestamp: new Date().toISOString()
        };

        // Cachear resultado
        this.cache.set(email, result);

        return result;
    }

    isRandomString(str) {
        // Verifica se a string parece aleatória
        if (str.length < 6) return false;

        // 1. Verificar proporção de consoantes/vogais
        const vowels = (str.match(/[aeiou]/gi) || []).length;
        const consonants = (str.match(/[bcdfghjklmnpqrstvwxyz]/gi) || []).length;

        if (vowels === 0 || consonants === 0) return true;

        const ratio = consonants / vowels;

        // Proporção muito desequilibrada indica aleatoriedade
        if (ratio > 5 || ratio < 0.3) {
            return true;
        }

        // 2. Verificar entropia (variedade de caracteres)
        const uniqueChars = new Set(str.toLowerCase()).size;
        const entropy = uniqueChars / str.length;

        // Alta entropia com string longa = provavelmente aleatória
        if (entropy > 0.8 && str.length > 10) {
            return true;
        }

        // 3. Verificar padrões de repetição inexistentes em nomes reais
        // Nomes reais raramente têm mais de 3 consoantes seguidas
        if (/[bcdfghjklmnpqrstvwxyz]{4,}/i.test(str)) {
            return true;
        }

        // 4. Verificar se tem estrutura de nome/palavra
        // Palavras reais geralmente têm vogais distribuídas
        const parts = str.toLowerCase().split(/[aeiou]+/);
        const longConsonantGroups = parts.filter(p => p.length > 3).length;

        if (longConsonantGroups > 1) {
            return true;
        }

        return false;
    }

    getStatistics() {
        return {
            ...this.stats,
            suspiciousRate: this.stats.totalChecked > 0
                ? ((this.stats.suspiciousFound / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            correctionRate: this.stats.totalChecked > 0
                ? ((this.stats.correctionsFound / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            patternRate: this.stats.totalChecked > 0
                ? ((this.stats.patternsDetected / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            cacheSize: this.cache.size
        };
    }

    clearCache() {
        this.cache.clear();
        console.log('✅ PatternDetector cache cleared');
    }

    resetStats() {
        this.stats = {
            totalChecked: 0,
            suspiciousFound: 0,
            correctionsFound: 0,
            patternsDetected: 0
        };
        console.log('✅ PatternDetector stats reset');
    }
}

module.exports = PatternDetector;
