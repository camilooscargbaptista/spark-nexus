// services/validators/advanced/DomainCorrector.js

/**
 * DomainCorrector - Correção automática de typos em domínios de email
 * Detecta e corrige erros comuns de digitação em domínios populares
 *
 * @class DomainCorrector
 * @author Spark Nexus Team
 * @version 1.0.0
 */
class DomainCorrector {
    constructor() {
        // Mapeamento direto de erros comuns
        this.commonMistakes = {
            // Gmail variations
            'gmai.com': 'gmail.com',
            'gmial.com': 'gmail.com',
            'gmil.com': 'gmail.com',
            'gmaill.com': 'gmail.com',
            'gmal.com': 'gmail.com',
            'gmeil.com': 'gmail.com',
            'gmaol.com': 'gmail.com',
            'gnail.com': 'gmail.com',
            'gmail.co': 'gmail.com',
            'gmail.cm': 'gmail.com',
            'gmail.con': 'gmail.com',
            'gmail.com.br': 'gmail.com',
            'gemail.com': 'gmail.com',

            // Hotmail variations
            'hotmial.com': 'hotmail.com',
            'hotmal.com': 'hotmail.com',
            'hotmil.com': 'hotmail.com',
            'hotmaill.com': 'hotmail.com',
            'hotmeil.com': 'hotmail.com',
            'hotmai.com': 'hotmail.com',
            'hotmael.com': 'hotmail.com',
            'hotmail.co': 'hotmail.com',
            'hotmail.con': 'hotmail.com',
            'hotmail.cm': 'hotmail.com',

            // Outlook variations
            'outlok.com': 'outlook.com',
            'outloook.com': 'outlook.com',
            'outlook.co': 'outlook.com',
            'outlook.con': 'outlook.com',
            'outlook.cm': 'outlook.com',
            'outllok.com': 'outlook.com',
            'outlokk.com': 'outlook.com',
            'putlook.com': 'outlook.com',
            'outlool.com': 'outlook.com',

            // Yahoo variations
            'yaho.com': 'yahoo.com',
            'yahooo.com': 'yahoo.com',
            'yahoo.co': 'yahoo.com',
            'yahoo.con': 'yahoo.com',
            'yahoo.cm': 'yahoo.com',
            'yaho.com.br': 'yahoo.com.br',
            'yahool.com': 'yahoo.com',
            'yaoo.com': 'yahoo.com',
            'yhaoo.com': 'yahoo.com',

            // iCloud variations
            'iclound.com': 'icloud.com',
            'icloude.com': 'icloud.com',
            'icoud.com': 'icloud.com',
            'icloud.co': 'icloud.com',
            'icloud.con': 'icloud.com',

            // Protonmail variations
            'protonmai.com': 'protonmail.com',
            'protonmails.com': 'protonmail.com',
            'protonmal.com': 'protonmail.com',
            'portonmail.com': 'protonmail.com',

            // AOL variations
            'aol.co': 'aol.com',
            'aol.con': 'aol.com',
            'aool.com': 'aol.com',
            'aoil.com': 'aol.com',

            // Live/MSN variations
            'live.co': 'live.com',
            'live.con': 'live.com',
            'liv.com': 'live.com',
            'livee.com': 'live.com',
            'msn.co': 'msn.com',
            'msn.con': 'msn.com',

            // Brazilian providers
            'bol.com.b': 'bol.com.br',
            'bol.com.rb': 'bol.com.br',
            'boll.com.br': 'bol.com.br',
            'uol.com.b': 'uol.com.br',
            'uol.com.rb': 'uol.com.br',
            'uoll.com.br': 'uol.com.br',
            'uol.co.br': 'uol.com.br',
            'terra.com.b': 'terra.com.br',
            'terra.com.rb': 'terra.com.br',
            'tera.com.br': 'terra.com.br',
            'ig.com.b': 'ig.com.br',
            'ig.com.rb': 'ig.com.br',
            'globo.co': 'globo.com',
            'globo.con': 'globo.com',
            'globomail.co': 'globomail.com',

            // Business domains
            'company.co': 'company.com',
            'company.con': 'company.com',
            'company.cm': 'company.com',

            // Educational
            'university.ed': 'university.edu',
            'college.ed': 'college.edu',

            // Government
            'governo.gov.b': 'governo.gov.br',
            'governo.gov.rb': 'governo.gov.br'
        };

        // Domínios válidos conhecidos (para validação)
        this.validDomains = new Set([
            'gmail.com', 'hotmail.com', 'outlook.com', 'yahoo.com',
            'icloud.com', 'protonmail.com', 'aol.com', 'live.com',
            'msn.com', 'mail.com', 'yandex.com', 'zoho.com',
            'bol.com.br', 'uol.com.br', 'terra.com.br', 'ig.com.br',
            'globo.com', 'globomail.com', 'oi.com.br', 'zipmail.com.br'
        ]);

        // TLDs válidos
        this.validTLDs = new Set([
            'com', 'org', 'net', 'edu', 'gov', 'mil', 'int',
            'com.br', 'org.br', 'net.br', 'edu.br', 'gov.br',
            'co', 'io', 'me', 'info', 'biz', 'name', 'pro',
            'br', 'us', 'uk', 'ca', 'au', 'de', 'fr', 'it', 'es', 'pt',
            'jp', 'cn', 'in', 'ru', 'mx', 'ar', 'cl', 'co.uk'
        ]);

        // Cache de correções para performance
        this.correctionCache = new Map();

        // Estatísticas
        this.stats = {
            totalProcessed: 0,
            totalCorrected: 0,
            corrections: {}
        };
    }

