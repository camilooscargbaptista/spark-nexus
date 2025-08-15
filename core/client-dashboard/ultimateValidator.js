// ================================================
// Ultimate Email Validator - v4.0
// Sistema completo de validação com todas funcionalidades críticas
// ================================================

const dns = require('dns').promises;
const net = require('net');

// Importar validadores avançados existentes
const DomainCorrector = require('./services/validators/advanced/DomainCorrector');
const BlockedDomains = require('./services/validators/advanced/BlockedDomains');
const DisposableChecker = require('./services/validators/advanced/DisposableChecker');
const TLDValidator = require('./services/validators/advanced/TLDValidator');
const PatternDetector = require('./services/validators/advanced/PatternDetector');
const SMTPValidator = require('./services/validators/advanced/SMTPValidator');
const TrustedDomains = require('./services/validators/advanced/TrustedDomains');
const EcommerceScoring = require('./services/validators/advanced/EcommerceScoring');
const MXValidator = require('./services/validators/advanced/MXValidator');

// NOVO: Importar validadores críticos adicionados
const RFCValidator = require('./services/validators/advanced/RFCValidator');
const CatchAllDetector = require('./services/validators/advanced/CatchAllDetector');
const RoleBasedDetector = require('./services/validators/advanced/RoleBasedDetector');
const SpamtrapDetector = require('./services/validators/advanced/SpamtrapDetector');
const BounceTracker = require('./services/validators/advanced/BounceTracker');

class UltimateValidator {
    constructor(options = {}) {
        // ================================================
        // CONFIGURAÇÕES EXPANDIDAS
        // ================================================
        this.options = {
            // Configurações existentes
            enableSMTP: options.enableSMTP !== false,
            enableCache: options.enableCache !== false,
            smtpTimeout: options.smtpTimeout || 5000,
            scoreThreshold: options.scoreThreshold || 45,
            enableCorrection: options.enableCorrection !== false,
            maxCacheSize: options.maxCacheSize || 10000,
            cacheExpiry: options.cacheExpiry || 3600000,
            debug: options.debug || false,

            // NOVO: Configurações adicionais
            enableRFCValidation: options.enableRFCValidation !== false,
            enableCatchAllDetection: options.enableCatchAllDetection !== false,
            enableRoleBasedDetection: options.enableRoleBasedDetection !== false,
            enableSpamtrapDetection: options.enableSpamtrapDetection !== false,
            enableBounceTracking: options.enableBounceTracking !== false,
            catchAllTimeout: options.catchAllTimeout || 8000,
            batchSize: options.batchSize || 10,
            parallelValidation: options.parallelValidation || false
        };

        // ================================================
        // INICIALIZAR TODOS OS VALIDADORES
        // ================================================

        // Validadores existentes
        this.domainCorrector = new DomainCorrector();
        this.blockedDomains = new BlockedDomains();
        this.disposableChecker = new DisposableChecker();
        this.tldValidator = new TLDValidator();
        this.patternDetector = new PatternDetector();
        this.smtpValidator = new SMTPValidator({ timeout: this.options.smtpTimeout });
        this.trustedDomains = new TrustedDomains();
        this.mxValidator = new MXValidator();

        // NOVO: Validadores críticos adicionais
        this.rfcValidator = new RFCValidator({ debug: this.options.debug });
        this.catchAllDetector = new CatchAllDetector({
            timeout: this.options.catchAllTimeout,
            debug: this.options.debug
        });
        this.roleBasedDetector = new RoleBasedDetector({ debug: this.options.debug });
        this.spamtrapDetector = new SpamtrapDetector({ debug: this.options.debug });
        this.bounceTracker = new BounceTracker({ debug: this.options.debug });

        // EcommerceScoring com todas as dependências
        this.ecommerceScoring = new EcommerceScoring({
            trustedDomains: this.trustedDomains,
            blockedDomains: this.blockedDomains,
            debug: this.options.debug
        });

        // ================================================
        // CACHE E ESTATÍSTICAS EXPANDIDAS
        // ================================================
        this.cache = new Map();
        this.cacheStats = {
            hits: 0,
            misses: 0,
            expired: 0
        };

        // Estatísticas expandidas
        this.stats = {
            totalValidated: 0,
            validEmails: 0,
            invalidEmails: 0,
            correctedEmails: 0,
            blockedEmails: 0,
            disposableEmails: 0,
            smtpVerified: 0,
            smtpFailed: 0,

            // NOVO: Estatísticas adicionais
            rfcInvalid: 0,
            catchAllDetected: 0,
            roleBasedDetected: 0,
            spamtrapsDetected: 0,
            bouncesDetected: 0,

            errors: 0,
            avgProcessingTime: 0,
            processingTimes: []
        };

        // Limpar cache periodicamente
        if (this.options.enableCache) {
            this.cacheCleanInterval = setInterval(() => this.cleanCache(), this.options.cacheExpiry);
        }

        this.log('✅ UltimateValidator v4.0 inicializado com todas funcionalidades');
    }

