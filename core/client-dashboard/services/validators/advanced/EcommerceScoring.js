// ================================================
// E-commerce Scoring System - ENHANCED v4.0
// Sistema com validações ultra rigorosas + correção de typos
// ================================================

const TrustedDomains = require('./TrustedDomains');
const BlockedDomains = require('./BlockedDomains');

class EcommerceScoring {
    constructor() {
        // Pesos ajustados para validação mais rigorosa
        this.weights = {
            domainBlocked: 30,      // Peso alto para domínios bloqueados
            domainCorrection: 15,   // NOVO - peso para correções de typo
            tldScore: 10,
            disposableCheck: 20,
            smtpVerification: 15,
            patternAnalysis: 10,
            formatQuality: 10,
            domainTrust: 5
        };

        // Threshold mais rigoroso
        this.scoreThreshold = {
            invalid: 40,        // < 40 = Inválido
            rejected: 50,       // 40-50 = Rejeitado
            suspicious: 65,     // 50-65 = Suspeito
            valid: 65,         // >= 65 = Válido
            trusted: 80        // >= 80 = Confiável
        };

        // Penalidades e bônus
        this.penalties = {
            typoCorrection: {
                minor: 5,      // Typo simples (1 caractere)
                major: 10,     // Typo significativo (2+ caracteres)
                suspicious: 15 // Typo em email já suspeito
            },
            suspicious: {
                low: 10,
                medium: 20,
                high: 30
            }
        };

        this.bonuses = {
            trustedDomain: {
                mainstream: 15,
                professional: 10,
                educational: 12,
                government: 15,
                brazilian: 8
            },
            verifiedSMTP: 10,
            oldDomain: 5
        };

        // Inicializar módulos
        this.trustedDomains = new TrustedDomains();
        this.blockedDomains = new BlockedDomains();

        // Estatísticas
        this.stats = {
            totalScored: 0,
            approved: 0,
            rejected: 0,
            correctedEmails: 0,
            averageScore: 0,
            scores: []
        };

        this.debug = process.env.DEBUG_SCORING === 'true';
    }

