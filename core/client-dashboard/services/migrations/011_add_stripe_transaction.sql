-- ================================================
-- ADICIONAR COLUNAS FALTANTES NA TABELA TRANSACTIONS
-- ================================================

-- Adicionar colunas do Stripe
ALTER TABLE billing.transactions
ADD COLUMN IF NOT EXISTS stripe_invoice_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS stripe_payment_intent VARCHAR(255),
ADD COLUMN IF NOT EXISTS stripe_charge_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS subscription_id INTEGER REFERENCES billing.subscriptions(id),
ADD COLUMN IF NOT EXISTS metadata JSONB;

-- Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_transactions_stripe_invoice
ON billing.transactions(stripe_invoice_id)
WHERE stripe_invoice_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_stripe_payment_intent
ON billing.transactions(stripe_payment_intent)
WHERE stripe_payment_intent IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_subscription
ON billing.transactions(subscription_id)
WHERE subscription_id IS NOT NULL;

-- Verificar estrutura atualizada
\d billing.transactions

-- Confirmar que as colunas foram criadas
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'billing'
AND table_name = 'transactions'
ORDER BY ordinal_position;
