// ================================================
// E-commerce Scoring System - ENHANCED v3.0
// Sistema com validações ultra rigorosas
// ================================================

const TrustedDomains = require('./TrustedDomains');
const BlockedDomains = require('./BlockedDomains');

class EcommerceScoring {
    constructor() {
        // Pesos ajustados para validação mais rigorosa
        this.weights = {
            domainBlocked: 30,      // NOVO - peso alto para domínios bloqueados
            tldScore: 10,
            disposableCheck: 20,
            smtpVerification: 15,
            patternAnalysis: 10,
            formatQuality: 10,
            domainTrust: 5
        };
        
        // Threshold mais rigoroso
        this.scoreThreshold = {
            invalid: 50,        // < 50 = Inválido
            suspicious: 70,     // 50-69 = Suspeito
            valid: 70          // >= 70 = Válido
        };
        
        // Inicializar módulos
        this.trustedDomains = new TrustedDomains();
        this.blockedDomains = new BlockedDomains();
        
        this.debug = process.env.DEBUG_SCORING === 'true';
    }
    
    calculateScore(validationResults) {
        // Validação de entrada
        if (!validationResults || typeof validationResults !== 'object') {
            return this.createEmptyScore('Invalid input');
        }
        
        const email = validationResults.email || '';
        const domain = email.split('@')[1] || '';
        
        // PRIMEIRO: Verificar se está bloqueado
        const blockCheck = this.blockedDomains.isBlocked(email);
        
        if (blockCheck.blocked) {
            this.logDebug(`Email bloqueado: ${email} - Razão: ${blockCheck.reason}`);
            return {
                baseScore: 0,
                finalScore: 0,
                valid: false,
                confidence: 'certain',
                buyerType: 'BLOCKED',
                riskLevel: 'BLOCKED',
                fraudProbability: 100,
                recommendations: [{
                    action: 'BLOCK',
                    message: blockCheck.reason,
                    priority: 'critical'
                }],
                breakdown: {
                    blocked: {
                        reason: blockCheck.reason,
                        category: blockCheck.category,
                        severity: blockCheck.severity
                    }
                },
                insights: {
                    blocked: true,
                    blockReason: blockCheck.reason
                },
                metadata: {
                    email: email,
                    domain: domain,
                    isBlocked: true,
                    blockCategory: blockCheck.category
                }
            };
        }
        
        const scoreData = {
            baseScore: 0,
            finalScore: 0,
            valid: false,
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
                domainCategory: 'unknown',
                suspicious: blockCheck.suspicious || false
            }
        };
        
        // Verificar se é domínio confiável
        const isTrustedDomain = this.trustedDomains.isTrusted(domain);
        const domainCategory = this.trustedDomains.getCategory(domain);
        
        scoreData.metadata.isTrustedDomain = isTrustedDomain;
        scoreData.metadata.domainCategory = domainCategory;
        
        // Calcular score
        let totalScore = 0;
        let totalWeight = 0;
        
        // Penalidade se for suspeito
        if (blockCheck.suspicious) {
            const penalty = blockCheck.penaltyScore || 20;
            totalScore -= penalty * 3; // Penalidade tripla
            scoreData.breakdown.suspicious = {
                penalty: penalty,
                reason: blockCheck.reason
            };
        }
        
