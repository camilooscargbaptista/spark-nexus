// core/client-dashboard/services/payment/stripe.service.js

const { stripe, STRIPE_PRODUCTS } = require('./stripe.config');

// Importar a classe DatabaseService
const DatabaseService = require('../database');

// Criar uma instância do DatabaseService
const dbService = new DatabaseService();

// Pegar o pool da instância
const pool = dbService.pool;

class StripePaymentService {

    // ================================================
    // CRIAR OU OBTER CLIENTE NO STRIPE
    // ================================================
    async createOrGetCustomer(organizationData) {
        try {
            console.log('🔍 Criando/obtendo cliente Stripe para org:', organizationData.id);

            // Verificar se já existe customer_id
            if (organizationData.stripe_customer_id) {
                console.log('✅ Cliente já existe:', organizationData.stripe_customer_id);
                return await stripe.customers.retrieve(organizationData.stripe_customer_id);
            }

            // Criar novo cliente no Stripe
            console.log('📝 Criando novo cliente no Stripe...');
            const customer = await stripe.customers.create({
                email: organizationData.email,
                name: organizationData.name,
                metadata: {
                    organization_id: organizationData.id,
                    organization_slug: organizationData.slug
                },
                preferred_locales: ['pt-BR'],
                tax_exempt: 'none',
                address: {
                    country: 'BR'
                }
            });

            console.log('✅ Cliente criado no Stripe:', customer.id);

            // Salvar customer_id no banco
            await pool.query(
                `UPDATE tenant.organizations
                 SET stripe_customer_id = $1, updated_at = CURRENT_TIMESTAMP
                 WHERE id = $2`,
                [customer.id, organizationData.id]
            );

            console.log('✅ Customer ID salvo no banco');
            return customer;

        } catch (error) {
            console.error('❌ Erro ao criar/obter cliente Stripe:', error);
            throw error;
        }
    }

    // ================================================
    // CRIAR SESSÃO DE CHECKOUT (PARA NOVAS ASSINATURAS)
    // ================================================
    async createCheckoutSession(options) {
        const {
            organizationId,
            planKey,
            successUrl,
            cancelUrl,
            userEmail,
            customerData
        } = options;

        try {
            console.log('🛒 Criando sessão de checkout...');
            console.log('   Organização:', organizationId);
            console.log('   Plano:', planKey);

            // Buscar dados da organização
            const orgResult = await pool.query(
                'SELECT * FROM tenant.organizations WHERE id = $1',
                [organizationId]
            );

            if (orgResult.rows.length === 0) {
                throw new Error('Organização não encontrada');
            }

            const organization = orgResult.rows[0];

            // Buscar plano no banco
            const planResult = await pool.query(
                'SELECT * FROM billing.plans WHERE plan_key = $1 AND is_active = true',
                [planKey]
            );

            if (planResult.rows.length === 0) {
                throw new Error('Plano não encontrado');
            }

            const plan = planResult.rows[0];
            console.log('✅ Plano encontrado:', plan.name);

            // Criar ou obter cliente com dados corretos
            const customerInfo = {
                ...organization,
                email: customerData?.email || userEmail || organization.email,
                name: customerData?.name || organization.name,
                company: customerData?.company || organization.name,
                phone: customerData?.phone || organization.phone,
                cpf_cnpj: customerData?.cpf_cnpj || organization.cpf_cnpj
            };
            
            console.log('👤 Dados do cliente para Stripe:', {
                email: customerInfo.email,
                name: customerInfo.name,
                company: customerInfo.company
            });
            
            const customer = await this.createOrGetCustomer(customerInfo);

            // Verificar se o plano está mapeado no Stripe
            const stripeProduct = STRIPE_PRODUCTS[planKey];
            if (!stripeProduct) {
                throw new Error('Plano não configurado no Stripe');
            }

            // Configurar sessão baseada no tipo de plano
            const sessionConfig = {
                payment_method_types: ['card'],
                customer: customer.id,
                success_url: successUrl || 'http://localhost:4201/payment/success?session_id={CHECKOUT_SESSION_ID}',
                cancel_url: cancelUrl || 'http://localhost:4201/payment/cancel',
                locale: 'pt-BR',
                metadata: {
                    organization_id: organizationId.toString(),
                    plan_key: planKey,
                    plan_id: plan.id.toString()
                }
            };

            if (plan.type === 'subscription') {
                // Configuração para assinatura
                sessionConfig.mode = 'subscription';
                sessionConfig.line_items = [{
                    price: stripeProduct.priceId,
                    quantity: 1
                }];
                sessionConfig.subscription_data = {
                    metadata: {
                        organization_id: organizationId.toString(),
                        plan_key: planKey,
                        plan_id: plan.id.toString()
                    }
                };

                // Adicionar trial se for primeiro plano
                const hasSubscription = await this.checkExistingSubscription(organizationId);
                if (!hasSubscription) {
                    sessionConfig.subscription_data.trial_period_days = 7; // 7 dias grátis
                    console.log('📅 Adicionando 7 dias de trial');
                }

            } else {
                // Configuração para pagamento único
                sessionConfig.mode = 'payment';
                sessionConfig.line_items = [{
                    price: stripeProduct.priceId,
                    quantity: 1
                }];
                sessionConfig.payment_intent_data = {
                    metadata: {
                        organization_id: organizationId.toString(),
                        plan_key: planKey,
                        plan_id: plan.id.toString()
                    }
                };
            }

            console.log('📤 Criando sessão no Stripe...');
            // Criar sessão
            const session = await stripe.checkout.sessions.create(sessionConfig);

            console.log('✅ Sessão criada:', session.id);

            // Salvar sessão pendente no banco
            await pool.query(
                `INSERT INTO billing.pending_checkouts
                 (organization_id, plan_id, stripe_session_id, status, created_at)
                 VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)`,
                [organizationId, plan.id, session.id, 'pending']
            );

            console.log('✅ Checkout pendente salvo no banco');

            return {
                success: true,
                sessionId: session.id,
                checkoutUrl: session.url
            };

        } catch (error) {
            console.error('❌ Erro ao criar sessão de checkout:', error);
            throw error;
        }
    }

