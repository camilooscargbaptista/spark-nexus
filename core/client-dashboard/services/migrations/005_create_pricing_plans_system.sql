-- ================================================
-- Migration: 005_create_pricing_plans_system
-- Description: Sistema completo de planos, preços e assinaturas
-- Author: Spark Nexus Team
-- Date: 2025-01-12
-- ================================================

-- ================================================
-- CRIAR SCHEMA billing SE NÃO EXISTIR
-- ================================================
CREATE SCHEMA IF NOT EXISTS billing;

-- ================================================
-- TABELA DE PLANOS
-- ================================================
DROP TABLE IF EXISTS billing.plans CASCADE;

CREATE TABLE billing.plans (
    id SERIAL PRIMARY KEY,
    plan_key VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('one_time', 'subscription')),
    period VARCHAR(20) CHECK (period IN ('monthly', 'yearly', NULL)),
    emails_limit INTEGER NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    original_price DECIMAL(10,2), -- Para planos anuais, mostrar preço original
    price_per_month DECIMAL(10,2), -- Para planos anuais
    price_per_email DECIMAL(10,4),
    discount_percentage INTEGER DEFAULT 0,
    savings_amount DECIMAL(10,2),
    features JSONB DEFAULT '[]'::JSONB,
    benefits JSONB DEFAULT '[]'::JSONB,
    is_popular BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_price_positive CHECK (price > 0),
    CONSTRAINT check_emails_positive CHECK (emails_limit > 0)
);

-- Índices
CREATE INDEX idx_plans_type ON billing.plans(type);
CREATE INDEX idx_plans_period ON billing.plans(period);
CREATE INDEX idx_plans_active ON billing.plans(is_active);
CREATE INDEX idx_plans_popular ON billing.plans(is_popular);
CREATE INDEX idx_plans_key ON billing.plans(plan_key);

-- Comentários
COMMENT ON TABLE billing.plans IS 'Tabela de planos disponíveis para contratação';
COMMENT ON COLUMN billing.plans.plan_key IS 'Chave única do plano (ex: monthly_5k, yearly_10k)';
COMMENT ON COLUMN billing.plans.type IS 'Tipo: one_time (avulso) ou subscription (assinatura)';
COMMENT ON COLUMN billing.plans.period IS 'Período: monthly, yearly ou NULL para one_time';

-- ================================================
-- TABELA DE FEATURES DOS PLANOS
-- ================================================
DROP TABLE IF EXISTS billing.plan_features CASCADE;

