#!/bin/bash

# ================================================
# SPARK NEXUS - FIX CLIENT DASHBOARD DEPENDENCIES
# Instala todas as dependências no local correto
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
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      🔧 FIX CLIENT DASHBOARD DEPENDENCIES                   ║${NC}"
echo -e "${CYAN}║      Instalação completa de todas as dependências           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================
# VERIFICAÇÕES INICIAIS
# ================================================
echo -e "${YELLOW}[1/8] Verificações iniciais...${NC}"

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Erro: Execute este script no diretório raiz do projeto Spark Nexus${NC}"
    exit 1
fi

# Verificar se o diretório client-dashboard existe
if [ ! -d "core/client-dashboard" ]; then
    echo -e "${RED}❌ Erro: Diretório core/client-dashboard não encontrado${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Diretório do projeto verificado${NC}"

# ================================================
# PARAR CONTAINER
# ================================================
echo -e "\n${YELLOW}[2/8] Parando container client-dashboard...${NC}"
docker-compose stop client-dashboard 2>/dev/null || true
echo -e "${GREEN}✅ Container parado${NC}"

# ================================================
# BACKUP DO PACKAGE.JSON
# ================================================
echo -e "\n${YELLOW}[3/8] Fazendo backup do package.json...${NC}"
if [ -f "core/client-dashboard/package.json" ]; then
    cp core/client-dashboard/package.json core/client-dashboard/package.json.backup_$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✅ Backup criado${NC}"
else
    echo -e "${YELLOW}⚠️  package.json não existe, será criado${NC}"
fi

# ================================================
# LIMPAR INSTALAÇÕES ANTIGAS
# ================================================
echo -e "\n${YELLOW}[4/8] Limpando instalações antigas...${NC}"
cd core/client-dashboard

# Remover node_modules e package-lock.json
if [ -d "node_modules" ]; then
    echo "  Removendo node_modules antigo..."
    rm -rf node_modules
fi

if [ -f "package-lock.json" ]; then
    echo "  Removendo package-lock.json antigo..."
    rm -f package-lock.json
fi

echo -e "${GREEN}✅ Limpeza concluída${NC}"

# ================================================
# VERIFICAR/CRIAR PACKAGE.JSON
# ================================================
echo -e "\n${YELLOW}[5/8] Verificando package.json...${NC}"