    // ================================================
    // MÉTODO PRINCIPAL - VALIDAR EMAIL COMPLETO
    // ================================================
    async validateEmail(email, options = {}) {
        const startTime = Date.now();
        this.stats.totalValidated++;

        try {
            // Validação básica de entrada
            if (!email || typeof email !== 'string') {
                return this.createErrorResult(email, 'Email inválido ou vazio');
            }

            const emailLower = email.toLowerCase().trim();

            // Verificar cache se habilitado
            if (this.options.enableCache) {
                const cached = this.getCached(emailLower);
                if (cached) {
                    this.cacheStats.hits++;
                    this.log(`📦 Cache hit para: ${emailLower}`);
                    return cached;
                }
                this.cacheStats.misses++;
            }

            // ================================================
            // ESTRUTURA DO RESULTADO EXPANDIDA
            // ================================================
            const result = {
                email: email,
                normalizedEmail: emailLower,
                correctedEmail: null,
                wasCorrected: false,
                correctionDetails: null,
                valid: false,
                score: 0,
                timestamp: new Date().toISOString(),
                processingTime: 0,

                // Checks expandidos
                checks: {
                    format: null,
                    rfc: null,           // NOVO
                    blocked: null,
                    disposable: null,
                    tld: null,
                    dns: null,
                    pattern: null,
                    smtp: null,
                    trusted: null,
                    catchAll: null,      // NOVO
                    roleBased: null,     // NOVO
                    spamtrap: null,      // NOVO
                    bounce: null         // NOVO
                },

                scoring: null,
                recommendations: [],
                warnings: [],            // NOVO
                metadata: {},
                insights: {}             // NOVO
            };

            // ================================================
            // PASSO 1: VALIDAÇÃO RFC (NOVO)
            // ================================================
            if (this.options.enableRFCValidation) {
                const rfcCheck = this.rfcValidator.validateSyntax(emailLower);
                result.checks.rfc = rfcCheck;

                if (!rfcCheck.valid) {
                    this.stats.rfcInvalid++;
                    result.valid = false;
                    result.score = 0;
                    result.recommendations.push('Email não é RFC 5321/5322 compliant');
                    rfcCheck.errors.forEach(error => {
                        result.warnings.push(`RFC: ${error}`);
                    });

                    // Tentar sugerir correção
                    const suggestions = this.rfcValidator.suggestCorrection(emailLower);
                    if (suggestions.length > 0) {
                        result.insights.rfcSuggestions = suggestions;
                        result.recommendations.push(`Sugestão: ${suggestions[0].suggested}`);
                    }

                    this.log(`❌ RFC inválido: ${emailLower}`);
                    return this.finalizeResult(result, startTime);
                }
            }

            // ================================================
            // PASSO 2: CORREÇÃO DE DOMÍNIO
            // ================================================
            let correctionResult = null;
            let emailToValidate = emailLower;
            let wasCorrected = false;

            if (this.options.enableCorrection) {
                correctionResult = this.domainCorrector.correctEmail(emailLower);

                if (correctionResult.wasCorrected) {
                    emailToValidate = correctionResult.corrected;
                    wasCorrected = true;
                    result.correctedEmail = emailToValidate;
                    result.wasCorrected = true;
                    result.correctionDetails = correctionResult.correction;
                    this.stats.correctedEmails++;
                    this.log(`✏️ Email corrigido: ${emailLower} → ${emailToValidate}`);
                }
            }

            // ================================================
            // PASSO 3: VALIDAÇÃO DE FORMATO BÁSICO
            // ================================================
            const formatCheck = this.validateFormat(emailToValidate);
            result.checks.format = formatCheck;

            if (!formatCheck.valid) {
                result.valid = false;
                result.score = 0;
                result.recommendations.push('Email em formato inválido');
                return this.finalizeResult(result, startTime);
            }

            const [localPart, domain] = emailToValidate.split('@');
            result.metadata.localPart = localPart;
            result.metadata.domain = domain;

            // ================================================
            // PASSO 4: DETECTAR ROLE-BASED (NOVO)
            // ================================================
            if (this.options.enableRoleBasedDetection) {
                const roleBasedCheck = this.roleBasedDetector.detectRoleBased(emailToValidate);
                result.checks.roleBased = roleBasedCheck;

                if (roleBasedCheck.isRoleBased) {
                    this.stats.roleBasedDetected++;
                    result.warnings.push(`Email funcional/departamental: ${roleBasedCheck.category}`);
                    result.insights.emailType = 'role-based';
                    result.insights.roleCategory = roleBasedCheck.category;

                    // Ajustar score baseado no risco
                    if (roleBasedCheck.risk === 'critical') {
                        result.score = Math.max(0, result.score - 30);
                        result.recommendations.push('NÃO ENVIAR - Email não monitorado');
                    } else if (roleBasedCheck.risk === 'high') {
                        result.score = Math.max(0, result.score - 20);
                        result.recommendations.push('EVITAR - Email de departamento');
                    } else if (roleBasedCheck.risk === 'medium') {
                        result.score = Math.max(0, result.score - 10);
                        result.warnings.push('Usar com cautela - email genérico');
                    }

                    this.log(`👤 Role-based detectado: ${emailToValidate} - ${roleBasedCheck.category}`);
                } else {
                    result.insights.emailType = 'personal';
                }
            }

            // ================================================
            // PASSO 5: VERIFICAR DOMÍNIO BLOQUEADO
            // ================================================
            const blockCheck = this.blockedDomains.isBlocked(emailToValidate);
            result.checks.blocked = blockCheck;

            if (blockCheck.blocked) {
                this.stats.blockedEmails++;
                result.valid = false;
                result.score = 0;
                result.recommendations.push(`Email bloqueado: ${blockCheck.reason}`);
                this.log(`🚫 Email bloqueado: ${emailToValidate} - ${blockCheck.reason}`);
                return this.finalizeResult(result, startTime);
            }

            // ================================================
            // PASSO 6: DETECTAR SPAMTRAP (NOVO)
            // ================================================
            if (this.options.enableSpamtrapDetection) {
                const spamtrapCheck = await this.spamtrapDetector.detectSpamtrap(
                    emailToValidate,
                    options.additionalData || {}
                );
                result.checks.spamtrap = spamtrapCheck;

                if (spamtrapCheck.isSpamtrap) {
                    this.stats.spamtrapsDetected++;
                    result.valid = false;
                    result.score = 0;
                    result.recommendations.push('REMOVER IMEDIATAMENTE - Spamtrap detectado');
                    result.warnings.push('Email é uma armadilha para spammers');
                    this.log(`🪤 Spamtrap detectado: ${emailToValidate}`);
                    return this.finalizeResult(result, startTime);
                } else if (spamtrapCheck.isLikelySpamtrap) {
                    result.warnings.push(`Possível spamtrap - Confiança: ${(spamtrapCheck.confidence * 100).toFixed(0)}%`);
                    result.score = Math.max(0, result.score - (spamtrapCheck.confidence * 50));
                }
            }

            // ================================================
            // PASSO 7: VERIFICAR EMAIL DESCARTÁVEL
            // ================================================
            const disposableCheck = this.disposableChecker.checkEmail(emailToValidate);
            result.checks.disposable = disposableCheck;

            if (disposableCheck.isDisposable) {
                this.stats.disposableEmails++;
                result.valid = false;
                result.score = disposableCheck.score || 0;
                result.recommendations.push('Email temporário/descartável detectado');
                this.log(`🗑️ Email descartável: ${emailToValidate}`);
            }

            // ================================================
            // PASSO 8: VALIDAR TLD
            // ================================================
            const tldCheck = this.tldValidator.validateTLD(domain);
            result.checks.tld = tldCheck;

            if (!tldCheck.valid || tldCheck.isBlocked) {
                result.valid = false;
                result.score = Math.min(result.score, 20);
                result.recommendations.push('TLD inválido ou bloqueado');
                this.log(`❌ TLD inválido: ${domain}`);
            }

            // ================================================
            // PASSO 9: VERIFICAR DNS/MX
            // ================================================
            const dnsCheck = await this.checkDNS(domain);
            result.checks.dns = dnsCheck;

            if (dnsCheck.mxValidation) {
                result.metadata.mxAnalysis = {
                    provider: dnsCheck.mxValidation.emailProvider,
                    quality: dnsCheck.mxValidation.analysis?.quality,
                    reliabilityScore: dnsCheck.mxValidation.reliabilityScore,
                    issues: dnsCheck.mxValidation.analysis?.issues || []
                };

                // Ajustar score baseado na qualidade MX
                if (dnsCheck.mxValidation.analysis?.quality === 'excellent') {
                    result.score = Math.min(100, result.score + 10);
                } else if (dnsCheck.mxValidation.analysis?.quality === 'poor') {
                    result.score = Math.max(0, result.score - 15);
                } else if (dnsCheck.mxValidation.analysis?.quality === 'invalid') {
                    result.score = Math.max(0, result.score - 25);
                }
            }

            if (!dnsCheck.valid) {
                result.valid = false;
                result.score = Math.min(result.score, 30);
                result.recommendations.push('Domínio não possui registros MX válidos');

                if (dnsCheck.mxValidation?.analysis?.recommendations) {
                    result.recommendations.push(...dnsCheck.mxValidation.analysis.recommendations);
                }

                this.log(`📭 Configuração MX inválida: ${domain}`);
            }

            // ================================================
            // PASSO 10: DETECTAR CATCH-ALL (NOVO)
            // ================================================
            if (this.options.enableCatchAllDetection && dnsCheck.valid) {
                const catchAllCheck = await this.catchAllDetector.detectCatchAll(domain);
                result.checks.catchAll = catchAllCheck;

                if (catchAllCheck.isCatchAll) {
                    this.stats.catchAllDetected++;
                    result.warnings.push('Domínio aceita todos os emails (catch-all)');
                    result.insights.catchAll = true;
                    result.metadata.catchAllConfidence = catchAllCheck.confidence;

                    // Catch-all reduz confiabilidade mas não invalida
                    result.score = Math.max(0, result.score - 20);
                    result.recommendations.push('Verificação SMTP real recomendada - domínio catch-all');

                    this.log(`📬 Catch-all detectado: ${domain}`);
                } else if (catchAllCheck.isRejectAll) {
                    result.valid = false;
                    result.score = 0;
                    result.recommendations.push('Domínio rejeita todos os emails');
                    this.log(`🚫 Reject-all detectado: ${domain}`);
                }
            }

            // ================================================
            // PASSO 11: DETECTAR PADRÕES SUSPEITOS
            // ================================================
            const patternCheck = this.patternDetector.analyzeEmail(emailToValidate);
            result.checks.pattern = patternCheck;

            if (patternCheck.suspicious) {
                result.metadata.suspicionLevel = patternCheck.suspicionLevel;
                result.metadata.suspiciousPatterns = patternCheck.patterns;

                if (patternCheck.suspicionLevel >= 7) {
                    result.valid = false;
                    result.score = Math.min(result.score, 20);
                    result.recommendations.push('Padrões altamente suspeitos detectados');
                } else if (patternCheck.suspicionLevel >= 5) {
                    result.warnings.push('Padrões suspeitos detectados');
                    result.score = Math.max(0, result.score - 15);
                }
            }

            // ================================================
            // PASSO 12: VERIFICAÇÃO SMTP
            // ================================================
            if (this.options.enableSMTP && dnsCheck.valid && !result.checks.catchAll?.isCatchAll) {
                try {
                    const smtpCheck = await this.smtpValidator.validateEmail(emailToValidate);
                    result.checks.smtp = smtpCheck;

                    if (smtpCheck.exists) {
                        this.stats.smtpVerified++;
                        result.metadata.mailboxVerified = true;
                        result.score = Math.min(100, result.score + 15);
                    } else {
                        this.stats.smtpFailed++;

                        // Analisar resposta SMTP para bounce
                        if (smtpCheck.response && this.options.enableBounceTracking) {
                            const bounceAnalysis = this.bounceTracker.analyzeBounceResponse(
                                smtpCheck.response,
                                emailToValidate
                            );

                            if (bounceAnalysis.isBounce) {
                                result.checks.bounce = bounceAnalysis;
                                this.stats.bouncesDetected++;

                                if (bounceAnalysis.isPermanent) {
                                    result.valid = false;
                                    result.score = 0;
                                    result.recommendations.push('Hard bounce - email permanentemente inválido');
                                } else {
                                    result.warnings.push('Soft bounce - problema temporário');
                                    result.score = Math.max(0, result.score - 20);
                                }
                            }
                        }

                        if (!result.checks.bounce?.isBounce) {
                            result.valid = false;
                            result.score = Math.min(result.score, 40);
                            result.recommendations.push('Caixa postal não encontrada no servidor');
                        }

                        this.log(`📪 Mailbox não existe: ${emailToValidate}`);
                    }
                } catch (smtpError) {
                    this.log(`⚠️ Erro SMTP para ${emailToValidate}: ${smtpError.message}`);
                    result.checks.smtp = {
                        checked: false,
                        error: smtpError.message,
                        exists: null
                    };
                }
            } else {
                result.checks.smtp = {
                    checked: false,
                    reason: this.options.enableSMTP ?
                        (result.checks.catchAll?.isCatchAll ? 'Catch-all domain' : 'No MX records') :
                        'SMTP disabled'
                };
            }

            // ================================================
            // PASSO 13: VERIFICAR HISTÓRICO DE BOUNCE (NOVO)
            // ================================================
            if (this.options.enableBounceTracking) {
                const bounceHistory = await this.bounceTracker.checkBounceHistory(emailToValidate);

                if (!result.checks.bounce) {
                    result.checks.bounce = bounceHistory;
                }

                if (bounceHistory.hasBounced) {
                    if (bounceHistory.risk === 'critical') {
                        result.valid = false;
                        result.score = 0;
                        result.recommendations.push('Email com histórico de hard bounce');
                    } else if (bounceHistory.risk === 'high') {
                        result.warnings.push('Múltiplos soft bounces no histórico');
                        result.score = Math.max(0, result.score - 25);
                    }
                }
            }

            // ================================================
            // PASSO 14: VERIFICAR DOMÍNIO CONFIÁVEL
            // ================================================
            const isTrusted = this.trustedDomains.isTrusted(domain);
            const trustCategory = this.trustedDomains.getCategory(domain);
            const trustScore = this.trustedDomains.getTrustScore(domain);

            result.checks.trusted = {
                isTrusted: isTrusted,
                category: trustCategory,
                trustScore: trustScore
            };

            result.metadata.trustedDomain = isTrusted;
            result.metadata.domainCategory = trustCategory;

            // ================================================
            // PASSO 15: CALCULAR SCORE FINAL (E-commerce Scoring)
            // ================================================
            const scoringInput = {
                email: emailToValidate,
                wasCorrected: wasCorrected,
                correctionDetails: correctionResult,
                tld: tldCheck,
                disposable: disposableCheck,
                smtp: result.checks.smtp,
                patterns: patternCheck,
                dns: dnsCheck,
                trusted: result.checks.trusted,
                blocked: blockCheck,

                // NOVO: Adicionar checks adicionais
                rfc: result.checks.rfc,
                catchAll: result.checks.catchAll,
                roleBased: result.checks.roleBased,
                spamtrap: result.checks.spamtrap,
                bounce: result.checks.bounce
            };

            const scoringResult = this.ecommerceScoring.calculateScore(scoringInput);
            result.scoring = scoringResult;
            result.score = scoringResult.finalScore;
            result.valid = scoringResult.valid;

            // ================================================
            // PASSO 16: CONSOLIDAR INSIGHTS
            // ================================================
            result.insights = {
                ...result.insights,
                emailQuality: this.getEmailQuality(result.score),
                riskLevel: scoringResult.riskLevel || 'UNKNOWN',
                buyerType: scoringResult.buyerType || 'UNKNOWN',
                fraudProbability: scoringResult.fraudProbability || 0,
                popularity: scoringResult.popularity,
                domainType: scoringResult.domainType,

                // Análise consolidada
                hasIssues: result.score < 60 || result.warnings.length > 0,
                requiresReview: result.score >= 45 && result.score < 70,
                isRecommended: result.score >= 70 && !result.checks.spamtrap?.isSpamtrap,

                // Flags importantes
                isCatchAll: result.checks.catchAll?.isCatchAll || false,
                isRoleBased: result.checks.roleBased?.isRoleBased || false,
                isDisposable: result.checks.disposable?.isDisposable || false,
                hasBounceHistory: result.checks.bounce?.hasBounced || false
            };

            // ================================================
            // PASSO 17: GERAR RECOMENDAÇÕES FINAIS
            // ================================================

            // Adicionar recomendações do scoring
            if (scoringResult.recommendations) {
                result.recommendations.push(...scoringResult.recommendations.map(r =>
                    typeof r === 'string' ? r : r.message
                ));
            }

            // Recomendação sobre correção
            if (wasCorrected) {
                result.recommendations.unshift(
                    `Email corrigido automaticamente de "${email}" para "${emailToValidate}"`
                );
            }

            // Recomendação final baseada no score e insights
            if (result.score >= 80 && !result.insights.hasIssues) {
                result.recommendations.push('✅ Email altamente confiável e seguro para uso');
                result.valid = true;
            } else if (result.score >= 70) {
                result.recommendations.push('✓ Email válido com boa confiabilidade');
                result.valid = true;
            } else if (result.score >= 60) {
                result.recommendations.push('✓ Email válido com confiança moderada');
                result.valid = true;
            } else if (result.score >= this.options.scoreThreshold) {
                result.recommendations.push('⚠️ Email duvidoso - verificação adicional recomendada');
                result.valid = true; // Válido mas com ressalvas
            } else {
                result.recommendations.push('❌ Email inválido ou de alto risco');
                result.valid = false;
            }

            // ================================================
            // PASSO 18: ADICIONAR METADADOS FINAIS
            // ================================================
            result.metadata.finalDecision = result.valid ? 'APPROVED' : 'REJECTED';
            result.metadata.confidenceLevel = this.getConfidenceLevel(result.score);
            result.metadata.riskLevel = scoringResult.riskLevel || 'UNKNOWN';
            result.metadata.buyerType = scoringResult.buyerType || 'UNKNOWN';
            result.metadata.completenessScore = this.calculateCompletenessScore(result.checks);

            // Atualizar estatísticas
            if (result.valid) {
                this.stats.validEmails++;
            } else {
                this.stats.invalidEmails++;
            }

            // Finalizar e cachear resultado
            return this.finalizeResult(result, startTime);

        } catch (error) {
            this.stats.errors++;
            this.log(`❌ Erro ao validar ${email}: ${error.message}`);
            return this.createErrorResult(email, error.message);
        }
    }

