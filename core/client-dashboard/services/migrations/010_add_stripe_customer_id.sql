-- migrations/010_add_stripe_customer_id.sql

-- ================================================
-- ADICIONAR COLUNA STRIPE_CUSTOMER_ID
-- ================================================

-- Adicionar coluna na tabela organizations
ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(255) UNIQUE;

-- Adicionar índice para melhor performance
CREATE INDEX IF NOT EXISTS idx_organizations_stripe_customer_id
ON tenant.organizations(stripe_customer_id)
WHERE stripe_customer_id IS NOT NULL;

-- Adicionar comentário
COMMENT ON COLUMN tenant.organizations.stripe_customer_id IS 'ID do cliente no Stripe para pagamentos';

-- ================================================
-- TABELA DE CHECKOUTS PENDENTES
-- ================================================

CREATE TABLE IF NOT EXISTS billing.pending_checkouts (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES tenant.organizations(id),
    plan_id INTEGER NOT NULL REFERENCES billing.plans(id),
    stripe_session_id VARCHAR(255) UNIQUE NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_pending_checkouts_org
ON billing.pending_checkouts(organization_id);

CREATE INDEX IF NOT EXISTS idx_pending_checkouts_session
ON billing.pending_checkouts(stripe_session_id);

CREATE INDEX IF NOT EXISTS idx_pending_checkouts_status
ON billing.pending_checkouts(status);

-- ================================================
-- ADICIONAR COLUNAS FALTANTES EM SUBSCRIPTIONS
-- ================================================

ALTER TABLE billing.subscriptions
ADD COLUMN IF NOT EXISTS stripe_subscription_id VARCHAR(255) UNIQUE,
ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50),
ADD COLUMN IF NOT EXISTS amount DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS currency VARCHAR(3) DEFAULT 'BRL',
ADD COLUMN IF NOT EXISTS cancel_at_period_end BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP;

-- Índices
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_sub
ON billing.subscriptions(stripe_subscription_id)
WHERE stripe_subscription_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_customer
ON billing.subscriptions(stripe_customer_id)
WHERE stripe_customer_id IS NOT NULL;

-- ================================================
-- TABELA DE TRANSAÇÕES
-- ================================================

CREATE TABLE IF NOT EXISTS billing.transactions (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES tenant.organizations(id),
    subscription_id INTEGER REFERENCES billing.subscriptions(id),
    type VARCHAR(50) NOT NULL, -- payment, refund, credit, debit
    status VARCHAR(50) NOT NULL, -- completed, pending, failed
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'BRL',
    description TEXT,
    stripe_invoice_id VARCHAR(255),
    stripe_payment_intent VARCHAR(255),
    stripe_charge_id VARCHAR(255),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_transactions_org
ON billing.transactions(organization_id);

CREATE INDEX IF NOT EXISTS idx_transactions_subscription
ON billing.transactions(subscription_id);

CREATE INDEX IF NOT EXISTS idx_transactions_type
ON billing.transactions(type);

CREATE INDEX IF NOT EXISTS idx_transactions_status
ON billing.transactions(status);

CREATE INDEX IF NOT EXISTS idx_transactions_created
ON billing.transactions(created_at DESC);

-- ================================================
-- ADICIONAR COLUNA EMAIL NA ORGANIZATIONS (se não existir)
-- ================================================

ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- Atualizar email com o email do owner se estiver vazio
UPDATE tenant.organizations o
SET email = u.email
FROM tenant.organization_members om
JOIN auth.users u ON om.user_id = u.id
WHERE om.organization_id = o.id
  AND om.role = 'owner'
  AND o.email IS NULL;

-- ================================================
-- FUNÇÃO PARA ATUALIZAR UPDATED_AT
-- ================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers
DROP TRIGGER IF EXISTS update_pending_checkouts_updated_at ON billing.pending_checkouts;
CREATE TRIGGER update_pending_checkouts_updated_at
BEFORE UPDATE ON billing.pending_checkouts
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_transactions_updated_at ON billing.transactions;
CREATE TRIGGER update_transactions_updated_at
BEFORE UPDATE ON billing.transactions
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ================================================
-- GRANT PERMISSIONS
-- ================================================

GRANT ALL ON billing.pending_checkouts TO sparknexus;
GRANT ALL ON billing.pending_checkouts_id_seq TO sparknexus;
GRANT ALL ON billing.transactions TO sparknexus;
GRANT ALL ON billing.transactions_id_seq TO sparknexus;

-- ================================================
-- VERIFICAR ESTRUTURA
-- ================================================

-- Mostrar estrutura atualizada
\d tenant.organizations
\d billing.subscriptions
\d billing.pending_checkouts
\d billing.transactions
