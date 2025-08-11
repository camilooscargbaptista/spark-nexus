// ================================================
// Trusted Domains Module
// Lista de domínios confiáveis com categorização
// ================================================

class TrustedDomains {
    constructor() {
        // Provedores de email mainstream (alta confiança)
        this.mainstream = [
            'gmail.com', 'googlemail.com',
            'outlook.com', 'outlook.com.br',
            'hotmail.com', 'hotmail.com.br',
            'live.com', 'msn.com',
            'yahoo.com', 'yahoo.com.br',
            'icloud.com', 'me.com', 'mac.com'
        ];
        
        // Provedores brasileiros confiáveis
        this.brazilian = [
            'uol.com.br', 'bol.com.br',
            'terra.com.br', 'globo.com',
            'ig.com.br', 'r7.com',
            'zipmail.com.br'
        ];
        
        // Provedores corporativos/profissionais
        this.professional = [
            'protonmail.com', 'proton.me',
            'tutanota.com', 'tutanota.de',
            'fastmail.com', 'fastmail.fm',
            'zoho.com', 'yandex.com'
        ];
        
        // Domínios educacionais (padrão)
        this.educational = [
            '.edu', '.edu.br', '.ac.uk'
        ];
        
        // Domínios governamentais (padrão)
        this.government = [
            '.gov', '.gov.br', '.mil'
        ];
        
        // Cache de verificações
        this.cache = new Map();
    }
    
    isTrusted(domain) {
        if (!domain) return false;
        
        domain = domain.toLowerCase();
        
        // Verificar cache
        if (this.cache.has(domain)) {
            return this.cache.get(domain);
        }
        
        // Verificar mainstream
        if (this.mainstream.includes(domain)) {
            this.cache.set(domain, true);
            return true;
        }
        
        // Verificar brasileiros
        if (this.brazilian.includes(domain)) {
            this.cache.set(domain, true);
            return true;
        }
        
        // Verificar profissionais
        if (this.professional.includes(domain)) {
            this.cache.set(domain, true);
            return true;
        }
        
        // Verificar padrões educacionais e governamentais
        for (const pattern of [...this.educational, ...this.government]) {
            if (domain.endsWith(pattern)) {
                this.cache.set(domain, true);
                return true;
            }
        }
        
        this.cache.set(domain, false);
        return false;
    }
    
    getCategory(domain) {
        if (!domain) return 'unknown';
        
        domain = domain.toLowerCase();
        
        if (this.mainstream.includes(domain)) return 'mainstream';
        if (this.brazilian.includes(domain)) return 'brazilian';
        if (this.professional.includes(domain)) return 'professional';
        
        for (const pattern of this.educational) {
            if (domain.endsWith(pattern)) return 'educational';
        }
        
        for (const pattern of this.government) {
            if (domain.endsWith(pattern)) return 'government';
        }
        
        return 'other';
    }
    
    getTrustScore(domain) {
        const category = this.getCategory(domain);
        
        switch(category) {
            case 'mainstream':
            case 'government':
                return 10; // Máxima confiança
            case 'educational':
            case 'professional':
                return 9;
            case 'brazilian':
                return 8;
            default:
                return 5; // Score neutro para desconhecidos
        }
    }
}

module.exports = TrustedDomains;