    // ================================================
    // MÉTODOS AUXILIARES EXPANDIDOS
    // ================================================

    /**
     * Valida formato básico do email
     */
    validateFormat(email) {
        const result = {
            valid: false,
            details: {}
        };

        // Regex RFC 5322 simplificado
        const emailRegex = /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;

        if (!emailRegex.test(email)) {
            result.details.reason = 'Formato inválido';
            return result;
        }

        const parts = email.split('@');
        if (parts.length !== 2) {
            result.details.reason = 'Deve conter exatamente um @';
            return result;
        }

        const [localPart, domain] = parts;

        // Validar local part
        if (localPart.length === 0 || localPart.length > 64) {
            result.details.reason = 'Local part deve ter entre 1 e 64 caracteres';
            return result;
        }

        // Validar domain
        if (domain.length === 0 || domain.length > 253) {
            result.details.reason = 'Domínio deve ter entre 1 e 253 caracteres';
            return result;
        }

        // Verificar caracteres consecutivos inválidos
        if (/\.{2,}/.test(email)) {
            result.details.reason = 'Pontos consecutivos não são permitidos';
            return result;
        }

        result.valid = true;
        result.details = {
            localPart: localPart,
            domain: domain,
            localPartLength: localPart.length,
            domainLength: domain.length
        };

        return result;
    }

