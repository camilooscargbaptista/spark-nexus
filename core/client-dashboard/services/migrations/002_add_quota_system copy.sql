-- ================================================
-- Migration: 001_add_quota_system
-- Description: Adiciona sistema de controle de quotas mensais
-- Author: Spark Nexus Team
-- Date: 2025-01-11
-- ================================================

-- ================================================
-- ADICIONAR COLUNAS DE QUOTA EM ORGANIZATIONS
-- ================================================

-- Coluna: max_validations (limite mensal)
ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS max_validations INTEGER DEFAULT 1000;

COMMENT ON COLUMN tenant.organizations.max_validations IS
'Limite máximo de validações de email por mês para esta organização';

-- Coluna: validations_used (contador atual)
ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS validations_used INTEGER DEFAULT 0;

COMMENT ON COLUMN tenant.organizations.validations_used IS
'Quantidade de validações já utilizadas no mês atual';

-- Coluna: last_reset_date (controle de reset)
ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS last_reset_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

COMMENT ON COLUMN tenant.organizations.last_reset_date IS
'Data e hora do último reset do contador de validações';

-- Coluna: billing_cycle_day (dia do reset mensal)
ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS billing_cycle_day INTEGER DEFAULT 1
CHECK (billing_cycle_day >= 1 AND billing_cycle_day <= 28);

COMMENT ON COLUMN tenant.organizations.billing_cycle_day IS
'Dia do mês para reset automático do contador (1-28)';

-- Coluna: quota_reset_count (histórico de resets)
ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS quota_reset_count INTEGER DEFAULT 0;

COMMENT ON COLUMN tenant.organizations.quota_reset_count IS
'Contador de quantos resets já foram realizados';

-- ================================================
-- CRIAR ÍNDICES PARA PERFORMANCE
-- ================================================

CREATE INDEX IF NOT EXISTS idx_organizations_last_reset
ON tenant.organizations(last_reset_date);

CREATE INDEX IF NOT EXISTS idx_organizations_billing_day
ON tenant.organizations(billing_cycle_day);

CREATE INDEX IF NOT EXISTS idx_organizations_validations
ON tenant.organizations(validations_used, max_validations);

-- ================================================
-- ATUALIZAR LIMITES BASEADOS NOS PLANOS
-- ================================================

UPDATE tenant.organizations
SET max_validations = CASE
    WHEN plan = 'free' THEN 1000
    WHEN plan = 'starter' THEN 10000
    WHEN plan = 'professional' THEN 50000
    WHEN plan = 'enterprise' THEN 999999
    WHEN plan = 'premium' THEN 100000  -- caso exista plano premium
    ELSE 1000  -- default para planos não reconhecidos
END
WHERE max_validations IS NULL OR max_validations = 1000;

-- Inicializar last_reset_date para início do mês atual
UPDATE tenant.organizations
SET last_reset_date = date_trunc('month', CURRENT_DATE)
WHERE last_reset_date IS NULL;

-- Resetar contadores se necessário
UPDATE tenant.organizations
SET validations_used = 0
WHERE validations_used IS NULL;

-- ================================================
-- CRIAR TABELA DE HISTÓRICO DE QUOTAS
-- ================================================

CREATE TABLE IF NOT EXISTS tenant.quota_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES tenant.organizations(id) ON DELETE CASCADE,
    month DATE NOT NULL,
    validations_used INTEGER DEFAULT 0,
    max_validations INTEGER,
    reset_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reset_reason VARCHAR(50) DEFAULT 'monthly',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_org_month UNIQUE (organization_id, month)
);

COMMENT ON TABLE tenant.quota_history IS
'Histórico mensal de uso de quotas por organização';

-- Índices para quota_history
CREATE INDEX IF NOT EXISTS idx_quota_history_org
ON tenant.quota_history(organization_id);

CREATE INDEX IF NOT EXISTS idx_quota_history_month
ON tenant.quota_history(month);

CREATE INDEX IF NOT EXISTS idx_quota_history_org_month
ON tenant.quota_history(organization_id, month DESC);

-- ================================================
-- CRIAR FUNÇÃO PARA RESET AUTOMÁTICO DE QUOTAS
-- ================================================

CREATE OR REPLACE FUNCTION tenant.reset_monthly_quotas()
RETURNS TABLE (
    org_id UUID,
    org_name VARCHAR(255),
    validations_before INTEGER,
    reset_performed BOOLEAN
) AS $$
DECLARE
    v_record RECORD;
    v_should_reset BOOLEAN;
    v_current_day INTEGER;
