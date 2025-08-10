// ================================================
// Serviço de Banco de Dados PostgreSQL
// ================================================

const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

class DatabaseService {
    constructor() {
        // Configurar PostgreSQL
        console.log('process.env.DATABASE_URL --> ', process.env.DATABASE_URL)
        this.pool = new Pool({
            connectionString: process.env.DATABASE_URL || 'postgresql://sparknexus:SparkNexus2024!@postgres:5432/sparknexus',
            ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
        });

        // Redis desabilitado temporariamente
        this.redis = { 
            isOpen: false,
            get: async () => null,
            set: async () => null,
            setEx: async () => null,
            del: async () => null,
            quit: async () => null
        };
        
        this.setupRedis();
    }

    async setupRedis() {
        try {
            const Redis = require('redis');
            this.redis = Redis.createClient({
                url: process.env.REDIS_URL || 'redis://redis:6379',
                password: process.env.REDIS_PASSWORD || 'SparkNexus2024!',
                socket: {
                    reconnectStrategy: (retries) => {
                        if (retries > 10) {
                            console.log('⚠️ Redis: desistindo após 10 tentativas');
                            return new Error('Redis connection failed');
                        }
                        return Math.min(retries * 100, 3000);
                    }
                }
            });

            this.redis.on('error', (err) => {
                console.error('Redis Client Error:', err);
                // isOpen é readonly
            });

            this.redis.on('connect', () => {
                console.log('✅ Redis conectado com sucesso');
                // isOpen é readonly
            });

            await this.redis.connect();
        } catch (error) {
            console.warn('⚠️ Redis não disponível:', error.message);
            // Manter fallback para operação sem Redis
            this.redis = {
                isOpen: false,
                get: async () => null,
                set: async () => null,
                setEx: async () => null,
                del: async () => null,
                quit: async () => null
            };
        }
    }

    // ================================================
    // USUÁRIOS
    // ================================================

    // Criar usuário
    async createUser(userData) {
      console.log('connectionString ---:', this.pool)
        const client = await this.pool.connect();

        try {
            await client.query('BEGIN');

            // Hash da senha
            const passwordHash = await bcrypt.hash(userData.password, 10);

            // Inserir usuário
            const query = `
                INSERT INTO auth.users (
                    email, password_hash, first_name, last_name,
                    cpf_cnpj, phone, company,
                    email_verification_token, phone_verification_token,
                    email_token_expires, phone_token_expires
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                RETURNING id, email, first_name, last_name, company
            `;

            const tokenExpiry = new Date();
            tokenExpiry.setMinutes(tokenExpiry.getMinutes() + 30);

            const phoneTokenExpiry = new Date();
            phoneTokenExpiry.setMinutes(phoneTokenExpiry.getMinutes() + 10);

            const result = await client.query(query, [
                userData.email.toLowerCase(),
                passwordHash,
                userData.firstName,
                userData.lastName,
                userData.cpfCnpj,
                userData.phone,
                userData.company,
                userData.emailToken,
                userData.phoneToken,
                tokenExpiry,
                phoneTokenExpiry
            ]);

            // Criar organização para o usuário
            const orgQuery = `
                INSERT INTO tenant.organizations (name, slug, cnpj)
                VALUES ($1, $2, $3)
                RETURNING id
            `;

            const slug = userData.company.toLowerCase()
                .replace(/[^\w\s-]/g, '')
                .replace(/\s+/g, '-');

            const orgResult = await client.query(orgQuery, [
                userData.company,
                slug + '-' + Date.now(),
                userData.cpfCnpj.length === 14 ? userData.cpfCnpj : null
            ]);

            // Associar usuário à organização
            await client.query(
                `INSERT INTO tenant.organization_members (organization_id, user_id, role)
                 VALUES ($1, $2, 'owner')`,
                [orgResult.rows[0].id, result.rows[0].id]
            );

            await client.query('COMMIT');

            return {
                success: true,
                user: result.rows[0],
                organizationId: orgResult.rows[0].id
            };
        } catch (error) {
            await client.query('ROLLBACK');
            console.error('Erro ao criar usuário:', error);

            if (error.code === '23505') {
                if (error.constraint === 'users_email_key') {
                    throw new Error('Email já cadastrado');
                }
                if (error.constraint === 'users_cpf_cnpj_key') {
                    throw new Error('CPF/CNPJ já cadastrado');
                }
            }

            throw error;
        } finally {
            client.release();
        }
    }

