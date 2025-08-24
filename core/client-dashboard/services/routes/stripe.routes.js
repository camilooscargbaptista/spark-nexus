// core/client-dashboard/services/routes/stripe.routes.js

const express = require('express');
const router = express.Router();
const stripeService = require('../payment/stripe.service');
const DatabaseService = require('../database');

// Middleware de autenticação (importado do server principal)
const jwt = require('jsonwebtoken');
const authenticateToken = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ error: 'Token não fornecido' });
    }
    
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;
        next();
    } catch (error) {
        return res.status(403).json({ error: 'Token inválido' });
    }
};

// Função auxiliar para buscar organizationId do usuário
const getUserOrganizationId = async (userId) => {
    try {
        const dbService = new DatabaseService();
        const result = await dbService.pool.query(
            `SELECT organization_id
             FROM tenant.organization_members
             WHERE user_id = $1
             ORDER BY joined_at DESC
             LIMIT 1`,
            [userId]
        );
        
        return result.rows.length > 0 ? result.rows[0].organization_id : null;
    } catch (error) {
        console.error('Erro ao buscar organizationId:', error);
        return null;
    }
};

// ================================================
// MIDDLEWARE DE LOG (para debug)
// ================================================
const logRequest = (req, res, next) => {
    console.log(`📦 [${new Date().toISOString()}] ${req.method} ${req.path}`);
    console.log('Headers:', req.headers);
    console.log('Body:', req.body);
    next();
};

// ================================================
// GET /api/stripe/test - Rota de teste
// ================================================
router.get('/test', (req, res) => {
    res.json({
        status: 'ok',
        message: '✅ Stripe API funcionando!',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development'
    });
});

// ================================================
// POST /api/stripe/create-checkout - Criar sessão de checkout
// ================================================
router.post('/create-checkout', authenticateToken, logRequest, async (req, res) => {
    try {
        console.log('🛒 Criando sessão de checkout...');

        const {
            planId,
            planKey,
            type,
            organizationId,
            userEmail,
            customerData,
            successUrl,
            cancelUrl
        } = req.body;

        // Obter organizationId - primeiro do body, depois buscar no banco via userId
        let orgId = organizationId;
        if (!orgId && req.user) {
            orgId = await getUserOrganizationId(req.user.id);
        }

        // Validação básica
        if (!orgId) {
            return res.status(400).json({
                success: false,
                error: 'Usuário não possui organização associada'
            });
        }

        if (!planKey) {
            return res.status(400).json({
                success: false,
                error: 'planKey é obrigatório'
            });
        }

        console.log(`📋 Plano selecionado: ${planKey} para org: ${orgId}`);

        const result = await stripeService.createCheckoutSession({
            organizationId: orgId,
            planKey,
            userEmail: userEmail || customerData?.email || 'cliente@exemplo.com',
            customerData: customerData || {
                email: userEmail || 'cliente@exemplo.com',
                name: 'Cliente SparkNexus',
                company: 'SparkNexus'
            },
            successUrl: successUrl || `${req.protocol}://${req.get('host')}/payment/success?session_id={CHECKOUT_SESSION_ID}`,
            cancelUrl: cancelUrl || `${req.protocol}://${req.get('host')}/payment/cancel`
        });

        console.log('✅ Sessão criada com sucesso:', result.sessionId);

        res.json({
            success: true,
            ...result
        });

    } catch (error) {
        console.error('❌ Erro ao criar checkout:', error);
        res.status(500).json({
            success: false,
            error: error.message || 'Erro ao criar sessão de checkout',
            details: process.env.NODE_ENV === 'development' ? error.stack : undefined
        });
    }
});

