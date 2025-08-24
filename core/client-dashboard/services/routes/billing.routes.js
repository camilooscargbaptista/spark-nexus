// core/client-dashboard/services/routes/billing.routes.js

const express = require('express');
const router = express.Router();

// Importar a classe DatabaseService
const DatabaseService = require('../database');

// Criar uma instância do DatabaseService
const dbService = new DatabaseService();

// Pegar o pool da instância
const pool = dbService.pool;

// ================================================
// MIDDLEWARE DE AUTENTICAÇÃO
// ================================================
const authMiddleware = (req, res, next) => {
    // Por enquanto, vamos simular um usuário autenticado
    // Em produção, isso deve verificar JWT token
    req.user = {
        id: 1,
        organizationId: req.headers['x-organization-id'] || 1
    };
    next();
};

// ================================================
// GET /api/billing/plans - Listar todos os planos disponíveis
// ================================================
router.get('/plans', async (req, res) => {
    try {
        const { type, period } = req.query;

        let query = `
            SELECT
                id,
                plan_key,
                name,
                type,
                period,
                emails_limit,
                price,
                original_price,
                price_per_month,
                price_per_email,
                discount_percentage,
                savings_amount,
                features,
                is_popular,
                display_order
            FROM billing.plans
            WHERE is_active = true
        `;

        const params = [];

        if (type) {
            params.push(type);
            query += ` AND type = $${params.length}`;
        }

        if (period) {
            params.push(period);
            query += ` AND period = $${params.length}`;
        }

        query += ' ORDER BY display_order';

        const result = await pool.query(query, params);

        // Agrupar por tipo para facilitar o frontend
        const grouped = {
            oneTime: [],
            monthly: [],
            yearly: []
        };

        result.rows.forEach(plan => {
            if (plan.type === 'one_time') {
                grouped.oneTime.push(plan);
            } else if (plan.period === 'monthly') {
                grouped.monthly.push(plan);
            } else if (plan.period === 'yearly') {
                grouped.yearly.push(plan);
            }
        });

        res.json({
            success: true,
            data: grouped,
            total: result.rows.length
        });

    } catch (error) {
        console.error('Erro ao buscar planos:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar planos'
        });
    }
});

// ================================================
// GET /api/billing/plans/:planKey - Detalhes de um plano específico
// ================================================
router.get('/plans/:planKey', async (req, res) => {
    try {
        const { planKey } = req.params;

        const query = `
            SELECT
                p.*,
                CASE
                    WHEN p.period = 'yearly' THEN
                        (SELECT price FROM billing.plans
                         WHERE plan_key = REPLACE(p.plan_key, 'yearly_', 'monthly_'))
                    ELSE NULL
                END as monthly_equivalent_price
            FROM billing.plans p
            WHERE p.plan_key = $1 AND p.is_active = true
        `;

        const result = await pool.query(query, [planKey]);

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Plano não encontrado'
            });
        }

        res.json({
            success: true,
            data: result.rows[0]
        });

    } catch (error) {
        console.error('Erro ao buscar plano:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar detalhes do plano'
        });
    }
});

// ================================================
// GET /api/billing/best-plan - Encontrar melhor plano para quantidade de emails
// ================================================
router.get('/best-plan', async (req, res) => {
    try {
        const { emails, period = 'monthly' } = req.query;

        if (!emails) {
            return res.status(400).json({
                success: false,
                error: 'Quantidade de emails é obrigatória'
            });
        }

        const query = `
            SELECT * FROM billing.get_best_plan($1, $2)
        `;

        const result = await pool.query(query, [parseInt(emails), period]);

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Nenhum plano adequado encontrado'
            });
        }

        res.json({
            success: true,
            data: result.rows[0]
        });

    } catch (error) {
        console.error('Erro ao buscar melhor plano:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar melhor plano'
        });
    }
});

// ================================================
// GET /api/billing/subscription/current - Assinatura atual da organização
// ================================================
router.get('/subscription/current', authMiddleware, async (req, res) => {
    try {
        const { organizationId } = req.user;

        const query = `
            SELECT
                s.*,
                p.name as plan_name,
                p.emails_limit,
                p.price as plan_price,
                p.period,
                p.features
            FROM billing.subscriptions s
            JOIN billing.plans p ON s.plan_id = p.id
            WHERE s.organization_id = $1
            AND s.status = 'active'
            ORDER BY s.created_at DESC
            LIMIT 1
        `;

        const result = await pool.query(query, [organizationId]);

        if (result.rows.length === 0) {
            return res.json({
                success: true,
                data: null,
                message: 'Nenhuma assinatura ativa'
            });
        }

        res.json({
            success: true,
            data: result.rows[0]
        });

    } catch (error) {
        console.error('Erro ao buscar assinatura:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar assinatura atual'
        });
    }
});

// ================================================
// GET /api/billing/usage/current - Uso atual do mês
// ================================================
router.get('/usage/current', authMiddleware, async (req, res) => {
    try {
        const { organizationId } = req.user;

        const query = `
            SELECT
                o.max_validations,
                o.validations_used,
                o.max_validations - o.validations_used as remaining,
                ROUND((o.validations_used::NUMERIC / NULLIF(o.max_validations, 0)) * 100, 2) as usage_percentage,
                o.last_reset_date,
                o.plan
            FROM tenant.organizations o
            WHERE o.id = $1
        `;

        const result = await pool.query(query, [organizationId]);

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Organização não encontrada'
            });
        }

        res.json({
            success: true,
            data: result.rows[0]
        });

    } catch (error) {
        console.error('Erro ao buscar uso:', error);
        res.status(500).json({
            success: false,
            error: 'Erro ao buscar uso atual'
        });
    }
});

module.exports = router;
