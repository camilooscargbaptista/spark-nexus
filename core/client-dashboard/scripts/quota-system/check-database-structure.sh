#!/bin/bash

# ================================================
# Script: check-database-structure.sh
# Descrição: Verifica a estrutura do banco de dados
# ================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Verificando estrutura do banco de dados...${NC}"
echo ""

# ================================================
# 1. LISTAR TODOS OS SCHEMAS
# ================================================
echo -e "${YELLOW}📁 Schemas disponíveis:${NC}"
docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c "
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
    ORDER BY schema_name;
"

echo ""
echo -e "${YELLOW}📊 Tabelas em cada schema:${NC}"

# ================================================
# 2. LISTAR TABELAS NO SCHEMA PUBLIC
# ================================================
echo -e "${BLUE}Schema: public${NC}"
docker exec -i postgres psql -U sparknexus -d sparknexus -c "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
    ORDER BY table_name;
"

# ================================================
# 3. LISTAR TABELAS NO SCHEMA AUTH (se existir)
# ================================================
echo -e "${BLUE}Schema: auth${NC}"
docker exec -i postgres psql -U sparknexus -d sparknexus -c "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'auth'
    ORDER BY table_name;
" 2>/dev/null || echo "Schema 'auth' não encontrado"

# ================================================
# 4. BUSCAR TABELA ORGANIZATIONS EM QUALQUER SCHEMA
# ================================================
echo ""
echo -e "${YELLOW}🔎 Procurando tabela 'organizations' em todos os schemas:${NC}"
docker exec -i postgres psql -U sparknexus -d sparknexus -c "
    SELECT
        table_schema as schema,
        table_name as tabela
    FROM information_schema.tables
    WHERE table_name LIKE '%organization%'
    ORDER BY table_schema, table_name;
"

# ================================================
# 5. VERIFICAR SE É 'organization' (singular) ou 'organizations' (plural)
# ================================================
echo ""
echo -e "${YELLOW}📋 Verificando variações do nome:${NC}"
docker exec -i postgres psql -U sparknexus -d sparknexus -c "
    SELECT
        table_schema,
        table_name,
        CASE
            WHEN table_name = 'organizations' THEN '✅ Nome correto (plural)'
            WHEN table_name = 'organization' THEN '⚠️  Nome no singular'
            ELSE '📌 Variação encontrada'
        END as status
    FROM information_schema.tables
    WHERE table_name IN ('organization', 'organizations', 'orgs', 'org')
    OR table_name LIKE '%org%'
    ORDER BY table_schema, table_name;
"

# ================================================
# 6. LISTAR ESTRUTURA DA TABELA SE ENCONTRADA
# ================================================
echo ""
echo -e "${YELLOW}📊 Estrutura da tabela de organizações (se existir):${NC}"

# Tentar diferentes combinações
for schema in "public" "auth" "core"; do
    for table in "organizations" "organization" "orgs"; do
        echo -e "${BLUE}Tentando: $schema.$table${NC}"
        docker exec -i postgres psql -U sparknexus -d sparknexus -c "
            SELECT
                column_name,
                data_type,
                is_nullable,
                column_default
            FROM information_schema.columns
            WHERE table_schema = '$schema'
            AND table_name = '$table'
            ORDER BY ordinal_position;
        " 2>/dev/null && break 2
    done
done

# ================================================
# 7. VERIFICAR TABELAS RELACIONADAS
# ================================================
echo ""
echo -e "${YELLOW}🔗 Tabelas relacionadas a organizações:${NC}"
docker exec -i postgres psql -U sparknexus -d sparknexus -c "
    SELECT DISTINCT
        table_schema,
        table_name
    FROM information_schema.columns
    WHERE column_name LIKE '%organization%'
    OR column_name LIKE '%org_id%'
    ORDER BY table_schema, table_name;
"

echo ""
echo -e "${GREEN}✅ Verificação concluída!${NC}"
echo ""
echo -e "${BLUE}💡 Dica: Se a tabela tem um nome diferente, precisaremos ajustar o script de migração.${NC}"
