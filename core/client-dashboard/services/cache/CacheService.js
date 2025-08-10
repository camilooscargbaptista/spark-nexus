// ================================================
// Cache Service - Sistema híbrido Memória + Redis
// ================================================

const Redis = require('redis');

class CacheService {
    constructor(options = {}) {
        // Configurações
        this.config = {
            memoryMaxSize: options.memoryMaxSize || 1000,
            memoryTTL: options.memoryTTL || 300, // 5 minutos
            redisTTL: options.redisTTL || 86400, // 24 horas
            redisPrefix: options.redisPrefix || 'spark:cache:',
            enableRedis: options.enableRedis !== false,
            enableStats: options.enableStats !== false
        };

        // Cache L1 (Memória)
        this.memoryCache = new Map();
        this.memoryCacheTimers = new Map();

        // Cache L2 (Redis)
        this.redis = null;
        this.redisConnected = false;

        if (this.config.enableRedis) {
            this.initRedis();
        }

        // Estatísticas
        this.stats = {
            hits: { memory: 0, redis: 0 },
            misses: 0,
            sets: { memory: 0, redis: 0 },
            evictions: 0,
            errors: { redis: 0 }
        };

        // Limpeza periódica
        this.startCleanupInterval();
    }

    async initRedis() {
        try {
            this.redis = Redis.createClient({
                url: process.env.REDIS_URL || 'redis://redis:6379',
                password: process.env.REDIS_PASSWORD || 'SparkNexus2024!',
                socket: {
                    reconnectStrategy: (retries) => {
                        if (retries > 10) {
                            console.log('❌ Redis: muitas tentativas de reconexão');
                            return new Error('Redis connection failed');
                        }
                        return Math.min(retries * 100, 3000);
                    }
                }
            });

            this.redis.on('error', (err) => {
                console.error('Redis error:', err);
                this.stats.errors.redis++;
                // Se for erro de autenticação, desabilitar Redis
                if (err.message && (err.message.includes('NOAUTH') || err.message.includes('Authentication'))) {
                    console.log('⚠️ Redis: Erro de autenticação, usando apenas cache em memória');
                    this.redisConnected = false;
                }
                this.redisConnected = false;
            });

            this.redis.on('connect', () => {
                console.log('✅ Redis conectado para cache');
                this.redisConnected = true;
            });

            await this.redis.connect();
        } catch (error) {
            console.warn('⚠️ Redis não disponível, usando apenas cache em memória');
            this.redisConnected = false;
        }
    }

    // ================================================
    // Métodos principais
    // ================================================

    async get(key) {
        // Tentar L1 (Memória)
        const memoryValue = this.memoryCache.get(key);
        if (memoryValue !== undefined) {
            this.stats.hits.memory++;
            return memoryValue;
        }

        // Tentar L2 (Redis)
        if (this.redisConnected) {
            try {
                const redisKey = this.config.redisPrefix + key;
                const redisValue = await this.redis.get(redisKey);
                
                if (redisValue) {
                    this.stats.hits.redis++;
                    const parsed = JSON.parse(redisValue);
                    
                    // Promover para L1
                    this.setMemory(key, parsed, this.config.memoryTTL);
                    
                    return parsed;
                }
            } catch (error) {
                console.error('Redis get error:', error);
                this.stats.errors.redis++;
            }
        }

        this.stats.misses++;
        return null;
    }

    async set(key, value, ttl = null) {
        // Salvar em L1 (Memória)
        const memoryTTL = ttl || this.config.memoryTTL;
        this.setMemory(key, value, memoryTTL);

        // Salvar em L2 (Redis)
        if (this.redisConnected) {
            try {
                const redisKey = this.config.redisPrefix + key;
                const redisTTL = ttl || this.config.redisTTL;
                
                await this.redis.setEx(
                    redisKey,
                    redisTTL,
                    JSON.stringify(value)
                );
                
                this.stats.sets.redis++;
            } catch (error) {
                console.error('Redis set error:', error);
                this.stats.errors.redis++;
            }
        }

        return true;
    }