// ================================================
// POST /api/stripe/create-checkout-session - Alias para criar sessão de checkout
// ================================================
router.post('/create-checkout-session', authenticateToken, logRequest, async (req, res) => {
    try {
        console.log('🛒 Criando sessão de checkout (via alias)...');

        const {
            planId,
            planKey,
            type,
            organizationId,
            userEmail,
            customerData,
            successUrl,
            cancelUrl
        } = req.body;

        // Obter organizationId - primeiro do body, depois buscar no banco via userId
        let orgId = organizationId;
        if (!orgId && req.user) {
            orgId = await getUserOrganizationId(req.user.id);
        }

        // Validação básica
        if (!orgId) {
            return res.status(400).json({
                success: false,
                error: 'Usuário não possui organização associada'
            });
        }

        if (!planKey) {
            return res.status(400).json({
                success: false,
                error: 'planKey é obrigatório'
            });
        }

        console.log(`📋 Plano selecionado: ${planKey} para org: ${orgId}`);

        const result = await stripeService.createCheckoutSession({
            organizationId: orgId,
            planKey,
            userEmail: userEmail || customerData?.email || 'cliente@exemplo.com',
            customerData: customerData || {
                email: userEmail || 'cliente@exemplo.com',
                name: 'Cliente SparkNexus',
                company: 'SparkNexus'
            },
            successUrl: successUrl || `${req.protocol}://${req.get('host')}/payment/success?session_id={CHECKOUT_SESSION_ID}`,
            cancelUrl: cancelUrl || `${req.protocol}://${req.get('host')}/payment/cancel`
        });

        console.log('✅ Sessão criada com sucesso:', result.sessionId);

        res.json({
            success: true,
            ...result
        });

    } catch (error) {
        console.error('❌ Erro ao criar checkout:', error);
        res.status(500).json({
            success: false,
            error: error.message || 'Erro ao criar sessão de checkout',
            details: process.env.NODE_ENV === 'development' ? error.stack : undefined
        });
    }
});

// ================================================
// POST /api/stripe/webhook - Webhook do Stripe
// ================================================
router.post('/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
    try {
        console.log('🔔 Webhook recebido do Stripe');

        const signature = req.headers['stripe-signature'];

        if (!signature) {
            console.error('❌ Assinatura do webhook ausente');
            return res.status(400).json({
                error: 'Assinatura do webhook ausente'
            });
        }

        const result = await stripeService.handleWebhook(req.body, signature);

        console.log('✅ Webhook processado com sucesso');
        res.json({ received: true, ...result });

    } catch (error) {
        console.error('❌ Erro no webhook:', error);

        // Stripe espera que retornemos 200 mesmo com erro
        // para evitar reenvios desnecessários
        if (error.type === 'StripeSignatureVerificationError') {
            return res.status(400).json({
                error: 'Assinatura inválida',
                received: false
            });
        }

        res.status(200).json({
            error: error.message,
            received: true // Marcamos como recebido para evitar retry
        });
    }
});

// ================================================
// POST /api/stripe/customer-portal - Portal do cliente
// ================================================
router.post('/customer-portal', logRequest, async (req, res) => {
    try {
        console.log('🚪 Criando portal do cliente...');

        const { organizationId } = req.body;

        if (!organizationId) {
            return res.status(400).json({
                success: false,
                error: 'organizationId é obrigatório'
            });
        }

        const result = await stripeService.createCustomerPortal(organizationId);

        console.log('✅ Portal criado:', result.portalUrl);
        res.json(result);

    } catch (error) {
        console.error('❌ Erro ao criar portal:', error);
        res.status(500).json({
            success: false,
            error: error.message || 'Erro ao criar portal do cliente'
        });
    }
});