    // ================================================
    // PROCESSAR WEBHOOK DO STRIPE
    // ================================================
    async handleWebhook(rawBody, signature) {
        const { STRIPE_WEBHOOK_SECRET } = require('./stripe.config');

        try {
            console.log('🔔 WEBHOOK RECEBIDO!');
            console.log('   Signature presente:', !!signature);
            console.log('   Secret configurado:', !!STRIPE_WEBHOOK_SECRET);

            let event;

            // Em desenvolvimento, aceitar webhooks sem verificação rigorosa
            if (process.env.NODE_ENV === 'development') {
                console.log('⚠️  Modo desenvolvimento - verificação flexível');

                try {
                    // Tentar verificar normalmente
                    event = stripe.webhooks.constructEvent(
                        rawBody,
                        signature,
                        STRIPE_WEBHOOK_SECRET
                    );
                } catch (err) {
                    console.log('⚠️  Verificação falhou, processando sem verificação:', err.message);
                    // Em dev, processar mesmo sem verificação
                    event = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
                }
            } else {
                // Produção - verificação rigorosa
                event = stripe.webhooks.constructEvent(
                    rawBody,
                    signature,
                    STRIPE_WEBHOOK_SECRET
                );
            }

            console.log(`📦 Evento: ${event.type}`);
            console.log('📋 Metadata:', event.data.object.metadata);

            // Processar diferentes tipos de eventos
            switch (event.type) {
                case 'checkout.session.completed':
                    console.log('💳 Processando checkout completo...');
                    await this.handleCheckoutCompleted(event.data.object);
                    break;

                case 'customer.subscription.created':
                    console.log('📝 Nova assinatura criada');
                    await this.handleSubscriptionCreated(event.data.object);
                    break;

                case 'customer.subscription.updated':
                    console.log('🔄 Assinatura atualizada');
                    await this.handleSubscriptionUpdated(event.data.object);
                    break;

                case 'customer.subscription.deleted':
                    console.log('❌ Assinatura cancelada');
                    await this.handleSubscriptionCancelled(event.data.object);
                    break;

                case 'invoice.payment_succeeded':
                    console.log('✅ Pagamento bem-sucedido');
                    await this.handlePaymentSucceeded(event.data.object);
                    break;

                case 'invoice.payment_failed':
                    console.log('❌ Pagamento falhou');
                    await this.handlePaymentFailed(event.data.object);
                    break;

                default:
                    console.log(`⚠️  Evento não tratado: ${event.type}`);
            }

            return { received: true };

        } catch (error) {
            console.error('❌ Erro no webhook:', error);
            console.error('Stack:', error.stack);

            // Em desenvolvimento, não lançar erro para evitar retry do Stripe
            if (process.env.NODE_ENV === 'development') {
                return { received: true, error: error.message };
            }

            throw error;
        }
    }