        // 1. Domain Trust Score
        const domainTrustPoints = isTrustedDomain ? 10 : 
                                  blockCheck.suspicious ? 2 : 5;
        totalScore += domainTrustPoints * this.weights.domainTrust;
        totalWeight += this.weights.domainTrust;
        scoreData.breakdown.domainTrust = {
            points: domainTrustPoints,
            weight: this.weights.domainTrust,
            weighted: domainTrustPoints * this.weights.domainTrust
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
        
        // 3. Disposable Check - MAIS RIGOROSO
        if (validationResults.disposable) {
            const disposablePoints = this.calculateDisposablePoints(
                validationResults.disposable, 
                isTrustedDomain,
                domain
            );
            totalScore += disposablePoints * this.weights.disposableCheck;
            totalWeight += this.weights.disposableCheck;
            scoreData.breakdown.disposable = {
                points: disposablePoints,
                weight: this.weights.disposableCheck,
                weighted: disposablePoints * this.weights.disposableCheck
            };
        }
        
        // 4. SMTP Verification
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
        
        // 5. Pattern Analysis - MAIS RIGOROSO
        if (validationResults.patterns) {
            const patternPoints = this.calculatePatternPoints(
                validationResults.patterns,
                blockCheck.suspicious
            );
            totalScore += patternPoints * this.weights.patternAnalysis;
            totalWeight += this.weights.patternAnalysis;
            scoreData.breakdown.patterns = {
                points: patternPoints,
                weight: this.weights.patternAnalysis,
                weighted: patternPoints * this.weights.patternAnalysis
            };
        }
        
        // 6. Format Quality
        const formatPoints = this.calculateFormatPoints(email, blockCheck.suspicious);
        totalScore += formatPoints * this.weights.formatQuality;
        totalWeight += this.weights.formatQuality;
        scoreData.breakdown.format = {
            points: formatPoints,
            weight: this.weights.formatQuality,
            weighted: formatPoints * this.weights.formatQuality
        };
        
        // Calcular score final
        if (totalWeight > 0) {
            scoreData.baseScore = Math.round((totalScore / totalWeight) * 10);
        } else {
            scoreData.baseScore = 0;
        }
        
        // Boost apenas para domínios MUITO confiáveis
        if (isTrustedDomain && domainCategory === 'mainstream' && scoreData.baseScore < 70) {
            scoreData.baseScore = Math.min(scoreData.baseScore + 15, 75);
        }
        
        // Garantir que emails suspeitos nunca tenham score alto
        if (blockCheck.suspicious && scoreData.baseScore > 60) {
            scoreData.baseScore = 60;
        }
        
        scoreData.finalScore = Math.max(0, Math.min(100, scoreData.baseScore));
        
        // Determinar validade baseado no threshold
        scoreData.valid = scoreData.finalScore >= this.scoreThreshold.valid;
        
        // Classificações
        scoreData.buyerType = this.classifyBuyer(scoreData.finalScore, blockCheck.suspicious);
        scoreData.riskLevel = this.assessRisk(scoreData.finalScore);
        scoreData.fraudProbability = this.calculateFraudProbability(
            scoreData.finalScore, 
            validationResults, 
            isTrustedDomain,
            blockCheck.suspicious
        );
        scoreData.confidence = this.determineConfidence(scoreData.finalScore);
        
        // Recomendações
        scoreData.recommendations = this.generateRecommendations(
            scoreData.finalScore, 
            validationResults,
            isTrustedDomain,
            blockCheck
        );
        
        // Insights
        scoreData.insights = this.generateInsights(
            validationResults, 
            isTrustedDomain,
            blockCheck
        );
        
        this.logDebug(`Score final para ${email}: ${scoreData.finalScore} - Válido: ${scoreData.valid}`);
        
        return scoreData;
    }
    
    calculateTLDPoints(tldResult, isTrustedDomain) {
        if (isTrustedDomain) return 10;
        if (tldResult.isBlocked) return 0;
        if (tldResult.isSuspicious) return 2;
        if (tldResult.isPremium) return 10;
        if (tldResult.valid) return 6;
        return 0;
    }
    
    calculateDisposablePoints(disposableResult, isTrustedDomain, domain) {
        if (isTrustedDomain) return 10;
        
        // Verificação adicional para domínios suspeitos
        if (domain) {
            const suspiciousKeywords = ['temp', 'trash', 'disposable', 'fake', 'minute'];
            for (const keyword of suspiciousKeywords) {
                if (domain.includes(keyword)) {
                    return 0;
                }
            }
        }
        
        if (disposableResult.isDisposable) return 0;
        return 10;
    }
    
    calculateSMTPPoints(smtpResult, isTrustedDomain) {
        if (isTrustedDomain && !smtpResult.exists && smtpResult.error) {
            return 7; // Fallback para domínios confiáveis
        }
        
        if (!smtpResult.smtp) return 3;
        if (smtpResult.exists && !smtpResult.catchAll) return 10;
        if (smtpResult.catchAll) return 5;
        if (!smtpResult.exists) return 0;
        return 3;
    }
    
    calculatePatternPoints(patternResult, isSuspicious) {
        let points = 10;
        
        if (patternResult.suspicious) {
            points = Math.max(0, 10 - patternResult.suspicionLevel);
        }
        
        // Penalidade adicional se já foi marcado como suspeito
        if (isSuspicious) {
            points = Math.max(0, points - 3);
        }
        
        return points;
    }
    
