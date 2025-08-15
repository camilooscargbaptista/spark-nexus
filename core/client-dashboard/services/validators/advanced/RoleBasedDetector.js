// ================================================
// Role-Based Email Detector
// Detecta emails funcionais/não pessoais
// ================================================

class RoleBasedDetector {
    constructor(options = {}) {
        this.debug = options.debug || false;

        // ================================================
        // CATEGORIAS DE EMAILS ROLE-BASED
        // ================================================
        this.categories = {
            administrative: {
                patterns: [
                    'admin', 'administrator', 'administrador', 'administracao',
                    'webmaster', 'postmaster', 'hostmaster', 'root',
                    'system', 'sys', 'operator', 'operations'
                ],
                risk: 'high',
                description: 'Emails administrativos',
                recommendation: 'Evitar - emails não pessoais administrativos'
            },

            support: {
                patterns: [
                    'support', 'suporte', 'help', 'helpdesk', 'ajuda',
                    'customer', 'cliente', 'service', 'servico', 'atendimento',
                    'contact', 'contato', 'contacts', 'contatos', 'feedback',
                    'faleconosco', 'sac', 'care', 'customercare'
                ],
                risk: 'medium',
                description: 'Emails de suporte',
                recommendation: 'Usar com cautela - emails de departamento'
            },

            sales: {
                patterns: [
                    'sales', 'vendas', 'venda', 'comercial', 'business',
                    'vendor', 'vendedor', 'partner', 'partners', 'parceiro',
                    'parceiros', 'reseller', 'revendedor', 'distributor',
                    'negocios', 'orcamento', 'cotacao', 'pedidos'
                ],
                risk: 'low',
                description: 'Emails comerciais',
                recommendation: 'OK para B2B - emails de vendas'
            },

            marketing: {
                patterns: [
                    'marketing', 'mkt', 'newsletter', 'news', 'noticias',
                    'media', 'midia', 'press', 'imprensa', 'pr',
                    'communication', 'comunicacao', 'campaign', 'campanha',
                    'promo', 'promocao', 'publicidade', 'advertising'
                ],
                risk: 'low',
                description: 'Emails de marketing',
                recommendation: 'OK para comunicação B2B'
            },

            info: {
                patterns: [
                    'info', 'information', 'informacao', 'informacoes',
                    'about', 'sobre', 'faq', 'questions', 'perguntas',
                    'duvidas', 'enquiry', 'inquiry', 'consulta'
                ],
                risk: 'medium',
                description: 'Emails informativos',
                recommendation: 'Usar com moderação - emails genéricos'
            },

            noreply: {
                patterns: [
                    'noreply', 'no-reply', 'donotreply', 'do-not-reply',
                    'naoresp', 'naoresponda', 'nao-responda', 'bounce',
                    'bounces', 'bounced', 'mailer-daemon', 'postmaster',
                    'automated', 'automatico', 'notification', 'notificacao'
                ],
                risk: 'critical',
                description: 'Emails não monitorados',
                recommendation: 'NÃO ENVIAR - emails não são lidos'
            },

            technical: {
                patterns: [
                    'tech', 'technical', 'tecnico', 'ti', 'it',
                    'dev', 'developer', 'desenvolvimento', 'engineering',
                    'engenharia', 'security', 'seguranca', 'abuse',
                    'bug', 'bugs', 'api', 'integration', 'integracao'
                ],
                risk: 'high',
                description: 'Emails técnicos',
                recommendation: 'Evitar - emails de departamento técnico'
            },

            hr: {
                patterns: [
                    'hr', 'rh', 'careers', 'carreiras', 'jobs',
                    'vagas', 'recruitment', 'recrutamento', 'recruiter',
                    'talent', 'talentos', 'hiring', 'contratacao',
                    'cv', 'resume', 'curriculo', 'trabalheconosco'
                ],
                risk: 'medium',
                description: 'Emails de RH',
                recommendation: 'Apenas para recrutamento/vagas'
            },

            finance: {
                patterns: [
                    'billing', 'cobranca', 'finance', 'financeiro',
                    'accounting', 'contabilidade', 'invoice', 'fatura',
                    'payment', 'payments', 'pagamento', 'pagamentos',
                    'treasury', 'tesouraria', 'fiscal', 'tax'
                ],
                risk: 'high',
                description: 'Emails financeiros',
                recommendation: 'Apenas para transações financeiras'
            },

            legal: {
                patterns: [
                    'legal', 'juridico', 'compliance', 'law',
                    'advocacia', 'attorney', 'advogado', 'contract',
                    'contrato', 'terms', 'termos', 'privacy',
                    'privacidade', 'lgpd', 'gdpr'
                ],
                risk: 'high',
                description: 'Emails jurídicos',
                recommendation: 'Apenas para assuntos legais'
            },

            social: {
                patterns: [
                    'facebook', 'twitter', 'instagram', 'linkedin',
                    'youtube', 'social', 'socialmedia', 'redessociais',
                    'blog', 'community', 'comunidade', 'forum'
                ],
                risk: 'low',
                description: 'Emails de redes sociais',
                recommendation: 'OK para comunicação social'
            }
        };

        // Estatísticas
        this.stats = {
            totalChecked: 0,
            roleBasedDetected: 0,
            personalDetected: 0,
            byCategory: {}
        };

        // Inicializar estatísticas por categoria
        Object.keys(this.categories).forEach(category => {
            this.stats.byCategory[category] = 0;
        });
    }