    calculateScore(validationResults) {
        this.stats.totalScored++;

        // Validação de entrada
        if (!validationResults || typeof validationResults !== 'object') {
            return this.createEmptyScore('Invalid input');
        }

        const email = validationResults.email || '';
        const domain = email.split('@')[1] || '';

        // ================================================
        // VERIFICAÇÃO DE BLOQUEIO (PRIORIDADE MÁXIMA)
        // ================================================
        const blockCheck = validationResults.blocked || this.blockedDomains.isBlocked(email);

        if (blockCheck && blockCheck.blocked) {
            this.logDebug(`Email bloqueado: ${email} - Razão: ${blockCheck.reason}`);
            this.stats.rejected++;

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
                    blockReason: blockCheck.reason,
                    correctionAttempted: false
                },
                metadata: {
                    email: email,
                    domain: domain,
                    isBlocked: true,
                    blockCategory: blockCheck.category,
                    timestamp: new Date().toISOString()
                }
            };
        }

        // Inicializar estrutura de pontuação
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
                suspicious: blockCheck?.suspicious || false,
                wasCorrected: validationResults.wasCorrected || false,
                timestamp: new Date().toISOString()
            }
        };

        // ================================================
        // ANÁLISE DE CORREÇÃO DE TYPO (NOVO)
        // ================================================
        if (validationResults.wasCorrected) {
            this.stats.correctedEmails++;

            const correctionDetails = validationResults.correctionDetails || {};
            const correctionType = correctionDetails.type || 'unknown';
            const correctionConfidence = correctionDetails.confidence || 0.5;

            // Determinar penalidade baseada no tipo de correção
            let correctionPenalty = this.penalties.typoCorrection.minor;

            if (correctionType === 'similarity' || correctionConfidence < 0.8) {
                correctionPenalty = this.penalties.typoCorrection.major;
            }

            // Penalidade extra se email já é suspeito
            if (blockCheck?.suspicious) {
                correctionPenalty = this.penalties.typoCorrection.suspicious;
            }

            scoreData.breakdown.correction = {
                wasCorrected: true,
                originalEmail: validationResults.email,
                correctedEmail: validationResults.correctedEmail || validationResults.corrected,
                correctionType: correctionType,
                correctionConfidence: correctionConfidence,
                penalty: correctionPenalty,
                details: correctionDetails
            };

            scoreData.insights.hadTypo = true;
            scoreData.insights.typoSeverity = correctionPenalty >= 10 ? 'high' : 'low';

            // Adicionar recomendação sobre correção
            scoreData.recommendations.push({
                action: 'INFO',
                message: `Email continha erro de digitação: "${validationResults.email}" foi corrigido para "${validationResults.correctedEmail || validationResults.corrected}"`,
                priority: 'medium'
            });

            this.logDebug(`Correção aplicada: ${validationResults.email} → ${validationResults.correctedEmail}, Penalidade: ${correctionPenalty}`);
        }

        // ================================================
        // VERIFICAÇÃO DE DOMÍNIO CONFIÁVEL
        // ================================================
        const isTrustedDomain = this.trustedDomains.isTrusted(domain);
        const domainCategory = this.trustedDomains.getCategory(domain);
        const trustScore = this.trustedDomains.getTrustScore(domain);

        scoreData.metadata.isTrustedDomain = isTrustedDomain;
        scoreData.metadata.domainCategory = domainCategory;
        scoreData.metadata.trustScore = trustScore;

        // ================================================
        // CÁLCULO DE PONTUAÇÃO POR COMPONENTE
        // ================================================
        let totalScore = 0;
        let totalWeight = 0;

        // 1. Penalidade inicial se suspeito
        if (blockCheck?.suspicious) {
            const suspicionPenalty = blockCheck.penaltyScore || this.penalties.suspicious.medium;
            totalScore -= suspicionPenalty * 2;
            scoreData.breakdown.suspicious = {
                penalty: suspicionPenalty,
                reason: blockCheck.reason,
                applied: true
            };
        }

        // 2. Penalidade por correção de typo
        if (validationResults.wasCorrected) {
            const correctionPenalty = scoreData.breakdown.correction.penalty;
            totalScore -= correctionPenalty * this.weights.domainCorrection / 10;
            totalWeight += this.weights.domainCorrection;
        }

        // 3. Domain Trust Score
        const domainTrustPoints = this.calculateDomainTrustPoints(
            isTrustedDomain,
            domainCategory,
            trustScore,
            blockCheck?.suspicious
        );
        totalScore += domainTrustPoints * this.weights.domainTrust;
        totalWeight += this.weights.domainTrust;
        scoreData.breakdown.domainTrust = {
            points: domainTrustPoints,
            weight: this.weights.domainTrust,
            weighted: domainTrustPoints * this.weights.domainTrust,
            category: domainCategory,
            trusted: isTrustedDomain
        };

        // 4. TLD Score
        if (validationResults.tld) {
            const tldPoints = this.calculateTLDPoints(
                validationResults.tld,
                isTrustedDomain,
                validationResults.wasCorrected
            );
            totalScore += tldPoints * this.weights.tldScore;
            totalWeight += this.weights.tldScore;
            scoreData.breakdown.tld = {
                points: tldPoints,
                weight: this.weights.tldScore,
                weighted: tldPoints * this.weights.tldScore,
                tldType: validationResults.tld.type || 'unknown'
            };
        }

        // 5. Disposable Check
        if (validationResults.disposable) {
            const disposablePoints = this.calculateDisposablePoints(
                validationResults.disposable,
                isTrustedDomain,
                domain,
                validationResults.wasCorrected
            );
            totalScore += disposablePoints * this.weights.disposableCheck;
            totalWeight += this.weights.disposableCheck;
            scoreData.breakdown.disposable = {
                points: disposablePoints,
                weight: this.weights.disposableCheck,
                weighted: disposablePoints * this.weights.disposableCheck,
                isDisposable: validationResults.disposable.isDisposable
            };
        }

        // 6. SMTP Verification
        if (validationResults.smtp) {
            const smtpPoints = this.calculateSMTPPoints(
                validationResults.smtp,
                isTrustedDomain,
                validationResults.wasCorrected
            );
            totalScore += smtpPoints * this.weights.smtpVerification;
            totalWeight += this.weights.smtpVerification;
            scoreData.breakdown.smtp = {
                points: smtpPoints,
                weight: this.weights.smtpVerification,
                weighted: smtpPoints * this.weights.smtpVerification,
                verified: validationResults.smtp.exists || false
            };
        }

        // 7. Pattern Analysis
        if (validationResults.patterns) {
            const patternPoints = this.calculatePatternPoints(
                validationResults.patterns,
                blockCheck?.suspicious,
                validationResults.wasCorrected
            );
            totalScore += patternPoints * this.weights.patternAnalysis;
            totalWeight += this.weights.patternAnalysis;
            scoreData.breakdown.patterns = {
                points: patternPoints,
                weight: this.weights.patternAnalysis,
                weighted: patternPoints * this.weights.patternAnalysis,
                suspicious: validationResults.patterns.suspicious || false
            };
        }

        // 8. Format Quality
        const formatPoints = this.calculateFormatPoints(
            email,
            blockCheck?.suspicious,
            validationResults.wasCorrected
        );
        totalScore += formatPoints * this.weights.formatQuality;
        totalWeight += this.weights.formatQuality;
        scoreData.breakdown.format = {
            points: formatPoints,
            weight: this.weights.formatQuality,
            weighted: formatPoints * this.weights.formatQuality
        };

        // ================================================
        // CÁLCULO DO SCORE BASE
        // ================================================
        if (totalWeight > 0) {
            scoreData.baseScore = Math.round((totalScore / totalWeight) * 10);
        } else {
            scoreData.baseScore = 0;
        }

        // ================================================
        // APLICAR BÔNUS E AJUSTES
        // ================================================

        // Bônus para domínios muito confiáveis
        if (isTrustedDomain && domainCategory === 'mainstream') {
            const bonus = this.bonuses.trustedDomain.mainstream;
            scoreData.baseScore = Math.min(100, scoreData.baseScore + bonus);
            scoreData.breakdown.trustedBonus = {
                applied: true,
                amount: bonus,
                category: domainCategory
            };
        }

        // Bônus para SMTP verificado em domínio confiável
        if (validationResults.smtp?.exists && isTrustedDomain) {
            const bonus = this.bonuses.verifiedSMTP;
            scoreData.baseScore = Math.min(100, scoreData.baseScore + bonus);
            scoreData.breakdown.smtpBonus = {
                applied: true,
                amount: bonus
            };
        }

        // Limitar score se teve correção significativa
        if (validationResults.wasCorrected && scoreData.baseScore > 85) {
            scoreData.baseScore = 85;
            scoreData.breakdown.correctionCap = {
                applied: true,
                cappedAt: 85,
                reason: 'Score limitado devido a correção de typo'
            };
        }

        // Garantir que emails muito suspeitos nunca tenham score alto
        if (blockCheck?.suspicious && scoreData.baseScore > 60) {
            scoreData.baseScore = 60;
            scoreData.breakdown.suspicionCap = {
                applied: true,
                cappedAt: 60,
                reason: 'Score limitado devido a suspeita'
            };
        }

        // ================================================
        // FINALIZAÇÃO DO SCORE
        // ================================================
        scoreData.finalScore = Math.max(0, Math.min(100, scoreData.baseScore));

        // Determinar validade baseado no threshold
        scoreData.valid = scoreData.finalScore >= this.scoreThreshold.valid;

        // Classificações
        scoreData.buyerType = this.classifyBuyer(
            scoreData.finalScore,
            blockCheck?.suspicious,
            validationResults.wasCorrected
        );

        scoreData.riskLevel = this.assessRisk(
            scoreData.finalScore,
            validationResults.wasCorrected
        );

        scoreData.fraudProbability = this.calculateFraudProbability(
            scoreData.finalScore,
            validationResults,
            isTrustedDomain,
            blockCheck?.suspicious,
            validationResults.wasCorrected
        );

        scoreData.confidence = this.determineConfidence(
            scoreData.finalScore,
            validationResults.wasCorrected
        );

        // ================================================
        // GERAR RECOMENDAÇÕES FINAIS
        // ================================================
        scoreData.recommendations = this.generateRecommendations(
            scoreData.finalScore,
            validationResults,
            isTrustedDomain,
            blockCheck,
            scoreData
        );

        // ================================================
        // GERAR INSIGHTS
        // ================================================
        scoreData.insights = this.generateInsights(
            validationResults,
            isTrustedDomain,
            blockCheck,
            scoreData
        );

        // ================================================
        // ESTATÍSTICAS
        // ================================================
        this.updateStatistics(scoreData);

        this.logDebug(`Score final para ${email}: ${scoreData.finalScore} - Válido: ${scoreData.valid}`);

        return scoreData;
    }

    calculateDomainTrustPoints(isTrusted, category, trustScore, isSuspicious) {
        if (isSuspicious) return 2;
        if (isTrusted) {
            switch(category) {
                case 'mainstream':
                case 'government':
                    return 10;
                case 'educational':
                case 'professional':
                    return 9;
                case 'brazilian':
                    return 8;
                default:
                    return 7;
            }
        }
        return 5;
    }

    calculateTLDPoints(tldResult, isTrustedDomain, wasCorrected) {
        if (isTrustedDomain) return 10;
        if (tldResult.isBlocked) return 0;
        if (tldResult.isSuspicious) {
            return wasCorrected ? 1 : 2; // Penalidade extra se teve correção
        }
        if (tldResult.isPremium) return 10;
        if (tldResult.valid) return wasCorrected ? 5 : 6;
        return 0;
    }

    calculateDisposablePoints(disposableResult, isTrustedDomain, domain, wasCorrected) {
        if (isTrustedDomain) return 10;

        // Verificação adicional para domínios suspeitos
        if (domain) {
            const suspiciousKeywords = ['temp', 'trash', 'disposable', 'fake', 'minute', 'throw'];
            for (const keyword of suspiciousKeywords) {
                if (domain.includes(keyword)) {
                    return 0;
                }
            }
        }

        if (disposableResult.isDisposable) return 0;

        // Reduzir pontos se teve correção
        return wasCorrected ? 8 : 10;
    }

    calculateSMTPPoints(smtpResult, isTrustedDomain, wasCorrected) {
        if (isTrustedDomain && !smtpResult.exists && smtpResult.error) {
            return 7; // Fallback para domínios confiáveis
        }

        if (!smtpResult.smtp) return 3;
        if (smtpResult.exists && !smtpResult.catchAll) {
            return wasCorrected ? 9 : 10; // Pequena penalidade se teve correção
        }
        if (smtpResult.catchAll) return wasCorrected ? 4 : 5;
        if (!smtpResult.exists) return 0;
        return 3;
    }

    calculatePatternPoints(patternResult, isSuspicious, wasCorrected) {
        let points = 10;

        if (patternResult.suspicious) {
            points = Math.max(0, 10 - patternResult.suspicionLevel);
        }

        // Penalidade adicional se já foi marcado como suspeito
        if (isSuspicious) {
            points = Math.max(0, points - 3);
        }

        // Penalidade se teve correção E padrões suspeitos
        if (wasCorrected && patternResult.suspicious) {
            points = Math.max(0, points - 2);
        }

        return points;
    }

    calculateFormatPoints(email, isSuspicious, wasCorrected) {
        if (!email || typeof email !== 'string') return 0;

        const parts = email.split('@');
        if (parts.length !== 2) return 0;

        const localPart = parts[0].toLowerCase();

        // Penalizar emails genéricos
        const genericPrefixes = ['test', 'admin', 'user', 'info', 'contact', 'support', 'noreply'];
        for (const prefix of genericPrefixes) {
            if (localPart === prefix || localPart.startsWith(prefix)) {
                return isSuspicious ? 0 : (wasCorrected ? 1 : 2);
            }
        }

        // Formato profissional
        if (/^[a-z]+\.[a-z]+$/.test(localPart)) {
            return wasCorrected ? 9 : 10;
        }

        // Formato corporativo
        if (/^[a-z]+[._-][a-z]+$/.test(localPart)) {
            return wasCorrected ? 7 : 8;
        }

        // Nome completo
        if (/^[a-z]{4,20}$/.test(localPart)) {
            return wasCorrected ? 5 : 6;
        }

        // Com números moderados
        if (/^[a-z]+[0-9]{1,3}$/.test(localPart)) {
            return wasCorrected ? 3 : 4;
        }

        // Muitos números ou caracteres especiais
        if (/[0-9]{4,}/.test(localPart)) return 1;

        return 3;
    }

    classifyBuyer(score, isSuspicious, wasCorrected) {
        // Classificação especial para emails corrigidos
        if (wasCorrected) {
            if (score >= 75) return 'CORRECTED_VALID_BUYER';
            if (score >= 60) return 'CORRECTED_REGULAR_BUYER';
            if (score >= 45) return 'CORRECTED_SUSPICIOUS_BUYER';
            return 'CORRECTED_HIGH_RISK_BUYER';
        }

        if (isSuspicious) {
            return score >= 70 ? 'SUSPICIOUS_BUYER' : 'HIGH_RISK_BUYER';
        }

        if (score >= 80) return 'TRUSTED_BUYER';
        if (score >= 70) return 'REGULAR_BUYER';
        if (score >= 60) return 'NEW_BUYER';
        if (score >= 50) return 'SUSPICIOUS_BUYER';
        return 'HIGH_RISK_BUYER';
    }

    assessRisk(score, wasCorrected) {
        // Ajustar risco se teve correção
        const adjustment = wasCorrected ? 5 : 0;
        const adjustedScore = score - adjustment;

        if (adjustedScore >= 80) return 'VERY_LOW';
        if (adjustedScore >= 70) return 'LOW';
        if (adjustedScore >= 60) return 'MEDIUM';
        if (adjustedScore >= 50) return 'HIGH';
        return 'VERY_HIGH';
    }

    calculateFraudProbability(score, results, isTrustedDomain, isSuspicious, wasCorrected) {
        let probability = 100 - score;

        if (isTrustedDomain) {
            probability = Math.max(5, probability - 20);
        }

        if (isSuspicious) {
            probability = Math.min(95, probability + 30);
        }

        if (wasCorrected) {
            // Emails com typo têm probabilidade levemente maior de fraude
            probability = Math.min(95, probability + 10);
        }

        if (results.disposable && results.disposable.isDisposable) {
            probability = Math.min(95, probability + 25);
        }

        if (results.smtp && !results.smtp.exists) {
            probability = Math.min(95, probability + 15);
        }

        return Math.min(95, Math.max(5, probability));
    }

    determineConfidence(score, wasCorrected) {
        // Reduzir confiança se teve correção
        const adjustment = wasCorrected ? 10 : 0;
        const adjustedScore = score - adjustment;

        if (adjustedScore >= 80) return 'very_high';
        if (adjustedScore >= 70) return 'high';
        if (adjustedScore >= 60) return 'medium';
        if (adjustedScore >= 50) return 'low';
        return 'very_low';
    }

    generateRecommendations(score, results, isTrustedDomain, blockCheck, scoreData) {
        const recommendations = [];

        // Recomendações sobre correção
        if (results.wasCorrected) {
            const severity = scoreData.breakdown.correction?.penalty >= 10 ? 'significant' : 'minor';
            recommendations.push({
                action: 'CORRECTION_NOTICE',
                message: `Email corrigido automaticamente (${severity} typo detected)`,
                priority: 'medium',
                details: {
                    original: results.email,
                    corrected: results.correctedEmail || results.corrected,
                    confidence: scoreData.breakdown.correction?.correctionConfidence
                }
            });

            if (score >= 65) {
                recommendations.push({
                    action: 'VERIFY_CORRECTION',
                    message: 'Confirmar com cliente se o email corrigido está correto',
                    priority: 'medium'
                });
            }
        }

        // Recomendações sobre suspeitas
        if (blockCheck?.suspicious) {
            recommendations.push({
                action: 'WARNING',
                message: `Email suspeito: ${blockCheck.reason}`,
                priority: 'high'
            });
        }

        // Recomendações baseadas no score
        if (score >= 80) {
            recommendations.push({
                action: 'APPROVE',
                message: 'Email altamente confiável - aprovar transação',
                priority: 'low'
            });
        } else if (score >= 65) {
            recommendations.push({
                action: 'APPROVE_WITH_MONITORING',
                message: 'Email válido - aprovar com monitoramento padrão',
                priority: 'medium'
            });
        } else if (score >= 50) {
            recommendations.push({
                action: 'MANUAL_REVIEW',
                message: 'Email duvidoso - revisar manualmente',
                priority: 'high'
            });
            recommendations.push({
                action: 'REQUEST_VERIFICATION',
                message: 'Solicitar verificação adicional via SMS ou documento',
                priority: 'high'
            });
        } else {
            recommendations.push({
                action: 'REJECT',
                message: 'Email inválido ou de alto risco - rejeitar transação',
                priority: 'critical'
            });
            recommendations.push({
                action: 'SUGGEST_ALTERNATIVE',
                message: 'Solicitar email alternativo válido ao cliente',
                priority: 'critical'
            });
        }

        // Recomendações específicas para e-commerce
        if (score < 50 && results.disposable?.isDisposable) {
            recommendations.push({
                action: 'BLOCK_CHECKOUT',
                message: 'Bloquear checkout - email temporário detectado',
                priority: 'critical'
            });
        }

        if (results.wasCorrected && score >= 60 && score < 80) {
            recommendations.push({
                action: 'SEND_CONFIRMATION',
                message: 'Enviar email de confirmação antes de processar pedido',
                priority: 'medium'
            });
        }

        return recommendations;
    }

    generateInsights(results, isTrustedDomain, blockCheck, scoreData) {
        const insights = {
            trustedProvider: isTrustedDomain,
            suspicious: blockCheck?.suspicious || false,
            blockReason: blockCheck?.reason || null,
            requiresVerification: scoreData.finalScore < 70,
            hadTypo: results.wasCorrected || false,
            typoImpact: null,
            riskFactors: [],
            positiveFactors: [],
            summary: ''
        };

        // Análise do impacto da correção
        if (results.wasCorrected) {
            const penalty = scoreData.breakdown.correction?.penalty || 0;
            insights.typoImpact = penalty >= 10 ? 'significant' : 'minor';
            insights.riskFactors.push('Email contained typo (corrected)');
        }

        // Fatores de risco
        if (results.disposable?.isDisposable) {
            insights.riskFactors.push('Disposable email detected');
        }
        if (!results.smtp?.exists) {
            insights.riskFactors.push('Mailbox does not exist');
        }
        if (results.patterns?.suspicious) {
            insights.riskFactors.push('Suspicious patterns detected');
        }
        if (blockCheck?.suspicious) {
            insights.riskFactors.push('Email flagged as suspicious');
        }

        // Fatores positivos
        if (isTrustedDomain) {
            insights.positiveFactors.push(`Trusted domain (${scoreData.metadata.domainCategory})`);
        }
        if (results.smtp?.exists && !results.smtp?.catchAll) {
            insights.positiveFactors.push('Verified mailbox exists');
        }
        if (scoreData.finalScore >= 80) {
            insights.positiveFactors.push('High confidence score');
        }

        // Resumo
        if (scoreData.finalScore >= 80) {
            insights.summary = 'Highly trustworthy email';
        } else if (scoreData.finalScore >= 65) {
            insights.summary = results.wasCorrected ?
                'Valid email with minor typo (corrected)' :
                'Valid email with moderate confidence';
        } else if (scoreData.finalScore >= 50) {
            insights.summary = 'Suspicious email requiring verification';
        } else {
            insights.summary = 'High-risk or invalid email';
        }

        return insights;
    }

    updateStatistics(scoreData) {
        this.stats.scores.push(scoreData.finalScore);

        if (scoreData.valid) {
            this.stats.approved++;
        } else {
            this.stats.rejected++;
        }

        // Manter apenas últimos 1000 scores para média
        if (this.stats.scores.length > 1000) {
            this.stats.scores.shift();
        }

        // Calcular média
        this.stats.averageScore = Math.round(
            this.stats.scores.reduce((a, b) => a + b, 0) / this.stats.scores.length
        );
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
            insights: {
                summary: reason
            },
            error: reason,
            metadata: {
                timestamp: new Date().toISOString()
            }
        };
    }

    getStatistics() {
        return {
            ...this.stats,
            approvalRate: this.stats.totalScored > 0
                ? ((this.stats.approved / this.stats.totalScored) * 100).toFixed(2) + '%'
                : '0%',
            correctionRate: this.stats.totalScored > 0
                ? ((this.stats.correctedEmails / this.stats.totalScored) * 100).toFixed(2) + '%'
                : '0%'
        };
    }

    resetStatistics() {
        this.stats = {
            totalScored: 0,
            approved: 0,
            rejected: 0,
            correctedEmails: 0,
            averageScore: 0,
            scores: []
        };
        this.logDebug('Statistics reset');
    }

    logDebug(message) {
        if (this.debug) {
            console.log(`[EcommerceScoring] ${message}`);
        }
    }
}

module.exports = EcommerceScoring;