    calculateFormatPoints(email, isSuspicious) {
        if (!email || typeof email !== 'string') return 0;
        
        const parts = email.split('@');
        if (parts.length !== 2) return 0;
        
        const localPart = parts[0].toLowerCase();
        
        // Penalizar emails genéricos
        const genericPrefixes = ['test', 'admin', 'user', 'info', 'contact', 'support'];
        for (const prefix of genericPrefixes) {
            if (localPart === prefix || localPart.startsWith(prefix)) {
                return isSuspicious ? 0 : 2;
            }
        }
        
        // Formato profissional
        if (/^[a-z]+\.[a-z]+$/.test(localPart)) return 10;
        
        // Formato corporativo
        if (/^[a-z]+[._-][a-z]+$/.test(localPart)) return 8;
        
        // Nome completo
        if (/^[a-z]{4,20}$/.test(localPart)) return 6;
        
        // Com números moderados
        if (/^[a-z]+[0-9]{1,3}$/.test(localPart)) return 4;
        
        // Muitos números ou caracteres especiais
        if (/[0-9]{4,}/.test(localPart)) return 1;
        
        return 3;
    }
    
    classifyBuyer(score, isSuspicious) {
        if (isSuspicious) {
            return score >= 70 ? 'SUSPICIOUS_BUYER' : 'HIGH_RISK_BUYER';
        }
        
        if (score >= 80) return 'TRUSTED_BUYER';
        if (score >= 70) return 'REGULAR_BUYER';
        if (score >= 60) return 'NEW_BUYER';
        if (score >= 50) return 'SUSPICIOUS_BUYER';
        return 'HIGH_RISK_BUYER';
    }
    
    assessRisk(score) {
        if (score >= 80) return 'VERY_LOW';
        if (score >= 70) return 'LOW';
        if (score >= 60) return 'MEDIUM';
        if (score >= 50) return 'HIGH';
        return 'VERY_HIGH';
    }
    
    calculateFraudProbability(score, results, isTrustedDomain, isSuspicious) {
        let probability = 100 - score;
        
        if (isTrustedDomain) {
            probability = Math.max(5, probability - 20);
        }
        
        if (isSuspicious) {
            probability = Math.min(95, probability + 30);
        }
        
        if (results.disposable && results.disposable.isDisposable) {
            probability = Math.min(95, probability + 25);
        }
        
        if (results.smtp && !results.smtp.exists) {
            probability = Math.min(95, probability + 15);
        }
        
        return Math.min(95, Math.max(5, probability));
    }
    
    determineConfidence(score) {
        if (score >= 80) return 'very_high';
        if (score >= 70) return 'high';
        if (score >= 60) return 'medium';
        if (score >= 50) return 'low';
        return 'very_low';
    }
    
    generateRecommendations(score, results, isTrustedDomain, blockCheck) {
        const recommendations = [];
        
        if (blockCheck.suspicious) {
            recommendations.push({
                action: 'WARNING',
                message: `Email suspeito: ${blockCheck.reason}`,
                priority: 'high'
            });
        }
        
        if (score >= 70) {
            recommendations.push({
                action: 'APPROVE',
                message: 'Email válido - aprovar com monitoramento padrão',
                priority: 'low'
            });
        } else if (score >= 50) {
            recommendations.push({
                action: 'MANUAL_REVIEW',
                message: 'Email duvidoso - revisar manualmente',
                priority: 'high'
            });
            recommendations.push({
                action: 'REQUEST_VERIFICATION',
                message: 'Solicitar verificação adicional via SMS',
                priority: 'high'
            });
        } else {
            recommendations.push({
                action: 'REJECT',
                message: 'Email inválido ou de alto risco - rejeitar',
                priority: 'critical'
            });
            recommendations.push({
                action: 'SUGGEST_ALTERNATIVE',
                message: 'Solicitar email alternativo válido',
                priority: 'critical'
            });
        }
        
        return recommendations;
    }
    
    generateInsights(results, isTrustedDomain, blockCheck) {
        return {
            trustedProvider: isTrustedDomain,
            suspicious: blockCheck.suspicious || false,
            blockReason: blockCheck.reason || null,
            requiresVerification: results.score < 70,
            riskFactors: []
        };
    }
    
    createEmptyScore(reason) {
        return {
            baseScore: 0,
            finalScore: 0,
            valid: false,
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
    
    logDebug(message) {
        if (this.debug) {
            console.log(`[EcommerceScoring] ${message}`);
        }
    }
}

module.exports = EcommerceScoring;
