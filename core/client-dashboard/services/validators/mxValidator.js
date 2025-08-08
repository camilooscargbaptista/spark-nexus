// MX Validator
const dns = require('dns').promises;

class MXValidator {
    constructor() {
        this.cache = new Map();
        this.cacheTime = 3600000; // 1 hora
    }

    async validate(domain) {
        const result = {
            valid: false,
            mxRecords: [],
            score: 0,
            reason: null
        };

        try {
            // Verificar cache
            const cached = this.getFromCache(domain);
            if (cached) {
                return { ...cached, cached: true };
            }

            // Buscar MX records
            const mxRecords = await this.getMXRecords(domain);
            
            if (mxRecords && mxRecords.length > 0) {
                result.valid = true;
                result.mxRecords = mxRecords.map(mx => ({
                    exchange: mx.exchange,
                    priority: mx.priority
                }));
                result.score = 80;
            } else {
                result.reason = 'Nenhum MX record encontrado';
                result.score = 20;
            }

            // Salvar no cache
            this.saveToCache(domain, result);
            return result;

        } catch (error) {
            result.error = error.message;
            result.score = 10;
            return result;
        }
    }

    async getMXRecords(domain) {
        try {
            const records = await dns.resolveMx(domain);
            return records;
        } catch (error) {
            return [];
        }
    }

    getFromCache(domain) {
        const cached = this.cache.get(domain);
        if (cached && Date.now() - cached.timestamp < this.cacheTime) {
            return cached.data;
        }
        this.cache.delete(domain);
        return null;
    }

    saveToCache(domain, data) {
        this.cache.set(domain, {
            data: data,
            timestamp: Date.now()
        });
    }
}

module.exports = MXValidator;
