// ================================================
// E-commerce Email Scoring System - v2.0
// Sistema avançado de pontuação com análise de popularidade
// Inclui análise de fraude, velocity check e batch processing
// ================================================

const PopularityScoring = require('./PopularityScoring');

class EcommerceScoring {
    constructor(options = {}) {
        this.debug = options.debug || false;

        // NOVO: Sistema de popularidade
        this.popularityScoring = new PopularityScoring();

        // Instâncias necessárias
        this.trustedDomains = options.trustedDomains || null;
        this.blockedDomains = options.blockedDomains || null;

        // Velocity tracker para análise de velocidade
        this.velocityTracker = new Map();
        this.velocityCleanupInterval = setInterval(() => {
            this.cleanupVelocityTracker();
        }, 3600000); // Limpar a cada hora

        // ================================================
        // CONFIGURAÇÕES DE PESO - AJUSTADAS
        // ================================================
        this.weights = {
            domainTrust: 5,        // Reduzido de 10 (agora temos popularity)
            popularity: 10,        // NOVO - peso alto
            tldScore: 3,
            disposableCheck: 8,
            smtpVerification: 10,
            patternAnalysis: 5,
            formatQuality: 3,
            domainCorrection: 5,
            mxValidation: 6        // Reduzido de 8
        };

        // ================================================
        // THRESHOLDS - AJUSTADOS PARA MENOS RIGOROSOS
        // ================================================
        this.scoreThreshold = {
            invalid: 25,        // < 25 = Inválido (era 30)
            rejected: 35,       // 25-35 = Rejeitado (era 40)
            suspicious: 45,     // 35-45 = Suspeito (era 50)
            valid: 45,          // >= 45 = Válido (ERA 65!)
            trusted: 70         // >= 70 = Confiável
        };

        // ================================================
        // BÔNUS E PENALIDADES - AJUSTADOS
        // ================================================
        this.bonuses = {
            trustedDomain: {
                mainstream: 15,     // Era 20
                business: 10,
                educational: 8,
                government: 12
            },
            verifiedSMTP: 5,        // Era 10
            corporateDomain: 5,
            tier1Domain: 10,        // NOVO
            loyalCustomer: 15,      // Para histórico positivo
            highValueCustomer: 5    // Para clientes de alto valor
        };

        this.penalties = {
            suspicious: {
                low: 5,             // Era 10
                medium: 10,         // Era 15
                high: 20            // Era 25
            },
            typoCorrection: {
                minor: 3,           // Era 5
                major: 5,           // Era 10
                suspicious: 8       // Era 15
            },
            disposable: 30,
            invalidFormat: 20,
            blacklisted: 50,
            velocityAbuse: 25,      // NOVO - para velocity check
            chargebackHistory: 30   // NOVO - para histórico de chargeback
        };

        // ================================================
        // CONFIGURAÇÕES DE FRAUDE
        // ================================================
        this.fraudIndicators = {
            sequentialNumbers: 10,
            randomString: 15,
            tooManyNumbers: 8,
            suspiciousPattern: 12,
            knownTestAccount: 20,
            temporaryEmail: 35,
            roleBasedEmail: 5,
            velocityAnomaly: 25,
            multipleDomainsPerEmail: 20,
            rapidFireRegistration: 30
        };

        // ================================================
        // CONFIGURAÇÕES DE VELOCITY
        // ================================================
        this.velocityThresholds = {
            emailPerHour: 5,
            emailPerDay: 20,
            domainPerHour: 10,
            ipPerHour: 15,
            suspiciousRate: 10
        };

        // ================================================
        // ESTATÍSTICAS
        // ================================================
        this.stats = {
            totalScored: 0,
            approved: 0,
            rejected: 0,
            review: 0,
            correctedEmails: 0,
            trustedDomains: 0,
            suspiciousEmails: 0,
            disposableEmails: 0,
            fraudDetected: 0,
            velocityBlocked: 0,
            averageScore: 0,
            scoreDistribution: {
                '0-25': 0,
                '26-45': 0,
                '46-60': 0,
                '61-75': 0,
                '76-90': 0,
                '91-100': 0
            },
            processingTimes: [],
            batchesProcessed: 0
        };

        // Mapas de categorização
        this.buyerTypeMap = {
            TRUSTED_BUYER: 'Comprador Confiável',
            REGULAR_BUYER: 'Comprador Regular',
            NEW_BUYER: 'Novo Comprador',
            SUSPICIOUS_BUYER: 'Comprador Suspeito',
            HIGH_RISK_BUYER: 'Comprador Alto Risco',
            CORRECTED_VALID_BUYER: 'Email Corrigido - Válido',
            CORRECTED_REGULAR_BUYER: 'Email Corrigido - Regular',
            CORRECTED_SUSPICIOUS_BUYER: 'Email Corrigido - Revisar',
            CORRECTED_HIGH_RISK_BUYER: 'Email Corrigido - Alto Risco',
            BLOCKED: 'Bloqueado',
            INVALID: 'Inválido'
        };

        this.riskLevelMap = {
            VERY_LOW: 'Muito Baixo',
            LOW: 'Baixo',
            MEDIUM: 'Médio',
            HIGH: 'Alto',
            VERY_HIGH: 'Muito Alto',
            CRITICAL: 'Crítico',
            BLOCKED: 'Bloqueado'
        };

        this.logDebug('EcommerceScoring v2.0 inicializado com análise de fraude e velocity check');
    }

    // ================================================
    // MÉTODO PRINCIPAL - CALCULATE SCORE (COMPLETO)
    // ================================================
    calculateScore(validationResults) {
        const startTime = Date.now();
        this.stats.totalScored++;

        // Validação de entrada
        if (!validationResults || typeof validationResults !== 'object') {
            return this.createEmptyScore('Invalid input');
        }

        const email = validationResults.email || '';
        const domain = email.split('@')[1] || '';

        // ================================================
        // NOVO: ANÁLISE DE POPULARIDADE (PRIORIDADE ALTA)
        // ================================================
        const popularityAnalysis = this.popularityScoring.getPopularityScore(domain);
        const isMainstream = this.popularityScoring.isMainstreamDomain(domain);
        const isCorporative = this.popularityScoring.isCorporativeDomain(domain);
        const isDisposable = this.popularityScoring.isDisposableDomain(domain);

        // ================================================
        // VELOCITY CHECK
        // ================================================
        const velocityAnalysis = this.analyzeVelocity(email);

        // ================================================
        // ANÁLISE DE FRAUDE
        // ================================================
        const fraudAnalysis = this.analyzeFraudIndicators(email, validationResults);

        // ================================================
        // VERIFICAÇÃO DE BLOQUEIO (PRIORIDADE MÁXIMA)
        // ================================================
        const blockCheck = validationResults.blocked || this.blockedDomains?.isBlocked(email);

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
                popularity: popularityAnalysis.popularity,
                domainType: popularityAnalysis.type,
                fraudAnalysis: fraudAnalysis,
                velocityAnalysis: velocityAnalysis,
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
                    correctionAttempted: false,
                    popularity: popularityAnalysis.popularity,
                    domainType: popularityAnalysis.type
                },
                metadata: {
                    email: email,
                    domain: domain,
                    isBlocked: true,
                    blockCategory: blockCheck.category,
                    processingTime: Date.now() - startTime,
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
            popularity: popularityAnalysis.popularity,
            domainType: popularityAnalysis.type,
            fraudAnalysis: fraudAnalysis,
            velocityAnalysis: velocityAnalysis,
            recommendations: [],
            breakdown: {},
            insights: {},
            metadata: {
                email: email,
                domain: domain,
                isTrustedDomain: false,
                isMainstreamDomain: isMainstream,
                isCorporativeDomain: isCorporative,
                domainCategory: popularityAnalysis.category,
                popularityTier: popularityAnalysis.tier,
                suspicious: blockCheck?.suspicious || false,
                wasCorrected: validationResults.wasCorrected || false,
                processingTime: 0,
                timestamp: new Date().toISOString()
            }
        };

        // ================================================
        // NOVO: BOOST INICIAL BASEADO EM POPULARIDADE
        // ================================================
        let initialBoost = popularityAnalysis.bonus || 0;

        // Se é mainstream e não é descartável, garantir boost mínimo
        if (isMainstream && !isDisposable) {
            initialBoost = Math.max(initialBoost, 20);
            scoreData.insights.mainstreamDomain = true;
        }

        // Penalidade por velocity suspeito
        if (velocityAnalysis.suspicious) {
            initialBoost -= this.penalties.velocityAbuse;
            scoreData.insights.velocityIssue = true;
            this.stats.velocityBlocked++;
        }

