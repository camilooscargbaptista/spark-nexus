-- ================================================
-- MIGRAÇÃO: SISTEMA CORRETO DE CRÉDITOS
-- ================================================

-- Adicionar novas colunas para o sistema correto de créditos
ALTER TABLE tenant.organizations 
ADD COLUMN IF NOT EXISTS balance_credits INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS monthly_credits INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_validations_ever INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS credits_last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Comentários para documentar as colunas
COMMENT ON COLUMN tenant.organizations.balance_credits IS 'Créditos acumulados disponíveis (inclui mensais + compras avulsas)';
COMMENT ON COLUMN tenant.organizations.monthly_credits IS 'Créditos mensais do plano de assinatura';
COMMENT ON COLUMN tenant.organizations.total_validations_ever IS 'Contador total de validações já realizadas (histórico)';
COMMENT ON COLUMN tenant.organizations.max_validations IS 'DEPRECATED - Usar balance_credits';
COMMENT ON COLUMN tenant.organizations.validations_used IS 'DEPRECATED - Usar total_validations_ever';

-- Migrar dados existentes para nova estrutura
UPDATE tenant.organizations 
SET 
    balance_credits = GREATEST(0, max_validations - COALESCE(validations_used, 0)),
    total_validations_ever = COALESCE(validations_used, 0),
    monthly_credits = CASE 
        WHEN plan LIKE '%1k%' OR plan LIKE '%1000%' THEN 1000
        WHEN plan LIKE '%5k%' OR plan LIKE '%5000%' THEN 5000
        WHEN plan LIKE '%10k%' OR plan LIKE '%10000%' THEN 10000
        WHEN plan LIKE '%unlimited%' THEN 50000
        ELSE 0
    END
WHERE balance_credits IS NULL OR balance_credits = 0;

-- Criar tabela para histórico de créditos
CREATE TABLE IF NOT EXISTS tenant.credit_history (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    credit_type VARCHAR(20) NOT NULL CHECK (credit_type IN ('monthly', 'purchase', 'bonus', 'usage')),
    amount INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    description TEXT,
    stripe_session_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES auth.users(id)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_credit_history_org_id ON tenant.credit_history(organization_id);
CREATE INDEX IF NOT EXISTS idx_credit_history_created_at ON tenant.credit_history(created_at);
CREATE INDEX IF NOT EXISTS idx_credit_history_type ON tenant.credit_history(credit_type);

-- Função para adicionar créditos e registrar histórico
CREATE OR REPLACE FUNCTION tenant.add_credits(
    p_organization_id INTEGER,
    p_amount INTEGER,
    p_credit_type VARCHAR(20),
    p_description TEXT DEFAULT NULL,
    p_stripe_session_id VARCHAR(255) DEFAULT NULL,
    p_created_by INTEGER DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_new_balance INTEGER;
BEGIN
    -- Atualizar créditos da organização
    UPDATE tenant.organizations 
    SET 
        balance_credits = balance_credits + p_amount,
        credits_last_updated = CURRENT_TIMESTAMP
    WHERE id = p_organization_id
    RETURNING balance_credits INTO v_new_balance;
    
    -- Registrar no histórico
    INSERT INTO tenant.credit_history (
        organization_id, credit_type, amount, balance_after, 
        description, stripe_session_id, created_by
    ) VALUES (
        p_organization_id, p_credit_type, p_amount, v_new_balance,
        p_description, p_stripe_session_id, p_created_by
    );
    
    RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql;

-- Função para usar créditos
CREATE OR REPLACE FUNCTION tenant.use_credits(
    p_organization_id INTEGER,
    p_amount INTEGER,
    p_description TEXT DEFAULT 'Validação de emails'
) RETURNS INTEGER AS $$
DECLARE
    v_current_balance INTEGER;
    v_new_balance INTEGER;
BEGIN
    -- Verificar saldo atual
    SELECT balance_credits INTO v_current_balance
    FROM tenant.organizations 
    WHERE id = p_organization_id;
    
    IF v_current_balance IS NULL THEN
        RAISE EXCEPTION 'Organização não encontrada';
    END IF;
    
    IF v_current_balance < p_amount THEN
        RAISE EXCEPTION 'Créditos insuficientes. Disponível: %, Necessário: %', v_current_balance, p_amount;
    END IF;
    
    -- Atualizar créditos e contador total
    UPDATE tenant.organizations 
    SET 
        balance_credits = balance_credits - p_amount,
        total_validations_ever = total_validations_ever + p_amount,
        credits_last_updated = CURRENT_TIMESTAMP
    WHERE id = p_organization_id
    RETURNING balance_credits INTO v_new_balance;
    
    -- Registrar no histórico
    INSERT INTO tenant.credit_history (
        organization_id, credit_type, amount, balance_after, description
    ) VALUES (
        p_organization_id, 'usage', -p_amount, v_new_balance, p_description
    );
    
    RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql;

-- Função para creditar mensalmente (para job/cron)
CREATE OR REPLACE FUNCTION tenant.credit_monthly_allowance() RETURNS INTEGER AS $$
DECLARE
    v_processed INTEGER := 0;
    org_record RECORD;
BEGIN
    -- Processar organizações com assinaturas ativas
    FOR org_record IN 
        SELECT o.id, o.monthly_credits, o.name
        FROM tenant.organizations o
        WHERE o.monthly_credits > 0 
        AND o.is_active = TRUE
        AND (
            o.credits_last_updated IS NULL 
            OR DATE_TRUNC('month', o.credits_last_updated) < DATE_TRUNC('month', CURRENT_TIMESTAMP)
        )
    LOOP
        PERFORM tenant.add_credits(
            org_record.id,
            org_record.monthly_credits,
            'monthly',
            'Créditos mensais da assinatura - ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM')
        );
        
        v_processed := v_processed + 1;
    END LOOP;
    
    RETURN v_processed;
END;
$$ LANGUAGE plpgsql;

-- Log da migração
INSERT INTO tenant.credit_history (organization_id, credit_type, amount, balance_after, description)
SELECT 
    id,
    'bonus',
    balance_credits,
    balance_credits,
    'Migração do sistema de créditos - dados transferidos'
FROM tenant.organizations 
WHERE balance_credits > 0;

RAISE NOTICE 'Sistema de créditos migrado com sucesso!';