if [ ! -f "package.json" ]; then
    echo -e "${YELLOW}Criando package.json...${NC}"
    cat > package.json << 'PACKAGEJSON'
{
  "name": "sparknexus-client-dashboard",
  "version": "2.0.0",
  "description": "Client Dashboard for Spark Nexus",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "axios": "^1.6.0",
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "compression": "^1.7.4",
    "cpf-cnpj-validator": "^1.0.3",
    "csv-parser": "^3.0.0",
    "csv-parse": "^5.5.0",
    "disposable-email-domains": "^1.0.62",
    "dns-socket": "^4.2.2",
    "dotenv": "^16.3.1",
    "email-validator": "^2.0.4",
    "exceljs": "^4.4.0",
    "express": "^4.18.2",
    "express-rate-limit": "^7.1.5",
    "express-validator": "^7.0.1",
    "helmet": "^7.1.0",
    "ioredis": "^5.3.0",
    "jsonwebtoken": "^9.0.2",
    "levenshtein": "^1.0.5",
    "lodash": "^4.17.21",
    "moment": "^2.29.4",
    "morgan": "^1.10.0",
    "multer": "^1.4.5-lts.1",
    "node-cache": "^5.1.2",
    "nodemailer": "^6.9.7",
    "papaparse": "^5.4.1",
    "pg": "^8.11.3",
    "psl": "^1.9.0",
    "punycode": "^2.3.0",
    "redis": "^4.6.0",
    "tldts": "^6.0.0",
    "twilio": "^4.19.0",
    "uuid": "^9.0.1",
    "validator": "^13.11.0",
    "xlsx": "^0.18.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
PACKAGEJSON
    echo -e "${GREEN}✅ package.json criado${NC}"
else
    echo -e "${GREEN}✅ package.json já existe${NC}"
fi

# ================================================
# INSTALAR DEPENDÊNCIAS
# ================================================
echo -e "\n${YELLOW}[6/8] Instalando dependências...${NC}"
echo -e "${CYAN}Isso pode levar alguns minutos...${NC}"

# Verificar se npm está disponível no host
if command -v npm &> /dev/null; then
    echo "  Usando npm local..."
    npm install --production
else
    echo "  npm não encontrado localmente, usando Docker..."
    docker run --rm -v $(pwd):/app -w /app node:18 npm install --production
fi

# Verificar se a instalação foi bem-sucedida
if [ -d "node_modules" ]; then
    MODULE_COUNT=$(ls -1 node_modules 2>/dev/null | wc -l)
    echo -e "${GREEN}✅ $MODULE_COUNT módulos instalados com sucesso${NC}"
else
    echo -e "${RED}❌ Falha na instalação dos módulos${NC}"
    exit 1
fi

# ================================================
# VERIFICAR MÓDULOS CRÍTICOS
# ================================================
echo -e "\n${YELLOW}[7/8] Verificando módulos críticos...${NC}"

CRITICAL_MODULES=(
    "express"
    "exceljs"
    "psl"
    "levenshtein"
    "email-validator"
    "validator"
    "axios"
    "cors"
    "dotenv"
    "jsonwebtoken"
)

MISSING_MODULES=()

for module in "${CRITICAL_MODULES[@]}"; do
    if [ -d "node_modules/$module" ]; then
        echo -e "  ✅ $module"
    else
        echo -e "  ❌ $module - FALTANDO!"
        MISSING_MODULES+=("$module")
    fi
done

# Se houver módulos faltando, tentar instalar individualmente
if [ ${#MISSING_MODULES[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}Instalando módulos faltantes individualmente...${NC}"
    for module in "${MISSING_MODULES[@]}"; do
        echo "  Instalando $module..."
        if command -v npm &> /dev/null; then
            npm install "$module" --save
        else
            docker run --rm -v $(pwd):/app -w /app node:18 npm install "$module" --save
        fi
    done
fi

# ================================================
# REINICIAR CONTAINER
# ================================================
echo -e "\n${YELLOW}[8/8] Reiniciando container...${NC}"

# Voltar para o diretório raiz
cd ../..

# Reiniciar o container
docker-compose up -d client-dashboard

# Aguardar inicialização
echo -e "${YELLOW}⏳ Aguardando serviço inicializar...${NC}"
for i in {1..20}; do
    echo -n "."
    sleep 1
done
echo ""

# ================================================
# VERIFICAÇÃO FINAL
# ================================================
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📊 VERIFICAÇÃO FINAL${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar se o container está rodando
if docker ps | grep -q "sparknexus-client"; then
    echo -e "${GREEN}✅ Container está RODANDO${NC}"
    
    # Verificar logs por erros
    echo -e "\n${CYAN}🔍 Verificando erros...${NC}"
    ERRORS=$(docker-compose logs --tail=30 client-dashboard 2>&1 | grep -c "Error\|Cannot find module" || echo "0")
    
    if [ "$ERRORS" -eq "0" ]; then
        echo -e "${GREEN}✅ Nenhum erro detectado nos logs${NC}"
    else
        echo -e "${YELLOW}⚠️  $ERRORS erros encontrados nos logs${NC}"
        echo -e "${YELLOW}Últimos erros:${NC}"
        docker-compose logs --tail=30 client-dashboard 2>&1 | grep -E "Error|Cannot find module" | head -5
    fi
    
    # Testar API
    echo -e "\n${CYAN}🧪 Testando API...${NC}"
    
    # Múltiplas tentativas
    API_OK=false
    for i in {1..5}; do
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4201/health 2>/dev/null || echo "000")
        
        if [ "$RESPONSE" = "200" ]; then
            echo -e "${GREEN}✅ API FUNCIONANDO! (HTTP 200)${NC}"
            API_OK=true
            break
        else
            echo -e "  Tentativa $i/5: HTTP $RESPONSE"
            if [ $i -lt 5 ]; then
                sleep 3
            fi
        fi
    done
    
    if [ "$API_OK" = false ]; then
        echo -e "${YELLOW}⚠️  API ainda não está respondendo${NC}"
        echo -e "${YELLOW}Verifique os logs: docker-compose logs -f client-dashboard${NC}"
    fi
    
else
    echo -e "${RED}❌ Container NÃO está rodando${NC}"
    echo -e "${RED}Últimos logs:${NC}"
    docker-compose logs --tail=20 client-dashboard
fi

# ================================================
# RELATÓRIO FINAL
# ================================================
echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}     📦 INSTALAÇÃO DE DEPENDÊNCIAS CONCLUÍDA${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${CYAN}📊 RESUMO:${NC}"
echo -e "  • Diretório: core/client-dashboard"
echo -e "  • Módulos instalados: $MODULE_COUNT"
echo -e "  • Container: sparknexus-client"
echo -e "  • Porta: 4201"

echo -e "\n${CYAN}🔧 COMANDOS ÚTEIS:${NC}"
echo -e "  Ver logs:          ${YELLOW}docker-compose logs -f client-dashboard${NC}"
echo -e "  Reiniciar:         ${YELLOW}docker-compose restart client-dashboard${NC}"
echo -e "  Verificar módulos: ${YELLOW}ls core/client-dashboard/node_modules/${NC}"
echo -e "  Testar API:        ${YELLOW}curl http://localhost:4201/health${NC}"

if [ "$API_OK" = true ]; then
    echo -e "\n${GREEN}🎉 SISTEMA FUNCIONANDO!${NC}"
    echo -e "${GREEN}Acesse: http://localhost:4201${NC}"
else
    echo -e "\n${YELLOW}⚠️  AÇÃO NECESSÁRIA:${NC}"
    echo -e "  1. Verifique os logs para identificar erros"
    echo -e "  2. Se houver módulos faltando, instale manualmente:"
    echo -e "     ${CYAN}cd core/client-dashboard && npm install [módulo]${NC}"
fi

echo -e "\n${GREEN}✅ Script concluído!${NC}\n"

exit 0