        // Penalidade por indicadores de fraude
        if (fraudAnalysis.hasIndicators) {
            const fraudPenalty = Math.min(30, fraudAnalysis.totalRisk / 2);
            initialBoost -= fraudPenalty;
            scoreData.insights.fraudIndicators = true;
            this.stats.fraudDetected++;
        }

        // ================================================
        // ANÁLISE DE CORREÇÃO DE TYPO
        // ================================================
        if (validationResults.wasCorrected) {
            this.stats.correctedEmails++;

            const correctionDetails = validationResults.correctionDetails || {};
            const correctionType = correctionDetails.type || 'unknown';
            const correctionConfidence = correctionDetails.confidence || 0.5;

            // AJUSTADO: Penalidade reduzida para correções
            let correctionPenalty = 3; // Era 5-15, agora 3-8

            if (correctionType === 'similarity' || correctionConfidence < 0.8) {
                correctionPenalty = 5;
            }

            // Se é mainstream, penalidade mínima
            if (isMainstream) {
                correctionPenalty = Math.min(correctionPenalty, 3);
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
            scoreData.insights.typoSeverity = correctionPenalty >= 5 ? 'high' : 'low';

            scoreData.recommendations.push({
                action: 'INFO',
                message: `Email corrigido: "${validationResults.email}" → "${validationResults.correctedEmail || validationResults.corrected}"`,
                priority: 'low'
            });
        }

        // ================================================
        // CÁLCULO DE PONTUAÇÃO POR COMPONENTE
        // ================================================
        let totalScore = initialBoost; // Começar com boost de popularidade
        let totalWeight = 0;

        // 1. Popularity Score (NOVO - peso alto)
        const popularityPoints = this.calculatePopularityPoints(popularityAnalysis, isDisposable);
        totalScore += popularityPoints * this.weights.popularity;
        totalWeight += this.weights.popularity;
        scoreData.breakdown.popularity = {
            points: popularityPoints,
            weight: this.weights.popularity,
            weighted: popularityPoints * this.weights.popularity,
            tier: popularityAnalysis.tier,
            category: popularityAnalysis.category,
            type: popularityAnalysis.type
        };

        // 2. Penalidade por correção (reduzida)
        if (validationResults.wasCorrected) {
            const correctionPenalty = scoreData.breakdown.correction.penalty;
            totalScore -= correctionPenalty;
        }

        // 3. Domain Trust Score
        const domainTrustPoints = this.calculateDomainTrustPoints(
            popularityAnalysis.trust >= 70,
            popularityAnalysis.category,
            popularityAnalysis.trust,
            blockCheck?.suspicious
        );
        totalScore += domainTrustPoints * this.weights.domainTrust;
        totalWeight += this.weights.domainTrust;
        scoreData.breakdown.domainTrust = {
            points: domainTrustPoints,
            weight: this.weights.domainTrust,
            weighted: domainTrustPoints * this.weights.domainTrust,
            category: popularityAnalysis.category,
            trusted: popularityAnalysis.trust >= 70
        };

        // 4. TLD Score
        if (validationResults.tld) {
            const tldPoints = this.calculateTLDPoints(
                validationResults.tld,
                popularityAnalysis.trust >= 70,
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
                popularityAnalysis.trust >= 70,
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

        // 6. MX Validation Score
        if (validationResults.dns?.mxValidation) {
            const mxValidation = validationResults.dns.mxValidation;
            const mxPoints = this.calculateMXPoints(mxValidation, isMainstream);

            totalScore += mxPoints * this.weights.mxValidation;
            totalWeight += this.weights.mxValidation;

            scoreData.breakdown.mx = {
                points: mxPoints,
                weight: this.weights.mxValidation,
                weighted: mxPoints * this.weights.mxValidation,
                provider: mxValidation.emailProvider,
                quality: mxValidation.analysis?.quality,
                reliabilityScore: mxValidation.reliabilityScore
            };
        } else if (validationResults.dns) {
            // Fallback para DNS básico
            const dnsPoints = validationResults.dns.valid ? 8 : 5;
            const dnsWeight = 4;

            totalScore += dnsPoints * dnsWeight;
            totalWeight += dnsWeight;

            scoreData.breakdown.dns = {
                points: dnsPoints,
                weight: dnsWeight,
                weighted: dnsPoints * dnsWeight,
                valid: validationResults.dns.valid
            };
        }

        // 7. SMTP Verification
        if (validationResults.smtp) {
            const smtpPoints = this.calculateSMTPPoints(
                validationResults.smtp,
                popularityAnalysis.trust >= 70,
                validationResults.wasCorrected,
                isMainstream
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

        // 8. Pattern Analysis
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

        // 9. Format Quality
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
        // NOVO: OVERRIDE PARA DOMÍNIOS MAINSTREAM
        // ================================================
        const minimumScore = this.popularityScoring.getMinimumScore(domain);

        if (isMainstream && !isDisposable && !velocityAnalysis.suspicious) {
            if (scoreData.baseScore < minimumScore) {
                scoreData.baseScore = minimumScore;
                scoreData.breakdown.mainstreamOverride = {
                    applied: true,
                    originalScore: Math.round((totalScore / totalWeight) * 10),
                    overrideScore: minimumScore,
                    reason: `Domínio mainstream (${domain}) - score mínimo garantido`
                };
            }
        }

        // ================================================
        // APLICAR BÔNUS E AJUSTES
        // ================================================

        // Bônus extra para tier 1 domains
        if (popularityAnalysis.tier === 1 && !isDisposable && !fraudAnalysis.hasIndicators) {
            const bonus = this.bonuses.tier1Domain;
            scoreData.baseScore = Math.min(100, scoreData.baseScore + bonus);
            scoreData.breakdown.tier1Bonus = {
                applied: true,
                amount: bonus,
                domain: domain
            };
        }

        // Bônus para corporativos brasileiros
        if (popularityAnalysis.category === 'brazilian_corp') {
            const bonus = this.bonuses.corporateDomain;
            scoreData.baseScore = Math.min(100, scoreData.baseScore + bonus);
            scoreData.breakdown.brazilianCorpBonus = {
                applied: true,
                amount: bonus
            };
        }

        // Limitar score se for descartável
        if (isDisposable || validationResults.disposable?.isDisposable) {
            scoreData.baseScore = Math.min(30, scoreData.baseScore);
            scoreData.breakdown.disposableCap = {
                applied: true,
                cappedAt: 30,
                reason: 'Email descartável/temporário detectado'
            };
        }

        // Limitar score se velocity suspeito
        if (velocityAnalysis.suspicious && velocityAnalysis.riskLevel === 'HIGH') {
            scoreData.baseScore = Math.min(50, scoreData.baseScore);
            scoreData.breakdown.velocityCap = {
                applied: true,
                cappedAt: 50,
                reason: 'Velocity check detectou atividade suspeita'
            };
        }

        // Limitar score se fraude detectada
        if (fraudAnalysis.totalRisk >= 30) {
            scoreData.baseScore = Math.min(40, scoreData.baseScore);
            scoreData.breakdown.fraudCap = {
                applied: true,
                cappedAt: 40,
                reason: 'Múltiplos indicadores de fraude detectados'
            };
        }

        // Limitar score se teve correção (mas menos rigoroso para mainstream)
        if (validationResults.wasCorrected && !isMainstream && scoreData.baseScore > 85) {
            scoreData.baseScore = 85;
            scoreData.breakdown.correctionCap = {
                applied: true,
                cappedAt: 85,
                reason: 'Score limitado devido a correção de typo'
            };
        }

        // Limites ajustados para MX
        if (scoreData.breakdown.mx?.quality === 'poor' && scoreData.baseScore > 75) {
            scoreData.baseScore = 75;
        }

        if (scoreData.breakdown.mx?.quality === 'invalid' && scoreData.baseScore > 60) {
            scoreData.baseScore = 60;
        }

        // ================================================
        // FINALIZAÇÃO DO SCORE
        // ================================================
        scoreData.finalScore = Math.max(0, Math.min(100, scoreData.baseScore));

        // Threshold de validade ajustado
        scoreData.valid = scoreData.finalScore >= this.scoreThreshold.valid;

        // Classificações
        scoreData.buyerType = this.classifyBuyer(
            scoreData.finalScore,
            blockCheck?.suspicious,
            validationResults.wasCorrected,
            scoreData.breakdown.mx?.quality,
            popularityAnalysis
        );

        scoreData.riskLevel = this.assessRisk(
            scoreData.finalScore,
            validationResults.wasCorrected,
            scoreData.breakdown.mx?.quality,
            popularityAnalysis,
            fraudAnalysis,
            velocityAnalysis
        );

        scoreData.fraudProbability = this.calculateFraudProbability(
            scoreData.finalScore,
            validationResults,
            popularityAnalysis.trust >= 70,
            blockCheck?.suspicious,
            validationResults.wasCorrected,
            scoreData.breakdown.mx,
            popularityAnalysis,
            fraudAnalysis,
            velocityAnalysis
        );

        scoreData.confidence = this.determineConfidence(
            scoreData.finalScore,
            validationResults.wasCorrected,
            scoreData.breakdown.mx?.quality,
            popularityAnalysis
        );

        // ================================================
        // GERAR RECOMENDAÇÕES E INSIGHTS
        // ================================================
        scoreData.recommendations = this.generateRecommendations(
            scoreData.finalScore,
            validationResults,
            popularityAnalysis.trust >= 70,
            blockCheck,
            scoreData
        );

        scoreData.insights = {
            ...scoreData.insights,
            popularityTier: popularityAnalysis.tier,
            popularityLabel: this.popularityScoring.getPopularityLabel(domain),
            domainTypeLabel: this.popularityScoring.getDomainTypeLabel(domain),
            isMainstream: isMainstream,
            isCorporative: isCorporative,
            trustScore: popularityAnalysis.trust,
            fraudRisk: fraudAnalysis.riskLevel,
            velocityStatus: velocityAnalysis.riskLevel
        };

        // Finalizar tempo de processamento
        scoreData.metadata.processingTime = Date.now() - startTime;
        this.stats.processingTimes.push(scoreData.metadata.processingTime);

        // Atualizar estatísticas
        this.updateStatistics(scoreData);

        this.logDebug(`Score final para ${email}: ${scoreData.finalScore} - Válido: ${scoreData.valid} - Popularidade: ${scoreData.insights.popularityLabel} - Tempo: ${scoreData.metadata.processingTime}ms`);

        return scoreData;
    }

    // ================================================
    // NOVO MÉTODO: ANÁLISE DE FRAUDE
    // ================================================
    analyzeFraudIndicators(email, validationResults) {
        const indicators = [];
        let totalRisk = 0;

        if (!email || !email.includes('@')) {
            return {
                indicators: [],
                totalRisk: 0,
                riskLevel: 'UNKNOWN',
                hasIndicators: false
            };
        }

        const localPart = email.split('@')[0];
        const domain = email.split('@')[1];

        // Verificar padrões sequenciais
        if (/\d{4,}/.test(localPart)) {
            indicators.push({
                type: 'sequential_numbers',
                risk: this.fraudIndicators.sequentialNumbers,
                description: 'Email contém números sequenciais',
                severity: 'medium'
            });
            totalRisk += this.fraudIndicators.sequentialNumbers;
        }

        // Verificar strings aleatórias
        const randomPatterns = /^[a-z0-9]{12,}$/;
        if (randomPatterns.test(localPart) && localPart.length > 15) {
            const hasPattern = /^(user|test|temp|mail|email)\d+/.test(localPart);

            if (!hasPattern) {
                indicators.push({
                    type: 'random_string',
                    risk: this.fraudIndicators.randomString,
                    description: 'Email parece ser gerado aleatoriamente',
                    severity: 'high'
                });
                totalRisk += this.fraudIndicators.randomString;
            }
        }

        // Verificar contas de teste conhecidas
        const testPatterns = [
            /^test/i,
            /^demo/i,
            /^sample/i,
            /^example/i,
            /^fake/i,
            /^temp/i,
            /^dummy/i,
            /^trial/i
        ];

        if (testPatterns.some(pattern => pattern.test(localPart))) {
            indicators.push({
                type: 'test_account',
                risk: this.fraudIndicators.knownTestAccount,
                description: 'Email parece ser conta de teste',
                severity: 'high'
            });
            totalRisk += this.fraudIndicators.knownTestAccount;
        }

        // Verificar emails role-based
        const rolePatterns = [
            /^(admin|info|support|sales|contact|help|service|noreply|no-reply|postmaster|webmaster|abuse)/i
        ];

        if (rolePatterns.some(pattern => pattern.test(localPart))) {
            indicators.push({
                type: 'role_based',
                risk: this.fraudIndicators.roleBasedEmail,
                description: 'Email baseado em função (não pessoal)',
                severity: 'low'
            });
            totalRisk += this.fraudIndicators.roleBasedEmail;
        }

        // Verificar excesso de números
        const numberCount = (localPart.match(/\d/g) || []).length;
        const letterCount = (localPart.match(/[a-z]/gi) || []).length;

        if (numberCount > letterCount && numberCount > 5) {
            indicators.push({
                type: 'excessive_numbers',
                risk: this.fraudIndicators.tooManyNumbers,
                description: 'Email contém números excessivos',
                severity: 'medium'
            });
            totalRisk += this.fraudIndicators.tooManyNumbers;
        }

        // Verificar padrões suspeitos conhecidos
        const suspiciousPatterns = [
            /^[a-z]{1,2}\d{6,}$/i,  // a123456
            /^user\d{4,}$/i,         // user1234
            /^mail\d{4,}$/i,         // mail1234
            /^email\d{4,}$/i,        // email1234
            /^[a-z]+\.?bot$/i        // bot, xxx.bot
        ];

        if (suspiciousPatterns.some(pattern => pattern.test(localPart))) {
            indicators.push({
                type: 'suspicious_pattern',
                risk: this.fraudIndicators.suspiciousPattern,
                description: 'Padrão de email suspeito detectado',
                severity: 'high'
            });
            totalRisk += this.fraudIndicators.suspiciousPattern;
        }

        // Verificar se é email temporário
        if (validationResults.disposable?.isDisposable) {
            indicators.push({
                type: 'temporary_email',
                risk: this.fraudIndicators.temporaryEmail,
                description: 'Email temporário/descartável',
                severity: 'critical'
            });
            totalRisk += this.fraudIndicators.temporaryEmail;
        }

        // Análise adicional baseada em outros resultados
        if (validationResults.patterns?.suspicious) {
            const suspicionLevel = validationResults.patterns.suspicionLevel || 5;
            indicators.push({
                type: 'pattern_analysis',
                risk: suspicionLevel * 2,
                description: 'Análise de padrão detectou anomalias',
                severity: suspicionLevel >= 7 ? 'high' : 'medium'
            });
            totalRisk += suspicionLevel * 2;
        }

        return {
            indicators: indicators,
            totalRisk: totalRisk,
            riskLevel: this.calculateRiskLevel(totalRisk),
            hasIndicators: indicators.length > 0,
            summary: {
                totalIndicators: indicators.length,
                criticalIndicators: indicators.filter(i => i.severity === 'critical').length,
                highIndicators: indicators.filter(i => i.severity === 'high').length,
                mediumIndicators: indicators.filter(i => i.severity === 'medium').length,
                lowIndicators: indicators.filter(i => i.severity === 'low').length
            }
        };
    }

    // ================================================
    // NOVO MÉTODO: VELOCITY CHECK
    // ================================================
    analyzeVelocity(email, timeWindow = 3600000) { // 1 hora padrão
        if (!email || !email.includes('@')) {
            return {
                velocity: 0,
                rate: 0,
                timeSpan: 0,
                suspicious: false,
                riskLevel: 'UNKNOWN'
            };
        }

        const now = Date.now();
        const domain = email.split('@')[1];
        const ip = this.getClientIP(); // Método auxiliar para obter IP se disponível

        // Rastrear email
        const emailKey = `email:${email}`;
        if (!this.velocityTracker.has(emailKey)) {
            this.velocityTracker.set(emailKey, {
                count: 1,
                firstSeen: now,
                lastSeen: now,
                ips: new Set(ip ? [ip] : []),
                userAgents: new Set()
            });
        } else {
            const data = this.velocityTracker.get(emailKey);
            data.count++;
            data.lastSeen = now;
            if (ip) data.ips.add(ip);
        }

        // Rastrear domínio
        const domainKey = `domain:${domain}`;
        if (!this.velocityTracker.has(domainKey)) {
            this.velocityTracker.set(domainKey, {
                count: 1,
                uniqueEmails: new Set([email]),
                firstSeen: now,
                lastSeen: now
            });
        } else {
            const data = this.velocityTracker.get(domainKey);
            data.count++;
            data.uniqueEmails.add(email);
            data.lastSeen = now;
        }

        // Calcular métricas
        const emailData = this.velocityTracker.get(emailKey);
        const domainData = this.velocityTracker.get(domainKey);

        const emailVelocity = emailData.count;
        const emailTimeSpan = now - emailData.firstSeen;
        const emailRate = emailTimeSpan > 0 ? (emailVelocity / emailTimeSpan) * timeWindow : emailVelocity;

        const domainVelocity = domainData.count;
        const domainUniqueEmails = domainData.uniqueEmails.size;
        const domainTimeSpan = now - domainData.firstSeen;
        const domainRate = domainTimeSpan > 0 ? (domainVelocity / domainTimeSpan) * timeWindow : domainVelocity;

        // Detectar anomalias
        const suspicious =
            emailVelocity > this.velocityThresholds.emailPerHour ||
            emailRate > this.velocityThresholds.suspiciousRate ||
            domainUniqueEmails > this.velocityThresholds.domainPerHour ||
            (emailData.ips && emailData.ips.size > 3); // Múltiplos IPs

        // Calcular nível de risco
        let riskLevel = 'LOW';
        if (emailVelocity > 20 || domainUniqueEmails > 30) {
            riskLevel = 'CRITICAL';
        } else if (emailVelocity > 10 || domainUniqueEmails > 15) {
            riskLevel = 'HIGH';
        } else if (emailVelocity > 5 || domainUniqueEmails > 10) {
            riskLevel = 'MEDIUM';
        }

        return {
            velocity: emailVelocity,
            rate: emailRate,
            timeSpan: emailTimeSpan,
            suspicious: suspicious,
            riskLevel: riskLevel,
            details: {
                email: {
                    count: emailVelocity,
                    rate: emailRate.toFixed(2),
                    timeSpan: emailTimeSpan,
                    ips: emailData.ips ? Array.from(emailData.ips) : []
                },
                domain: {
                    count: domainVelocity,
                    uniqueEmails: domainUniqueEmails,
                    rate: domainRate.toFixed(2),
                    timeSpan: domainTimeSpan
                }
            },
            recommendations: this.getVelocityRecommendations(suspicious, riskLevel)
        };
    }

    // ================================================
    // NOVO MÉTODO: E-COMMERCE SCORE ESPECÍFICO
    // ================================================
    calculateEcommerceScore(scoreData, orderHistory = null) {
        let ecomScore = scoreData.finalScore;
        const adjustments = [];

        // Se tem histórico de pedidos
        if (orderHistory) {
            // Cliente fiel sem problemas
            if (orderHistory.totalOrders > 10 && orderHistory.chargebacks === 0) {
                const bonus = this.bonuses.loyalCustomer;
                ecomScore = Math.min(100, ecomScore + bonus);
                adjustments.push({
                    type: 'loyal_customer',
                    bonus: bonus,
                    reason: 'Cliente fiel sem chargebacks',
                    impact: 'positive'
                });
            }

            // Histórico de chargeback
            if (orderHistory.chargebacks > 0) {
                const chargebackRate = orderHistory.chargebacks / orderHistory.totalOrders;
                const penalty = Math.min(this.penalties.chargebackHistory, chargebackRate * 100);
                ecomScore = Math.max(0, ecomScore - penalty);
                adjustments.push({
                    type: 'chargeback_history',
                    penalty: penalty,
                    reason: `Taxa de chargeback: ${(chargebackRate * 100).toFixed(1)}%`,
                    impact: 'negative'
                });
            }

            // Cliente de alto valor
            if (orderHistory.averageOrderValue > 500) {
                const bonus = this.bonuses.highValueCustomer;
                ecomScore = Math.min(100, ecomScore + bonus);
                adjustments.push({
                    type: 'high_value_customer',
                    bonus: bonus,
                    reason: `Ticket médio: R$ ${orderHistory.averageOrderValue.toFixed(2)}`,
                    impact: 'positive'
                });
            }

            // Frequência de compra
            if (orderHistory.purchaseFrequency === 'frequent') {
                ecomScore = Math.min(100, ecomScore + 3);
                adjustments.push({
                    type: 'frequent_buyer',
                    bonus: 3,
                    reason: 'Comprador frequente',
                    impact: 'positive'
                });
            }

            // Tempo como cliente
            if (orderHistory.customerSince) {
                const monthsAsCustomer = this.calculateMonthsSince(orderHistory.customerSince);
                if (monthsAsCustomer > 24) {
                    ecomScore = Math.min(100, ecomScore + 5);
                    adjustments.push({
                        type: 'long_term_customer',
                        bonus: 5,
                        reason: `Cliente há ${monthsAsCustomer} meses`,
                        impact: 'positive'
                    });
                }
            }
        }

        // Ajustes baseados no tipo de comprador
        switch(scoreData.buyerType) {
            case 'TRUSTED_BUYER':
                ecomScore = Math.max(ecomScore, 75);
                break;
            case 'HIGH_RISK_BUYER':
                ecomScore = Math.min(ecomScore, 40);
                break;
            case 'CORRECTED_VALID_BUYER':
                ecomScore = Math.min(ecomScore, 85);
                break;
            case 'BLOCKED':
                ecomScore = 0;
                break;
        }

        // Ajustes baseados em fraude
        if (scoreData.fraudAnalysis && scoreData.fraudAnalysis.totalRisk > 30) {
            const penalty = Math.min(20, scoreData.fraudAnalysis.totalRisk / 3);
            ecomScore = Math.max(0, ecomScore - penalty);
            adjustments.push({
                type: 'fraud_risk',
                penalty: penalty,
                reason: 'Indicadores de fraude detectados',
                impact: 'negative'
            });
        }

        // Ajustes baseados em velocity
        if (scoreData.velocityAnalysis && scoreData.velocityAnalysis.suspicious) {
            const penalty = 10;
            ecomScore = Math.max(0, ecomScore - penalty);
            adjustments.push({
                type: 'velocity_anomaly',
                penalty: penalty,
                reason: 'Atividade suspeita detectada',
                impact: 'negative'
            });
        }

        // Finalizar score
        ecomScore = Math.round(Math.max(0, Math.min(100, ecomScore)));

        return {
            ecommerceScore: ecomScore,
            baseScore: scoreData.finalScore,
            adjustments: adjustments,
            recommendation: this.getEcommerceRecommendation(ecomScore),
            requiresVerification: ecomScore >= 45 && ecomScore < 70,
            autoApprove: ecomScore >= 85,
            autoReject: ecomScore < 30,
            riskProfile: {
                fraudRisk: scoreData.fraudProbability,
                chargebackRisk: this.calculateChargebackRisk(ecomScore, orderHistory),
                deliveryRisk: this.calculateDeliveryRisk(scoreData, orderHistory)
            },
            suggestedActions: this.getSuggestedActions(ecomScore, scoreData, orderHistory)
        };
    }

    // ================================================
    // NOVO MÉTODO: API RESPONSE
    // ================================================
    toAPIResponse(scoreData) {
        return {
            email: scoreData.metadata.email,
            valid: scoreData.valid,
            score: scoreData.finalScore,
            confidence: scoreData.confidence,
            buyer_type: scoreData.buyerType,
            risk_level: scoreData.riskLevel,
            fraud_probability: scoreData.fraudProbability,
            popularity: scoreData.popularity,
            domain_type: scoreData.domainType,
            fraud_analysis: {
                has_indicators: scoreData.fraudAnalysis.hasIndicators,
                risk_level: scoreData.fraudAnalysis.riskLevel,
                total_risk: scoreData.fraudAnalysis.totalRisk,
                indicators_count: scoreData.fraudAnalysis.indicators.length
            },
            velocity_analysis: {
                suspicious: scoreData.velocityAnalysis.suspicious,
                risk_level: scoreData.velocityAnalysis.riskLevel,
                velocity: scoreData.velocityAnalysis.velocity
            },
            recommendations: scoreData.recommendations.map(r => ({
                action: r.action,
                message: r.message,
                priority: r.priority
            })),
            insights: {
                quality: this.getQualityLabel(scoreData.finalScore),
                is_mainstream: scoreData.insights.isMainstream,
                is_corporative: scoreData.insights.isCorporative,
                was_corrected: scoreData.metadata.wasCorrected,
                popularity_tier: scoreData.insights.popularityTier,
                popularity_label: scoreData.insights.popularityLabel,
                domain_type_label: scoreData.insights.domainTypeLabel,
                trust_score: scoreData.insights.trustScore,
                fraud_risk: scoreData.insights.fraudRisk,
                velocity_status: scoreData.insights.velocityStatus
            },
            metadata: {
                timestamp: scoreData.metadata.timestamp,
                processing_time: scoreData.metadata.processingTime,
                version: '2.0'
            }
        };
    }

    // ================================================
    // NOVO MÉTODO: COMPARAR SCORES
    // ================================================
    compareScores(score1, score2) {
        const diff = score1.finalScore - score2.finalScore;
        const improvement = diff > 0;
        const significant = Math.abs(diff) >= 10;

        const analysis = {
            score1: score1.finalScore,
            score2: score2.finalScore,
            difference: diff,
            percentChange: score2.finalScore > 0 ? ((diff / score2.finalScore) * 100).toFixed(2) : 0,
            improved: improvement,
            significant: significant,
            changes: {
                buyerType: {
                    changed: score1.buyerType !== score2.buyerType,
                    from: score2.buyerType,
                    to: score1.buyerType,
                    improvement: this.isBuyerTypeImprovement(score2.buyerType, score1.buyerType)
                },
                riskLevel: {
                    changed: score1.riskLevel !== score2.riskLevel,
                    from: score2.riskLevel,
                    to: score1.riskLevel,
                    improvement: this.isRiskLevelImprovement(score2.riskLevel, score1.riskLevel)
                },
                validity: {
                    changed: score1.valid !== score2.valid,
                    from: score2.valid,
                    to: score1.valid,
                    improvement: !score2.valid && score1.valid
                },
                confidence: {
                    changed: score1.confidence !== score2.confidence,
                    from: score2.confidence,
                    to: score1.confidence,
                    improvement: this.isConfidenceImprovement(score2.confidence, score1.confidence)
                }
            },
            breakdown: {
                score1Components: score1.breakdown,
                score2Components: score2.breakdown,
                mainDifferences: this.identifyMainDifferences(score1.breakdown, score2.breakdown)
            },
            recommendations: {
                action: improvement && significant ? 'UPDATE_APPROVED' :
                       !improvement && significant ? 'REVIEW_REQUIRED' :
                       'NO_ACTION',
                message: this.getComparisonMessage(diff, significant)
            }
        };

        return analysis;
    }

    // ================================================
    // NOVO MÉTODO: BATCH SCORE
    // ================================================
    async batchScore(validationResultsArray, options = {}) {
        const results = [];
        const errors = [];
        const batchId = `batch_${Date.now()}`;

        const batchStats = {
            batchId: batchId,
            total: validationResultsArray.length,
            processed: 0,
            successful: 0,
            failed: 0,
            valid: 0,
            invalid: 0,
            averageScore: 0,
            averageProcessingTime: 0,
            totalProcessingTime: 0,
            startTime: Date.now(),
            endTime: null
        };

        this.stats.batchesProcessed++;

        // Processar em chunks para melhor performance
        const chunkSize = options.chunkSize || 100;
        const chunks = [];

        for (let i = 0; i < validationResultsArray.length; i += chunkSize) {
            chunks.push(validationResultsArray.slice(i, i + chunkSize));
        }

        for (const [chunkIndex, chunk] of chunks.entries()) {
            const chunkResults = await Promise.all(
                chunk.map(async (validationResult, index) => {
                    const itemIndex = chunkIndex * chunkSize + index;

                    try {
                        const scoreResult = this.calculateScore(validationResult);

                        batchStats.processed++;
                        batchStats.successful++;

                        if (scoreResult.valid) {
                            batchStats.valid++;
                        } else {
                            batchStats.invalid++;
                        }

                        batchStats.averageScore += scoreResult.finalScore;
                        batchStats.totalProcessingTime += scoreResult.metadata.processingTime || 0;

                        // Callback de progresso
                        if (options.onProgress) {
                            const progress = {
                                processed: batchStats.processed,
                                total: batchStats.total,
                                percentage: ((batchStats.processed / batchStats.total) * 100).toFixed(2),
                                currentItem: validationResult.email,
                                batchId: batchId
                            };

                            if (batchStats.processed % 10 === 0 || batchStats.processed === batchStats.total) {
                                options.onProgress(progress);
                            }
                        }

                        return {
                            index: itemIndex,
                            success: true,
                            result: scoreResult
                        };
                    } catch (error) {
                        batchStats.processed++;
                        batchStats.failed++;

                        const errorResult = {
                            index: itemIndex,
                            success: false,
                            email: validationResult.email || 'unknown',
                            error: error.message,
                            result: this.createEmptyScore(`Error: ${error.message}`)
                        };

                        errors.push(errorResult);

                        console.error(`Erro ao processar score para ${validationResult.email}:`, error);

                        return errorResult;
                    }
                })
            );

            results.push(...chunkResults);
        }

        // Finalizar estatísticas
        batchStats.endTime = Date.now();
        batchStats.processingTime = batchStats.endTime - batchStats.startTime;
        batchStats.averageScore = batchStats.successful > 0
            ? (batchStats.averageScore / batchStats.successful).toFixed(2)
            : 0;
        batchStats.averageProcessingTime = batchStats.successful > 0
            ? (batchStats.totalProcessingTime / batchStats.successful).toFixed(2)
            : 0;

        // Callback de conclusão
        if (options.onComplete) {
            options.onComplete(batchStats);
        }

        return {
            batchId: batchId,
            results: results.sort((a, b) => a.index - b.index).map(r => r.result),
            errors: errors,
            stats: batchStats,
            summary: {
                successRate: ((batchStats.successful / batchStats.total) * 100).toFixed(2) + '%',
                validRate: ((batchStats.valid / batchStats.total) * 100).toFixed(2) + '%',
                averageScore: batchStats.averageScore,
                processingSpeed: (batchStats.total / (batchStats.processingTime / 1000)).toFixed(2) + ' emails/segundo'
            }
        };
    }

    // ================================================
    // MÉTODOS DE CÁLCULO DE PONTOS
    // ================================================

    calculatePopularityPoints(popularityAnalysis, isDisposable) {
        if (isDisposable) return 0;

        switch(popularityAnalysis.tier) {
            case 1: return 10; // Gmail, Outlook, etc
            case 2: return 9;  // iCloud, ProtonMail
            case 3: return 8;  // Domínios brasileiros
            case 4: return 7;  // Corporativos
            case 5: return 5;  // Genéricos
            case 6: return 0;  // Suspeitos
            default: return 4;
        }
    }

    calculateDomainTrustPoints(isTrusted, category, trustScore, isSuspicious) {
        let points = 5; // Base

        if (isTrusted || trustScore >= 70) {
            points = 9;

            if (category === 'mainstream' || trustScore >= 90) {
                points = 10;
            } else if (category === 'business' || category === 'educational') {
                points = 9;
            }
        } else if (trustScore >= 50) {
            points = 7;
        } else if (trustScore >= 30) {
            points = 5;
        }

        if (isSuspicious && trustScore < 70) {
            points = Math.max(0, points - 3);
        }

        return points;
    }

    calculateTLDPoints(tld, isTrusted, wasCorrected) {
        if (!tld || !tld.type) return 5;

        let points = 5;

        switch(tld.type) {
            case 'generic':
                points = isTrusted ? 9 : 7;
                break;
            case 'country':
                // Verificar TLDs brasileiros
                if (tld.tld === '.br' || tld.tld === '.com.br') {
                    points = 8;
                } else {
                    points = 6;
                }
                break;
            case 'sponsored':
                points = 8;
                break;
            case 'infrastructure':
                points = 3;
                break;
            case 'test':
                points = 1;
                break;
            default:
                points = 5;
        }

        if (wasCorrected) {
            points = Math.max(0, points - 1);
        }

        return points;
    }

    calculateDisposablePoints(disposableCheck, isTrusted, domain, wasCorrected) {
        if (!disposableCheck) return 5;

        let points = 10;

        if (disposableCheck.isDisposable) {
            points = 0;

            // Se é confiável mas detectado como descartável, pode ser falso positivo
            if (isTrusted) {
                points = 3;
            }
        } else if (disposableCheck.suspicious) {
            points = 5;
        }

        if (wasCorrected && points > 0) {
            points = Math.max(0, points - 1);
        }

        return points;
    }

    calculateMXPoints(mxValidation, isMainstream) {
        if (!mxValidation) {
            return isMainstream ? 8 : 5;
        }

        let points = 0;

        switch(mxValidation.analysis?.quality) {
            case 'excellent':
                points = 10;
                break;
            case 'good':
                points = 9;
                break;
            case 'acceptable':
                points = 7;
                break;
            case 'poor':
                points = isMainstream ? 6 : 4;
                break;
            case 'invalid':
                points = isMainstream ? 5 : 2;
                break;
            default:
                points = 6;
        }

        // Bônus por provedor conhecido
        const trustedProviders = [
            'Google Workspace',
            'Microsoft 365',
            'Amazon SES',
            'ProtonMail',
            'Zoho'
        ];

        if (trustedProviders.includes(mxValidation.emailProvider)) {
            points = Math.min(10, points + 1);
        }

        // Menos penalidade para mainstream
        if (mxValidation.mxServersReachable && !isMainstream) {
            const totalServers = mxValidation.mxServersReachable.length;
            const reachableServers = mxValidation.mxServersReachable.filter(s => s.reachable).length;

            if (totalServers > 0 && reachableServers === 0) {
                points = Math.max(3, points - 3);
            }
        }

        return points;
    }

    calculateSMTPPoints(smtp, isTrusted, wasCorrected, isMainstream) {
        if (!smtp) {
            return isMainstream ? 7 : 5;
        }

        let points = 0;

        if (smtp.exists) {
            points = 10;
        } else if (smtp.catchAll) {
            points = isMainstream ? 8 : 7;
        } else {
            points = isMainstream ? 6 : 3;
        }

        if (isTrusted && !smtp.exists) {
            points = Math.max(points, 6);
        }

        if (wasCorrected) {
            points = Math.max(0, points - 1);
        }

        return points;
    }

    calculatePatternPoints(patterns, isSuspicious, wasCorrected) {
        if (!patterns) return 7;

        let points = 10;

        if (patterns.suspicious) {
            const level = patterns.suspicionLevel || 0;

            if (level >= 8) {
                points = 2;
            } else if (level >= 6) {
                points = 4;
            } else if (level >= 4) {
                points = 6;
            } else {
                points = 8;
            }
        }

        if (patterns.isSequential) {
            points = Math.max(0, points - 3);
        }

        if (patterns.hasRandomString) {
            points = Math.max(0, points - 2);
        }

        if (patterns.tooManyNumbers) {
            points = Math.max(0, points - 1);
        }

        if (isSuspicious) {
            points = Math.max(0, points - 2);
        }

        if (wasCorrected) {
            points = Math.max(0, points - 1);
        }

        return points;
    }

    calculateFormatPoints(email, isSuspicious, wasCorrected) {
        if (!email || !email.includes('@')) return 0;

        let points = 10;
        const [localPart, domain] = email.split('@');

        // Verificar comprimento
        if (localPart.length < 2 || localPart.length > 64) {
            points -= 3;
        }

        // Verificar caracteres especiais excessivos
        const specialChars = (localPart.match(/[._\-+]/g) || []).length;
        if (specialChars > 2) {
            points -= 2;
        }

        // Verificar início ou fim com caracteres especiais
        if (/^[._\-+]|[._\-+]$/.test(localPart)) {
            points -= 2;
        }

        // Verificar formato profissional (nome.sobrenome)
        if (/^[a-z]+\.[a-z]+$/.test(localPart)) {
            points = Math.min(10, points + 2);
        }

        // Verificar números excessivos
        const numbers = (localPart.match(/\d/g) || []).length;
        if (numbers > localPart.length / 2) {
            points -= 3;
        }

        if (isSuspicious) {
            points = Math.max(0, points - 2);
        }

        if (wasCorrected) {
            points = Math.max(0, points - 1);
        }

        return Math.max(0, points);
    }

    // ================================================
    // MÉTODOS DE CLASSIFICAÇÃO
    // ================================================

    classifyBuyer(score, isSuspicious, wasCorrected, mxQuality, popularityAnalysis) {
        // Tier 1 com score alto = sempre confiável
        if (popularityAnalysis.tier === 1 && score >= 80) {
            return 'TRUSTED_BUYER';
        }

        // MX inválido em domínio não popular
        if (mxQuality === 'invalid' && popularityAnalysis.tier > 3) {
            return 'HIGH_RISK_BUYER';
        }

        // Emails corrigidos
        if (wasCorrected) {
            if (score >= 70) return 'CORRECTED_VALID_BUYER';
            if (score >= 55) return 'CORRECTED_REGULAR_BUYER';
            if (score >= 45) return 'CORRECTED_SUSPICIOUS_BUYER';
            return 'CORRECTED_HIGH_RISK_BUYER';
        }

        // Suspeitos em domínios não populares
        if (isSuspicious && popularityAnalysis.tier > 4) {
            return score >= 60 ? 'SUSPICIOUS_BUYER' : 'HIGH_RISK_BUYER';
        }

        // Classificação padrão
        if (score >= 75) return 'TRUSTED_BUYER';
        if (score >= 65) return 'REGULAR_BUYER';
        if (score >= 55) return 'NEW_BUYER';
        if (score >= 45) return 'SUSPICIOUS_BUYER';
        return 'HIGH_RISK_BUYER';
    }

    assessRisk(score, wasCorrected, mxQuality, popularityAnalysis, fraudAnalysis, velocityAnalysis) {
        let adjustment = 0;

        // Ajuste baseado em popularidade
        if (popularityAnalysis.tier === 1) {
            adjustment -= 10;
        } else if (popularityAnalysis.tier === 2) {
            adjustment -= 5;
        } else if (popularityAnalysis.tier >= 5) {
            adjustment += 10;
        }

        // Ajuste por correção
        if (wasCorrected) adjustment += 5;

        // Ajuste por MX
        if (mxQuality === 'invalid') {
            adjustment += 15;
        } else if (mxQuality === 'poor') {
            adjustment += 8;
        } else if (mxQuality === 'excellent') {
            adjustment -= 5;
        }

        // Ajuste por fraude
        if (fraudAnalysis && fraudAnalysis.totalRisk > 20) {
            adjustment += 10;
        }

        // Ajuste por velocity
        if (velocityAnalysis && velocityAnalysis.suspicious) {
            adjustment += 10;
        }

        const adjustedScore = score - adjustment;

        if (adjustedScore >= 75) return 'VERY_LOW';
        if (adjustedScore >= 65) return 'LOW';
        if (adjustedScore >= 55) return 'MEDIUM';
        if (adjustedScore >= 45) return 'HIGH';
        return 'VERY_HIGH';
    }

    calculateFraudProbability(score, results, isTrustedDomain, isSuspicious, wasCorrected, mxBreakdown, popularityAnalysis, fraudAnalysis, velocityAnalysis) {
       let probability = 100 - score;

       // Ajuste por popularidade
       if (popularityAnalysis.tier === 1) {
           probability = Math.max(5, probability - 25);
       } else if (popularityAnalysis.tier === 2) {
           probability = Math.max(5, probability - 15);
       } else if (popularityAnalysis.tier >= 5) {
           probability = Math.min(95, probability + 20);
       }

       if (isTrustedDomain) {
           probability = Math.max(5, probability - 15);
       }

       if (isSuspicious && popularityAnalysis.tier > 3) {
           probability = Math.min(95, probability + 25);
       }

       if (wasCorrected) {
           probability = Math.min(95, probability + 5);
       }

       // Ajuste por fraude detectada
       if (fraudAnalysis && fraudAnalysis.hasIndicators) {
           const fraudAdjustment = Math.min(30, fraudAnalysis.totalRisk / 2);
           probability = Math.min(95, probability + fraudAdjustment);
       }

       // Ajuste por velocity
       if (velocityAnalysis && velocityAnalysis.suspicious) {
           const velocityAdjustment = velocityAnalysis.riskLevel === 'HIGH' ? 20 : 10;
           probability = Math.min(95, probability + velocityAdjustment);
       }

       if (results.disposable && results.disposable.isDisposable) {
           probability = Math.min(95, probability + 30);
       }

       return Math.min(95, Math.max(5, probability));
   }

   determineConfidence(score, wasCorrected, mxQuality, popularityAnalysis) {
       let adjustment = 0;

       // Boost para domínios populares
       if (popularityAnalysis.tier <= 2) {
           adjustment -= 10;
       }

       if (wasCorrected) adjustment += 5;

       if (mxQuality === 'poor' || mxQuality === 'invalid') {
           adjustment += 10;
       } else if (mxQuality === 'excellent') {
           adjustment -= 5;
       }

       const adjustedScore = score - adjustment;

       if (adjustedScore >= 75) return 'very_high';
       if (adjustedScore >= 65) return 'high';
       if (adjustedScore >= 55) return 'medium';
       if (adjustedScore >= 45) return 'low';
       return 'very_low';
   }

   // ================================================
   // MÉTODO DE RECOMENDAÇÕES
   // ================================================
   generateRecommendations(score, results, isTrusted, blockCheck, scoreData) {
       const recommendations = [];

       // Recomendação principal baseada no score
       if (score >= 80) {
           recommendations.push({
               action: 'APPROVE',
               message: 'Email de alta qualidade. Aprovado para todas as comunicações.',
               priority: 'info'
           });
       } else if (score >= 70) {
           recommendations.push({
               action: 'APPROVE',
               message: 'Email confiável. Aprovado para comunicações normais.',
               priority: 'info'
           });
       } else if (score >= 60) {
           recommendations.push({
               action: 'REVIEW',
               message: 'Email regular. Revisar histórico de compras antes de aprovar.',
               priority: 'medium'
           });
       } else if (score >= 45) {
           recommendations.push({
               action: 'CAUTION',
               message: 'Email suspeito. Usar com cautela e monitorar atividade.',
               priority: 'high'
           });
       } else {
           recommendations.push({
               action: 'REJECT',
               message: 'Email de baixa qualidade. Não recomendado para uso.',
               priority: 'critical'
           });
       }

       // Recomendações específicas para fraude
       if (scoreData.fraudAnalysis && scoreData.fraudAnalysis.hasIndicators) {
           scoreData.fraudAnalysis.indicators.forEach(indicator => {
               if (indicator.severity === 'critical' || indicator.severity === 'high') {
                   recommendations.push({
                       action: 'FRAUD_ALERT',
                       message: `Alerta de fraude: ${indicator.description}`,
                       priority: indicator.severity
                   });
               }
           });
       }

       // Recomendações para velocity
       if (scoreData.velocityAnalysis && scoreData.velocityAnalysis.suspicious) {
           recommendations.push({
               action: 'VELOCITY_CHECK',
               message: `Atividade suspeita: ${scoreData.velocityAnalysis.velocity} tentativas em ${scoreData.velocityAnalysis.timeSpan}ms`,
               priority: scoreData.velocityAnalysis.riskLevel === 'HIGH' ? 'high' : 'medium'
           });
       }

       // Recomendações específicas
       if (results.wasCorrected) {
           recommendations.push({
               action: 'INFO',
               message: 'Email continha erro de digitação que foi corrigido.',
               priority: 'low'
           });
       }

       if (results.disposable?.isDisposable) {
           recommendations.push({
               action: 'WARNING',
               message: 'Email temporário/descartável detectado. Alto risco de fraude.',
               priority: 'critical'
           });
       }

       if (scoreData.breakdown.mx?.quality === 'poor' || scoreData.breakdown.mx?.quality === 'invalid') {
           recommendations.push({
               action: 'TECHNICAL',
               message: 'Configuração de email do domínio tem problemas. Pode haver falhas de entrega.',
               priority: 'medium'
           });
       }

       if (blockCheck?.suspicious) {
           recommendations.push({
               action: 'SECURITY',
               message: `Email suspeito: ${blockCheck.reason}`,
               priority: 'high'
           });
       }

       if (scoreData.insights.isMainstream) {
           recommendations.push({
               action: 'INFO',
               message: 'Domínio de email popular e confiável.',
               priority: 'info'
           });
       }

       return recommendations;
   }

   // ================================================
   // MÉTODOS AUXILIARES PARA ANÁLISE
   // ================================================

   calculateRiskLevel(riskPoints) {
       if (riskPoints >= 50) return 'CRITICAL';
       if (riskPoints >= 35) return 'VERY_HIGH';
       if (riskPoints >= 25) return 'HIGH';
       if (riskPoints >= 15) return 'MEDIUM';
       if (riskPoints >= 5) return 'LOW';
       return 'VERY_LOW';
   }

   getVelocityRecommendations(suspicious, riskLevel) {
       const recommendations = [];

       if (suspicious) {
           if (riskLevel === 'CRITICAL') {
               recommendations.push('Bloquear temporariamente');
               recommendations.push('Exigir verificação adicional');
           } else if (riskLevel === 'HIGH') {
               recommendations.push('Implementar rate limiting');
               recommendations.push('Monitorar atividade');
           } else {
               recommendations.push('Acompanhar próximas tentativas');
           }
       }

       return recommendations;
   }

   getEcommerceRecommendation(score) {
       if (score >= 85) {
           return {
               action: 'AUTO_APPROVE',
               message: 'Aprovar automaticamente. Cliente confiável.',
               color: 'green',
               suggestedLimit: 'normal',
               fraudCheck: false
           };
       } else if (score >= 70) {
           return {
               action: 'APPROVE',
               message: 'Aprovar com monitoramento padrão.',
               color: 'blue',
               suggestedLimit: 'normal',
               fraudCheck: false
           };
       } else if (score >= 55) {
           return {
               action: 'MANUAL_REVIEW',
               message: 'Revisar manualmente antes de aprovar.',
               color: 'yellow',
               suggestedLimit: 'reduced',
               fraudCheck: true
           };
       } else if (score >= 40) {
           return {
               action: 'VERIFY',
               message: 'Verificação adicional necessária.',
               color: 'orange',
               suggestedLimit: 'minimal',
               fraudCheck: true
           };
       } else {
           return {
               action: 'REJECT',
               message: 'Rejeitar ou exigir pagamento antecipado.',
               color: 'red',
               suggestedLimit: 'none',
               fraudCheck: true
           };
       }
   }

   calculateChargebackRisk(ecomScore, orderHistory) {
       let risk = 100 - ecomScore;

       if (orderHistory) {
           if (orderHistory.chargebacks > 0) {
               const chargebackRate = orderHistory.chargebacks / orderHistory.totalOrders;
               risk += chargebackRate * 50;
           }

           if (orderHistory.disputes > 0) {
               risk += 10;
           }

           if (orderHistory.refunds > orderHistory.totalOrders * 0.1) {
               risk += 15;
           }
       }

       return Math.min(100, Math.max(0, risk));
   }

   calculateDeliveryRisk(scoreData, orderHistory) {
       let risk = 0;

       // Risco baseado no score
       if (scoreData.finalScore < 50) {
           risk += 30;
       } else if (scoreData.finalScore < 70) {
           risk += 15;
       }

       // Risco baseado em fraude
       if (scoreData.fraudAnalysis && scoreData.fraudAnalysis.hasIndicators) {
           risk += 20;
       }

       // Risco baseado no histórico
       if (orderHistory && orderHistory.deliveryIssues > 0) {
           risk += orderHistory.deliveryIssues * 10;
       }

       return Math.min(100, Math.max(0, risk));
   }

   getSuggestedActions(ecomScore, scoreData, orderHistory) {
       const actions = [];

       if (ecomScore >= 85) {
           actions.push({
               type: 'payment',
               action: 'Liberar todos os métodos de pagamento',
               priority: 'low'
           });
           actions.push({
               type: 'shipping',
               action: 'Liberar envio expresso',
               priority: 'low'
           });
       } else if (ecomScore >= 70) {
           actions.push({
               type: 'payment',
               action: 'Liberar pagamentos padrão',
               priority: 'medium'
           });
           actions.push({
               type: 'monitoring',
               action: 'Monitoramento padrão',
               priority: 'low'
           });
       } else if (ecomScore >= 55) {
           actions.push({
               type: 'verification',
               action: 'Solicitar confirmação de identidade',
               priority: 'high'
           });
           actions.push({
               type: 'payment',
               action: 'Limitar a cartão de crédito verificado',
               priority: 'high'
           });
       } else if (ecomScore >= 40) {
           actions.push({
               type: 'verification',
               action: 'Verificação completa obrigatória',
               priority: 'critical'
           });
           actions.push({
               type: 'payment',
               action: 'Apenas pagamento antecipado',
               priority: 'critical'
           });
           actions.push({
               type: 'monitoring',
               action: 'Monitoramento intensivo',
               priority: 'high'
           });
       } else {
           actions.push({
               type: 'block',
               action: 'Bloquear transação',
               priority: 'critical'
           });
           actions.push({
               type: 'security',
               action: 'Adicionar à lista de observação',
               priority: 'critical'
           });
       }

       // Ações baseadas em fraude
       if (scoreData.fraudAnalysis && scoreData.fraudAnalysis.hasIndicators) {
           actions.push({
               type: 'fraud',
               action: 'Análise antifraude aprofundada',
               priority: 'high'
           });
       }

       // Ações baseadas em velocity
       if (scoreData.velocityAnalysis && scoreData.velocityAnalysis.suspicious) {
           actions.push({
               type: 'rate_limit',
               action: 'Aplicar rate limiting',
               priority: 'high'
           });
       }

       return actions;
   }

   calculateMonthsSince(date) {
       const now = new Date();
       const past = new Date(date);
       const months = (now.getFullYear() - past.getFullYear()) * 12 + (now.getMonth() - past.getMonth());
       return Math.max(0, months);
   }

   isBuyerTypeImprovement(from, to) {
       const hierarchy = {
           'HIGH_RISK_BUYER': 1,
           'SUSPICIOUS_BUYER': 2,
           'NEW_BUYER': 3,
           'REGULAR_BUYER': 4,
           'TRUSTED_BUYER': 5
       };

       const fromValue = hierarchy[from] || 0;
       const toValue = hierarchy[to] || 0;

       return toValue > fromValue;
   }

   isRiskLevelImprovement(from, to) {
       const hierarchy = {
           'CRITICAL': 1,
           'VERY_HIGH': 2,
           'HIGH': 3,
           'MEDIUM': 4,
           'LOW': 5,
           'VERY_LOW': 6
       };

       const fromValue = hierarchy[from] || 0;
       const toValue = hierarchy[to] || 0;

       return toValue > fromValue;
   }

   isConfidenceImprovement(from, to) {
       const hierarchy = {
           'very_low': 1,
           'low': 2,
           'medium': 3,
           'high': 4,
           'very_high': 5
       };

       const fromValue = hierarchy[from] || 0;
       const toValue = hierarchy[to] || 0;

       return toValue > fromValue;
   }

   identifyMainDifferences(breakdown1, breakdown2) {
       const differences = [];

       if (!breakdown1 || !breakdown2) return differences;

       Object.keys(breakdown1).forEach(key => {
           if (breakdown2[key]) {
               const diff = (breakdown1[key].points || 0) - (breakdown2[key].points || 0);
               if (Math.abs(diff) >= 2) {
                   differences.push({
                       component: key,
                       change: diff,
                       from: breakdown2[key].points || 0,
                       to: breakdown1[key].points || 0,
                       impact: diff > 0 ? 'positive' : 'negative'
                   });
               }
           }
       });

       return differences.sort((a, b) => Math.abs(b.change) - Math.abs(a.change));
   }

   getComparisonMessage(diff, significant) {
       if (significant) {
           if (diff > 0) {
               return `Score melhorou significativamente (+${diff} pontos)`;
           } else {
               return `Score piorou significativamente (${diff} pontos)`;
           }
       } else {
           if (Math.abs(diff) < 5) {
               return 'Mudança mínima no score';
           } else {
               return `Mudança moderada no score (${diff > 0 ? '+' : ''}${diff} pontos)`;
           }
       }
   }

   getClientIP() {
       // Placeholder - em produção, obter do request
       return null;
   }

   cleanupVelocityTracker() {
       const now = Date.now();
       const expirationTime = 86400000; // 24 horas

       for (const [key, data] of this.velocityTracker.entries()) {
           if (now - data.lastSeen > expirationTime) {
               this.velocityTracker.delete(key);
           }
       }

       this.logDebug(`Velocity tracker limpo. Entradas ativas: ${this.velocityTracker.size}`);
   }

   // ================================================
   // MÉTODOS AUXILIARES
   // ================================================

   getQualityLabel(score) {
       if (score >= 90) return 'Excelente';
       if (score >= 80) return 'Muito Boa';
       if (score >= 70) return 'Boa';
       if (score >= 60) return 'Regular';
       if (score >= 45) return 'Baixa';
       return 'Muito Baixa';
   }

   createEmptyScore(reason) {
       return {
           baseScore: 0,
           finalScore: 0,
           valid: false,
           confidence: 'none',
           buyerType: 'INVALID',
           riskLevel: 'CRITICAL',
           fraudProbability: 100,
           fraudAnalysis: {
               indicators: [],
               totalRisk: 0,
               riskLevel: 'UNKNOWN',
               hasIndicators: false
           },
           velocityAnalysis: {
               velocity: 0,
               rate: 0,
               timeSpan: 0,
               suspicious: false,
               riskLevel: 'UNKNOWN'
           },
           recommendations: [{
               action: 'ERROR',
               message: reason,
               priority: 'critical'
           }],
           breakdown: {},
           insights: {
               error: true,
               errorReason: reason
           },
           metadata: {
               error: reason,
               processingTime: 0,
               timestamp: new Date().toISOString()
           }
       };
   }

   updateStatistics(scoreData) {
       // Atualizar contadores
       if (scoreData.finalScore >= 70) {
           this.stats.approved++;
       } else if (scoreData.finalScore >= 45) {
           this.stats.review++;
       } else {
           this.stats.rejected++;
       }

       if (scoreData.metadata.isTrustedDomain) {
           this.stats.trustedDomains++;
       }

       if (scoreData.metadata.suspicious) {
           this.stats.suspiciousEmails++;
       }

       if (scoreData.breakdown.disposable?.isDisposable) {
           this.stats.disposableEmails++;
       }

       // Atualizar distribuição
       if (scoreData.finalScore <= 25) {
           this.stats.scoreDistribution['0-25']++;
       } else if (scoreData.finalScore <= 45) {
           this.stats.scoreDistribution['26-45']++;
       } else if (scoreData.finalScore <= 60) {
           this.stats.scoreDistribution['46-60']++;
       } else if (scoreData.finalScore <= 75) {
           this.stats.scoreDistribution['61-75']++;
       } else if (scoreData.finalScore <= 90) {
           this.stats.scoreDistribution['76-90']++;
       } else {
           this.stats.scoreDistribution['91-100']++;
       }

       // Atualizar média
       const totalScores = Object.values(this.stats.scoreDistribution).reduce((a, b) => a + b, 0);
       if (totalScores > 0) {
           // Cálculo simplificado da média
           this.stats.averageScore = Math.round(
               (this.stats.approved * 80 + this.stats.review * 55 + this.stats.rejected * 25) /
               (this.stats.approved + this.stats.review + this.stats.rejected)
           );
       }
   }

   getStatistics() {
       const avgProcessingTime = this.stats.processingTimes.length > 0
           ? (this.stats.processingTimes.reduce((a, b) => a + b, 0) / this.stats.processingTimes.length).toFixed(2)
           : 0;

       return {
           ...this.stats,
           successRate: this.stats.totalScored > 0
               ? ((this.stats.approved / this.stats.totalScored) * 100).toFixed(2) + '%'
               : '0%',
           reviewRate: this.stats.totalScored > 0
               ? ((this.stats.review / this.stats.totalScored) * 100).toFixed(2) + '%'
               : '0%',
           rejectionRate: this.stats.totalScored > 0
               ? ((this.stats.rejected / this.stats.totalScored) * 100).toFixed(2) + '%'
               : '0%',
           fraudDetectionRate: this.stats.totalScored > 0
               ? ((this.stats.fraudDetected / this.stats.totalScored) * 100).toFixed(2) + '%'
               : '0%',
           velocityBlockRate: this.stats.totalScored > 0
               ? ((this.stats.velocityBlocked / this.stats.totalScored) * 100).toFixed(2) + '%'
               : '0%',
           averageProcessingTime: avgProcessingTime + 'ms',
           velocityTrackerSize: this.velocityTracker.size
       };
   }

   resetStatistics() {
       this.stats = {
           totalScored: 0,
           approved: 0,
           rejected: 0,
           review: 0,
           correctedEmails: 0,
           trustedDomains: 0,
           suspiciousEmails: 0,
           disposableEmails: 0,
           fraudDetected: 0,
           velocityBlocked: 0,
           averageScore: 0,
           scoreDistribution: {
               '0-25': 0,
               '26-45': 0,
               '46-60': 0,
               '61-75': 0,
               '76-90': 0,
               '91-100': 0
           },
           processingTimes: [],
           batchesProcessed: 0
       };
       this.velocityTracker.clear();
       this.logDebug('Estatísticas e velocity tracker resetados');
   }

   // Limpar interval ao destruir a instância
   destroy() {
       if (this.velocityCleanupInterval) {
           clearInterval(this.velocityCleanupInterval);
       }
       this.velocityTracker.clear();
       this.logDebug('EcommerceScoring destruído e recursos liberados');
   }

   logDebug(message) {
       if (this.debug) {
           console.log(`[EcommerceScoring] ${message}`);
       }
   }
}

module.exports = EcommerceScoring;
