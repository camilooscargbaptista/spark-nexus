-- Migration: 007_add_stripe_tables.sql

-- Adicionar coluna stripe_customer_id na organizations
ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(255);

-- Tabela para checkouts pendentes
CREATE TABLE IF NOT EXISTS billing.pending_checkouts (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES tenant.organizations(id),
    plan_id INTEGER NOT NULL REFERENCES billing.plans(id),
    stripe_session_id VARCHAR(255) UNIQUE NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Adicionar colunas Stripe nas subscriptions
ALTER TABLE billing.subscriptions
ADD COLUMN IF NOT EXISTS stripe_subscription_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(255);

-- Adicionar colunas Stripe nas transactions
ALTER TABLE billing.transactions
ADD COLUMN IF NOT EXISTS stripe_invoice_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS stripe_payment_intent VARCHAR(255);

-- Índices
CREATE INDEX IF NOT EXISTS idx_org_stripe_customer ON tenant.organizations(stripe_customer_id);
CREATE INDEX IF NOT EXISTS idx_sub_stripe_id ON billing.subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_checkout_session ON billing.pending_checkouts(stripe_session_id);
