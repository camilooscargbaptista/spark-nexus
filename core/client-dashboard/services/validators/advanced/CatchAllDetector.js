// ================================================
// Catch-All / Accept-All Email Detector
// Detecta domínios que aceitam qualquer email
// ================================================

const dns = require('dns').promises;
const net = require('net');

class CatchAllDetector {
    constructor(options = {}) {
        this.debug = options.debug || false;
        this.timeout = options.timeout || 5000;

        // Cache para evitar múltiplas verificações
        this.cache = new Map();
        this.cacheExpiry = 3600000; // 1 hora

        // Configurações de teste
        this.testConfig = {
            numberOfTests: 3,
            testEmailPatterns: [
                () => `test_${Date.now()}_${Math.random().toString(36).substring(7)}`,
                () => `invalid_${Math.random().toString(36).substring(2, 15)}`,
                () => `notexist_${Date.now()}_${Math.floor(Math.random() * 999999)}`,
                () => `fake_user_${Math.random().toString(36).substring(7)}`,
                () => `nonexistent_${Date.now()}`
            ]
        };

        // Estatísticas
        this.stats = {
            totalChecked: 0,
            catchAllDetected: 0,
            normalDomains: 0,
            rejectAllDetected: 0,
            errors: 0,
            cacheHits: 0,
            cacheMisses: 0
        };
    }

    // ================================================
    // MÉTODO PRINCIPAL - DETECTAR CATCH-ALL
    // ================================================
    async detectCatchAll(domain) {
        this.stats.totalChecked++;

        // Verificar cache
        const cached = this.getCached(domain);
        if (cached) {
            this.stats.cacheHits++;
            this.logDebug(`Cache hit para catch-all: ${domain}`);
            return cached;
        }
        this.stats.cacheMisses++;

        const result = {
            domain: domain,
            isCatchAll: false,
            isRejectAll: false,
            confidence: 0,
            method: null,
            details: {
                testsPerformed: 0,
                emailsAccepted: 0,
                emailsRejected: 0,
                testResults: [],
                mxRecords: [],
                smtpBanner: null
            },
            timestamp: new Date().toISOString()
        };

        try {
            // ================================================
            // 1. OBTER MX RECORDS
            // ================================================
            try {
                const mxRecords = await dns.resolveMx(domain);
                result.details.mxRecords = mxRecords.sort((a, b) => a.priority - b.priority);

                if (mxRecords.length === 0) {
                    result.isRejectAll = true;
                    result.confidence = 0.9;
                    result.method = 'no_mx_records';
                    this.stats.rejectAllDetected++;
                    this.setCached(domain, result);
                    return result;
                }
            } catch (error) {
                result.details.mxError = error.message;
                result.isRejectAll = true;
                result.confidence = 0.8;
                result.method = 'mx_resolution_failed';
                this.stats.errors++;
                this.setCached(domain, result);
                return result;
            }

            // ================================================
            // 2. TESTAR EMAILS ALEATÓRIOS
            // ================================================
            const testEmails = this.generateTestEmails(domain);
            const testResults = [];

            for (const testEmail of testEmails) {
                const testResult = await this.testEmailAddress(
                    testEmail,
                    result.details.mxRecords[0].exchange
                );

                testResults.push({
                    email: testEmail,
                    accepted: testResult.accepted,
                    responseCode: testResult.responseCode,
                    message: testResult.message
                });

                result.details.testsPerformed++;

                if (testResult.accepted) {
                    result.details.emailsAccepted++;
                } else {
                    result.details.emailsRejected++;
                }

                // Guardar banner SMTP se disponível
                if (testResult.smtpBanner && !result.details.smtpBanner) {
                    result.details.smtpBanner = testResult.smtpBanner;
                }
            }

            result.details.testResults = testResults;

            // ================================================
            // 3. ANALISAR RESULTADOS
            // ================================================
            const acceptanceRate = result.details.emailsAccepted / result.details.testsPerformed;

            if (acceptanceRate >= 0.8) {
                // 80% ou mais aceitos = catch-all
                result.isCatchAll = true;
                result.confidence = Math.min(0.95, 0.5 + (acceptanceRate * 0.5));
                result.method = 'high_acceptance_rate';
                this.stats.catchAllDetected++;
            } else if (acceptanceRate <= 0.2) {
                // 20% ou menos aceitos = reject-all ou muito restritivo
                result.isRejectAll = acceptanceRate === 0;
                result.confidence = Math.min(0.95, 0.5 + ((1 - acceptanceRate) * 0.5));
                result.method = acceptanceRate === 0 ? 'reject_all' : 'highly_restrictive';
                if (result.isRejectAll) {
                    this.stats.rejectAllDetected++;
                }
            } else {
                // Normal - aceita alguns, rejeita outros
                result.isCatchAll = false;
                result.isRejectAll = false;
                result.confidence = 0.7;
                result.method = 'selective_acceptance';
                this.stats.normalDomains++;
            }

            // ================================================
            // 4. ANÁLISE ADICIONAL BASEADA NO BANNER
            // ================================================
            if (result.details.smtpBanner) {
                const banner = result.details.smtpBanner.toLowerCase();

                // Detectar servidores conhecidos por catch-all
                const catchAllIndicators = [
                    'catch-all',
                    'accept all',
                    'wildcard',
                    'devnull'
                ];

                for (const indicator of catchAllIndicators) {
                    if (banner.includes(indicator)) {
                        result.isCatchAll = true;
                        result.confidence = Math.min(0.99, result.confidence + 0.2);
                        result.method = 'banner_analysis';
                        break;
                    }
                }

                // Detectar servidores corporativos (menos provável catch-all)
                const corporateIndicators = [
                    'microsoft',
                    'exchange',
                    'google',
                    'gmail',
                    'outlook',
                    'office365'
                ];

                for (const indicator of corporateIndicators) {
                    if (banner.includes(indicator)) {
                        result.confidence = Math.max(0.3, result.confidence - 0.2);
                        break;
                    }
                }
            }

            // Cachear resultado
            this.setCached(domain, result);

            this.logDebug(`Catch-all detection para ${domain}: isCatchAll=${result.isCatchAll}, confidence=${result.confidence}`);

            return result;

        } catch (error) {
            this.stats.errors++;
            result.error = error.message;
            result.confidence = 0;
            this.logDebug(`Erro ao detectar catch-all para ${domain}: ${error.message}`);
            return result;
        }
    }

