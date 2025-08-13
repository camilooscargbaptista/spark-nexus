// ================================================
// TLD Validator - Versão Simplificada (sem PSL)
// ================================================

const fs = require('fs');
const path = require('path');

class TLDValidator {
    constructor() {
        this.loadTLDData();
        this.stats = {
            totalChecked: 0,
            blocked: 0,
            suspicious: 0,
            premium: 0
        };
    }

    loadTLDData() {
        try {
            const dataPath = path.join(__dirname, '../../../data/lists/tlds.json');
            const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));

            this.validTLDs = new Set(data.valid);
            this.blockedTLDs = new Set(data.blocked);
            this.suspiciousTLDs = new Set(data.suspicious);
            this.premiumTLDs = new Set(data.premium);

            console.log(`✅ TLD Validator: ${this.validTLDs.size} TLDs válidos carregados`);
        } catch (error) {
            console.log('⚠️ Usando lista de TLDs padrão (arquivo não encontrado)');
            // Lista padrão extensa de TLDs válidos
            this.validTLDs = new Set([
                'com', 'org', 'net', 'edu', 'gov', 'mil', 'int',
                'br', 'us', 'uk', 'ca', 'au', 'de', 'fr', 'it', 'es', 'pt',
                'jp', 'cn', 'in', 'ru', 'mx', 'ar', 'cl', 'co', 'pe', 've',
                'io', 'ai', 'app', 'dev', 'tech', 'digital', 'online', 'store',
                'shop', 'web', 'site', 'blog', 'news', 'info', 'biz', 'name',
                'tv', 'cc', 'ws', 'mobi', 'asia', 'tel', 'travel', 'pro'
            ]);
            this.blockedTLDs = new Set([
                'test', 'example', 'invalid', 'localhost', 'local', 'fake',
                // NOVOS domínios bloqueados:
                'testing', 'teste', 'demo', 'sample', 'temp', 'tmp',
                'dev', 'development', 'staging', 'sandbox'
            ]);
            this.suspiciousTLDs = new Set([
                'tk', 'ml', 'ga', 'cf', 'click', 'download',
                // NOVOS TLDs suspeitos:
                'loan', 'win', 'racing', 'cricket', 'science', 'party',
                'review', 'faith', 'accountant', 'bid', 'trade'
            ]);
            this.premiumTLDs = new Set(['com', 'org', 'net', 'edu', 'gov', 'com.br', 'org.br']);
        }
    }

    extractTLD(domain) {
        // Extração simples de TLD sem PSL
        const parts = domain.toLowerCase().split('.');

        // Verificar TLDs de dois níveis comuns (.com.br, .co.uk, etc)
        const twoLevelTLDs = ['com.br', 'org.br', 'gov.br', 'edu.br', 'net.br',
                              'co.uk', 'org.uk', 'gov.uk', 'ac.uk', 'edu.uk',
                              'com.au', 'org.au', 'gov.au', 'edu.au',
                              'com.mx', 'org.mx', 'gob.mx', 'edu.mx'];

        if (parts.length >= 2) {
            const lastTwo = parts.slice(-2).join('.');
            if (twoLevelTLDs.includes(lastTwo)) {
                return lastTwo;
            }
        }

        // Retornar apenas o último elemento como TLD
        return parts[parts.length - 1];
    }

    validateTLD(domain) {
        this.stats.totalChecked++;

        const result = {
            valid: false,
            tld: null,
            type: 'unknown',
            score: 0,
            isBlocked: false,
            isSuspicious: false,
            isPremium: false,
            details: {}
        };

        // Extrair TLD de forma simples
        const tld = this.extractTLD(domain);
        result.tld = tld;

        // Verificar se está bloqueado
        if (this.blockedTLDs.has(tld)) {
            this.stats.blocked++;
            result.isBlocked = true;
            result.type = 'blocked';
            result.score = 0;
            result.details.reason = 'TLD is blocked for testing/internal use';
            return result;
        }

        // Verificar se existe na lista válida
        if (!this.validTLDs.has(tld)) {
            // Se não estiver na lista, mas não for obviamente inválido, dar uma chance
            if (tld && tld.length >= 2 && tld.length <= 10 && /^[a-z]+$/.test(tld)) {
                result.valid = true;
                result.type = 'generic';
                result.score = 3; // Score baixo para TLD desconhecido
                result.details.warning = 'TLD not in common list';
            } else {
                result.type = 'invalid';
                result.score = 0;
                result.details.reason = 'Invalid TLD format';
                return result;
            }
        } else {
            result.valid = true;
        }

        // Verificar se é suspeito
        if (this.suspiciousTLDs.has(tld)) {
            this.stats.suspicious++;
            result.isSuspicious = true;
            result.type = 'suspicious';
            result.score = 2;
            result.details.warning = 'TLD has high spam/fraud rate';
        }
        // Verificar se é premium
        else if (this.premiumTLDs.has(tld)) {
            this.stats.premium++;
            result.isPremium = true;
            result.type = 'premium';
            result.score = 10;
            result.details.trust = 'Premium TLD with high trust';
        }
        // TLD válido genérico
        else if (result.valid) {
            result.type = 'generic';
            result.score = 5;
        }

        // Adicionar metadados
        result.details.registryInfo = {
            isCountryCode: tld && tld.length === 2,
            isGeneric: tld && tld.length > 2,
            isSpecialUse: this.blockedTLDs.has(tld)
        };

        return result;
    }

    getStatistics() {
        return {
            ...this.stats,
            blockedRate: this.stats.totalChecked > 0
                ? ((this.stats.blocked / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            suspiciousRate: this.stats.totalChecked > 0
                ? ((this.stats.suspicious / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%'
        };
    }

    reloadTLDs() {
        this.loadTLDData();
        console.log('🔄 TLD data reloaded');
    }
}

module.exports = TLDValidator;
