// ================================================
// E-commerce Scoring System - VERSÃO CORRIGIDA v2.0
// Sistema de pontuação específico para lojas online
// ================================================

const TrustedDomains = require('./TrustedDomains');

class EcommerceScoring {
    constructor() {
        // Pesos ajustados para melhor balanceamento
        this.weights = {
            tldScore: 15,
            disposableCheck: 20,     // Reduzido de 25
            smtpVerification: 15,    // Reduzido de 20
            patternAnalysis: 15,
            formatQuality: 15,       // Aumentado de 10
            domainTrust: 15,         // Novo - confiança do domínio
            mxRecords: 5            // Novo - verificação MX
        };
        
        // Inicializar módulo de domínios confiáveis
        this.trustedDomains = new TrustedDomains();
        
        // Sistema de log configurável
        this.debug = process.env.DEBUG_SCORING === 'true';
    }
    
    // Método principal com validação de entrada
    calculateScore(validationResults) {
        // Validação de entrada
        if (!validationResults || typeof validationResults !== 'object') {
            this.logDebug('Invalid input: validationResults is null or not an object');
            return this.createEmptyScore('Invalid input');
        }
        
        // Garantir que email existe
        const email = validationResults.email || '';
        const domain = email.split('@')[1] || '';
        
        const scoreData = {
            baseScore: 0,
            finalScore: 0,
            confidence: 'low',
            buyerType: 'unknown',
            riskLevel: 'high',
            fraudProbability: 0,
            recommendations: [],
            breakdown: {},
            insights: {},
            metadata: {
                email: email,
                domain: domain,
                isTrustedDomain: false,
                domainCategory: 'unknown'
            }
        };
        
        // Verificar se é domínio confiável
        const isTrustedDomain = this.trustedDomains.isTrusted(domain);
        const domainCategory = this.trustedDomains.getCategory(domain);
        
        scoreData.metadata.isTrustedDomain = isTrustedDomain;
        scoreData.metadata.domainCategory = domainCategory;
        
        this.logDebug(`Processing email: ${email}, Domain: ${domain}, Trusted: ${isTrustedDomain}`);
        
        // Calcular score base
        let totalScore = 0;
        let totalWeight = 0;
        
        // 1. Domain Trust Score (NOVO)
        const domainTrustPoints = this.trustedDomains.getTrustScore(domain);
        totalScore += domainTrustPoints * this.weights.domainTrust;
        totalWeight += this.weights.domainTrust;
        scoreData.breakdown.domainTrust = {
            points: domainTrustPoints,
            weight: this.weights.domainTrust,
            weighted: domainTrustPoints * this.weights.domainTrust,
            category: domainCategory
        };
        
        // 2. TLD Score
        if (validationResults.tld) {
            const tldPoints = this.calculateTLDPoints(validationResults.tld, isTrustedDomain);
            totalScore += tldPoints * this.weights.tldScore;
            totalWeight += this.weights.tldScore;
            scoreData.breakdown.tld = {
                points: tldPoints,
                weight: this.weights.tldScore,
                weighted: tldPoints * this.weights.tldScore
            };
        }
        
        // 3. Disposable Check com fallback para domínios confiáveis
        if (validationResults.disposable) {
            const disposablePoints = this.calculateDisposablePoints(
                validationResults.disposable, 
                isTrustedDomain
            );
            totalScore += disposablePoints * this.weights.disposableCheck;
            totalWeight += this.weights.disposableCheck;
            scoreData.breakdown.disposable = {
                points: disposablePoints,
                weight: this.weights.disposableCheck,
                weighted: disposablePoints * this.weights.disposableCheck
            };
        }
        
        // 4. SMTP Verification com fallback
        if (validationResults.smtp) {
            const smtpPoints = this.calculateSMTPPoints(
                validationResults.smtp, 
                isTrustedDomain
            );
            totalScore += smtpPoints * this.weights.smtpVerification;
            totalWeight += this.weights.smtpVerification;
            scoreData.breakdown.smtp = {
                points: smtpPoints,
                weight: this.weights.smtpVerification,
                weighted: smtpPoints * this.weights.smtpVerification
            };
        }
        
        // 5. MX Records (NOVO)
        if (validationResults.mx) {
            const mxPoints = this.calculateMXPoints(validationResults.mx, isTrustedDomain);
            totalScore += mxPoints * this.weights.mxRecords;
            totalWeight += this.weights.mxRecords;
            scoreData.breakdown.mx = {
                points: mxPoints,
                weight: this.weights.mxRecords,
                weighted: mxPoints * this.weights.mxRecords
            };
        }
        
        // 6. Pattern Analysis
        if (validationResults.patterns) {
            const patternPoints = this.calculatePatternPoints(validationResults.patterns);
            totalScore += patternPoints * this.weights.patternAnalysis;
            totalWeight += this.weights.patternAnalysis;
            scoreData.breakdown.patterns = {
                points: patternPoints,
                weight: this.weights.patternAnalysis,
                weighted: patternPoints * this.weights.patternAnalysis
            };
        }
        
        // 7. Format Quality - com validação de email
        const formatPoints = this.calculateFormatPoints(email);
        totalScore += formatPoints * this.weights.formatQuality;
        totalWeight += this.weights.formatQuality;
        scoreData.breakdown.format = {
            points: formatPoints,
            weight: this.weights.formatQuality,
            weighted: formatPoints * this.weights.formatQuality
        };
        
        // CORREÇÃO CRÍTICA: Calcular score final corretamente
        // A fórmula correta multiplica por 10 para converter para escala 0-100
        if (totalWeight > 0) {
            scoreData.baseScore = Math.round((totalScore / totalWeight) * 10);
        } else {
            scoreData.baseScore = 0;
        }
        
        // Aplicar boost para domínios muito confiáveis
        if (isTrustedDomain && scoreData.baseScore < 70) {
            const boost = domainCategory === 'mainstream' ? 20 : 15;
            scoreData.baseScore = Math.min(scoreData.baseScore + boost, 85);
            this.logDebug(`Applied trusted domain boost: +${boost} points`);
        }
        
        scoreData.finalScore = Math.max(0, Math.min(100, scoreData.baseScore));
        
        this.logDebug(`Score calculation: Total=${totalScore}, Weight=${totalWeight}, Base=${scoreData.baseScore}, Final=${scoreData.finalScore}`);
        
        // Determinar classificações
        scoreData.buyerType = this.classifyBuyer(scoreData.finalScore, validationResults, isTrustedDomain);
        scoreData.riskLevel = this.assessRisk(scoreData.finalScore);
        scoreData.fraudProbability = this.calculateFraudProbability(
            scoreData.finalScore, 
            validationResults, 
            isTrustedDomain
        );
        scoreData.confidence = this.determineConfidence(scoreData.finalScore);
        
        // Gerar recomendações
        scoreData.recommendations = this.generateRecommendations(
            scoreData.finalScore, 
            validationResults,
            isTrustedDomain
        );
        
        // Adicionar insights
        scoreData.insights = this.generateInsights(validationResults, isTrustedDomain);
        
        return scoreData;
    }
    
