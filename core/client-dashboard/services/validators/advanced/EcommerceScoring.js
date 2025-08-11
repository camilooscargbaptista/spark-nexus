// ================================================
// E-commerce Scoring System
// Sistema de pontuação específico para lojas online
// ================================================

class EcommerceScoring {
    constructor() {
        this.weights = {
            tldScore: 15,
            disposableCheck: 25,
            smtpVerification: 20,
            patternAnalysis: 15,
            formatQuality: 10,
            domainAge: 10,
            reputation: 5
        };
    }

    calculateScore(validationResults) {
        const scoreData = {
            baseScore: 0,
            finalScore: 0,
            confidence: 'low',
            buyerType: 'unknown',
            riskLevel: 'high',
            fraudProbability: 0,
            recommendations: [],
            breakdown: {},
            insights: {}
        };

        // Calcular score base
        let totalScore = 0;
        let totalWeight = 0;

        // TLD Score
        if (validationResults.tld) {
            const tldPoints = this.calculateTLDPoints(validationResults.tld);
            totalScore += tldPoints * this.weights.tldScore;
            totalWeight += this.weights.tldScore;
            scoreData.breakdown.tld = {
                points: tldPoints,
                weight: this.weights.tldScore,
                weighted: tldPoints * this.weights.tldScore
            };
        }

        // Disposable Check
        if (validationResults.disposable) {
            const disposablePoints = validationResults.disposable.isDisposable ? 0 : 10;
            totalScore += disposablePoints * this.weights.disposableCheck;
            totalWeight += this.weights.disposableCheck;
            scoreData.breakdown.disposable = {
                points: disposablePoints,
                weight: this.weights.disposableCheck,
                weighted: disposablePoints * this.weights.disposableCheck
            };
        }

        // SMTP Verification
        if (validationResults.smtp) {
            const smtpPoints = this.calculateSMTPPoints(validationResults.smtp);
            totalScore += smtpPoints * this.weights.smtpVerification;
            totalWeight += this.weights.smtpVerification;
            scoreData.breakdown.smtp = {
                points: smtpPoints,
                weight: this.weights.smtpVerification,
                weighted: smtpPoints * this.weights.smtpVerification
            };
        }

        // Pattern Analysis
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

        // Format Quality
        console.log('validationResults: ', validationResults);
        console.log('validationResults.email: ', validationResults.email);

        const formatPoints = this.calculateFormatPoints(validationResults.email);
        console.log('formatPoints ------', formatPoints);

        totalScore += formatPoints * this.weights.formatQuality;
        totalWeight += this.weights.formatQuality;
        scoreData.breakdown.format = {
            points: formatPoints,
            weight: this.weights.formatQuality,
            weighted: formatPoints * this.weights.formatQuality
        };

        // Calcular score final (0-100)
        console.log('totalScore: ---- ', totalScore);
        console.log('totalWeight: ---- ', totalWeight);

        scoreData.baseScore = totalWeight > 0 ? Math.round(totalScore / totalWeight) : 0;
        console.log('baseScore ------ ', scoreData.baseScore);

        scoreData.finalScore = Math.max(0, Math.min(100, scoreData.baseScore));
        console.log('finalScore ------- ', scoreData.finalScore);


        // Determinar classificações
        scoreData.buyerType = this.classifyBuyer(scoreData.finalScore, validationResults);
        scoreData.riskLevel = this.assessRisk(scoreData.finalScore);
        scoreData.fraudProbability = this.calculateFraudProbability(scoreData.finalScore, validationResults);
        scoreData.confidence = this.determineConfidence(scoreData.finalScore);

        // Gerar recomendações
        scoreData.recommendations = this.generateRecommendations(scoreData.finalScore, validationResults);

        // Adicionar insights
        scoreData.insights = this.generateInsights(validationResults);

        return scoreData;
    }

    calculateTLDPoints(tldResult) {
        if (tldResult.isBlocked) return 0;
        if (tldResult.isSuspicious) return 2;
        if (tldResult.isPremium) return 10;
        if (tldResult.valid) return 6;
        return 0;
    }

    calculateSMTPPoints(smtpResult) {
        if (!smtpResult.smtp) return 5; // Não verificado
        if (smtpResult.exists && !smtpResult.catchAll) return 10;
        if (smtpResult.catchAll) return 6;
        if (!smtpResult.exists) return 2;
        return 5;
    }

