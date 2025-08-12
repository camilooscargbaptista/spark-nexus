#!/bin/bash

# ================================================
# Script: 01-database-migrations-v2.sh
# Descrição: Adiciona campos de controle de quota mensal
# Schema correto: tenant.organizations
# ================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ================================================
# CONFIGURAÇÃO
# ================================================

# Detectar diretório base
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../../../" && pwd )"

# Configurações do banco
POSTGRES_USER="sparknexus"
POSTGRES_PASSWORD="SparkNexus2024!"
DB_NAME="sparknexus"

# ================================================
# FUNÇÕES AUXILIARES
# ================================================

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Função para executar SQL
execute_sql() {
    local sql="$1"
    local description="$2"

    log_info "Executando: $description"

    if docker exec -i sparknexus-postgres psql -U "$POSTGRES_USER" -d "$DB_NAME" -c "$sql" > /dev/null 2>&1; then
        log_success "$description concluído"
        return 0
    else
        log_error "Falha ao executar: $description"
        return 1
    fi
}

# Função para verificar se coluna existe
column_exists() {
    local schema="$1"
    local table="$2"
    local column="$3"

    local result=$(docker exec -i sparknexus-postgres psql -U "$POSTGRES_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*)
        FROM information_schema.columns
        WHERE table_schema = '$schema'
        AND table_name = '$table'
        AND column_name = '$column';
    " 2>/dev/null | tr -d ' ')

    [ "$result" = "1" ]
}

# ================================================
# VALIDAÇÕES INICIAIS
# ================================================

log_info "Iniciando migração do sistema de quotas..."

# Verificar se Docker está rodando
if ! docker ps > /dev/null 2>&1; then
    log_error "Docker não está rodando ou não está acessível"
    exit 1
fi

# Verificar se container sparknexus-postgres existe e está rodando
if ! docker ps | grep -q "sparknexus-postgres"; then
    log_error "Container PostgreSQL (sparknexus-postgres) não está rodando"
    exit 1
fi

log_success "Container PostgreSQL encontrado e rodando"

# ================================================
# VERIFICAR ESTADO ATUAL DO BANCO
# ================================================

log_info "Verificando estado atual do banco de dados..."

# Verificar se tabela tenant.organizations existe
TABLE_EXISTS=$(docker exec -i sparknexus-postgres psql -U "$POSTGRES_USER" -d "$DB_NAME" -t -c "
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'tenant'
    AND table_name = 'organizations';
" 2>/dev/null | tr -d ' ')

if [ "$TABLE_EXISTS" != "1" ]; then
    log_error "Tabela 'tenant.organizations' não encontrada!"
    exit 1
fi

log_success "Tabela 'tenant.organizations' encontrada"

# ================================================
# CRIAR TABELA DE CONTROLE DE MIGRATIONS
# ================================================

log_info "Criando sistema de controle de migrations..."

execute_sql "
    CREATE SCHEMA IF NOT EXISTS migrations;
" "Criar schema migrations"

execute_sql "
    CREATE TABLE IF NOT EXISTS migrations.history (
        id SERIAL PRIMARY KEY,
        migration_name VARCHAR(255) UNIQUE NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        execution_time_ms INTEGER,
        success BOOLEAN DEFAULT TRUE,
        error_message TEXT
    );
" "Criar tabela de histórico de migrations"

# ================================================
# VERIFICAR SE MIGRATION JÁ FOI EXECUTADA
# ================================================

MIGRATION_NAME="001_add_quota_system"
MIGRATION_EXISTS=$(docker exec -i sparknexus-postgres psql -U "$POSTGRES_USER" -d "$DB_NAME" -t -c "
    SELECT COUNT(*)
    FROM migrations.history
    WHERE migration_name = '$MIGRATION_NAME'
    AND success = true;
" 2>/dev/null | tr -d ' ')

if [ "$MIGRATION_EXISTS" = "1" ]; then
    log_warning "Migration '$MIGRATION_NAME' já foi executada. Pulando..."
    exit 0
fi

# ================================================
# APLICAR MIGRAÇÕES
# ================================================

log_info "Aplicando migrações no banco de dados..."
START_TIME=$(date +%s%3N)

# 1. Adicionar colunas de quota em tenant.organizations
if ! column_exists "tenant" "organizations" "max_validations"; then
    execute_sql "
        ALTER TABLE tenant.organizations
        ADD COLUMN max_validations INTEGER DEFAULT 1000;
    " "Adicionar coluna max_validations"
else
    log_warning "Coluna max_validations já existe"
fi

if ! column_exists "tenant" "organizations" "validations_used"; then
    execute_sql "
        ALTER TABLE tenant.organizations
        ADD COLUMN validations_used INTEGER DEFAULT 0;
    " "Adicionar coluna validations_used"
else
    log_warning "Coluna validations_used já existe"
fi

if ! column_exists "tenant" "organizations" "last_reset_date"; then
    execute_sql "
        ALTER TABLE tenant.organizations
        ADD COLUMN last_reset_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
    " "Adicionar coluna last_reset_date"
else
    log_warning "Coluna last_reset_date já existe"
fi

if ! column_exists "tenant" "organizations" "billing_cycle_day"; then
    execute_sql "
        ALTER TABLE tenant.organizations
        ADD COLUMN billing_cycle_day INTEGER DEFAULT 1
        CHECK (billing_cycle_day >= 1 AND billing_cycle_day <= 28);
    " "Adicionar coluna billing_cycle_day"
else
    log_warning "Coluna billing_cycle_day já existe"
fi

if ! column_exists "tenant" "organizations" "quota_reset_count"; then
    execute_sql "
        ALTER TABLE tenant.organizations
        ADD COLUMN quota_reset_count INTEGER DEFAULT 0;
    " "Adicionar coluna quota_reset_count"
else
    log_warning "Coluna quota_reset_count já existe"
fi

# 2. Criar índices para performance
log_info "Criando índices para otimização..."

execute_sql "
    CREATE INDEX IF NOT EXISTS idx_organizations_last_reset
    ON tenant.organizations(last_reset_date);
" "Criar índice em last_reset_date"

execute_sql "
    CREATE INDEX IF NOT EXISTS idx_organizations_billing_day
    ON tenant.organizations(billing_cycle_day);
" "Criar índice em billing_cycle_day"

execute_sql "
    CREATE INDEX IF NOT EXISTS idx_organizations_validations
    ON tenant.organizations(validations_used, max_validations);
" "Criar índice em validations"

# 3. Atualizar valores baseados no plano
log_info "Atualizando limites baseados nos planos..."

execute_sql "
    UPDATE tenant.organizations
    SET max_validations = CASE
        WHEN plan = 'free' THEN 1000
        WHEN plan = 'starter' THEN 10000
        WHEN plan = 'professional' THEN 50000
        WHEN plan = 'enterprise' THEN 999999
        ELSE 1000
    END
    WHERE max_validations IS NULL OR max_validations = 1000;
" "Atualizar limites por plano"

# 4. Popular dados iniciais
log_info "Populando dados iniciais..."

execute_sql "
    UPDATE tenant.organizations
    SET last_reset_date = date_trunc('month', CURRENT_DATE)
    WHERE last_reset_date IS NULL;
" "Definir last_reset_date inicial"

execute_sql "
    UPDATE tenant.organizations
    SET validations_used = 0
    WHERE validations_used IS NULL;
" "Inicializar validations_used"

# 5. Criar tabela de histórico de quotas
log_info "Criando tabela de histórico de quotas..."

execute_sql "
    CREATE TABLE IF NOT EXISTS tenant.quota_history (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        organization_id UUID REFERENCES tenant.organizations(id),
        month DATE NOT NULL,
        validations_used INTEGER DEFAULT 0,
        max_validations INTEGER,
        reset_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        reset_reason VARCHAR(50) DEFAULT 'monthly',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
" "Criar tabela quota_history"

execute_sql "
    CREATE INDEX IF NOT EXISTS idx_quota_history_org
    ON tenant.quota_history(organization_id);
" "Criar índice quota_history.organization_id"

execute_sql "
    CREATE INDEX IF NOT EXISTS idx_quota_history_month
    ON tenant.quota_history(month);
" "Criar índice quota_history.month"

# 6. Criar função para reset automático
log_info "Criando função de reset automático..."

execute_sql "
    CREATE OR REPLACE FUNCTION tenant.reset_monthly_quotas()
    RETURNS INTEGER AS \$\$
    DECLARE
        updated_count INTEGER;
    BEGIN
        -- Inserir histórico antes do reset
        INSERT INTO tenant.quota_history (
            organization_id,
            month,
            validations_used,
            max_validations,
            reset_reason
        )
        SELECT
            id,
            date_trunc('month', last_reset_date),
            validations_used,
            max_validations,
            'monthly'
        FROM tenant.organizations
        WHERE
            (DATE_PART('day', CURRENT_DATE) = billing_cycle_day
             OR (billing_cycle_day > DATE_PART('day', CURRENT_DATE)
                 AND DATE_PART('day', CURRENT_DATE) = DATE_PART('day', (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day')::date)))
            AND last_reset_date < date_trunc('month', CURRENT_DATE);

        -- Resetar quotas
        UPDATE tenant.organizations
        SET
            validations_used = 0,
            last_reset_date = CURRENT_TIMESTAMP,
            quota_reset_count = quota_reset_count + 1
        WHERE
            (DATE_PART('day', CURRENT_DATE) = billing_cycle_day
             OR (billing_cycle_day > DATE_PART('day', CURRENT_DATE)
                 AND DATE_PART('day', CURRENT_DATE) = DATE_PART('day', (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day')::date)))
            AND last_reset_date < date_trunc('month', CURRENT_DATE);

        GET DIAGNOSTICS updated_count = ROW_COUNT;
        RETURN updated_count;
    END;
    \$\$ LANGUAGE plpgsql;
" "Criar função reset_monthly_quotas"

# ================================================
# REGISTRAR MIGRATION COMO CONCLUÍDA
# ================================================

END_TIME=$(date +%s%3N)
EXECUTION_TIME=$((END_TIME - START_TIME))

execute_sql "
    INSERT INTO migrations.history (migration_name, execution_time_ms, success)
    VALUES ('$MIGRATION_NAME', $EXECUTION_TIME, true);
" "Registrar migration como concluída"

# ================================================
# VERIFICAR RESULTADO FINAL
# ================================================

log_info "Verificando resultado da migração..."

# Exibir estrutura atualizada
docker exec -i sparknexus-postgres psql -U "$POSTGRES_USER" -d "$DB_NAME" -c "
    SELECT
        column_name as \"Coluna\",
        data_type as \"Tipo\",
        column_default as \"Padrão\"
    FROM information_schema.columns
    WHERE table_schema = 'tenant'
    AND table_name = 'organizations'
    AND column_name IN ('max_validations', 'validations_used', 'last_reset_date', 'billing_cycle_day', 'quota_reset_count')
    ORDER BY ordinal_position;
"

# ================================================
# EXIBIR ESTATÍSTICAS
# ================================================

log_info "Estatísticas do banco após migração:"

docker exec -i postgres psql -U "$POSTGRES_USER" -d "$DB_NAME" -c "
    SELECT
        name as \"Organização\",
        plan as \"Plano\",
        max_validations as \"Limite\",
        validations_used as \"Usado\",
        TO_CHAR(last_reset_date, 'DD/MM/YYYY') as \"Último Reset\",
        billing_cycle_day as \"Dia\"
    FROM tenant.organizations
    ORDER BY created_at;
"

# ================================================
# CRIAR ARQUIVO SQL DA MIGRATION
# ================================================

MIGRATION_SQL_FILE="$SCRIPT_DIR/sql/001_add_quota_system.sql"
mkdir -p "$SCRIPT_DIR/sql"

cat > "$MIGRATION_SQL_FILE" << 'EOF'
-- Migration: 001_add_quota_system
-- Description: Adiciona sistema de controle de quotas mensais
-- Date: 2025-01-11

-- Adicionar colunas de quota
ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS max_validations INTEGER DEFAULT 1000;

ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS validations_used INTEGER DEFAULT 0;

ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS last_reset_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS billing_cycle_day INTEGER DEFAULT 1
CHECK (billing_cycle_day >= 1 AND billing_cycle_day <= 28);

ALTER TABLE tenant.organizations
ADD COLUMN IF NOT EXISTS quota_reset_count INTEGER DEFAULT 0;

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_organizations_last_reset
ON tenant.organizations(last_reset_date);

CREATE INDEX IF NOT EXISTS idx_organizations_billing_day
ON tenant.organizations(billing_cycle_day);

CREATE INDEX IF NOT EXISTS idx_organizations_validations
ON tenant.organizations(validations_used, max_validations);

-- Atualizar limites por plano
UPDATE tenant.organizations
SET max_validations = CASE
    WHEN plan = 'free' THEN 1000
    WHEN plan = 'starter' THEN 10000
    WHEN plan = 'professional' THEN 50000
    WHEN plan = 'enterprise' THEN 999999
    ELSE 1000
END
WHERE max_validations IS NULL OR max_validations = 1000;

-- Criar tabela de histórico
CREATE TABLE IF NOT EXISTS tenant.quota_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES tenant.organizations(id),
    month DATE NOT NULL,
    validations_used INTEGER DEFAULT 0,
    max_validations INTEGER,
    reset_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reset_reason VARCHAR(50) DEFAULT 'monthly',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Criar função de reset
CREATE OR REPLACE FUNCTION tenant.reset_monthly_quotas()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    -- Inserir histórico antes do reset
    INSERT INTO tenant.quota_history (
        organization_id,
        month,
        validations_used,
        max_validations,
        reset_reason
    )
    SELECT
        id,
        date_trunc('month', last_reset_date),
        validations_used,
        max_validations,
        'monthly'
    FROM tenant.organizations
    WHERE
        (DATE_PART('day', CURRENT_DATE) = billing_cycle_day
         OR (billing_cycle_day > DATE_PART('day', CURRENT_DATE)
             AND DATE_PART('day', CURRENT_DATE) = DATE_PART('day', (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day')::date)))
        AND last_reset_date < date_trunc('month', CURRENT_DATE);

    -- Resetar quotas
    UPDATE tenant.organizations
    SET
        validations_used = 0,
        last_reset_date = CURRENT_TIMESTAMP,
        quota_reset_count = quota_reset_count + 1
    WHERE
        (DATE_PART('day', CURRENT_DATE) = billing_cycle_day
         OR (billing_cycle_day > DATE_PART('day', CURRENT_DATE)
             AND DATE_PART('day', CURRENT_DATE) = DATE_PART('day', (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day')::date)))
        AND last_reset_date < date_trunc('month', CURRENT_DATE);

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;
EOF

log_success "Arquivo SQL criado: $MIGRATION_SQL_FILE"

# ================================================
# FINALIZAÇÃO
# ================================================

echo ""
log_success "🎉 Migração do sistema de quotas concluída com sucesso!"
echo ""
echo -e "${BLUE}📊 Resumo das alterações:${NC}"
echo "  • Adicionadas 5 colunas em tenant.organizations"
echo "  • Criada tabela tenant.quota_history"
echo "  • Criada função tenant.reset_monthly_quotas()"
echo "  • Criado sistema de controle de migrations"
echo "  • Limites atualizados por plano"
echo ""
echo -e "${YELLOW}📝 Próximos passos:${NC}"
echo "  1. Execute: ./02-create-quota-service.sh"
echo "  2. Para resetar quotas manualmente:"
echo "     docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c 'SELECT tenant.reset_monthly_quotas();'"
echo ""

exit 0