    /**
     * Verifica DNS e MX records
     */
    async checkDNS(domain) {
        const result = {
            valid: false,
            hasMX: false,
            hasA: false,
            mxRecords: [],
            details: {},
            mxValidation: null
        };

        try {
            // Usar o MXValidator avançado
            const mxResult = await this.mxValidator.validateMX(domain);

            result.valid = mxResult.valid;
            result.hasMX = mxResult.hasMX;
            result.hasA = mxResult.hasA;
            result.mxRecords = mxResult.mxRecords;
            result.mxValidation = mxResult;

            // Adicionar detalhes importantes
            result.details = {
                preferredExchange: mxResult.preferredExchange,
                emailProvider: mxResult.emailProvider,
                reliabilityScore: mxResult.reliabilityScore,
                analysis: mxResult.analysis,
                mxServersReachable: mxResult.mxServersReachable
            };

        } catch (error) {
            result.details.error = error.message;
        }

        return result;
    }

    /**
     * Calcula score de completude das verificações
     */
    calculateCompletenessScore(checks) {
        const totalChecks = Object.keys(checks).length;
        const completedChecks = Object.values(checks).filter(check => check !== null).length;
        return Math.round((completedChecks / totalChecks) * 100);
    }

    /**
     * Determina qualidade do email baseado no score
     */
    getEmailQuality(score) {
        if (score >= 90) return 'EXCELLENT';
        if (score >= 80) return 'VERY_GOOD';
        if (score >= 70) return 'GOOD';
        if (score >= 60) return 'FAIR';
        if (score >= 50) return 'POOR';
        if (score >= 40) return 'VERY_POOR';
        return 'INVALID';
    }

