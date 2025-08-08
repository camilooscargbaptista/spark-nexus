// Parser de Email
class EmailParser {
    parse(email) {
        if (!email || typeof email !== 'string') {
            throw new Error('Email inválido');
        }

        const normalized = email.toLowerCase().trim();
        const parts = normalized.split('@');
        
        if (parts.length !== 2) {
            throw new Error('Formato de email inválido');
        }

        const [local, domain] = parts;
        
        return {
            full: normalized,
            local: local,
            domain: domain,
            tld: domain.split('.').pop(),
            isSubaddressed: local.includes('+')
        };
    }

    normalize(email) {
        const parsed = this.parse(email);
        return parsed.full;
    }
}

module.exports = EmailParser;