    // ================================================
    // MÉTODO PRINCIPAL - DETECTAR ROLE-BASED
    // ================================================
    detectRoleBased(email) {
        this.stats.totalChecked++;

        const result = {
            email: email,
            isRoleBased: false,
            isPersonal: true,
            category: null,
            pattern: null,
            risk: 'none',
            confidence: 0,
            description: 'Email pessoal',
            recommendation: 'Email pessoal - aprovado para marketing',
            details: {
                localPart: null,
                matchedPatterns: [],
                analysis: {}
            },
            timestamp: new Date().toISOString()
        };

        if (!email || !email.includes('@')) {
            result.description = 'Email inválido';
            result.recommendation = 'Email inválido para análise';
            return result;
        }

        const localPart = email.split('@')[0].toLowerCase();
        const domain = email.split('@')[1].toLowerCase();

        result.details.localPart = localPart;

        // ================================================
        // 1. VERIFICAR CADA CATEGORIA
        // ================================================
        const matches = [];

        for (const [category, config] of Object.entries(this.categories)) {
            for (const pattern of config.patterns) {
                // Verificar match exato
                if (localPart === pattern) {
                    matches.push({
                        category: category,
                        pattern: pattern,
                        matchType: 'exact',
                        confidence: 1.0
                    });
                    break;
                }

                // Verificar se começa com pattern
                if (localPart.startsWith(pattern + '.') ||
                    localPart.startsWith(pattern + '-') ||
                    localPart.startsWith(pattern + '_')) {
                    matches.push({
                        category: category,
                        pattern: pattern,
                        matchType: 'prefix',
                        confidence: 0.9
                    });
                    break;
                }

                // Verificar se termina com pattern
                if (localPart.endsWith('.' + pattern) ||
                    localPart.endsWith('-' + pattern) ||
                    localPart.endsWith('_' + pattern)) {
                    matches.push({
                        category: category,
                        pattern: pattern,
                        matchType: 'suffix',
                        confidence: 0.8
                    });
                    break;
                }

                // Verificar se contém pattern (menor confiança)
                if (localPart.includes(pattern) && pattern.length > 3) {
                    matches.push({
                        category: category,
                        pattern: pattern,
                        matchType: 'contains',
                        confidence: 0.6
                    });
                }
            }
        }

        result.details.matchedPatterns = matches;

        // ================================================
        // 2. DETERMINAR CATEGORIA PRINCIPAL
        // ================================================
        if (matches.length > 0) {
            // Ordenar por confiança
            matches.sort((a, b) => b.confidence - a.confidence);

            const bestMatch = matches[0];
            const category = this.categories[bestMatch.category];

            result.isRoleBased = true;
            result.isPersonal = false;
            result.category = bestMatch.category;
            result.pattern = bestMatch.pattern;
            result.risk = category.risk;
            result.confidence = bestMatch.confidence;
            result.description = category.description;
            result.recommendation = category.recommendation;

            // Atualizar estatísticas
            this.stats.roleBasedDetected++;
            this.stats.byCategory[bestMatch.category]++;
        } else {
            // ================================================
            // 3. ANÁLISE ADICIONAL PARA EMAILS PESSOAIS
            // ================================================
            result.details.analysis = this.analyzePersonalEmail(localPart);

            // Verificar se parece nome pessoal
            if (result.details.analysis.likelyPersonal) {
                result.confidence = result.details.analysis.confidence;
                result.description = 'Email pessoal identificado';
                result.recommendation = 'Email pessoal - ideal para marketing direto';
                this.stats.personalDetected++;
            } else if (result.details.analysis.generic) {
                result.isPersonal = false;
                result.risk = 'low';
                result.confidence = 0.5;
                result.description = 'Email genérico';
                result.recommendation = 'Email genérico - usar com moderação';
            }
        }

        // ================================================
        // 4. ANÁLISE BASEADA NO DOMÍNIO
        // ================================================
        if (domain) {
            // Domínios corporativos têm maior chance de emails role-based
            const corporateDomains = ['company', 'corp', 'enterprise', 'group'];
            for (const corp of corporateDomains) {
                if (domain.includes(corp)) {
                    result.confidence = Math.min(1.0, result.confidence + 0.1);
                    break;
                }
            }
        }

        this.logDebug(`Role-based detection para ${email}: isRoleBased=${result.isRoleBased}, category=${result.category}`);

        return result;
    }