    // ================================================
    // HANDLERS PARA EVENTOS DO WEBHOOK
    // ================================================

    async handleCheckoutCompleted(session) {
        const client = await pool.connect();

        try {
            console.log('💳 Processando checkout:', session.id);
            console.log('   Modo:', session.mode);
            console.log('   Cliente:', session.customer);
            console.log('   Metadata:', JSON.stringify(session.metadata));

            await client.query('BEGIN');

            // Extrair metadata
            let {
                organization_id,
                plan_id,
                plan_key
            } = session.metadata || {};

            if (!organization_id) {
                console.error('⚠️  Metadata incompleta, tentando recuperar do customer');

                // Tentar recuperar pelo customer_id
                const orgResult = await client.query(
                    'SELECT id FROM tenant.organizations WHERE stripe_customer_id = $1',
                    [session.customer]
                );

                if (orgResult.rows.length === 0) {
                    throw new Error('Organização não encontrada para customer: ' + session.customer);
                }

                organization_id = orgResult.rows[0].id;
            }

            // Se não temos plan_id, buscar pelo plan_key
            if (!plan_id && plan_key) {
                console.log('🔍 Buscando plan_id pelo plan_key:', plan_key);
                const planKeyResult = await client.query(
                    'SELECT id FROM billing.plans WHERE plan_key = $1',
                    [plan_key]
                );
                if (planKeyResult.rows.length > 0) {
                    plan_id = planKeyResult.rows[0].id;
                    console.log('✅ Plan ID encontrado:', plan_id);
                }
            }

            // Fallback se ainda não temos plan_id
            if (!plan_id) {
                console.log('⚠️  Plan ID não encontrado, usando fallback');
                plan_id = 1; // Default para plano 1
                plan_key = plan_key || 'monthly_1k';
            }

            console.log('   Org ID:', organization_id);
            console.log('   Plan ID:', plan_id);

            // Buscar informações do plano
            const planResult = await client.query(
                'SELECT * FROM billing.plans WHERE id = $1',
                [plan_id || 1]
            );

            const planInfo = planResult.rows[0] || {
                name: 'Plano Desconhecido',
                emails_limit: 0,
                price: session.amount_total / 100
            };

            if (session.mode === 'subscription') {
                // ========== PROCESSAMENTO DE ASSINATURA ==========

                // Verificar se já existe
                const existingResult = await client.query(
                    'SELECT id FROM billing.subscriptions WHERE stripe_subscription_id = $1',
                    [session.subscription]
                );

                let subscriptionId;

                if (existingResult.rows.length === 0) {
                    // Criar assinatura no banco
                    console.log('📝 Criando assinatura no banco...');

                    const subResult = await client.query(
                        `INSERT INTO billing.subscriptions
                         (organization_id, plan_id, status, stripe_subscription_id,
                          stripe_customer_id, payment_method, amount, currency, created_at)
                         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, CURRENT_TIMESTAMP)
                         RETURNING id`,
                        [
                            organization_id,
                            plan_id || 1,
                            'active',
                            session.subscription,
                            session.customer,
                            'stripe',
                            session.amount_total / 100,
                            (session.currency || 'brl').toUpperCase()
                        ]
                    );

                    subscriptionId = subResult.rows[0].id;
                    console.log('✅ Assinatura criada no banco');
                } else {
                    console.log('⚠️  Assinatura já existe, atualizando...');
                    subscriptionId = existingResult.rows[0].id;

                    await client.query(
                        `UPDATE billing.subscriptions
                         SET status = 'active', updated_at = CURRENT_TIMESTAMP
                         WHERE stripe_subscription_id = $1`,
                        [session.subscription]
                    );
                }

                // 🔧 CRIAR TRANSAÇÃO PARA ASSINATURA
                console.log('💰 Criando transação para assinatura...');

                await client.query(
                    `INSERT INTO billing.transactions
                     (organization_id, subscription_id, type, status, amount, currency,
                      description, stripe_invoice_id, created_at)
                     VALUES ($1, $2, 'subscription', 'completed', $3, $4, $5, $6, NOW())`,
                    [
                        organization_id,
                        subscriptionId,
                        session.amount_total / 100,
                        (session.currency || 'brl').toUpperCase(),
                        `Assinatura - ${planInfo.name}`,
                        session.invoice || null
                    ]
                );

                console.log('✅ Transação de assinatura criada');

                // Atualizar plano e créditos mensais
                console.log('📊 Atualizando organização (assinatura):', {
                    organization_id: organization_id,
                    monthly_credits: planInfo.emails_limit,
                    plan: planInfo.name
                });
                
                const updateResult = await client.query(
                    `UPDATE tenant.organizations
                     SET plan = $1, monthly_credits = $2, updated_at = CURRENT_TIMESTAMP
                     WHERE id = $3
                     RETURNING id, name, plan, monthly_credits, balance_credits`,
                    [planInfo.name, planInfo.emails_limit, organization_id]
                );
                
                if (updateResult.rows.length > 0) {
                    console.log('✅ Organização atualizada (assinatura):', updateResult.rows[0]);
                    
                    // Adicionar créditos mensais usando a função
                    const creditResult = await client.query(
                        `SELECT tenant.add_credits($1, $2, $3, $4, $5) as new_balance`,
                        [
                            organization_id,
                            planInfo.emails_limit,
                            'monthly',
                            `Créditos da assinatura: ${planInfo.name}`,
                            session.id
                        ]
                    );
                    
                    console.log('✅ Créditos mensais adicionados:', creditResult.rows[0].new_balance);
                } else {
                    console.error('❌ Nenhuma organização foi atualizada - ID não encontrado:', organization_id);
                }

                console.log('✅ Organização atualizada com novo plano');

            } else {
                // ========== PROCESSAMENTO DE PAGAMENTO ÚNICO ==========

                console.log('💰 Processando pagamento único...');

                // Adicionar créditos
                await this.addOneTimeCredits(organization_id, plan_id || 1, client);

                // 🔧 CRIAR TRANSAÇÃO PARA PAGAMENTO ÚNICO
                console.log('💰 Criando transação para pagamento único...');

                await client.query(
                    `INSERT INTO billing.transactions
                     (organization_id, type, status, amount, currency,
                      description, stripe_payment_intent, created_at)
                     VALUES ($1, 'payment', 'completed', $2, $3, $4, $5, NOW())`,
                    [
                        organization_id,
                        session.amount_total / 100,
                        (session.currency || 'brl').toUpperCase(),
                        `Pagamento único - ${planInfo.name}`,
                        session.payment_intent || null
                    ]
                );

                console.log('✅ Transação de pagamento único criada');
            }

            // Atualizar checkout como completo
            await client.query(
                `UPDATE billing.pending_checkouts
                 SET status = 'completed', completed_at = CURRENT_TIMESTAMP
                 WHERE stripe_session_id = $1`,
                [session.id]
            );

            await client.query('COMMIT');

            console.log('✅ Checkout processado com sucesso! Transação criada automaticamente.');

        } catch (error) {
            await client.query('ROLLBACK');
            console.error('❌ Erro ao processar checkout:', error);
            throw error;
        } finally {
            client.release();
        }
    }