// ================================================
// GET /api/stripe/payment-methods/:organizationId - Listar métodos de pagamento
// ================================================
router.get('/payment-methods/:organizationId', async (req, res) => {
    try {
        console.log('💳 Listando métodos de pagamento...');

        const { organizationId } = req.params;

        const methods = await stripeService.listPaymentMethods(organizationId);

        res.json({
            success: true,
            data: methods
        });

    } catch (error) {
        console.error('❌ Erro ao listar métodos:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ================================================
// GET /api/stripe/session/:sessionId - Verificar status da sessão
// ================================================
router.get('/session/:sessionId', async (req, res) => {
    try {
        const { sessionId } = req.params;

        // Importar stripe diretamente
        const { stripe } = require('../payment/stripe.config');

        const session = await stripe.checkout.sessions.retrieve(sessionId);

        res.json({
            success: true,
            data: {
                id: session.id,
                status: session.status,
                payment_status: session.payment_status,
                amount_total: session.amount_total,
                currency: session.currency,
                customer_email: session.customer_details?.email,
                planName: session.metadata?.plan_key
            }
        });

    } catch (error) {
        console.error('❌ Erro ao buscar sessão:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ================================================
// POST /api/stripe/cancel-subscription - Cancelar assinatura
// ================================================
router.post('/cancel-subscription', logRequest, async (req, res) => {
    try {
        console.log('🚫 Cancelando assinatura...');

        const { subscriptionId, organizationId } = req.body;

        if (!subscriptionId || !organizationId) {
            return res.status(400).json({
                success: false,
                error: 'subscriptionId e organizationId são obrigatórios'
            });
        }

        // Importar stripe
        const { stripe } = require('../payment/stripe.config');

        // Cancelar no Stripe
        const subscription = await stripe.subscriptions.update(subscriptionId, {
            cancel_at_period_end: true // Cancela no fim do período pago
        });

        // Atualizar no banco
        const DatabaseService = require('../database');
        const dbService = new DatabaseService();
        const pool = dbService.pool;

        await pool.query(
            `UPDATE billing.subscriptions
             SET status = 'canceling',
                 cancel_at_period_end = true,
                 updated_at = CURRENT_TIMESTAMP
             WHERE stripe_subscription_id = $1
             AND organization_id = $2`,
            [subscriptionId, organizationId]
        );

        console.log('✅ Assinatura marcada para cancelamento');

        res.json({
            success: true,
            message: 'Assinatura será cancelada no fim do período atual',
            cancelAt: subscription.cancel_at
        });

    } catch (error) {
        console.error('❌ Erro ao cancelar assinatura:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ================================================
// GET /api/stripe/prices - Listar todos os preços/produtos
// ================================================
router.get('/prices', async (req, res) => {
    try {
        const { stripe } = require('../payment/stripe.config');

        // Buscar todos os preços ativos
        const prices = await stripe.prices.list({
            active: true,
            expand: ['data.product'],
            limit: 100
        });

        // Formatar resposta
        const formattedPrices = prices.data.map(price => ({
            id: price.id,
            productId: price.product.id,
            productName: price.product.name,
            unitAmount: price.unit_amount,
            currency: price.currency,
            interval: price.recurring?.interval,
            intervalCount: price.recurring?.interval_count,
            type: price.type,
            metadata: price.product.metadata
        }));

        res.json({
            success: true,
            data: formattedPrices
        });

    } catch (error) {
        console.error('❌ Erro ao listar preços:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ================================================
// POST /api/stripe/simulate-webhook - Simular webhook (APENAS DEV)
// ================================================
if (process.env.NODE_ENV === 'development') {
    router.post('/simulate-webhook', async (req, res) => {
        try {
            console.log('🧪 Simulando webhook...');

            const { eventType, data } = req.body;

            // Criar evento fake
            const fakeEvent = {
                type: eventType || 'checkout.session.completed',
                data: {
                    object: data || {
                        id: 'cs_test_simulated',
                        mode: 'payment',
                        metadata: {
                            organization_id: '1',
                            plan_id: '1',
                            plan_key: 'onetime_1k'
                        },
                        customer: 'cus_test_simulated',
                        amount_total: 4999,
                        currency: 'brl',
                        payment_status: 'paid',
                        status: 'complete'
                    }
                }
            };

            // Processar direto sem verificar assinatura
            const result = await stripeService.handleWebhook(
                JSON.stringify(fakeEvent),
                'simulated_signature'
            );

            console.log('✅ Webhook simulado processado');
            res.json({
                success: true,
                message: 'Webhook simulado com sucesso',
                result
            });

        } catch (error) {
            console.error('❌ Erro na simulação:', error);
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    });
}

// ================================================
// HEALTH CHECK
// ================================================
router.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        service: 'stripe-routes',
        timestamp: new Date().toISOString()
    });
});

module.exports = router;