    setMemory(key, value, ttl) {
        // Verificar limite de tamanho
        if (this.memoryCache.size >= this.config.memoryMaxSize) {
            this.evictOldest();
        }

        // Limpar timer existente
        if (this.memoryCacheTimers.has(key)) {
            clearTimeout(this.memoryCacheTimers.get(key));
        }

        // Adicionar ao cache
        this.memoryCache.set(key, value);
        this.stats.sets.memory++;

        // Configurar expiração
        const timer = setTimeout(() => {
            this.memoryCache.delete(key);
            this.memoryCacheTimers.delete(key);
        }, ttl * 1000);

        this.memoryCacheTimers.set(key, timer);
    }

    evictOldest() {
        const firstKey = this.memoryCache.keys().next().value;
        if (firstKey) {
            this.memoryCache.delete(firstKey);
            
            if (this.memoryCacheTimers.has(firstKey)) {
                clearTimeout(this.memoryCacheTimers.get(firstKey));
                this.memoryCacheTimers.delete(firstKey);
            }
            
            this.stats.evictions++;
        }
    }

    async delete(key) {
        // Remover de L1
        this.memoryCache.delete(key);
        if (this.memoryCacheTimers.has(key)) {
            clearTimeout(this.memoryCacheTimers.get(key));
            this.memoryCacheTimers.delete(key);
        }

        // Remover de L2
        if (this.redisConnected) {
            try {
                const redisKey = this.config.redisPrefix + key;
                await this.redis.del(redisKey);
            } catch (error) {
                console.error('Redis delete error:', error);
            }
        }
    }

    async clear() {
        // Limpar L1
        for (const timer of this.memoryCacheTimers.values()) {
            clearTimeout(timer);
        }
        this.memoryCache.clear();
        this.memoryCacheTimers.clear();

        // Limpar L2
        if (this.redisConnected) {
            try {
                const keys = await this.redis.keys(this.config.redisPrefix + '*');
                if (keys.length > 0) {
                    await this.redis.del(keys);
                }
            } catch (error) {
                console.error('Redis clear error:', error);
            }
        }

        console.log('🧹 Cache completamente limpo');
    }

    // ================================================
    // Métodos especializados para validação de email
    // ================================================

    async getEmailValidation(email) {
        const key = `email:${email.toLowerCase()}`;
        return this.get(key);
    }

    async setEmailValidation(email, result, ttl = 3600) {
        const key = `email:${email.toLowerCase()}`;
        return this.set(key, result, ttl);
    }

    async getDomainValidation(domain) {
        const key = `domain:${domain.toLowerCase()}`;
        return this.get(key);
    }

    async setDomainValidation(domain, result, ttl = 7200) {
        const key = `domain:${domain.toLowerCase()}`;
        return this.set(key, result, ttl);
    }

    // ================================================
    // Estatísticas e manutenção
    // ================================================

    getStatistics() {
        const totalHits = this.stats.hits.memory + this.stats.hits.redis;
        const totalRequests = totalHits + this.stats.misses;
        
        return {
            ...this.stats,
            totalHits,
            totalRequests,
            hitRate: totalRequests > 0 
                ? ((totalHits / totalRequests) * 100).toFixed(2) + '%'
                : '0%',
            memoryCacheSize: this.memoryCache.size,
            redisConnected: this.redisConnected,
            memoryHitRate: totalRequests > 0
                ? ((this.stats.hits.memory / totalRequests) * 100).toFixed(2) + '%'
                : '0%',
            redisHitRate: totalRequests > 0
                ? ((this.stats.hits.redis / totalRequests) * 100).toFixed(2) + '%'
                : '0%'
        };
    }

    startCleanupInterval() {
        // Limpeza a cada 5 minutos
        setInterval(() => {
            const now = Date.now();
            let cleaned = 0;
            
            // Limpar entradas expiradas manualmente (backup)
            for (const [key, timer] of this.memoryCacheTimers.entries()) {
                if (!this.memoryCache.has(key)) {
                    clearTimeout(timer);
                    this.memoryCacheTimers.delete(key);
                    cleaned++;
                }
            }
            
            if (cleaned > 0) {
                console.log(`🧹 Limpeza periódica: ${cleaned} timers órfãos removidos`);
            }
        }, 300000); // 5 minutos
    }

    async shutdown() {
        // Limpar timers
        for (const timer of this.memoryCacheTimers.values()) {
            clearTimeout(timer);
        }

        // Desconectar Redis
        if (this.redis) {
            await this.redis.quit();
        }

        console.log('Cache service encerrado');
    }
}

module.exports = CacheService;