CREATE TABLE billing.plan_features (
    id SERIAL PRIMARY KEY,
    feature_key VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX idx_plan_features_key ON billing.plan_features(feature_key);
CREATE INDEX idx_plan_features_category ON billing.plan_features(category);

-- ================================================
-- TABELA DE RELAÇÃO PLANO-FEATURES
-- ================================================
DROP TABLE IF EXISTS billing.plan_features_mapping CASCADE;

CREATE TABLE billing.plan_features_mapping (
    id SERIAL PRIMARY KEY,
    plan_id INTEGER NOT NULL REFERENCES billing.plans(id) ON DELETE CASCADE,
    feature_id INTEGER NOT NULL REFERENCES billing.plan_features(id) ON DELETE CASCADE,
    value VARCHAR(255), -- Valor da feature (ex: "5 usuários", "Ilimitado", etc)
    is_included BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_plan_feature UNIQUE(plan_id, feature_id)
);

-- Índices
CREATE INDEX idx_plan_features_mapping_plan ON billing.plan_features_mapping(plan_id);
CREATE INDEX idx_plan_features_mapping_feature ON billing.plan_features_mapping(feature_id);

-- ================================================
-- TABELA DE ASSINATURAS
-- ================================================
DROP TABLE IF EXISTS billing.subscriptions CASCADE;

CREATE TABLE billing.subscriptions (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    plan_id INTEGER NOT NULL REFERENCES billing.plans(id),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN (
        'active', 'cancelled', 'expired', 'suspended', 'trialing', 'past_due'
    )),
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    trial_end_date DATE,
    renewal_date DATE,
    cancelled_at TIMESTAMP,
    cancel_reason TEXT,
    payment_method VARCHAR(50),
    payment_gateway VARCHAR(50), -- stripe, pagseguro, etc
    gateway_customer_id VARCHAR(255),
    gateway_subscription_id VARCHAR(255),
    last_payment_date TIMESTAMP,
    next_payment_date TIMESTAMP,
    amount DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'BRL',
    auto_renew BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Índices
CREATE INDEX idx_subscriptions_org ON billing.subscriptions(organization_id);
CREATE INDEX idx_subscriptions_plan ON billing.subscriptions(plan_id);
CREATE INDEX idx_subscriptions_status ON billing.subscriptions(status);
CREATE INDEX idx_subscriptions_dates ON billing.subscriptions(start_date, end_date);
CREATE INDEX idx_subscriptions_gateway ON billing.subscriptions(payment_gateway, gateway_subscription_id);

-- ================================================
-- TABELA DE TRANSAÇÕES/PAGAMENTOS
-- ================================================
DROP TABLE IF EXISTS billing.transactions CASCADE;

CREATE TABLE billing.transactions (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    subscription_id INTEGER REFERENCES billing.subscriptions(id) ON DELETE SET NULL,
    plan_id INTEGER REFERENCES billing.plans(id),
    type VARCHAR(20) NOT NULL CHECK (type IN (
        'payment', 'refund', 'credit', 'debit', 'adjustment'
    )),
    status VARCHAR(20) NOT NULL CHECK (status IN (
        'pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded'
    )),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'BRL',
    description TEXT,
    payment_method VARCHAR(50),
    payment_gateway VARCHAR(50),
    gateway_transaction_id VARCHAR(255),
    gateway_response JSONB,
    reference_number VARCHAR(100),
    invoice_number VARCHAR(100),
    paid_at TIMESTAMP,
    failed_at TIMESTAMP,
    refunded_at TIMESTAMP,
    metadata JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX idx_transactions_org ON billing.transactions(organization_id);
CREATE INDEX idx_transactions_subscription ON billing.transactions(subscription_id);
CREATE INDEX idx_transactions_status ON billing.transactions(status);
CREATE INDEX idx_transactions_type ON billing.transactions(type);
CREATE INDEX idx_transactions_gateway ON billing.transactions(payment_gateway, gateway_transaction_id);
CREATE INDEX idx_transactions_dates ON billing.transactions(created_at DESC);

-- ================================================
-- TABELA DE HISTÓRICO DE USO
-- ================================================
DROP TABLE IF EXISTS billing.usage_history CASCADE;

CREATE TABLE billing.usage_history (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    subscription_id INTEGER REFERENCES billing.subscriptions(id) ON DELETE SET NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    emails_validated INTEGER DEFAULT 0,
    emails_limit INTEGER,
    overage_count INTEGER DEFAULT 0,
    overage_charge DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_org_period UNIQUE(organization_id, period_start, period_end)
);

-- Índices
CREATE INDEX idx_usage_history_org ON billing.usage_history(organization_id);
CREATE INDEX idx_usage_history_period ON billing.usage_history(period_start, period_end);

-- ================================================
-- INSERIR DADOS DOS PLANOS
-- ================================================

-- PLANOS AVULSOS (ONE TIME)
INSERT INTO billing.plans (
    plan_key, name, type, period, emails_limit, price, price_per_email,
    features, display_order, is_active
) VALUES
    ('onetime_1k', 'Pacote Starter', 'one_time', NULL, 1000, 49.99, 0.050,
     '["1.000 validações", "Relatório completo", "Suporte por email", "Validade: 30 dias", "Sem recorrência"]'::JSONB,
     1, true),

    ('onetime_5k', 'Pacote Basic', 'one_time', NULL, 5000, 99.99, 0.020,
     '["5.000 validações", "Relatório premium", "Suporte prioritário", "Validade: 60 dias", "Sem recorrência"]'::JSONB,
     2, true);

-- PLANOS MENSAIS
INSERT INTO billing.plans (
    plan_key, name, type, period, emails_limit, price, price_per_email,
    features, is_popular, display_order, is_active
) VALUES
    -- Starter
    ('monthly_1k', 'Starter', 'subscription', 'monthly', 1000, 39.99, 0.040,
     '["1.000 emails/mês", "Relatórios ilimitados", "Suporte por email", "API básica", "Dashboard simples"]'::JSONB,
     false, 10, true),

    -- Basic
    ('monthly_5k', 'Basic', 'subscription', 'monthly', 5000, 79.99, 0.016,
     '["5.000 emails/mês", "Relatórios ilimitados", "Suporte prioritário", "API completa", "Dashboard avançado"]'::JSONB,
     false, 20, true),

    -- Professional
    ('monthly_6k', 'Professional', 'subscription', 'monthly', 6000, 89.99, 0.015,
     '["6.000 emails/mês", "Relatórios ilimitados", "Suporte prioritário", "API completa", "Dashboard avançado", "Webhooks"]'::JSONB,
     false, 30, true),

    -- Professional Plus
    ('monthly_7k', 'Professional Plus', 'subscription', 'monthly', 7000, 99.99, 0.014,
     '["7.000 emails/mês", "Todos recursos Professional", "Integração Zapier"]'::JSONB,
     false, 40, true),

    -- Business
    ('monthly_8k', 'Business', 'subscription', 'monthly', 8000, 109.99, 0.014,
     '["8.000 emails/mês", "Todos recursos", "Multi-usuários (3)"]'::JSONB,
     false, 50, true),

    -- Business Plus
    ('monthly_9k', 'Business Plus', 'subscription', 'monthly', 9000, 119.99, 0.013,
     '["9.000 emails/mês", "Todos recursos Business", "Multi-usuários (5)"]'::JSONB,
     false, 60, true),

    -- Growth (POPULAR)
    ('monthly_10k', 'Growth', 'subscription', 'monthly', 10000, 129.99, 0.013,
     '["10.000 emails/mês", "Todos os recursos", "Suporte VIP", "Multi-usuários (5)", "White label básico"]'::JSONB,
     true, 70, true),

    -- Scale
    ('monthly_15k', 'Scale', 'subscription', 'monthly', 15000, 179.99, 0.012,
     '["15.000 emails/mês", "Todos os recursos", "Suporte VIP", "Multi-usuários (10)", "White label completo"]'::JSONB,
     false, 80, true),

    -- Scale Plus
    ('monthly_20k', 'Scale Plus', 'subscription', 'monthly', 20000, 229.99, 0.011,
     '["20.000 emails/mês", "Todos recursos Scale", "Account manager"]'::JSONB,
     false, 90, true),

    -- Enterprise
    ('monthly_30k', 'Enterprise', 'subscription', 'monthly', 30000, 329.99, 0.011,
     '["30.000 emails/mês", "Account manager dedicado", "SLA garantido", "Usuários ilimitados"]'::JSONB,
     false, 100, true),

    -- Enterprise Plus
    ('monthly_40k', 'Enterprise Plus', 'subscription', 'monthly', 40000, 419.99, 0.010,
     '["40.000 emails/mês", "Todos recursos Enterprise", "Servidor dedicado"]'::JSONB,
     false, 110, true),

    -- Corporate
    ('monthly_50k', 'Corporate', 'subscription', 'monthly', 50000, 499.99, 0.010,
     '["50.000 emails/mês", "Todos recursos Enterprise Plus", "Consultoria mensal"]'::JSONB,
     false, 120, true),

    -- Corporate Max
    ('monthly_100k', 'Corporate Max', 'subscription', 'monthly', 100000, 899.99, 0.009,
     '["100.000 emails/mês", "Infraestrutura dedicada", "Consultoria semanal", "Desenvolvimento personalizado"]'::JSONB,
     false, 130, true);

-- PLANOS ANUAIS (25% de desconto)
INSERT INTO billing.plans (
    plan_key, name, type, period, emails_limit, price, original_price,
    price_per_month, price_per_email, discount_percentage, savings_amount,
    features, is_popular, display_order, is_active
) VALUES
    -- Starter Anual
    ('yearly_1k', 'Starter Anual', 'subscription', 'yearly', 1000, 359.99, 479.88,
     30.00, 0.030, 25, 119.89,
     '["1.000 emails/mês", "25% de economia", "Todos recursos do plano mensal", "2 meses grátis de bônus"]'::JSONB,
     false, 200, true),

    -- Basic Anual
    ('yearly_5k', 'Basic Anual', 'subscription', 'yearly', 5000, 719.99, 959.88,
     60.00, 0.012, 25, 239.89,
     '["5.000 emails/mês", "25% de economia", "Todos recursos do plano mensal", "2 meses grátis de bônus"]'::JSONB,
     false, 210, true),

    -- Professional Anual
    ('yearly_6k', 'Professional Anual', 'subscription', 'yearly', 6000, 809.99, 1079.88,
     67.50, 0.011, 25, 269.89,
     '["6.000 emails/mês", "25% de economia", "Todos recursos Professional"]'::JSONB,
     false, 220, true),

    -- Professional Plus Anual
    ('yearly_7k', 'Professional Plus Anual', 'subscription', 'yearly', 7000, 899.99, 1199.88,
     75.00, 0.011, 25, 299.89,
     '["7.000 emails/mês", "25% de economia", "Todos recursos Professional Plus"]'::JSONB,
     false, 230, true),

    -- Business Anual
    ('yearly_8k', 'Business Anual', 'subscription', 'yearly', 8000, 989.99, 1319.88,
     82.50, 0.010, 25, 329.89,
     '["8.000 emails/mês", "25% de economia", "Todos recursos Business"]'::JSONB,
     false, 240, true),

    -- Business Plus Anual
    ('yearly_9k', 'Business Plus Anual', 'subscription', 'yearly', 9000, 1079.99, 1439.88,
     90.00, 0.010, 25, 359.89,
     '["9.000 emails/mês", "25% de economia", "Todos recursos Business Plus"]'::JSONB,
     false, 250, true),

    -- Growth Anual (POPULAR)
    ('yearly_10k', 'Growth Anual', 'subscription', 'yearly', 10000, 1169.99, 1559.88,
     97.50, 0.010, 25, 389.89,
     '["10.000 emails/mês", "25% de economia", "Todos recursos Growth"]'::JSONB,
     true, 260, true),

    -- Scale Anual
    ('yearly_15k', 'Scale Anual', 'subscription', 'yearly', 15000, 1619.99, 2159.88,
     135.00, 0.009, 25, 539.89,
     '["15.000 emails/mês", "25% de economia", "Todos recursos Scale"]'::JSONB,
     false, 270, true),

    -- Scale Plus Anual
    ('yearly_20k', 'Scale Plus Anual', 'subscription', 'yearly', 20000, 2069.99, 2759.88,
     172.50, 0.009, 25, 689.89,
     '["20.000 emails/mês", "25% de economia", "Todos recursos Scale Plus"]'::JSONB,
     false, 280, true),

    -- Enterprise Anual
    ('yearly_30k', 'Enterprise Anual', 'subscription', 'yearly', 30000, 2969.99, 3959.88,
     247.50, 0.008, 25, 989.89,
     '["30.000 emails/mês", "25% de economia", "Todos recursos Enterprise"]'::JSONB,
     false, 290, true),

    -- Enterprise Plus Anual
    ('yearly_40k', 'Enterprise Plus Anual', 'subscription', 'yearly', 40000, 3779.99, 5039.88,
     315.00, 0.008, 25, 1259.89,
     '["40.000 emails/mês", "25% de economia", "Todos recursos Enterprise Plus"]'::JSONB,
     false, 300, true),

    -- Corporate Anual
    ('yearly_50k', 'Corporate Anual', 'subscription', 'yearly', 50000, 4499.99, 5999.88,
     375.00, 0.007, 25, 1499.89,
     '["50.000 emails/mês", "25% de economia", "Todos recursos Corporate"]'::JSONB,
     false, 310, true),

    -- Corporate Max Anual
    ('yearly_100k', 'Corporate Max Anual', 'subscription', 'yearly', 100000, 8099.99, 10799.88,
     675.00, 0.007, 25, 2699.89,
     '["100.000 emails/mês", "25% de economia", "Todos recursos Corporate Max"]'::JSONB,
     false, 320, true);

-- ================================================
-- INSERIR FEATURES PADRÃO
-- ================================================
INSERT INTO billing.plan_features (feature_key, name, description, category, display_order) VALUES
    ('validations', 'Validações Mensais', 'Quantidade de emails que podem ser validados por mês', 'quota', 10),
    ('api_access', 'Acesso à API', 'Acesso completo à API REST', 'technical', 20),
    ('dashboard', 'Dashboard', 'Painel de controle para visualização de dados', 'interface', 30),
    ('reports', 'Relatórios', 'Relatórios detalhados em Excel', 'reports', 40),
    ('support', 'Suporte', 'Nível de suporte disponível', 'support', 50),
    ('users', 'Usuários', 'Quantidade de usuários permitidos', 'access', 60),
    ('webhooks', 'Webhooks', 'Integração via webhooks', 'integration', 70),
    ('white_label', 'White Label', 'Personalização com sua marca', 'branding', 80),
    ('sla', 'SLA', 'Acordo de nível de serviço', 'guarantee', 90),
    ('dedicated_server', 'Servidor Dedicado', 'Infraestrutura dedicada', 'infrastructure', 100);

-- ================================================
-- FUNÇÕES AUXILIARES
-- ================================================

-- Função para obter o melhor plano baseado no volume
CREATE OR REPLACE FUNCTION billing.get_best_plan(
    p_emails_needed INTEGER,
    p_period VARCHAR(20) DEFAULT 'monthly'
)
RETURNS TABLE (
    plan_id INTEGER,
    plan_key VARCHAR(50),
    plan_name VARCHAR(100),
    emails_limit INTEGER,
    price DECIMAL(10,2),
    price_per_email DECIMAL(10,4),
    savings DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.plan_key,
        p.name,
        p.emails_limit,
        p.price,
        p.price_per_email,
        p.savings_amount
    FROM billing.plans p
    WHERE p.type = 'subscription'
    AND p.period = p_period
    AND p.emails_limit >= p_emails_needed
    AND p.is_active = true
    ORDER BY p.price_per_email ASC, p.price ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Função para calcular economia anual vs mensal
CREATE OR REPLACE FUNCTION billing.calculate_yearly_savings(
    p_monthly_plan_key VARCHAR(50)
)
RETURNS TABLE (
    monthly_total DECIMAL(10,2),
    yearly_total DECIMAL(10,2),
    total_savings DECIMAL(10,2),
    savings_percentage INTEGER
) AS $$
DECLARE
    v_monthly_price DECIMAL(10,2);
    v_yearly_price DECIMAL(10,2);
    v_yearly_key VARCHAR(50);
BEGIN
    -- Construir chave do plano anual
    v_yearly_key := REPLACE(p_monthly_plan_key, 'monthly_', 'yearly_');

    -- Obter preços
    SELECT price INTO v_monthly_price
    FROM billing.plans
    WHERE plan_key = p_monthly_plan_key;

    SELECT price INTO v_yearly_price
    FROM billing.plans
    WHERE plan_key = v_yearly_key;

    IF v_monthly_price IS NOT NULL AND v_yearly_price IS NOT NULL THEN
        RETURN QUERY SELECT
            v_monthly_price * 12,
            v_yearly_price,
            (v_monthly_price * 12) - v_yearly_price,
            ROUND(((v_monthly_price * 12 - v_yearly_price) / (v_monthly_price * 12)) * 100)::INTEGER;
    ELSE
        RETURN QUERY SELECT
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            0::INTEGER;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Função para verificar limite de validações
CREATE OR REPLACE FUNCTION billing.check_validation_limit(
    p_organization_id INTEGER,
    p_validations_needed INTEGER DEFAULT 1
)
RETURNS TABLE (
    allowed BOOLEAN,
    current_limit INTEGER,
    used_count INTEGER,
    remaining INTEGER,
    message TEXT
) AS $$
DECLARE
    v_subscription RECORD;
    v_current_usage INTEGER;
BEGIN
    -- Obter assinatura ativa
    SELECT
        s.id,
        p.emails_limit,
        s.start_date,
        s.end_date
    INTO v_subscription
    FROM billing.subscriptions s
    JOIN billing.plans p ON s.plan_id = p.id
    WHERE s.organization_id = p_organization_id
    AND s.status = 'active'
    AND (s.end_date IS NULL OR s.end_date >= CURRENT_DATE)
    ORDER BY s.created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN QUERY SELECT
            false,
            0,
            0,
            0,
            'Nenhuma assinatura ativa encontrada';
        RETURN;
    END IF;

    -- Obter uso atual do mês
    SELECT COALESCE(emails_validated, 0)
    INTO v_current_usage
    FROM billing.usage_history
    WHERE organization_id = p_organization_id
    AND period_start = DATE_TRUNC('month', CURRENT_DATE)
    AND subscription_id = v_subscription.id;

    IF v_current_usage IS NULL THEN
        v_current_usage := 0;
    END IF;

    RETURN QUERY SELECT
        (v_current_usage + p_validations_needed) <= v_subscription.emails_limit,
        v_subscription.emails_limit,
        v_current_usage,
        v_subscription.emails_limit - v_current_usage,
        CASE
            WHEN (v_current_usage + p_validations_needed) <= v_subscription.emails_limit THEN
                format('%s validações disponíveis de %s',
                       v_subscription.emails_limit - v_current_usage,
                       v_subscription.emails_limit)
            ELSE
                format('Limite excedido. Apenas %s validações restantes de %s',
                       GREATEST(v_subscription.emails_limit - v_current_usage, 0),
                       v_subscription.emails_limit)
        END;
END;
$$ LANGUAGE plpgsql;

-- ================================================
-- VIEWS ÚTEIS
-- ================================================

-- View de planos com comparação
CREATE OR REPLACE VIEW billing.v_plans_comparison AS
SELECT
    p.plan_key,
    p.name,
    p.type,
    p.period,
    p.emails_limit,
    p.price,
    p.price_per_email,
    p.discount_percentage,
    p.savings_amount,
    p.is_popular,
    CASE
        WHEN p.period = 'yearly' THEN p.price / 12
        ELSE p.price
    END as monthly_equivalent,
    p.features,
    p.display_order
FROM billing.plans p
WHERE p.is_active = true
ORDER BY p.display_order;

-- View de assinaturas ativas
CREATE OR REPLACE VIEW billing.v_active_subscriptions AS
SELECT
    s.id,
    s.organization_id,
    o.name as organization_name,
    p.name as plan_name,
    p.emails_limit,
    s.status,
    s.start_date,
    s.end_date,
    s.renewal_date,
    s.auto_renew,
    p.price as plan_price,
    CASE
        WHEN p.period = 'yearly' THEN 'Anual'
        WHEN p.period = 'monthly' THEN 'Mensal'
        ELSE 'Avulso'
    END as billing_period
FROM billing.subscriptions s
JOIN billing.plans p ON s.plan_id = p.id
JOIN tenant.organizations o ON s.organization_id = o.id
WHERE s.status = 'active'
AND (s.end_date IS NULL OR s.end_date >= CURRENT_DATE);

-- ================================================
-- GRANT PERMISSIONS
-- ================================================
GRANT ALL ON SCHEMA billing TO sparknexus;
GRANT ALL ON ALL TABLES IN SCHEMA billing TO sparknexus;
GRANT ALL ON ALL SEQUENCES IN SCHEMA billing TO sparknexus;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA billing TO sparknexus;

-- ================================================
-- TESTES DE VALIDAÇÃO
-- ================================================
DO $$
DECLARE
    v_test_result RECORD;
    v_plan_count INTEGER;
BEGIN
    -- Verificar se os planos foram inseridos
    SELECT COUNT(*) INTO v_plan_count FROM billing.plans;
    RAISE NOTICE 'Total de planos criados: %', v_plan_count;

    -- Testar função get_best_plan
    SELECT * INTO v_test_result
    FROM billing.get_best_plan(7500, 'monthly');

    IF v_test_result.plan_id IS NOT NULL THEN
        RAISE NOTICE 'Melhor plano para 7500 emails/mês: % (R$ %)',
                     v_test_result.plan_name, v_test_result.price;
    END IF;

    -- Testar cálculo de economia
    SELECT * INTO v_test_result
    FROM billing.calculate_yearly_savings('monthly_10k');

    IF v_test_result.total_savings IS NOT NULL THEN
        RAISE NOTICE 'Economia anual no plano Growth: R$ % (%s%%)',
                     v_test_result.total_savings, v_test_result.savings_percentage;
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 005_create_pricing_plans_system aplicada com sucesso!';
    RAISE NOTICE '';
    RAISE NOTICE 'Resumo da criação:';
    RAISE NOTICE '  ✓ Schema billing criado';
    RAISE NOTICE '  ✓ Tabela de planos com % registros', v_plan_count;
    RAISE NOTICE '  ✓ Tabelas de assinaturas e transações criadas';
    RAISE NOTICE '  ✓ Funções auxiliares implementadas';
    RAISE NOTICE '  ✓ Views de consulta criadas';
    RAISE NOTICE '  ✓ Permissões concedidas';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erro na migration: %', SQLERRM;
END $$;
