// ================================================
// Spamtrap Email Detector
// Detecta emails que são armadilhas para spammers
// ================================================

const crypto = require('crypto');

class SpamtrapDetector {
    constructor(options = {}) {
        this.debug = options.debug || false;

        // ================================================
        // CONFIGURAÇÕES DE DETECÇÃO
        // ================================================

        // Domínios conhecidos de spamtrap
        this.knownSpamtrapDomains = new Set([
            'spamtrap.com',
            'honeypot.net',
            'trapmail.com',
            'antispam.com',
            'spamcop.net',
            'abuse.net'
        ]);

        // Padrões suspeitos no local part
        this.suspiciousPatterns = [
            /^[a-f0-9]{32}@/i,          // MD5 hash
            /^[a-f0-9]{40}@/i,          // SHA1 hash
            /^[a-f0-9]{64}@/i,          // SHA256 hash
            /^test\d{10,}@/,            // test com muitos números
            /^trap/i,                   // Começa com trap
            /honeypot/i,                // Contém honeypot
            /^spam/i,                   // Começa com spam
            /^abuse/i,                  // Começa com abuse
            /^postmaster@/i,            // Postmaster (frequentemente reciclado)
            /^unused/i,                 // Emails não usados
            /^old\./i,                  // Emails antigos
            /^former\./i,               // Emails anteriores
            /^invalid/i,                // Emails inválidos
            /^fake/i,                   // Emails falsos
            /^dummy/i                   // Emails dummy
        ];

        // Indicadores de email reciclado
        this.recycledIndicators = {
            patterns: [
                /^(info|admin|sales|support)@.+\.(com|net|org)$/i,
                /^webmaster@/i,
                /^contact@/i
            ],
            // Domínios que frequentemente reciclam emails
            recyclingDomains: [
                'yahoo.com',
                'aol.com',
                'hotmail.com'
            ]
        };

        // Banco de dados simulado de spamtraps conhecidos (em produção, seria uma API ou DB)
        this.knownSpamtraps = new Set([
            crypto.createHash('md5').update('example@spamtrap.com').digest('hex'),
            crypto.createHash('md5').update('test@honeypot.net').digest('hex')
            // Adicionar mais hashes de spamtraps conhecidos
        ]);

        // Estatísticas
        this.stats = {
            totalChecked: 0,
            spamtrapsDetected: 0,
            likelySpamtraps: 0,
            recycledDetected: 0,
            cleanEmails: 0
        };
    }

