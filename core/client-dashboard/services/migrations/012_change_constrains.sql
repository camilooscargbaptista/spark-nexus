-- 1. REMOVER CONSTRAINTS ANTIGAS
ALTER TABLE billing.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE billing.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_status_check;

-- 2. CRIAR CONSTRAINTS CORRETAS COM TODOS OS VALORES POSSÍVEIS
ALTER TABLE billing.transactions
ADD CONSTRAINT transactions_type_check
CHECK (type IN (
    'payment',
    'subscription',
    'refund',
    'credit',
    'debit',
    'recurring_payment',
    'subscription_created',
    'cancellation',
    'import',
    'test',
    'test_manual',
    'test_webhook',
    'forced_test'
));

ALTER TABLE billing.subscriptions
ADD CONSTRAINT subscriptions_status_check
CHECK (status IN (
    'active',
    'cancelled',
    'past_due',
    'trialing',
    'incomplete',
    'incomplete_expired',
    'unpaid',
    'paused'
));

-- 3. VERIFICAR SE FUNCIONOU
SELECT 'Constraints atualizadas com sucesso!' as status;
