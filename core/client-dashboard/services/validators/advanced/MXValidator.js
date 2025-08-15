// ================================================
// MX Record Validator - v1.0
// Verificação avançada de registros MX e roteamento de email
// ================================================

const dns = require('dns').promises;
const net = require('net');

class MXValidator {
    constructor() {
        this.cache = new Map();
        this.cacheExpiry = 3600000; // 1 hora

        this.stats = {
            totalChecks: 0,
            validMX: 0,
            invalidMX: 0,
            cacheHits: 0,
            cacheMisses: 0,
            errors: 0
        };

        // Domínios conhecidos com configurações especiais
        this.specialConfigs = {
            // Domínios que usam A record ao invés de MX
            aRecordDomains: [
                'localhost',
                'example.com'
            ],
            // Domínios com MX não standard
            customMXDomains: {
                'gmail.com': ['gmail-smtp-in.l.google.com', 'alt1.gmail-smtp-in.l.google.com'],
                'outlook.com': ['outlook-com.olc.protection.outlook.com'],
                'yahoo.com': ['mta5.am0.yahoodns.net', 'mta6.am0.yahoodns.net']
            }
        };

        this.debug = process.env.DEBUG_MX === 'true';
    }

    /**
     * Verifica registros MX completos de um domínio
     */
    async validateMX(domain) {
        this.stats.totalChecks++;

        // Verificar cache
        const cached = this.getCached(domain);
        if (cached) {
            this.stats.cacheHits++;
            this.log(`📦 Cache hit para MX: ${domain}`);
            return cached;
        }
        this.stats.cacheMisses++;

        const result = {
            domain: domain,
            valid: false,
            hasMX: false,
            hasA: false,
            hasCNAME: false,
            mxRecords: [],
            aRecords: [],
            cnameRecord: null,
            preferredExchange: null,
            emailRoutingValid: false,
            priority: null,
            details: {},
            timestamp: new Date().toISOString()
        };

        try {
            // 1. Verificar registros MX
            try {
                const mxRecords = await dns.resolveMx(domain);
                if (mxRecords && mxRecords.length > 0) {
                    result.hasMX = true;
                    result.mxRecords = mxRecords.sort((a, b) => a.priority - b.priority);
                    result.preferredExchange = result.mxRecords[0].exchange;
                    result.priority = result.mxRecords[0].priority;
                    result.emailRoutingValid = true;
                    result.valid = true;

                    // Verificar se os servidores MX são alcançáveis
                    result.mxServersReachable = await this.checkMXServersReachability(result.mxRecords);

                    this.log(`✅ MX records encontrados para ${domain}: ${result.mxRecords.length} registros`);
                }
            } catch (mxError) {
                result.details.mxError = mxError.code || mxError.message;
                this.log(`⚠️ Sem MX records para ${domain}: ${mxError.code}`);
            }

            // 2. Se não tem MX, verificar A record (fallback)
            if (!result.hasMX) {
                try {
                    const aRecords = await dns.resolve4(domain);
                    if (aRecords && aRecords.length > 0) {
                        result.hasA = true;
                        result.aRecords = aRecords;
                        // Alguns servidores aceitam email direto no A record
                        result.emailRoutingValid = true;
                        result.valid = true;
                        result.details.note = 'Usando A record como fallback (sem MX)';

                        this.log(`📌 A records encontrados para ${domain}: ${aRecords.join(', ')}`);
                    }
                } catch (aError) {
                    result.details.aError = aError.code || aError.message;
                }
            }

            // 3. Verificar CNAME (pode indicar redirecionamento)
            try {
                const cnameRecords = await dns.resolveCname(domain);
                if (cnameRecords && cnameRecords.length > 0) {
                    result.hasCNAME = true;
                    result.cnameRecord = cnameRecords[0];
                    result.details.cname = cnameRecords;

                    // Se tem CNAME, verificar MX do destino
                    if (!result.hasMX && !result.hasA) {
                        const cnameResult = await this.validateMX(result.cnameRecord);
                        if (cnameResult.valid) {
                            result.emailRoutingValid = true;
                            result.valid = true;
                            result.details.cnameRouting = cnameResult;
                        }
                    }

                    this.log(`🔄 CNAME encontrado para ${domain}: ${result.cnameRecord}`);
                }
            } catch (cnameError) {
                // CNAME não encontrado é normal
            }

            // 4. Análise adicional
            result.analysis = this.analyzeMXConfiguration(result);

            // 5. Determinar provedor de email
            result.emailProvider = this.detectEmailProvider(result);

            // 6. Calcular score de confiabilidade
            result.reliabilityScore = this.calculateReliabilityScore(result);

            // Atualizar estatísticas
            if (result.valid) {
                this.stats.validMX++;
            } else {
                this.stats.invalidMX++;
            }

            // Cachear resultado
            this.setCached(domain, result);

            return result;

        } catch (error) {
            this.stats.errors++;
            result.error = error.message;
            result.details.generalError = error.stack;
            this.log(`❌ Erro ao verificar MX para ${domain}: ${error.message}`);
            return result;
        }
    }

