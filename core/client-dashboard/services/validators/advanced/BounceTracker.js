// ================================================
// Email Bounce Tracker and Analyzer
// Sistema de rastreamento e análise de bounces
// ================================================

class BounceTracker {
    constructor(options = {}) {
        this.debug = options.debug || false;

        // ================================================
        // TIPOS DE BOUNCE E CÓDIGOS SMTP
        // ================================================
        this.bounceTypes = {
            hardBounce: {
                codes: ['550', '551', '552', '553', '554', '511'],
                permanent: true,
                action: 'REMOVE_IMMEDIATELY',
                description: 'Email permanentemente inválido',
                patterns: [
                    /user unknown/i,
                    /user not found/i,
                    /mailbox not found/i,
                    /address rejected/i,
                    /does not exist/i,
                    /invalid recipient/i,
                    /no such user/i,
                    /recipient rejected/i,
                    /address not found/i
                ]
            },

            softBounce: {
                codes: ['421', '450', '451', '452', '454'],
                permanent: false,
                action: 'RETRY_LATER',
                description: 'Problema temporário',
                patterns: [
                    /mailbox full/i,
                    /quota exceeded/i,
                    /temporarily unavailable/i,
                    /try again later/i,
                    /mailbox busy/i,
                    /too many connections/i,
                    /temporary failure/i,
                    /greylist/i,
                    /defer/i
                ]
            },

            blocked: {
                codes: ['571', '572', '573', '521', '541'],
                permanent: true,
                action: 'BLOCKED_BY_SERVER',
                description: 'Bloqueado pelo servidor',
                patterns: [
                    /blocked/i,
                    /blacklist/i,
                    /spam/i,
                    /rejected for policy/i,
                    /access denied/i,
                    /relay denied/i,
                    /not authorized/i,
                    /refused/i,
                    /banned/i
                ]
            },

            dnsFail: {
                codes: ['512', '513', '523'],
                permanent: false,
                action: 'CHECK_DOMAIN',
                description: 'Problema de DNS',
                patterns: [
                    /domain not found/i,
                    /dns failure/i,
                    /no mx record/i,
                    /host not found/i,
                    /unrouteable address/i
                ]
            },

            syntaxError: {
                codes: ['501', '502', '503', '504', '555'],
                permanent: true,
                action: 'FIX_SYNTAX',
                description: 'Erro de sintaxe',
                patterns: [
                    /syntax error/i,
                    /invalid address/i,
                    /malformed address/i,
                    /bad address syntax/i
                ]
            },

            autoReply: {
                codes: [],
                permanent: false,
                action: 'IGNORE',
                description: 'Resposta automática',
                patterns: [
                    /out of office/i,
                    /vacation/i,
                    /auto.?reply/i,
                    /automatic reply/i,
                    /away from/i
                ]
            }
        };

        // Histórico de bounces (em produção seria um banco de dados)
        this.bounceHistory = new Map();

        // Estatísticas
        this.stats = {
            totalChecked: 0,
            hardBounces: 0,
            softBounces: 0,
            blocked: 0,
            dnsFails: 0,
            syntaxErrors: 0,
            autoReplies: 0,
            clean: 0
        };
    }

    // ================================================
    // ANALISAR RESPOSTA SMTP
    // ================================================
    analyzeBounceResponse(smtpResponse, email = null) {
        const analysis = {
            isBounce: false,
            bounceType: null,
            bounceCategory: null,
            isPermanent: false,
            action: 'NONE',
            smtpCode: null,
            message: smtpResponse,
            details: [],
            confidence: 0,
            timestamp: new Date().toISOString()
        };

        if (!smtpResponse) {
            return analysis;
        }

        const responseStr = smtpResponse.toString().toLowerCase();

        // ================================================
        // 1. EXTRAIR CÓDIGO SMTP
        // ================================================
        const codeMatch = smtpResponse.match(/^(\d{3})/);
        if (codeMatch) {
            analysis.smtpCode = codeMatch[1];
        }

        // ================================================
        // 2. IDENTIFICAR TIPO DE BOUNCE
        // ================================================
        let bestMatch = null;
        let bestConfidence = 0;

        for (const [type, config] of Object.entries(this.bounceTypes)) {
            let confidence = 0;

            // Verificar código SMTP
            if (analysis.smtpCode && config.codes.includes(analysis.smtpCode)) {
                confidence += 0.5;
            }

            // Verificar padrões de texto
            for (const pattern of config.patterns) {
                if (pattern.test(responseStr)) {
                    confidence += 0.5;
                    analysis.details.push(`Padrão detectado: ${pattern.source}`);
                    break;
                }
            }

            if (confidence > bestConfidence) {
                bestConfidence = confidence;
                bestMatch = type;
            }
        }

        if (bestMatch && bestConfidence >= 0.5) {
            const bounceConfig = this.bounceTypes[bestMatch];

            analysis.isBounce = true;
            analysis.bounceType = bestMatch;
            analysis.bounceCategory = this.categorizeBounce(bestMatch);
            analysis.isPermanent = bounceConfig.permanent;
            analysis.action = bounceConfig.action;
            analysis.confidence = bestConfidence;

            // Atualizar estatísticas
            this.updateStats(bestMatch);

            // Registrar no histórico
            if (email) {
                this.recordBounce(email, analysis);
            }
        }

        // ================================================
        // 3. ANÁLISE ADICIONAL
        // ================================================

        // Verificar se é delayed (não é bounce mas é importante)
        if (/delay|defer|queued|will retry/i.test(responseStr)) {
            analysis.isDelayed = true;
            analysis.details.push('Email atrasado mas será tentado novamente');
        }

        // Verificar menções a spam
        if (/spam|spf|dkim|dmarc/i.test(responseStr)) {
            analysis.spamRelated = true;
            analysis.details.push('Problema relacionado a spam/autenticação');
        }

        // Verificar challenge-response
        if (/challenge|verify|confirm/i.test(responseStr)) {
            analysis.challengeResponse = true;
            analysis.details.push('Sistema challenge-response detectado');
        }

        this.logDebug(`Bounce analysis: type=${analysis.bounceType}, permanent=${analysis.isPermanent}`);

        return analysis;
    }

