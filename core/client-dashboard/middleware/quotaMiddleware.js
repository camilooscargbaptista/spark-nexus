// ================================================
// Quota Middleware - Controle de Limites
// ================================================

const QuotaService = require('../services/QuotaService');
const DatabaseService = require('../services/database');

let quotaServiceInstance = null;

const getQuotaService = () => {
    if (!quotaServiceInstance) {
        let dbPool = null;
        let redisClient = null;

        try {
            const db = new DatabaseService();
            dbPool = db.pool;
            redisClient = db.redis;
        } catch (error) {
            console.log('[QuotaMiddleware] Criando novo pool de conexão');
        }

        quotaServiceInstance = new QuotaService(dbPool, redisClient);
    }
    return quotaServiceInstance;
};

const checkQuota = (options = {}) => {
    const {
        count = 1,
        increment = true,
        strict = true,
        source = 'api'
    } = options;

    return async (req, res, next) => {
        try {
            const quotaService = getQuotaService();
            const userId = req.user?.id;

            if (!userId) {
                console.error('[QuotaMiddleware] Usuário não encontrado no request');
                return res.status(401).json({
                    error: 'Usuário não autenticado',
                    code: 'AUTH_REQUIRED'
                });
            }

            const organization = await quotaService.getUserOrganization(userId);

            if (!organization) {
                console.error(`[QuotaMiddleware] Nenhuma organização encontrada para usuário ${userId}`);
                return res.status(403).json({
                    error: 'Você não pertence a nenhuma organização',
                    code: 'NO_ORGANIZATION'
                });
            }

            let actualCount = count;
            if (req.body?.emails && Array.isArray(req.body.emails)) {
                actualCount = req.body.emails.length;
            } else if (req.body?.count && typeof req.body.count === 'number') {
                actualCount = req.body.count;
            }

            const quotaCheck = await quotaService.checkQuota(organization.id, actualCount);

            req.quota = {
                organizationId: organization.id,
                organizationName: organization.name,
                plan: organization.plan,
                limit: quotaCheck.limit,
                used: quotaCheck.used,
                remaining: quotaCheck.remaining,
                requested: actualCount,
                allowed: quotaCheck.allowed,
                willIncrement: increment && quotaCheck.allowed
            };

            res.set({
                'X-RateLimit-Limit': quotaCheck.limit,
                'X-RateLimit-Remaining': quotaCheck.remaining,
                'X-RateLimit-Used': quotaCheck.used,
                'X-Organization-Plan': organization.plan
            });

            if (!quotaCheck.allowed) {
                console.log(`[QuotaMiddleware] Quota excedida para org ${organization.name}: ${quotaCheck.message}`);

                if (!strict) {
                    req.quota.warning = 'Quota excedida mas continuando (modo não-strict)';
                    return next();
                }

                const alerts = await quotaService.checkQuotaAlerts(organization.id);

                return res.status(429).json({
                    error: 'Limite de validações excedido',
                    code: 'QUOTA_EXCEEDED',
                    details: {
                        message: quotaCheck.message,
                        limit: quotaCheck.limit,
                        used: quotaCheck.used,
                        remaining: quotaCheck.remaining,
                        requested: actualCount,
                        plan: organization.plan,
                        nextResetDate: organization.next_reset_date,
                        alerts: alerts.alerts
                    },
                    suggestions: [
                        'Aguarde até o próximo período de faturamento',
                        'Faça upgrade do seu plano para aumentar o limite',
                        'Entre em contato com o suporte para assistência'
                    ]
                });
            }

            if (increment && quotaCheck.allowed) {
                res.on('finish', async () => {
                    if (res.statusCode >= 200 && res.statusCode < 300) {
                        try {
                            const result = await quotaService.incrementUsage(
                                organization.id,
                                actualCount
                            );
                            console.log(`[QuotaMiddleware] Incrementado ${actualCount} validações para org ${organization.name}. Source: ${source}`);
                        } catch (error) {
                            console.error('[QuotaMiddleware] Erro ao incrementar uso:', error);
                        }
                    }
                });
            }

            const alerts = await quotaService.checkQuotaAlerts(organization.id);
            if (alerts.alerts.length > 0) {
                req.quota.alerts = alerts.alerts;

                const criticalAlert = alerts.alerts.find(a => a.level === 'critical');
                if (criticalAlert) {
                    res.set('X-Quota-Alert', criticalAlert.message);
                }
            }

            next();

        } catch (error) {
            console.error('[QuotaMiddleware] Erro:', error);

            if (strict) {
                return res.status(500).json({
                    error: 'Erro ao verificar quota',
                    code: 'QUOTA_CHECK_ERROR'
                });
            } else {
                req.quota = {
                    error: error.message,
                    warning: 'Verificação de quota falhou mas continuando'
                };
                next();
            }
        }
    };
};

const checkQuotaOnly = (options = {}) => {
    return checkQuota({ ...options, increment: false });
};

const getQuotaStats = async (req, res, next) => {
    try {
        const quotaService = getQuotaService();
        const userId = req.user?.id;

        if (!userId) {
            return res.status(401).json({
                error: 'Usuário não autenticado'
            });
        }

        const organization = await quotaService.getUserOrganization(userId);

        if (!organization) {
            return res.status(403).json({
                error: 'Nenhuma organização encontrada'
            });
        }

        const stats = await quotaService.getQuotaStats(organization.id);
        const history = await quotaService.getUsageHistory(organization.id, 6);
        const alerts = await quotaService.checkQuotaAlerts(organization.id);

        res.json({
            organization: {
                id: organization.id,
                name: organization.name,
                plan: organization.plan
            },
            quota: stats,
            history: history,
            alerts: alerts.alerts
        });

    } catch (error) {
        console.error('[QuotaMiddleware] Erro ao buscar stats:', error);
        res.status(500).json({
            error: 'Erro ao buscar estatísticas de quota'
        });
    }
};

const resetQuotas = async (req, res, next) => {
    try {
        if (!req.user?.is_admin) {
            return res.status(403).json({
                error: 'Acesso negado. Apenas administradores.'
            });
        }

        const quotaService = getQuotaService();
        const result = await quotaService.resetMonthlyQuotas();

        res.json({
            success: true,
            message: `Quotas resetadas para ${result.resetCount} organizações`,
            details: result.details
        });

    } catch (error) {
        console.error('[QuotaMiddleware] Erro ao resetar quotas:', error);
        res.status(500).json({
            error: 'Erro ao resetar quotas'
        });
    }
};

module.exports = {
    checkQuota,
    checkQuotaOnly,
    getQuotaStats,
    resetQuotas,
    quotaForSingle: checkQuota({ count: 1, source: 'single' }),
    quotaForBatch: checkQuota({ source: 'batch' }),
    quotaForUpload: checkQuota({ source: 'upload' }),
    quotaForAPI: checkQuota({ source: 'api' }),
    quotaSoftCheck: checkQuota({ strict: false }),
    getQuotaService
};