    // ================================================
    // GERAR EMAILS DE TESTE
    // ================================================
    generateTestEmails(domain) {
        const emails = [];
        const patterns = [...this.testConfig.testEmailPatterns];

        // Embaralhar patterns
        for (let i = patterns.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [patterns[i], patterns[j]] = [patterns[j], patterns[i]];
        }

        // Gerar emails de teste
        for (let i = 0; i < this.testConfig.numberOfTests && i < patterns.length; i++) {
            const localPart = patterns[i]();
            emails.push(`${localPart}@${domain}`);
        }

        return emails;
    }

    // ================================================
    // TESTAR EMAIL INDIVIDUAL VIA SMTP
    // ================================================
    async testEmailAddress(email, mxHost) {
        return new Promise((resolve) => {
            const result = {
                accepted: false,
                responseCode: null,
                message: null,
                smtpBanner: null
            };

            const socket = new net.Socket();
            let commandsSent = 0;
            let dataReceived = '';

            socket.setTimeout(this.timeout);

            socket.on('connect', () => {
                this.logDebug(`Conectado ao servidor SMTP ${mxHost}`);
            });

            socket.on('data', (data) => {
                dataReceived += data.toString();
                const lines = dataReceived.split('\r\n');

                for (const line of lines) {
                    if (line.length < 3) continue;

                    const code = line.substring(0, 3);
                    const message = line.substring(4);

                    // Capturar banner
                    if (commandsSent === 0 && code === '220') {
                        result.smtpBanner = message;
                        // Enviar HELO
                        socket.write('HELO test.com\r\n');
                        commandsSent++;
                    } else if (commandsSent === 1 && code === '250') {
                        // Resposta ao HELO, enviar MAIL FROM
                        socket.write('MAIL FROM: <test@test.com>\r\n');
                        commandsSent++;
                    } else if (commandsSent === 2 && code === '250') {
                        // Resposta ao MAIL FROM, enviar RCPT TO
                        socket.write(`RCPT TO: <${email}>\r\n`);
                        commandsSent++;
                    } else if (commandsSent === 3) {
                        // Resposta ao RCPT TO
                        result.responseCode = code;
                        result.message = message;

                        if (code === '250' || code === '251') {
                            result.accepted = true;
                        } else {
                            result.accepted = false;
                        }

                        // Enviar QUIT
                        socket.write('QUIT\r\n');
                        socket.end();
                    }
                }
            });

            socket.on('timeout', () => {
                result.message = 'Timeout';
                socket.destroy();
                resolve(result);
            });

            socket.on('error', (error) => {
                result.message = error.message;
                resolve(result);
            });

            socket.on('close', () => {
                resolve(result);
            });

            socket.connect(25, mxHost);
        });
    }

    // ================================================
    // CACHE MANAGEMENT
    // ================================================
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
        if (this.cache.size > 1000) {
            const firstKey = this.cache.keys().next().value;
            this.cache.delete(firstKey);
        }
    }

    clearCache() {
        this.cache.clear();
        this.logDebug('Cache de catch-all limpo');
    }

    // ================================================
    // ESTATÍSTICAS
    // ================================================
    getStatistics() {
        return {
            ...this.stats,
            catchAllRate: this.stats.totalChecked > 0
                ? ((this.stats.catchAllDetected / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            rejectAllRate: this.stats.totalChecked > 0
                ? ((this.stats.rejectAllDetected / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            normalRate: this.stats.totalChecked > 0
                ? ((this.stats.normalDomains / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            cacheHitRate: (this.stats.cacheHits + this.stats.cacheMisses) > 0
                ? ((this.stats.cacheHits / (this.stats.cacheHits + this.stats.cacheMisses)) * 100).toFixed(2) + '%'
                : '0%',
            cacheSize: this.cache.size
        };
    }

    resetStatistics() {
        this.stats = {
            totalChecked: 0,
            catchAllDetected: 0,
            normalDomains: 0,
            rejectAllDetected: 0,
            errors: 0,
            cacheHits: 0,
            cacheMisses: 0
        };
        this.logDebug('Estatísticas de catch-all resetadas');
    }

    logDebug(message) {
        if (this.debug) {
            console.log(`[CatchAllDetector] ${message}`);
        }
    }
}

module.exports = CatchAllDetector;