    // ================================================
    // VERIFICAR HISTÓRICO DE BOUNCES
    // ================================================
    async checkBounceHistory(email) {
        this.stats.totalChecked++;

        const history = this.bounceHistory.get(email) || [];

        const result = {
            email: email,
            hasBounced: history.length > 0,
            bounceCount: history.length,
            lastBounce: history[0] || null,
            bouncePattern: this.analyzeBouncePattern(history),
            risk: 'none',
            recommendation: 'OK',
            details: {
                hardBounces: 0,
                softBounces: 0,
                lastHardBounce: null,
                lastSoftBounce: null,
                trend: 'stable'
            }
        };

        // Analisar histórico
        for (const bounce of history) {
            if (bounce.isPermanent) {
                result.details.hardBounces++;
                if (!result.details.lastHardBounce ||
                    new Date(bounce.timestamp) > new Date(result.details.lastHardBounce.timestamp)) {
                    result.details.lastHardBounce = bounce;
                }
            } else {
                result.details.softBounces++;
                if (!result.details.lastSoftBounce ||
                    new Date(bounce.timestamp) > new Date(result.details.lastSoftBounce.timestamp)) {
                    result.details.lastSoftBounce = bounce;
                }
            }
        }

        // ================================================
        // DETERMINAR RISCO E RECOMENDAÇÃO
        // ================================================

        if (result.details.hardBounces > 0) {
            result.risk = 'critical';
            result.recommendation = 'REMOVER - Hard bounce detectado';
            this.stats.hardBounces++;
        } else if (result.details.softBounces >= 5) {
            result.risk = 'high';
            result.recommendation = 'SUSPENDER - Múltiplos soft bounces';
        } else if (result.details.softBounces >= 3) {
            result.risk = 'medium';
            result.recommendation = 'MONITORAR - Soft bounces recorrentes';
        } else if (result.details.softBounces > 0) {
            result.risk = 'low';
            result.recommendation = 'TENTAR NOVAMENTE - Soft bounce temporário';
        } else {
            result.risk = 'none';
            result.recommendation = 'OK - Sem histórico de bounce';
            this.stats.clean++;
        }

        // Analisar tendência
        if (history.length >= 3) {
            const recent = history.slice(0, 3);
            const allRecent = recent.every(b =>
                (Date.now() - new Date(b.timestamp)) < 7 * 24 * 60 * 60 * 1000
            );

            if (allRecent) {
                result.details.trend = 'worsening';
                result.risk = 'high';
                result.recommendation = 'PROBLEMA RECENTE - Verificar urgentemente';
            }
        }

        return result;
    }

    // ================================================
    // REGISTRAR BOUNCE
    // ================================================
    recordBounce(email, bounceData) {
        if (!this.bounceHistory.has(email)) {
            this.bounceHistory.set(email, []);
        }

        const history = this.bounceHistory.get(email);

        // Adicionar ao início (mais recente primeiro)
        history.unshift({
            timestamp: bounceData.timestamp || new Date().toISOString(),
            type: bounceData.bounceType,
            isPermanent: bounceData.isPermanent,
            code: bounceData.smtpCode,
            message: bounceData.message?.substring(0, 200) // Limitar tamanho
        });

        // Manter apenas últimos 10 bounces
        if (history.length > 10) {
            history.pop();
        }

        this.logDebug(`Bounce registrado para ${email}: ${bounceData.bounceType}`);
    }