    // ================================================
    // ANALISAR SE É EMAIL PESSOAL
    // ================================================
    analyzePersonalEmail(localPart) {
        const analysis = {
            likelyPersonal: false,
            confidence: 0,
            generic: false,
            indicators: []
        };

        // Padrões de nomes pessoais
        const personalPatterns = [
            /^[a-z]+\.[a-z]+$/,           // nome.sobrenome
            /^[a-z]+_[a-z]+$/,            // nome_sobrenome
            /^[a-z]+\-[a-z]+$/,           // nome-sobrenome
            /^[a-z]{2,}[0-9]{0,4}$/,      // nome ou nome123
            /^[a-z]+\.[a-z]+[0-9]{0,4}$/  // nome.sobrenome123
        ];

        for (const pattern of personalPatterns) {
            if (pattern.test(localPart)) {
                analysis.likelyPersonal = true;
                analysis.confidence = 0.8;
                analysis.indicators.push('Formato de nome pessoal');
                break;
            }
        }

        // Verificar se é muito genérico
        const genericPatterns = [
            /^user[0-9]+$/,
            /^test[0-9]+$/,
            /^email[0-9]+$/,
            /^mail[0-9]+$/,
            /^[a-z]{1,2}[0-9]{5,}$/  // a12345
        ];

        for (const pattern of genericPatterns) {
            if (pattern.test(localPart)) {
                analysis.generic = true;
                analysis.confidence = 0.3;
                analysis.indicators.push('Formato genérico');
                break;
            }
        }

        // Verificar comprimento
        if (localPart.length >= 3 && localPart.length <= 20 && !analysis.generic) {
            analysis.confidence = Math.min(1.0, analysis.confidence + 0.2);
            analysis.indicators.push('Comprimento típico de nome');
        }

        // Verificar se tem apenas letras (possível nome)
        if (/^[a-z]+$/.test(localPart) && localPart.length >= 3 && localPart.length <= 15) {
            analysis.likelyPersonal = true;
            analysis.confidence = Math.max(analysis.confidence, 0.6);
            analysis.indicators.push('Possível primeiro nome');
        }

        return analysis;
    }

    // ================================================
    // MÉTODO PARA OBTER RECOMENDAÇÃO DETALHADA
    // ================================================
    getDetailedRecommendation(result) {
        const recommendations = {
            action: 'ALLOW',
            priority: 'low',
            details: []
        };

        if (!result.isRoleBased) {
            recommendations.action = 'ALLOW';
            recommendations.priority = 'low';
            recommendations.details.push('Email pessoal - ideal para campanhas de marketing');
            recommendations.details.push('Maior probabilidade de engajamento');
            return recommendations;
        }

        switch (result.risk) {
            case 'critical':
                recommendations.action = 'BLOCK';
                recommendations.priority = 'critical';
                recommendations.details.push('NÃO ENVIAR - Email não monitorado');
                recommendations.details.push('Envios serão desperdiçados');
                recommendations.details.push('Pode prejudicar reputação do remetente');
                break;

            case 'high':
                recommendations.action = 'AVOID';
                recommendations.priority = 'high';
                recommendations.details.push('EVITAR - Email de departamento');
                recommendations.details.push('Baixa taxa de engajamento esperada');
                recommendations.details.push('Considerar contato direto com pessoa');
                break;

            case 'medium':
                recommendations.action = 'CAUTION';
                recommendations.priority = 'medium';
                recommendations.details.push('USAR COM CAUTELA');
                recommendations.details.push('Avaliar relevância do conteúdo');
                recommendations.details.push('Preferir emails pessoais quando possível');
                break;

            case 'low':
                recommendations.action = 'ALLOW';
                recommendations.priority = 'low';
                recommendations.details.push('OK PARA USO');
                recommendations.details.push('Apropriado para comunicação B2B');
                recommendations.details.push('Monitorar taxa de engajamento');
                break;
        }

        return recommendations;
    }

    // ================================================
    // ESTATÍSTICAS
    // ================================================
    getStatistics() {
        const total = this.stats.totalChecked || 1; // Evitar divisão por zero

        return {
            ...this.stats,
            roleBasedRate: ((this.stats.roleBasedDetected / total) * 100).toFixed(2) + '%',
            personalRate: ((this.stats.personalDetected / total) * 100).toFixed(2) + '%',
            topCategories: Object.entries(this.stats.byCategory)
                .filter(([_, count]) => count > 0)
                .sort((a, b) => b[1] - a[1])
                .slice(0, 5)
                .map(([category, count]) => ({
                    category: category,
                    count: count,
                    percentage: ((count / total) * 100).toFixed(2) + '%',
                    risk: this.categories[category].risk
                }))
        };
    }

    resetStatistics() {
        this.stats = {
            totalChecked: 0,
            roleBasedDetected: 0,
            personalDetected: 0,
            byCategory: {}
        };

        Object.keys(this.categories).forEach(category => {
            this.stats.byCategory[category] = 0;
        });

        this.logDebug('Estatísticas de role-based resetadas');
    }

    logDebug(message) {
        if (this.debug) {
            console.log(`[RoleBasedDetector] ${message}`);
        }
    }
}

module.exports = RoleBasedDetector;
