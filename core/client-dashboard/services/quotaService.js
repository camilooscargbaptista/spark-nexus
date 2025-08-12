// ================================================
// QuotaService - Gerenciamento de Quotas
// Sistema de controle de limites mensais
// ================================================

const { Pool } = require('pg');
const moment = require('moment');

class QuotaService {
    constructor(dbPool = null, redisClient = null) {
        // Usar pool fornecido ou criar novo
        this.pool = dbPool || new Pool({
            host: process.env.DB_HOST || 'localhost',
            port: process.env.DB_PORT || 5432,
            database: process.env.DB_NAME || 'sparknexus',
            user: process.env.DB_USER || 'sparknexus',
            password: process.env.DB_PASSWORD || 'SparkNexus2024!'
        });

        this.redis = redisClient;
        this.cacheEnabled = !!redisClient;
        this.cacheTTL = 300; // 5 minutos
        this.debug = process.env.DEBUG_QUOTA === 'true';
    }

    async getUserOrganization(userId) {
        try {
            const query = `
                SELECT
                    o.id,
                    o.name,
                    o.slug,
                    o.plan,
                    o.max_validations,
                    o.validations_used,
                    o.last_reset_date,
                    o.billing_cycle_day,
                    om.role
                FROM tenant.organization_members om
                JOIN tenant.organizations o ON o.id = om.organization_id
                WHERE om.user_id = $1
                AND o.is_active = true
                ORDER BY om.joined_at
                LIMIT 1
            `;

            const result = await this.pool.query(query, [userId]);

            if (result.rows.length === 0) {
                this.log('Nenhuma organização encontrada para usuário:', userId);
                return null;
            }

            const org = result.rows[0];
            org.validations_remaining = org.max_validations - org.validations_used;
            org.usage_percentage = Math.round((org.validations_used / org.max_validations) * 100);
            org.next_reset_date = this.calculateNextResetDate(org.billing_cycle_day);

            return org;
        } catch (error) {
            console.error('Erro ao buscar organização do usuário:', error);
            throw error;
        }
    }

    async checkQuota(organizationId, requiredCount = 1) {
        try {
            const query = `
                SELECT
                    max_validations,
                    validations_used,
                    max_validations - validations_used as validations_remaining
                FROM tenant.organizations
                WHERE id = $1
            `;

            const result = await this.pool.query(query, [organizationId]);

            if (result.rows.length === 0) {
                return {
                    allowed: false,
                    remaining: 0,
                    used: 0,
                    limit: 0,
                    message: 'Organização não encontrada'
                };
            }

            const org = result.rows[0];

            return {
                allowed: org.validations_remaining >= requiredCount,
                remaining: org.validations_remaining,
                used: org.validations_used,
                limit: org.max_validations,
                message: org.validations_remaining >= requiredCount
                    ? `${org.validations_remaining} validações disponíveis`
                    : `Limite excedido. Apenas ${org.validations_remaining} validações restantes`
            };
        } catch (error) {
            console.error('Erro ao verificar quota:', error);
            throw error;
        }
    }

    async incrementUsage(organizationId, count = 1) {
        try {
            const query = `
                SELECT * FROM tenant.increment_validation_usage($1, $2)
            `;

            const result = await this.pool.query(query, [organizationId, count]);

            if (result.rows.length === 0) {
                throw new Error('Erro ao incrementar uso');
            }

            const response = result.rows[0];

            if (response.success) {
                this.log(`Incrementado ${count} validações para org ${organizationId}. Restam: ${response.remaining}`);
            }

            return {
                success: response.success,
                remaining: response.remaining,
                message: response.message
            };
        } catch (error) {
            console.error('Erro ao incrementar uso:', error);
            // Se a função não existir, fazer update direto
            if (error.message.includes('increment_validation_usage')) {
                const fallbackQuery = `
                    UPDATE tenant.organizations
                    SET validations_used = validations_used + $2
                    WHERE id = $1
                    RETURNING max_validations - validations_used as remaining
                `;
                const result = await this.pool.query(fallbackQuery, [organizationId, count]);
                return {
                    success: true,
                    remaining: result.rows[0]?.remaining || 0,
                    message: 'Uso incrementado'
                };
            }
            throw error;
        }
    }