    // ================================================
    // MÉTODO PRINCIPAL - DETECTAR SPAMTRAP
    // ================================================
    async detectSpamtrap(email, additionalData = {}) {
        this.stats.totalChecked++;

        const result = {
            email: email,
            isSpamtrap: false,
            isLikelySpamtrap: false,
            isRecycled: false,
            confidence: 0,
            risk: 'none',
            indicators: [],
            details: {
                domainCheck: false,
                patternCheck: false,
                hashCheck: false,
                ageCheck: false,
                activityCheck: false
            },
            recommendations: [],
            timestamp: new Date().toISOString()
        };

        if (!email || !email.includes('@')) {
            result.risk = 'invalid';
            result.recommendations.push('Email inválido');
            return result;
        }

        const [localPart, domain] = email.split('@');
        const emailHash = crypto.createHash('md5').update(email.toLowerCase()).digest('hex');

        // ================================================
        // 1. VERIFICAR HASH DE SPAMTRAPS CONHECIDOS
        // ================================================
        if (this.knownSpamtraps.has(emailHash)) {
            result.isSpamtrap = true;
            result.confidence = 1.0;
            result.risk = 'critical';
            result.indicators.push('Email em lista de spamtraps conhecidos');
            result.details.hashCheck = true;
            result.recommendations.push('REMOVER IMEDIATAMENTE - Spamtrap confirmado');
            this.stats.spamtrapsDetected++;

            this.logDebug(`Spamtrap confirmado: ${email}`);
            return result;
        }

        // ================================================
        // 2. VERIFICAR DOMÍNIO CONHECIDO
        // ================================================
        if (this.knownSpamtrapDomains.has(domain.toLowerCase())) {
            result.isSpamtrap = true;
            result.confidence = 0.95;
            result.risk = 'critical';
            result.indicators.push(`Domínio de spamtrap conhecido: ${domain}`);
            result.details.domainCheck = true;
            result.recommendations.push('REMOVER - Domínio de spamtrap');
            this.stats.spamtrapsDetected++;

            this.logDebug(`Domínio de spamtrap: ${domain}`);
            return result;
        }

        // ================================================
        // 3. VERIFICAR PADRÕES SUSPEITOS
        // ================================================
        let patternMatches = 0;
        for (const pattern of this.suspiciousPatterns) {
            if (pattern.test(localPart)) {
                patternMatches++;
                result.indicators.push(`Padrão suspeito detectado: ${pattern.source}`);
                result.confidence = Math.min(1.0, result.confidence + 0.2);
            }
        }

        if (patternMatches > 0) {
            result.details.patternCheck = true;
            result.isLikelySpamtrap = true;

            if (patternMatches >= 2) {
                result.confidence = Math.min(1.0, result.confidence + 0.3);
                result.risk = 'high';
            } else {
                result.risk = 'medium';
            }
        }

        // ================================================
        // 4. VERIFICAR EMAILS RECICLADOS
        // ================================================
        const recycledCheck = this.checkRecycled(email, localPart, domain, additionalData);
        if (recycledCheck.isRecycled) {
            result.isRecycled = true;
            result.isLikelySpamtrap = true;
            result.confidence = Math.min(1.0, result.confidence + recycledCheck.confidence);
            result.indicators.push(...recycledCheck.indicators);
            result.details.ageCheck = true;
            result.risk = result.risk === 'none' ? 'medium' : result.risk;
            this.stats.recycledDetected++;
        }

        // ================================================
        // 5. ANÁLISE DE ATIVIDADE (se dados disponíveis)
        // ================================================
        if (additionalData.lastActivity) {
            const inactivityCheck = this.checkInactivity(additionalData.lastActivity);
            if (inactivityCheck.suspicious) {
                result.isLikelySpamtrap = true;
                result.confidence = Math.min(1.0, result.confidence + inactivityCheck.confidence);
                result.indicators.push(inactivityCheck.indicator);
                result.details.activityCheck = true;
            }
        }

        // ================================================
        // 6. ANÁLISE DE FORMATO
        // ================================================
        const formatAnalysis = this.analyzeFormat(localPart);
        if (formatAnalysis.suspicious) {
            result.confidence = Math.min(1.0, result.confidence + formatAnalysis.confidence);
            result.indicators.push(...formatAnalysis.indicators);

            if (formatAnalysis.confidence > 0.3) {
                result.isLikelySpamtrap = true;
            }
        }

        // ================================================
        // 7. DETERMINAR RISCO FINAL
        // ================================================
        if (result.confidence >= 0.8) {
            result.isSpamtrap = true;
            result.risk = 'critical';
            result.recommendations.push('REMOVER - Alta probabilidade de spamtrap');
            this.stats.spamtrapsDetected++;
        } else if (result.confidence >= 0.6) {
            result.isLikelySpamtrap = true;
            result.risk = 'high';
            result.recommendations.push('ALTO RISCO - Provável spamtrap');
            result.recommendations.push('Remover ou verificar manualmente');
            this.stats.likelySpamtraps++;
        } else if (result.confidence >= 0.4) {
            result.isLikelySpamtrap = true;
            result.risk = 'medium';
            result.recommendations.push('RISCO MÉDIO - Possível spamtrap');
            result.recommendations.push('Monitorar engajamento cuidadosamente');
            this.stats.likelySpamtraps++;
        } else if (result.confidence >= 0.2) {
            result.risk = 'low';
            result.recommendations.push('Risco baixo mas existente');
            result.recommendations.push('Incluir em segmentação cuidadosa');
        } else {
            result.risk = 'none';
            result.recommendations.push('Email aparentemente seguro');
            this.stats.cleanEmails++;
        }

        // ================================================
        // 8. RECOMENDAÇÕES ESPECÍFICAS
        // ================================================
        if (result.isRecycled) {
            result.recommendations.push('Email possivelmente reciclado - verificar idade da lista');
        }

        if (result.indicators.length > 2) {
            result.recommendations.push('Múltiplos indicadores de risco detectados');
        }

        this.logDebug(`Spamtrap detection para ${email}: isSpamtrap=${result.isSpamtrap}, confidence=${result.confidence}`);

        return result;
    }