    /**
     * Corrige um email completo
     * @param {string} email - Email para corrigir
     * @returns {Object} Resultado da correção
     */
    correctEmail(email) {
        if (!email || typeof email !== 'string') {
            return {
                original: email,
                corrected: email,
                wasCorrected: false,
                error: 'Email inválido'
            };
        }

        this.stats.totalProcessed++;

        const emailLower = email.toLowerCase().trim();
        const parts = emailLower.split('@');

        if (parts.length !== 2) {
            return {
                original: email,
                corrected: email,
                wasCorrected: false,
                error: 'Formato de email inválido'
            };
        }

        const [localPart, domain] = parts;

        // Corrigir domínio
        const domainCorrection = this.correctDomain(domain);

        if (domainCorrection.wasCorrected) {
            this.stats.totalCorrected++;
            const correctedEmail = `${localPart}@${domainCorrection.corrected}`;

            // Atualizar estatísticas
            if (!this.stats.corrections[domain]) {
                this.stats.corrections[domain] = {
                    to: domainCorrection.corrected,
                    count: 0
                };
            }
            this.stats.corrections[domain].count++;

            return {
                original: email,
                corrected: correctedEmail,
                wasCorrected: true,
                correction: {
                    type: domainCorrection.type,
                    from: domain,
                    to: domainCorrection.corrected,
                    confidence: domainCorrection.confidence
                }
            };
        }

        return {
            original: email,
            corrected: email,
            wasCorrected: false
        };
    }

    /**
     * Corrige apenas o domínio
     * @param {string} domain - Domínio para corrigir
     * @returns {Object} Resultado da correção
     */
    correctDomain(domain) {
        if (!domain) {
            return {
                original: domain,
                corrected: domain,
                wasCorrected: false
            };
        }

        const domainLower = domain.toLowerCase().trim();

        // Verificar cache
        if (this.correctionCache.has(domainLower)) {
            return this.correctionCache.get(domainLower);
        }

        // 1. Verificar correção direta (typos conhecidos)
        if (this.commonMistakes[domainLower]) {
            const result = {
                original: domain,
                corrected: this.commonMistakes[domainLower],
                wasCorrected: true,
                type: 'known_typo',
                confidence: 1.0
            };
            this.correctionCache.set(domainLower, result);
            return result;
        }

        // 2. Verificar TLD inválido
        const tldCorrection = this.correctTLD(domainLower);
        if (tldCorrection.wasCorrected) {
            this.correctionCache.set(domainLower, tldCorrection);
            return tldCorrection;
        }

        // 3. Verificar distância de Levenshtein para domínios populares
        const similarityCorrection = this.findSimilarDomain(domainLower);
        if (similarityCorrection.wasCorrected) {
            this.correctionCache.set(domainLower, similarityCorrection);
            return similarityCorrection;
        }

        // Nenhuma correção necessária
        const result = {
            original: domain,
            corrected: domain,
            wasCorrected: false
        };
        this.correctionCache.set(domainLower, result);
        return result;
    }

