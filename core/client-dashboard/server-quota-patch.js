// ================================================
// PATCH: Sistema de Quota - Adicionar após os requires existentes
// ================================================

// Importar middleware de quota
const {
    checkQuota,
    quotaForSingle,
    quotaForBatch,
    quotaForUpload,
    getQuotaStats,
    resetQuotas,
    getQuotaService
} = require('./middleware/quotaMiddleware');

// Importar QuotaService diretamente se necessário
const QuotaService = require('./services/QuotaService');

// ================================================
// ENDPOINTS DE QUOTA (adicionar após /api/auth/verify)
// ================================================

// Obter estatísticas de quota do usuário
app.get('/api/user/quota', authenticateToken, getQuotaStats);

// Obter informações de quota simplificadas
app.get('/api/user/quota/summary', authenticateToken, async (req, res) => {
    try {
        const quotaService = getQuotaService();
        const userId = req.user.id;

        const organization = await quotaService.getUserOrganization(userId);
        if (!organization) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        const quota = await quotaService.checkQuota(organization.id);
        const alerts = await quotaService.checkQuotaAlerts(organization.id);

        res.json({
            organization: organization.name,
            plan: organization.plan,
            used: quota.used,
            limit: quota.limit,
            remaining: quota.remaining,
            percentage: Math.round((quota.used / quota.limit) * 100),
            nextReset: organization.next_reset_date,
            alerts: alerts.alerts.filter(a => a.level !== 'info')
        });
    } catch (error) {
        console.error('Erro ao buscar resumo de quota:', error);
        res.status(500).json({ error: 'Erro ao buscar informações de quota' });
    }
});

// Reset manual de quotas (admin only)
app.post('/api/admin/quota/reset', authenticateToken, resetQuotas);

// Histórico de uso de quota
app.get('/api/user/quota/history', authenticateToken, async (req, res) => {
    try {
        const quotaService = getQuotaService();
        const userId = req.user.id;
        const months = parseInt(req.query.months) || 6;

        const organization = await quotaService.getUserOrganization(userId);
        if (!organization) {
            return res.status(404).json({ error: 'Organização não encontrada' });
        }

        const history = await quotaService.getUsageHistory(organization.id, months);

        res.json({
            organization: organization.name,
            history: history
        });
    } catch (error) {
        console.error('Erro ao buscar histórico:', error);
        res.status(500).json({ error: 'Erro ao buscar histórico' });
    }
});

// ================================================
// MODIFICAÇÕES NOS ENDPOINTS EXISTENTES
// ================================================

// NOTA: Os seguintes endpoints precisam ser modificados manualmente:
// 1. /api/validate/single - Adicionar quotaForSingle após authenticateToken
// 2. /api/validate/batch - Adicionar quotaForBatch após authenticateToken
// 3. /api/validate/advanced - Adicionar quotaForSingle após authenticateToken
// 4. /api/upload - Adicionar checkQuota customizado após processar arquivo
// 5. /api/validate/batch-with-report - Adicionar quotaForBatch após authenticateToken

// Exemplo de como deve ficar:
/*
app.post('/api/validate/single',
    authenticateToken,
    quotaForSingle,  // <-- ADICIONAR ESTA LINHA
    [
        body('email').isEmail().withMessage('Email inválido')
    ],
    async (req, res) => {
        // código existente...
    }
);
*/