    /**
     * Determina nível de confiança baseado no score
     */
    getConfidenceLevel(score) {
        if (score >= 90) return 'VERY_HIGH';
        if (score >= 75) return 'HIGH';
        if (score >= 60) return 'MODERATE';
        if (score >= 45) return 'LOW';
        return 'VERY_LOW';
    }

    /**
     * Valida múltiplos emails em lote com paralelização
     */
    async validateBatch(emails, options = {}) {
        const batchSize = options.batchSize || this.options.batchSize;
        const results = [];
        const startTime = Date.now();

        this.log(`🔄 Iniciando validação em lote de ${emails.length} emails`);

        if (this.options.parallelValidation) {
            // Validação paralela
            for (let i = 0; i < emails.length; i += batchSize) {
                const batch = emails.slice(i, i + batchSize);
                const batchPromises = batch.map(email => this.validateEmail(email, options));
                const batchResults = await Promise.allSettled(batchPromises);

                batchResults.forEach((result, index) => {
                    if (result.status === 'fulfilled') {
                        results.push(result.value);
                    } else {
                        results.push(this.createErrorResult(batch[index], result.reason));
                    }
                });

                this.log(`✅ Processados ${Math.min(i + batchSize, emails.length)}/${emails.length}`);

                // Callback de progresso
                if (options.onProgress) {
                    options.onProgress({
                        processed: results.length,
                        total: emails.length,
                        percentage: ((results.length / emails.length) * 100).toFixed(2)
                    });
                }
            }
        } else {
            // Validação sequencial
            for (let i = 0; i < emails.length; i++) {
                try {
                    const result = await this.validateEmail(emails[i], options);
                    results.push(result);
                } catch (error) {
                    results.push(this.createErrorResult(emails[i], error.message));
                }

                if ((i + 1) % 10 === 0 || i === emails.length - 1) {
                    this.log(`✅ Processados ${i + 1}/${emails.length}`);

                    if (options.onProgress) {
                        options.onProgress({
                            processed: i + 1,
                            total: emails.length,
                            percentage: (((i + 1) / emails.length) * 100).toFixed(2)
                        });
                    }
                }
            }
        }

        const processingTime = Date.now() - startTime;

        // Gerar resumo do lote
        const summary = {
            total: emails.length,
            valid: results.filter(r => r.valid).length,
            invalid: results.filter(r => !r.valid).length,
            corrected: results.filter(r => r.wasCorrected).length,
            warnings: results.filter(r => r.warnings && r.warnings.length > 0).length,
            processingTime: processingTime,
            avgProcessingTime: Math.round(processingTime / emails.length)
        };

        this.log(`✅ Validação em lote concluída: ${summary.valid}/${summary.total} válidos em ${processingTime}ms`);

        return {
            results: results,
            summary: summary
        };
    }