    calculateTLDPoints(tldResult, isTrustedDomain) {
        // Domínios confiáveis sempre recebem pontuação alta
        if (isTrustedDomain) return 10;
        
        if (tldResult.isBlocked) return 0;
        if (tldResult.isSuspicious) return 2;
        if (tldResult.isPremium) return 10;
        if (tldResult.valid) return 6;
        return 0;
    }
    
    calculateDisposablePoints(disposableResult, isTrustedDomain) {
        // Domínios confiáveis NUNCA são descartáveis
        if (isTrustedDomain) {
            return 10;
        }
        
        if (disposableResult.isDisposable) {
            return 0;
        }
        
        return 10;
    }
    
    calculateSMTPPoints(smtpResult, isTrustedDomain) {
        // Fallback para domínios confiáveis que bloqueiam SMTP
        if (isTrustedDomain) {
            // Se SMTP falhou mas é domínio confiável, assumir válido
            if (!smtpResult.exists && smtpResult.error) {
                this.logDebug('SMTP failed for trusted domain, applying fallback');
                return 8; // Pontuação alta mas não máxima
            }
            
            // Se passou na verificação
            if (smtpResult.exists) {
                return 10;
            }
        }
        
        // Lógica padrão para outros domínios
        if (!smtpResult.smtp) return 5; // Não verificado
        if (smtpResult.exists && !smtpResult.catchAll) return 10;
        if (smtpResult.catchAll) return 6;
        if (!smtpResult.exists) return 2;
        return 5;
    }
    
