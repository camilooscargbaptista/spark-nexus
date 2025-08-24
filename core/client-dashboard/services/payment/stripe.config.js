// core/client-dashboard/services/payment/stripe.config.js

const Stripe = require('stripe');

// Chaves do Stripe
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

// Inicializar Stripe
const stripe = new Stripe(STRIPE_SECRET_KEY, {
    apiVersion: '2023-10-16',
    typescript: false,
});

// Mapear nossos planos para produtos do Stripe (IDs REAIS)
const STRIPE_PRODUCTS = {
    // Planos Avulsos
    'onetime_1k': {
        priceId: process.env.STRIPE_PRICE_ONETIME_1K || 'price_1RxDDrDDs93u86g8pz81AXvB'
    },
    'onetime_5k': {
        priceId: process.env.STRIPE_PRICE_ONETIME_5K || 'price_1RxDDsDDs93u86g8hYnyphPy'
    },
    'onetime_10k': {
        priceId: process.env.STRIPE_PRICE_ONETIME_10K || 'price_1RxDDsDDs93u86g8TjutEbcp'
    },
    // Planos Mensais
    'monthly_1k': {
        priceId: process.env.STRIPE_PRICE_MONTHLY_1K || 'price_1RxDDtDDs93u86g8P8Boo99g'
    },
    'monthly_5k': {
        priceId: process.env.STRIPE_PRICE_MONTHLY_5K || 'price_1RxDDuDDs93u86g8PQMJBf3g'
    },
    'monthly_10k': {
        priceId: process.env.STRIPE_PRICE_MONTHLY_10K || 'price_1RxDDvDDs93u86g8VIZjZDNR'
    },
    // Planos Anuais
    'yearly_1k': {
        priceId: process.env.STRIPE_PRICE_YEARLY_1K || 'price_1RxDDwDDs93u86g8bjNmMTir'
    },
    'yearly_5k': {
        priceId: process.env.STRIPE_PRICE_YEARLY_5K || 'price_1RxDDwDDs93u86g8IZbjNHOB'
    },
    'yearly_10k': {
        priceId: process.env.STRIPE_PRICE_YEARLY_10K || 'price_1RxDDxDDs93u86g8tUYTNbog'
    }
};

module.exports = {
    stripe,
    STRIPE_SECRET_KEY,
    STRIPE_WEBHOOK_SECRET,
    STRIPE_PRODUCTS
};
