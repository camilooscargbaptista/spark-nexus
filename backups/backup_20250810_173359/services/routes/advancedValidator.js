// Rotas do Validador Avançado
const express = require('express');
const router = express.Router();

let emailValidator;

const initializeValidator = (validator) => {
    emailValidator = validator;
    return router;
};

// Validação completa de um email
router.post('/advanced', async (req, res) => {
    try {
        const { email } = req.body;
        
        if (!email) {
            return res.status(400).json({ error: 'Email é obrigatório' });
        }

        const result = await emailValidator.validate(email, {
            checkMX: true,
            checkDisposable: true,
            useCache: true
        });

        res.json(result);
    } catch (error) {
        console.error('Erro na validação:', error);
        res.status(500).json({ error: 'Erro ao validar email' });
    }
});

// Validação em lote
router.post('/batch', async (req, res) => {
    try {
        const { emails } = req.body;
        
        if (!emails || !Array.isArray(emails)) {
            return res.status(400).json({ error: 'Lista de emails é obrigatória' });
        }

        if (emails.length > 100) {
            return res.status(400).json({ error: 'Máximo de 100 emails por lote' });
        }

        const results = await emailValidator.validateBatch(emails, {
            checkMX: true,
            checkDisposable: true,
            batchSize: 10
        });

        res.json({
            total: emails.length,
            results: results,
            summary: {
                valid: results.filter(r => r.valid).length,
                invalid: results.filter(r => !r.valid).length,
                avgScore: Math.round(results.reduce((acc, r) => acc + r.score, 0) / results.length)
            }
        });
    } catch (error) {
        console.error('Erro na validação em lote:', error);
        res.status(500).json({ error: 'Erro ao validar lote' });
    }
});

// Estatísticas
router.get('/stats', (req, res) => {
    try {
        const stats = emailValidator.getStats();
        res.json(stats);
    } catch (error) {
        res.status(500).json({ error: 'Erro ao buscar estatísticas' });
    }
});

module.exports = { initializeValidator, router };