    /**
     * Verifica se os servidores MX são alcançáveis
     */
    async checkMXServersReachability(mxRecords) {
        const results = [];

        for (const mx of mxRecords.slice(0, 3)) { // Verificar apenas os 3 primeiros
            const reachable = await this.isServerReachable(mx.exchange, 25);
            results.push({
                exchange: mx.exchange,
                priority: mx.priority,
                reachable: reachable,
                port25Open: reachable
            });
        }

        return results;
    }

    /**
     * Verifica se um servidor é alcançável em uma porta
     */
    async isServerReachable(host, port, timeout = 3000) {
        return new Promise((resolve) => {
            const socket = new net.Socket();

            socket.setTimeout(timeout);

            socket.on('connect', () => {
                socket.destroy();
                resolve(true);
            });

            socket.on('timeout', () => {
                socket.destroy();
                resolve(false);
            });

            socket.on('error', () => {
                resolve(false);
            });

            try {
                socket.connect(port, host);
            } catch (error) {
                resolve(false);
            }
        });
    }

    /**
     * Analisa a configuração MX e retorna insights
     */
    analyzeMXConfiguration(result) {
        const analysis = {
            quality: 'unknown',
            issues: [],
            recommendations: [],
            score: 0
        };

        // Tem MX records válidos
        if (result.hasMX && result.mxRecords.length > 0) {
            analysis.score += 10;

            // Múltiplos MX records (redundância)
            if (result.mxRecords.length > 1) {
                analysis.score += 5;
                analysis.recommendations.push('Boa redundância com múltiplos MX records');
            }

            // Verifica se os servidores são alcançáveis
            if (result.mxServersReachable) {
                const reachableCount = result.mxServersReachable.filter(s => s.reachable).length;
                if (reachableCount === result.mxServersReachable.length) {
                    analysis.score += 5;
                    analysis.quality = 'excellent';
                } else if (reachableCount > 0) {
                    analysis.score += 2;
                    analysis.quality = 'good';
                    analysis.issues.push(`${result.mxServersReachable.length - reachableCount} servidor(es) MX não alcançável(is)`);
                } else {
                    analysis.quality = 'poor';
                    analysis.issues.push('Nenhum servidor MX alcançável');
                }
            }

            // Verificar prioridades
            const priorities = result.mxRecords.map(mx => mx.priority);
            if (new Set(priorities).size === priorities.length) {
                analysis.score += 2;
                analysis.recommendations.push('Prioridades MX bem configuradas');
            } else {
                analysis.issues.push('MX records com prioridades duplicadas');
            }

        } else if (result.hasA) {
            analysis.score += 5;
            analysis.quality = 'acceptable';
            analysis.issues.push('Sem MX records, usando A record como fallback');
            analysis.recommendations.push('Configurar MX records para melhor entrega de email');

        } else if (result.hasCNAME) {
            analysis.score += 3;
            analysis.quality = 'poor';
            analysis.issues.push('Apenas CNAME encontrado');
            analysis.recommendations.push('Configurar MX records diretos');

        } else {
            analysis.quality = 'invalid';
            analysis.issues.push('Nenhum registro de roteamento de email encontrado');
            analysis.recommendations.push('Domínio não configurado para receber emails');
        }

        // Score final
        if (analysis.score >= 15) {
            analysis.quality = 'excellent';
        } else if (analysis.score >= 10) {
            analysis.quality = 'good';
        } else if (analysis.score >= 5) {
            analysis.quality = 'acceptable';
        } else {
            analysis.quality = 'poor';
        }

        return analysis;
    }