    async handleSubscriptionCreated(subscription) {
        try {
            console.log('📝 Processando nova assinatura:', subscription.id);

            // Extrair metadata
            const { organization_id, plan_id, plan_key } = subscription.metadata || {};

            let org_id = organization_id;

            if (!org_id) {
                console.log('⚠️  Sem metadata, tentando recuperar pelo customer');

                // Buscar organização pelo customer
                const orgResult = await pool.query(
                    'SELECT id FROM tenant.organizations WHERE stripe_customer_id = $1',
                    [subscription.customer]
                );

                if (orgResult.rows.length > 0) {
                    org_id = orgResult.rows[0].id;
                } else {
                    console.log('❌ Organização não encontrada para customer:', subscription.customer);
                    return;
                }
            }

            // Criar ou atualizar assinatura
            const subResult = await pool.query(
                `INSERT INTO billing.subscriptions
                 (organization_id, plan_id, status, stripe_subscription_id,
                  stripe_customer_id, payment_method, amount, currency, created_at)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                 ON CONFLICT (stripe_subscription_id)
                 DO UPDATE SET
                    status = EXCLUDED.status,
                    amount = EXCLUDED.amount,
                    updated_at = CURRENT_TIMESTAMP
                 RETURNING id`,
                [
                    org_id,
                    plan_id || 1,
                    subscription.status,
                    subscription.id,
                    subscription.customer,
                    'stripe',
                    subscription.items.data[0].price.unit_amount / 100,
                    subscription.currency.toUpperCase(),
                    new Date(subscription.created * 1000)
                ]
            );

            // Criar transação para o evento de criação
            await pool.query(
                `INSERT INTO billing.transactions
                 (organization_id, subscription_id, type, status, amount, currency,
                  description, created_at)
                 VALUES ($1, $2, 'subscription_created', 'completed', $3, $4, $5, NOW())`,
                [
                    org_id,
                    subResult.rows[0].id,
                    subscription.items.data[0].price.unit_amount / 100,
                    subscription.currency.toUpperCase(),
                    'Nova assinatura criada'
                ]
            );

            console.log('✅ Assinatura e transação criadas no banco');

        } catch (error) {
            console.error('❌ Erro ao processar subscription.created:', error);
        }
    }