    calculateMXPoints(mxResult, isTrustedDomain) {
        if (isTrustedDomain) return 10;
        
        if (mxResult && mxResult.valid) return 10;
        if (mxResult && mxResult.records > 0) return 8;
        
        return 2;
    }
    
    calculatePatternPoints(patternResult) {
        if (!patternResult.suspicious) return 10;
        if (patternResult.suspicionLevel >= 8) return 0;
        if (patternResult.suspicionLevel >= 6) return 3;
        if (patternResult.suspicionLevel >= 4) return 6;
        return 8;
    }
    
    calculateFormatPoints(email) {
        // Validação de entrada
        if (!email || typeof email !== 'string') {
            this.logDebug('Invalid email format: null or not string');
            return 0;
        }
        
        const parts = email.split('@');
        if (parts.length !== 2) {
            return 0;
        }
        
        const localPart = parts[0].toLowerCase();
        
        // Formato profissional (nome.sobrenome)
        if (/^[a-z]+\.[a-z]+$/.test(localPart)) return 10;
        
        // Formato corporativo comum
        if (/^[a-z]+[._-][a-z]+$/.test(localPart)) return 8;
        
        // Nome completo sem separadores (4-20 caracteres)
        if (/^[a-z]{4,20}$/.test(localPart)) return 7;
        
        // Nome simples
        if (/^[a-z]{3,15}$/.test(localPart)) return 6;
        
        // Com alguns números (comum em emails pessoais)
        if (/^[a-z]+[0-9]{1,4}$/.test(localPart)) return 5;
        
        // Formato genérico (info@, contact@, etc)
        if (/^(info|contact|admin|support|sales|hello|contato)/.test(localPart)) return 4;
        
        // Muitos números ou caracteres especiais
        if (/[0-9]{5,}/.test(localPart) || /[^a-z0-9._-]/.test(localPart)) return 2;
        
        // Formato suspeito ou não identificado
        return 3;
    }
    
    classifyBuyer(score, results, isTrustedDomain) {
        if (score >= 80) {
            if (isTrustedDomain) {
                return 'PREMIUM_BUYER';
            }
            return 'TRUSTED_BUYER';
        } else if (score >= 60) {
            return 'REGULAR_BUYER';
        } else if (score >= 40) {
            return 'NEW_BUYER';
        } else if (score >= 20) {
            return 'SUSPICIOUS_BUYER';
        }
        return 'HIGH_RISK_BUYER';
    }
    
    assessRisk(score) {
        if (score >= 80) return 'VERY_LOW';
        if (score >= 60) return 'LOW';
        if (score >= 40) return 'MEDIUM';
        if (score >= 20) return 'HIGH';
        return 'VERY_HIGH';
    }
    
    calculateFraudProbability(score, results, isTrustedDomain) {
        let probability = 100 - score; // Base
        
        // Reduzir significativamente para domínios confiáveis
        if (isTrustedDomain) {
            probability = Math.max(5, probability - 30);
        }
        
        // Ajustes baseados em indicadores
        if (results.disposable && results.disposable.isDisposable && !isTrustedDomain) {
            probability += 20;
        }
        
        if (results.patterns && results.patterns.suspicious) {
            probability += isTrustedDomain ? 5 : 15;
        }
        
        if (results.smtp && !results.smtp.exists && !isTrustedDomain) {
            probability += 10;
        }
        
        return Math.min(95, Math.max(5, probability));
    }
    
