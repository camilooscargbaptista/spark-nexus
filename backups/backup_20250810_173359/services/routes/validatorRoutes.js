// Stub temporário para validatorRoutes
const express = require('express');
const router = express.Router();

const initializeValidator = (validator) => {
    return router;
};

// Rota temporária
router.get('/health', (req, res) => {
    res.json({ status: 'ok', message: 'Validator routes stub' });
});

module.exports = { initializeValidator, router };
