-- ================================================
-- Migration: 000_complete_setup
-- Migration consolidada e corrigida
-- ================================================

-- Adicionar colunas de quota se não existirem
ALTER TABLE tenant.organizations ADD COLUMN IF NOT EXISTS max_validations INTEGER DEFAULT 1000;
ALTER TABLE tenant.organizations ADD COLUMN IF NOT EXISTS validations_used INTEGER DEFAULT 0;
ALTER TABLE tenant.organizations ADD COLUMN IF NOT EXISTS last_reset_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE tenant.organizations ADD COLUMN IF NOT EXISTS billing_cycle_day INTEGER DEFAULT 1 CHECK (billing_cycle_day >= 1 AND billing_cycle_day <= 28);
ALTER TABLE tenant.organizations ADD COLUMN IF NOT EXISTS quota_reset_count INTEGER DEFAULT 0;
ALTER TABLE tenant.organizations ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE tenant.organizations ADD COLUMN IF NOT EXISTS settings JSONB DEFAULT '{}';
ALTER TABLE tenant.organizations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Adicionar coluna em organization_members
ALTER TABLE tenant.organization_members ADD COLUMN IF NOT EXISTS joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Criar índices se não existirem
CREATE INDEX IF NOT EXISTS idx_organizations_last_reset ON tenant.organizations(last_reset_date);
CREATE INDEX IF NOT EXISTS idx_organizations_billing_day ON tenant.organizations(billing_cycle_day);
CREATE INDEX IF NOT EXISTS idx_organizations_validations ON tenant.organizations(validations_used, max_validations);
CREATE INDEX IF NOT EXISTS idx_organizations_is_active ON tenant.organizations(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_organizations_updated_at ON tenant.organizations(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_organizations_settings ON tenant.organizations USING GIN(settings);
CREATE INDEX IF NOT EXISTS idx_organization_members_joined_at ON tenant.organization_members(joined_at DESC);

-- Atualizar valores baseados nos planos
UPDATE tenant.organizations
SET max_validations = CASE
    WHEN plan = 'free' THEN 1000
    WHEN plan = 'starter' THEN 10000
    WHEN plan = 'professional' THEN 50000
    WHEN plan = 'enterprise' THEN 999999
    ELSE 1000
END
WHERE max_validations = 1000;

-- Criar tabela quota_history se não existir
CREATE TABLE IF NOT EXISTS tenant.quota_history (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    month DATE NOT NULL,
    validations_used INTEGER DEFAULT 0,
    max_validations INTEGER,
    reset_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reset_reason VARCHAR(50) DEFAULT 'monthly',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_org_month UNIQUE (organization_id, month)
);

-- Criar função de trigger para updated_at
CREATE OR REPLACE FUNCTION tenant.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger
DROP TRIGGER IF EXISTS update_organizations_updated_at ON tenant.organizations;
CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON tenant.organizations
    FOR EACH ROW
    EXECUTE FUNCTION tenant.update_updated_at_column();

-- Criar funções com INTEGER (não UUID)
CREATE OR REPLACE FUNCTION tenant.increment_validation_usage(
    p_organization_id INTEGER,
    p_count INTEGER DEFAULT 1
)
RETURNS TABLE (
    success BOOLEAN,
    remaining INTEGER,
    message TEXT
) AS $$
DECLARE
    v_current_used INTEGER;
    v_max_allowed INTEGER;
    v_new_used INTEGER;
BEGIN
    SELECT validations_used, max_validations
    INTO v_current_used, v_max_allowed
    FROM tenant.organizations
    WHERE id = p_organization_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 0, 'Organização não encontrada';
        RETURN;
    END IF;

    v_new_used := COALESCE(v_current_used, 0) + COALESCE(p_count, 1);

    IF v_new_used > v_max_allowed THEN
        RETURN QUERY SELECT 
            false,
            GREATEST(v_max_allowed - v_current_used, 0),
            format('Limite excedido. Restam %s validações.', GREATEST(v_max_allowed - v_current_used, 0));
        RETURN;
    END IF;

    UPDATE tenant.organizations
    SET validations_used = v_new_used
    WHERE id = p_organization_id;

    RETURN QUERY SELECT
        true,
        v_max_allowed - v_new_used,
        format('Sucesso. Restam %s de %s validações.', v_max_allowed - v_new_used, v_max_allowed);
END;
$$ LANGUAGE plpgsql;

-- Grants
GRANT ALL ON TABLE tenant.quota_history TO sparknexus;
GRANT ALL ON FUNCTION tenant.increment_validation_usage(INTEGER, INTEGER) TO sparknexus;
GRANT ALL ON FUNCTION tenant.update_updated_at_column() TO sparknexus;

-- Mensagem de sucesso
DO $$
BEGIN
    RAISE NOTICE 'Migration 000_complete_setup executada com sucesso!';
END $$;