    determineConfidence(score) {
        if (score >= 80) return 'very_high';
        if (score >= 60) return 'high';
        if (score >= 40) return 'medium';
        if (score >= 20) return 'low';
        return 'very_low';
    }
    
    generateRecommendations(score, results, isTrustedDomain) {
        const recommendations = [];
        
        if (score >= 80) {
            recommendations.push({
                action: 'APPROVE',
                message: 'Aprovar compra normalmente',
                priority: 'low'
            });
            
            if (isTrustedDomain) {
                recommendations.push({
                    action: 'FAST_CHECKOUT',
                    message: 'Cliente com email de provedor confiável - liberar checkout rápido',
                    priority: 'low'
                });
            }
        } else if (score >= 60) {
            recommendations.push({
                action: 'APPROVE_WITH_MONITORING',
                message: 'Aprovar mas monitorar comportamento',
                priority: 'medium'
            });
        } else if (score >= 40) {
            recommendations.push({
                action: 'REQUEST_VERIFICATION',
                message: 'Solicitar verificação adicional (SMS/WhatsApp)',
                priority: 'high'
            });
            
            if (!isTrustedDomain) {
                recommendations.push({
                    action: 'LIMIT_PAYMENT_METHODS',
                    message: 'Limitar métodos de pagamento (apenas PIX/boleto)',
                    priority: 'high'
                });
            }
        } else {
            recommendations.push({
                action: 'MANUAL_REVIEW',
                message: 'Enviar para análise manual',
                priority: 'critical'
            });
            
            if (!isTrustedDomain) {
                recommendations.push({
                    action: 'BLOCK_HIGH_VALUE',
                    message: 'Bloquear compras acima de R$ 500',
                    priority: 'critical'
                });
            }
        }
        
        // Recomendações específicas
        if (results.disposable && results.disposable.isDisposable && !isTrustedDomain) {
            recommendations.push({
                action: 'BLOCK_EMAIL',
                message: 'Email temporário detectado - solicitar email permanente',
                priority: 'critical'
            });
        }
        
        if (results.patterns && results.patterns.suggestions && results.patterns.suggestions.length > 0) {
            recommendations.push({
                action: 'SUGGEST_CORRECTION',
                message: `Possível erro de digitação - sugerir: ${results.patterns.suggestions[0].suggestion}`,
                priority: 'medium'
            });
        }
        
        return recommendations;
    }
    
    generateInsights(results, isTrustedDomain) {
        const insights = {
            emailAge: 'unknown',
            socialPresence: false,
            corporateEmail: false,
            personalEmail: false,
            trustedProvider: isTrustedDomain,
            likelyFirstPurchase: true,
            deviceMatch: true
        };
        
        // Determinar tipo de email baseado no domínio
        if (results.email) {
            const domain = results.email.split('@')[1];
            const category = this.trustedDomains.getCategory(domain);
            
            if (category === 'mainstream' || category === 'brazilian') {
                insights.personalEmail = true;
            } else if (category === 'professional' || category === 'educational') {
                insights.corporateEmail = true;
                insights.likelyFirstPurchase = false;
            }
        }
        
        // Presença social (simulada - em produção seria via API)
        if (results.score > 70 || isTrustedDomain) {
            insights.socialPresence = true;
        }
        
        return insights;
    }
    
    // Método auxiliar para criar score vazio
    createEmptyScore(reason) {
        return {
            baseScore: 0,
            finalScore: 0,
            confidence: 'none',
            buyerType: 'INVALID',
            riskLevel: 'BLOCKED',
            fraudProbability: 100,
            recommendations: [{
                action: 'BLOCK',
                message: reason,
                priority: 'critical'
            }],
            breakdown: {},
            insights: {},
            error: reason
        };
    }
    
    // Sistema de log configurável
    logDebug(message) {
        if (this.debug) {
            console.log(`[EcommerceScoring] ${message}`);
        }
    }
}

module.exports = EcommerceScoring;