    // Buscar usuário por email
    async getUserByEmail(email) {
        const query = `
            SELECT id, email, password_hash, first_name, last_name,
                   cpf_cnpj, phone, company, email_verified, phone_verified
            FROM auth.users
            WHERE email = $1
        `;

        const result = await this.pool.query(query, [email.toLowerCase()]);
        console.log('result: ', result.rows)
        return result.rows[0];
    }

    // Verificar email
    async verifyEmail(token) {
        const query = `
            UPDATE auth.users
            SET email_verified = true,
                email_verification_token = NULL,
                email_token_expires = NULL
            WHERE email_verification_token = $1
                AND email_token_expires > NOW()
            RETURNING id, email, first_name
        `;

        const result = await this.pool.query(query, [token]);
        return result.rows[0];
    }

    // Verificar telefone
    async verifyPhone(userId, token) {
        const query = `
            UPDATE auth.users
            SET phone_verified = true,
                phone_verification_token = NULL,
                phone_token_expires = NULL
            WHERE id = $1
                AND phone_verification_token = $2
                AND phone_token_expires > NOW()
            RETURNING id, phone
        `;

        const result = await this.pool.query(query, [userId, token]);
        return result.rows[0];
    }

    // Criar sessão
    async createSession(userId, token, ipAddress, userAgent) {
        const expires = new Date();
        expires.setHours(expires.getHours() + 24);

        const query = `
            INSERT INTO auth.sessions (user_id, token, ip_address, user_agent, expires_at)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id
        `;

        const result = await this.pool.query(query, [
            userId, token, ipAddress, userAgent, expires
        ]);

        return result.rows[0];
    }

    // Validar sessão
    async validateSession(token) {
        // Se não tem Redis, ir direto ao banco
        const query = `
            SELECT s.*, u.email, u.first_name, u.last_name
            FROM auth.sessions s
            JOIN auth.users u ON s.user_id = u.id
            WHERE s.token = $1 AND s.expires_at > NOW()
        `;

        const result = await this.pool.query(query, [token]);
        return result.rows[0];
    }

    // Registrar tentativa de login
    async logLoginAttempt(email, ipAddress, success) {
        const query = `
            INSERT INTO auth.login_attempts (email, ip_address, success)
            VALUES ($1, $2, $3)
        `;

        await this.pool.query(query, [email, ipAddress, success]);
    }

    // Verificar tentativas de login
    async checkLoginAttempts(email, ipAddress) {
        const query = `
            SELECT COUNT(*) as attempts
            FROM auth.login_attempts
            WHERE (email = $1 OR ip_address = $2)
                AND success = false
                AND attempted_at > NOW() - INTERVAL '15 minutes'
        `;

        const result = await this.pool.query(query, [email, ipAddress]);
        return parseInt(result.rows[0].attempts);
    }

    // Limpar dados expirados
    async cleanupExpiredData() {
        // Limpar sessões expiradas
        await this.pool.query(
            `DELETE FROM auth.sessions WHERE expires_at < NOW()`
        );

        // Limpar tokens de verificação expirados
        await this.pool.query(`
            UPDATE auth.users
            SET email_verification_token = NULL
            WHERE email_token_expires < NOW() AND email_verification_token IS NOT NULL
        `);

        await this.pool.query(`
            UPDATE auth.users
            SET phone_verification_token = NULL
            WHERE phone_token_expires < NOW() AND phone_verification_token IS NOT NULL
        `);
    }
}

module.exports = DatabaseService;
