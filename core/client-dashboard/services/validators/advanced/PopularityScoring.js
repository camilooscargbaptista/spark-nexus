// ================================================
// Domain Popularity Scoring System - v1.0
// Sistema de pontuação baseado em popularidade de domínio
// ================================================

class PopularityScoring {
    constructor() {
        // Sistema de tiers de popularidade
        this.domainPopularity = {
            // ====================================
            // TIER 1 - Extremamente Populares e Confiáveis
            // Raramente Difundido = Alta Confiança
            // ====================================
            'gmail.com': {
                tier: 1,
                bonus: 25,
                trust: 95,
                category: 'mainstream',
                popularity: 'RARELY_SPREAD',
                type: 'Email Provider'
            },
            'outlook.com': {
                tier: 1,
                bonus: 25,
                trust: 95,
                category: 'mainstream',
                popularity: 'RARELY_SPREAD',
                type: 'Email Provider'
            },
            'hotmail.com': {
                tier: 1,
                bonus: 25,
                trust: 95,
                category: 'mainstream',
                popularity: 'RARELY_SPREAD',
                type: 'Email Provider'
            },
            'yahoo.com': {
                tier: 1,
                bonus: 23,
                trust: 92,
                category: 'mainstream',
                popularity: 'RARELY_SPREAD',
                type: 'Email Provider'
            },
            'yahoo.com.br': {
                tier: 1,
                bonus: 22,
                trust: 90,
                category: 'mainstream',
                popularity: 'RARELY_SPREAD',
                type: 'Email Provider'
            },
            'msn.com': {
                tier: 1,
                bonus: 22,
                trust: 90,
                category: 'mainstream',
                popularity: 'RARELY_SPREAD',
                type: 'Email Provider'
            },
            'live.com': {
                tier: 1,
                bonus: 22,
                trust: 90,
                category: 'mainstream',
                popularity: 'RARELY_SPREAD',
                type: 'Email Provider'
            },

            // ====================================
            // TIER 2 - Muito Populares
            // Pouco Difundido = Boa Confiança
            // ====================================
            'icloud.com': {
                tier: 2,
                bonus: 18,
                trust: 85,
                category: 'premium',
                popularity: 'LITTLE_SPREAD',
                type: 'Email Provider'
            },
            'me.com': {
                tier: 2,
                bonus: 18,
                trust: 85,
                category: 'premium',
                popularity: 'LITTLE_SPREAD',
                type: 'Email Provider'
            },
            'protonmail.com': {
                tier: 2,
                bonus: 20,
                trust: 88,
                category: 'privacy',
                popularity: 'LITTLE_SPREAD',
                type: 'Corporative'
            },
            'proton.me': {
                tier: 2,
                bonus: 20,
                trust: 88,
                category: 'privacy',
                popularity: 'LITTLE_SPREAD',
                type: 'Corporative'
            },
            'zoho.com': {
                tier: 2,
                bonus: 15,
                trust: 80,
                category: 'business',
                popularity: 'LITTLE_SPREAD',
                type: 'Corporative'
            },
            'aol.com': {
                tier: 2,
                bonus: 15,
                trust: 78,
                category: 'mainstream',
                popularity: 'LITTLE_SPREAD',
                type: 'Email Provider'
            },

            // ====================================
            // TIER 3 - Domínios Brasileiros Confiáveis
            // ====================================
            'uol.com.br': {
                tier: 3,
                bonus: 15,
                trust: 80,
                category: 'brazilian',
                popularity: 'LITTLE_SPREAD',
                type: 'Email Provider'
            },
            'bol.com.br': {
                tier: 3,
                bonus: 15,
                trust: 80,
                category: 'brazilian',
                popularity: 'LITTLE_SPREAD',
                type: 'Email Provider'
            },
            'terra.com.br': {
                tier: 3,
                bonus: 14,
                trust: 78,
                category: 'brazilian',
                popularity: 'LITTLE_SPREAD',
                type: 'Email Provider'
            },
            'globo.com': {
                tier: 3,
                bonus: 16,
                trust: 82,
                category: 'brazilian_corp',
                popularity: 'LITTLE_SPREAD',
                type: 'Corporative'
            },
            'ig.com.br': {
                tier: 3,
                bonus: 14,
                trust: 78,
                category: 'brazilian',
                popularity: 'LITTLE_SPREAD',
                type: 'Email Provider'
            },
            'r7.com': {
                tier: 3,
                bonus: 12,
                trust: 75,
                category: 'brazilian_corp',
                popularity: 'SPREAD',
                type: 'Corporative'
            },
            'folha.com.br': {
                tier: 3,
                bonus: 14,
                trust: 78,
                category: 'brazilian_corp',
                popularity: 'LITTLE_SPREAD',
                type: 'Corporative'
            },
            'estadao.com.br': {
                tier: 3,
                bonus: 14,
                trust: 78,
                category: 'brazilian_corp',
                popularity: 'LITTLE_SPREAD',
                type: 'Corporative'
            },

            // ====================================
            // TIER 4 - Serviços Corporativos/Pagos
            // ====================================
            'fastmail.com': {
                tier: 4,
                bonus: 10,
                trust: 70,
                category: 'paid',
                popularity: 'SPREAD',
                type: 'Corporative'
            },
            'hushmail.com': {
                tier: 4,
                bonus: 10,
                trust: 70,
                category: 'privacy',
                popularity: 'SPREAD',
                type: 'Corporative'
            },
            'runbox.com': {
                tier: 4,
                bonus: 8,
                trust: 65,
                category: 'paid',
                popularity: 'SPREAD',
                type: 'Corporative'
            },
            'mailfence.com': {
                tier: 4,
                bonus: 8,
                trust: 65,
                category: 'privacy',
                popularity: 'SPREAD',
                type: 'Corporative'
            },

            // ====================================
            // TIER 5 - Genéricos (Neutros)
            // Difundido = Confiança Média
            // ====================================
            'mail.com': {
                tier: 5,
                bonus: 0,
                trust: 50,
                category: 'generic',
                popularity: 'SPREAD',
                type: 'Email Provider'
            },
            'email.com': {
                tier: 5,
                bonus: 0,
                trust: 50,
                category: 'generic',
                popularity: 'SPREAD',
                type: 'Email Provider'
            },
            'inbox.com': {
                tier: 5,
                bonus: -2,
                trust: 45,
                category: 'generic',
                popularity: 'SPREAD',
                type: 'Corporative'
            },
            'webmail.com': {
                tier: 5,
                bonus: -2,
                trust: 45,
                category: 'generic',
                popularity: 'SPREAD',
                type: 'Email Provider'
            },

            // ====================================
            // TIER 6 - Suspeitos/Temporários
            // Muito Difundido = Baixa Confiança
            // ====================================
            'tempmail.com': {
                tier: 6,
                bonus: -30,
                trust: 10,
                category: 'disposable',
                popularity: 'VERY_SPREAD',
                type: 'Disposable'
            },
            'guerrillamail.com': {
                tier: 6,
                bonus: -30,
                trust: 10,
                category: 'disposable',
                popularity: 'VERY_SPREAD',
                type: 'Disposable'
            },
            '10minutemail.com': {
                tier: 6,
                bonus: -30,
                trust: 10,
                category: 'disposable',
                popularity: 'VERY_SPREAD',
                type: 'Disposable'
            },
            'mailinator.com': {
                tier: 6,
                bonus: -30,
                trust: 10,
                category: 'disposable',
                popularity: 'VERY_SPREAD',
                type: 'Disposable'
            },
            'throwaway.email': {
                tier: 6,
                bonus: -30,
                trust: 10,
                category: 'disposable',
                popularity: 'VERY_SPREAD',
                type: 'Disposable'
            },
            'maildrop.cc': {
                tier: 6,
                bonus: -30,
                trust: 10,
                category: 'disposable',
                popularity: 'VERY_SPREAD',
                type: 'Disposable'
            }
        };

        this.popularityLabels = {
            'RARELY_SPREAD': 'Raramente Difundido',
            'LITTLE_SPREAD': 'Pouco Difundido',
            'SPREAD': 'Difundido',
            'VERY_SPREAD': 'Muito Difundido'
        };

        this.typeLabels = {
            'Email Provider': 'Provedor de Email',
            'Corporative': 'Corporativo',
            'Disposable': 'Descartável'
        };
    }

