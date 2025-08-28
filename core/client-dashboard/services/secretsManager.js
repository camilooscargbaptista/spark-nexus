// ================================================
// AWS Secrets Manager Service
// Gestão segura de credenciais para produção
// ================================================

const AWS = require('aws-sdk');

class SecretsManager {
    constructor() {
        // Configurar AWS Secrets Manager
        this.region = process.env.AWS_SECRETS_MANAGER_REGION || process.env.AWS_REGION || 'us-east-1';
        this.secretPrefix = process.env.SECRET_NAME_PREFIX || 'sparknexus/';
        
        // Inicializar cliente AWS
        this.secretsManager = new AWS.SecretsManager({
            region: this.region
        });
        
        // Cache para evitar chamadas desnecessárias
        this.cache = new Map();
        this.cacheExpiry = new Map();
        this.cacheTTL = 5 * 60 * 1000; // 5 minutos
    }

    /**
     * Buscar secret do AWS Secrets Manager
     * @param {string} secretName - Nome do secret
     * @param {boolean} useCache - Usar cache (padrão: true)
     * @returns {Promise<Object>} - Secret data
     */
    async getSecret(secretName, useCache = true) {
        const fullSecretName = `${this.secretPrefix}${secretName}`;
        
        // Verificar cache primeiro
        if (useCache && this.isValidCache(fullSecretName)) {
            console.log(`[SecretsManager] Cache hit para: ${secretName}`);
            return this.cache.get(fullSecretName);
        }

        // Em desenvolvimento ou se AWS não está configurado, usar fallback diretamente
        if (process.env.NODE_ENV === 'development' || !this.isAWSConfigured()) {
            console.log(`[SecretsManager] Ambiente de desenvolvimento - usando fallback para: ${secretName}`);
            return this.getFallbackFromEnv(secretName);
        }

        try {
            console.log(`[SecretsManager] Buscando secret: ${secretName}`);
            
            const result = await this.secretsManager.getSecretValue({
                SecretId: fullSecretName
            }).promise();

            let secret;
            if ('SecretString' in result) {
                secret = JSON.parse(result.SecretString);
            } else {
                // Binary secret
                secret = Buffer.from(result.SecretBinary, 'base64').toString('ascii');
            }

            // Salvar no cache
            if (useCache) {
                this.cache.set(fullSecretName, secret);
                this.cacheExpiry.set(fullSecretName, Date.now() + this.cacheTTL);
            }

            console.log(`[SecretsManager] Secret carregado: ${secretName}`);
            return secret;

        } catch (error) {
            console.error(`[SecretsManager] Erro ao buscar secret ${secretName}:`, error.message);
            
            // Fallback para variáveis de ambiente
            console.log(`[SecretsManager] Usando fallback para env var: ${secretName}`);
            return this.getFallbackFromEnv(secretName);
        }
    }

    /**
     * Verificar se cache é válido
     * @param {string} secretName - Nome completo do secret
     * @returns {boolean} - Cache válido
     */
    isValidCache(secretName) {
        if (!this.cache.has(secretName)) return false;
        
        const expiry = this.cacheExpiry.get(secretName);
        return expiry && Date.now() < expiry;
    }

    /**
     * Verificar se AWS está configurado
     * @returns {boolean} - AWS configurado
     */
    isAWSConfigured() {
        return process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY;
    }

    /**
     * Fallback para variáveis de ambiente
     * @param {string} secretName - Nome do secret
     * @returns {Object} - Dados do fallback
     */
    getFallbackFromEnv(secretName) {
        const fallbacks = {
            'database': {
                host: process.env.DB_HOST,
                port: process.env.DB_PORT,
                database: process.env.DB_NAME,
                username: process.env.DB_USER,
                password: process.env.DB_PASSWORD,
                url: process.env.DATABASE_URL
            },
            'jwt': {
                secret: process.env.JWT_SECRET,
                refreshSecret: process.env.JWT_REFRESH_SECRET,
                expiresIn: process.env.JWT_EXPIRES_IN || '7d'
            },
            'stripe': {
                secretKey: process.env.STRIPE_SECRET_KEY,
                publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
                webhookSecret: process.env.STRIPE_WEBHOOK_SECRET
            },
            'twilio': {
                accountSid: process.env.TWILIO_ACCOUNT_SID,
                authToken: process.env.TWILIO_AUTH_TOKEN,
                whatsappNumber: process.env.TWILIO_WHATSAPP_NUMBER
            },
            'email': {
                host: process.env.SMTP_HOST,
                port: process.env.SMTP_PORT,
                user: process.env.SMTP_USER,
                password: process.env.SMTP_PASS,
                from: process.env.EMAIL_FROM
            },
            'redis': {
                host: process.env.REDIS_HOST,
                port: process.env.REDIS_PORT,
                password: process.env.REDIS_PASSWORD,
                url: process.env.REDIS_URL
            }
        };

        const fallback = fallbacks[secretName];
        if (!fallback) {
            throw new Error(`Nenhum fallback encontrado para secret: ${secretName}`);
        }

        return fallback;
    }

