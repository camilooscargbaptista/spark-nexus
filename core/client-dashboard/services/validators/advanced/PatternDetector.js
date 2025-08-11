// ================================================
// Pattern Detector - Detecção de padrões suspeitos
// ================================================

const levenshtein = require('levenshtein');

class PatternDetector {
    constructor() {
        this.stats = {
            totalChecked: 0,
            suspiciousFound: 0,
            corrections: 0
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
            /^info\d*@/i
        ];
        
        // Keyboard walks
        this.keyboardWalks = [
            'qwerty', 'asdfgh', 'zxcvbn', 'qwertyuiop',
            'asdfghjkl', 'zxcvbnm', '123456', '12345678',
            'qweasd', 'qazwsx', 'password', 'admin123'
        ];
        
        // Sequências numéricas
        this.sequentialPatterns = [
            /\d{4,}/, // 4+ números seguidos
            /(.)\1{3,}/, // Caractere repetido 4+ vezes
            /(012|123|234|345|456|567|678|789)/, // Sequências
            /(abc|bcd|cde|def|efg|fgh)/i // Sequências alfabéticas
        ];
        
        // Domínios populares para correção
        this.popularDomains = [
            'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com',
            'icloud.com', 'aol.com', 'live.com', 'msn.com',
            'yahoo.com.br', 'hotmail.com.br', 'outlook.com.br',
            'gmail.com.br', 'uol.com.br', 'bol.com.br', 'terra.com.br'
        ];
    }

    analyzeEmail(email) {
        this.stats.totalChecked++;
        
        const result = {
            suspicious: false,
            suspicionLevel: 0, // 0-10
            patterns: [],
            suggestions: [],
            score: 10 // Score inicial
        };
        
        const [localPart, domain] = email.toLowerCase().split('@');
        
        if (!localPart || !domain) {
            result.suspicious = true;
            result.suspicionLevel = 10;
            result.score = 0;
            return result;
        }
        
        // Verificar padrões de teste
        for (const pattern of this.testPatterns) {
            if (pattern.test(email)) {
                result.suspicious = true;
                result.patterns.push({
                    type: 'test_pattern',
                    pattern: pattern.source,
                    severity: 'high'
                });
                result.suspicionLevel = Math.max(result.suspicionLevel, 8);
            }
        }
        
        // Verificar keyboard walks
        for (const walk of this.keyboardWalks) {
            if (localPart.includes(walk)) {
                result.suspicious = true;
                result.patterns.push({
                    type: 'keyboard_walk',
                    pattern: walk,
                    severity: 'high'
                });
                result.suspicionLevel = Math.max(result.suspicionLevel, 9);
            }
        }
        
        // Verificar sequências
        for (const pattern of this.sequentialPatterns) {
            if (pattern.test(localPart)) {
                result.suspicious = true;
                result.patterns.push({
                    type: 'sequential',
                    pattern: pattern.source,
                    severity: 'medium'
                });
                result.suspicionLevel = Math.max(result.suspicionLevel, 6);
            }
        }
        
        // Verificar caracteres aleatórios excessivos
        if (this.isRandomString(localPart)) {
            result.suspicious = true;
            result.patterns.push({
                type: 'random_string',
                severity: 'medium'
            });
            result.suspicionLevel = Math.max(result.suspicionLevel, 7);
        }
        
        // Verificar comprimento suspeito
        if (localPart.length < 3 || localPart.length > 30) {
            result.patterns.push({
                type: 'unusual_length',
                length: localPart.length,
                severity: 'low'
            });
            result.suspicionLevel = Math.max(result.suspicionLevel, 4);
        }
        
        // Sugerir correções para typos comuns
        const suggestions = this.suggestCorrections(domain);
        if (suggestions.length > 0) {
            result.suggestions = suggestions;
            this.stats.corrections++;
            result.suspicionLevel = Math.max(result.suspicionLevel, 5);
        }
        
        // Calcular score final
        if (result.suspicionLevel >= 8) {
            result.score = 0; // Muito suspeito
        } else if (result.suspicionLevel >= 6) {
            result.score = 3; // Suspeito
        } else if (result.suspicionLevel >= 4) {
            result.score = 6; // Duvidoso
        } else if (result.suspicionLevel >= 2) {
            result.score = 8; // Levemente suspeito
        }
        
        if (result.suspicious) {
            this.stats.suspiciousFound++;
        }
        
        return result;
    }
    
    isRandomString(str) {
        // Verifica se parece uma string aleatória
        const consonants = str.replace(/[aeiou]/gi, '').length;
        const vowels = str.replace(/[^aeiou]/gi, '').length;
        const ratio = consonants / (vowels || 1);
        
        // String aleatória geralmente tem proporção estranha
        if (ratio > 4 || ratio < 0.5) {
            return true;
        }
        
        // Verificar entropia (variação de caracteres)
        const uniqueChars = new Set(str).size;
        const entropy = uniqueChars / str.length;
        
        // Alta entropia = mais aleatório
        return entropy > 0.8 && str.length > 10;
    }
    
    suggestCorrections(domain) {
        const suggestions = [];
        
        for (const popularDomain of this.popularDomains) {
            const distance = new levenshtein(domain, popularDomain).distance;
            
            // Se a distância é pequena (1-2 caracteres), é provável typo
            if (distance === 1) {
                suggestions.push({
                    original: domain,
                    suggestion: popularDomain,
                    confidence: 'high',
                    distance: distance
                });
            } else if (distance === 2) {
                suggestions.push({
                    original: domain,
                    suggestion: popularDomain,
                    confidence: 'medium',
                    distance: distance
                });
            }
        }
        
        // Ordenar por confiança
        return suggestions.sort((a, b) => a.distance - b.distance).slice(0, 3);
    }
    
    getStatistics() {
        return {
            ...this.stats,
            suspiciousRate: this.stats.totalChecked > 0
                ? ((this.stats.suspiciousFound / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            correctionRate: this.stats.totalChecked > 0
                ? ((this.stats.corrections / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%'
        };
    }
}

module.exports = PatternDetector;