    // ================================================
    // ANALISAR PADRÃO DE BOUNCES
    // ================================================
    analyzeBouncePattern(history) {
        if (history.length === 0) {
            return { pattern: 'none', description: 'Sem bounces' };
        }

        if (history.length === 1) {
            return {
                pattern: 'single',
                description: history[0].isPermanent ? 'Bounce único permanente' : 'Bounce único temporário'
            };
        }

        const permanent = history.filter(b => b.isPermanent).length;
        const temporary = history.filter(b => !b.isPermanent).length;

        if (permanent > 0 && temporary === 0) {
            return { pattern: 'permanent', description: 'Apenas hard bounces' };
        }

        if (permanent === 0 && temporary > 0) {
            return { pattern: 'temporary', description: 'Apenas soft bounces' };
        }

        if (permanent > 0 && temporary > 0) {
            return { pattern: 'mixed', description: 'Mix de hard e soft bounces' };
        }

        // Verificar se são recentes
        const recentCount = history.filter(b =>
            (Date.now() - new Date(b.timestamp)) < 30 * 24 * 60 * 60 * 1000
        ).length;

        if (recentCount === history.length) {
            return { pattern: 'recent', description: 'Todos os bounces são recentes' };
        }

        return { pattern: 'historical', description: 'Bounces históricos' };
    }

    // ================================================
    // CATEGORIZAR BOUNCE
    // ================================================
    categorizeBounce(bounceType) {
        const categories = {
            hardBounce: 'invalid_recipient',
            softBounce: 'temporary_issue',
            blocked: 'policy_block',
            dnsFail: 'dns_issue',
            syntaxError: 'format_error',
            autoReply: 'auto_response'
        };

        return categories[bounceType] || 'unknown';
    }

    // ================================================
    // SIMULAR BUSCA DE HISTÓRICO (em produção seria DB)
    // ================================================
    async getBounceHistory(email) {
        // Simular delay de busca no banco
        await new Promise(resolve => setTimeout(resolve, 10));

        // Retornar histórico se existir
        return this.bounceHistory.get(email) || [];
    }

    // ================================================
    // OBTER RECOMENDAÇÃO BASEADA NO HISTÓRICO
    // ================================================
    getRecommendation(history) {
        if (history.length === 0) {
            return 'Email sem histórico de bounces - OK para envio';
        }

        const hardBounces = history.filter(h => h.isPermanent).length;
        const softBounces = history.filter(h => !h.isPermanent).length;

        if (hardBounces > 0) {
            return 'REMOVER IMEDIATAMENTE - Hard bounce detectado';
        }

        if (softBounces >= 5) {
            return 'SUSPENDER ENVIOS - Muitos soft bounces';
        }

        if (softBounces >= 3) {
            return 'MONITORAR - Soft bounces frequentes';
        }

        return 'TENTAR NOVAMENTE - Problema temporário';
    }

    // ================================================
    // LIMPAR HISTÓRICO ANTIGO
    // ================================================
    cleanOldHistory(daysToKeep = 90) {
        const cutoffDate = Date.now() - (daysToKeep * 24 * 60 * 60 * 1000);
        let cleaned = 0;

        for (const [email, history] of this.bounceHistory.entries()) {
            const filteredHistory = history.filter(bounce =>
                new Date(bounce.timestamp).getTime() > cutoffDate
            );

            if (filteredHistory.length === 0) {
                this.bounceHistory.delete(email);
                cleaned++;
            } else if (filteredHistory.length < history.length) {
                this.bounceHistory.set(email, filteredHistory);
                cleaned++;
            }
        }

        this.logDebug(`Histórico limpo: ${cleaned} registros atualizados/removidos`);
        return cleaned;
    }

    // ================================================
    // ATUALIZAR ESTATÍSTICAS
    // ================================================
    updateStats(bounceType) {
        switch(bounceType) {
            case 'hardBounce':
                this.stats.hardBounces++;
                break;
            case 'softBounce':
                this.stats.softBounces++;
                break;
            case 'blocked':
                this.stats.blocked++;
                break;
            case 'dnsFail':
                this.stats.dnsFails++;
                break;
            case 'syntaxError':
                this.stats.syntaxErrors++;
                break;
            case 'autoReply':
                this.stats.autoReplies++;
                break;
        }
    }

    // ================================================
    // ESTATÍSTICAS
    // ================================================
    getStatistics() {
        const total = this.stats.totalChecked || 1;

        return {
            ...this.stats,
            hardBounceRate: ((this.stats.hardBounces / total) * 100).toFixed(2) + '%',
            softBounceRate: ((this.stats.softBounces / total) * 100).toFixed(2) + '%',
            blockedRate: ((this.stats.blocked / total) * 100).toFixed(2) + '%',
            cleanRate: ((this.stats.clean / total) * 100).toFixed(2) + '%',
            historySize: this.bounceHistory.size
        };
    }

    // ================================================
    // RESETAR ESTATÍSTICAS
    // ================================================
    resetStatistics() {
        this.stats = {
            totalChecked: 0,
            hardBounces: 0,
            softBounces: 0,
            blocked: 0,
            dnsFails: 0,
            syntaxErrors: 0,
            autoReplies: 0,
            clean: 0
        };

        this.logDebug('Estatísticas de bounce resetadas');
    }

    // ================================================
    // LIMPAR HISTÓRICO
    // ================================================
    clearHistory() {
        this.bounceHistory.clear();
        this.logDebug('Histórico de bounces limpo');
    }

    // ================================================
    // LOG DEBUG
    // ================================================
    logDebug(message) {
        if (this.debug) {
            console.log(`[BounceTracker] ${message}`);
        }
    }
}

module.exports = BounceTracker;