    /**
     * Corrige TLD inválido
     * @param {string} domain - Domínio para verificar
     * @returns {Object} Resultado da correção
     */
    correctTLD(domain) {
        const parts = domain.split('.');
        if (parts.length < 2) {
            return { original: domain, corrected: domain, wasCorrected: false };
        }

        const tld = parts.slice(1).join('.');
        const baseDomain = parts[0];

        // Correções comuns de TLD
        const tldCorrections = {
            'con': 'com',
            'co': 'com',
            'cm': 'com',
            'om': 'com',
            'com.b': 'com.br',
            'com.rb': 'com.br',
            'com.brr': 'com.br',
            'co.br': 'com.br',
            'con.br': 'com.br',
            'ed': 'edu',
            'eduu': 'edu',
            'go': 'gov',
            'gob': 'gov',
            'gv': 'gov',
            'ogr': 'org',
            'og': 'org',
            'orgg': 'org',
            'nt': 'net',
            'nett': 'net'
        };

        if (tldCorrections[tld]) {
            const corrected = `${baseDomain}.${tldCorrections[tld]}`;
            return {
                original: domain,
                corrected: corrected,
                wasCorrected: true,
                type: 'tld_correction',
                confidence: 0.9
            };
        }

        return { original: domain, corrected: domain, wasCorrected: false };
    }

    /**
     * Encontra domínio similar usando distância de Levenshtein
     * @param {string} domain - Domínio para verificar
     * @returns {Object} Resultado da correção
     */
    findSimilarDomain(domain) {
        let bestMatch = null;
        let bestDistance = Infinity;
        const maxDistance = 2; // Máximo de 2 caracteres diferentes

        for (const validDomain of this.validDomains) {
            const distance = this.levenshteinDistance(domain, validDomain);

            if (distance <= maxDistance && distance < bestDistance) {
                bestDistance = distance;
                bestMatch = validDomain;
            }
        }

        if (bestMatch && bestDistance <= maxDistance) {
            return {
                original: domain,
                corrected: bestMatch,
                wasCorrected: true,
                type: 'similarity',
                confidence: 1 - (bestDistance / maxDistance) * 0.3
            };
        }

        return { original: domain, corrected: domain, wasCorrected: false };
    }

    /**
     * Calcula distância de Levenshtein entre duas strings
     * @param {string} str1 - Primeira string
     * @param {string} str2 - Segunda string
     * @returns {number} Distância
     */
    levenshteinDistance(str1, str2) {
        const matrix = [];
        const len1 = str1.length;
        const len2 = str2.length;

        if (len1 === 0) return len2;
        if (len2 === 0) return len1;

        // Inicializar primeira linha e coluna
        for (let i = 0; i <= len2; i++) {
            matrix[i] = [i];
        }

        for (let j = 0; j <= len1; j++) {
            matrix[0][j] = j;
        }

        // Calcular distâncias
        for (let i = 1; i <= len2; i++) {
            for (let j = 1; j <= len1; j++) {
                if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
                    matrix[i][j] = matrix[i - 1][j - 1];
                } else {
                    matrix[i][j] = Math.min(
                        matrix[i - 1][j - 1] + 1, // substituição
                        matrix[i][j - 1] + 1,      // inserção
                        matrix[i - 1][j] + 1       // deleção
                    );
                }
            }
        }

        return matrix[len2][len1];
    }

    /**
     * Processa lote de emails
     * @param {Array} emails - Array de emails
     * @returns {Array} Resultados das correções
     */
    correctBatch(emails) {
        if (!Array.isArray(emails)) {
            return [];
        }

        return emails.map(email => this.correctEmail(email));
    }

    /**
     * Adiciona nova correção ao dicionário
     * @param {string} typo - Domínio com erro
     * @param {string} correct - Domínio correto
     */
    addCorrection(typo, correct) {
        if (typo && correct) {
            this.commonMistakes[typo.toLowerCase()] = correct.toLowerCase();
            // Limpar cache para aplicar nova correção
            this.correctionCache.clear();
        }
    }

    /**
     * Retorna estatísticas de uso
     * @returns {Object} Estatísticas
     */
    getStatistics() {
        return {
            ...this.stats,
            cacheSize: this.correctionCache.size,
            knownMistakes: Object.keys(this.commonMistakes).length,
            validDomains: this.validDomains.size,
            correctionRate: this.stats.totalProcessed > 0
                ? ((this.stats.totalCorrected / this.stats.totalProcessed) * 100).toFixed(2) + '%'
                : '0%'
        };
    }

    /**
     * Limpa cache e estatísticas
     */
    reset() {
        this.correctionCache.clear();
        this.stats = {
            totalProcessed: 0,
            totalCorrected: 0,
            corrections: {}
        };
    }

    /**
     * Verifica se domínio precisa de correção
     * @param {string} domain - Domínio para verificar
     * @returns {boolean} Se precisa de correção
     */
    needsCorrection(domain) {
        const result = this.correctDomain(domain);
        return result.wasCorrected;
    }
}

module.exports = DomainCorrector;
