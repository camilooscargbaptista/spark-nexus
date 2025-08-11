// Cache Service Simples
class CacheService {
    constructor(options = {}) {
        this.cache = new Map();
        this.ttl = options.memoryTTL || 300;
    }
    
    async get(key) {
        const item = this.cache.get(key);
        if (!item) return null;
        
        if (Date.now() > item.expires) {
            this.cache.delete(key);
            return null;
        }
        
        return item.value;
    }
    
    async set(key, value, ttl = null) {
        const expires = Date.now() + ((ttl || this.ttl) * 1000);
        this.cache.set(key, { value, expires });
    }
    
    async clear() {
        this.cache.clear();
    }
    
    async shutdown() {
        this.cache.clear();
    }
}

module.exports = CacheService;