    // ================================================
    // GERENCIAMENTO DE CACHE
    // ================================================

    getCached(email) {
        if (!this.cache.has(email)) return null;

        const cached = this.cache.get(email);
        const now = Date.now();

        if (now - cached.cachedAt > this.options.cacheExpiry) {
            this.cache.delete(email);
            this.cacheStats.expired++;
            return null;
        }

        return { ...cached.result, fromCache: true };
    }

    setCached(email, result) {
        if (this.cache.size >= this.options.maxCacheSize) {
            // Remover entrada mais antiga
            const firstKey = this.cache.keys().next().value;
            this.cache.delete(firstKey);
        }

        this.cache.set(email, {
            result: result,
            cachedAt: Date.now()
        });
    }

    cleanCache() {
        const now = Date.now();
        let cleaned = 0;

        for (const [email, data] of this.cache.entries()) {
            if (now - data.cachedAt > this.options.cacheExpiry) {
                this.cache.delete(email);
                cleaned++;
            }
        }

        if (cleaned > 0) {
            this.log(`🧹 Cache limpo: ${cleaned} entradas removidas`);
        }
    }

    clearCache() {
        this.cache.clear();
        this.patternDetector.clearCache();
        this.catchAllDetector.clearCache();
        this.mxValidator.clearCache();
        this.log('🧹 Cache completamente limpo');
    }