    async handleSubscriptionUpdated(subscription) {
        try {
            console.log('🔄 Atualizando assinatura:', subscription.id);

            // Atualizar status da assinatura
            await pool.query(
                `UPDATE billing.subscriptions
                 SET status = $1, updated_at = CURRENT_TIMESTAMP
                 WHERE stripe_subscription_id = $2`,
                [subscription.status, subscription.id]
            );

            console.log('✅ Status atualizado para:', subscription.status);
        } catch (error) {
            console.error('❌ Erro ao atualizar assinatura:', error);
        }
    }

    async handleSubscriptionCancelled(subscription) {
        try {
            console.log('🚫 Cancelando assinatura:', subscription.id);

            // Cancelar assinatura
            await pool.query(
                `UPDATE billing.subscriptions
                 SET status = 'cancelled', cancelled_at = CURRENT_TIMESTAMP
                 WHERE stripe_subscription_id = $1`,
                [subscription.id]
            );

            // Buscar informações da assinatura
            const result = await pool.query(
                `SELECT organization_id, id FROM billing.subscriptions
                 WHERE stripe_subscription_id = $1`,
                [subscription.id]
            );

            if (result.rows.length > 0) {
                const { organization_id, id: subscription_id } = result.rows[0];

                // Resetar limite da organização
                await pool.query(
                    `UPDATE tenant.organizations
                     SET max_validations = 100, plan = 'free', updated_at = CURRENT_TIMESTAMP
                     WHERE id = $1`,
                    [organization_id]
                );

                // Criar transação de cancelamento
                await pool.query(
                    `INSERT INTO billing.transactions
                     (organization_id, subscription_id, type, status, amount, currency,
                      description, created_at)
                     VALUES ($1, $2, 'cancellation', 'completed', 0, 'BRL',
                      'Assinatura cancelada', NOW())`,
                    [organization_id, subscription_id]
                );

                console.log('✅ Organização revertida para plano free e transação registrada');
            }
        } catch (error) {
            console.error('❌ Erro ao cancelar assinatura:', error);
        }
    }

