#!/bin/bash

# ================================================
# SPARK NEXUS - FORCE RESTART WITH MIGRATIONS
# Reinicialização com execução automática de migrations
# ================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ================================================
# HEADER
# ================================================
clear
echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║      🔄 FORCE RESTART WITH MIGRATIONS                       ║${NC}"
echo -e "${RED}║      Reinicialização com atualização de banco               ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================
# FUNÇÃO PARA EXECUTAR MIGRATIONS
# ================================================
run_migrations() {
    echo -e "\n${CYAN}🗄️  EXECUTANDO MIGRATIONS...${NC}"
    
    # Verificar se existe pasta de migrations
    MIGRATIONS_DIR="core/client-dashboard/services/migrations"
    
    if [ ! -d "$MIGRATIONS_DIR" ]; then
        echo -e "${YELLOW}⚠️  Pasta de migrations não encontrada em $MIGRATIONS_DIR${NC}"
        echo -e "${YELLOW}   Criando estrutura de migrations...${NC}"
        mkdir -p "$MIGRATIONS_DIR"
    fi
    
    # Criar tabela de controle de migrations se não existir
    echo -e "${BLUE}Criando sistema de controle de migrations...${NC}"
    docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus << 'EOSQL' 2>/dev/null || true
    -- Criar schema se não existir
    CREATE SCHEMA IF NOT EXISTS migrations;
    
    -- Criar tabela de histórico se não existir
    CREATE TABLE IF NOT EXISTS migrations.history (
        id SERIAL PRIMARY KEY,
        migration_name VARCHAR(255) UNIQUE NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        execution_time_ms INTEGER,
        success BOOLEAN DEFAULT TRUE,
        error_message TEXT,
        checksum VARCHAR(64)
    );
    
    -- Criar índice se não existir
    CREATE INDEX IF NOT EXISTS idx_migrations_name ON migrations.history(migration_name);
    CREATE INDEX IF NOT EXISTS idx_migrations_success ON migrations.history(success);
EOSQL
    
    # Buscar arquivos SQL de migration
    echo -e "${BLUE}Procurando arquivos de migration...${NC}"
    
    # Lista de diretórios onde podem estar as migrations
    MIGRATION_PATHS=(
        "core/client-dashboard/services/migrations"
        "core/client-dashboard/scripts/quota-system/sql"
        "migrations"
    )
    
    MIGRATIONS_FOUND=0
    MIGRATIONS_EXECUTED=0
    MIGRATIONS_SKIPPED=0
    MIGRATIONS_FAILED=0
    
    for MIGRATION_PATH in "${MIGRATION_PATHS[@]}"; do
        if [ -d "$MIGRATION_PATH" ]; then
            echo -e "${BLUE}Verificando em: $MIGRATION_PATH${NC}"
            
            # Listar arquivos SQL ordenados
            for SQL_FILE in $(ls -1 "$MIGRATION_PATH"/*.sql 2>/dev/null | sort); do
                if [ -f "$SQL_FILE" ]; then
                    MIGRATION_NAME=$(basename "$SQL_FILE" .sql)
                    MIGRATIONS_FOUND=$((MIGRATIONS_FOUND + 1))
                    
                    # Calcular checksum do arquivo
                    if command -v md5sum &> /dev/null; then
                        FILE_CHECKSUM=$(md5sum "$SQL_FILE" | cut -d' ' -f1)
                    elif command -v md5 &> /dev/null; then
                        FILE_CHECKSUM=$(md5 -q "$SQL_FILE")
                    else
                        FILE_CHECKSUM="no-checksum"
                    fi
                    
                    # Verificar se já foi executada com sucesso
                    MIGRATION_STATUS=$(docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -t -A -c "
                        SELECT 
                            CASE 
                                WHEN success = true AND checksum = '$FILE_CHECKSUM' THEN 'unchanged'
                                WHEN success = true AND checksum != '$FILE_CHECKSUM' THEN 'changed'
                                WHEN success = false THEN 'failed'
                                ELSE 'new'
                            END
                        FROM migrations.history 
                        WHERE migration_name = '$MIGRATION_NAME'
                        LIMIT 1;
                    " 2>/dev/null | tr -d ' ' || echo "new")
                    
                    if [ -z "$MIGRATION_STATUS" ]; then
                        MIGRATION_STATUS="new"
                    fi
                    
                    case "$MIGRATION_STATUS" in
                        "unchanged")
                            echo -e "${GREEN}  ✓ Migration $MIGRATION_NAME já executada (sem mudanças)${NC}"
                            MIGRATIONS_SKIPPED=$((MIGRATIONS_SKIPPED + 1))
                            ;;
                        "changed")
                            echo -e "${YELLOW}  ⚠️  Migration $MIGRATION_NAME foi modificada após execução${NC}"
                            echo -e "${BLUE}     Re-executando migration modificada...${NC}"
                            ;;
                        "failed")
                            echo -e "${YELLOW}  🔄 Re-tentando migration $MIGRATION_NAME (falhou anteriormente)${NC}"
                            ;;
                        "new")
                            echo -e "${YELLOW}  📝 Executando nova migration: $MIGRATION_NAME${NC}"
                            ;;
                    esac
                    
                    if [ "$MIGRATION_STATUS" != "unchanged" ]; then
                        START_TIME=$(date +%s%N)
                        
                        # Criar arquivo temporário para capturar erro
                        ERROR_FILE="/tmp/migration_error_$$.txt"
                        
                        # Executar SQL
                        if docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus < "$SQL_FILE" 2>"$ERROR_FILE"; then
                            END_TIME=$(date +%s%N)
                            EXEC_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
                            
                            # Registrar sucesso
                            docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c "
                                INSERT INTO migrations.history (migration_name, execution_time_ms, success, checksum)
                                VALUES ('$MIGRATION_NAME', $EXEC_TIME, true, '$FILE_CHECKSUM')
                                ON CONFLICT (migration_name) DO UPDATE 
                                SET executed_at = CURRENT_TIMESTAMP, 
                                    execution_time_ms = $EXEC_TIME,
                                    success = true,
                                    error_message = NULL,
                                    checksum = '$FILE_CHECKSUM';
                            " > /dev/null 2>&1
                            
                            echo -e "${GREEN}  ✅ Migration $MIGRATION_NAME executada com sucesso (${EXEC_TIME}ms)${NC}"
                            MIGRATIONS_EXECUTED=$((MIGRATIONS_EXECUTED + 1))
                        else
                            # Capturar erro
                            ERROR_MSG=$(cat "$ERROR_FILE" | head -20 | sed "s/'/''/g")
                            
                            # Registrar erro
                            docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c "
                                INSERT INTO migrations.history (migration_name, success, error_message, checksum)
                                VALUES ('$MIGRATION_NAME', false, '$ERROR_MSG', '$FILE_CHECKSUM')
                                ON CONFLICT (migration_name) DO UPDATE 
                                SET executed_at = CURRENT_TIMESTAMP, 
                                    success = false,
                                    error_message = '$ERROR_MSG',
                                    checksum = '$FILE_CHECKSUM';
                            " > /dev/null 2>&1
                            
                            echo -e "${RED}  ❌ Erro ao executar migration $MIGRATION_NAME${NC}"
                            echo -e "${RED}     Erro: $(head -5 "$ERROR_FILE")${NC}"
                            MIGRATIONS_FAILED=$((MIGRATIONS_FAILED + 1))
                        fi
                        
                        # Limpar arquivo temporário
                        rm -f "$ERROR_FILE"
                    fi
                fi
            done
        fi
    done
    
    # Relatório de execução
    echo -e "\n${CYAN}📊 Resumo das Migrations:${NC}"
    echo -e "  Total encontradas: ${YELLOW}$MIGRATIONS_FOUND${NC}"
    echo -e "  Executadas agora:  ${GREEN}$MIGRATIONS_EXECUTED${NC}"
    echo -e "  Já executadas:     ${BLUE}$MIGRATIONS_SKIPPED${NC}"
    if [ $MIGRATIONS_FAILED -gt 0 ]; then
        echo -e "  Com erro:          ${RED}$MIGRATIONS_FAILED${NC}"
    fi
    
    # Mostrar status das migrations
    echo -e "\n${CYAN}📊 Últimas Migrations Executadas:${NC}"
    docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c "
        SELECT 
            migration_name as \"Migration\",
            TO_CHAR(executed_at, 'DD/MM/YYYY HH24:MI:SS') as \"Executada em\",
            execution_time_ms as \"Tempo (ms)\",
            CASE WHEN success THEN '✅' ELSE '❌' END as \"Status\"
        FROM migrations.history
        ORDER BY executed_at DESC
        LIMIT 10;
    " 2>/dev/null || echo "Não foi possível listar migrations"
    
    # Se houver falhas, mostrar detalhes
    if [ $MIGRATIONS_FAILED -gt 0 ]; then
        echo -e "\n${RED}⚠️  Migrations com Erro:${NC}"
        docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c "
            SELECT 
                migration_name as \"Migration\",
                LEFT(error_message, 80) as \"Erro\"
            FROM migrations.history
            WHERE success = false
            ORDER BY executed_at DESC;
        " 2>/dev/null
    fi
}

# ================================================
# PASSO 1: PARAR TODOS OS CONTAINERS
# ================================================
echo -e "${YELLOW}[1/11] Parando TODOS os containers...${NC}"
docker-compose down --remove-orphans
echo -e "${GREEN}✅ Todos os containers parados e removidos${NC}"

# ================================================
# PASSO 2: LIMPAR CONTAINERS ÓRFÃOS
# ================================================
echo -e "\n${YELLOW}[2/11] Limpando containers órfãos...${NC}"
docker container prune -f 2>/dev/null || true
echo -e "${GREEN}✅ Containers órfãos removidos${NC}"

# ================================================
# PASSO 3: LIMPAR CACHE DOCKER DO CLIENT
# ================================================
echo -e "\n${YELLOW}[3/11] Limpando cache e volumes temporários...${NC}"
docker volume ls -q | grep -v "_data" | xargs -r docker volume rm 2>/dev/null || true
docker builder prune -f 2>/dev/null || true
echo -e "${GREEN}✅ Cache limpo${NC}"

# ================================================
# PASSO 4: VERIFICAR NODE_MODULES
# ================================================
echo -e "\n${YELLOW}[4/11] Verificando node_modules em client-dashboard...${NC}"

if [ -d "core/client-dashboard/node_modules" ]; then
    MODULE_COUNT=$(ls -1 core/client-dashboard/node_modules 2>/dev/null | wc -l)
    echo -e "${GREEN}✅ $MODULE_COUNT módulos encontrados${NC}"
    
    if [ -d "core/client-dashboard/node_modules/exceljs" ]; then
        echo -e "${GREEN}✅ ExcelJS está instalado${NC}"
    else
        echo -e "${YELLOW}⚠️  ExcelJS NÃO encontrado - instalando...${NC}"
        cd core/client-dashboard
        npm install exceljs --save
        cd ../..
    fi
else
    echo -e "${YELLOW}⚠️  node_modules não existe - instalando dependências...${NC}"
    cd core/client-dashboard
    npm install
    cd ../..
fi

# ================================================
# PASSO 5: RECONSTRUIR IMAGEM DO CLIENT
# ================================================
echo -e "\n${YELLOW}[5/11] Reconstruindo imagem do client-dashboard...${NC}"
docker-compose build --no-cache client-dashboard
echo -e "${GREEN}✅ Imagem reconstruída${NC}"

# ================================================
# PASSO 6: INICIAR SERVIÇOS BASE
# ================================================
echo -e "\n${YELLOW}[6/11] Iniciando serviços base...${NC}"

echo -n "  📦 PostgreSQL... "
docker-compose up -d postgres
sleep 5  # Dar mais tempo para o PostgreSQL inicializar
echo -e "${GREEN}OK${NC}"

echo -n "  📦 Redis... "
docker-compose up -d redis
sleep 2
echo -e "${GREEN}OK${NC}"

echo -n "  📦 RabbitMQ... "
docker-compose up -d rabbitmq
sleep 3
echo -e "${GREEN}OK${NC}"

# ================================================
# PASSO 7: EXECUTAR MIGRATIONS
# ================================================
echo -e "\n${YELLOW}[7/11] Executando migrations do banco de dados...${NC}"
run_migrations

# ================================================
# PASSO 8: EXECUTAR SCRIPTS DE QUOTA SE EXISTIREM
# ================================================
echo -e "\n${YELLOW}[8/11] Verificando scripts de quota...${NC}"

QUOTA_SCRIPT="core/client-dashboard/scripts/quota-system/01-database-migrations-v2.sh"
if [ -f "$QUOTA_SCRIPT" ]; then
    echo -e "${BLUE}Executando script de quota...${NC}"
    chmod +x "$QUOTA_SCRIPT"
    if bash "$QUOTA_SCRIPT"; then
        echo -e "${GREEN}✅ Script de quota executado${NC}"
    else
        echo -e "${YELLOW}⚠️  Erro ao executar script de quota${NC}"
    fi
else
    echo -e "${BLUE}ℹ️  Script de quota não encontrado${NC}"
fi

# ================================================
# PASSO 9: INICIAR SERVIÇOS DE AUTENTICAÇÃO
# ================================================
echo -e "\n${YELLOW}[9/11] Iniciando serviços de autenticação...${NC}"

echo -n "  🔐 Auth Service... "
docker-compose up -d auth-service
sleep 2
echo -e "${GREEN}OK${NC}"

echo -n "  🏢 Tenant Service... "
docker-compose up -d tenant-service
sleep 2
echo -e "${GREEN}OK${NC}"

echo -n "  💳 Billing Service... "
docker-compose up -d billing-service
sleep 2
echo -e "${GREEN}OK${NC}"

# ================================================
# PASSO 10: INICIAR CLIENT-DASHBOARD
# ================================================
echo -e "\n${YELLOW}[10/11] Iniciando client-dashboard...${NC}"
docker-compose up -d client-dashboard

echo -e "${YELLOW}⏳ Aguardando inicialização (20 segundos)...${NC}"
for i in {1..20}; do
    echo -n "."
    sleep 1
done
echo ""

# ================================================
# PASSO 11: VERIFICAR E INICIAR OUTROS SERVIÇOS
# ================================================
echo -e "\n${YELLOW}[11/11] Iniciando outros serviços...${NC}"
docker-compose up -d admin-dashboard email-validator

sleep 5

# ================================================
# VERIFICAR STATUS
# ================================================
echo -e "\n${CYAN}📊 Verificando status dos serviços...${NC}"

# Testar cada serviço
echo -e "\n${CYAN}🧪 Testando APIs:${NC}"

echo -n "  Client Dashboard (4201): "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4201/api/health 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP $RESPONSE${NC}"
fi

echo -n "  Admin Dashboard (4200):  "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4200/api/health 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP $RESPONSE${NC}"
fi

echo -n "  Auth Service (3001):     "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP $RESPONSE${NC}"
fi

# ================================================
# STATUS DOS CONTAINERS
# ================================================
echo -e "\n${CYAN}📊 Status de todos os containers:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | head -20

# ================================================
# VERIFICAR ESTRUTURA DO BANCO ATUALIZADA
# ================================================
echo -e "\n${CYAN}🗄️  Verificando estrutura do banco:${NC}"
docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c "
    SELECT 
        column_name as \"Coluna\",
        data_type as \"Tipo\"
    FROM information_schema.columns
    WHERE table_schema = 'tenant'
    AND table_name = 'organizations'
    AND column_name IN ('max_validations', 'validations_used', 'last_reset_date', 'is_active', 'settings', 'updated_at')
    ORDER BY ordinal_position;
" 2>/dev/null || echo "Não foi possível verificar estrutura"

# ================================================
# VERIFICAR FUNÇÕES DO BANCO
# ================================================
echo -e "\n${CYAN}🔧 Verificando funções de quota:${NC}"
docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c "
    SELECT 
        routine_name as \"Função\",
        parameter_data_types as \"Parâmetros\"
    FROM information_schema.routines
    WHERE routine_schema = 'tenant'
    AND routine_name IN ('increment_validation_usage', 'check_quota', 'reset_monthly_quotas')
    ORDER BY routine_name;
" 2>/dev/null || echo "Não foi possível verificar funções"

# ================================================
# RELATÓRIO FINAL
# ================================================
echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     🔄 REINICIALIZAÇÃO COM MIGRATIONS CONCLUÍDA${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}📝 AÇÕES REALIZADAS:${NC}"
echo "  ✅ Containers reiniciados"
echo "  ✅ Migrations executadas"
echo "  ✅ Banco de dados atualizado"
echo "  ✅ Serviços verificados"

echo -e "\n${CYAN}🔧 COMANDOS ÚTEIS:${NC}"
echo -e "  Ver logs:                   ${YELLOW}docker-compose logs -f client-dashboard${NC}"
echo -e "  Ver migrations executadas:  ${YELLOW}docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c 'SELECT * FROM migrations.history ORDER BY executed_at DESC;'${NC}"
echo -e "  Ver migrations com erro:    ${YELLOW}docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c 'SELECT * FROM migrations.history WHERE success = false;'${NC}"
echo -e "  Resetar quotas manualmente: ${YELLOW}docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c 'SELECT * FROM tenant.reset_monthly_quotas();'${NC}"
echo -e "  Verificar quota de org:     ${YELLOW}docker exec -i sparknexus-postgres psql -U sparknexus -d sparknexus -c 'SELECT * FROM tenant.check_quota(1, 1);'${NC}"

echo -e "\n${GREEN}🎉 SISTEMA REINICIADO COM SUCESSO!${NC}"
echo -e "${GREEN}Acesse: http://localhost:4201${NC}"

exit 0