    async getQuotaStats(organizationId) {
        try {
            const query = `
                SELECT
                    o.id,
                    o.name,
                    o.plan,
                    o.max_validations,
                    o.validations_used,
                    o.max_validations - o.validations_used as validations_remaining,
                    ROUND((o.validations_used::NUMERIC / NULLIF(o.max_validations, 0)) * 100, 2) as usage_percentage,
                    o.last_reset_date,
                    o.billing_cycle_day
                FROM tenant.organizations o
                WHERE o.id = $1
            `;

            const result = await this.pool.query(query, [organizationId]);

            if (result.rows.length === 0) {
                return null;
            }

            return result.rows[0];
        } catch (error) {
            console.error('Erro ao buscar estatísticas de quota:', error);
            throw error;
        }
    }

    async getUsageHistory(organizationId, months = 12) {
        try {
            const query = `
                SELECT
                    TO_CHAR(month, 'YYYY-MM') as month,
                    TO_CHAR(month, 'Mon YYYY') as month_label,
                    validations_used,
                    max_validations,
                    ROUND((validations_used::NUMERIC / NULLIF(max_validations, 0)) * 100, 2) as usage_percentage
                FROM tenant.quota_history
                WHERE organization_id = $1
                ORDER BY month DESC
                LIMIT $2
            `;

            const result = await this.pool.query(query, [organizationId, months]);
            return result.rows;
        } catch (error) {
            console.error('Erro ao buscar histórico:', error);
            return []; // Retornar array vazio se tabela não existir
        }
    }

    async checkQuotaAlerts(organizationId) {
        try {
            const stats = await this.getQuotaStats(organizationId);

            if (!stats) {
                return { alerts: [] };
            }

            const alerts = [];
            const usagePercent = parseFloat(stats.usage_percentage);

            if (usagePercent >= 100) {
                alerts.push({
                    level: 'critical',
                    message: 'Limite de validações excedido!',
                    action: 'Faça upgrade do plano ou aguarde o próximo reset'
                });
            } else if (usagePercent >= 90) {
                alerts.push({
                    level: 'warning',
                    message: `Atenção! Você já usou ${usagePercent}% da sua quota mensal`,
                    action: 'Considere fazer upgrade do plano'
                });
            } else if (usagePercent >= 75) {
                alerts.push({
                    level: 'info',
                    message: `Você já usou ${usagePercent}% da sua quota mensal`,
                    remaining: stats.validations_remaining
                });
            }

            return {
                alerts
            };
        } catch (error) {
            console.error('Erro ao verificar alertas:', error);
            return { alerts: [] };
        }
    }

    async resetMonthlyQuotas() {
        try {
            const query = `SELECT * FROM tenant.reset_monthly_quotas()`;
            const result = await this.pool.query(query);

            return {
                success: true,
                resetCount: result.rows.length,
                details: result.rows
            };
        } catch (error) {
            console.error('Erro ao resetar quotas:', error);
            // Se função não existir, fazer reset manual
            if (error.message.includes('reset_monthly_quotas')) {
                const fallbackQuery = `
                    UPDATE tenant.organizations
                    SET validations_used = 0, last_reset_date = CURRENT_TIMESTAMP
                    WHERE last_reset_date < date_trunc('month', CURRENT_DATE)
                `;
                await this.pool.query(fallbackQuery);
                return { success: true, resetCount: 0, details: [] };
            }
            throw error;
        }
    }

    calculateNextResetDate(billingCycleDay) {
        const today = moment();
        const currentDay = today.date();

        let nextReset;
        if (billingCycleDay >= currentDay) {
            nextReset = moment().date(billingCycleDay);
        } else {
            nextReset = moment().add(1, 'month').date(billingCycleDay);
        }

        return nextReset.format('YYYY-MM-DD');
    }

    log(message, ...args) {
        if (this.debug) {
            console.log(`[QuotaService] ${message}`, ...args);
        }
    }

    async close() {
        if (this.pool) {
            await this.pool.end();
        }
    }
}

module.exports = QuotaService;
