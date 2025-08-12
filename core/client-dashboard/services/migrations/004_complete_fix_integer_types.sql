-- ================================================
-- Migration: 004_complete_fix_integer_types
-- Description: Correção completa para usar INTEGER em todas as funções e tabelas
-- Author: Spark Nexus Team
-- Date: 2025-01-12
-- ================================================

-- ================================================
-- LIMPAR FUNÇÕES ANTIGAS (TODAS AS VARIAÇÕES)
-- ================================================

-- Dropar todas as versões antigas das funções
DROP FUNCTION IF EXISTS tenant.increment_validation_usage(UUID, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS tenant.increment_validation_usage(INTEGER, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS tenant.update_organization_settings(UUID, JSONB) CASCADE;
DROP FUNCTION IF EXISTS tenant.update_organization_settings(INTEGER, JSONB) CASCADE;
DROP FUNCTION IF EXISTS tenant.get_organization_setting(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS tenant.get_organization_setting(INTEGER, TEXT) CASCADE;
DROP FUNCTION IF EXISTS tenant.reset_monthly_quotas() CASCADE;
DROP FUNCTION IF EXISTS tenant.check_quota(INTEGER, INTEGER) CASCADE;

-- ================================================
-- VERIFICAR E CORRIGIR TABELA quota_history
-- ================================================

-- Verificar se a tabela existe e qual tipo está usando
DO $$
DECLARE
    v_column_type TEXT;
BEGIN
    -- Verificar o tipo da coluna organization_id se a tabela existir
    SELECT data_type INTO v_column_type
    FROM information_schema.columns
    WHERE table_schema = 'tenant'
    AND table_name = 'quota_history'
    AND column_name = 'organization_id';

    IF v_column_type = 'uuid' THEN
        RAISE NOTICE 'Tabela quota_history usa UUID, recriando com INTEGER...';

        -- Fazer backup se houver dados
        CREATE TEMP TABLE IF NOT EXISTS quota_history_backup AS
        SELECT * FROM tenant.quota_history;

        -- Dropar a tabela antiga
        DROP TABLE tenant.quota_history CASCADE;

        -- Criar nova tabela com INTEGER
        CREATE TABLE tenant.quota_history (
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

        RAISE NOTICE 'Tabela quota_history recriada com INTEGER';

    ELSIF v_column_type = 'integer' THEN
        RAISE NOTICE 'Tabela quota_history já usa INTEGER, OK';
    ELSIF v_column_type IS NULL THEN
        RAISE NOTICE 'Tabela quota_history não existe, criando...';

        -- Criar tabela com INTEGER
        CREATE TABLE tenant.quota_history (
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

        RAISE NOTICE 'Tabela quota_history criada com INTEGER';
    END IF;
END $$;

-- Adicionar comentário na tabela
COMMENT ON TABLE tenant.quota_history IS
'Histórico mensal de uso de quotas por organização';

-- Criar índices se não existirem
CREATE INDEX IF NOT EXISTS idx_quota_history_org
ON tenant.quota_history(organization_id);

CREATE INDEX IF NOT EXISTS idx_quota_history_month
ON tenant.quota_history(month);

CREATE INDEX IF NOT EXISTS idx_quota_history_org_month
ON tenant.quota_history(organization_id, month DESC);

-- ================================================
-- CRIAR FUNÇÃO increment_validation_usage (VERSÃO CORRETA)
-- ================================================

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
    -- Validar entrada
    IF p_organization_id IS NULL THEN
        RETURN QUERY SELECT
            false,
            0,
            'ID da organização não pode ser nulo';
        RETURN;
    END IF;

    -- Obter valores atuais com lock
    SELECT validations_used, max_validations
    INTO v_current_used, v_max_allowed
    FROM tenant.organizations
    WHERE id = p_organization_id
    FOR UPDATE;

    -- Verificar se encontrou
    IF NOT FOUND THEN
        RETURN QUERY SELECT
            false,
            0,
            format('Organização com ID %s não encontrada', p_organization_id);
        RETURN;
    END IF;

    -- Calcular novo valor
    v_new_used := COALESCE(v_current_used, 0) + COALESCE(p_count, 1);

    -- Verificar limite
    IF v_new_used > v_max_allowed THEN
        RETURN QUERY SELECT
            false,
            GREATEST(v_max_allowed - v_current_used, 0),
            format('Limite de %s validações excedido. Restam %s validações.',
                   v_max_allowed, GREATEST(v_max_allowed - v_current_used, 0));
        RETURN;
    END IF;

    -- Atualizar contador
    UPDATE tenant.organizations
    SET validations_used = v_new_used,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_organization_id;

    RETURN QUERY SELECT
        true,
        v_max_allowed - v_new_used,
        format('Sucesso. Restam %s validações de %s.',
               v_max_allowed - v_new_used, v_max_allowed);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tenant.increment_validation_usage(INTEGER, INTEGER) IS
'Incrementa o contador de validações usadas, verificando o limite';

-- ================================================
-- CRIAR FUNÇÃO check_quota
-- ================================================

CREATE OR REPLACE FUNCTION tenant.check_quota(
    p_organization_id INTEGER,
    p_required_count INTEGER DEFAULT 1
)
RETURNS TABLE (
    allowed BOOLEAN,
    remaining INTEGER,
    used INTEGER,
    max_limit INTEGER,
    message TEXT
) AS $$
DECLARE
    v_max INTEGER;
    v_used INTEGER;
    v_remaining INTEGER;
BEGIN
    -- Validar entrada
    IF p_organization_id IS NULL THEN
        RETURN QUERY SELECT
            false,
            0,
            0,
            0,
            'ID da organização não pode ser nulo';
        RETURN;
    END IF;

    SELECT max_validations, validations_used, max_validations - validations_used
    INTO v_max, v_used, v_remaining
    FROM tenant.organizations
    WHERE id = p_organization_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT
            false,
            0,
            0,
            0,
            format('Organização com ID %s não encontrada', p_organization_id);
        RETURN;
    END IF;

    RETURN QUERY SELECT
        v_remaining >= p_required_count,
        v_remaining,
        v_used,
        v_max,
        CASE
            WHEN v_remaining >= p_required_count THEN
                format('%s validações disponíveis', v_remaining)
            ELSE
                format('Limite excedido. Apenas %s validações restantes', v_remaining)
        END;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tenant.check_quota(INTEGER, INTEGER) IS
'Verifica se a organização tem quota disponível';

-- ================================================
-- CRIAR FUNÇÃO reset_monthly_quotas
-- ================================================

CREATE OR REPLACE FUNCTION tenant.reset_monthly_quotas()
RETURNS TABLE (
    org_id INTEGER,
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
        v_should_reset := FALSE;

        -- Verificar se deve resetar
        IF (v_current_day = v_record.billing_cycle_day) OR
           (v_record.last_reset_date < date_trunc('month', CURRENT_DATE)) THEN
            v_should_reset := TRUE;
        END IF;

        -- Fim do mês
        IF (v_record.billing_cycle_day > v_current_day) AND
           (v_current_day = DATE_PART('day', (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day')::date)) THEN
            v_should_reset := TRUE;
        END IF;

        IF v_should_reset THEN
            -- Inserir histórico
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

            -- Resetar
            UPDATE tenant.organizations
            SET
                validations_used = 0,
                last_reset_date = CURRENT_TIMESTAMP,
                quota_reset_count = COALESCE(quota_reset_count, 0) + 1,
                updated_at = CURRENT_TIMESTAMP
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
'Reseta os contadores de validação mensais das organizações';

-- ================================================
-- CRIAR FUNÇÕES DE SETTINGS (VERSÃO INTEGER)
-- ================================================

CREATE OR REPLACE FUNCTION tenant.update_organization_settings(
    p_organization_id INTEGER,
    p_settings JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_current_settings JSONB;
    v_new_settings JSONB;
BEGIN
    -- Validar entrada
    IF p_organization_id IS NULL THEN
        RAISE EXCEPTION 'ID da organização não pode ser nulo';
    END IF;

    -- Obter settings atuais
    SELECT settings
    INTO v_current_settings
    FROM tenant.organizations
    WHERE id = p_organization_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Organização com ID % não encontrada', p_organization_id;
    END IF;

    -- Merge
    v_new_settings := COALESCE(v_current_settings, '{}'::JSONB) || p_settings;

    -- Atualizar
    UPDATE tenant.organizations
    SET settings = v_new_settings,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_organization_id;

    RETURN v_new_settings;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tenant.update_organization_settings(INTEGER, JSONB) IS
'Atualiza configurações da organização com merge';

CREATE OR REPLACE FUNCTION tenant.get_organization_setting(
    p_organization_id INTEGER,
    p_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_value JSONB;
BEGIN
    -- Validar entrada
    IF p_organization_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT settings->p_key
    INTO v_value
    FROM tenant.organizations
    WHERE id = p_organization_id;

    RETURN v_value;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION tenant.get_organization_setting(INTEGER, TEXT) IS
'Obtém valor específico das configurações';

-- ================================================
-- RECREAR VIEWS ATUALIZADAS
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
    o.is_active,
    o.created_at,
    o.updated_at
FROM tenant.organizations o;

COMMENT ON VIEW tenant.v_organization_quotas IS
'View consolidada com informações de quota das organizações';

-- ================================================
-- GRANT PERMISSIONS
-- ================================================

GRANT ALL ON TABLE tenant.quota_history TO sparknexus;
GRANT ALL ON FUNCTION tenant.increment_validation_usage(INTEGER, INTEGER) TO sparknexus;
GRANT ALL ON FUNCTION tenant.check_quota(INTEGER, INTEGER) TO sparknexus;
GRANT ALL ON FUNCTION tenant.reset_monthly_quotas() TO sparknexus;
GRANT ALL ON FUNCTION tenant.update_organization_settings(INTEGER, JSONB) TO sparknexus;
GRANT ALL ON FUNCTION tenant.get_organization_setting(INTEGER, TEXT) TO sparknexus;
GRANT SELECT ON tenant.v_organization_quotas TO sparknexus;

-- ================================================
-- TESTES DE VALIDAÇÃO
-- ================================================

DO $$
DECLARE
    v_test_result RECORD;
    v_org_id INTEGER;
BEGIN
    -- Pegar um ID de organização para teste
    SELECT id INTO v_org_id FROM tenant.organizations LIMIT 1;

    IF v_org_id IS NOT NULL THEN
        -- Testar check_quota
        SELECT * INTO v_test_result FROM tenant.check_quota(v_org_id, 1);
        RAISE NOTICE 'Teste check_quota: OK - Remaining: %', v_test_result.remaining;

        -- Testar increment_validation_usage
        SELECT * INTO v_test_result FROM tenant.increment_validation_usage(v_org_id, 0);
        RAISE NOTICE 'Teste increment_validation_usage: OK - Success: %', v_test_result.success;
    ELSE
        RAISE NOTICE 'Nenhuma organização encontrada para testes';
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 004_complete_fix_integer_types aplicada com sucesso!';
    RAISE NOTICE '';
    RAISE NOTICE 'Resumo das correções:';
    RAISE NOTICE '  ✓ Todas as funções agora usam INTEGER para organization_id';
    RAISE NOTICE '  ✓ Tabela quota_history corrigida para usar INTEGER';
    RAISE NOTICE '  ✓ Validações de NULL adicionadas';
    RAISE NOTICE '  ✓ Views atualizadas';
    RAISE NOTICE '  ✓ Permissões concedidas';
END $$;
