// ================================================
// SMTP Validator - Verificação real de caixa postal
// ================================================

const net = require('net');
const dns = require('dns').promises;
const { promisify } = require('util');

class SMTPValidator {
    constructor() {
        this.timeout = 5000; // 5 segundos
        this.fromEmail = 'verify@sparknexus.com.br';
        this.stats = {
            totalChecked: 0,
            mailboxExists: 0,
            mailboxNotFound: 0,
            catchAll: 0,
            errors: 0
        };
    }

    async validateEmail(email, options = {}) {
        this.stats.totalChecked++;
        
        const result = {
            valid: false,
            exists: false,
            catchAll: false,
            disposable: false,
            roleAccount: false,
            smtp: {
                connected: false,
                command: null,
                response: null,
                responseCode: null
            },
            score: 50 // Score base
        };

        try {
            const [localPart, domain] = email.split('@');
            
            if (!domain) {
                result.smtp.response = 'Invalid email format';
                return result;
            }

            // Passo 1: Verificar MX records
            const mxRecords = await this.getMXRecords(domain);
            if (!mxRecords || mxRecords.length === 0) {
                result.smtp.response = 'No MX records found';
                result.score = 10;
                return result;
            }

            // Passo 2: Conectar ao servidor SMTP
            const smtpResult = await this.checkSMTP(email, mxRecords[0].exchange);
            
            result.smtp = { ...result.smtp, ...smtpResult };
            result.valid = smtpResult.valid;
            result.exists = smtpResult.exists;
            result.catchAll = smtpResult.catchAll;
            
            // Ajustar score baseado no resultado
            if (smtpResult.exists && !smtpResult.catchAll) {
                this.stats.mailboxExists++;
                result.score = 90; // Alta confiança
            } else if (smtpResult.catchAll) {
                this.stats.catchAll++;
                result.score = 60; // Média confiança (aceita tudo)
            } else if (!smtpResult.exists) {
                this.stats.mailboxNotFound++;
                result.score = 20; // Baixa confiança
            }
            
        } catch (error) {
            this.stats.errors++;
            result.smtp.response = error.message;
            result.score = 40; // Score neutro em caso de erro
        }
        
        return result;
    }

    async getMXRecords(domain) {
        try {
            const records = await dns.resolveMx(domain);
            return records.sort((a, b) => a.priority - b.priority);
        } catch (error) {
            return null;
        }
    }

    async checkSMTP(email, mxHost) {
        return new Promise((resolve) => {
            const result = {
                valid: false,
                exists: false,
                catchAll: false,
                connected: false,
                response: '',
                responseCode: null
            };

            const client = new net.Socket();
            let step = 0;
            let responses = [];

            // Timeout
            const timeout = setTimeout(() => {
                client.destroy();
                result.response = 'Connection timeout';
                resolve(result);
            }, this.timeout);

            client.on('connect', () => {
                result.connected = true;
            });

            client.on('data', async (data) => {
                const response = data.toString();
                responses.push(response);
                const code = parseInt(response.substring(0, 3));
                
                switch(step) {
                    case 0: // Resposta inicial
                        if (code === 220) {
                            client.write(`HELO sparknexus.com.br\r\n`);
                            step++;
                        }
                        break;
                        
                    case 1: // Resposta ao HELO
                        if (code === 250) {
                            client.write(`MAIL FROM: <${this.fromEmail}>\r\n`);
                            step++;
                        }
                        break;
                        
                    case 2: // Resposta ao MAIL FROM
                        if (code === 250) {
                            // Testar email real
                            client.write(`RCPT TO: <${email}>\r\n`);
                            step++;
                        }
                        break;
                        
                    case 3: // Resposta ao RCPT TO (email real)
                        result.responseCode = code;
                        if (code === 250 || code === 251) {
                            result.exists = true;
                            result.valid = true;
                            
                            // Testar catch-all com email aleatório
                            const randomEmail = `random${Date.now()}@${email.split('@')[1]}`;
                            client.write(`RCPT TO: <${randomEmail}>\r\n`);
                            step++;
                        } else if (code === 550 || code === 551 || code === 553) {
                            result.exists = false;
                            result.valid = false;
                            client.write(`QUIT\r\n`);
                            clearTimeout(timeout);
                            client.destroy();
                            resolve(result);
                        } else {
                            // Código desconhecido, assumir inválido
                            result.exists = false;
                            client.write(`QUIT\r\n`);
                            clearTimeout(timeout);
                            client.destroy();
                            resolve(result);
                        }
                        break;
                        
                    case 4: // Resposta ao teste catch-all
                        if (code === 250 || code === 251) {
                            // Aceita emails aleatórios = catch-all
                            result.catchAll = true;
                        }
                        client.write(`QUIT\r\n`);
                        clearTimeout(timeout);
                        client.destroy();
                        resolve(result);
                        break;
                }
            });

            client.on('error', (err) => {
                clearTimeout(timeout);
                result.response = err.message;
                resolve(result);
            });

            client.on('close', () => {
                clearTimeout(timeout);
                result.response = responses.join(' ');
                resolve(result);
            });

            // Conectar
            client.connect(25, mxHost);
        });
    }

    getStatistics() {
        return {
            ...this.stats,
            successRate: this.stats.totalChecked > 0
                ? ((this.stats.mailboxExists / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            catchAllRate: this.stats.totalChecked > 0
                ? ((this.stats.catchAll / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%',
            errorRate: this.stats.totalChecked > 0
                ? ((this.stats.errors / this.stats.totalChecked) * 100).toFixed(2) + '%'
                : '0%'
        };
    }
}

module.exports = SMTPValidator;