    // ================================================
    // FINALIZAÇÃO E ESTATÍSTICAS
    // ================================================

    finalizeResult(result, startTime) {
        const processingTime = Date.now() - startTime;
        result.processingTime = processingTime;

        // Atualizar estatísticas de tempo
        this.stats.processingTimes.push(processingTime);
        if (this.stats.processingTimes.length > 100) {
            this.stats.processingTimes.shift();
        }
        this.stats.avgProcessingTime = Math.round(
            this.stats.processingTimes.reduce((a, b) => a + b, 0) / this.stats.processingTimes.length
        );

        // Cachear se habilitado
        if (this.options.enableCache) {
            this.setCached(result.normalizedEmail, result);
        }

        return result;
    }

    createErrorResult(email, errorMessage) {
        return {
            email: email,
            valid: false,
            score: 0,
            error: errorMessage,
            timestamp: new Date().toISOString(),
            recommendations: ['Email inválido ou erro no processamento'],
            warnings: [],
            insights: { error: true }
        };
    }

    // ================================================
    // ESTATÍSTICAS E MONITORAMENTO
    // ================================================

    getStatistics() {
        return {
            ...this.stats,
            cache: {
                ...this.cacheStats,
                size: this.cache.size,
                hitRate: this.cacheStats.hits > 0
                    ? ((this.cacheStats.hits / (this.cacheStats.hits + this.cacheStats.misses)) * 100).toFixed(2) + '%'
                    : '0%'
            },
            rates: {
                validationRate: this.stats.totalValidated > 0
                    ? ((this.stats.validEmails / this.stats.totalValidated) * 100).toFixed(2) + '%'
                    : '0%',
                correctionRate: this.stats.totalValidated > 0
                    ? ((this.stats.correctedEmails / this.stats.totalValidated) * 100).toFixed(2) + '%'
                    : '0%',
                catchAllRate: this.stats.totalValidated > 0
                    ? ((this.stats.catchAllDetected / this.stats.totalValidated) * 100).toFixed(2) + '%'
                    : '0%',
                roleBasedRate: this.stats.totalValidated > 0
                    ? ((this.stats.roleBasedDetected / this.stats.totalValidated) * 100).toFixed(2) + '%'
                    : '0%',
                spamtrapRate: this.stats.totalValidated > 0
                    ? ((this.stats.spamtrapsDetected / this.stats.totalValidated) * 100).toFixed(2) + '%'
                    : '0%'
            },
            subValidators: {
                domainCorrector: this.domainCorrector.getStatistics(),
                disposableChecker: this.disposableChecker.getStatistics(),
                patternDetector: this.patternDetector.getStatistics(),
                smtpValidator: this.smtpValidator.getStatistics(),
                tldValidator: this.tldValidator.getStatistics(),
                rfcValidator: this.rfcValidator.getStatistics(),
                catchAllDetector: this.catchAllDetector.getStatistics(),
                roleBasedDetector: this.roleBasedDetector.getStatistics(),
                spamtrapDetector: this.spamtrapDetector.getStatistics(),
                bounceTracker: this.bounceTracker.getStatistics(),
                mxValidator: this.mxValidator.getStatistics()
            }
        };
    }