    async handlePaymentSucceeded(invoice) {
        try {
            console.log('💰 Registrando pagamento bem-sucedido:', invoice.id);

            // Registrar pagamento bem-sucedido
            const subscription = invoice.subscription;
            const amount = invoice.amount_paid / 100;

            // Criar transação
            await pool.query(
                `INSERT INTO billing.transactions
                 (organization_id, subscription_id, type, status, amount, currency,
                  stripe_invoice_id, stripe_payment_intent, description, created_at)
                 SELECT
                    s.organization_id, s.id, 'recurring_payment', 'completed', $1, $2,
                    $3, $4, 'Pagamento recorrente - ' || p.name, CURRENT_TIMESTAMP
                 FROM billing.subscriptions s
                 LEFT JOIN billing.plans p ON s.plan_id = p.id
                 WHERE s.stripe_subscription_id = $5`,
                [amount, (invoice.currency || 'brl').toUpperCase(),
                 invoice.id, invoice.payment_intent, subscription]
            );

            console.log('✅ Transação de pagamento recorrente registrada');
        } catch (error) {
            console.error('❌ Erro ao registrar pagamento:', error);
        }
    }

    async handlePaymentFailed(invoice) {
        console.error('❌ Pagamento falhou:', invoice.id);

        try {
            // Registrar falha
            const subscription = invoice.subscription;
            const amount = invoice.amount_due / 100;

            await pool.query(
                `INSERT INTO billing.transactions
                 (organization_id, subscription_id, type, status, amount, currency,
                  stripe_invoice_id, description, created_at)
                 SELECT
                    s.organization_id, s.id, 'payment', 'failed', $1, $2,
                    $3, 'Falha no pagamento recorrente', CURRENT_TIMESTAMP
                 FROM billing.subscriptions s
                 WHERE s.stripe_subscription_id = $4`,
                [amount, (invoice.currency || 'brl').toUpperCase(),
                 invoice.id, subscription]
            );

            // TODO: Enviar email de notificação
            // TODO: Suspender serviço após X tentativas

            console.log('✅ Falha de pagamento registrada');

        } catch (error) {
            console.error('❌ Erro ao registrar falha:', error);
        }
    }

    // ================================================
    // FUNÇÕES AUXILIARES
    // ================================================

    async checkExistingSubscription(organizationId) {
        const result = await pool.query(
            `SELECT id FROM billing.subscriptions
             WHERE organization_id = $1 AND status IN ('active', 'trialing')
             LIMIT 1`,
            [organizationId]
        );
        return result.rows.length > 0;
    }

    async addOneTimeCredits(organizationId, planId, client = null) {
        const shouldRelease = !client;
        if (!client) client = await pool.connect();

        try {
            // Buscar detalhes do plano
            const planResult = await client.query(
                'SELECT emails_limit, name FROM billing.plans WHERE id = $1',
                [planId]
            );

            if (planResult.rows.length > 0) {
                const { emails_limit, name } = planResult.rows[0];

                console.log('📊 Adicionando créditos avulsos:', {
                    organizationId: organizationId,
                    emails_limit: emails_limit,
                    plan_name: name
                });
                
                // Usar a nova função para adicionar créditos
                const creditResult = await client.query(
                    `SELECT tenant.add_credits($1, $2, $3, $4) as new_balance`,
                    [
                        organizationId,
                        emails_limit,
                        'purchase',
                        `Compra avulsa: ${name} (${emails_limit} créditos)`
                    ]
                );
                
                if (creditResult.rows.length > 0) {
                    console.log('✅ Créditos avulsos adicionados:', {
                        organizationId: organizationId,
                        credits_added: emails_limit,
                        new_balance: creditResult.rows[0].new_balance
                    });
                } else {
                    console.error('❌ Erro ao adicionar créditos avulsos:', organizationId);
                }
            }
        } finally {
            if (shouldRelease) client.release();
        }
    }