    /**
     * Detecta o provedor de email baseado nos MX records
     */
    detectEmailProvider(result) {
        if (!result.mxRecords || result.mxRecords.length === 0) {
            return 'unknown';
        }

        const mxString = result.mxRecords.map(mx => mx.exchange.toLowerCase()).join(' ');

        const providers = {
            'Google Workspace': ['google.com', 'googlemail.com', 'aspmx.l.google.com'],
            'Microsoft 365': ['outlook.com', 'protection.outlook.com', 'mail.protection.outlook.com'],
            'Yahoo': ['yahoodns.net', 'yahoo.com'],
            'Zoho': ['zoho.com', 'zohomail.com'],
            'ProtonMail': ['protonmail.ch', 'proton.me'],
            'Amazon SES': ['amazonses.com', 'amazonaws.com'],
            'SendGrid': ['sendgrid.net', 'sendgrid.com'],
            'Mailgun': ['mailgun.org', 'mailgun.com'],
            'cPanel': ['mail.', 'mx.', 'mx1.', 'mx2.'],
            'Locaweb': ['locaweb.com.br', 'locamail.com.br'],
            'UOL Host': ['uolhost.com.br', 'uol.com.br'],
            'Kinghost': ['kinghost.net', 'kinghost.com.br']
        };

        for (const [provider, patterns] of Object.entries(providers)) {
            for (const pattern of patterns) {
                if (mxString.includes(pattern)) {
                    return provider;
                }
            }
        }

        // Verificar se é self-hosted
        if (result.domain && mxString.includes(result.domain)) {
            return 'Self-hosted';
        }

        return 'Other';
    }

    /**
     * Calcula score de confiabilidade baseado na configuração MX
     */
    calculateReliabilityScore(result) {
        let score = 0;

        // Fatores positivos
        if (result.hasMX) score += 40;
        if (result.mxRecords && result.mxRecords.length > 1) score += 20; // Redundância
        if (result.mxServersReachable) {
            const reachableCount = result.mxServersReachable.filter(s => s.reachable).length;
            score += (reachableCount / result.mxServersReachable.length) * 20;
        }
        if (result.emailProvider !== 'unknown' && result.emailProvider !== 'Other') score += 10;
        if (result.hasA) score += 5;
        if (!result.error) score += 5;

        // Fatores negativos
        if (!result.valid) score = Math.min(score, 20);
        if (result.hasCNAME && !result.hasMX) score -= 10;

        return Math.max(0, Math.min(100, Math.round(score)));
    }

    /**
     * Cache management
     */
    getCached(domain) {
        if (!this.cache.has(domain)) return null;

        const cached = this.cache.get(domain);
        const now = Date.now();

        if (now - cached.cachedAt > this.cacheExpiry) {
            this.cache.delete(domain);
            return null;
        }

        return { ...cached.result, fromCache: true };
    }

    setCached(domain, result) {
        this.cache.set(domain, {
            result: result,
            cachedAt: Date.now()
        });

        // Limpar cache se muito grande
        if (this.cache.size > 10000) {
            const firstKey = this.cache.keys().next().value;
            this.cache.delete(firstKey);
        }
    }

    clearCache() {
        this.cache.clear();
        this.log('🧹 Cache MX limpo');
    }

    /**
     * Estatísticas
     */
    getStatistics() {
        return {
            ...this.stats,
            cacheSize: this.cache.size,
            cacheHitRate: this.stats.totalChecks > 0
                ? ((this.stats.cacheHits / this.stats.totalChecks) * 100).toFixed(2) + '%'
                : '0%',
            validRate: this.stats.totalChecks > 0
                ? ((this.stats.validMX / this.stats.totalChecks) * 100).toFixed(2) + '%'
                : '0%'
        };
    }

    resetStatistics() {
        this.stats = {
            totalChecks: 0,
            validMX: 0,
            invalidMX: 0,
            cacheHits: 0,
            cacheMisses: 0,
            errors: 0
        };
        this.log('📊 Estatísticas MX resetadas');
    }

    log(message) {
        if (this.debug) {
            console.log(`[MXValidator] ${message}`);
        }
    }
}

module.exports = MXValidator;