    /**
     * Buscar credenciais do banco de dados
     * @returns {Promise<Object>} - Database credentials
     */
    async getDatabaseCredentials() {
        return await this.getSecret('database');
    }

    /**
     * Buscar configurações JWT
     * @returns {Promise<Object>} - JWT configuration
     */
    async getJWTConfig() {
        return await this.getSecret('jwt');
    }

    /**
     * Buscar credenciais Stripe
     * @returns {Promise<Object>} - Stripe credentials
     */
    async getStripeCredentials() {
        return await this.getSecret('stripe');
    }

    /**
     * Buscar credenciais Twilio
     * @returns {Promise<Object>} - Twilio credentials
     */
    async getTwilioCredentials() {
        return await this.getSecret('twilio');
    }

    /**
     * Buscar configuração de email
     * @returns {Promise<Object>} - Email configuration
     */
    async getEmailConfig() {
        return await this.getSecret('email');
    }

    /**
     * Buscar configuração Redis
     * @returns {Promise<Object>} - Redis configuration
     */
    async getRedisConfig() {
        return await this.getSecret('redis');
    }

    /**
     * Limpar cache de secrets
     */
    clearCache() {
        this.cache.clear();
        this.cacheExpiry.clear();
        console.log('[SecretsManager] Cache limpo');
    }

    /**
     * Validar se AWS está configurado
     * @returns {boolean} - AWS configurado
     */
    isAWSConfigured() {
        return !!(process.env.AWS_ACCESS_KEY_ID || process.env.AWS_REGION);
    }

    /**
     * Criar secret no AWS (para setup inicial)
     * @param {string} secretName - Nome do secret
     * @param {Object} secretValue - Valor do secret
     * @returns {Promise<boolean>} - Sucesso
     */
    async createSecret(secretName, secretValue) {
        const fullSecretName = `${this.secretPrefix}${secretName}`;
        
        try {
            await this.secretsManager.createSecret({
                Name: fullSecretName,
                SecretString: JSON.stringify(secretValue),
                Description: `SparkNexus ${secretName} credentials`
            }).promise();

            console.log(`[SecretsManager] Secret criado: ${secretName}`);
            return true;

        } catch (error) {
            if (error.code === 'ResourceExistsException') {
                console.log(`[SecretsManager] Secret já existe: ${secretName}`);
                return await this.updateSecret(secretName, secretValue);
            }
            
            console.error(`[SecretsManager] Erro ao criar secret ${secretName}:`, error.message);
            return false;
        }
    }

    /**
     * Atualizar secret no AWS
     * @param {string} secretName - Nome do secret
     * @param {Object} secretValue - Novo valor
     * @returns {Promise<boolean>} - Sucesso
     */
    async updateSecret(secretName, secretValue) {
        const fullSecretName = `${this.secretPrefix}${secretName}`;
        
        try {
            await this.secretsManager.updateSecret({
                SecretId: fullSecretName,
                SecretString: JSON.stringify(secretValue)
            }).promise();

            // Limpar cache para este secret
            this.cache.delete(fullSecretName);
            this.cacheExpiry.delete(fullSecretName);

            console.log(`[SecretsManager] Secret atualizado: ${secretName}`);
            return true;

        } catch (error) {
            console.error(`[SecretsManager] Erro ao atualizar secret ${secretName}:`, error.message);
            return false;
        }
    }

    /**
     * Testar conexão com AWS Secrets Manager
     * @returns {Promise<boolean>} - Conectividade OK
     */
    async testConnection() {
        try {
            // Listar secrets para testar conexão
            await this.secretsManager.listSecrets({
                MaxResults: 1
            }).promise();

            console.log('[SecretsManager] Conexão com AWS OK');
            return true;

        } catch (error) {
            console.error('[SecretsManager] Erro na conexão AWS:', error.message);
            return false;
        }
    }
}

// Exportar instância singleton
const secretsManager = new SecretsManager();

module.exports = secretsManager;