    resetStatistics() {
        this.stats = {
            totalValidated: 0,
            validEmails: 0,
            invalidEmails: 0,
            correctedEmails: 0,
            blockedEmails: 0,
            disposableEmails: 0,
            smtpVerified: 0,
            smtpFailed: 0,
            rfcInvalid: 0,
            catchAllDetected: 0,
            roleBasedDetected: 0,
            spamtrapsDetected: 0,
            bouncesDetected: 0,
            errors: 0,
            avgProcessingTime: 0,
            processingTimes: []
        };

        this.cacheStats = {
            hits: 0,
            misses: 0,
            expired: 0
        };

        // Resetar estatísticas dos sub-validadores
        this.domainCorrector.reset();
        this.patternDetector.resetStats();
        this.rfcValidator.resetStatistics();
        this.catchAllDetector.resetStatistics();
        this.roleBasedDetector.resetStatistics();
        this.spamtrapDetector.resetStatistics();
        this.bounceTracker.resetStatistics();
        this.mxValidator.resetStatistics();

        this.log('📊 Estatísticas resetadas');
    }

    // ================================================
    // LIMPEZA E DESTRUIÇÃO
    // ================================================

    destroy() {
        // Limpar intervalos
        if (this.cacheCleanInterval) {
            clearInterval(this.cacheCleanInterval);
        }

        // Limpar recursos dos validadores
        if (this.ecommerceScoring.destroy) {
            this.ecommerceScoring.destroy();
        }

        // Limpar cache
        this.clearCache();

        this.log('🔚 UltimateValidator destruído');
    }

    log(message) {
        if (this.options.debug) {
            console.log(`[UltimateValidator v4.0] ${message}`);
        }
    }
}

module.exports = UltimateValidator;