    // ================================================
    // CRIAR PORTAL DO CLIENTE (GERENCIAR ASSINATURA)
    // ================================================
    async createCustomerPortal(organizationId) {
        try {
            console.log('🚪 Criando portal do cliente para org:', organizationId);

            // Buscar customer_id
            const result = await pool.query(
                'SELECT stripe_customer_id FROM tenant.organizations WHERE id = $1',
                [organizationId]
            );

            if (result.rows.length === 0 || !result.rows[0].stripe_customer_id) {
                throw new Error('Cliente não encontrado no Stripe');
            }

            // Criar sessão do portal
            const session = await stripe.billingPortal.sessions.create({
                customer: result.rows[0].stripe_customer_id,
                return_url: 'http://localhost:4201/billing/dashboard',
                locale: 'pt-BR'
            });

            console.log('✅ Portal criado:', session.url);

            return {
                success: true,
                portalUrl: session.url
            };

        } catch (error) {
            console.error('❌ Erro ao criar portal:', error);
            throw error;
        }
    }

    // ================================================
    // LISTAR MÉTODOS DE PAGAMENTO
    // ================================================
    async listPaymentMethods(organizationId) {
        try {
            const result = await pool.query(
                'SELECT stripe_customer_id FROM tenant.organizations WHERE id = $1',
                [organizationId]
            );

            if (result.rows.length === 0 || !result.rows[0].stripe_customer_id) {
                return [];
            }

            const paymentMethods = await stripe.paymentMethods.list({
                customer: result.rows[0].stripe_customer_id,
                type: 'card'
            });

            return paymentMethods.data.map(pm => ({
                id: pm.id,
                brand: pm.card.brand,
                last4: pm.card.last4,
                expMonth: pm.card.exp_month,
                expYear: pm.card.exp_year
            }));

        } catch (error) {
            console.error('❌ Erro ao listar métodos de pagamento:', error);
            throw error;
        }
    }

    // ================================================
    // SINCRONIZAR ASSINATURAS DO STRIPE (UTILIDADE)
    // ================================================
    async syncSubscriptionsFromStripe() {
        try {
            console.log('🔄 Sincronizando assinaturas do Stripe...');

            // Buscar todas as assinaturas do Stripe
            const subscriptions = await stripe.subscriptions.list({
                limit: 100,
                expand: ['data.customer']
            });

            console.log(`📦 Encontradas ${subscriptions.data.length} assinaturas no Stripe`);

            for (const sub of subscriptions.data) {
                // Verificar se existe no banco
                const existingResult = await pool.query(
                    'SELECT id FROM billing.subscriptions WHERE stripe_subscription_id = $1',
                    [sub.id]
                );

                if (existingResult.rows.length === 0) {
                    console.log(`📝 Importando assinatura: ${sub.id}`);

                    // Buscar organização
                    const orgResult = await pool.query(
                        'SELECT id FROM tenant.organizations WHERE stripe_customer_id = $1',
                        [sub.customer.id || sub.customer]
                    );

                    if (orgResult.rows.length > 0) {
                        // Inserir assinatura
                        const subResult = await pool.query(
                            `INSERT INTO billing.subscriptions
                             (organization_id, plan_id, status, stripe_subscription_id,
                              stripe_customer_id, payment_method, amount, currency, created_at)
                             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                             RETURNING id`,
                            [
                                orgResult.rows[0].id,
                                1, // Default plan_id
                                sub.status,
                                sub.id,
                                sub.customer.id || sub.customer,
                                'stripe',
                                sub.items.data[0].price.unit_amount / 100,
                                sub.currency.toUpperCase(),
                                new Date(sub.created * 1000)
                            ]
                        );

                        // Criar transação de importação
                        await pool.query(
                            `INSERT INTO billing.transactions
                             (organization_id, subscription_id, type, status, amount, currency,
                              description, created_at)
                             VALUES ($1, $2, 'import', 'completed', $3, $4,
                              'Assinatura importada do Stripe', NOW())`,
                            [
                                orgResult.rows[0].id,
                                subResult.rows[0].id,
                                sub.items.data[0].price.unit_amount / 100,
                                sub.currency.toUpperCase()
                            ]
                        );

                        console.log('✅ Assinatura importada com transação');
                    } else {
                        console.log('⚠️  Organização não encontrada para customer:', sub.customer.id || sub.customer);
                    }
                }
            }

            console.log('✅ Sincronização concluída!');

        } catch (error) {
            console.error('❌ Erro na sincronização:', error);
            throw error;
        }
    }
}

module.exports = new StripePaymentService();