    getPopularityScore(domain) {
        if (!domain) return { tier: 5, bonus: 0, trust: 40, category: 'unknown' };

        domain = domain.toLowerCase().trim();

        // Verificar domínio exato
        if (this.domainPopularity[domain]) {
            return this.domainPopularity[domain];
        }

        // Verificar TLD brasileiro genérico
        if (domain.endsWith('.com.br') || domain.endsWith('.net.br') || domain.endsWith('.org.br')) {
            return {
                tier: 4,
                bonus: 5,
                trust: 60,
                category: 'brazilian',
                popularity: 'SPREAD',
                type: 'Corporative'
            };
        }

        // Verificar se é domínio corporativo (não está na lista de providers conhecidos)
        const parts = domain.split('.');
        if (parts.length >= 2) {
            const isGenericTLD = ['.com', '.net', '.org', '.info', '.biz'].some(tld => domain.endsWith(tld));
            if (!isGenericTLD || parts[0].length > 10) {
                // Provável domínio corporativo
                return {
                    tier: 4,
                    bonus: 3,
                    trust: 55,
                    category: 'corporate',
                    popularity: 'SPREAD',
                    type: 'Corporative'
                };
            }
        }

        // Domínio desconhecido
        return {
            tier: 5,
            bonus: 0,
            trust: 40,
            category: 'unknown',
            popularity: 'SPREAD',
            type: 'Unknown'
        };
    }

    getPopularityLabel(domain) {
        const score = this.getPopularityScore(domain);
        return this.popularityLabels[score.popularity] || 'Não Classificado';
    }

    getDomainType(domain) {
        const score = this.getPopularityScore(domain);
        return score.type || 'Unknown';
    }

    getDomainTypeLabel(domain) {
        const type = this.getDomainType(domain);
        return this.typeLabels[type] || type;
    }

    isMainstreamDomain(domain) {
        const score = this.getPopularityScore(domain);
        return score.category === 'mainstream' && score.tier <= 2;
    }

    isCorporativeDomain(domain) {
        const score = this.getPopularityScore(domain);
        return score.type === 'Corporative';
    }

    isDisposableDomain(domain) {
        const score = this.getPopularityScore(domain);
        return score.category === 'disposable' || score.type === 'Disposable';
    }

    shouldOverrideScore(domain) {
        const score = this.getPopularityScore(domain);
        // Override para tier 1 e 2 (muito confiáveis)
        return score.tier <= 2 && score.trust >= 85;
    }

    getMinimumScore(domain) {
        const score = this.getPopularityScore(domain);

        if (score.tier === 1) return 85; // Gmail, Outlook, etc
        if (score.tier === 2) return 75; // iCloud, ProtonMail, etc
        if (score.tier === 3) return 70; // Domínios brasileiros confiáveis
        if (score.tier === 4) return 60; // Corporativos
        if (score.tier === 5) return 40; // Genéricos
        return 20; // Suspeitos
    }
}

module.exports = PopularityScoring;