BEGIN
    v_current_day := DATE_PART('day', CURRENT_DATE);

    FOR v_record IN
        SELECT
            o.id,
            o.name,
            o.validations_used,
            o.max_validations,
            o.last_reset_date,
            o.billing_cycle_day
        FROM tenant.organizations o
        WHERE o.is_active = true
    LOOP
        -- Determinar se deve resetar
        v_should_reset := FALSE;

        -- Verificar se é o dia do reset OU se passou do mês sem resetar
        IF (v_current_day = v_record.billing_cycle_day) OR
           (v_record.last_reset_date < date_trunc('month', CURRENT_DATE)) THEN
            v_should_reset := TRUE;
        END IF;

        -- Se é fim do mês e o dia de reset é maior que o último dia do mês
        IF (v_record.billing_cycle_day > v_current_day) AND
           (v_current_day = DATE_PART('day', (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day')::date)) THEN
            v_should_reset := TRUE;
        END IF;

        IF v_should_reset THEN
            -- Inserir no histórico antes de resetar
            INSERT INTO tenant.quota_history (
                organization_id,
                month,
                validations_used,
                max_validations,
                reset_reason
            ) VALUES (
                v_record.id,
                date_trunc('month', v_record.last_reset_date),
                v_record.validations_used,
                v_record.max_validations,
                'monthly'
            ) ON CONFLICT (organization_id, month) DO UPDATE
            SET validations_used = EXCLUDED.validations_used,
                reset_date = CURRENT_TIMESTAMP;

            -- Resetar contador
            UPDATE tenant.organizations
            SET
                validations_used = 0,
                last_reset_date = CURRENT_TIMESTAMP,
                quota_reset_count = quota_reset_count + 1
            WHERE id = v_record.id;

            RETURN QUERY SELECT
                v_record.id,
                v_record.name,
                v_record.validations_used,
                true;
        ELSE
            RETURN QUERY SELECT
                v_record.id,
                v_record.name,
                v_record.validations_used,
                false;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tenant.reset_monthly_quotas() IS
'Reseta os contadores de validação mensais das organizações conforme billing_cycle_day';

-- ================================================
-- CRIAR FUNÇÃO PARA INCREMENTAR USO DE QUOTA
-- ================================================

CREATE OR REPLACE FUNCTION tenant.increment_validation_usage(
    p_organization_id UUID,
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
    -- Obter valores atuais com lock para evitar condições de corrida
    SELECT validations_used, max_validations
    INTO v_current_used, v_max_allowed
    FROM tenant.organizations
    WHERE id = p_organization_id
    FOR UPDATE;

    -- Verificar se encontrou a organização
    IF NOT FOUND THEN
        RETURN QUERY SELECT
            false,
            0,
            'Organização não encontrada';
        RETURN;
    END IF;

    -- Calcular novo valor
    v_new_used := v_current_used + p_count;

    -- Verificar se excede o limite
    IF v_new_used > v_max_allowed THEN
        RETURN QUERY SELECT
            false,
            v_max_allowed - v_current_used,
            format('Limite de %s validações excedido. Restam %s validações.',
                   v_max_allowed, v_max_allowed - v_current_used);
        RETURN;
    END IF;

    -- Atualizar contador
    UPDATE tenant.organizations
    SET validations_used = v_new_used
    WHERE id = p_organization_id;

    RETURN QUERY SELECT
        true,
        v_max_allowed - v_new_used,
        format('Sucesso. Restam %s validações de %s.',
               v_max_allowed - v_new_used, v_max_allowed);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tenant.increment_validation_usage(UUID, INTEGER) IS
'Incrementa o contador de validações usadas, verificando o limite';

-- ================================================
-- CRIAR VIEW PARA FACILITAR CONSULTAS
-- ================================================

CREATE OR REPLACE VIEW tenant.v_organization_quotas AS
SELECT
    o.id,
    o.name,
    o.slug,
    o.plan,
    o.max_validations,
    o.validations_used,
    o.max_validations - o.validations_used AS validations_remaining,
    ROUND((o.validations_used::NUMERIC / NULLIF(o.max_validations, 0)) * 100, 2) AS usage_percentage,
    o.last_reset_date,
    o.billing_cycle_day,
    CASE
        WHEN o.billing_cycle_day >= DATE_PART('day', CURRENT_DATE) THEN
            DATE_TRUNC('month', CURRENT_DATE) + (o.billing_cycle_day - 1) * INTERVAL '1 day'
        ELSE
            DATE_TRUNC('month', CURRENT_DATE + INTERVAL '1 month') + (o.billing_cycle_day - 1) * INTERVAL '1 day'
    END AS next_reset_date,
    o.is_active
FROM tenant.organizations o;

COMMENT ON VIEW tenant.v_organization_quotas IS
'View consolidada com informações de quota das organizações';

-- ================================================
-- GRANT PERMISSIONS
-- ================================================

-- Garantir permissões para o usuário da aplicação
GRANT ALL ON TABLE tenant.quota_history TO sparknexus;
GRANT ALL ON FUNCTION tenant.reset_monthly_quotas() TO sparknexus;
GRANT ALL ON FUNCTION tenant.increment_validation_usage(UUID, INTEGER) TO sparknexus;
GRANT SELECT ON tenant.v_organization_quotas TO sparknexus;

-- ================================================
-- VERIFICAÇÃO FINAL
-- ================================================

DO $$
DECLARE
    v_org_count INTEGER;
    v_member_count INTEGER;
BEGIN
    -- Contar registros afetados
    SELECT COUNT(*) INTO v_org_count FROM tenant.organizations;
    SELECT COUNT(*) INTO v_member_count FROM tenant.organization_members;

    RAISE NOTICE 'Migration 002_add_active_settings_joined_columns aplicada com sucesso!';
    RAISE NOTICE 'Colunas adicionadas em tenant.organizations: is_active, settings, updated_at';
    RAISE NOTICE 'Coluna adicionada em tenant.organization_members: joined_at';
    RAISE NOTICE 'Organizações afetadas: %', v_org_count;
    RAISE NOTICE 'Membros afetados: %', v_member_count;
    RAISE NOTICE 'Trigger criado: update_organizations_updated_at';
    RAISE NOTICE 'Funções criadas: update_updated_at_column(), update_organization_settings(), get_organization_setting()';
    RAISE NOTICE 'Views criadas: v_organization_details, v_organization_members_details';
END $$;