    // ================================================
    // VERIFICAR EMAILS RECICLADOS
    // ================================================
    checkRecycled(email, localPart, domain, additionalData) {
        const check = {
            isRecycled: false,
            confidence: 0,
            indicators: []
        };

        // Verificar se é domínio que recicla emails
        if (this.recycledIndicators.recyclingDomains.includes(domain)) {
            check.confidence += 0.2;
            check.indicators.push(`Domínio conhecido por reciclar emails: ${domain}`);
        }

        // Verificar padrões de emails corporativos antigos
        for (const pattern of this.recycledIndicators.patterns) {
            if (pattern.test(email)) {
                check.confidence += 0.3;
                check.indicators.push('Formato de email corporativo genérico (possivelmente reciclado)');
                break;
            }
        }

        // Verificar idade do email (se disponível)
        if (additionalData.emailAge) {
            const ageInYears = additionalData.emailAge / 365;
            if (ageInYears > 5) {
                check.confidence += 0.3;
                check.indicators.push(`Email muito antigo: ${ageInYears.toFixed(1)} anos`);
            } else if (ageInYears > 3) {
                check.confidence += 0.2;
                check.indicators.push(`Email antigo: ${ageInYears.toFixed(1)} anos`);
            }
        }

        // Verificar se tem formato de email abandonado
        const abandonedPatterns = [
            /^old\./,
            /^former\./,
            /^ex\./,
            /\.old$/,
            /\.backup$/,
            /\.temp$/
        ];

        for (const pattern of abandonedPatterns) {
            if (pattern.test(localPart)) {
                check.confidence += 0.4;
                check.indicators.push('Formato sugere email abandonado');
                break;
            }
        }

        check.isRecycled = check.confidence >= 0.4;

        return check;
    }

    // ================================================
    // VERIFICAR INATIVIDADE
    // ================================================
    checkInactivity(lastActivity) {
        const check = {
            suspicious: false,
            confidence: 0,
            indicator: ''
        };

        if (!lastActivity) return check;

        const now = new Date();
        const last = new Date(lastActivity);
        const daysSinceActivity = (now - last) / (1000 * 60 * 60 * 24);

        if (daysSinceActivity > 730) { // 2 anos
            check.suspicious = true;
            check.confidence = 0.5;
            check.indicator = 'Email inativo há mais de 2 anos';
        } else if (daysSinceActivity > 365) { // 1 ano
            check.suspicious = true;
            check.confidence = 0.3;
            check.indicator = 'Email inativo há mais de 1 ano';
        } else if (daysSinceActivity > 180) { // 6 meses
            check.suspicious = true;
            check.confidence = 0.2;
            check.indicator = 'Email inativo há mais de 6 meses';
        }

        return check;
    }

// ================================================
   // ANALISAR FORMATO DO EMAIL
   // ================================================
   analyzeFormat(localPart) {
       const analysis = {
           suspicious: false,
           confidence: 0,
           indicators: []
       };

       // Verificar se é hash
       if (/^[a-f0-9]{32,}$/i.test(localPart)) {
           analysis.suspicious = true;
           analysis.confidence += 0.4;
           analysis.indicators.push('Local part parece ser um hash');
       }

       // Verificar se tem muitos números aleatórios
       const numbers = (localPart.match(/\d/g) || []).length;
       const letters = (localPart.match(/[a-z]/gi) || []).length;

       if (numbers > letters && localPart.length > 10) {
           analysis.suspicious = true;
           analysis.confidence += 0.3;
           analysis.indicators.push('Excesso de números aleatórios');
       }

       // Verificar comprimento suspeito
       if (localPart.length > 30) {
           analysis.suspicious = true;
           analysis.confidence += 0.2;
           analysis.indicators.push('Local part muito longo');
       }

       // Verificar caracteres aleatórios
       if (localPart.length > 15 && !/[\.\-_]/.test(localPart)) {
           // String longa sem separadores
           const entropy = this.calculateEntropy(localPart);
           if (entropy > 4.5) {
               analysis.suspicious = true;
               analysis.confidence += 0.3;
               analysis.indicators.push('Alta entropia - possível string aleatória');
           }
       }

       // Verificar padrões de teste
       const testPatterns = [
           /^test/i,
           /^demo/i,
           /^sample/i,
           /^example/i,
           /^temp/i,
           /^tmp/i
       ];

       for (const pattern of testPatterns) {
           if (pattern.test(localPart)) {
               analysis.suspicious = true;
               analysis.confidence += 0.2;
               analysis.indicators.push('Padrão de email de teste');
               break;
           }
       }

       return analysis;
   }

