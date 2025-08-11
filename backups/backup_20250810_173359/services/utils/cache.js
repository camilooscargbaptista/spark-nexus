// Cache Service
class CacheService {
    constructor() {
        this.memoryCache = new Map();
        this.maxSize = 1000;
    }

    async get(key) {
        const cached = this.memoryCache.get(key);
        if (cached && Date.now() < cached.expires) {
            return cached.value;
        }
        this.memoryCache.delete(key);
        return null;
    }

    async set(key, value, ttl = 3600) {
        this.memoryCache.set(key, {
            value: value,
            expires: Date.now() + (ttl * 1000)
        });
        
        if (this.memoryCache.size > this.maxSize) {
            const firstKey = this.memoryCache.keys().next().value;
            this.memoryCache.delete(firstKey);
        }
    }

    getStats() {
        return { size: this.memoryCache.size };
    }
}

module.exports = CacheService;
