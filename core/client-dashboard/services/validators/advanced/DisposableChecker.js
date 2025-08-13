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
            score: 10, // Começa com score alto
            category: 'permanent',
            riskLevel: 'low',
            flags: [],
            analysis: {
                domain: '',
                domainAge: 'unknown',
                providerType: 'unknown',
                suspiciousKeywords: [],
                domainPattern: 'normal'
            },
            metadata: {
                timestamp: new Date().toISOString(),
                checkedAgainst: []
            }
        };

        // Validação básica de entrada
        if (!email || typeof email !== 'string') {
            result.isDisposable = true;
            result.confidence = 'certain';
            result.detectionMethod = 'invalid_input';
            result.score = 0;
            result.category = 'invalid';
            result.riskLevel = 'critical';
            return result;
        }

        const emailParts = email.toLowerCase().split('@');

        if (emailParts.length !== 2) {
            result.isDisposable = true;
            result.confidence = 'certain';
            result.detectionMethod = 'malformed_email';
            result.score = 0;
            result.category = 'invalid';
            result.riskLevel = 'critical';
            return result;
        }

        const [localPart, domain] = emailParts;
        result.analysis.domain = domain;

        if (!domain || domain.length < 3) {
            result.isDisposable = true;
            result.confidence = 'certain';
            result.detectionMethod = 'invalid_domain';
            result.score = 0;
            result.category = 'invalid';
            result.riskLevel = 'critical';
            return result;
        }

        // ================================================
        // VERIFICAÇÃO 1: LISTA DE DOMÍNIOS CONHECIDOS
        // ================================================

        result.metadata.checkedAgainst.push('domain_blacklist');

        if (this.disposableDomains.has(domain)) {
            this.stats.disposableFound++;
            result.isDisposable = true;
            result.confidence = 'certain';
            result.detectionMethod = 'domain_blacklist';
            result.provider = domain;
            result.score = 0;
            result.category = 'disposable_known';
            result.riskLevel = 'critical';
            result.flags.push('KNOWN_DISPOSABLE');
            result.analysis.providerType = 'disposable_service';
            return result;
        }

        // ================================================
        // VERIFICAÇÃO 2: SUBDOMÍNIOS DE SERVIÇOS DISPOSABLE
        // ================================================

        result.metadata.checkedAgainst.push('subdomain_check');

        const domainParts = domain.split('.');
        for (let i = 1; i < domainParts.length; i++) {
            const parentDomain = domainParts.slice(i).join('.');
            if (this.disposableDomains.has(parentDomain)) {
                this.stats.disposableFound++;
                result.isDisposable = true;
                result.confidence = 'high';
                result.detectionMethod = 'subdomain_of_disposable';
                result.provider = parentDomain;
                result.score = 0;
                result.category = 'disposable_subdomain';
                result.riskLevel = 'critical';
                result.flags.push('DISPOSABLE_SUBDOMAIN');
                result.analysis.providerType = 'disposable_subdomain';
                return result;
            }
        }

        // ================================================
        // VERIFICAÇÃO 3: PALAVRAS-CHAVE SUSPEITAS NO DOMÍNIO
        // ================================================

        result.metadata.checkedAgainst.push('keyword_analysis');

        const suspiciousKeywords = [
            // Temporário/Descartável
            'temp', 'tmp', 'temporary', 'temporario', 'provisorio',
            'disposable', 'descartavel', 'throwaway', 'trash', 'lixo',
            'fake', 'falso', 'dummy', 'test', 'teste', 'testing',

            // Duração específica
            'minute', 'minuto', 'hour', 'hora', 'day', 'dia',
            '10minute', '20minute', '30minute', '60minute',
            'short', 'quick', 'fast', 'rapid', 'instant',

            // Serviços conhecidos
            'burner', 'guerrilla', 'guerrilha', 'mailinator',
            'yopmail', 'maildrop', 'spamgourmet', 'sharklasers',
            'anonymous', 'anonimo', 'hide', 'esconder', 'privacy',
            'tempmail', 'tempinbox', 'throwmail', 'trashmail',

            // Padrões específicos
            'disposable', 'jetable', 'wegwerf', 'temporal',
            'ephemeral', 'volatile', 'transient'
        ];

        const foundKeywords = [];
        for (const keyword of suspiciousKeywords) {
            if (domain.includes(keyword)) {
                foundKeywords.push(keyword);
                result.analysis.suspiciousKeywords.push(keyword);
            }
        }

        if (foundKeywords.length > 0) {
            this.stats.disposableFound++;
            result.isDisposable = true;
            result.confidence = foundKeywords.length > 1 ? 'very_high' : 'high';
            result.detectionMethod = 'keyword_detection';
            result.provider = `Keywords: ${foundKeywords.join(', ')}`;
            result.score = 0;
            result.category = 'disposable_keyword';
            result.riskLevel = 'critical';
            result.flags.push('SUSPICIOUS_KEYWORDS');
            result.analysis.providerType = 'keyword_based_disposable';
            return result;
        }

        // ================================================
        // VERIFICAÇÃO 4: PADRÕES DE DOMÍNIO SUSPEITO
        // ================================================

        result.metadata.checkedAgainst.push('domain_pattern_analysis');

        const domainName = domain.split('.')[0];
        const tld = domain.split('.').pop();

        // Domínio muito curto (alta chance de ser spam/temporário)
        if (domainName.length <= 3) {
            result.confidence = 'medium';
            result.detectionMethod = 'short_domain_pattern';
            result.score = 3;
            result.category = 'suspicious_short';
            result.riskLevel = 'high';
            result.flags.push('SHORT_DOMAIN');
            result.analysis.domainPattern = 'very_short';
        }

        // Domínio com muitos números (padrão gerado automaticamente)
        else if (/\d{3,}/.test(domainName)) {
            result.confidence = 'medium';
            result.detectionMethod = 'numeric_domain_pattern';
            result.score = 4;
            result.category = 'suspicious_numeric';
            result.riskLevel = 'medium';
            result.flags.push('NUMERIC_DOMAIN');
            result.analysis.domainPattern = 'numeric_heavy';
        }

        // Domínio com hífens excessivos (padrão de geração automática)
        else if ((domainName.match(/-/g) || []).length >= 3) {
            result.confidence = 'medium';
            result.detectionMethod = 'hyphen_pattern';
            result.score = 5;
            result.category = 'suspicious_hyphen';
            result.riskLevel = 'medium';
            result.flags.push('EXCESSIVE_HYPHENS');
            result.analysis.domainPattern = 'hyphen_heavy';
        }

        // Domínio muito longo e aleatório
        else if (domainName.length > 20 && this.isRandomString(domainName)) {
            result.confidence = 'medium';
            result.detectionMethod = 'random_long_domain';
            result.score = 4;
            result.category = 'suspicious_random';
            result.riskLevel = 'medium';
            result.flags.push('RANDOM_LONG_DOMAIN');
            result.analysis.domainPattern = 'random_long';
        }

        // ================================================
        // VERIFICAÇÃO 5: TLD SUSPEITOS
        // ================================================

        result.metadata.checkedAgainst.push('tld_analysis');

        const suspiciousTlds = [
            'tk', 'ml', 'ga', 'cf', // Freenom gratuitos
            'click', 'download', 'loan', 'win', 'racing',
            'party', 'review', 'faith', 'science', 'accountant',
            'bid', 'trade', 'cricket'
        ];

        if (suspiciousTlds.includes(tld)) {
            // Não marcar como disposable, mas reduzir score
            result.confidence = 'medium';
            result.score = Math.min(result.score, 6);
            result.category = result.category === 'permanent' ? 'suspicious_tld' : result.category;
            result.riskLevel = 'medium';
            result.flags.push('SUSPICIOUS_TLD');
            result.analysis.providerType = 'suspicious_tld_provider';
        }

        // ================================================
        // VERIFICAÇÃO 6: PADRÕES NO LOCAL PART SUSPEITOS
        // ================================================

        result.metadata.checkedAgainst.push('local_part_analysis');

        const suspiciousLocalPatterns = [
            /^test\d*/i,
            /^temp/i,
            /^fake/i,
            /^trash/i,
            /^disposable/i,
            /^mailinator/i,
            /^throwaway/i,
            /^burner/i,
            /^anonymous/i,
            /^spam/i,
            /^junk/i
        ];

        for (const pattern of suspiciousLocalPatterns) {
            if (pattern.test(localPart)) {
                result.confidence = 'high';
                result.detectionMethod = 'suspicious_local_pattern';
                result.score = Math.min(result.score, 3); // Reduzir score significativamente
                result.category = result.category === 'permanent' ? 'suspicious_local' : result.category;
                result.riskLevel = 'high';
                result.flags.push('SUSPICIOUS_LOCAL_PART');
                result.analysis.providerType = 'suspicious_local_pattern';
                break;
            }
        }

        // ================================================
        // VERIFICAÇÃO 7: VERIFICAÇÃO POR PADRÕES REGEX
        // ================================================

        result.metadata.checkedAgainst.push('regex_patterns');

        for (const pattern of this.patterns) {
            if (pattern.test(domain)) {
                this.stats.patternMatches++;
                result.isDisposable = true;
                result.confidence = 'medium';
                result.detectionMethod = 'regex_pattern_match';
                result.provider = 'Pattern: ' + pattern.source;
                result.score = 1;
                result.category = 'disposable_pattern';
                result.riskLevel = 'high';
                result.flags.push('REGEX_PATTERN_MATCH');
                result.analysis.providerType = 'pattern_matched_disposable';
                return result;
            }
        }

        // ================================================
        // VERIFICAÇÃO 8: ANÁLISE DE ENTROPIA DE DOMÍNIO
        // ================================================

        result.metadata.checkedAgainst.push('entropy_analysis');

        const entropy = this.calculateDomainEntropy(domainName);
        if (entropy > 0.85 && domainName.length > 10) {
            result.confidence = 'medium';
            result.detectionMethod = 'high_entropy_domain';
            result.score = Math.min(result.score, 5);
            result.category = result.category === 'permanent' ? 'suspicious_entropy' : result.category;
            result.riskLevel = 'medium';
            result.flags.push('HIGH_ENTROPY');
            result.analysis.domainPattern = 'high_entropy';
            result.analysis.entropy = Math.round(entropy * 100);
        }

        // ================================================
        // VERIFICAÇÃO 9: DOMÍNIOS RECÉM-CRIADOS (SIMULAÇÃO)
        // ================================================

        result.metadata.checkedAgainst.push('domain_age_simulation');

        // Simular verificação de idade baseada em padrões
        const newDomainPatterns = [
            /\d{4,}/, // Muitos números sequenciais
            /^[a-z]{15,}$/, // Muito longo e só letras
            /-{2,}/, // Múltiplos hífens consecutivos
            /[0-9]{2}[a-z]{2}[0-9]{2}/, // Padrão número-letra-número
        ];

        for (const pattern of newDomainPatterns) {
            if (pattern.test(domainName)) {
                result.confidence = 'low';
                result.score = Math.min(result.score, 6);
                result.category = result.category === 'permanent' ? 'potentially_new' : result.category;
                result.riskLevel = result.riskLevel === 'low' ? 'medium' : result.riskLevel;
                result.flags.push('POTENTIALLY_NEW_DOMAIN');
                result.analysis.domainAge = 'potentially_new';
                break;
            }
        }

        // ================================================
        // VERIFICAÇÃO 10: ANÁLISE FINAL E CLASSIFICAÇÃO
        // ================================================

        // Se não foi marcado como disposable até aqui, analisar score final
        if (!result.isDisposable) {
            if (result.score <= 3) {
                result.isDisposable = true;
                result.confidence = 'medium';
                result.detectionMethod = 'cumulative_risk_analysis';
                result.category = 'high_risk_cumulative';
                result.riskLevel = 'high';
                result.flags.push('HIGH_CUMULATIVE_RISK');
            } else if (result.score <= 5) {
                // Não disposable, mas suspeito
                result.category = 'suspicious_cumulative';
                result.riskLevel = 'medium';
                result.flags.push('MEDIUM_CUMULATIVE_RISK');
            } else if (result.score <= 7) {
                result.category = 'low_risk';
                result.riskLevel = 'low';
            } else {
                result.category = 'trusted';
                result.riskLevel = 'very_low';
            }
        }

        // ================================================
        // ANÁLISE DE PROVEDOR
        // ================================================

        if (!result.isDisposable) {
            // Identificar tipo de provedor para emails legítimos
            const mainstream = ['gmail.com', 'outlook.com', 'yahoo.com', 'hotmail.com', 'icloud.com'];
            const brazilian = ['uol.com.br', 'bol.com.br', 'terra.com.br', 'ig.com.br'];
            const corporate = ['protonmail.com', 'fastmail.com', 'zoho.com'];

            if (mainstream.includes(domain)) {
                result.analysis.providerType = 'mainstream';
                result.score = Math.min(10, result.score + 1); // Pequeno boost
            } else if (brazilian.includes(domain)) {
                result.analysis.providerType = 'brazilian_provider';
                result.score = Math.min(10, result.score + 1);
            } else if (corporate.includes(domain)) {
                result.analysis.providerType = 'corporate_provider';
            } else {
                result.analysis.providerType = 'independent_provider';
            }
        }

        // ================================================
        // RECOMENDAÇÕES BASEADAS NO RESULTADO
        // ================================================

        result.recommendations = [];

        if (result.isDisposable) {
            result.recommendations.push({
                action: 'REJECT',
                message: 'Email temporário/descartável detectado',
                priority: 'high'
            });
            result.recommendations.push({
                action: 'REQUEST_ALTERNATIVE',
                message: 'Solicitar email permanente',
                priority: 'high'
            });
        } else if (result.score <= 5) {
            result.recommendations.push({
                action: 'ADDITIONAL_VERIFICATION',
                message: 'Email suspeito - verificação adicional recomendada',
                priority: 'medium'
            });
        } else if (result.score <= 7) {
            result.recommendations.push({
                action: 'MONITOR',
                message: 'Monitorar atividade do usuário',
                priority: 'low'
            });
        } else {
            result.recommendations.push({
                action: 'APPROVE',
                message: 'Email confiável',
                priority: 'low'
            });
        }

        // ================================================
        // METADADOS FINAIS
        // ================================================

        result.metadata.domainLength = domain.length;
        result.metadata.localPartLength = localPart.length;
        result.metadata.tld = tld;
        result.metadata.domainParts = domainParts.length;
        result.metadata.flagsCount = result.flags.length;
        result.metadata.processingSteps = result.metadata.checkedAgainst.length;

        // ================================================
        // LOG E ESTATÍSTICAS
        // ================================================

        if (result.isDisposable) {
            this.stats.disposableFound++;
        }

        // Debug log
        if (process.env.DEBUG_DISPOSABLE === 'true') {
            console.log(`[DisposableChecker] ${email} - Disposable: ${result.isDisposable}, Score: ${result.score}, Method: ${result.detectionMethod}, Flags: [${result.flags.join(', ')}]`);
        }

        return result;
    }

    // Método auxiliar para verificar se string é aleatória
    isRandomString(str) {
        // Verificar entropia de caracteres
        const uniqueChars = new Set(str.toLowerCase()).size;
        const entropy = uniqueChars / str.length;

        // Verificar proporção consonantes/vogais
        const vowels = str.toLowerCase().match(/[aeiou]/g) || [];
        const consonants = str.toLowerCase().match(/[bcdfghjklmnpqrstvwxyz]/g) || [];
        const vowelRatio = vowels.length / (consonants.length || 1);

        // String aleatória: alta entropia + proporção estranha de vogais
        return entropy > 0.8 || vowelRatio > 3 || vowelRatio < 0.2;
    }

    // Método auxiliar para calcular entropia do domínio
    calculateDomainEntropy(domainName) {
        const charFreq = {};

        // Contar frequência de cada caractere
        for (const char of domainName.toLowerCase()) {
            charFreq[char] = (charFreq[char] || 0) + 1;
        }

        // Calcular entropia de Shannon
        let entropy = 0;
        const length = domainName.length;

        for (const freq of Object.values(charFreq)) {
            const probability = freq / length;
            entropy -= probability * Math.log2(probability);
        }

        // Normalizar para 0-1
        const maxEntropy = Math.log2(Math.min(26, length)); // Máximo possível
        return entropy / maxEntropy;
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
