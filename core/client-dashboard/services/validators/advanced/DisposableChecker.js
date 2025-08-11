// ================================================
// Disposable Email Checker - Detecção massiva
// ================================================

const fs = require('fs');
const path = require('path');

class DisposableChecker {
    constructor() {
        this.loadDisposableData();
        this.stats = {
            totalChecked: 0,
            disposableFound: 0,
            patternMatches: 0
        };
    }

    loadDisposableData() {
        try {
            const dataPath = path.join(__dirname, '../../../data/lists/disposable.json');
            const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
            
            this.disposableDomains = new Set(data.domains);
            this.patterns = data.patterns.map(p => new RegExp(p, 'i'));
            
            console.log(`✅ Disposable Checker: ${this.disposableDomains.size} domínios carregados`);
        } catch (error) {
            console.error('❌ Erro ao carregar disposable list:', error);
            // Fallback mínimo
            this.disposableDomains = new Set([
                'tempmail.com', 'throwaway.email', '10minutemail.com',
                'guerrillamail.com', 'mailinator.com', 'temp-mail.org'
            ]);
            this.patterns = [/temp/i, /trash/i, /fake/i, /disposable/i];
        }
    }

    checkEmail(email) {
        this.stats.totalChecked++;
        
        const result = {
            isDisposable: false,
            confidence: 'high',
            detectionMethod: null,
            provider: null,
            score: 10 // Começa com score alto
        };
        
        const [localPart, domain] = email.toLowerCase().split('@');
        
        if (!domain) {
            return result;
        }
        
        // Verificação 1: Lista de domínios
        if (this.disposableDomains.has(domain)) {
            this.stats.disposableFound++;
            result.isDisposable = true;
            result.confidence = 'certain';
            result.detectionMethod = 'domain_list';
            result.provider = domain;
            result.score = 0;
            return result;
        }
        
        // Verificação 2: Subdomínios de disposable
        const domainParts = domain.split('.');
        for (let i = 1; i < domainParts.length; i++) {
            const parentDomain = domainParts.slice(i).join('.');
            if (this.disposableDomains.has(parentDomain)) {
                this.stats.disposableFound++;
                result.isDisposable = true;
                result.confidence = 'high';
                result.detectionMethod = 'subdomain';
                result.provider = parentDomain;
                result.score = 0;
                return result;
            }
        }
        
        // Verificação 3: Padrões no domínio
        for (const pattern of this.patterns) {
            if (pattern.test(domain)) {
                this.stats.patternMatches++;
                result.isDisposable = true;
                result.confidence = 'medium';
                result.detectionMethod = 'pattern_match';
                result.provider = 'pattern: ' + pattern.source;
                result.score = 1;
                return result;
            }
        }
        
        // Verificação 4: Padrões no local part suspeitos
        const suspiciousLocalPatterns = [
            /^test\d*/i,
            /^temp/i,
            /^fake/i,
            /^trash/i,
            /^disposable/i,
            /^mailinator/i,
            /^throwaway/i
        ];
        
        for (const pattern of suspiciousLocalPatterns) {
            if (pattern.test(localPart)) {
                result.confidence = 'low';
                result.detectionMethod = 'local_pattern';
                result.score = 5; // Reduz score mas não marca como disposable definitivo
                break;
            }
        }
        
        // Verificação 5: Domínios recém criados (simulação)
        // Na prática, isso seria verificado via WHOIS ou API
        const newDomainPatterns = [
            /\d{4,}/, // Muitos números
            /^[a-z]{15,}/, // Muito longo e aleatório
            /-{2,}/, // Múltiplos hífens
        ];
        
        for (const pattern of newDomainPatterns) {
            if (pattern.test(domain)) {
                result.confidence = 'low';
                result.score = Math.min(result.score, 6);
                break;
            }
        }
        
        return result;
    }

    getStatistics() {
        return {
            ...this.stats,
            disposableRate: this.stats.totalChecked > 0
                ? ((this.stats.disposableFound / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            patternMatchRate: this.stats.totalChecked > 0
                ? ((this.stats.patternMatches / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%'
        };
    }

    reloadData() {
        this.loadDisposableData();
        console.log('🔄 Disposable data reloaded');
    }
}

module.exports = DisposableChecker;