    calculatePatternPoints(patternResult) {
        if (!patternResult.suspicious) return 10;
        if (patternResult.suspicionLevel >= 8) return 0;
        if (patternResult.suspicionLevel >= 6) return 3;
        if (patternResult.suspicionLevel >= 4) return 6;
        return 8;
    }

    calculateFormatPoints(email) {
        const [localPart] = email.split('@');

        // Formato profissional (nome.sobrenome)
        if (/^[a-z]+\.[a-z]+/.test(localPart)) return 10;

        // Formato corporativo comum
        if (/^[a-z]+[._-][a-z]+/.test(localPart)) return 8;

        // Nome simples
        if (/^[a-z]{3,15}$/.test(localPart)) return 6;

        // Formato genérico (info@, contact@, etc)
        if (/^(info|contact|admin|support|sales)/.test(localPart)) return 4;

        // Formato suspeito
        return 2;
    }

    classifyBuyer(score, results) {
        if (score >= 80) {
            if (results.email && results.email.includes('.')) {
                return 'PREMIUM_BUYER'; // Comprador premium
            }
            return 'TRUSTED_BUYER'; // Comprador confiável
        } else if (score >= 60) {
            return 'REGULAR_BUYER'; // Comprador regular
        } else if (score >= 40) {
            return 'NEW_BUYER'; // Comprador novo/não verificado
        } else if (score >= 20) {
            return 'SUSPICIOUS_BUYER'; // Comprador suspeito
        }
        return 'HIGH_RISK_BUYER'; // Alto risco
    }

    assessRisk(score) {
        if (score >= 80) return 'VERY_LOW';
        if (score >= 60) return 'LOW';
        if (score >= 40) return 'MEDIUM';
        if (score >= 20) return 'HIGH';
        return 'VERY_HIGH';
    }

    calculateFraudProbability(score, results) {
        let probability = 100 - score; // Base

        // Ajustes baseados em indicadores
        if (results.disposable && results.disposable.isDisposable) {
            probability += 20;
        }

        if (results.patterns && results.patterns.suspicious) {
            probability += 15;
        }

        if (results.smtp && !results.smtp.exists) {
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

    generateRecommendations(score, results) {
        const recommendations = [];

        if (score >= 80) {
            recommendations.push({
                action: 'APPROVE',
                message: 'Aprovar compra normalmente',
                priority: 'low'
            });
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
            recommendations.push({
                action: 'LIMIT_PAYMENT_METHODS',
                message: 'Limitar métodos de pagamento (apenas PIX/boleto)',
                priority: 'high'
            });
        } else {
            recommendations.push({
                action: 'MANUAL_REVIEW',
                message: 'Enviar para análise manual',
                priority: 'critical'
            });
            recommendations.push({
                action: 'BLOCK_HIGH_VALUE',
                message: 'Bloquear compras acima de R$ 500',
                priority: 'critical'
            });
        }

        // Recomendações específicas
        if (results.disposable && results.disposable.isDisposable) {
            recommendations.push({
                action: 'BLOCK_EMAIL',
                message: 'Email temporário detectado - solicitar email permanente',
                priority: 'critical'
            });
        }

        if (results.patterns && results.patterns.suggestions.length > 0) {
            recommendations.push({
                action: 'SUGGEST_CORRECTION',
                message: `Sugerir correção: ${results.patterns.suggestions[0].suggestion}`,
                priority: 'medium'
            });
        }

        console.log('recomendacao -------->0: ',recommendations[0])
        console.log('recomendacao -------->1: ',recommendations[1])

        return recommendations;
    }

    generateInsights(results) {
        const insights = {
            emailAge: 'unknown',
            socialPresence: false,
            corporateEmail: false,
            personalEmail: false,
            likelyFirstPurchase: true,
            deviceMatch: true
        };

        // Determinar tipo de email
        if (results.email) {
            const domain = results.email.split('@')[1];

            // Email corporativo
            if (domain && !['gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com'].includes(domain)) {
                insights.corporateEmail = true;
                insights.likelyFirstPurchase = false;
            } else {
                insights.personalEmail = true;
            }
        }

        // Presença social (simulada - em produção seria via API)
        if (results.score > 70) {
            insights.socialPresence = true;
        }

        return insights;
    }
}

module.exports = EcommerceScoring;
