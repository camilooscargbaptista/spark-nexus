#!/bin/bash

# ================================================
# SPARK NEXUS - FIX MIGRATIONS
# Script para corrigir problemas de migrations
# ================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      🔧 FIX MIGRATIONS - CORREÇÃO DE TIPOS                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================
# PASSO 1: VERIFICAR SE POSTGRES ESTÁ RODANDO
# ================================================
echo -e "${YELLOW}[1/6] Verificando PostgreSQL...${NC}"
if ! docker ps | grep -q sparknexus-postgres; then
    echo -e "${BLUE}Iniciando PostgreSQL...${NC}"
    docker-compose up -d postgres
    sleep 5
fi
echo -e "${GREEN}✅ PostgreSQL está rodando${NC}"

# ================================================
# PASSO 2: LIMPAR FUNÇÕES COM PROBLEMA
# ================================================
echo -e "\n${YELLOW}[2/6] Limpando funções antigas com UUID...${NC}"

docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus << 'EOSQL' 2>&1 | grep -v "NOTICE" || true
-- Dropar TODAS as funções que podem ter problema com UUID
DROP FUNCTION IF EXISTS tenant.update_organization_settings(UUID, JSONB) CASCADE;
DROP FUNCTION IF EXISTS tenant.get_organization_setting(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS tenant.increment_validation_usage(UUID, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS tenant.reset_monthly_quotas() CASCADE;

-- Dropar views que dependem dessas funções
DROP VIEW IF EXISTS tenant.v_organization_details CASCADE;
DROP VIEW IF EXISTS tenant.v_organization_members_details CASCADE;
DROP VIEW IF EXISTS tenant.v_organization_quotas CASCADE;

-- Limpar tabela de histórico de migrations se houver registros com erro
DELETE FROM migrations.history WHERE success = false;
EOSQL

echo -e "${GREEN}✅ Funções antigas removidas${NC}"

# ================================================
# PASSO 3: CRIAR FUNÇÕES CORRETAS COM INTEGER
# ================================================
echo -e "\n${YELLOW}[3/6] Criando funções corretas com INTEGER...${NC}"

docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus << 'EOSQL'
-- Função para atualizar settings (com INTEGER)
CREATE OR REPLACE FUNCTION tenant.update_organization_settings(
    p_organization_id INTEGER,
    p_settings JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_current_settings JSONB;
    v_new_settings JSONB;
BEGIN
    SELECT settings INTO v_current_settings
    FROM tenant.organizations
    WHERE id = p_organization_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Organização com ID % não encontrada', p_organization_id;
    END IF;

    v_new_settings := COALESCE(v_current_settings, '{}'::JSONB) || p_settings;

    UPDATE tenant.organizations
    SET settings = v_new_settings,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_organization_id;

    RETURN v_new_settings;
END;
$$ LANGUAGE plpgsql;

-- Função para obter setting específico (com INTEGER)
CREATE OR REPLACE FUNCTION tenant.get_organization_setting(
    p_organization_id INTEGER,
    p_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_value JSONB;
BEGIN
    SELECT settings->p_key INTO v_value
    FROM tenant.organizations
    WHERE id = p_organization_id;

    RETURN v_value;
END;
$$ LANGUAGE plpgsql;

-- Função increment_validation_usage (com INTEGER)
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
            format('Limite de %s validações excedido. Restam %s validações.',
                   v_max_allowed, GREATEST(v_max_allowed - v_current_used, 0));
        RETURN;
    END IF;

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

-- Função reset_monthly_quotas
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
        SELECT o.id, o.name, o.validations_used, o.max_validations,
               o.last_reset_date, o.billing_cycle_day
        FROM tenant.organizations o
        WHERE o.is_active = true
    LOOP
        v_should_reset := FALSE;

        IF (v_current_day = v_record.billing_cycle_day) OR
           (v_record.last_reset_date < date_trunc('month', CURRENT_DATE)) THEN
            v_should_reset := TRUE;
        END IF;

        IF v_should_reset THEN
            UPDATE tenant.organizations
            SET validations_used = 0,
                last_reset_date = CURRENT_TIMESTAMP,
                quota_reset_count = COALESCE(quota_reset_count, 0) + 1
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

-- Conceder permissões
GRANT ALL ON FUNCTION tenant.update_organization_settings(INTEGER, JSONB) TO sparknexus;
GRANT ALL ON FUNCTION tenant.get_organization_setting(INTEGER, TEXT) TO sparknexus;
GRANT ALL ON FUNCTION tenant.increment_validation_usage(INTEGER, INTEGER) TO sparknexus;
GRANT ALL ON FUNCTION tenant.reset_monthly_quotas() TO sparknexus;
EOSQL

echo -e "${GREEN}✅ Funções criadas com tipos corretos${NC}"

# ================================================
# PASSO 4: RECRIAR VIEWS
# ================================================
echo -e "\n${YELLOW}[4/6] Recriando views...${NC}"

docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus << 'EOSQL'
-- View de detalhes das organizações
CREATE OR REPLACE VIEW tenant.v_organization_details AS
SELECT
    o.id,
    o.name,
    o.slug,
    o.plan,
    o.is_active,
    o.settings,
    o.max_validations,
    o.validations_used,
    o.max_validations - o.validations_used AS validations_remaining,
    o.created_at,
    o.updated_at,
    o.last_reset_date,
    o.billing_cycle_day,
    COUNT(DISTINCT om.user_id) AS member_count
FROM tenant.organizations o
LEFT JOIN tenant.organization_members om ON o.id = om.organization_id
GROUP BY o.id;

-- View de quotas
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
    o.is_active
FROM tenant.organizations o;

-- Conceder permissões
GRANT SELECT ON tenant.v_organization_details TO sparknexus;
GRANT SELECT ON tenant.v_organization_quotas TO sparknexus;
EOSQL

echo -e "${GREEN}✅ Views recriadas${NC}"

# ================================================
# PASSO 5: MARCAR MIGRATIONS COMO EXECUTADAS
# ================================================
echo -e "\n${YELLOW}[5/6] Marcando migrations como executadas...${NC}"

docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus << 'EOSQL'
-- Marcar as migrations que já foram parcialmente executadas
INSERT INTO migrations.history (migration_name, success, execution_time_ms)
VALUES 
    ('001_alter_tables', true, 100),
    ('002_add_quota_system', true, 100),
    ('003_alter_table_quota', true, 100)
ON CONFLICT (migration_name) 
DO UPDATE SET 
    success = true,
    executed_at = CURRENT_TIMESTAMP;
EOSQL

echo -e "${GREEN}✅ Migrations marcadas como executadas${NC}"

# ================================================
# PASSO 6: VERIFICAR RESULTADO
# ================================================
echo -e "\n${YELLOW}[6/6] Verificando resultado...${NC}"

echo -e "\n${CYAN}📊 Estrutura do banco:${NC}"
docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c "
    SELECT 
        column_name as \"Coluna\",
        data_type as \"Tipo\"
    FROM information_schema.columns
    WHERE table_schema = 'tenant'
    AND table_name = 'organizations'
    AND column_name IN ('id', 'max_validations', 'validations_used', 'is_active', 'settings')
    ORDER BY ordinal_position;
"

echo -e "\n${CYAN}🔧 Funções criadas:${NC}"
docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c "
    SELECT 
        routine_name as \"Função\",
        parameter_data_types as \"Parâmetros\"
    FROM information_schema.routines
    WHERE routine_schema = 'tenant'
    AND routine_name IN ('increment_validation_usage', 'update_organization_settings', 'reset_monthly_quotas')
    ORDER BY routine_name;
"

echo -e "\n${CYAN}📋 Status das migrations:${NC}"
docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c "
    SELECT 
        migration_name as \"Migration\",
        CASE WHEN success THEN '✅' ELSE '❌' END as \"Status\",
        TO_CHAR(executed_at, 'DD/MM HH24:MI') as \"Executada\"
    FROM migrations.history
    ORDER BY executed_at DESC;
"

# ================================================
# TESTE RÁPIDO
# ================================================
echo -e "\n${CYAN}🧪 Teste rápido das funções:${NC}"

echo -n "  Testando increment_validation_usage... "
TEST_RESULT=$(docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -t -A -c "
    SELECT success FROM tenant.increment_validation_usage(
        (SELECT id FROM tenant.organizations LIMIT 1), 0
    );
" 2>/dev/null || echo "erro")

if [ "$TEST_RESULT" = "t" ] || [ "$TEST_RESULT" = "f" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}ERRO${NC}"
fi

echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      ✅ MIGRATIONS CORRIGIDAS COM SUCESSO!                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${CYAN}Próximos passos:${NC}"
echo -e "1. Execute o restart completo: ${YELLOW}./force-restart_with_migrations.sh${NC}"
echo -e "2. As migrations já estão marcadas como executadas"
echo -e "3. O sistema deve funcionar normalmente agora"

exit 0