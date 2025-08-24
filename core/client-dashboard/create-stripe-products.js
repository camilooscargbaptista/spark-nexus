// create-stripe-products.js
// Salve este arquivo e execute com: node create-stripe-products.js
// IMPORTANTE: Configure STRIPE_SECRET_KEY no .env antes de executar

require('dotenv').config();
const Stripe = require('stripe');

if (!process.env.STRIPE_SECRET_KEY) {
    console.error('❌ ERRO: STRIPE_SECRET_KEY não encontrada no .env');
    process.exit(1);
}

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
    apiVersion: '2023-10-16'
});

async function createProducts() {
    console.log('🚀 Criando produtos no Stripe...\n');

    const products = [];
    const prices = [];

    try {
        // ========================================
        // PRODUTOS AVULSOS (ONE-TIME)
        // ========================================

        console.log('📦 Criando produtos avulsos...');

        // Pacote 1K
        const product1K = await stripe.products.create({
            name: 'Pacote Starter - 1.000 validações',
            description: '1.000 validações de email avulsas',
            metadata: {
                plan_key: 'onetime_1k',
                emails_limit: '1000',
                type: 'one_time'
            }
        });
        products.push(product1K);

        const price1K = await stripe.prices.create({
            product: product1K.id,
            unit_amount: 4999, // R$ 49,99
            currency: 'brl',
            metadata: {
                plan_key: 'onetime_1k'
            }
        });
        prices.push(price1K);
        console.log(`✅ Pacote 1K criado: ${price1K.id}`);

        // Pacote 5K
        const product5K = await stripe.products.create({
            name: 'Pacote Basic - 5.000 validações',
            description: '5.000 validações de email avulsas',
            metadata: {
                plan_key: 'onetime_5k',
                emails_limit: '5000',
                type: 'one_time'
            }
        });
        products.push(product5K);

        const price5K = await stripe.prices.create({
            product: product5K.id,
            unit_amount: 19999, // R$ 199,99
            currency: 'brl',
            metadata: {
                plan_key: 'onetime_5k'
            }
        });
        prices.push(price5K);
        console.log(`✅ Pacote 5K criado: ${price5K.id}`);

        // Pacote 10K
        const product10K = await stripe.products.create({
            name: 'Pacote Pro - 10.000 validações',
            description: '10.000 validações de email avulsas',
            metadata: {
                plan_key: 'onetime_10k',
                emails_limit: '10000',
                type: 'one_time'
            }
        });
        products.push(product10K);

        const price10K = await stripe.prices.create({
            product: product10K.id,
            unit_amount: 34999, // R$ 349,99
            currency: 'brl',
            metadata: {
                plan_key: 'onetime_10k'
            }
        });
        prices.push(price10K);
        console.log(`✅ Pacote 10K criado: ${price10K.id}`);

        // ========================================
        // ASSINATURAS MENSAIS
        // ========================================

        console.log('\n📅 Criando assinaturas mensais...');

        // Mensal 1K
        const productMonthly1K = await stripe.products.create({
            name: 'Plano Starter Mensal',
            description: '1.000 validações por mês',
            metadata: {
                plan_key: 'monthly_1k',
                emails_limit: '1000',
                type: 'subscription',
                period: 'monthly'
            }
        });
        products.push(productMonthly1K);

        const priceMonthly1K = await stripe.prices.create({
            product: productMonthly1K.id,
            unit_amount: 3999, // R$ 39,99/mês
            currency: 'brl',
            recurring: {
                interval: 'month'
            },
            metadata: {
                plan_key: 'monthly_1k'
            }
        });
        prices.push(priceMonthly1K);
        console.log(`✅ Plano Mensal 1K criado: ${priceMonthly1K.id}`);

        // Mensal 5K
        const productMonthly5K = await stripe.products.create({
            name: 'Plano Basic Mensal',
            description: '5.000 validações por mês',
            metadata: {
                plan_key: 'monthly_5k',
                emails_limit: '5000',
                type: 'subscription',
                period: 'monthly'
            }
        });
        products.push(productMonthly5K);

        const priceMonthly5K = await stripe.prices.create({
            product: productMonthly5K.id,
            unit_amount: 7999, // R$ 79,99/mês
            currency: 'brl',
            recurring: {
                interval: 'month'
            },
            metadata: {
                plan_key: 'monthly_5k'
            }
        });
        prices.push(priceMonthly5K);
        console.log(`✅ Plano Mensal 5K criado: ${priceMonthly5K.id}`);

        // Mensal 10K (MAIS POPULAR)
        const productMonthly10K = await stripe.products.create({
            name: 'Plano Growth Mensal',
            description: '10.000 validações por mês - MAIS POPULAR',
            metadata: {
                plan_key: 'monthly_10k',
                emails_limit: '10000',
                type: 'subscription',
                period: 'monthly',
                popular: 'true'
            }
        });
        products.push(productMonthly10K);

        const priceMonthly10K = await stripe.prices.create({
            product: productMonthly10K.id,
            unit_amount: 12999, // R$ 129,99/mês
            currency: 'brl',
            recurring: {
                interval: 'month'
            },
            metadata: {
                plan_key: 'monthly_10k',
                popular: 'true'
            }
        });
        prices.push(priceMonthly10K);
        console.log(`✅ Plano Mensal 10K criado: ${priceMonthly10K.id} ⭐`);

        // ========================================
        // ASSINATURAS ANUAIS (COM DESCONTO)
        // ========================================

        console.log('\n📅 Criando assinaturas anuais...');

        // Anual 1K
        const productYearly1K = await stripe.products.create({
            name: 'Plano Starter Anual',
            description: '1.000 validações por mês (cobrança anual) - Economize 20%',
            metadata: {
                plan_key: 'yearly_1k',
                emails_limit: '1000',
                type: 'subscription',
                period: 'yearly',
                discount: '20'
            }
        });
        products.push(productYearly1K);

        const priceYearly1K = await stripe.prices.create({
            product: productYearly1K.id,
            unit_amount: 38390, // R$ 383,90/ano (20% desconto)
            currency: 'brl',
            recurring: {
                interval: 'year'
            },
            metadata: {
                plan_key: 'yearly_1k'
            }
        });
        prices.push(priceYearly1K);
        console.log(`✅ Plano Anual 1K criado: ${priceYearly1K.id}`);

        // Anual 5K
        const productYearly5K = await stripe.products.create({
            name: 'Plano Basic Anual',
            description: '5.000 validações por mês (cobrança anual) - Economize 20%',
            metadata: {
                plan_key: 'yearly_5k',
                emails_limit: '5000',
                type: 'subscription',
                period: 'yearly',
                discount: '20'
            }
        });
        products.push(productYearly5K);

        const priceYearly5K = await stripe.prices.create({
            product: productYearly5K.id,
            unit_amount: 76790, // R$ 767,90/ano (20% desconto)
            currency: 'brl',
            recurring: {
                interval: 'year'
            },
            metadata: {
                plan_key: 'yearly_5k'
            }
        });
        prices.push(priceYearly5K);
        console.log(`✅ Plano Anual 5K criado: ${priceYearly5K.id}`);

        // Anual 10K
        const productYearly10K = await stripe.products.create({
            name: 'Plano Growth Anual',
            description: '10.000 validações por mês (cobrança anual) - Economize 20%',
            metadata: {
                plan_key: 'yearly_10k',
                emails_limit: '10000',
                type: 'subscription',
                period: 'yearly',
                discount: '20'
            }
        });
        products.push(productYearly10K);

        const priceYearly10K = await stripe.prices.create({
            product: productYearly10K.id,
            unit_amount: 124790, // R$ 1.247,90/ano (20% desconto)
            currency: 'brl',
            recurring: {
                interval: 'year'
            },
            metadata: {
                plan_key: 'yearly_10k'
            }
        });
        prices.push(priceYearly10K);
        console.log(`✅ Plano Anual 10K criado: ${priceYearly10K.id}`);

        // ========================================
        // RESUMO
        // ========================================

        console.log('\n' + '='.repeat(50));
        console.log('🎉 PRODUTOS CRIADOS COM SUCESSO!');
        console.log('='.repeat(50));

        console.log('\n📋 COPIE ESTAS VARIÁVEIS PARA O SEU .env:\n');

        console.log('# Produtos Avulsos');
        console.log(`STRIPE_PRICE_ONETIME_1K=${prices[0].id}`);
        console.log(`STRIPE_PRICE_ONETIME_5K=${prices[1].id}`);
        console.log(`STRIPE_PRICE_ONETIME_10K=${prices[2].id}`);

        console.log('\n# Assinaturas Mensais');
        console.log(`STRIPE_PRICE_MONTHLY_1K=${prices[3].id}`);
        console.log(`STRIPE_PRICE_MONTHLY_5K=${prices[4].id}`);
        console.log(`STRIPE_PRICE_MONTHLY_10K=${prices[5].id}`);

        console.log('\n# Assinaturas Anuais');
        console.log(`STRIPE_PRICE_YEARLY_1K=${prices[6].id}`);
        console.log(`STRIPE_PRICE_YEARLY_5K=${prices[7].id}`);
        console.log(`STRIPE_PRICE_YEARLY_10K=${prices[8].id}`);

        console.log('\n✅ Todos os produtos foram criados no Stripe!');
        console.log('📌 Agora você pode ver todos em: https://dashboard.stripe.com/test/products');

    } catch (error) {
        console.error('❌ Erro ao criar produtos:', error.message);
    }
}

// Executar
createProducts();
