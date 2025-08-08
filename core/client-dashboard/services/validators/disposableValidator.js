// Disposable Email Validator
class DisposableValidator {
    constructor() {
        // Lista básica de domínios disposable
        this.disposableSet = new Set([
            'tempmail.com', '10minutemail.com', 'guerrillamail.com',
            'mailinator.com', 'throwawaymail.com', 'yopmail.com',
            'tempmail.net', 'trashmail.com', 'fakeinbox.com',
            'temp-mail.org', 'sharklasers.com', 'guerrillamail.info'
        ]);
        
        this.patterns = [
            /^(temp|tmp|test|fake|spam|trash|disposable)/i,
            /^[0-9]+(minute|hour|day)mail/i
        ];
    }

    async check(email, parsed) {
        const result = {
            isDisposable: false,
            confidence: 0,
            riskLevel: 'low',
            reason: null
        };

        const domain = parsed.domain.toLowerCase();

        // Verificar lista de disposable
        if (this.disposableSet.has(domain)) {
            result.isDisposable = true;
            result.confidence = 95;
            result.riskLevel = 'very_high';
            result.reason = 'Domínio na lista de descartáveis';
            return result;
        }

        // Verificar padrões
        for (const pattern of this.patterns) {
            if (pattern.test(domain) || pattern.test(parsed.local)) {
                result.isDisposable = true;
                result.confidence = 70;
                result.riskLevel = 'high';
                result.reason = 'Padrão suspeito detectado';
                return result;
            }
        }

        return result;
    }

    getStats() {
        return {
            totalDisposable: this.disposableSet.size,
            patterns: this.patterns.length
        };
    }
}

module.exports = DisposableValidator;