   // ================================================
   // CALCULAR ENTROPIA (ALEATORIEDADE)
   // ================================================
   calculateEntropy(str) {
       const freq = {};
       for (const char of str) {
           freq[char] = (freq[char] || 0) + 1;
       }

       let entropy = 0;
       const len = str.length;

       for (const count of Object.values(freq)) {
           const probability = count / len;
           entropy -= probability * Math.log2(probability);
       }

       return entropy;
   }

   // ================================================
   // MÉTODO PARA VERIFICAÇÃO EM LOTE
   // ================================================
   async detectBatch(emails, options = {}) {
       const results = [];
       const summary = {
           total: emails.length,
           spamtraps: 0,
           likely: 0,
           recycled: 0,
           clean: 0
       };

       for (const email of emails) {
           const result = await this.detectSpamtrap(email, options.additionalData?.[email] || {});
           results.push(result);

           if (result.isSpamtrap) {
               summary.spamtraps++;
           } else if (result.isLikelySpamtrap) {
               summary.likely++;
           } else if (result.isRecycled) {
               summary.recycled++;
           } else {
               summary.clean++;
           }

           // Callback de progresso
           if (options.onProgress && results.length % 100 === 0) {
               options.onProgress({
                   processed: results.length,
                   total: emails.length,
                   percentage: ((results.length / emails.length) * 100).toFixed(2)
               });
           }
       }

       return {
           results: results,
           summary: summary,
           recommendations: this.generateBatchRecommendations(summary)
       };
   }

   // ================================================
   // GERAR RECOMENDAÇÕES PARA LOTE
   // ================================================
   generateBatchRecommendations(summary) {
       const recommendations = [];
       const spamtrapRate = (summary.spamtraps / summary.total) * 100;
       const likelyRate = (summary.likely / summary.total) * 100;
       const recycledRate = (summary.recycled / summary.total) * 100;

       if (spamtrapRate > 5) {
           recommendations.push({
               level: 'critical',
               message: `ALERTA CRÍTICO: ${spamtrapRate.toFixed(1)}% de spamtraps detectados`,
               action: 'Não usar esta lista - alto risco de blacklist'
           });
       } else if (spamtrapRate > 2) {
           recommendations.push({
               level: 'high',
               message: `Alto risco: ${spamtrapRate.toFixed(1)}% de spamtraps`,
               action: 'Limpar lista urgentemente antes de usar'
           });
       } else if (spamtrapRate > 0) {
           recommendations.push({
               level: 'medium',
               message: `${summary.spamtraps} spamtraps encontrados`,
               action: 'Remover spamtraps identificados'
           });
       }

       if (likelyRate > 10) {
           recommendations.push({
               level: 'high',
               message: `${likelyRate.toFixed(1)}% de prováveis spamtraps`,
               action: 'Revisar e segmentar cuidadosamente'
           });
       }

       if (recycledRate > 15) {
           recommendations.push({
               level: 'medium',
               message: `${recycledRate.toFixed(1)}% de emails possivelmente reciclados`,
               action: 'Lista pode estar desatualizada - verificar idade'
           });
       }

       if (spamtrapRate === 0 && likelyRate < 5) {
           recommendations.push({
               level: 'low',
               message: 'Lista relativamente limpa de spamtraps',
               action: 'Seguro para uso com monitoramento padrão'
           });
       }

       return recommendations;
   }

   // ================================================
   // ESTATÍSTICAS
   // ================================================
   getStatistics() {
       const total = this.stats.totalChecked || 1;

       return {
           ...this.stats,
           spamtrapRate: ((this.stats.spamtrapsDetected / total) * 100).toFixed(2) + '%',
           likelyRate: ((this.stats.likelySpamtraps / total) * 100).toFixed(2) + '%',
           recycledRate: ((this.stats.recycledDetected / total) * 100).toFixed(2) + '%',
           cleanRate: ((this.stats.cleanEmails / total) * 100).toFixed(2) + '%'
       };
   }

   resetStatistics() {
       this.stats = {
           totalChecked: 0,
           spamtrapsDetected: 0,
           likelySpamtraps: 0,
           recycledDetected: 0,
           cleanEmails: 0
       };

       this.logDebug('Estatísticas de spamtrap resetadas');
   }

   logDebug(message) {
       if (this.debug) {
           console.log(`[SpamtrapDetector] ${message}`);
       }
   }
}

module.exports = SpamtrapDetector;
